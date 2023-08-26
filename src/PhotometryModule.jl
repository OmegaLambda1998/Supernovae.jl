# Photometry Module
module PhotometryModule

# Internal Packages 
using ..FilterModule

# External Packages 
using Unitful, UnitfulAstro
const UNITS = [Unitful, UnitfulAstro]

# Exports
export Observation
export Lightcurve
export flux_to_mag, mag_to_flux
export absmag_to_mag, mag_to_absmag

const c::typeof(1.0u"m/s") = 299792458.0u"m / s"


mutable struct Observation
    name::String
    time::typeof(1.0u"d")
    flux::typeof(1.0u"Jy")
    flux_err::typeof(1.0u"Jy")
    mag::typeof(1.0u"AB_mag")
    mag_err::typeof(1.0u"AB_mag")
    absmag::typeof(1.0u"AB_mag")
    absmag_err::typeof(1.0u"AB_mag")
    filter::Filter
    is_upperlimit::Bool
end

Base.@kwdef mutable struct Lightcurve
    observations::Vector{Observation} = Vector{Observation}()
end

function parse_file(lines::Vector{String}; delimiter::String=", ", comment::String="#")
    parsed_file = Vector{Vector{String}}()
    for line in lines
        # Remove comments
        # Assumes once a comment starts, it takes up the rest of the line
        first = findfirst(comment, line)
        if !isnothing(first)
            comment_index = first[1] - 1
            line = line[1:comment_index]
        end
        line = string.([l for l in split(line, delimiter) if l != ""])
        if length(line) > 0
            push!(parsed_file, line)
        end
    end
    return parsed_file
end

function get_column_index(header::Vector{String}, header_keys::Dict{String,Any})
    columns = Dict{String,Tuple{Any,Any}}()
    for key in keys(header_keys)
        opts = header_keys[key]
        column_id::String = opts["COL"]
        unit = get(opts, "UNIT", nothing)
        unit_column_id = get(opts, "UNIT_COL", nothing)
        column_index = get_column_id(header, column_id)
        if !isnothing(unit)
            if unit == "DEFAULT"
                column_unit = get_default_unit(header, column_id, column_index)
            else
                column_unit = uparse(unit, unit_context=UNITS)
            end
        elseif !isnothing(unit_column_id)
            column_unit = get_column_id(header, unit_column_id)
        else
            column_unit = nothing
        end
        columns[key] = (column_index, column_unit)
    end
    return columns
end

function get_column_id(::Vector{String}, column_id::Int64)
    return column_id
end

function get_column_id(header::Vector{String}, column_id::String)
    first = findfirst(f -> occursin(column_id, f), header)
    if !isnothing(first)
        return first
    end
    error("Can not find column $(column_id) in header: $header")
end

function get_default_unit(header::Vector{String}, column_id::String, column_index::Int64)
    column_head = header[column_index]
    unit = replace(column_head, column_id => "", "[" => "", "]" => "")
    return uparse(unit, unit_context=UNITS)
end

