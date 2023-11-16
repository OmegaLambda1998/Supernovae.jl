using Supernovae
using Supernovae.RunModule
using Supernovae.RunModule.FilterModule
using Supernovae.RunModule.PhotometryModule
using Test
using Unitful, UnitfulAstro

@testset "Supernovae.jl" begin
    # Write your tests here.
    @testset "FilterModule" begin
        facility = "JWST"
        instrument = "NIRCam"
        passband = "F200W"
        filter_config = Dict{String, Any}(
            "FILTER_PATH" => joinpath(@__DIR__, "filters")
        )
        filter_path = joinpath(filter_config["FILTER_PATH"], "$(facility)__$(instrument)__$(passband)")
        # Get the filter from svo
        filter_1 = Filter(facility, instrument, passband, filter_config)
        # Load the same filter from disk
        filter_2 = Filter(facility, instrument, passband, filter_path)
        for field in fieldnames(Filter)
            @test getfield(filter_1, field) == getfield(filter_2, field)
        end
        rm(filter_path)
        neg_t = -10u"K"
        zero_t = 0.0u"K"
        neg_λ = -10.0u"nm"
        zero_λ = 0u"nm"
        @test_throws DomainError planck(neg_t, 1000.0u"nm") 
        @test_throws DomainError planck(zero_t, 1000.0u"nm") 
        @test_throws DomainError planck(1000.0u"K", neg_λ)
        @test_throws DomainError planck(1000.0u"K", zero_λ)
        @test_throws DomainError synthetic_flux(filter_1, neg_t)
        @test_throws DomainError synthetic_flux(filter_1, zero_t)
    end
end
