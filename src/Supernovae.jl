module Supernovae

# External Packages
using TOML
using LoggingExtras

# Internal Packages 
include("Filters.jl")
using .Filters
include("Photometrics.jl")
using .Photometrics
include("Data.jl")
using .Data
include("Plotting.jl")
using .Plotting

# Exports
export process_supernova 
export Filter
export planck, synthetic_flux
export Observation, Lightcurve, Supernova
export plot_lightcurve, plot_lightcurve!
export mag_to_flux, flux_to_mag
export mag_to_absmag, absmag_to_mag

function process_supernova(toml::Dict, verbose::Bool)
    paths = Dict(
        "base_path" => ("toml_path", ""),
        "output_path" => ("base_path", "Output"),
        "data_path" => ("base_path", "Data"),
        "filter_path" => ("base_path", "Filters")
    )
    setup_global!(toml, verbose, path)
    config = toml["global"]
    # Pass path's down a layer
    toml["data"]["base_path"] = config["base_path"]
    toml["data"]["output_path"] = config["output_path"]
    toml["data"]["filter_path"] = config["filter_path"]
    toml["data"]["data_path"] = config["data_path"]
    # TODO test
    supernova = Supernova(toml["data"])
    plot_config = get(toml, "plot", nothing)
    # Plotting
    # TODO test
    if !isnothing(plot_config)
        # Lightcurve plotting
        lc_config = get(plot_config, "lightcurve", nothing)
        if !isnothing(lc_config)
            @info "Plotting lightcurve"
            lc_path = get(lc_config, "path", "$(supernova.name)_lightcurve.svg")
            if !isabspath(lc_path)
                lc_path = joinpath(config["output_path"], lc_path)
            end
            lc_config["path"] = lc_path
            plot_lightcurve(supernova, lc_config)
        end
    end
    return supernova
end

function process_supernova(toml_path::AbstractString, verbose::Bool)
    toml = TOML.parsefile(toml_path)
    if !("global" in keys(toml))
        toml["global"] = Dict()
    end
    toml["global"]["toml_path"] = dirname(abspath(toml_path))
    return process_supernova(toml, verbose)
end

end # module
