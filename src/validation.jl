"""
Input validation functions for VpinEstimation.jl
"""

using DataFrames
using Dates

"""
    validate_dataset(dataset::AbstractDataFrame)

Validate that the input dataset has the correct structure and data types for VPIN calculation.

# Arguments
- `dataset::AbstractDataFrame`: Input dataset to validate

# Throws
- `ArgumentError`: If dataset structure or types are invalid
- `DomainError`: If dataset is empty or has insufficient data

# Expected Structure
The dataset must have exactly 3 columns:
1. Column 1: timestamps (DateTime or convertible to DateTime)
2. Column 2: prices (numeric, convertible to Float64)
3. Column 3: volumes (numeric, convertible to Float64, positive values)
"""
function validate_dataset(dataset::AbstractDataFrame)
    if nrow(dataset) == 0
        throw(DomainError(dataset, "Dataset cannot be empty"))
    end
    
    if ncol(dataset) < 3
        throw(ArgumentError("Dataset must have at least 3 columns (timestamp, price, volume), got $(ncol(dataset)) columns"))
    end
    
    min_rows = 10
    if nrow(dataset) < min_rows
        throw(DomainError(dataset, "Dataset must contain at least $min_rows rows for reliable VPIN calculation, got $(nrow(dataset)) rows"))
    end
    
    timestamp_col = dataset[!, 1]
    if !all(x -> x isa Union{DateTime, AbstractString, Missing}, timestamp_col)
        throw(ArgumentError("First column (timestamp) must contain DateTime objects or convertible strings"))
    end
    
    if any(ismissing, timestamp_col)
        throw(ArgumentError("Timestamp column cannot contain missing values"))
    end
    
    price_col = dataset[!, 2]
    if !all(x -> x isa Union{Real, Missing}, price_col)
        throw(ArgumentError("Second column (price) must contain numeric values"))
    end
    
    if any(ismissing, price_col)
        throw(ArgumentError("Price column cannot contain missing values"))
    end
    
    volume_col = dataset[!, 3]
    if !all(x -> x isa Union{Real, Missing}, volume_col)
        throw(ArgumentError("Third column (volume) must contain numeric values"))
    end
    
    if any(ismissing, volume_col)
        throw(ArgumentError("Volume column cannot contain missing values"))
    end
    
    numeric_volumes = filter(!ismissing, volume_col)
    if any(x -> x <= 0, numeric_volumes)
        throw(DomainError(volume_col, "Volume values must be positive"))
    end
    
    return true
end

"""
    validate_parameters(timebarsize::Int, buckets::Int, samplength::Int)

Validate numeric parameters for VPIN calculation.

# Arguments
- `timebarsize::Int`: Size of time bars in seconds
- `buckets::Int`: Number of volume buckets
- `samplength::Int`: Sample length for VPIN calculation window

# Throws
- `ArgumentError`: If any parameter is invalid
- `DomainError`: If parameter values are outside acceptable ranges
"""
function validate_parameters(timebarsize::Int, buckets::Int, samplength::Int)
    if timebarsize <= 0
        throw(ArgumentError("Parameter 'timebarsize' must be positive, got: $timebarsize"))
    end
    
    if timebarsize > 3600
        throw(DomainError(timebarsize, "Parameter 'timebarsize' should not exceed 3600 seconds (1 hour), got: $timebarsize"))
    end
    
    if buckets <= 0
        throw(ArgumentError("Parameter 'buckets' must be positive, got: $buckets"))
    end
    
    if buckets < 5
        throw(DomainError(buckets, "Parameter 'buckets' should be at least 5 for meaningful analysis, got: $buckets"))
    end
    
    if buckets > 1000
        throw(DomainError(buckets, "Parameter 'buckets' should not exceed 1000 for computational efficiency, got: $buckets"))
    end
    
    if samplength <= 0
        throw(ArgumentError("Parameter 'samplength' must be positive, got: $samplength"))
    end
    
    if samplength >= buckets
        throw(DomainError(samplength, "Parameter 'samplength' ($samplength) must be less than 'buckets' ($buckets)"))
    end
    
    if samplength < 2
        throw(DomainError(samplength, "Parameter 'samplength' should be at least 2 for meaningful window calculation, got: $samplength"))
    end
    
    return true
end

"""
    validate_timestamp_format(timestamps::AbstractVector)

Validate timestamp format and ensure proper chronological ordering.

# Arguments
- `timestamps::AbstractVector`: Vector of timestamps to validate

# Throws
- `ArgumentError`: If timestamps are not properly formatted or ordered
- `DomainError`: If timestamp range is invalid
"""
function validate_timestamp_format(timestamps::AbstractVector)
    if length(timestamps) == 0
        throw(ArgumentError("Timestamp vector cannot be empty"))
    end
    
    if length(unique(timestamps)) != length(timestamps)
        @warn "Duplicate timestamps detected in dataset. This may affect VPIN calculation accuracy."
    end
    
    if eltype(timestamps) <: DateTime
        if !issorted(timestamps)
            throw(ArgumentError("Timestamps must be in chronological order"))
        end
        
        min_time = minimum(timestamps)
        max_time = maximum(timestamps)
        current_time = now()
        
        if min_time < DateTime(1990, 1, 1)
            throw(DomainError(min_time, "Timestamps appear to be too far in the past: $min_time"))
        end
        
        if max_time > current_time + Year(1)
            throw(DomainError(max_time, "Timestamps appear to be too far in the future: $max_time"))
        end
        
        time_span = max_time - min_time
        if time_span < Minute(1)
            throw(DomainError(time_span, "Time span of data is too short for meaningful VPIN analysis: $time_span"))
        end
    end
    
    return true
end