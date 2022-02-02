module Photometrics

# External Packages
using Unitful, UnitfulAstro

# Internal Packages
using ..Filters

# Exports
export Lightcurve
export Observation
export mag_to_flux
export flux_to_mag
export mag_to_absmag, absmag_to_mag

mutable struct Observation
    name :: AbstractString # Human readable name
    time :: typeof(1.0u"d") # Default unit of MJD (Days)
    flux :: typeof(1.0u"Jy") # Default unit of Janksy
    flux_err :: typeof(1.0u"Jy") # Default unit of Janksy
    magnitude :: typeof(1.0u"AB_mag") # Default unit of AB mag
    magnitude_err :: typeof(1.0u"AB_mag") # Default unit of AB mag
    abs_magnitude :: typeof(1.0u"AB_mag") # Default unit of AB mag
    abs_magnitude_err :: typeof(1.0u"AB_mag") # Default unit of AB mag
    is_upperlimit :: Bool
    filter :: Filter
end

mutable struct Lightcurve
    observations :: Vector{Observation}
end

function Base.get(lightcurve::Lightcurve, key::AbstractString, default::Any=nothing)
    if Symbol(key) in fieldnames(Observation)
        return [getfield(obs, Symbol(key)) for obs in lightcurve.observations]
    end
    return default
end

function Base.get!(lightcurve::Lightcurve, key::AbstractString, default::Any=nothing)
    value = get(lightcurve, key, default)
    # If using the default value, set the key for all observations
    if value == default
        for obs in lightcurve.observations
            setfield!(obs, Symbol(key), value)
        end
    end
    return value
end

# When using get! you can specify either a single value for all observations or a vector of values for the default
function Base.get!(lightcurve::Lightcurve, key::AbstractString, default::Vector)
    value = get(lightcurve, key, default)
    # If using the default value, set the key for all observations
    if value == default
        if length(value) != length(lightcurve.observations)
            error("Default value length ($(length(default))) not equal to number of observations ($(length(lightcurve.observations)))")
        end
        for (i, obs) in lightcurve.observations
            setfield(obs, Symbol(key), default[i])
        end
    end
end

function get_column_index(obs_file::Vector{String}, delimiter::AbstractString, header_keys::Dict, facility, instrument, filter_name, upperlimit)
    if typeof(header_keys["time"]["col"]) <: AbstractString
        @debug "Reading in string based header"
        header = [h for h in split(obs_file[1], delimiter) if h != ""]
        time_col = findfirst(f -> header_keys["time"]["col"] == f, header)
        time_unit = header_keys["time"]["unit"]
        if "flux" in keys(header_keys)
            flux_col = findfirst(f -> header_keys["flux"]["col"] == f, header)
            flux_unit = header_keys["flux"]["unit"]
            flux_err_col = findfirst(f -> header_keys["flux_err"]["col"] == f, header)
            flux_err_unit = header_keys["flux_err"]["unit"]
        else
            flux_col = flux_err_col = nothing
            flux_unit = flux_err_unit = "µJy"
        end
        if "magnitude" in keys(header_keys)
            magnitude_col = findfirst(f -> header_keys["magnitude"]["col"] == f, header)
            magnitude_unit = header_keys["magnitude"]["unit"]
            magnitude_err_col = findfirst(f -> header_keys["magnitude_err"]["col"] == f, header)
            magnitude_err_unit = header_keys["magnitude_err"]["unit"]
        else
            magnitude_col = magnitude_err_col = nothing
            magnitude_unit = magnitude_err_unit = "AB_mag"
        end
        if !("flux" in keys(header_keys)) & !("magnitude" in keys(header_keys))
            error("You must specify either flux columns or magnitude columns")
        end
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
        if "upperlimit" in keys(header_keys) 
            upperlimit_col = findfirst(f -> header_keys["upperlimit"]["col"] == f, header)
        else
            upperlimit_col = nothing
        end
        obs_file = obs_file[2:end] # Remove header
    else
        @debug "Reading in index based header"
        time_col = header_keys["time"]["col"]
        time_unit = header_keys["time"]["unit"]
        if "flux" in keys(header_keys)
            flux_col = header_keys["flux"]["col"]
            flux_unit = header_keys["flux"]["unit"]
            flux_err_col = header_keys["flux_err"]["col"]
            flux_err_unit = header_keys["flux_err"]["unit"]
        else
            flux_col = flux_err_col = nothing
            flux_unit = flux_err_unit = "µJy"
        end
        if "magnitude" in keys(header_keys)
            magnitude_col = header_keys["magnitude"]["col"]
            magnitude_unit = header_keys["magnitude"]["unit"]
            magnitude_err_col = header_keys["magnitude_err"]["col"]
            magnitude_err_unit = header_keys["magnitude_err"]["unit"]
        else
            magnitude_col = magnitude_err_col = nothing
            magnitude_unit = magnitude_err_unit = "AB_mag"
        end
        if !("flux" in keys(header_keys)) & !("magnitude" in keys(header_keys))
            error("You must specify either flux columns or magnitude columns")
        end
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
        if "upperlimit" in keys(header_keys) 
            upperlimit_col = header_keys["upperlimit"]["col"]
        else
            upperlimit_col = nothing
        end
    end
    return obs_file, time_col, time_unit, flux_col, flux_unit, flux_err_col, flux_err_unit, magnitude_col, magnitude_unit, magnitude_err_col, magnitude_err_unit, facility_col, instrument_col, filter_col, upperlimit_col
