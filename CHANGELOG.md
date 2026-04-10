# Changelog

## [Unreleased]

## [0.0.2] - 2026-04-27

### Added

- `SIRParams`: Example parameter struct for the SIR model, with `beta` and `gamma` fields
- `sir_model!`: Exported example compartmental model
- `DurationTrigger`: New trigger type for deactivating effects based on elapsed time since activation
  - Fires when `current_time - last(activation_time) >= threshold`
  - Only valid as `trigger_off` to deactivate effects after specified duration
- `ParamEffect.time_on`: New mutable field tracking all activation timestamps (append-only history)
  - Records each activation in callbacks for use with `DurationTrigger`
  - Enables tracking of effect history and re-activations
- `ParamEffect.time_off`: New mutable field tracking all deactivation timestamps (append-only history)
  - Records each deactivation in off-callbacks (reactive, timed, and duration-based)
  - Complements `time_on` for complete activation/deactivation timeline tracking
- `make_duration_off_callback`: New callback generator for duration-based deactivation
  - Uses continuous callback with condition based on time since last activation

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
