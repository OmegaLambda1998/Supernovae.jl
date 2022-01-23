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
    # Base path is where everything relative will be relative to
    # Defaults to the directory containing the toml path
    # Can be relative (to the toml path) or absolute
    base_path = get(config, "base_path", nothing)
    if isnothing(base_path)
        base_path = dirname(toml["toml_path"])
    elseif !isabspath(base_path)
        base_path = joinpath(dirname(toml["toml_path"]), base_path)
    end
    base_path = abspath(base_path)
    config["base_path"] = base_path
    # Output path is where all output (figures) will be placed
    # Defaults to base_path / Output
    # Can be relative (to base_path) or absolute
    output_path = get(config, "output_path", nothing)
    if isnothing(output_path)
        output_path = joinpath(base_path, "Output")
    elseif !isabspath(output_path)
        output_path = joinpath(base_path, output_path)
    end
    config["output_path"] = output_path
    # Data path is where all supernovae data (both photometric and spectroscopic) will be stored
    # Default to base_path / Data
    # Can be relatvie (to base_path) or absolute
    data_path = get(config, "data", nothing)
    if isnothing(data_path)
        data_path = joinpath(base_path, "Data")
    elseif !isabspath(data_path)
        data_path = joinpath(base_path, data_path)
    end
    config["data_path"] = data_path
    # Filter path is where all filter data will be placed. This is seperate from the data path so filters can be shared between supernovae
    # Defaults to base_path / Filters
    # Can be relative (to base_path) or absolute
    filter_path = get(config, "filter_path", nothing)
    if isnothing(filter_path)
        filter_path = joinpath(base_path, "Filters")
    elseif !isabspath(filter_path)
        filter_path = joinpath(base_path, filter_path)
    end
    config["filter_path"] = filter_path
    # Logging sets whether or not to setup and use Supernovae's logging
    logging = get(config, "logging", false)
    config["logging"] = logging
    # Log file is the name of the log file. This will only work if logging is true
    # Defaults to output_path / log.txt
    # Can only be relative to output_path
    log_file = get(config, "log_file", nothing)
    if !isnothing(log_file)
        log_file = joinpath(output_path, log_file) 
        if !logging
            @warn "Logging set to false, so log file $log_file will not be written"
        end
    end
    config["log_file"] = log_file
    toml["global"] = config
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
    setup_global_config!(toml)
    config = toml["global"]
    # Optionally set up logging
    if config["logging"]
        setup_logger(config["log_file"], verbose)
    end
    # Ensure all path's exist
    if !isdir(config["base_path"])
        mkpath(config["base_path"])
    end
    if !isdir(config["output_path"])
        mkpath(config["output_path"])
    end
    if !isdir(config["filter_path"])
        mkpath(config["filter_path"])
    end
    # Pass path's down a layer
    toml["data"]["base_path"] = config["base_path"]
    toml["data"]["output_path"] = config["output_path"]
    toml["data"]["filter_path"] = config["filter_path"]
    toml["data"]["data_path"] = config["data_path"]
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
    toml["toml_path"] = abspath(toml_path)
    return main(toml, verbose)
end

end # module
