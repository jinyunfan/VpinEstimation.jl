"""
VpinEstimation.jl

A Julia package for calculating the Volume-synchronized Probability of Informed Trading (VPIN)
in high-frequency trading environments. VPIN is a real-time measure of the probability of 
informed trading that can be used for risk management and market microstructure analysis.

# Main Functions
- `vpin`: Calculate VPIN from high-frequency trading data

# References
Easley, D., López de Prado, M. M., & O'Hara, M. (2012). Flow toxicity and 
liquidity in a high-frequency world. The Review of Financial Studies, 25(5), 1457-1493.
"""
module VpinEstimation

const VERSION = v"0.1.0"
const PACKAGE_NAME = "VpinEstimation"
const AUTHOR = "fanjinyun"

using DataFrames
using CSV
using Dates
using Statistics
using Distributions
using ProgressMeter

export vpin

include("validation.jl")
include("utils.jl")
include("calculate.jl")
"""
    package_version()

Return the current version of VpinEstimation.jl package.
"""
package_version() = VERSION

"""
    package_info()

Return a dictionary with package metadata information.
"""
function package_info()
    return Dict(
        "name" => PACKAGE_NAME,
        "version" => string(VERSION),
        "author" => AUTHOR,
        "description" => "Calculate Volume-synchronized Probability of Informed Trading (VPIN)",
        "julia_compat" => "≥ 1.6.7"
    )
end

end

