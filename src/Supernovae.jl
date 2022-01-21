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
export main
export Filter
export planck, flux
export Observation, Lightcurve, Supernova
export plot_lightcurve, plot_lightcurve!

function setup_global_config!(toml::Dict)
    config = get(toml, "global", Dict())
    base_path = abspath(get(config, "base_path", dirname(toml["toml_path"])))
    config["base_path"] = base_path
    output_path = joinpath(base_path, get(config, "output_path", "Output"))
    if isdir(output_path)
        @warn "$output_path already exists. Some files may be overwritten"
    else
        mkpath(output_path)
    end
    config["output_path"] = output_path
    log_file = get(config, "log_file", nothing)
    if !isnothing(log_file)
        log_file = joinpath(output_path, log_file) 
    end
    config["log_file"] = log_file
    toml["global"] = config
    return toml
end

function setup_logger(log_file::AbstractString, verbose::Bool)
    if verbose
        level = Logging.Debug
    else
        level = Logging.Info
    end
    function fmt(io, args)
        if args.level == Logging.Error
            color = :red
            bold = true
        elseif args.level == Logging.Warn
            color = :yellow
            bold = true
        elseif args.level == Logging.Info
            color = :cyan
            bold = false
        else
            color = :white
            bold = false
        end
        printstyled(io, args._module, " | ", "[", args.level, "] ", args.message, "\n"; color = color, bold = bold)
    end
    logger = TeeLogger(
        MinLevelLogger(FormatLogger(fmt, open(log_file, "w")), level),
        MinLevelLogger(FormatLogger(fmt, stdout), level)
    )
    global_logger(logger)
    @info "Logging to $log_file"
end

function main(toml::Dict, verbose::Bool)
    toml = setup_global_config!(toml)
    config = toml["global"]
    # Optionally set up logging
    log_file = config["log_file"]
    if !isnothing(log_file)
        setup_logger(log_file, verbose)
    end
    toml["data"]["base_path"] = config["base_path"]
    toml["data"]["output_path"] = config["output_path"]
    supernova = Supernova(toml["data"])
    plot_config = get(toml, "plot", nothing)
    # Plotting
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

function main(toml_path::AbstractString, verbose::Bool)
    toml = TOML.parsefile(toml_path)
    toml["toml_path"] = toml_path
    return main(toml, verbose)
end

end # module
