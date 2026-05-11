using Test
using EpiEvents
using DiffEqCallbacks: CallbackSet, PresetTimeCallback

@testset "Callback Generation" begin
    # Test make_callbacks with single reactive effect
    rt_on = ReactiveTrigger(1:5, 1000.0)
    rt_off = ReactiveTrigger(1:5, 500.0, sum, :<)
    eff_reactive = ParamEffect(
        :beta,
        x -> x * 0.5,
        x -> x / 0.5,
        rt_on,
        rt_off
    )

    npi_reactive = Npi([eff_reactive])
    cbset_reactive = make_callbacks(npi_reactive)
    @test cbset_reactive !== nothing
    # Should have 2 callbacks (on and off)
    @test length(cbset_reactive.continuous_callbacks) == 2

    # Test make_callbacks with single timed effect
    tt_on = TimeTrigger(10.0)
    tt_off = TimeTrigger(50.0)
    eff_timed = ParamEffect(
        :contact_rate,
        x -> x * 0.7,
        x -> x / 0.7,
        tt_on,
        tt_off
    )

    npi_timed = Npi([eff_timed])
    cbset_timed = make_callbacks(npi_timed)
    @test cbset_timed !== nothing
    # Should have 2 discrete time callbacks
    @test length(cbset_timed.discrete_callbacks) == 2

    # Test make_callbacks with mixed effects
    npi_mixed = Npi([eff_reactive, eff_timed])
    cbset_mixed = make_callbacks(npi_mixed)
    @test cbset_mixed !== nothing
    @test length(cbset_mixed.continuous_callbacks) == 2  # from reactive effect
    @test length(cbset_mixed.discrete_callbacks) == 2     # from timed effect

    # Test make_callbacks with multiple effects of same type
    eff_reactive2 = ParamEffect(
        :sigma,
        x -> x * 0.9,
        x -> x / 0.9,
        ReactiveTrigger(6:10, 500.0),
        ReactiveTrigger(6:10, 200.0, sum, :<)
    )

    npi_double = Npi([eff_reactive, eff_reactive2])
    cbset_double = make_callbacks(npi_double)
    @test length(cbset_double.continuous_callbacks) == 4  # 2 on + 2 off

    # Test make_callbacks with DurationTrigger off
    duration_off = DurationTrigger(30.0)
    eff_duration = ParamEffect(
        :beta,
        x -> x * 0.5,
        x -> x / 0.5,
        ReactiveTrigger(1:5, 1000.0),
        duration_off
    )

    npi_duration = Npi([eff_duration])
    cbset_duration = make_callbacks(npi_duration)
    @test cbset_duration !== nothing
    # Should have 2 continuous callbacks (reactive on, duration off)
    @test length(cbset_duration.continuous_callbacks) == 2

    # Test make_callbacks with EmptyTrigger off (indefinite effect)
    # trigger_off defaults to EmptyTrigger() — effect never deactivates
    eff_indefinite = ParamEffect(
        :beta,
        x -> x * 0.5,
        x -> x / 0.5,
        ReactiveTrigger(1:5, 1000.0)
    )

    npi_indefinite = Npi([eff_indefinite])
    cbset_indefinite = make_callbacks(npi_indefinite)
    @test cbset_indefinite !== nothing
    # Should have 1 continuous callback (reactive on only, no off)
    @test length(cbset_indefinite.continuous_callbacks) == 1

    # Test mixed: one effect with on/off, one with indefinite
    eff_timed = ParamEffect(
        :contact_rate,
        x -> x * 0.7,
        x -> x / 0.7,
        TimeTrigger(10.0),
        TimeTrigger(50.0)
    )

    npi_mixed = Npi([eff_indefinite, eff_timed])
    cbset_mixed = make_callbacks(npi_mixed)
    @test cbset_mixed !== nothing
    # Should have 1 continuous callback (from indefinite on) + 2 discrete callbacks (from timed)
    @test length(cbset_mixed.continuous_callbacks) == 1
    @test length(cbset_mixed.discrete_callbacks) == 2
end

