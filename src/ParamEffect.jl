"""
    ParamEffect

A parameter modification effect that changes an ODE parameter based on trigger conditions.

# Fields
- `target::Symbol`: The ODE parameter to modify (e.g., `:beta`, `:contact_rate`)
- `func::Function`: Function mapping original value to modified value: `f(x) -> x_modified`
- `reset_func::Function`: Function to undo the modification: `f_reset(x_modified) -> x_original`
- `trigger_on::Trigger`: Condition for activating the effect
- `trigger_off::Trigger`: Condition for deactivating the effect
- `ison::Bool`: Current state (mutable) tracking whether the effect is active

# Constructor
```julia
ParamEffect(target::Symbol, func::Function, reset_func::Function,
            trigger_on::Trigger, trigger_off::Trigger)
```

# Examples
```julia
# Reduce beta by 40% when H > 5000, restore when H < 3000
effect = ParamEffect(
    :beta,
    x -> x * 0.4,
    x -> x / 0.4,
    ReactiveTrigger(idx_H, 5000.0, sum, :>=),
    ReactiveTrigger(idx_H, 3000.0, sum, :<)
)

# Reduce contact rate starting at day 10, restore at day 50
effect = ParamEffect(
    :contact_rate,
    x -> x * 0.5,
    x -> x / 0.5,
    TimeTrigger(10.0),
    TimeTrigger(50.0)
)

# Mixed triggers: activate when cases rise, deactivate at day 100
effect = ParamEffect(
    :beta,
    x -> x * 0.6,
    x -> x / 0.6,
    ReactiveTrigger(idx_cases, 1000.0),
    TimeTrigger(100.0)
)
```
"""
mutable struct ParamEffect
    target::Symbol
    func::Function
    reset_func::Function
    trigger_on::Trigger
    trigger_off::Trigger
    ison::Bool

    function ParamEffect(target::Symbol, func::Function, reset_func::Function,
            trigger_on::Trigger, trigger_off::Trigger)
        # Check if func and reset_func are inverses of each other
        test_value = 1.0
        transformed = func(test_value)
        restored = reset_func(transformed)

        if !isapprox(restored, test_value; rtol = 1e-8, atol = 1e-12)
            @warn "The change function and reset function may not be inverses of each other. " *
                  "Expected reset_func(func($test_value)) ≈ $test_value, " *
                  "but got $restored (change function returned $transformed)."
        end

        return new(target, func, reset_func, trigger_on, trigger_off, false)
    end
end
