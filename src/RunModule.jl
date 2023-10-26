module RunModule

# External Packages

# Internal Packages
include(joinpath(@__DIR__, "FilterModule.jl"))
using .FilterModule
include(joinpath(@__DIR__, "PhotometryModule.jl"))
using .PhotometryModule
include(joinpath(@__DIR__, "SupernovaModule.jl"))
using .SupernovaModule
include(joinpath(@__DIR__, "PlotModule.jl"))
# `used` later only if needed

# Exports
export run_Supernovae
export Supernova
export Observation
export synthetic_flux
export flux_to_mag, mag_to_flux
export absmag_to_mag, mag_to_absmag

"""
    run_Supernovae(toml::Dict{String, Any})

Main entrance function for the package

# Arguments
- `toml::Dict{String, Any}`: Input toml file containing all options for the package
"""
function run_Supernovae(toml::Dict{String,Any})
    config = toml["GLOBAL"]
    supernova = Supernova(toml["DATA"], config)
    if "PLOT" in keys(toml)
        @info "Plotting"
        plot_config = toml["PLOT"]

        # Only include PlotModule if needed to save on precompilation time if we don't need to use Makie
        @debug "Loading Plotting Module"
        @eval using .PlotModule
        if "LIGHTCURVE" in keys(plot_config)
            @info "Plotting Lightcurve"
            for lightcurve_config in plot_config["LIGHTCURVE"]
                Base.@invokelatest plot_lightcurve(supernova, lightcurve_config, config)
            end
        end
    end
    return supernova
end

end
