"""
    EpiEvents

A Julia package for defining modular events and callbacks in epidemic projection models.

EpiEvents provides a framework for specifying parameter modifications (non-pharmaceutical
interventions, policy changes, etc.) that respond to either model time or epidemic state.

# Core Types
- `Trigger`: Abstract base for activation/deactivation conditions
  - `ReactiveTrigger`: Fires when model state crosses a threshold
  - `TimeTrigger`: Fires at specific time points
- `ParamEffect`: Specifies how to modify an ODE parameter and when
- `Npi`: Container for collections of `ParamEffect`

# Main Functions
- `make_callbacks(npi::Npi)`: Generate a `CallbackSet` for use with OrdinaryDiffEq

# Example
```julia
using EpiEvents

# Define state indices (user responsibility)
idx_H = 20:25  # indices of hospitalized compartments

# Create a reactive intervention: reduce beta when H > 5000, restore when H < 2000
effect = ParamEffect(
    :beta,                                    # parameter to modify
    x -> x * 0.4,                            # reduction function
    x -> x / 0.4,                            # restoration function
    ReactiveTrigger(idx_H, 5000.0),          # activate when H ≥ 5000
    ReactiveTrigger(idx_H, 2000.0, sum, :<)  # deactivate when H < 2000
)

npi = Npi([effect])
cbset = make_callbacks(npi)

# Use with DifferentialEquations.jl:
# sol = solve(prob, Tsit5(), callback=cbset)
```

See the documentation for detailed examples and architectural notes.
"""
module EpiEvents

include("Trigger.jl")
include("ParamEffect.jl")
include("Npi.jl")
include("GenEvents.jl")
include("ExampleModels.jl")

export Trigger, ReactiveTrigger, TimeTrigger, DurationTrigger
export ParamEffect
export Npi
export make_callbacks
export SIRParams, sir_model!

end