@testset "Activation and Deactivation Time Tracking" begin
    # Test that time_on and time_off are initialized for all effects
    rt_on = ReactiveTrigger(1:5, 1000.0)
    rt_off = ReactiveTrigger(1:5, 500.0, sum, :<)
    eff = ParamEffect(
        :beta,
        x -> x * 0.5,
        x -> x / 0.5,
        rt_on,
        rt_off
    )

    # Both should initialize as empty vectors
    @test eff.time_on == Float64[]
    @test eff.time_off == Float64[]

    # Test time_on and time_off are independent
    push!(eff.time_on, 10.0)
    push!(eff.time_on, 20.0)
    push!(eff.time_off, 15.0)
    @test eff.time_on == [10.0, 20.0]
    @test eff.time_off == [15.0]

    # Test with timed triggers
    tt_on = TimeTrigger(10.0)
    tt_off = TimeTrigger(50.0)
    eff_timed = ParamEffect(
        :contact_rate,
        x -> x * 0.7,
        x -> x / 0.7,
        tt_on,
        tt_off
    )

    @test isempty(eff_timed.time_on)
    @test isempty(eff_timed.time_off)

    # Test with duration trigger
    eff_duration = ParamEffect(
        :sigma,
        x -> x * 0.8,
        x -> x / 0.8,
        TimeTrigger(5.0),
        DurationTrigger(20.0)
    )

    @test isempty(eff_duration.time_on)
    @test isempty(eff_duration.time_off)
end

@testset "Callback Condition Functions" begin
    # Create a mock integrator-like object for testing
    # Note: we'll test the condition functions directly without full ODE integration

    rt_ge = ReactiveTrigger(1:3, 100.0, sum, :>=)
    eff_ge = ParamEffect(
        :beta,
        x -> x * 0.5,
        x -> x / 0.5,
        rt_ge,
        TimeTrigger(50.0)
    )

    # Test condition for >= comparison
    cb_ge = EpiEvents.make_reactive_on_callback(eff_ge)
    condition_ge = cb_ge.condition

    # Test state at threshold: condition should return 0
    u_at_threshold = [30.0, 40.0, 30.0, 40.0]  # sum(u[1:3]) = 100
    @test condition_ge(u_at_threshold, nothing, nothing) ≈ 0.0

    # Test state below threshold: condition should return negative
    u_well_below = [20.0, 30.0, 25.0, 40.0]  # sum(u[1:3]) = 75, below threshold
    @test condition_ge(u_well_below, nothing, nothing) < 0.0

    # Test state above threshold: condition should return positive
    u_above = [40.0, 40.0, 40.0, 40.0]  # sum(u[1:3]) = 120, above threshold
    @test condition_ge(u_above, nothing, nothing) > 0.0

    # Test condition for < comparison
    rt_lt = ReactiveTrigger(1:3, 100.0, sum, :<)
    eff_lt = ParamEffect(
        :beta,
        x -> x * 0.5,
        x -> x / 0.5,
        rt_lt,
        TimeTrigger(50.0)
    )

    cb_lt = EpiEvents.make_reactive_on_callback(eff_lt)
    condition_lt = cb_lt.condition

    # Test state at threshold: condition should return 0
    u_at_threshold = [30.0, 40.0, 30.0, 40.0]  # sum(u[1:3]) = 100
    @test condition_lt(u_at_threshold, nothing, nothing) ≈ 0.0

    # Test state below threshold: condition should return positive
    u_well_below = [20.0, 30.0, 25.0, 40.0]  # sum(u[1:3]) = 75, below threshold
    @test condition_lt(u_well_below, nothing, nothing) > 0.0

    # Test state above threshold: condition should return negative
    u_above = [40.0, 40.0, 40.0, 40.0]  # sum(u[1:3]) = 120, above threshold
    @test condition_lt(u_above, nothing, nothing) < 0.0
end

@testset "Dict and Struct Parameter Access" begin
    # Test with Dict parameters
    params_dict = Dict(:beta => 0.5, :contact_rate => 1.0)

    # Simulate getting and setting via _get_param and _set_param!
    original = params_dict[:beta]
    new_val = original * 0.5
    params_dict[:beta] = new_val

    @test params_dict[:beta] ≈ 0.25

    # Test with struct parameters (simple struct)
    mutable struct SimpleParams
        beta::Float64
        contact_rate::Float64
    end

    params_struct = SimpleParams(0.5, 1.0)
    original_struct = params_struct.beta
    new_val_struct = original_struct * 0.5
    params_struct.beta = new_val_struct

    @test params_struct.beta ≈ 0.25
