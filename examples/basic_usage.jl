# Basic Usage Example for VpinEstimation.jl

using VpinEstimation
using CSV
using DataFrames
using Dates
using Statistics

# Load sample data
data_path = joinpath(@__DIR__, "..", "test", "testdata.csv")

if isfile(data_path)
    dataset = CSV.read(data_path, DataFrame)
    println("Loaded $(nrow(dataset)) rows from testdata.csv")
else
    # Create synthetic data if test data not available
    n_points = 1000
    start_time = DateTime(2023, 1, 1, 9, 30, 0)
    
    timestamps = [start_time + Second(30 * i) for i in 0:(n_points-1)]
    prices = 100.0 .+ cumsum(randn(n_points) * 0.1)
    volumes = abs.(randn(n_points) * 1000) .+ 500
    
    dataset = DataFrame(
        timestamp = timestamps,
        price = prices,
        volume = volumes
    )
    println("Created synthetic dataset with $(nrow(dataset)) rows")
end

# Set parameters
timebarsize = 60    # 1-minute time bars
buckets = 50        # Number of volume buckets
samplength = 10     # Rolling window size

# Calculate VPIN
try
    daily_vpin, bucket_data = vpin(timebarsize, buckets, samplength, dataset)
    
    # Display results
    println("VPIN calculation completed")
    println("Days analyzed: $(nrow(daily_vpin))")
    println("Volume buckets: $(nrow(bucket_data))")
    
    if nrow(daily_vpin) > 0
        println("Mean daily VPIN: $(round(mean(daily_vpin.dvpin), digits=4))")
        println("VPIN range: $(round(minimum(daily_vpin.dvpin), digits=4)) - $(round(maximum(daily_vpin.dvpin), digits=4))")
    end
    
catch e
    println("Error: $e")
    println("Check data format: [timestamp, price, volume] with positive volumes")
end