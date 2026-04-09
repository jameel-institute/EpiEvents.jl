```@meta
CurrentModule = EpiEvents
```

# SIR Model Example

This example demonstrates EpiEvents.jl with a simple compartmental SIR (Susceptible-Infected-Recovered) epidemic model.

## The SIR Model

We implement a basic SIR model with parameters that can be modified via interventions:

```@example real_example
using OrdinaryDiffEq
using EpiEvents
using Plots

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

```@example real_example
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
    1.3 / 7.0, 1.0 / 7.0
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
    ReactiveTrigger(idx_I, 0.02 * N),    # activate when I > 2000
    ReactiveTrigger(idx_I, 0.005 * N, sum, :<) # deactivate when I < 1000
)

npi = Npi([effect])
callbacks = make_callbacks(npi)

# Solve with callbacks
sol = solve(prob, Tsit5(), callback=callbacks, saveat=1.0);

# Extract solution
S = sol[1, :]
I = sol[2, :]
R = sol[3, :]
t = sol.t

# plot
p = plot(t, I, label="Infected")
xlabel!(p, "Time (days)")
ylabel!(p, "Count")
title!(p, "SIR Model with Reactive Intervention")
```
