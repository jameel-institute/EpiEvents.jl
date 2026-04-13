using Test
using EpiEvents

@testset "ReactiveTrigger" begin
    # Test basic construction with defaults
    rt = ReactiveTrigger(1:10, 100.0)
    @test rt.idx == 1:10
    @test rt.value == 100.0
    @test rt.combiner == sum
    @test rt.comparison == :>=

    # Test single index
    rt_single = ReactiveTrigger(5, 50.0)
    @test rt_single.idx == 5

    # Test with custom combiner
    rt_max = ReactiveTrigger(1:5, 200.0, maximum)
    @test rt_max.combiner == maximum

    # Test with custom comparison (less than)
    rt_lt = ReactiveTrigger(10:20, 50.0, sum, :<)
    @test rt_lt.comparison == :<

    # Test with greater than
    rt_gt = ReactiveTrigger(5:15, 75.0, sum, :>)
    @test rt_gt.comparison == :>

    # Test with less than or equal
    rt_lte = ReactiveTrigger(1:10, 30.0, minimum, :<=)
    @test rt_lte.comparison == :<=

    # Test invalid comparison raises error
    @test_throws AssertionError ReactiveTrigger(1:5, 100.0, sum, :!=)
end

@testset "TimeTrigger" begin
    # Test basic construction
    tt = TimeTrigger(10.0)
    @test tt.value == 10.0

    # Test with different time values
    tt_day1 = TimeTrigger(1.0)
    @test tt_day1.value == 1.0

    tt_day365 = TimeTrigger(365.0)
    @test tt_day365.value == 365.0
end

@testset "DurationTrigger" begin
    # Test basic construction with positive value
    dt = DurationTrigger(30.0)
    @test dt.value == 30.0

    # Test with different duration values
    dt_short = DurationTrigger(1.0)
    @test dt_short.value == 1.0

    dt_long = DurationTrigger(365.0)
    @test dt_long.value == 365.0

    # Test that non-positive values raise error
    @test_throws AssertionError DurationTrigger(0.0)
    @test_throws AssertionError DurationTrigger(-5.0)
end

@testset "EmptyTrigger" begin
    # Test basic construction
    et = EmptyTrigger()
    @test isa(et, EmptyTrigger)
    @test isa(et, Trigger)

    # EmptyTrigger is a singleton-like (no fields)
    et2 = EmptyTrigger()
    @test isa(et2, EmptyTrigger)
end
