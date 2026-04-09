```@meta
CurrentModule = EpiEvents
```

# SIR Model Example

This example demonstrates EpiEvents.jl with a simple compartmental SIR (Susceptible-Infected-Recovered) epidemic model.

## The SIR Model

We implement a basic SIR model with parameters that can be modified via interventions:

```julia
using OrdinaryDiffEq
using EpiEvents

# SIR model with modifiable parameters
function sir_model!(du, u, p, t)
    S, I, R = u
    β, γ = p.beta, p.gamma
    
    N = S + I + R
    
    du[1] = -β * S * I / N          # dS/dt
    du[2] = β * S * I / N - γ * I   # dI/dt
    du[3] = γ * I                   # dR/dt
end
```

The parameters are:
- `β` (beta): transmission rate (contacts × probability per contact)
- `γ` (gamma): recovery rate (1/infectious period)

The state vector is:
- `u[1] = S`: susceptible individuals
- `u[2] = I`: infected individuals
- `u[3] = R`: recovered individuals

## Adding a Public Health Intervention

When infections spike, public health authorities typically respond by increasing social distancing, which reduces the transmission rate. We can model this with EpiEvents.

```julia
# Model parameters (mutable so they can be modified by callbacks)
mutable struct SIRParams
    beta::Float64     # transmission rate
    gamma::Float64    # recovery rate
end

# Initial conditions
N = 100_000  # population size
I0 = 100     # initial infected
S0 = N - I0
R0 = 0

u0 = [S0, I0, R0]

# Parameters
params = SIRParams(
    0.5 / N,   # beta: 0.5 contacts per day, normalized by population
    1/10       # gamma: infectious period of 10 days
)

# Time span: 200 days
tspan = (0.0, 200.0)

# Define the ODE problem
prob = ODEProblem(sir_model!, u0, tspan, params)

# Create intervention: reduce beta when infections exceed 5% of population
idx_I = 2  # state index for infected

effect = ParamEffect(
    :beta,
    x -> x * 0.3,              # reduce beta to 30% (70% reduction)
    x -> x / 0.3,              # restoration function
    ReactiveTrigger(idx_I, 0.05 * N),    # activate when I > 5000
    ReactiveTrigger(idx_I, 0.02 * N, :<) # deactivate when I < 2000
)

npi = Npi([effect])
callbacks = make_callbacks(npi)

# Solve with callbacks
sol = solve(prob, Tsit5(), callback=callbacks, saveat=1.0)
```

## Results

When you run this example, you'll observe:

1. **Initial exponential growth** (days 0–20): Infections grow rapidly with β = 0.5/N
2. **Intervention activation** (around day 20): When I exceeds 5000, beta is reduced to 0.15/N
3. **Flattened curve** (days 20–50): Slower growth with reduced transmission
4. **Intervention deactivation** (around day 50): When I drops below 2000, beta returns to 0.5/N
5. **Second wave suppression** (days 50+): Any subsequent resurgence is limited

## Plotting Results

To visualize the epidemic curve and intervention timing:

```julia
using Plots

# Extract solution
S = sol[1, :]
I = sol[2, :]
R = sol[3, :]
t = sol.t

# Plot
p = plot(t, S, label="Susceptible", linewidth=2)
plot!(p, t, I, label="Infected", linewidth=2)
plot!(p, t, R, label="Recovered", linewidth=2)
xlabel!(p, "Time (days)")
ylabel!(p, "Count")
title!(p, "SIR Model with Reactive Intervention")
legend!(p, loc=:topright)
```

The infected curve (orange) shows a characteristic "flattening":
- Steep rise until day ~20
- Growth slows after intervention (beta reduced)
- Peak becomes lower and broader
- This is the classic "flatten the curve" effect

## Exploring Different Interventions

You can easily modify the intervention:

### Stronger intervention
```julia
effect_strong = ParamEffect(
    :beta,
    x -> x * 0.1,              # 90% reduction
    x -> x / 0.1,
    ReactiveTrigger(idx_I, 0.05 * N),
    ReactiveTrigger(idx_I, 0.01 * N, :<)
)
```

### Earlier activation
```julia
effect_early = ParamEffect(
    :beta,
    x -> x * 0.3,
    x -> x / 0.3,
    ReactiveTrigger(idx_I, 0.02 * N),    # activate at 2% instead of 5%
    ReactiveTrigger(idx_I, 0.01 * N, :<)
)
```

### Timed intervention (lockdown for 30 days)
```julia
effect_timed = ParamEffect(
    :beta,
    x -> x * 0.1,              # strict lockdown
    x -> x / 0.1,
    TimeTrigger(15.0),         # start day 15
    TimeTrigger(45.0)          # end day 45
)
```

## Multiple Interventions

You can combine multiple interventions targeting different parameters:

```julia
effects = [
    # Reduce transmission when infections spike
    ParamEffect(
        :beta,
        x -> x * 0.3,
        x -> x / 0.3,
        ReactiveTrigger(idx_I, 0.05 * N),
        ReactiveTrigger(idx_I, 0.02 * N, :<)
    ),
    
    # Increase recovery rate (e.g., more treatment/hospital resources)
    ParamEffect(
        :gamma,
        x -> x * 1.2,              # 20% faster recovery
        x -> x / 1.2,
        ReactiveTrigger(idx_I, 0.05 * N),
        ReactiveTrigger(idx_I, 0.02 * N, :<)
    )
]

npi_multi = Npi(effects)
callbacks_multi = make_callbacks(npi_multi)

sol_multi = solve(prob, Tsit5(), callback=callbacks_multi, saveat=1.0)
```

With both interventions active, the epidemic is further suppressed.

## Key Takeaways

This example demonstrates:

1. **Reactive triggers**: Interventions activate based on epidemic state (infections crossing a threshold)
2. **Hysteresis**: Different thresholds for activation and deactivation prevent oscillation
3. **Parameter modification**: The framework seamlessly modifies ODE parameters via callbacks
4. **Integration**: EpiEvents works naturally with OrdinaryDiffEq.jl solvers
5. **Realism**: Models real public health responses that depend on current conditions

The SIR model is simplified (no age structure, no hospital compartments, no vaccination), but the same techniques scale to complex epidemiological models like SEIR, age-structured models, or models with multiple intervention types.

## Complete Working Code

```julia
using OrdinaryDiffEq
using EpiEvents
using Plots

# SIR model
function sir_model!(du, u, p, t)
    S, I, R = u
    β, γ = p.beta, p.gamma
    N = S + I + R
    
    du[1] = -β * S * I / N
    du[2] = β * S * I / N - γ * I
    du[3] = γ * I
end

# Parameters
mutable struct SIRParams
    beta::Float64
    gamma::Float64
end

# Setup
N = 100_000
u0 = [N - 100, 100.0, 0.0]
params = SIRParams(0.5 / N, 1/10)
tspan = (0.0, 200.0)
prob = ODEProblem(sir_model!, u0, tspan, params)

# Intervention
effect = ParamEffect(
    :beta,
    x -> x * 0.3,
    x -> x / 0.3,
    ReactiveTrigger(2, 0.05 * N),
    ReactiveTrigger(2, 0.02 * N, :<)
)

npi = Npi([effect])
callbacks = make_callbacks(npi)

# Solve
sol = solve(prob, Tsit5(), callback=callbacks, saveat=1.0)

# Plot
plot(sol.t, sol[2, :], label="Infected", linewidth=2, xlabel="Time (days)", ylabel="Count")
```

Run this and observe the "flattened curve" effect of public health intervention!