function Lightcurve(observations::Vector{Dict{String,Any}}, zeropoint::Union{Level,Nothing}, redshift::Float64, config::Dict{String,Any}; max_flux_err::Unitful.Quantity{Float64}=Inf * 1.0u"μJy", peak_time::Union{Bool,Float64}=false, peak_time_unit::Unitful.FreeUnits)
    lightcurve = Lightcurve()
    for observation in observations
        # File path
        obs_name = observation["NAME"]
        @info "Loading observations for $obs_name"
        obs_path = observation["PATH"]
        if !isabspath(obs_path)
            obs_path = joinpath(config["DATA_PATH"], obs_path)
        end
        obs_path = abspath(obs_path)

        # Optional overwrites
        facility = get(observation, "FACILITY", nothing)
        instrument = get(observation, "INSTRUMENT", nothing)
        passband = get(observation, "PASSBAND", nothing)
        upperlimit = get(observation, "UPPERLIMIT", nothing)
        flux_offset = get(observation, "FLUX_OFFSET", 0)

        # Upperlimit identifiers
        upperlimit_true = collect(get(observation, "UPPERLIMIT_TRUE", ["T", "TRUE"]))
        upperlimit_false = collect(get(observation, "UPPERLIMIT_FALSE", ["F", "FALSE"]))

        # File details
        delimiter = get(observation, "DELIMITER", ", ")
        comment = get(observation, "COMMENT", "#")
        default_header_keys = Dict{String,Any}(
            "TIME" => Dict{String,Any}("COL" => "time", "UNIT" => "DEFAULT"),
            "FLUX" => Dict{String,Any}("COL" => "flux", "UNIT" => "DEFAULT"),
            "FLUX_ERR" => Dict{String,Any}("COL" => "flux_err", "UNIT" => "DEFAULT")
        )
        header_keys = get(observation, "HEADER", default_header_keys)

        obs_file = open(obs_path, "r") do io
            return parse_file(readlines(io); delimiter=delimiter, comment=comment)
        end
        header = obs_file[1]
        data = obs_file[2:end]

        columns::Dict{String,Tuple{Any,Any}} = get_column_index(header, header_keys)

        if "TIME" in keys(columns)
            time_col = columns["TIME"][1]
            if isnothing(time_col)
                error("Can not find time column, please make sure you are specifying it correctly")
            end
            time_unit = columns["TIME"][2]
            time = [parse(Float64, d[time_col]) * time_unit for d in data]
        else
            error("Missing time column. Please specify a time column.")
        end


        if "FLUX" in keys(columns)
            flux_col = columns["FLUX"][1]
            if isnothing(flux_col)
                error("Can not find flux column, please make sure you are specifying it correctly")
            end
            flux_unit = columns["FLUX"][2]
            flux = [(parse(Float64, d[flux_col]) + flux_offset) * flux_unit for d in data]
        else
            error("Missing flux column. Please specify a flux column.")
        end



        if "FLUX_ERR" in keys(columns)
            flux_err_col = columns["FLUX_ERR"][1]
            if isnothing(flux_err_col)
                error("Can not find flux_err column, please make sure you are specifying it correctly")
            end
            flux_err_unit = columns["FLUX_ERR"][2]
            flux_err = [parse(Float64, d[flux_err_col]) * flux_err_unit for d in data]
        else
            error("Missing flux_err column. Please specify a flux_err column.")
        end

        mag = flux_to_mag.(flux, zeropoint)
        mag_err = flux_err_to_mag_err.(flux, flux_err)
        absmag = mag_to_absmag.(mag, redshift)
        absmag_err = mag_err

        if isnothing(facility)
            if "FACILITY" in keys(columns)
                facility_col = columns["FACILITY"][1]
                if isnothing(facility_col)
                    error("Can not find facility column, please make sure you are specifying it correctly")
                end
                facility = [d[facility_col] for d in data]
            else
                error("Missing Facility details. Please either specify a facility column, or provide a facility")
            end
        else
            facility = [facility for d in data]
        end

        if isnothing(instrument)
            if "INSTRUMENT" in keys(columns)
                instrument_col = columns["INSTRUMENT"][1]
                if isnothing(instrument_col)
                    error("Can not find instrument column, please make sure you are specifying it correctly")
                end
                instrument = [d[instrument_col] for d in data]
            else
                error("Missing instrument details. Please either specify a instrument column, or provide a instrument")
            end
        else
            instrument = [instrument for d in data]
        end

        if isnothing(passband)
            if "PASSBAND" in keys(columns)
                passband_col = columns["PASSBAND"][1]
                if isnothing(passband_col)
                    error("Can not find passband column, please make sure you are specifying it correctly")
                end
                passband = [d[passband_col] for d in data]
            else
                error("Missing passband details. Please either specify a passband column, or provide a passband")
            end
        else
            passband = [passband for _ in data]
        end

        get_equiv = Dict("time" => time, "flux" => flux, "flux_err" => flux_err)
        if isnothing(upperlimit)
            if "UPPERLIMIT" in keys(columns)
                upperlimit_col = columns["UPPERLIMIT"][1]
                if isnothing(upperlimit_col)
                    error("Can not find upperlimit column, please make sure you are specifying it correctly")
                end
                upperlimit = [d[upperlimit_col] for d in data]
            else
                error("Missing upperlimit details. Please either specify a upperlimit column, or provide a upperlimit")
            end
        else
            if typeof(upperlimit) == Bool
                upperlimit = [upperlimit for _ in data]
            elseif typeof(upperlimit) == String
                if upperlimit in keys(get_equiv)
                    upperlimit_equivalent = get_equiv[upperlimit]
                    upperlimit = [u < 0 * unit(u) for u in upperlimit_equivalent]
                else
                    error("Can not determine upperlimit from $(upperlimit), only 'time', 'flux', and 'flux_err' can be used.")
                end
            end
        end

        filter = [Filter(facility[i], instrument[i], passband[i], config) for i in 1:length(data)]

        obs = [Observation(obs_name, time[i], flux[i], flux_err[i], mag[i], mag_err[i], absmag[i], absmag_err[i], filter[i], upperlimit[i]) for i in 1:length(data) if flux_err[i] < max_flux_err]

        lightcurve.observations = vcat(lightcurve.observations, obs)
    end
    # If peak_time is a value, set all time relative to that value
    if peak_time isa Float64
        peak_time *= peak_time_unit
        for obs in lightcurve.observations
            obs.time -= peak_time
        end
        # Otherwise if peak_time is true, set all time relative to maximum flux time
    elseif peak_time
        max_ind = argmax(get(lightcurve, "flux"))
        time = get(lightcurve, "time")
        max_time = time[max_ind]
        for obs in lightcurve.observations
            obs.time -= max_time
        end
    end

    return lightcurve
