```@meta
CurrentModule = EpiEvents
```

# Basic usage

This guide demonstrates how to use EpiEvents.jl to define parameter modifications (non-pharmaceutical interventions, policy changes, etc.) in epidemic models.

## Core Concepts

EpiEvents provides a modular framework for specifying how model parameters should change based on either:
- **Reactive triggers**: When epidemic state crosses a threshold (e.g., "when hospitalizations exceed 5000")
- **Timed triggers**: At specific time points (e.g., "day 10 through day 50")

Each parameter modification is specified as a `ParamEffect` with:
- A target parameter (e.g., `:beta` for transmission rate)
- A modification function (e.g., "multiply by 0.4" to reduce contact)
- A restoration function (e.g., "divide by 0.4" to restore)
- Trigger conditions for activation and deactivation

## State-dependent effects

State-dependent effects react to the model state alone, and not to time, using `ContinuousCallback`s.
They require information on when to trigger and what state value to watch out for, and this is passed via `ReactiveTrigger` structs, which are passed to both the 'on' and 'off' triggers.

In this example, we define an effect that reduces a hypothetical transmission parameter (`beta`) when hospitalizations exceed a threshold.
There are certain implicit assumptions:

1. The state indices should exist (no OOB errros), and should correspond to some meaningful quantity in the model;

2. The model parameters should be contained in a type that supports indexing by symbol, such as a struct or a dict;

3. The modification and restoration functions should be reasonable, and ideally set and reset the value of the modified parameter;

4. The state summary and comparison function should be reasonable.

This implementation is intentionally flexible to allow users to build off of it.

Each effect is expected to have both change and reset functions, which is reasonable for modelling perturbations to a system rather than permanent changes to the parameters.
Pass a dummy function as the reset if you want to change a parameter permanently; there are no checks on whether a `ParamEffect` has an reset function that inverts the effect of the change function.

!!! note "Depedence on dx"

State-dependent effects currently only handle compartmental prevalence and not incidence.
For an epi modelling context this means it is not currently possible to launch an Npi on new cases, only on a prevalence measure (such as hospital occupancy, deaths etc.).

```@example basic_reactive
using EpiEvents

# Indices of hospitalized compartments in your state vector
# these should come from the user
idx_H = 20:25

# Create the effect
effect = ParamEffect(
    :beta,                                    # parameter to modify
    x -> x * 0.4,                            # multiply by 0.4 (60% reduction)
    x -> x / 0.4,                            # divide by 0.4 (restoration)
    ReactiveTrigger(idx_H, 5000.0),          # activate: sum(H) >= 5000
    ReactiveTrigger(idx_H, 3000.0, sum, :<)  # deactivate: sum(H) < 3000
)

# Package into an NPI and generate callbacks
npi = Npi([effect])
callbacks = make_callbacks(npi)

# Use with OrdinaryDiffEq
# sol = solve(prob, Tsit5(), callback=callbacks)
```

## Time-dependent effects

Time-dependent effects react only to model time, and not to model state.
The assumptions around the change and reset functions are carried over from the state-dependent effects; they should be reasonable but this isn't checked.

The `TimeTrigger` type simply activates the change and reset functions at the specified times, using `PresetTimeCallbacks`.

```@example basic_timed
using EpiEvents

# Reduce contact rate during intervention period
effect_timed = ParamEffect(
    :contact_rate,
    x -> x * 0.6,                            # 40% reduction
    x -> x / 0.6,                            # restoration
    TimeTrigger(10.0),                       # activate at day 10
    TimeTrigger(50.0)                        # deactivate at day 50
)

npi = Npi([effect_timed])
callbacks = make_callbacks(npi)
```

## Mixed effects

The `ParamEffect` type allows mixing trigger types, so that an effect can be triggered by some critical state and shut off at a particular time, or vice-versa.

```@example basic_mixed
using EpiEvents

# Activate when cases spike (reactive), 
# but force deactivation by day 100 (timed)
idx_cases = 4:6
effect_mixed = ParamEffect(
    :beta,
    x -> x * 0.5,
    x -> x / 0.5,
    ReactiveTrigger(idx_cases, 10000.0),    # activate when cases >= 10000
    TimeTrigger(100.0)                       # deactivate at day 100
)

npi = Npi([effect_mixed])
callbacks = make_callbacks(npi)
```

## Combining effects

Multiple effects can be combined into a single `Npi`.
This example shows a hypothetical case of modifying both the transmission rate and the vaccination rate.

```@example multi_effects
using EpiEvents

idx_H = 20:25

effects = [
    # Reactive effect: reduce beta when H spikes
    ParamEffect(
        :beta,
        x -> x * 0.4,
        x -> x / 0.4,
        ReactiveTrigger(idx_H, 5000.0),
        ReactiveTrigger(idx_H, 2000.0, sum, :<)
    ),
    
    # Timed effect: increase vaccination rate from day 30-60
    ParamEffect(
        :nu,
        x -> x * 1.5,
        x -> x / 1.5,
        TimeTrigger(30.0),
        TimeTrigger(60.0)
    )
]

npi = Npi(effects)
callbacks = make_callbacks(npi)
```

## Custom aggregation functions

Users can pass any function to aggregate the state at chosen indices, as shown here.

