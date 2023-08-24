module RunModule

# External Packages

# Internal Packages
include(joinpath(@__DIR__, "FilterModule.jl"))
using .FilterModule
include(joinpath(@__DIR__, "PhotometryModule.jl"))
using .PhotometryModule
include(joinpath(@__DIR__, "SupernovaModule.jl"))
using .SupernovaModule

# Exports
export run_Supernovae
export Supernova

"""
    run_Supernovae(toml::Dict{String, Any})

Main entrance function for the package

# Arguments
- `toml::Dict{String, Any}`: Input toml file containing all options for the package
"""
function run_Supernovae(toml::Dict{String,Any})
    supernova = Supernova(toml["DATA"], toml["GLOBAL"])
    if "PLOT" in keys(toml)
        plot_config = toml["PLOT"]

        # Only include PlotModule if needed to save on precompilation time if we don't need to use Makie
        include(joinpath(@__DIR__, "PlotModule.jl"))
        @eval using .PlotModule
        if "LIGHTCURVE" in keys(plot_config)
            @info "Plotting Lightcurve"
        end
    end
    return supernova
end

end
