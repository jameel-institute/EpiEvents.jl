# Changelog

## [Unreleased]

## [0.0.1] - 2026-04-21

- Initial implementation of core event/callback framework distilled from [Daedalus.jl](https://github.com/jameel-institute/Daedalus.jl):
- Three-level hierarchy of epidemic model events: `Trigger`, `ParamEffect`, and `Npi`;
- `Callback` generation functionality in `GenEvents.jl`; relies on OrdinaryDiffEq-compatible `CallbackSet`, using a mixture of `ContinuousCallback` for reactive triggers (zero-crossing detection on state thresholds) and `PresetTimeCallback` for timed triggers (fires at specific times);
- Flexible state extraction for reactive triggers;
- Directional comparison: Reactive triggers can activate on upward (>=, >) or downward (<, <=) state crossings;
- Parameter access: Support for both dict-like and struct-based parameter specifications;
- Basic tests added.
