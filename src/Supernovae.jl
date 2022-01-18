module Supernovae

# External packages
using TOML
using ArgParse
using Unitful, UnitfulAstro
using CairoMakie
CairoMakie.activate!(type = "svg")

# Exports
export Supernova
export Observation
export plot, plot!

# Fix for unknown unit context
function Unitful.uparse(str)
    try
        uparse(str, unit_context=Unitful)
    catch
        uparse(str, unit_context=UnitfulAstro)
    end
end

# Internal files
include("Filters.jl")
using .Filters

# Data Definitions

mutable struct Observation
    name :: AbstractString # Human readable name
    time :: typeof(1.0u"d") # Default unit of MJD (Days)
    flux :: typeof(1.0u"Jy") # Default unit of Janksy
    flux_err :: typeof(1.0u"Jy") # Default unit of Janksy
    filter :: Filter
end

mutable struct Supernova
    name :: AbstractString # Human readable name
    redshift :: Real # Unitless
    distance_modulus :: Real # Unitless
    lightcurve :: Vector{Observation}
end

# Read in a supernova object from a toml dictionary
function Supernova(toml::Dict)
    data = toml["data"]
    name = data["name"]
    redshift = data["redshift"]
    distance_modulus = data["distance_modulus"]
    max_flux_err = nothing
    max_flux_err_val = get(data, "max_flux_err", nothing)
    if !isnothing(max_flux_err_val)
        max_flux_error_unit = get(data, "max_flux_err_unit", nothing)
        if !isnothing(max_flux_error_unit)
            max_flux_err = max_flux_err_val * uparse(max_flux_error_unit)
        end
    end
    lightcurve = Observation[]
    for observation in get(data, "observations", [])
        obs_name = observation["name"]
        obs_path = observation["path"]
        println("Reading $obs_path")
        facility = get(observation, "facility", nothing)
        instrument = get(observation, "instrument", nothing)
        filter_name = get(observation, "filter", nothing)
        delimiter = get(observation, "delimiter", ",")
        comment = get(observation, "comment", "#")
        obs_file = open(obs_path, "r") do io
            return readlines(io)
        end
        if "header" in keys(observation)
            header_keys = observation["header"]
            if typeof(header_keys["time"]["col"]) <: AbstractString
                println("Detected string based header")
                header = [h for h in split(obs_file[1], delimiter) if h != ""]
                time_col = findfirst(f -> header_keys["time"]["col"] == f, header)
                time_unit = header_keys["time"]["unit"]
                flux_col = findfirst(f -> header_keys["flux"]["col"] == f, header)
                flux_unit = header_keys["flux"]["unit"]
                flux_err_col = findfirst(f -> header_keys["flux_err"]["col"] == f, header)
                flux_err_unit = header_keys["flux_err"]["unit"]
                if isnothing(facility)
                    facility_col = findfirst(f -> header_keys["facility"]["col"] == f, header)
                else
                    facility_col = nothing
                end
                if isnothing(instrument)
                    instrument_col = findfirst(f -> header_keys["instrument"]["col"] == f, header)
                else
                    instrument_col = nothing
                end

                if isnothing(filter_name)
                    filter_col = findfirst(f -> header_keys["filter"]["col"] == f, header)
                else
                    filter_col = nothing
                end
                obs_file = obs_file[2:end] # Remove header
            else
                println("Detected index based header")
                time_col = header_keys["time"]["col"]
                time_unit = header_keys["time"]["unit"]
                flux_col = header_keys["flux"]["col"]
                flux_unit = header_keys["flux"]["unit"]
                flux_err_col = header_keys["flux_err"]["col"]
                flux_err_unit = header_keys["flux_err"]["unit"]
                if isnothing(facility)
                    facility_col = header_keys["facility"]["col"]
                else
                    facility_col = nothing
                end
                if isnothing(instrument)
                    instrument_col = header_keys["instrument"]["col"]
                else
                    instrument_col = nothing
                end
                if isnothing(filter_name)
                    filter_col = header_keys["filter"]["col"]
                else
                    filter_col = nothing
                end
            end
            # Assumes no header
        else
            println("No header specified, using default header")
            header = [h for h in split(obs_file[1], delimiter) if h != ""]
            time_col = findfirst(f -> occursin("time[", f), header)
            time_unit = "$(header[time_col][6:end-1])"
            flux_col = findfirst(f -> occursin("flux[", f), header)
            flux_unit = "$(header[flux_col][6:end-1])"
            flux_err_col = findfirst(f -> occursin("flux_err[", f), header)
            flux_err_unit = "$(header[flux_err_col][10:end-1])"
            if isnothing(facility)
                facility_col = findfirst(f -> "facility" in f, header)
            else
                facility_col = nothing
            end
            if isnothing(instrument)
                instrument_col = findfirst(f -> "instrument" in f, header)
            else
                instrument_col = nothing
            end
            if isnothing(filter_name)
                filter_col = findfirst(f -> "filter" in f, header)
            else
                filter_col = nothing
            end
            obs_file = obs_file[2:end] # Remove header
        end
        flux_offset_val = get(observation, "flux_offset", 0)
        flux_offset_unit = uparse(get(observation, "flux_offset_unit", flux_unit))
        flux_offset = flux_offset_val * flux_offset_unit
        for line in obs_file
            if occursin(comment, line)
                continue
            end
            line = [l for l in split(line, delimiter) if l != ""]
            time = parse(Float64, line[time_col]) * uparse(time_unit)
            flux = parse(Float64, line[flux_col]) * uparse(flux_unit)
            flux += flux_offset
            flux_err = parse(Float64, line[flux_err_col]) * uparse(flux_err_unit)
            if !isnothing(max_flux_err)
                if flux_err > max_flux_err
                    continue
                end
            end
            if !isnothing(facility_col)
                facility = line[facility_col]
            end
            if !isnothing(instrument_col)
                instrument = line[instrument_col]
            end
            if !isnothing(filter_col)
                filter_name = line[filter_col]
            end
            filter = Filter(facility, instrument, filter_name)
            obs = Observation(obs_name, time, flux, flux_err, filter)
            push!(lightcurve, obs)
        end
    end
    # Setting time relative to peak if requested
    peak_time = get(toml["data"], "peak_time", nothing)
    if !isnothing(peak_time)
        if peak_time == true
            max_obs = lightcurve[1]
            for obs in lightcurve
                if obs.flux > max_obs.flux
                    max_obs = obs
                end
            end
            peak_time = max_obs.time
        else
            peak_time_unit = uparse(toml["data"], "peak_time_unit", "d")
            peak_time = peak_time * peak_time_unit
        end
        for obs in lightcurve
            obs.time -= peak_time
        end
    end
    supernova = Supernova(name, redshift, distance_modulus, lightcurve)
    plot_config = get(toml, "plot", Dict())
    lightcurve_plot_path = get(plot_config, "lightcurve_plot_path", nothing)
    if !isnothing(lightcurve_plot_path)
        println("Plotting $(supernova.name)")
        plot(supernova, plot_config, joinpath(lightcurve_plot_path, "$(toml["data"]["name"]).svg"))
    end
    return supernova
