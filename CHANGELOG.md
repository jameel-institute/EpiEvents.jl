# Changelog

## [0.0.1] - 2026-04-09

### Added
- Initial implementation of core event/callback framework distilled from Daedalus.jl
- **Trigger types**: `ReactiveTrigger` (state-based with directional comparison) and `TimeTrigger` (time-based)
- **ParamEffect**: Specifies parameter modifications with on/off triggers and transformation functions
- **Npi**: Container for collections of parameter effects
- **Callback generation**: `make_callbacks()` generates OrdinaryDiffEq-compatible `CallbackSet` from effect specifications
- **Callback types**: 
  - `ContinuousCallback` for reactive triggers (zero-crossing detection on state thresholds)
  - `PresetTimeCallback` for timed triggers (fires at specific times)
- **Flexible state extraction**: Reactive triggers support explicit indices with custom aggregator functions (sum, max, min, etc.)
- **Directional comparison**: Reactive triggers can activate on upward (>=, >) or downward (<, <=) state crossings
- **Parameter access**: Support for both dict-like and struct-based parameter specifications
- Comprehensive test suite covering triggers, effects, NPIs, and callback generation
