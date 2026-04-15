using Test
using EpiEvents

@testset "RealizedValues - Phase 1: ParamEffect" begin
    # Test helper function is_effect_active
    @testset "is_effect_active" begin
        eff = ParamEffect(
            :beta,
            x -> x * 0.5,
            x -> x / 0.5,
            TimeTrigger(10.0),
            TimeTrigger(40.0)
        )

        # Before any activation
        @test !is_effect_active(eff, 5.0)

        # Manually set activation history
        eff.time_on = [10.0]
        eff.time_off = []

        # Active period
        @test is_effect_active(eff, 10.0)  # at activation
        @test is_effect_active(eff, 25.0)  # middle of active period
        @test is_effect_active(eff, 40.0)  # exactly at deactivation threshold

        # Now deactivate
        eff.time_off = [40.0]

        # After deactivation
        @test !is_effect_active(eff, 40.0)  # at deactivation (counts as deactivated)
        @test !is_effect_active(eff, 50.0)  # after deactivation

        # Multiple cycles
        eff.time_on = [10.0, 50.0, 100.0]
        eff.time_off = [40.0, 80.0]

        # First cycle
        @test is_effect_active(eff, 15.0)   # true (activated, not yet deactivated)
        @test !is_effect_active(eff, 45.0)  # false (deactivated, not yet reactivated)

        # Second cycle
        @test is_effect_active(eff, 60.0)   # true (reactivated at 50.0, not yet deactivated again)
        @test !is_effect_active(eff, 90.0)  # false (deactivated at 80.0, not yet reactivated)

        # Third cycle
        @test is_effect_active(eff, 110.0)  # true (reactivated at 100.0, never deactivated)

        # Edge case: effect never activated
        eff.time_on = []
        eff.time_off = []
        @test !is_effect_active(eff, 100.0)
    end

    # Test realized_values for single activation/deactivation
    @testset "Single Activation/Deactivation Cycle" begin
        eff = ParamEffect(
            :beta,
            x -> x * 0.5,
            x -> x / 0.5,
            TimeTrigger(10.0),
            TimeTrigger(40.0)
        )
        eff.time_on = [10.0]
        eff.time_off = [40.0]

        times = [5.0, 15.0, 40.0, 50.0]
        realized = realized_values(eff, 1.0, times)

        @test realized[1] ≈ 1.0      # t=5: before activation
        @test realized[2] ≈ 0.5      # t=15: during active period (1.0 * 0.5)
        @test realized[3] ≈ 1.0      # t=40: at deactivation boundary
        @test realized[4] ≈ 1.0      # t=50: after deactivation
    end

    # Test realized_values with different transformation function
    @testset "Different Transformation Functions" begin
        # Test with addition instead of multiplication
        eff = ParamEffect(
            :contact_rate,
            x -> x + 0.3,
            x -> x - 0.3,
            TimeTrigger(5.0),
            TimeTrigger(15.0)
        )
        eff.time_on = [5.0]
        eff.time_off = [15.0]

        times = [3.0, 10.0, 20.0]
        realized = realized_values(eff, 1.0, times)

        @test realized[1] ≈ 1.0      # before: 1.0
        @test realized[2] ≈ 1.3      # during: 1.0 + 0.3
        @test realized[3] ≈ 1.0      # after: 1.0
    end

    # Test realized_values with multiple activation/deactivation cycles
    @testset "Multiple Activation/Deactivation Cycles" begin
        eff = ParamEffect(
            :beta,
            x -> x * 0.6,
            x -> x / 0.6,
            ReactiveTrigger(1, 1000.0),
            ReactiveTrigger(1, 500.0, sum, :<)
        )
        eff.time_on = [10.0, 50.0, 100.0]
        eff.time_off = [40.0, 80.0]

        times = [5.0, 15.0, 45.0, 60.0, 85.0, 110.0]
        realized = realized_values(eff, 10.0, times)

        @test realized[1] ≈ 10.0     # t=5: before any activation
        @test realized[2] ≈ 6.0      # t=15: first activation (10.0 * 0.6)
        @test realized[3] ≈ 10.0     # t=45: after first deactivation
        @test realized[4] ≈ 6.0      # t=60: second activation
        @test realized[5] ≈ 10.0     # t=85: after second deactivation
        @test realized[6] ≈ 6.0      # t=110: third activation (ongoing)
    end

    # Test realized_values with indefinite effect (no deactivation)
    @testset "Indefinite Effect (EmptyTrigger)" begin
        eff = ParamEffect(
            :beta,
            x -> x * 0.4,
            x -> x / 0.4,
            TimeTrigger(20.0)
            # trigger_off defaults to EmptyTrigger (never deactivates)
        )
        eff.time_on = [20.0]
        eff.time_off = []  # never deactivated

        times = [10.0, 20.0, 100.0]
        realized = realized_values(eff, 5.0, times)

        @test realized[1] ≈ 5.0      # before activation
        @test realized[2] ≈ 2.0      # at activation (5.0 * 0.4)
        @test realized[3] ≈ 2.0      # long after (stays at 2.0)
    end

    # Test realized_values with effect that never activates
    @testset "Effect Never Activates" begin
        eff = ParamEffect(
            :beta,
            x -> x * 0.5,
            x -> x / 0.5,
            ReactiveTrigger(1, 10000.0),  # threshold never reached in simulation
            TimeTrigger(100.0)
        )
        eff.time_on = []   # no activations
        eff.time_off = []

        times = [0.0, 50.0, 100.0, 150.0]
        realized = realized_values(eff, 2.5, times)

        @test all(realized .≈ 2.5)   # always original value
    end

    # Test realized_values with dense time sampling
    @testset "Dense Time Sampling" begin
        eff = ParamEffect(
            :gamma,
            x -> x * 0.7,
            x -> x / 0.7,
            TimeTrigger(30.0),
            TimeTrigger(70.0)
        )
        eff.time_on = [30.0]
        eff.time_off = [70.0]

        # Fine time grid
        times = collect(0.0:5.0:100.0)
        realized = realized_values(eff, 1.0, times)

        # Check key transitions
        @test realized[1] ≈ 1.0    # t=0
        @test realized[7] ≈ 0.7    # t=30 (boundary, depends on interpretation)
        @test realized[15] ≈ 1.0   # t=70 (boundary)
        @test realized[21] ≈ 1.0   # t=100
    end

    # Test realized_values with very large parameter values
    @testset "Large Parameter Values" begin
        eff = ParamEffect(
            :beta,
            x -> x * 0.1,
            x -> x / 0.1,
            TimeTrigger(5.0),
            TimeTrigger(10.0)
        )
        eff.time_on = [5.0]
        eff.time_off = [10.0]

        times = [0.0, 7.5, 15.0]
        realized = realized_values(eff, 1e6, times)

        @test realized[1] ≈ 1e6       # before
        @test realized[2] ≈ 1e5       # during (1e6 * 0.1)
        @test realized[3] ≈ 1e6       # after
    end

    # Test realized_values with small parameter values
    @testset "Small Parameter Values" begin
        eff = ParamEffect(
            :sigma,
            x -> x * 2.0,
            x -> x / 2.0,
            TimeTrigger(1.0),
            TimeTrigger(2.0)
        )
        eff.time_on = [1.0]
        eff.time_off = [2.0]

        times = [0.5, 1.5, 2.5]
        realized = realized_values(eff, 0.001, times)

        @test realized[1] ≈ 0.001     # before
        @test realized[2] ≈ 0.002     # during (0.001 * 2.0)
        @test realized[3] ≈ 0.001     # after
    end

    # Test realized_values with negative parameter values (if applicable)
    @testset "Negative Parameter Values" begin
        eff = ParamEffect(
            :adjustment,
            x -> -x,  # flip sign
            x -> -x,  # flip back
            TimeTrigger(10.0),
            TimeTrigger(20.0)
        )
        eff.time_on = [10.0]
        eff.time_off = [20.0]

        times = [5.0, 15.0, 25.0]
        realized = realized_values(eff, -2.5, times)

        @test realized[1] ≈ -2.5      # before
        @test realized[2] ≈ 2.5       # during (-(-2.5) = 2.5)
        @test realized[3] ≈ -2.5      # after
    end

    # Test realized_values return type and structure
    @testset "Return Type and Structure" begin
        eff = ParamEffect(
            :beta,
            x -> x * 0.5,
            x -> x / 0.5,
            TimeTrigger(10.0),
            TimeTrigger(20.0)
        )
        eff.time_on = [10.0]
        eff.time_off = [20.0]

        times = [5.0, 15.0, 25.0]
        realized = realized_values(eff, 1.0, times)

        @test isa(realized, Vector)
        @test eltype(realized) <: Real
        @test length(realized) == length(times)
    end

    # Test with activation times at exact time points
    @testset "Activation at Exact Time Points" begin
        eff = ParamEffect(
            :beta,
            x -> x * 0.5,
            x -> x / 0.5,
            TimeTrigger(10.0),
            TimeTrigger(20.0)
        )
        eff.time_on = [10.0]
        eff.time_off = [20.0]

        # Include exact activation/deactivation times
        times = [10.0, 20.0]
        realized = realized_values(eff, 1.0, times)

        @test realized[1] ≈ 0.5   # at activation
        @test realized[2] ≈ 1.0   # at deactivation
    end

    # Test with unsorted time array
    @testset "Unsorted Time Array" begin
        eff = ParamEffect(
            :beta,
            x -> x * 0.5,
            x -> x / 0.5,
            TimeTrigger(10.0),
            TimeTrigger(40.0)
        )
        eff.time_on = [10.0]
        eff.time_off = [40.0]

        times = [50.0, 5.0, 25.0, 15.0]  # unsorted
        realized = realized_values(eff, 1.0, times)

        @test realized[1] ≈ 1.0      # t=50
        @test realized[2] ≈ 1.0      # t=5
        @test realized[3] ≈ 0.5      # t=25
        @test realized[4] ≈ 0.5      # t=15
    end