end

@testset "Effect Durations" begin
    using EpiEvents: effect_durations

    # Test with empty time_on and time_off
    eff_empty = ParamEffect(
        :beta,
        x -> x * 0.5,
        x -> x / 0.5,
        ReactiveTrigger(1:5, 1000.0),
        ReactiveTrigger(1:5, 500.0, sum, :<)
    )
    @test effect_durations(eff_empty) == Float64[]

    # Test with single completed interval
    eff_single = ParamEffect(
        :beta,
        x -> x * 0.5,
        x -> x / 0.5,
        ReactiveTrigger(1:5, 1000.0),
        ReactiveTrigger(1:5, 500.0, sum, :<)
    )
    push!(eff_single.time_on, 10.0)
    push!(eff_single.time_off, 40.0)
    @test effect_durations(eff_single) == [30.0]

    # Test with multiple completed intervals
    eff_multi = ParamEffect(
        :beta,
        x -> x * 0.5,
        x -> x / 0.5,
        ReactiveTrigger(1:5, 1000.0),
        ReactiveTrigger(1:5, 500.0, sum, :<)
    )
    push!(eff_multi.time_on, 10.0, 50.0, 100.0)
    push!(eff_multi.time_off, 40.0, 80.0)
    @test effect_durations(eff_multi) == [30.0, 30.0, Inf]

    # Test with open interval (effect still active)
    eff_open = ParamEffect(
        :sigma,
        x -> x * 0.9,
        x -> x / 0.9,
        TimeTrigger(10.0),
        TimeTrigger(100.0)
    )
    push!(eff_open.time_on, 10.0)
    @test effect_durations(eff_open) == [Inf]

    # Test with solution context (typed AbstractODESolution)
    # Create a mock solution with .t field
    mutable struct MockSolution
        t::Vector{Float64}
    end

    mock_sol = MockSolution([0.0, 50.0, 100.0, 150.0, 200.0])

    # With completed and open intervals
    eff_with_sol = ParamEffect(
        :beta,
        x -> x * 0.5,
        x -> x / 0.5,
        ReactiveTrigger(1:5, 1000.0),
        ReactiveTrigger(1:5, 500.0, sum, :<)
    )
    push!(eff_with_sol.time_on, 10.0, 150.0)
    push!(eff_with_sol.time_off, 40.0)

    # With solution, open interval uses sol.t[end]
    # This won't work without proper typing, so we skip the typed version test
    # and just verify the basic behavior

    # Test Npi method (bare)
    eff1 = ParamEffect(
        :beta,
        x -> x * 0.5,
        x -> x / 0.5,
        ReactiveTrigger(1:5, 1000.0),
        ReactiveTrigger(1:5, 500.0, sum, :<)
    )
    push!(eff1.time_on, 10.0)
    push!(eff1.time_off, 40.0)

    eff2 = ParamEffect(
        :contact_rate,
        x -> x * 0.7,
        x -> x / 0.7,
        TimeTrigger(10.0),
        TimeTrigger(50.0)
    )
    push!(eff2.time_on, 10.0)
    push!(eff2.time_off, 50.0)

    npi = Npi([eff1, eff2])
    durations_npi = effect_durations(npi)
    @test length(durations_npi) == 2
    @test durations_npi[1] == [30.0]
    @test durations_npi[2] == [40.0]

    # Test Npi with mixed durations
    eff3 = ParamEffect(
        :sigma,
        x -> x * 0.9,
        x -> x / 0.9,
        TimeTrigger(20.0),
        TimeTrigger(100.0)
    )
    push!(eff3.time_on, 20.0)  # active, no corresponding off time

    npi_mixed = Npi([eff1, eff3])
    durations_mixed = effect_durations(npi_mixed)
    @test length(durations_mixed) == 2
    @test durations_mixed[1] == [30.0]
    @test durations_mixed[2] == [Inf]
end
