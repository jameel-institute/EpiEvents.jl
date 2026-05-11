using Test
using EpiEvents

@testset "ParamEffect" begin
    # Test construction with reactive triggers
    rt_on = ReactiveTrigger(1:10, 1000.0)
    rt_off = ReactiveTrigger(1:10, 500.0, sum, :<)

    eff = ParamEffect(
        :beta,
        x -> x * 0.5,
        x -> x / 0.5,
        rt_on,
        rt_off
    )

    @test eff.target == :beta
    @test eff.func(100.0) == 50.0
    @test eff.reset_func(50.0) == 100.0
    @test eff.trigger_on == rt_on
    @test eff.trigger_off == rt_off
    @test eff.ison == false  # starts inactive

    # Test construction with timed triggers
    tt_on = TimeTrigger(10.0)
    tt_off = TimeTrigger(50.0)

    eff_timed = ParamEffect(
        :contact_rate,
        x -> x * 0.7,
        x -> x / 0.7,
        tt_on,
        tt_off
    )

    @test eff_timed.target == :contact_rate
    @test eff_timed.func(1.0) ≈ 0.7
    @test eff_timed.reset_func(0.7) ≈ 1.0
    @test eff_timed.ison == false

    # Test mixed triggers (reactive on, timed off)
    eff_mixed = ParamEffect(
        :sigma,
        x -> x * 0.9,
        x -> x / 0.9,
        ReactiveTrigger(5:8, 200.0),
        TimeTrigger(100.0)
    )

    @test isa(eff_mixed.trigger_on, ReactiveTrigger)
    @test isa(eff_mixed.trigger_off, TimeTrigger)

    # Test time_on field initialization
    @test eff.time_on == Float64[]
    @test isa(eff.time_on, Vector{Float64})

    # Test time_off field initialization
    @test eff.time_off == Float64[]
    @test isa(eff.time_off, Vector{Float64})

    # Test time_on with DurationTrigger
    duration_off = DurationTrigger(30.0)
    eff_duration = ParamEffect(
        :beta,
        x -> x * 0.6,
        x -> x / 0.6,
        ReactiveTrigger(1:5, 100.0),
        duration_off
    )
    @test isa(eff_duration.trigger_off, DurationTrigger)
    @test isempty(eff_duration.time_on)
    @test isempty(eff_duration.time_off)

    # Test that time_on is mutable
    push!(eff_duration.time_on, 5.0)
    @test eff_duration.time_on == [5.0]
    push!(eff_duration.time_on, 10.0)
    @test eff_duration.time_on == [5.0, 10.0]

    # Test that time_off is mutable
    push!(eff_duration.time_off, 35.0)
    @test eff_duration.time_off == [35.0]
    push!(eff_duration.time_off, 70.0)
    @test eff_duration.time_off == [35.0, 70.0]

    # Test id field initialization and keyword argument
    # Default: id should be nothing
    @test eff.id === nothing

    # With id specified
    eff_with_id = ParamEffect(
        :beta,
        x -> x * 0.5,
        x -> x / 0.5,
        ReactiveTrigger(1:5, 1000.0),
        ReactiveTrigger(1:5, 500.0, sum, :<);
        id = "intervention_1"
    )
    @test eff_with_id.id == "intervention_1"
    @test isa(eff_with_id.id, String)

    # id can be set to nothing explicitly
    eff_no_id = ParamEffect(
        :sigma,
        x -> x * 0.9,
        x -> x / 0.9,
        TimeTrigger(20.0),
        TimeTrigger(100.0);
        id = nothing
    )
    @test eff_no_id.id === nothing

    # Verify id is of correct type
    @test isa(eff_with_id.id, Union{String, Nothing})
    @test isa(eff.id, Union{String, Nothing})

    # Test optional trigger_off with EmptyTrigger default
    eff_indefinite = ParamEffect(
        :beta,
        x -> x * 0.5,
        x -> x / 0.5,
        ReactiveTrigger(1:5, 1000.0)        # trigger_off defaults to EmptyTrigger()
    )
    @test isa(eff_indefinite.trigger_off, EmptyTrigger)
    @test eff_indefinite.ison == false
    @test isempty(eff_indefinite.time_on)
    @test isempty(eff_indefinite.time_off)

    # Test explicit EmptyTrigger
    eff_explicit_empty = ParamEffect(
        :sigma,
        x -> x * 0.9,
        x -> x / 0.9,
        TimeTrigger(10.0),
        EmptyTrigger()
    )
    @test isa(eff_explicit_empty.trigger_off, EmptyTrigger)

    # Test with id and optional trigger_off
    eff_with_id_indefinite = ParamEffect(
        :contact_rate,
        x -> x * 0.7,
        x -> x / 0.7,
        TimeTrigger(5.0);
        id = "permanent_reduction"
    )
    @test isa(eff_with_id_indefinite.trigger_off, EmptyTrigger)
    @test eff_with_id_indefinite.id == "permanent_reduction"
end

@testset "ParamEffect inverse function check" begin
    tt_on = TimeTrigger(10.0)
    tt_off = TimeTrigger(50.0)

    # Test: Valid inverse functions (should not warn)
    @test_logs match_mode=:any ParamEffect(
        :beta,
        x -> x * 2.0,
        x -> x / 2.0,
        tt_on,
        tt_off
    )

    # Test: Invalid inverse functions (should warn)
    @test_logs (:warn,) ParamEffect(
        :beta,
        x -> x + 5.0,
        x -> x - 3.0,  # Wrong reset function
        tt_on,
        tt_off
    )

    # Test: Exponential transformation (valid inverse)
    @test_logs match_mode=:any ParamEffect(
        :beta,
        x -> exp(x),
        x -> log(x),
        tt_on,
        tt_off
    )

    # Test: Non-inverse functions (should warn)
    @test_logs (:warn,) ParamEffect(
        :beta,
        x -> x * 2.0,
        x -> x,  # Wrong reset - should divide by 2
        tt_on,
        tt_off
    )
end
