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

mutable struct Observation
    name::String
    time::typeof(1.0u"d")
    flux::typeof(1.0u"Jy")
    flux_err::typeof(1.0u"Jy")
    filter::Filter
    is_upperlimit::Bool
end

Base.@kwdef mutable struct Lightcurve
    observations::Vector{Observation} = Vector{Observation}()
end

function parse_file(lines::Vector{String}; delimiter::String=", ", comment::String="#")
    parsed_file = Vector{Vector{String}}()
    for (i, line) in enumerate(lines)
        # Remove comments
        # Assumes once a comment starts, it takes up the rest of the line
        if occursin(comment, line)
            comment_index = findfirst(comment, line)[1] - 1
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
        column_id = opts["COL"]
        unit = get(opts, "UNIT", nothing)
        unit_column_id = get(opts, "UNIT_COL", nothing)
        column_index = get_column_index(header, column_id)
        if !isnothing(unit)
            if unit == "DEFAULT"
                column_unit = get_default_unit(header, column_id, column_index)
            else
                column_unit = uparse(unit, unit_context=UNITS)
            end
        elseif !isnothing(unit_column_id)
            column_unit = get_column_index(header, unit_column_id)
        else
            column_unit = nothing
        end
        columns[key] = (column_index, column_unit)
    end
    return columns
end

function get_column_index(header::Vector{String}, column_id::Int64)
    return column_id
end

function get_column_index(header::Vector{String}, column_id::String)
    return findfirst(f -> occursin(column_id, f), header)
end

function get_default_unit(header::Vector{String}, column_id::String, column_index::Int64)
    column_head = header[column_index]
    unit = replace(column_head, column_id => "", "[" => "", "]" => "")
    return uparse(unit, unit_context=UNITS)
end

function Lightcurve(observations::Vector{Dict{String,Any}}, zeropoint::typeof(1.0u"AB_mag"), redshift::Float64, config::Dict{String,Any}; max_flux_err::typeof(1.0u"μJy")=Inf * 1.0u"μJy", peak_time::Bool=false)
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

        columns = get_column_index(header, header_keys)

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
            passband = [passband for d in data]
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
                upperlimit = [upperlimit for d in data]
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

        obs = [Observation(obs_name, time[i], flux[i], flux_err[i], filter[i], upperlimit[i]) for i in 1:length(data)]

        lightcurve.observations = vcat(lightcurve.observations, obs)
    end
    return lightcurve
end

end
