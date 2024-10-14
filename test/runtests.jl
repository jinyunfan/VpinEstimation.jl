using VPIN
using Test
using CSV,DataFrames

testdata = CSV.read(joinpath(@__DIR__, "testdata.csv"), DataFrame)
bucketdata = CSV.read(joinpath(@__DIR__, "expect_output/bucketdata.csv"), DataFrame)
dailyvpin = CSV.read(joinpath(@__DIR__, "expect_output/dailyvpin.csv"), DataFrame)

@testset "VPIN.jl" begin
    vpin(60, 50, 10, testdata)[1] == dailyvpin
    vpin(60, 50, 10, testdata)[2] == bucketdata
end


