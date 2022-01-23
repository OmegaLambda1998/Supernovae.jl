module Photometrics

# External Packages
using Unitful, UnitfulAstro

# Internal Packages
using ..Filters

# Exports
export Lightcurve
export Observation

mutable struct Observation
    name :: AbstractString # Human readable name
    time :: typeof(1.0u"d") # Default unit of MJD (Days)
    flux :: typeof(1.0u"Jy") # Default unit of Janksy
    flux_err :: typeof(1.0u"Jy") # Default unit of Janksy
    filter :: Filter
end

mutable struct Lightcurve
    observations :: Vector{Observation}
end

function get_column_index(obs_file::Vector{String}, delimiter::AbstractString, header_keys::Dict, facility, instrument, filter_name)
    if typeof(header_keys["time"]["col"]) <: AbstractString
        @debug "Reading in string based header"
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
        @debug "Reading in index based header"
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
    return obs_file, time_col, time_unit, flux_col, flux_unit, flux_err_col, flux_err_unit, facility_col, instrument_col, filter_col
end

# Default header
function get_column_index(obs_file::Vector{String}, delimiter::AbstractString, header_keys::Nothing, facility, instrument, filter_name)
    @debug "Reading in default header"
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
    return obs_file, time_col, time_unit, flux_col, flux_unit, flux_err_col, flux_err_unit, facility_col, instrument_col, filter_col
end


function Lightcurve(observations::Vector, max_flux_err)
    lc = Observation[]
    for observation in observations
        obs_name = observation["name"]
        @info "Loading observations for $obs_name"
        obs_path = observation["path"]
        if !isabspath(obs_path)
            obs_path = joinpath(observation["data_path"], observation["path"])
        end
        facility = get(observation, "facility", nothing)
        instrument = get(observation, "instrument", nothing)
        filter_name = get(observation, "filter", nothing)
        delimiter = get(observation, "delimiter", ",")
        comment = get(observation, "comment", "#")
        obs_file = open(obs_path, "r") do io
            return readlines(io)
        end
        header_keys = get(observation, "header", nothing)
        obs_file, time_col, time_unit, flux_col, flux_unit, flux_err_col, flux_err_unit, facility_col, instrument_col, filter_col = get_column_index(obs_file, delimiter, header_keys, facility, instrument, filter_name)
        flux_offset_val = get(observation, "flux_offset", 0)
        flux_offset_unit = uparse(get(observation, "flux_offset_unit", flux_unit))
        flux_offset = flux_offset_val * flux_offset_unit
        @debug "Moving through lines"
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
            filter = Filter(observation["filter_path"], facility, instrument, filter_name)
            obs = Observation(obs_name, time, flux, flux_err, filter)
            push!(lc, obs)
        end
    end
    return Lightcurve(lc)
end

function Lightcurve(observations::Vector, max_flux_err, peak_time::Bool)
    lightcurve = Lightcurve(observations, max_flux_err)
    @debug "Offsetting peak time"
    if peak_time
        max_obs = lightcurve.observations[1]
        for obs in lightcurve.observations
            if obs.flux > max_obs.flux
                max_obs = obs
            end
        end
        peak_time = max_obs.time
        for obs in lightcurve.observations
            obs.time -= peak_time
        end
    end
    return lightcurve 
end

function Lightcurve(observations::Vector, max_flux_err, peak_time, peak_time_unit)
    lightcurve = Lightcurve(observations, max_flux_err)
    peak_time_unit = uparse(toml["data"], "peak_time_unit", "d")
    peak_time = peak_time * peak_time_unit
    @debug "Offsetting peak time"
    for obs in lightcurve
        obs.time -= peak_time
    end
    return lightcurve
end

end