```@example custom_aggregation
using EpiEvents

# Trigger when the MAXIMUM value in a compartment group exceeds threshold
effect_max = ParamEffect(
    :beta,
    x -> x * 0.5,
    x -> x / 0.5,
    ReactiveTrigger(5:15, 100.0, maximum),    # max(u[5:15]) >= 100
    ReactiveTrigger(5:15, 50.0, maximum, :<)  # max(u[5:15]) < 50
)

# Trigger when the MINIMUM value drops below threshold
effect_min = ParamEffect(
    :sigma,
    x -> x * 0.9,
    x -> x / 0.9,
    ReactiveTrigger(30:35, 10.0, minimum, :<), # min(u[30:35]) < 10
    TimeTrigger(200.0)                          # restore at day 200
)

npi = Npi([effect_max, effect_min])
callbacks = make_callbacks(npi)
```

## Mapping state indices

The framework requires explicit mapping of compartment names to state vector indices. This is user responsibility, allowing flexibility for different model structures.

**Example**: If your state vector `u` is structured as:

```
u[1:5]    = S (susceptible, 5 age groups)
u[6:10]   = E (exposed, 5 age groups)
u[11:15]  = I (infectious, 5 age groups)
u[16:20]  = H (hospitalized, 5 age groups)
u[21:25]  = ICU (intensive care, 5 age groups)
```

Then define indices as:

```julia
idx_S = 1:5
idx_E = 6:10
idx_I = 11:15
idx_H = 16:20
idx_ICU = 21:25

# Use in triggers:
ReactiveTrigger(idx_H, 1000.0)      # when sum(H) >= 1000
ReactiveTrigger(idx_ICU, 100.0)     # when sum(ICU) >= 100
```

## Flexibility in zero-crossing for state-dependent effects

_EpiEvents.jl_ supports specifying reactive triggers that check whether a state value has increased above, or dropped below, a critical threshold.

```julia
# Upward crossing (default): activate when state RISES above threshold
ReactiveTrigger(idx, 1000.0)                 # same as :>=
ReactiveTrigger(idx, 1000.0, sum, :>=)       # explicit

# Downward crossing: activate when state FALLS below threshold
ReactiveTrigger(idx, 1000.0, sum, :<)        # strict <
ReactiveTrigger(idx, 1000.0, sum, :<=)       # less than or equal

# Strict comparisons
ReactiveTrigger(idx, 500.0, sum, :>)         # strict >
```

**Use case**: Pair comparisons for hysteresis (prevent rapid toggling):

```julia
# code not run
# Activate when H rises above 5000, deactivate when H falls below 3000
# (prevents rapid on/off cycling at boundary)
ParamEffect(
    :beta,
    x -> x * 0.4,
    x -> x / 0.4,
    ReactiveTrigger(idx_H, 5000.0, sum, :>=),   # activation threshold
    ReactiveTrigger(idx_H, 3000.0, sum, :<)     # deactivation threshold
)
```

## Integration with OrdinaryDiffEq.jl

Once callbacks are generated, use them directly with any _DifferentialEquations.jl_ solver:

```julia
# code not run
using OrdinaryDiffEq

# Build callbacks
npi = Npi([effect1, effect2])
cbset = make_callbacks(npi)

# Solve with callbacks
sol = solve(prob, Tsit5(), callback=cbset, saveat=0.1)

# Or use ensemble methods
ensembleprob = EnsembleProblem(prob)
sol = solve(ensembleprob, Tsit5(), callback=cbset, trajectories=10)
```

## Common Patterns

### Pattern: Gradual Intervention

Apply intervention proportional to state level:

```julia
# When cases exceed threshold, reduce beta by a factor
# Proportional reduction could be implemented as:
effect = ParamEffect(
    :beta,
    x -> x * 0.5,  # fixed reduction (you control the amount)
    x -> x / 0.5,
    ReactiveTrigger(idx_cases, 5000.0),
    ReactiveTrigger(idx_cases, 1000.0, sum, :<)
)
```

### Pattern: Sequential interventions

Stage interventions with different triggers:

```julia
# note code not run
npi = Npi([
    # Stage 1: mild measures when cases start rising
    ParamEffect(:beta, x -> x * 0.8, x -> x / 0.8,
                ReactiveTrigger(idx_cases, 1000.0),
                ReactiveTrigger(idx_cases, 500.0, sum, :<)),
    
    # Stage 2: stricter measures when hospitalizations spike
    ParamEffect(:beta, x -> x * 0.5, x -> x / 0.5,
                ReactiveTrigger(idx_H, 5000.0),
                ReactiveTrigger(idx_H, 2000.0, sum, :<)),
])
```

### Pattern: Time-limited emergency measures

Apply strict intervention for bounded duration:
```julia
effect = ParamEffect(
    :beta,
    x -> x * 0.3,  # 70% reduction
    x -> x / 0.3,
    ReactiveTrigger(idx_cases, 50000.0),  # activate at crisis level
    TimeTrigger(30.0)                      # hard stop after 30 days
)
```

## Parameter access

The framework supports both struct and dict-like parameter objects:

```julia
# Struct-based parameters
mutable struct ModelParams
    beta::Float64
    contact_rate::Float64
end

params = ModelParams(0.5, 1.0)

# Dict-based parameters
params = Dict(:beta => 0.5, :contact_rate => 1.0)

# Both work seamlessly with callbacks:
npi = Npi([effect])
cbset = make_callbacks(npi)
sol = solve(prob, Tsit5(), p=params, callback=cbset)
```

See the Function Reference page for complete API documentation.
