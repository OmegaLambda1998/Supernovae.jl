using Supernovae
using Supernovae.RunModule
using Supernovae.RunModule.FilterModule
using Supernovae.RunModule.PhotometryModule
using Test
using Unitful, UnitfulAstro

@testset "Supernovae.jl" begin
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
        filter_2 = Filter(facility, instrument, passband, filter_config)
        # Make sure it crashes correctly
        @test_throws ErrorException broken_filter = Filter("A", "B", "C", filter_config)

        # Test that filter_1 and filter_2 are identical
        for field in fieldnames(Filter)
            @test getfield(filter_1, field) == getfield(filter_2, field)
        end
        rm(filter_path)

        neg_t = -10u"K"
        zero_t = 0.0u"K"
        neg_λ = -10.0u"nm"
        zero_λ = 0u"nm"

        # Ensure physically impossible inputs are caught
        @test_throws DomainError planck(neg_t, 1000.0u"nm") 
        @test_throws DomainError planck(zero_t, 1000.0u"nm") 
        @test_throws DomainError planck(1000.0u"K", neg_λ)
        @test_throws DomainError planck(1000.0u"K", zero_λ)
        @test_throws DomainError synthetic_flux(filter_1, neg_t)
        @test_throws DomainError synthetic_flux(filter_1, zero_t)

        # Ensure units are handled correctly
        a_planck = planck(1000u"K", 5000u"nm") 
        b_planck = planck(1000.0u"K", 50000.0u"Å") 
        @test a_planck |> unit(b_planck) ≈ b_planck
        @test synthetic_flux(filter_1, 1000u"K") == synthetic_flux(filter_2, 1000.0u"K")
    end

    @testset "PhotometryModule" begin
        # Load lightcurves using various methods
        default_observations = Vector{Dict{String, Any}}([
            Dict{String, Any}(
                "NAME" => "default",
                "PATH" => joinpath(@__DIR__, "observations/Default.txt"),
                "FACILITY" => "JWST",
                "INSTRUMENT" => "NIRCam",
                "PASSBAND" => "F200W",
                "UPPERLIMIT" => false
            )
        ])
        default_zeropoint = -21.0u"AB_mag"
        default_redshift = 1.0
        default_config = Dict{String, Any}(
            "FILTER_PATH" => joinpath(@__DIR__, "filters")
        )
        default_lightcurve = Lightcurve(default_observations, default_zeropoint, default_redshift, default_config)
        default_time = [o.time for o in default_lightcurve.observations]
        default_flux = [o.flux for o in default_lightcurve.observations]
        default_flux_err = [o.flux_err for o in default_lightcurve.observations]
        default_mag = [o.mag for o in default_lightcurve.observations]
        default_absmag = [o.absmag for o in default_lightcurve.observations]
        default_filter = [o.filter for o in default_lightcurve.observations]
        default_upperlimit = [o.is_upperlimit for o in default_lightcurve.observations]

        extracols_observations = Vector{Dict{String, Any}}([
            Dict{String, Any}(
                "NAME" => "extracols",
                "PATH" => joinpath(@__DIR__, "observations/ExtraCols.txt"),
                "UPPERLIMIT_TRUE" => ["True"],
                "UPPERLIMIT_FALSE" => ["False"],
                "HEADER" => Dict{String, Any}(
                    "TIME" => Dict{String, Any}(
                        "COL" => "time",
                        "UNIT" => "DEFAULT"
                    ),
                    "FLUX" => Dict{String, Any}(
                        "COL" => "flux",
                        "UNIT" => "DEFAULT"
                    ),
                    "FLUX_ERR" => Dict{String, Any}(
                        "COL" => "flux_err",
                        "UNIT" => "DEFAULT"
                    ),
                    "FACILITY" => Dict{String, Any}(
                        "COL" => "facility"
                    ),
                    "INSTRUMENT" => Dict{String, Any}(
                        "COL" => "instrument"
                    ),
                    "PASSBAND" => Dict{String, Any}(
                        "COL" => "passband"
                    ),
                    "UPPERLIMIT" => Dict{String, Any}(
                        "COL" => "upperlimit"
                    )
                )
            )
        ])
        extracols_zeropoint = -21.0u"AB_mag"
        extracols_redshift = 1.0
        extracols_config = Dict{String, Any}(
            "FILTER_PATH" => joinpath(@__DIR__, "filters")
        )
        extracols_lightcurve = Lightcurve(extracols_observations, extracols_zeropoint, extracols_redshift, extracols_config)
        extracols_time = [o.time for o in extracols_lightcurve.observations]
        extracols_flux = [o.flux for o in extracols_lightcurve.observations]
        extracols_flux_err = [o.flux_err for o in extracols_lightcurve.observations]
        extracols_filter = [o.filter for o in extracols_lightcurve.observations]
        extracols_upperlimit = [o.is_upperlimit for o in extracols_lightcurve.observations]


        named_observations = Vector{Dict{String, Any}}([
            Dict{String, Any}(
                "NAME" => "named",
                "PATH" => joinpath(@__DIR__, "observations/Named.txt"),
                "FACILITY" => "JWST",
                "INSTRUMENT" => "NIRCam",
                "PASSBAND" => "F200W",
                "UPPERLIMIT" => "flux",
                "HEADER" => Dict{String, Any}(
                    "TIME" => Dict{String, Any}(
                        "COL" => "time",
                        "UNIT" => "d"
                    ),
                    "FLUX" => Dict{String, Any}(
                        "COL" => "flux",
                        "UNIT_COL" => "flux_unit"
                    ),
                    "FLUX_ERR" => Dict{String, Any}(
                        "COL" => "flux_err",
                        "UNIT_COL" => 5
                    )
                )
            )
        ])
        named_zeropoint = -21.0u"AB_mag"
        named_redshift = 1.0
        named_config = Dict{String, Any}(
            "FILTER_PATH" => joinpath(@__DIR__, "filters")
        )
        named_lightcurve = Lightcurve(named_observations, named_zeropoint, named_redshift, named_config)
        named_time = [o.time for o in named_lightcurve.observations]
        named_flux = [o.flux for o in named_lightcurve.observations]
        named_flux_err = [o.flux_err for o in named_lightcurve.observations]
        named_filter = [o.filter for o in named_lightcurve.observations]
        named_upperlimit = [o.is_upperlimit for o in named_lightcurve.observations]

        index_observations = Vector{Dict{String, Any}}([
            Dict{String, Any}(
                "NAME" => "index",
                "PATH" => joinpath(@__DIR__, "observations/Index.txt"),
                "FACILITY" => "JWST",
                "INSTRUMENT" => "NIRCam",
                "PASSBAND" => "F200W",
                "UPPERLIMIT" => false,
                "COMMENT" => "-", # Treat comment as header
                "HEADER" => Dict{String, Any}(
                    "TIME" => Dict{String, Any}(
                        "COL" => 1,
                        "UNIT_COL" => 2 
                    ),
                    "FLUX" => Dict{String, Any}(
                        "COL" => 3,
                        "UNIT_COL" => 4
                    ),
                    "FLUX_ERR" => Dict{String, Any}(
                        "COL" => 5,
                        "UNIT_COL" => 6
                    )
                )
            )
        ])
        index_zeropoint = -21.0u"AB_mag"
        index_redshift = 1.0
        index_config = Dict{String, Any}(
            "FILTER_PATH" => joinpath(@__DIR__, "filters")
        )
        index_lightcurve = Lightcurve(index_observations, index_zeropoint, index_redshift, index_config)
        index_time = [o.time for o in index_lightcurve.observations]
        index_flux = [o.flux for o in index_lightcurve.observations]
        index_flux_err = [o.flux_err for o in index_lightcurve.observations]
        index_filter = [o.filter for o in index_lightcurve.observations]
        index_upperlimit = [o.is_upperlimit for o in index_lightcurve.observations]

        # Test that the lightcurves are identical
        @test default_time == extracols_time == named_time == index_time
        @test default_flux == extracols_flux == named_flux == index_flux
        @test default_flux_err == extracols_flux_err == named_flux_err == index_flux_err
        for field in fieldnames(Filter)
            @test getfield.(default_filter, field) == getfield.(extracols_filter, field) == getfield.(named_filter, field) == getfield.(index_filter, field)
        end
        @test default_upperlimit == extracols_upperlimit == named_upperlimit == index_upperlimit
        @test !(false in (absmag_to_mag.(default_absmag, default_redshift) .≈ default_mag))
        @test !(false in (mag_to_flux.(default_mag, default_zeropoint) ≈ default_flux))
    end
end