end

# Default header
function get_column_index(obs_file::Vector{String}, delimiter::AbstractString, header_keys::Nothing, facility, instrument, filter_name, upperlimit)
    @debug "Reading in default header"
    header = [h for h in split(obs_file[1], delimiter) if h != ""]
    time_col = findfirst(f -> occursin("time[", f), header)
    time_unit = "$(header[time_col][6:end-1])"
    flux_col = findfirst(f -> occursin("flux[", f), header)
    if !isnothing(flux_col)
        flux_unit = "$(header[flux_col][6:end-1])"
    else
        flux_unit = nothing
    end
    flux_err_col = findfirst(f -> occursin("flux_err[", f), header)
    if !isnothing(flux_err_col)
        flux_err_unit = "$(header[flux_err_col][10:end-1])"
    else
        flux_err_unit = nothing
    end
    magnitude_col = findfirst(f -> occursin("magnitude[", f), header)
    if !isnothing(magnitude_col)
        magnitude_unit = "$(header[magnitude_col][6:end-1])"
    else
        magnitude_unit = nothing
    end
    magnitude_err_col = findfirst(f -> occursin("magnitude_err[", f), header)
    if !isnothing(magnitude_err_col)
        magnitude_err_unit = "$(header[magnitude_err_col][10:end-1])"
    else
        magnitude_err_unit = nothing

    end
    if isnothing(flux_col) & isnothing(magnitude_col)
        error("You must specify either flux columns or magnitude columns")
    end
    facility_col = findfirst(f -> occursin("facility", f), header)
    instrument_col = findfirst(f -> occursin("instrument", f), header)
    filter_col = findfirst(f -> occursin("filter", f), header)
    upperlimit_col = findfirst(f -> occursin("upperlimit", f), header)
    obs_file = obs_file[2:end] # Remove header
    return obs_file, time_col, time_unit, flux_col, flux_unit, flux_err_col, flux_err_unit, magnitude_col, magnitude_unit, magnitude_err_col, magnitude_err_unit, facility_col, instrument_col, filter_col, upperlimit_col
end

function flux_to_mag(flux, zeropoint)
    return (ustrip(zeropoint |> u"AB_mag") - 2.5 * log10(ustrip(flux |> u"Jy"))) * u"AB_mag"
end

function mag_to_flux(mag, zeropoint)
    return (10 ^ (0.4 * (ustrip(zeropoint |> u"AB_mag") - ustrip(mag |> u"AB_mag")))) * u"Jy"
end

function mag_to_absmag(mag, redshift; H0=70u"km / s / Mpc")
    c = 299792458u"m / s"
    d = c * redshift / H0
    μ = 5 * log10(d / 10u"pc")
    absmag = (ustrip(mag |> u"AB_mag") - μ) * u"AB_mag"
    return absmag
end

function absmag_to_mag(absmag, redshift; H0=70u"km / s / Mpc")
    c = 299792458u"m / s"
    d = c * redshift / H0
    μ = 5 * log10(d / 10u"pc")
    mag = (ustrip(absmag |> u"AB_mag") + μ) * u"AB_mag"
    return mag 
end

