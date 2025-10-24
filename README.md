# VPINEstimation.jl

[![Build Status](https://github.com/jinyunfan/VPINEstimation.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/jinyunfan/VPINEstimation.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/jinyunfan/VPINEstimation.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/jinyunfan/VPINEstimation.jl)
[![Julia](https://img.shields.io/badge/julia-v1.6%2B-blue.svg)](https://julialang.org/)

A Julia package for calculating the Volume-synchronized Probability of Informed Trading (VPIN) in high-frequency trading environments.

## What is VPIN?

VPIN measures the probability of informed trading by analyzing volume imbalances in high-frequency data. Unlike time-based measures, VPIN synchronizes on volume, making it more robust for market microstructure analysis.

## Key Features

- **Volume Synchronization**: Uses volume buckets instead of time intervals for accurate analysis
- **High-Frequency Ready**: Efficiently processes large tick-by-tick datasets
- **Real-Time Capable**: Suitable for live trading and risk management applications
- **Robust Validation**: Comprehensive input validation with informative error messages
- **Performance Optimized**: Leverages Julia's speed with type-stable implementations
- **Flexible Parameters**: Configurable time bars, buckets, and sample windows
- **Comprehensive Output**: Provides both daily and bucket-level VPIN calculations

## Installation

```julia
using Pkg
Pkg.add("VPINEstimation")
```

## Quick Start

```julia
using VPINEstimation, CSV, DataFrames

# Load trading data with columns: [timestamp, price, volume]
data = CSV.read("trading_data.csv", DataFrame)

# Calculate VPIN: 60-second bars, 50 buckets, 10-period window
daily_vpin, bucket_data = vpin(60, 50, 10, data)

# View results
println("Daily VPIN: ", daily_vpin)
```

## Parameters

- `timebarsize`: Time bar size in seconds (e.g., 60 for 1-minute bars)
- `buckets`: Number of volume buckets per day (typically 20-100)
- `samplength`: Rolling window size (must be < buckets)

## Data Format

Your input DataFrame has at least 3 columns:
1. **timestamp**: DateTime or convertible string
2. **price**: Numeric price data
3. **volume**: Positive numeric volume data

## Example with Sample Data

```julia
using VPINEstimation, DataFrames, Dates

# Create sample data
n = 1000
timestamps = [DateTime(2023,1,1,9,30,0) + Second(30*i) for i in 0:(n-1)]
prices = 100.0 .+ cumsum(randn(n) * 0.05)
volumes = abs.(randn(n) * 100) .+ 500

data = DataFrame(timestamp=timestamps, price=prices, volume=volumes)

# Calculate VPIN
daily_vpin, bucket_data = vpin(60, 50, 10, data)
println("Mean VPIN: ", round(mean(daily_vpin.dvpin), digits=4))
```

## Error Handling

The package includes comprehensive validation:

```julia
# Validate your data before calculation
VPINEstimation.validate_dataset(data)
VPINEstimation.validate_parameters(60, 50, 10)
```

## Academic Reference

**Easley, D., López de Prado, M. M., & O'Hara, M. (2012).** Flow toxicity and liquidity in a high-frequency world. *The Review of Financial Studies*, 25(5), 1457-1493.

## License

MIT License. See [LICENSE](LICENSE) file for details.

## Contributing

Contributions welcome! Please see [GitHub Issues](https://github.com/jinyunfan/VPINEstimation.jl/issues) for bug reports and feature requests.
