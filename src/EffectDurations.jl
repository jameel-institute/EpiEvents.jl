"""
    EffectDurations

Functions for computing how long each parameter effect was active during a simulation.
Provides both bare analysis (returns `Inf` for open intervals) and solution-aware analysis
(calculates duration for still-active effects using the final simulation time).
"""

using SciMLBase: AbstractODESolution

"""
    effect_durations(eff::ParamEffect)::Vector{Float64}

Compute the duration(s) for which the effect was active.

For each completed activation-deactivation pair, returns the duration (time_off[i] - time_on[i]).
If the effect is currently active (more time_on entries than time_off), the last entry is `Inf`.

# Arguments
- `eff::ParamEffect`: The effect to analyze

# Returns
A vector of durations (in model time units). Empty vector if effect was never activated.
Open interval (effect still active) is represented as `Inf`.

# Examples
```julia
# Effect activated once, deactivated once
eff.time_on = [10.0]
eff.time_off = [40.0]
effect_durations(eff)  # [30.0]

# Effect activated once, still active
eff.time_on = [10.0]
eff.time_off = []
effect_durations(eff)  # [Inf]

# Effect with multiple cycles
eff.time_on = [10.0, 50.0, 100.0]
eff.time_off = [40.0, 80.0]
effect_durations(eff)  # [30.0, 30.0, Inf]
```
"""
function effect_durations(eff::ParamEffect)::Vector{Float64}
    n_complete = min(length(eff.time_on), length(eff.time_off))
    durations = eff.time_off[1:n_complete] .- eff.time_on[1:n_complete]
    if length(eff.time_on) > length(eff.time_off)
        push!(durations, Inf)
    end
    return durations
end

"""
    effect_durations(eff::ParamEffect, sol::AbstractODESolution)::Vector{Float64}

Compute the duration(s) for which the effect was active, given an ODE solution.

For each completed activation-deactivation pair, returns the duration (time_off[i] - time_on[i]).
If the effect is currently active, the duration is calculated as (final_time - last_activation_time).

# Arguments
- `eff::ParamEffect`: The effect to analyze
- `sol::AbstractODESolution`: The ODE solution from which to extract the final simulation time

# Returns
A vector of durations (in model time units). Empty vector if effect was never activated.
Open intervals use `sol.t[end]` as the end time.

# Examples
```julia
# Effect activated at t=10, still active at t=200
eff.time_on = [10.0]
eff.time_off = []
sol.t = [0.0, 50.0, 100.0, 150.0, 200.0]  # (simplified representation)
effect_durations(eff, sol)  # [190.0]  (200.0 - 10.0)
```
"""
function effect_durations(eff::ParamEffect, sol::AbstractODESolution)::Vector{Float64}
    n_complete = min(length(eff.time_on), length(eff.time_off))
    durations = eff.time_off[1:n_complete] .- eff.time_on[1:n_complete]
    if length(eff.time_on) > length(eff.time_off)
        push!(durations, sol.t[end] - last(eff.time_on))
    end
    return durations
end

"""
    effect_durations(npi::Npi)::Vector{Vector{Float64}}

Compute the duration(s) for each effect in the NPI (without solution context).

Returns a vector where each element corresponds to an effect in `npi.effects`,
and contains the durations for that effect (with open intervals as `Inf`).

# Arguments
- `npi::Npi`: The NPI containing multiple effects

# Returns
A vector of duration vectors, one per effect.

# Examples
```julia
npi = Npi([eff1, eff2])
durations = effect_durations(npi)
# durations[1] is a vector of durations for eff1
# durations[2] is a vector of durations for eff2
```
"""
function effect_durations(npi::Npi)::Vector{Vector{Float64}}
    return [effect_durations(eff) for eff in npi.effects]
end

"""
    effect_durations(npi::Npi, sol::AbstractODESolution)::Vector{Vector{Float64}}

Compute the duration(s) for each effect in the NPI, given an ODE solution.

Returns a vector where each element corresponds to an effect in `npi.effects`,
and contains the durations for that effect, with open intervals calculated from `sol.t[end]`.

# Arguments
- `npi::Npi`: The NPI containing multiple effects
- `sol::AbstractODESolution`: The ODE solution from which to extract the final simulation time

# Returns
A vector of duration vectors, one per effect. Open intervals use the final solution time.

# Examples
```julia
npi = Npi([eff1, eff2])
sol = solve(prob, Tsit5(), callback=make_callbacks(npi))
durations = effect_durations(npi, sol)
# durations[1] is a vector of durations for eff1
# durations[2] is a vector of durations for eff2
```
"""
function effect_durations(npi::Npi, sol::AbstractODESolution)::Vector{Vector{Float64}}
    return [effect_durations(eff, sol) for eff in npi.effects]
end

export effect_durations