function Lightcurve(observations::Vector, zeropoint, redshift, max_flux_err; H0=70u"km / s / Mpc")
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
        upperlimit = get(observation, "upperlimit", false)
        upperlimit_true = get(observation, "upperlimit_true", true)
        upperlimit_true = push!(Any["true", "T", "t", "True"], upperlimit_true)
        upperlimit_false = get(observation, "upperlimit_false", false)
        upperlimit_false = push!(Any["false", "F", "f", "False"], upperlimit_false)
        delimiter = get(observation, "delimiter", ",")
        comment = get(observation, "comment", "#")
        obs_file = open(obs_path, "r") do io
            return readlines(io)
        end
        header_keys = get(observation, "header", nothing)
        obs_file, time_col, time_unit, flux_col, flux_unit, flux_err_col, flux_err_unit, magnitude_col, magnitude_unit, magnitude_err_col, magnitude_err_unit, facility_col, instrument_col, filter_col, upperlimit_col = get_column_index(obs_file, delimiter, header_keys, facility, instrument, filter_name, upperlimit)
        flux_offset_val = get(observation, "flux_offset", 0)
        flux_offset_unit = uparse(get(observation, "flux_offset_unit", flux_unit), unit_context = [Unitful, UnitfulAstro])
        flux_offset = flux_offset_val * flux_offset_unit
        @debug "Processing file"
        for line in obs_file
            if occursin(comment, line)
                continue
            end
            line = [l for l in split(line, delimiter) if l != ""]
            time = parse(Float64, string(line[time_col])) * uparse(time_unit, unit_context = [Unitful, UnitfulAstro])
            if !isnothing(upperlimit_col)
                upperlimit = string(line[upperlimit_col])
                if upperlimit in upperlimit_true
                    upperlimit = true
                elseif upperlimit in upperlimit_false
                    upperlimit = false
                else
                    error("Unknown upperlimit specifier $upperlimit")
                end
            else
                upperlimit = false
            end
            if isnothing(flux_col)
                flux = flux_err = nothing
            else
                flux = parse(Float64, string(line[flux_col])) * uparse(flux_unit, unit_context = [Unitful, UnitfulAstro])
                if !upperlimit
                    flux_err = parse(Float64, string(line[flux_err_col])) * uparse(flux_err_unit, unit_context = [Unitful, UnitfulAstro])
                else
                    flux_err = 0 * uparse(flux_err_unit, unit_context = [Unitful, UnitfulAstro])
                end
            end
            if isnothing(magnitude_col)
                magnitude = magnitude_err = nothing
            else
                magnitude = parse(Float64, string(line[magnitude_col])) * uparse(magnitude_unit, unit_context = [Unitful, UnitfulAstro])
                if !upperlimit
                    magnitude_err = parse(Float64, string(line[magnitude_err_col])) * uparse(magnitude_err_unit, unit_context = [Unitful, UnitfulAstro])
                else
                    magnitude_err = 0 * uparse(magnitude_err_unit, unit_context = [Unitful, UnitfulAstro])
                end
            end
            if isnothing(flux) & isnothing(magnitude)
                error("Either flux or magnitude must be defined")
            end
            if isnothing(flux)
                flux = mag_to_flux(magnitude, zeropoint) |> u"µJy"
                if !upperlimit
                    flux_err = ustrip(magnitude_err |> u"AB_mag") * log(10) * 0.4 * flux
                else
                    flux_err = 0 * u"µJy"
                end
            end
            flux += flux_offset
            if flux <= 0 * u"Jy"
                continue
            end
            magnitude = flux_to_mag(flux, zeropoint) |> u"AB_mag"
            if !upperlimit
                magnitude_err = ustrip((2.5 / log(10)) * (flux_err / flux)) * u"AB_mag"
            else
                magnitude_err = 0 * u"AB_mag"
            end
            if !isnothing(max_flux_err)
                if flux_err > max_flux_err
                    continue
                end
            end
            if !isnothing(facility_col)
                facility = string(line[facility_col])
            end
            if !isnothing(instrument_col)
                instrument = string(line[instrument_col])
            end
            if !isnothing(filter_col)
                filter_name = string(line[filter_col])
            end
            abs_magnitude = mag_to_absmag(magnitude, redshift; H0=H0)
            abs_magnitude_err = magnitude_err
            filter = Filter(observation["filter_path"], facility, instrument, filter_name)
            obs = Observation(obs_name, time, flux, flux_err, magnitude, magnitude_err, abs_magnitude, abs_magnitude_err, upperlimit, filter)
            push!(lc, obs)
        end
    end
    return Lightcurve(lc)
end

function Lightcurve(observations::Vector, zeropoint, redshift, max_flux_err, peak_time::Bool; H0=70u"km / s / Mpc")
    lightcurve = Lightcurve(observations, zeropoint, redshift, max_flux_err; H0=H0)
    if peak_time
        @debug "Offsetting peak time"
        max_obs = lightcurve.observations[1]
        for obs in lightcurve.observations
            if obs.flux > max_obs.flux
                max_obs = obs
            end
        end
        peak_time = max_obs.time
        @debug "Peak time set to $peak_time"
        for obs in lightcurve.observations
            obs.time -= peak_time
        end
    end
    return lightcurve 
end

function Lightcurve(observations::Vector, zeropoint, redshift, max_flux_err, peak_time, peak_time_unit; H0=70u"km / s / Mpc")
    lightcurve = Lightcurve(observations, zeropoint, redshift, max_flux_err; H0=H0)
    peak_time = peak_time * peak_time_unit
    @debug "Offsetting peak time"
    @debug "Peak time set to $peak_time"
    for obs in lightcurve.observations
        obs.time -= peak_time
    end
    return lightcurve
end

end