end

@testset "RealizedValues - Phase 2: Npi Aggregation" begin
    # Helper to create a mock ODE solution
    function mock_solution(times::Vector{Float64})
        return (t=times, tspan=(times[1], times[end]))
    end

    # Test single parameter, single effect
    @testset "Single Parameter, Single Effect" begin
        eff = ParamEffect(
            :beta,
            x -> x * 0.5,
            x -> x / 0.5,
            TimeTrigger(10.0),
            TimeTrigger(40.0)
        )
        eff.time_on = [10.0]
        eff.time_off = [40.0]

        npi = Npi([eff])
        params = Dict(:beta => 1.0)
        times = [5.0, 15.0, 50.0]
        sol = mock_solution(times)

        realized = realized_values(npi, params, sol)

        @test haskey(realized, :beta)
        @test realized[:beta] ≈ [1.0, 0.5, 1.0]
    end

    # Test multiple parameters, non-overlapping effects
    @testset "Multiple Parameters, Non-Overlapping Effects" begin
        eff_beta = ParamEffect(
            :beta,
            x -> x * 0.5,
            x -> x / 0.5,
            TimeTrigger(10.0),
            TimeTrigger(40.0)
        )
        eff_beta.time_on = [10.0]
        eff_beta.time_off = [40.0]

        eff_gamma = ParamEffect(
            :gamma,
            x -> x * 0.8,
            x -> x / 0.8,
            TimeTrigger(50.0),
            TimeTrigger(80.0)
        )
        eff_gamma.time_on = [50.0]
        eff_gamma.time_off = [80.0]

        npi = Npi([eff_beta, eff_gamma])
        params = Dict(:beta => 1.0, :gamma => 2.0)
        times = [5.0, 20.0, 55.0, 90.0]
        sol = mock_solution(times)

        realized = realized_values(npi, params, sol)

        @test realized[:beta] ≈ [1.0, 0.5, 1.0, 1.0]
        @test realized[:gamma] ≈ [2.0, 2.0, 1.6, 2.0]  # 2.0 * 0.8 = 1.6
    end

    # Test multiple effects on same parameter, sequential activation
    @testset "Multiple Effects, Same Parameter, Sequential" begin
        # First effect: activate at 10, deactivate at 40
        eff1 = ParamEffect(
            :beta,
            x -> x * 0.5,
            x -> x / 0.5,
            TimeTrigger(10.0),
            TimeTrigger(40.0)
        )
        eff1.time_on = [10.0]
        eff1.time_off = [40.0]

        # Second effect: activate at 50, deactivate at 80
        eff2 = ParamEffect(
            :beta,
            x -> x * 0.3,
            x -> x / 0.3,
            TimeTrigger(50.0),
            TimeTrigger(80.0)
        )
        eff2.time_on = [50.0]
        eff2.time_off = [80.0]

        npi = Npi([eff1, eff2])
        params = Dict(:beta => 1.0)
        times = [5.0, 25.0, 60.0, 90.0]
        sol = mock_solution(times)

        realized = realized_values(npi, params, sol)

        @test realized[:beta][1] ≈ 1.0      # t=5: no effect
        @test realized[:beta][2] ≈ 0.5      # t=25: eff1 active
        @test realized[:beta][3] ≈ 0.3      # t=60: eff2 active (eff1 deactivated)
        @test realized[:beta][4] ≈ 1.0      # t=90: both deactivated
    end

    # Test multiple effects on same parameter, overlapping activation
    @testset "Multiple Effects, Same Parameter, Overlapping" begin
        # First effect: activate at 10, deactivate at 50
        eff1 = ParamEffect(
            :beta,
            x -> x * 0.5,
            x -> x / 0.5,
            TimeTrigger(10.0),
            TimeTrigger(50.0)
        )
        eff1.time_on = [10.0]
        eff1.time_off = [50.0]

        # Second effect: activate at 30, deactivate at 70
        eff2 = ParamEffect(
            :beta,
            x -> x * 0.6,
            x -> x / 0.6,
            TimeTrigger(30.0),
            TimeTrigger(70.0)
        )
        eff2.time_on = [30.0]
        eff2.time_off = [70.0]

        npi = Npi([eff1, eff2])
        params = Dict(:beta => 1.0)
        times = [5.0, 20.0, 40.0, 60.0, 80.0]
        sol = mock_solution(times)

        realized = realized_values(npi, params, sol)

        @test realized[:beta][1] ≈ 1.0      # t=5: neither active
        @test realized[:beta][2] ≈ 0.5      # t=20: eff1 active (1.0 * 0.5)
        @test realized[:beta][3] ≈ 0.3      # t=40: both active, eff1 then eff2 (1.0 * 0.5 * 0.6)
        @test realized[:beta][4] ≈ 0.6      # t=60: only eff2 active (1.0 * 0.6)
        @test realized[:beta][5] ≈ 1.0      # t=80: neither active
    end

    # Test with NamedTuple parameters
    @testset "NamedTuple Parameters" begin
        eff = ParamEffect(
            :beta,
            x -> x * 0.5,
            x -> x / 0.5,
            TimeTrigger(10.0),
            TimeTrigger(40.0)
        )
        eff.time_on = [10.0]
        eff.time_off = [40.0]

        npi = Npi([eff])
        params = (beta=1.0, gamma=2.0)  # NamedTuple
        times = [5.0, 20.0, 50.0]
        sol = mock_solution(times)

        realized = realized_values(npi, params, sol)

        @test realized[:beta] ≈ [1.0, 0.5, 1.0]
        # gamma not targeted, so not in result
        @test !haskey(realized, :gamma)
    end

    # Test effect that never activates
    @testset "Effect Never Activates" begin
        eff1 = ParamEffect(
            :beta,
            x -> x * 0.5,
            x -> x / 0.5,
            ReactiveTrigger(1, 10000.0),  # threshold never reached
            TimeTrigger(100.0)
        )
        eff1.time_on = []
        eff1.time_off = []

        eff2 = ParamEffect(
            :beta,
            x -> x * 0.3,
            x -> x / 0.3,
            TimeTrigger(20.0),
            TimeTrigger(80.0)
        )
        eff2.time_on = [20.0]
        eff2.time_off = [80.0]

        npi = Npi([eff1, eff2])
        params = Dict(:beta => 1.0)
        times = [10.0, 50.0, 90.0]
        sol = mock_solution(times)

        realized = realized_values(npi, params, sol)

        @test realized[:beta][1] ≈ 1.0      # t=10: neither active
        @test realized[:beta][2] ≈ 0.3      # t=50: only eff2 active
        @test realized[:beta][3] ≈ 1.0      # t=90: neither active
    end

    # Test indefinite effect (EmptyTrigger)
    @testset "Indefinite Effect with EmptyTrigger" begin
        eff1 = ParamEffect(
            :beta,
            x -> x * 0.5,
            x -> x / 0.5,
            TimeTrigger(10.0)
            # trigger_off defaults to EmptyTrigger
        )
        eff1.time_on = [10.0]
        eff1.time_off = []  # never deactivates

        eff2 = ParamEffect(
            :beta,
            x -> x * 0.8,
            x -> x / 0.8,
            TimeTrigger(30.0),
            TimeTrigger(70.0)
        )
        eff2.time_on = [30.0]
        eff2.time_off = [70.0]

        npi = Npi([eff1, eff2])
        params = Dict(:beta => 1.0)
        times = [5.0, 20.0, 50.0, 80.0]
        sol = mock_solution(times)

        realized = realized_values(npi, params, sol)

        @test realized[:beta][1] ≈ 1.0      # t=5: neither active
        @test realized[:beta][2] ≈ 0.5      # t=20: only eff1 active (indefinite)
        @test realized[:beta][3] ≈ 0.4      # t=50: both active (1.0 * 0.5 * 0.8)
        @test realized[:beta][4] ≈ 0.5      # t=80: only eff1 active (eff2 deactivated)
    end

    # Test empty NPI (no effects)
    @testset "Empty NPI" begin
        npi = Npi(ParamEffect[])
        params = Dict(:beta => 1.0, :gamma => 2.0)
        times = [0.0, 10.0, 20.0]
        sol = mock_solution(times)

        realized = realized_values(npi, params, sol)

        @test isempty(realized)  # no parameters have effects
    end

    # Test multiple cycles on same parameter
    @testset "Multiple Cycles, Same Parameter" begin
        # Effect with 2 activation/deactivation cycles
        eff = ParamEffect(
            :beta,
            x -> x * 0.5,
            x -> x / 0.5,
            TimeTrigger(10.0),
            TimeTrigger(40.0)
        )
        eff.time_on = [10.0, 50.0]
        eff.time_off = [40.0, 80.0]

        npi = Npi([eff])
        params = Dict(:beta => 1.0)
        times = [5.0, 20.0, 45.0, 60.0, 90.0]
        sol = mock_solution(times)

        realized = realized_values(npi, params, sol)

        @test realized[:beta][1] ≈ 1.0      # t=5: before first cycle
        @test realized[:beta][2] ≈ 0.5      # t=20: first cycle active
        @test realized[:beta][3] ≈ 1.0      # t=45: between cycles
        @test realized[:beta][4] ≈ 0.5      # t=60: second cycle active
        @test realized[:beta][5] ≈ 1.0      # t=90: after all cycles
    end

    # Test three effects on same parameter, different ordering
    @testset "Three Effects, Different Activation Orders" begin
        # Three effects with different activation times
        eff_a = ParamEffect(:beta, x -> x * 0.5, x -> x / 0.5, TimeTrigger(20.0), TimeTrigger(100.0))
        eff_a.time_on = [20.0]
        eff_a.time_off = [100.0]

        eff_b = ParamEffect(:beta, x -> x * 0.6, x -> x / 0.6, TimeTrigger(10.0), TimeTrigger(100.0))
        eff_b.time_on = [10.0]
        eff_b.time_off = [100.0]

        eff_c = ParamEffect(:beta, x -> x * 0.8, x -> x / 0.8, TimeTrigger(30.0), TimeTrigger(100.0))
        eff_c.time_on = [30.0]
        eff_c.time_off = [100.0]

        npi = Npi([eff_a, eff_b, eff_c])
        params = Dict(:beta => 1.0)
        times = [5.0, 15.0, 25.0, 35.0]
        sol = mock_solution(times)

        realized = realized_values(npi, params, sol)

        @test realized[:beta][1] ≈ 1.0      # t=5: none active
        @test realized[:beta][2] ≈ 0.6      # t=15: only eff_b active (first by activation time)
        @test realized[:beta][3] ≈ 0.3      # t=25: eff_b and eff_a (1.0 * 0.6 * 0.5)
        @test realized[:beta][4] ≈ 0.24     # t=35: all three (1.0 * 0.6 * 0.5 * 0.8)
    end

    # Test with addition-based effects (not just multiplication)
    @testset "Non-Multiplicative Effects" begin
        eff1 = ParamEffect(
            :sigma,
            x -> x + 0.5,
            x -> x - 0.5,
            TimeTrigger(10.0),
            TimeTrigger(40.0)
        )
        eff1.time_on = [10.0]
        eff1.time_off = [40.0]

        eff2 = ParamEffect(
            :sigma,
            x -> x + 0.3,
            x -> x - 0.3,
            TimeTrigger(20.0),
            TimeTrigger(50.0)
        )
        eff2.time_on = [20.0]
        eff2.time_off = [50.0]

        npi = Npi([eff1, eff2])
        params = Dict(:sigma => 0.1)
        times = [5.0, 15.0, 30.0, 45.0, 60.0]
        sol = mock_solution(times)

        realized = realized_values(npi, params, sol)

        @test realized[:sigma][1] ≈ 0.1      # t=5: none active
        @test realized[:sigma][2] ≈ 0.6      # t=15: eff1 active (0.1 + 0.5)
        @test realized[:sigma][3] ≈ 0.9      # t=30: both active (0.1 + 0.5 + 0.3)
        @test realized[:sigma][4] ≈ 0.4      # t=45: only eff2 active (0.1 + 0.3)
        @test realized[:sigma][5] ≈ 0.1      # t=60: none active
    end

    # Test return type and structure
    @testset "Return Type and Structure" begin
        eff = ParamEffect(
            :beta,
            x -> x * 0.5,
            x -> x / 0.5,
            TimeTrigger(10.0),
            TimeTrigger(40.0)
        )
        eff.time_on = [10.0]
        eff.time_off = [40.0]

        npi = Npi([eff])
        params = Dict(:beta => 1.0)
        times = [5.0, 15.0, 25.0]
        sol = mock_solution(times)

        realized = realized_values(npi, params, sol)

        @test isa(realized, Dict)
        @test all(v isa Vector{Float64} for v in values(realized))
        @test all(length(v) == length(times) for v in values(realized))
    end
end
