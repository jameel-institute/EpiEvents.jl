"""
    GenEvents

Functions for generating OrdinaryDiffEq callbacks from `ParamEffect` specifications.

This module handles conversion of effects into `ContinuousCallback` (for reactive triggers),
`PresetTimeCallback` (for timed triggers), and combines them into a `CallbackSet`.
"""

using DiffEqCallbacks: ContinuousCallback, PresetTimeCallback, CallbackSet

# Helper functions for parameter access (supports both struct and dict-like parameters)

"""
    _get_param(p, target::Symbol)

Get a parameter value from either a struct (via getproperty) or dict-like object.
"""
function _get_param(p, target::Symbol)
    if isa(p, AbstractDict)
        return p[target]
    else
        return getproperty(p, target)
    end
end

"""
    _set_param!(p, target::Symbol, value)

Set a parameter value in either a struct (via setproperty!) or dict-like object.
"""
function _set_param!(p, target::Symbol, value)
    if isa(p, AbstractDict)
        p[target] = value
    else
        setproperty!(p, target, value)
    end
end

# Callback generator functions

"""
    make_reactive_on_callback(eff::ParamEffect)::ContinuousCallback

Create a continuous callback that activates when `trigger_on` condition is crossed.

Modifies the parameter when the state first crosses the trigger threshold.
Uses the `ison` flag to prevent multiple activations.
"""
function make_reactive_on_callback(eff::ParamEffect)
    trigger = eff.trigger_on
    @assert isa(trigger, ReactiveTrigger) "trigger_on must be ReactiveTrigger for reactive callback"

    function condition(u, ::Any, ::Any)
        state = trigger.combiner(u[trigger.idx])
        if trigger.comparison in (:>=, :>)
            return state - trigger.value
        else  # (:<=, :<)
            return trigger.value - state
        end
    end

    function affect!(integrator)
        if !eff.ison
            eff.ison = true
            original = _get_param(integrator.p, eff.target)
            new_val = eff.func(original)
            _set_param!(integrator.p, eff.target, new_val)
        end
    end

    return ContinuousCallback(condition, affect!)
end

"""
    make_reactive_off_callback(eff::ParamEffect)::ContinuousCallback

Create a continuous callback that deactivates when `trigger_off` condition is crossed.

Resets the parameter when the state first crosses the off-trigger threshold.
Uses the `ison` flag to prevent multiple resets.
"""
function make_reactive_off_callback(eff::ParamEffect)
    trigger = eff.trigger_off
    @assert isa(trigger, ReactiveTrigger) "trigger_off must be ReactiveTrigger for reactive callback"

    function condition(u, ::Any, ::Any)
        state = trigger.combiner(u[trigger.idx])
        if trigger.comparison in (:>=, :>)
            return state - trigger.value
        else  # (:<=, :<)
            return trigger.value - state
        end
    end

    function affect!(integrator)
        if eff.ison
            eff.ison = false
            current = _get_param(integrator.p, eff.target)
            reset_val = eff.reset_func(current)
            _set_param!(integrator.p, eff.target, reset_val)
        end
    end

    return ContinuousCallback(condition, affect!)
end

"""
    make_timed_on_callback(eff::ParamEffect)::PresetTimeCallback

Create a timed callback that activates at `trigger_on.value` time.

Modifies the parameter when the specified time is reached.
"""
function make_timed_on_callback(eff::ParamEffect)
    trigger = eff.trigger_on
    @assert isa(trigger, TimeTrigger) "trigger_on must be TimeTrigger for timed callback"

    function affect!(integrator)
        if !eff.ison
            eff.ison = true
            original = _get_param(integrator.p, eff.target)
            new_val = eff.func(original)
            _set_param!(integrator.p, eff.target, new_val)
        end
    end

    return PresetTimeCallback([trigger.value], affect!)
end

"""
    make_timed_off_callback(eff::ParamEffect)::PresetTimeCallback

Create a timed callback that deactivates at `trigger_off.value` time.

Resets the parameter when the specified time is reached.
"""
function make_timed_off_callback(eff::ParamEffect)
    trigger = eff.trigger_off
    @assert isa(trigger, TimeTrigger) "trigger_off must be TimeTrigger for timed callback"

    function affect!(integrator)
        if eff.ison
            eff.ison = false
            current = _get_param(integrator.p, eff.target)
            reset_val = eff.reset_func(current)
            _set_param!(integrator.p, eff.target, reset_val)
        end
    end

    return PresetTimeCallback([trigger.value], affect!)
end

"""
    make_callbacks(npi::Npi)

Generate a combined `CallbackSet` from an NPI containing multiple effects.

Creates appropriate callback types for each effect based on its trigger types:
- ReactiveTrigger → ContinuousCallback (checks state continuously)
- TimeTrigger → PresetTimeCallback (fires at specific times)

Returns a single `CallbackSet` combining all callbacks.

# Arguments
- `npi::Npi`: Container of `ParamEffect` objects

# Returns
A `CallbackSet` ready to use with OrdinaryDiffEq solvers

# Example
```julia
npi = Npi([
    ParamEffect(:beta, x -> x * 0.4, x -> x / 0.4,
                ReactiveTrigger(idx_H, 5000.0), ReactiveTrigger(idx_H, 2000.0, :<))
])
cbset = make_callbacks(npi)
# Use in solve: solve(prob, Tsit5(), callback=cbset)
```
"""
function make_callbacks(npi::Npi)::CallbackSet
    callbacks = []

    for eff in npi.effects
        # Handle trigger_on
        if isa(eff.trigger_on, ReactiveTrigger)
            push!(callbacks, make_reactive_on_callback(eff))
        elseif isa(eff.trigger_on, TimeTrigger)
            push!(callbacks, make_timed_on_callback(eff))
        else
            error("Unknown trigger_on type: $(typeof(eff.trigger_on))")
        end

        # Handle trigger_off
        if isa(eff.trigger_off, ReactiveTrigger)
            push!(callbacks, make_reactive_off_callback(eff))
        elseif isa(eff.trigger_off, TimeTrigger)
            push!(callbacks, make_timed_off_callback(eff))
        else
            error("Unknown trigger_off type: $(typeof(eff.trigger_off))")
        end
    end

    # Combine all callbacks into a single CallbackSet
    if isempty(callbacks)
        return CallbackSet()
    else
        return CallbackSet(callbacks...)
    end
end

export make_callbacks
