"""
Utility functions for VpinEstimation.jl

This module contains helper functions extracted from the main VPIN calculation
to improve code organization, performance, and maintainability.
"""

using DataFrames
using Dates
using Statistics
using Distributions

"""
    format_timestamps(dataset::AbstractDataFrame)

Standardize timestamp formatting in the dataset, converting string timestamps to DateTime objects.

# Arguments
- `dataset::AbstractDataFrame`: Input dataset with timestamp column as first column

# Returns
- `AbstractDataFrame`: Dataset with properly formatted DateTime timestamps

# Notes
- Modifies the dataset in-place for performance
- Handles string timestamps in "yyyy-mm-dd HH:MM:SS" format
- Skips conversion if timestamps are already DateTime objects
"""
function format_timestamps(dataset::AbstractDataFrame)
    if eltype(dataset[!, 1]) != DateTime
        dataset[!, 1] = first.(dataset[!, 1], 19)

        transform!(dataset, 1 => ByRow(x -> DateTime(x, dateformat"yyyy-mm-dd HH:MM:SS")) => names(dataset)[1])
    end
    
    return dataset
end

"""
    calculate_volume_buckets(minutebars::AbstractDataFrame, vbs::Float64, buckets::Int)

Calculate volume buckets by dividing trading data into equal volume periods.

# Arguments
- `minutebars::AbstractDataFrame`: Processed minute bar data with tbv (time bar volume) column
- `vbs::Float64`: Volume bucket size
- `buckets::Int`: Number of buckets

# Returns
- `AbstractDataFrame`: Updated minutebars with bucket assignments and volume calculations

# Notes
- Handles large volume bars by splitting them appropriately
- Optimizes memory usage through in-place operations where possible
"""
function calculate_volume_buckets(minutebars::AbstractDataFrame, vbs::Float64, buckets::Int)

    x = 10
    threshold = (1 - 1 / x) * vbs

    large_bar_mask = minutebars.tbv .> threshold
    
    if any(large_bar_mask)
        largebars = minutebars[large_bar_mask, :]
        minutebars[large_bar_mask, :tbv] .= minutebars[large_bar_mask, :tbv] .% threshold

        new_rows = DataFrame()
        for row in eachrow(largebars)
            n_rep = x * div(row.tbv, threshold)
            new_row = (interval=row.interval, dp=row.dp, tbv=threshold/x, id=row.id)
            
            for _ in 1:n_rep
                push!(new_rows, new_row)
            end
        end
        
        # Combine and sort
        minutebars = vcat(minutebars, new_rows)
        sort!(minutebars, :interval)
        minutebars.id = 1:nrow(minutebars)
    end
    
    # Calculate running volume and bucket assignments
    minutebars.runvol = cumsum(minutebars.tbv)
    minutebars.bucket = 1 .+ div.(minutebars.runvol, vbs)
    minutebars.exvol = minutebars.runvol - (minutebars.bucket .- 1) * vbs

    boundary_rows = combine(groupby(filter(row -> row.bucket != 1, minutebars), :bucket), first)
    
    if nrow(boundary_rows) > 0
        boundary_indices = findall(row -> row.id in boundary_rows.id, eachrow(minutebars))
        minutebars[boundary_indices, :tbv] .= minutebars[boundary_indices, :exvol]
        boundary_rows.tbv = boundary_rows.tbv - boundary_rows.exvol
        boundary_rows.bucket = boundary_rows.bucket .- 1

        boundary_rows = boundary_rows[!, [:interval, :dp, :tbv, :id, :runvol, :bucket, :exvol]]
        minutebars = vcat(minutebars, boundary_rows)
        sort!(minutebars, [:interval, :bucket])
    end
    
    return minutebars
end

"""
    compute_probabilities(minutebars::AbstractDataFrame, sdp::Float64)

Compute buy and sell probabilities using normal distribution CDF.

# Arguments
- `minutebars::AbstractDataFrame`: Minute bar data with dp (price difference) column
- `sdp::Float64`: Standard deviation of price differences

# Returns
- `AbstractDataFrame`: Updated minutebars with probability columns (zb, zs, bvol, svol)

# Notes
- Uses standard normal distribution for probability calculation
- Calculates both buy volume (bvol) and sell volume (svol)
- Filters out zero-volume bars for data quality
"""
function compute_probabilities(minutebars::AbstractDataFrame, sdp::Float64)
    d = Normal(0.0, 1.0)

    minutebars.zb = cdf.(d, minutebars.dp ./ sdp)
    minutebars.zs = 1.0 .- minutebars.zb
    
    minutebars.bvol = minutebars.tbv .* minutebars.zb
    minutebars.svol = minutebars.tbv .* minutebars.zs

    minutebars = minutebars[minutebars.tbv .> 0, :]
    
    return minutebars
end

"""
    create_time_intervals(dataset::AbstractDataFrame, timebarsize::Int)

Create time intervals for grouping trading data into time bars.

# Arguments
- `dataset::AbstractDataFrame`: Input dataset with timestamp column
- `timebarsize::Int`: Size of time bars in seconds

# Returns
- `Tuple{Vector{DateTime}, AbstractDataFrame}`: Time series vector and updated dataset with interval assignments

# Notes
- Optimizes memory usage by avoiding unnecessary intermediate variables
- Uses efficient time interval calculation
"""
function create_time_intervals(dataset::AbstractDataFrame, timebarsize::Int)
    time_interval = Second(timebarsize)
    start_time = minimum(dataset[!, 1])  # First column is timestamp
    end_time = maximum(dataset[!, 1]) + time_interval

    time_series = collect(start_time:time_interval:end_time)

    breaks = time_series[2:end]
    dataset.bins = map(x -> findfirst(y -> x <= y, breaks), dataset[!, 1])
    dataset.interval = time_series[dataset.bins]

    select!(dataset, Not(:bins))
    
    return time_series, dataset
end

"""
    aggregate_to_minute_bars(dataset::AbstractDataFrame)

Aggregate tick data to minute bars with price differences and volume sums.

# Arguments
- `dataset::AbstractDataFrame`: Dataset with interval, price, and volume columns

# Returns
- `Tuple{AbstractDataFrame, Float64}`: Minute bars DataFrame and standard deviation of price differences

# Notes
- Calculates price differences as last - first within each interval
- Removes missing values for data quality
- Computes standard deviation for probability calculations
"""
function aggregate_to_minute_bars(dataset::AbstractDataFrame)

    price_diff(x) = isempty(x) ? missing : last(x) - first(x)

    minutebars = combine(
        groupby(dataset, :interval),
        names(dataset)[2] => price_diff => :dp,  # Second column is price
        names(dataset)[3] => sum => :tbv         # Third column is volume
    )

    dropmissing!(minutebars)
    minutebars.id = 1:nrow(minutebars)

    sdp = std(minutebars.dp)
    
    return minutebars, sdp
end

"""
    calculate_daily_metrics(totvol::Float64, ndays::Int, buckets::Int)

Calculate daily volume metrics for VPIN calculation.

# Arguments
- `totvol::Float64`: Total volume across all data
- `ndays::Int`: Number of trading days
- `buckets::Int`: Number of volume buckets per day

# Returns
- `Float64`: Volume bucket size (VBS)

# Notes
- VBS represents the volume per bucket for equal volume division
"""
function calculate_daily_metrics(totvol::Float64, ndays::Int, buckets::Int)
    vbs = (totvol / ndays) / buckets
    return vbs
end