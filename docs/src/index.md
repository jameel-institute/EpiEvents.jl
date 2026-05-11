```@meta
CurrentModule = EpiEvents
```

# EpiEvents.jl

[![License:MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-0.0.3-aquamarine.svg)](https://jameel-institute.github.io/EpiEvents.jl/dev/)
[![Project Status: Concept – Minimal or no implementation has been done yet, or the repository is only intended to be a limited example, demo, or proof-of-concept.](https://www.repostatus.org/badges/latest/concept.svg)](https://www.repostatus.org/#concept)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://jameel-institute.github.io/EpiEvents.jl/dev/)
[![Build Status](https://github.com/jameel-institute/EpiEvents.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jameel-institute/EpiEvents.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/jameel-institute/EpiEvents.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/jameel-institute/EpiEvents.jl)
[![SciML Code Style](https://img.shields.io/static/v1?label=code%20style&message=SciML&color=9558b2&labelColor=389826)](https://github.com/SciML/SciMLStyle)

_EpiEvents.jl_ is a Julia package that aims to provide some commonly used functionality for events in epidemic projection models.

_EpiEvents.jl_ is developed at the [Jameel Institute](https://www.imperial.ac.uk/jameel-institute/) at Imperial College London as part of the [Jameel Institute-Kenneth C. Griffin Initiative for the Economics of Pandemic Preparedness (EPPI)](https://new.express.adobe.com/webpage/TXLBkz1sN9FI5?), in collaboration with the [RESIDE research software engineering team](https://reside-ic.github.io/about/).

## Installation

_EpiEvents.jl_ can be installed from GitHub using the Julia package manager _Pkg.jl_.

```julia
using Pkg
Pkg.add(url="git@github.com:jameel-institute/EpiEvents.jl.git")
```

## Quick start

```julia
using OrdinaryDiffEq, EpiEvents

# SIR model with a reactive intervention
params = SIRParams(1.3 / 7.0, 1.0 / 7.0)
u0 = [99_900.0, 100.0, 0.0]
prob = ODEProblem(sir_model!, u0, (0.0, 200.0), params)

# Reduce beta by 70% when infected (u[2]) exceeds 2000; lift after 30 days
effect = ParamEffect(
    :beta,
    x -> x * 0.3,
    x -> x / 0.3,
    ReactiveTrigger(2, 2000.0),
    DurationTrigger(30.0)
)

sol = solve(prob, Tsit5(), callback=make_callbacks(Npi([effect])))
```

## Related packages

- [Daedalus.jl](https://github.com/jameel-institute/Daedalus.jl): Integrated epidemic-economic model where events functionality was initially implemented, and which has been distilled into _EpiEvents.jl_.
- [DifferentialEquations.jl](https://github.com/SciML/DifferentialEquations.jl): ODE solver suite used to run epidemic models.
- [DiffEqCallbacks.jl](https://github.com/SciML/DiffEqCallbacks.jl): Callback primitives (`ContinuousCallback`, `PresetTimeCallback`, `CallbackSet`) wrapped by _EpiEvents.jl_.

## Help

To report a bug, request a feature, or just start a discussion, [please open an issue](https://github.com/jameel-institute/EpiEvents.jl/issues/new).
