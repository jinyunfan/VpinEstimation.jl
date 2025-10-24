"""
Test suite for VPINEstimation.jl - Functional and Unit Tests
"""

using VPINEstimation
using Test
using CSV
using DataFrames
using Dates
using Statistics

# Load test data
testdata = CSV.read(joinpath(@__DIR__, "testdata.csv"), DataFrame)

@testset "VPINEstimation.jl Tests" begin
    
    @testset "Package Info Tests" begin
        @test VPINEstimation.package_version() == v"0.1.0"
        info = VPINEstimation.package_info()
        @test info["name"] == "VPINEstimation"
    end
    
    @testset "Input Validation Tests" begin
        # Test valid dataset
        @test VPINEstimation.validate_dataset(testdata) == true
        
        # Test invalid datasets
        empty_df = DataFrame()
        @test_throws DomainError VPINEstimation.validate_dataset(empty_df)
        
        # Wrong number of columns (less than 3)
        wrong_cols = DataFrame(a=[1,2], b=[3,4])
        @test_throws ArgumentError VPINEstimation.validate_dataset(wrong_cols)
        
        # Test parameter validation
        @test VPINEstimation.validate_parameters(60, 50, 10) == true
        @test_throws ArgumentError VPINEstimation.validate_parameters(-1, 50, 10)  # negative timebarsize
        @test_throws ArgumentError VPINEstimation.validate_parameters(60, -1, 10)  # negative buckets
        @test_throws DomainError VPINEstimation.validate_parameters(60, 10, 15)    # samplength >= buckets
    end
    
    @testset "Utility Functions Tests" begin
        # Test format_timestamps
        test_df = DataFrame(
            timestamp = ["2018-10-18 00:11:33", "2018-10-18 00:13:10"],
            price = [15.4, 15.5],
            volume = [100, 200]
        )
        formatted_df = VPINEstimation.format_timestamps(test_df)
        @test eltype(formatted_df[!, 1]) == DateTime
        
        # Test validate_timestamp_format
        timestamps = [DateTime("2018-10-18T00:11:33"), DateTime("2018-10-18T00:13:10")]
        @test VPINEstimation.validate_timestamp_format(timestamps) == true
        
        # Test calculate_daily_metrics
        vbs = VPINEstimation.calculate_daily_metrics(100000.0, 5, 50)
        @test vbs == 400.0  # (100000 / 5) / 50
    end
    
    @testset "Core VPIN Function Tests" begin
        # Test with valid parameters
        daily_vpin, bucket_data = vpin(60, 50, 10, testdata)
        
        # Check return types
        @test daily_vpin isa DataFrame
        @test bucket_data isa DataFrame
        
        # Check column names
        @test "day" in names(daily_vpin)
        @test "dvpin" in names(daily_vpin)
        @test "agg_bvol" in names(bucket_data)
        @test "agg_svol" in names(bucket_data)
        @test "vpin" in names(bucket_data)
        
        # Check data validity
        @test nrow(daily_vpin) > 0
        @test nrow(bucket_data) > 0
        @test all(x -> ismissing(x) || x >= 0, bucket_data.vpin)
        @test all(x -> x >= 0, bucket_data.agg_bvol)
        @test all(x -> x >= 0, bucket_data.agg_svol)
    end
    
    @testset "Error Handling Tests" begin
        # Test with insufficient data
        small_data = testdata[1:5, :]
        @test_throws DomainError vpin(60, 50, 10, small_data)
        
        # Test with invalid parameters
        @test_throws ArgumentError vpin(-1, 50, 10, testdata)
        @test_throws DomainError vpin(60, 5, 10, testdata)
        
        # Test with empty dataset
        empty_data = DataFrame(timestamp=DateTime[], price=Float64[], volume=Float64[])
        @test_throws DomainError vpin(60, 50, 10, empty_data)
    end
    
    @testset "Numerical Accuracy Tests" begin
        # Test with known small dataset
        simple_data = DataFrame(
            timestamp = [
                DateTime("2018-10-18T09:00:00"),
                DateTime("2018-10-18T09:01:00"),
                DateTime("2018-10-18T09:02:00"),
                DateTime("2018-10-18T09:03:00"),
                DateTime("2018-10-18T09:04:00"),
                DateTime("2018-10-18T09:05:00"),
                DateTime("2018-10-18T09:06:00"),
                DateTime("2018-10-18T09:07:00"),
                DateTime("2018-10-18T09:08:00"),
                DateTime("2018-10-18T09:09:00"),
                DateTime("2018-10-18T09:10:00")
            ],
            price = [100.0, 100.1, 100.05, 100.15, 100.2, 100.1, 100.25, 100.3, 100.2, 100.35, 100.4],
            volume = [1000.0, 1500.0, 1200.0, 1800.0, 1600.0, 1400.0, 1700.0, 1900.0, 1300.0, 2000.0, 1100.0]
        )
        
        daily_vpin, bucket_data = vpin(60, 5, 3, simple_data)
        
        # Basic sanity checks
        @test all(x -> ismissing(x) || (0 <= x <= 1), bucket_data.vpin)
        @test sum(bucket_data.agg_bvol .+ bucket_data.agg_svol) ≈ sum(simple_data.volume) atol=1e-10
    end
    
end