end

# Plotting functions
function plot!(fig, ax, supernova::Supernova, plot_config::Dict)
    instruments = String[]
    filters = String[]
    time = Dict()
    flux = Dict()
    flux_err = Dict()
    legend_plots = MarkerElement[]
    legend_names = String[]
    units = get(plot_config, "unit", Dict())
    time_unit = uparse(get(units, "time", "d"))
    flux_unit = uparse(get(units, "flux", "μJy"))
    names = get(plot_config, "names", nothing)
    for obs in supernova.lightcurve
        if !isnothing(names)
            if !(obs.name in names)
                continue
            end
        end
        if !(obs.name in instruments)
            elem = MarkerElement(color = :black, marker = Meta.parse(plot_config["marker"][obs.name]))
            push!(legend_plots, elem)
            push!(legend_names, obs.name)
        end
        if !(obs.filter.name in filters)
            elem = MarkerElement(color = plot_config["color"][obs.filter.name], marker = :circle)
            push!(legend_plots, elem)
            push!(legend_names, obs.filter.name)
        end
        if !(obs.name in instruments)
            push!(instruments, obs.name)
        end
        if !(obs.filter.name in filters)
            push!(filters, obs.filter.name)
        end
        push!(get!(time, (obs.name, obs.filter.name), Float64[]), ustrip(uconvert(time_unit, obs.time)))
        push!(get!(flux, (obs.name, obs.filter.name), Float64[]), ustrip(uconvert(flux_unit, obs.flux)))
        push!(get!(flux_err, (obs.name, obs.filter.name), Float64[]), ustrip(uconvert(flux_unit, obs.flux_err)))
    end
    for (i, time_key) in enumerate(collect(keys(time)))
        flux_key = collect(keys(flux))[i]
        flux_err_key = collect(keys(flux_err))[i]
        scatter!(ax, time[time_key], flux[flux_key], color = plot_config["color"][time_key[2]], marker = Meta.parse(plot_config["marker"][time_key[1]]))
        errorbars!(ax, time[time_key], flux[flux_key], flux_err[flux_err_key], color = plot_config["color"][time_key[2]], marker = Meta.parse(plot_config["marker"][time_key[1]]))
    end
    Legend(fig[1, 2], legend_plots, legend_names)
    return fig, ax
end

function plot(supernova::Supernova, plot_config::Dict)
    fig = Figure()
    units = get(plot_config, "unit", Dict())
    time_unit = uparse(get(units, "time", "d"))
    flux_unit = uparse(get(units, "flux", "μJy"))
    ax = Axis(fig[1, 1], xlabel = "Time [$time_unit]", ylabel = "Flux [$flux_unit]", title = supernova.name)
    fig, ax = plot!(fig, ax, supernova, plot_config)
    return fig, ax
end

function plot(supernova::Supernova, plot_config::Dict, path::AbstractString)
    fig, ax = plot(supernova, plot_config)
    save(path, fig)
end

function get_args()
    s = ArgParseSettings()
    @add_arg_table s begin
        "--verbose", "-v"
            help = "Increase level of logging verbosity"
            action = :store_true
        "toml"
            help = "Path to toml input file"
            required = true
    end

    return parse_args(s)
end

if abspath(PROGRAM_FILE) == @__FILE__
    args = get_args()
    verbose = args["verbose"]
    toml_path = args["toml"]
    toml = TOML.parsefile(toml_path)
    Supernova(toml)
end
 

end # module
