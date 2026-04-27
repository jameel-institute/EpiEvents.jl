"""
    Npi

A container for a collection of parameter effects representing a non-pharmaceutical intervention.

An NPI can contain any mix of `ParamEffect`s with reactive triggers (state-dependent) or
timed triggers (time-fixed), allowing flexible specification of complex interventions.
An NPI must contain at least one effect.

# Fields
- `effects::Vector{ParamEffect}`: Collection of parameter modifications to apply (non-empty)

# Constructor
```julia
Npi(effects::AbstractVector{ParamEffect})
```

# Examples
```julia
# Single reactive effect
npi = Npi([
    ParamEffect(:beta, x -> x * 0.4, x -> x / 0.4,
                ReactiveTrigger(idx_H, 5000.0), ReactiveTrigger(idx_H, 2000.0, :<))
])

# Multiple effects with different trigger types
npi = Npi([
    ParamEffect(:beta, x -> x * 0.5, x -> x / 0.5,
                ReactiveTrigger(idx_cases, 1000.0), TimeTrigger(100.0)),
    ParamEffect(:contact_rate, x -> x * 0.7, x -> x / 0.7,
                TimeTrigger(20.0), TimeTrigger(80.0))
])
```
"""
mutable struct Npi
    effects::Vector{ParamEffect}

    function Npi(effects::AbstractVector{ParamEffect})
        if isempty(effects)
            throw(ArgumentError("Npi must contain at least one ParamEffect"))
        end
        return new(Vector{ParamEffect}(effects))
    end
end
