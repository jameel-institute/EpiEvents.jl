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

    # Test mutable ison flag
    eff.ison = true
    @test eff.ison == true
    eff.ison = false
    @test eff.ison == false
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
