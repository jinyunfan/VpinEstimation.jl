using DataFrames
using Dates
using Statistics
using Distributions

"""
    vpin(timebarsize::Int, buckets::Int, samplength::Int, dataset::AbstractDataFrame)

Calculate the Volume-synchronized Probability of Informed Trading (VPIN) metric.



# Arguments
- `timebarsize::Int`: Size of time bars in seconds (must be positive)
- `buckets::Int`: Number of volume buckets per day (must be > samplength)
- `samplength::Int`: Rolling window size for VPIN calculation (must be < buckets)
- `dataset::AbstractDataFrame`: Trading data with 3 columns: [timestamp, price, volume]

# Returns
- `Tuple{DataFrame, DataFrame}`: (daily_vpin, bucket_data)
  - `daily_vpin`: Daily aggregated VPIN values
  - `bucket_data`: Detailed bucket-level data with VPIN calculations

# Example
```julia
daily_vpin, bucket_data = vpin(60, 50, 10, trading_data)
```

"""

function vpin(timebarsize::Int, buckets::Int, samplength::Int, dataset::AbstractDataFrame)
    validate_parameters(timebarsize, buckets, samplength)
    validate_dataset(dataset)
    
    if ncol(dataset) < 3
        throw(ArgumentError("Dataset must have at least 3 columns"))
    end
    working_data = dataset[:, [1, 2, 3]]
    
    working_data[!, 2] = convert.(Float64, working_data[!, 2])
    working_data[!, 3] = convert.(Float64, working_data[!, 3])
    
    working_data = format_timestamps(working_data)
    validate_timestamp_format(working_data[!, 1])
    
    time_series, working_data = create_time_intervals(working_data, timebarsize)
    minutebars, sdp = aggregate_to_minute_bars(working_data)
    
    if nrow(minutebars) < samplength
        throw(DomainError(nrow(minutebars), "Insufficient data after time bar aggregation. Got $(nrow(minutebars)) bars, need at least $samplength"))
    end
    
    ndays::Int = length(unique(Date.(minutebars.interval)))
    if ndays == 0
        throw(DomainError(ndays, "No valid trading days found in dataset"))
    end
    
    totvol::Float64 = sum(minutebars.tbv)
    if totvol <= 0
        throw(DomainError(totvol, "Total volume must be positive, got: $totvol"))
    end
    
    vbs::Float64 = calculate_daily_metrics(totvol, ndays, buckets)
    
    if vbs < 1000
        @warn "Volume bucket size is very small ($vbs). Consider reducing the number of buckets or using more data."
    end
    
    if samplength > buckets / 2
        @warn "Sample length ($samplength) is more than half the number of buckets ($buckets). This may lead to unstable VPIN estimates."
    end
    minutebars = calculate_volume_buckets(minutebars, vbs, buckets)
    
    if sdp <= 0 || !isfinite(sdp)
        throw(DomainError(sdp, "Standard deviation of price changes is invalid: $sdp"))
    end
    
    minutebars = compute_probabilities(minutebars, sdp)
    
    if nrow(minutebars) == 0
        throw(DomainError(minutebars, "No valid data remaining after probability calculations"))
    end
    bucketdata = combine(
        groupby(minutebars, :bucket), 
        :bvol => sum => :agg_bvol, 
        :svol => sum => :agg_svol,
        :interval => first => :starttime,
        :interval => last => :endtime
    )
    
    if nrow(bucketdata) < samplength
        throw(DomainError(nrow(bucketdata), "Insufficient volume buckets created. Got $(nrow(bucketdata)), need at least $samplength"))
    end
    
    bucketdata.aoi = abs.(bucketdata.agg_bvol .- bucketdata.agg_svol)
    
    n_buckets::Int = nrow(bucketdata)
    vpin_values = Vector{Union{Float64, Missing}}(undef, n_buckets)
    cumoi = cumsum(bucketdata.aoi)
    
    for i in 1:n_buckets
        if i < samplength
            vpin_values[i] = missing
        elseif i == samplength
            vpin_values[i] = cumoi[i] / (samplength * vbs)
        else
            vpin_values[i] = (cumoi[i] - cumoi[i - samplength]) / (samplength * vbs)
        end
        
        if i >= samplength && (!isfinite(vpin_values[i]) || vpin_values[i] < 0)
            @warn "Potentially unstable VPIN value at bucket $i: $(vpin_values[i])"
        end
    end
    
    bucketdata.vpin = vpin_values
    
    bucketdata.day = Date.(bucketdata.starttime)
    dailyvpin = combine(
        groupby(bucketdata, :day),
        :vpin => (x -> mean(skipmissing(x))) => :dvpin
    )
    
    select!(bucketdata, Not(:day))
    
    return (dailyvpin, bucketdata)
end