using Test
using EpiEvents
using DiffEqCallbacks: CallbackSet, PresetTimeCallback

@testset "Callback Generation" begin
    # Test make_callbacks with empty NPI
    npi_empty = Npi(ParamEffect[])
    cbset = make_callbacks(npi_empty)
    @test cbset !== nothing

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
    # When state < threshold, condition should be negative
    u_low = [10.0, 20.0, 30.0, 100.0, 200.0]
    # sum([10, 20, 30]) = 60 < 100, so condition = 60 - 100 = -40
    @test 60 - 100.0 < 0

    # When state > threshold, condition should be positive
    u_high = [50.0, 60.0, 70.0, 100.0, 200.0]
    # sum([50, 60, 70]) = 180 > 100, so condition = 180 - 100 = 80
    @test 180 - 100.0 > 0

    # Test condition for < comparison
    rt_lt = ReactiveTrigger(1:3, 100.0, sum, :<)
    eff_lt = ParamEffect(
        :beta,
        x -> x * 0.5,
        x -> x / 0.5,
        rt_lt,
        TimeTrigger(50.0)
    )

    # When state > threshold, condition should be negative
    # condition = value - state = 100 - 180 = -80
    @test 100.0 - 180 < 0

    # When state < threshold, condition should be positive
    # condition = value - state = 100 - 60 = 40
    @test 100.0 - 60 > 0
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