end

function Base.get(lightcurve::Lightcurve, key::String, default::Any=nothing)
    if Symbol(key) in fieldnames(Observation)
        return [getfield(obs, Symbol(key)) for obs in lightcurve.observations]
    end
    return default
end

function Base.get!(lightcurve::Lightcurve, key::String, default::Any=nothing)
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
function Base.get!(lightcurve::Lightcurve, key::String, default::Vector)
    if length(default) != length(lightcurve.observations)
        error("Default value length ($(length(default))) not equal to number of observations ($(length(lightcurve.observations)))")
    end
    value = get(lightcurve, key, default)
    # If using the default value, set the key for all observations
    if value == default
        for (i, obs) in lightcurve.observations
            setfield(obs, Symbol(key), default[i])
        end
    end
end

function flux_to_mag(flux::Unitful.Quantity{Float64}, zeropoint::Level)
    if flux < 0.0 * unit(flux)
        flux *= 0.0
    end
    return (ustrip(zeropoint |> u"AB_mag") - 2.5 * log10(ustrip(flux |> u"Jy"))) * u"AB_mag"
end

function flux_err_to_mag_err(flux::Unitful.Quantity{Float64}, flux_err::Unitful.Quantity{Float64})
    return (2.5 / log(10)) * (flux_err / flux) * u"AB_mag"
end

function mag_to_flux(mag::Level, zeropoint::Level)
    return (10.0^(0.4 * (ustrip(zeropoint |> u"AB_mag") - ustrip(mag |> u"AB_mag")))) * u"Jy"
end

function mag_to_absmag(mag::Level, redshift::Float64; H0::Unitful.Quantity{Float64}=70.0u"km/s/Mpc")
    d = c * redshift / H0
    μ = 5.0 * log10(d / 10.0u"pc")
    absmag = (ustrip(mag |> u"AB_mag") - μ) * u"AB_mag"
    return absmag
end

function absmag_to_mag(absmag::Level, redshift::Float64; H0::Unitful.Quantity{Float64}=70.0u"km/s/Mpc")
    d = c * redshift / H0
    μ = 5.0 * log10(d / 10.0u"pc")
    mag = (ustrip(absmag |> u"AB_mag") + μ) * u"AB_mag"
    return mag
end


end
