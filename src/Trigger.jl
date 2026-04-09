"""
    Trigger

Abstract type for event triggers.

Subtypes define conditions under which a `ParamEffect` activates or deactivates.
"""
abstract type Trigger end

"""
    ReactiveTrigger(idx, value, combiner=sum, comparison=:>=)

A trigger that fires when model state crosses a threshold value.

# Arguments
- `idx::Union{Int, AbstractVector{Int}}`: Index or indices into state vector `u` to monitor
- `value::Float64`: Critical threshold value
- `combiner::Function=sum`: Function to aggregate multiple state indices (e.g., `sum`, `maximum`, `minimum`)
- `comparison::Symbol=:>=`: Comparison direction for zero-crossing detection
  - `:>=` or `:>`: Fire when state rises above threshold (upward crossing)
  - `:<=` or `:<`: Fire when state falls below threshold (downward crossing)

# Examples
```julia
# Trigger when sum of indices 20:25 exceeds 5000
ReactiveTrigger(20:25, 5000.0)

# Trigger when u[30] drops below 100
ReactiveTrigger(30, 100.0, sum, :<)

# Trigger when maximum across indices is less than 50
ReactiveTrigger(10:20, 50.0, maximum, :<)
```
"""
struct ReactiveTrigger <: Trigger
    idx::Union{Int, AbstractVector{Int}}
    value::Float64
    combiner::Function
    comparison::Symbol

    function ReactiveTrigger(idx::Union{Int, AbstractVector{Int}}, value::Float64,
            combiner::Function = sum, comparison::Symbol = :>=)
        @assert comparison in (:>=, :>, :<=, :<) "comparison must be one of (:>=, :>, :<=, :<)"
        return new(idx, value, combiner, comparison)
    end
end

"""
    TimeTrigger(value)

A trigger that fires at a specific time point.

# Arguments
- `value::Float64`: Time (in model time units, typically days) at which to fire

# Examples
```julia
# Trigger at day 10
TimeTrigger(10.0)

# Trigger at day 365
TimeTrigger(365.0)
```
"""
struct TimeTrigger <: Trigger
    value::Float64

    function TimeTrigger(value::Float64)
        return new(value)
    end
end
