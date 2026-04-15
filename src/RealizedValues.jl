"""
    RealizedValues

Functions for computing the realized (actual) values of parameters during a simulation,
accounting for which effects are active at each point in time.
"""

using SciMLBase: AbstractODESolution

"""
    is_effect_active(eff::ParamEffect, time::Real)::Bool

Determine whether an effect is active at a specific time point.

An effect is considered active if:
- It has been activated (time_on entry exists)
- AND it has either never been deactivated, or the last deactivation was before this time

# Arguments
- `eff::ParamEffect`: The effect to check
- `time::Real`: The time point to evaluate at

# Returns
Boolean indicating if the effect is active at the given time.

# Examples
```julia
eff.time_on = [10.0, 50.0]
eff.time_off = [40.0]

is_effect_active(eff, 5.0)   # false (before first activation)
is_effect_active(eff, 25.0)  # true (activated at 10.0, deactivated at 40.0)
is_effect_active(eff, 45.0)  # true (reactivated at 50.0)
is_effect_active(eff, 60.0)  # true (activated at 50.0, never deactivated)
```
"""
function is_effect_active(eff::ParamEffect, time::Real)::Bool
    # Check how many times the effect has been activated by this time
    n_activated = count(t -> t <= time, eff.time_on)

    # If never activated, effect is inactive
    n_activated == 0 && return false

    # Check how many times the effect has been deactivated by this time
    n_deactivated = count(t -> t <= time, eff.time_off)

    # Effect is active if more activations than deactivations
    return n_activated > n_deactivated
end

"""
    realized_values(eff::ParamEffect, original_value::Real, times::AbstractVector{Real})::Vector{Real}

Compute the realized (actual) value of a parameter at each time point, accounting for this effect.

The realized value represents the effective parameter value when this single effect is applied.
For effects with multiple activation/deactivation cycles, the value is `func(original_value)`
when the effect is active, and `original_value` when inactive.

# Arguments
- `eff::ParamEffect`: The effect to analyze
- `original_value::Real`: The baseline parameter value (before any effects)
- `times::AbstractVector{Real}`: Time points at which to evaluate realized values

# Returns
A vector of realized parameter values, one per time point. Length matches `times`.

# Details
- If effect never activates, returns vector of original_value
- If effect activates multiple times, applies func during active intervals
- Assumes func and reset_func are proper inverses
- Order of time points in `times` does not matter; algorithm is O(n*m) where n=length(times), m=number of activations

# Examples
```julia
eff = ParamEffect(:beta, x -> x * 0.5, x -> x / 0.5, TimeTrigger(10.0), TimeTrigger(40.0))
eff.time_on = [10.0]
eff.time_off = [40.0]

realized_values(eff, 1.0, [5.0, 15.0, 50.0])
# Returns: [1.0, 0.5, 1.0]
# At t=5: effect not yet active → 1.0
# At t=15: effect active → 0.5 (1.0 * 0.5)
# At t=50: effect deactivated → 1.0
```
"""
function realized_values(eff::ParamEffect, original_value::Real, times::AbstractVector{Real})::Vector{Real}
    return [is_effect_active(eff, t) ? eff.func(original_value) : original_value for t in times]
end

"""
    realized_values(npi::Npi, params::AbstractDict, sol::AbstractODESolution)::Dict{Symbol, Vector{Float64}}

Compute the realized (actual) values of all parameters at each time point, accounting for all effects.

This function aggregates effects from an NPI by target parameter and computes the combined realized
values considering all effects that may be active at each time point. Multiple effects targeting
the same parameter are applied in order of their first activation time.

# Arguments
- `npi::Npi`: The NPI containing all effects
- `params::AbstractDict`: Dictionary of original parameter values (e.g., `Dict(:beta => 0.5, :gamma => 0.1)`)
- `sol::AbstractODESolution`: ODE solution providing time points and solution data

# Returns
A dictionary mapping parameter symbols to vectors of realized values, one vector per parameter.
Each vector has length equal to `length(sol.t)`.

# Details
- Parameters not targeted by any effect are excluded from the result
- When multiple effects target the same parameter, they are applied in order of first activation
- If multiple effects are simultaneously active on the same parameter, the transformations are chained
- Effects that never activate (empty time_on) are never applied

# Examples
```julia
npi = Npi([
    ParamEffect(:beta, x -> x * 0.5, x -> x / 0.5, TimeTrigger(10.0), TimeTrigger(40.0)),
    ParamEffect(:gamma, x -> x * 0.8, x -> x / 0.8, TimeTrigger(20.0), TimeTrigger(60.0))
])
params = Dict(:beta => 0.5, :gamma => 0.1)
sol = solve(prob, Tsit5(), callback=make_callbacks(npi))

realized = realized_values(npi, params, sol)
# realized[:beta]   # Vector of beta values at each sol.t
# realized[:gamma]  # Vector of gamma values at each sol.t
```
"""
function realized_values(npi::Npi, params::AbstractDict, sol::AbstractODESolution)::Dict{Symbol, Vector{Float64}}
    times = sol.t
    result = Dict{Symbol, Vector{Float64}}()

    # Group effects by target parameter
    effects_by_param = Dict{Symbol, Vector{ParamEffect}}()
    for eff in npi.effects
        if eff.target ∉ keys(effects_by_param)
            effects_by_param[eff.target] = ParamEffect[]
        end
        push!(effects_by_param[eff.target], eff)
    end

    # For each parameter, compute realized values
    for (param_symbol, effects) in effects_by_param
        # Get original parameter value
        original_value = params[param_symbol]

        # Sort effects by first activation time (effects that never activate have Inf as first time)
        first_activation_times = [isempty(eff.time_on) ? Inf : first(eff.time_on) for eff in effects]
        sorted_indices = sortperm(first_activation_times)
        sorted_effects = effects[sorted_indices]

        # For each time point, compute realized value with all effects applied in order
        realized = similar(times, Float64)
        for (i, t) in enumerate(times)
            value = original_value
            # Apply each active effect in order of first activation
            for eff in sorted_effects
                if is_effect_active(eff, t)
                    value = eff.func(value)
                end
            end
            realized[i] = value
        end

        result[param_symbol] = realized
    end

    return result
end

"""
    realized_values(npi::Npi, params::NamedTuple, sol::AbstractODESolution)::Dict{Symbol, Vector{Float64}}

Compute realized parameter values using a NamedTuple of parameters.

This is a convenience overload of `realized_values(npi::Npi, params::AbstractDict, sol)` that
accepts a NamedTuple instead of a dictionary.

# Arguments
- `npi::Npi`: The NPI containing all effects
- `params::NamedTuple`: Named tuple of original parameter values (e.g., `(beta=0.5, gamma=0.1)`)
- `sol::AbstractODESolution`: ODE solution providing time points

# Returns
A dictionary mapping parameter symbols to vectors of realized values.

# Examples
```julia
params = (beta=0.5, gamma=0.1)
realized = realized_values(npi, params, sol)
```
"""
function realized_values(npi::Npi, params::NamedTuple, sol::AbstractODESolution)::Dict{Symbol, Vector{Float64}}
    return realized_values(npi, Dict(params), sol)
end
