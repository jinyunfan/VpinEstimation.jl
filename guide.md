# VPINEstimation.jl Detailed Guide

## API Reference

### Main Function

```julia
vpin(timebarsize::Int, buckets::Int, samplength::Int, dataset::DataFrame)
```

Calculate VPIN from high-frequency trading data.

**Parameters:**
- `timebarsize`: Time bar size in seconds (1-3600)
- `buckets`: Number of volume buckets (5-1000)  
- `samplength`: Rolling window size (2 to buckets-1)
- `dataset`: DataFrame with [timestamp, price, volume] columns

**Returns:**
- `daily_vpin`: DataFrame with daily VPIN values
- `bucket_data`: DataFrame with detailed bucket-level calculations

## Data Requirements

### Input Format
```julia
DataFrame(
    timestamp = [DateTime(2023,1,1,9,30,0), ...],  # DateTime objects
    price = [100.0, 100.1, ...],                   # Numeric prices
    volume = [1000.0, 1500.0, ...]                 # Positive volumes
)
```

### Data Quality
- No missing values allowed
- Timestamps must be chronologically ordered
- Volumes must be positive
- Minimum 10 rows required

## Parameter Guidelines

### Time Bar Size
- **30-60 seconds**: High-frequency analysis
- **60-300 seconds**: Standard analysis (recommended)
- **300+ seconds**: Lower frequency, smoother signals

### Number of Buckets
- **20-50**: Standard range for most applications
- **50-100**: Higher resolution, requires more data
- Should scale with daily trading volume

### Sample Length
- **5-10**: More responsive to changes
- **10-20**: Balanced (recommended)
- **20+**: Smoother but less responsive

## Working with Real Data

```julia
using VPINEstimation, CSV, DataFrames

# Load and validate data
data = CSV.read("market_data.csv", DataFrame)
VPINEstimation.validate_dataset(data)

# Calculate VPIN
daily_vpin, bucket_data = vpin(60, 50, 10, data)

# Analyze results
println("Trading days: ", nrow(daily_vpin))
println("Mean VPIN: ", round(mean(daily_vpin.dvpin), digits=4))
println("VPIN range: ", extrema(daily_vpin.dvpin))
```

## Common Issues

### Insufficient Data
```julia
# Error: Dataset too small
# Solution: Use more data or reduce parameters
```

### Invalid Parameters
```julia
# Error: samplength >= buckets
# Solution: Ensure samplength < buckets
```

### Data Quality Issues
```julia
# Error: Missing values or negative volumes
# Solution: Clean data before calculation
```

## Mathematical Background

VPIN calculation steps:
1. Divide daily volume into equal buckets
2. Classify trades as buy/sell using price movements
3. Calculate volume imbalances per bucket
4. Apply rolling window average

**Formula:**
```
VPIN_t = (1/n) * Σ|BuyVolume_i - SellVolume_i| / VolumePerBucket
```

## Performance Notes

- **Memory usage**: ~2-3x input data size
- **Time complexity**: Linear with data size
- **Recommended**: 4GB+ RAM for large datasets
- **Typical speed**: 1K-100K rows processed in seconds