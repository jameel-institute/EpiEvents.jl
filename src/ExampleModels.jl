"""
    SIRParams

A mutable struct for parameters of the SIR model.

# Fields
- `beta::Float64`: Transmission rate (contacts × probability per contact)
- `gamma::Float64`: Recovery rate (1/infectious period)

# Example
```julia
using EpiEvents

params = SIRParams(
    1.3 / 7.0,  # beta: transmission rate
    1.0 / 7.0   # gamma: recovery rate
)
```
"""
mutable struct SIRParams
    beta::Float64
    gamma::Float64
end

"""
    sir_model!(du, u, p, t)

A simple SIR (Susceptible-Infected-Recovered) compartmental model.

# Arguments
- `du::Vector`: Derivatives (filled in place)
- `u::Vector`: State vector where u[1] = S, u[2] = I, u[3] = R
- `p::SIRParams or NamedTuple`: Parameters with fields `beta` and `gamma`
- `t::Float64`: Current time

# Parameters
- `beta`: Transmission rate (contacts × probability per contact)
- `gamma`: Recovery rate (1/infectious period)

# Dynamics
- dS/dt = -β × S × I / N
- dI/dt = β × S × I / N - γ × I
- dR/dt = γ × I

where N = S + I + R is the total population.

# Example
```julia
using OrdinaryDiffEq, EpiEvents

# Initial conditions
u0 = [99900.0, 100.0, 0.0]
tspan = (0.0, 200.0)
p = SIRParams(1.3/7.0, 1.0/7.0)

prob = ODEProblem(sir_model!, u0, tspan, p)
sol = solve(prob, Tsit5())
```
"""
function sir_model!(du, u, p, t)
    S, I, R = u
    β, γ = p.beta, p.gamma

    N = S + I + R

    du[1] = -β * S * I / N          # dS/dt
    du[2] = β * S * I / N - γ * I   # dI/dt
    du[3] = γ * I                   # dR/dt
end

export SIRParams, sir_model!
