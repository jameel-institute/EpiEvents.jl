using Test
using EpiEvents

@testset "Npi" begin
    # Test with single effect
    eff1 = ParamEffect(
        :beta,
        x -> x * 0.5,
        x -> x / 0.5,
        ReactiveTrigger(1:5, 1000.0),
        ReactiveTrigger(1:5, 500.0, sum, :<)
    )

    npi_single = Npi([eff1])
    @test length(npi_single.effects) == 1
    @test npi_single.effects[1] == eff1

    # Test with multiple effects
    eff2 = ParamEffect(
        :contact_rate,
        x -> x * 0.7,
        x -> x / 0.7,
        TimeTrigger(10.0),
        TimeTrigger(50.0)
    )

    npi_multi = Npi([eff1, eff2])
    @test length(npi_multi.effects) == 2
    @test npi_multi.effects[1] == eff1
    @test npi_multi.effects[2] == eff2

    # Test that empty effects list throws error
    @test_throws ArgumentError Npi(ParamEffect[])

    # Test that effects vector is mutable
    eff3 = ParamEffect(
        :sigma,
        x -> x * 0.9,
        x -> x / 0.9,
        TimeTrigger(20.0),
        TimeTrigger(100.0)
    )

    push!(npi_single.effects, eff3)
    @test length(npi_single.effects) == 2
end
