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

const c = 299792458.0u"m / s"
const Magnitude = Union{
    Quantity{T,dimension(1.0u"AB_mag"),U},
    Level{L,S,Quantity{T,dimension(1.0u"AB_mag"),U}} where {L,S},
} where {T,U}
const Flux = Union{
    Quantity{T,dimension(1.0u"μJy"),U},
    Level{L,S,Quantity{T,dimension(1.0u"μJy"),U}} where {L,S},
} where {T,U}

"""
    mutable struct Observation

A single observation of a supernova, including time, flux, magnitude and filter information.

# Fields
- `name::String`: The name of the supernova
- `time::typeof(1.0u"d")`: The time of the observation in MJD
- `flux::typeof(1.0u"Jy")`: The flux of the observation in Jansky
- `flux_err::typeof(1.0u"Jy")`: The flux error of the observation in Jansky
- `mag::typeof(1.0u"AB_mag")`: The magnitude of the observations in AB Magnitude 
- `mag_err::typeof(1.0u"AB_mag")`: The magnitude error of the observations in AB Magnitude 
- `absmag::typeof(1.0u"AB_mag")`: The absolute magnitude of the observations in AB Magnitude 
- `absmag_err::typeof(1.0u"AB_mag")`: The absolute magnitude error of the observations in AB Magnitude 
- `filter::Filter`: The [`Filter`](@ref) used to observe the supernova 
- `is_upperlimit::Bool`: Whether the observation is an upperlimit
"""
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

"""
    mutable struct Lightcurve 

A lightcurve is simply a collection of observations

# Fields
- `observations::Vector{Observation}`: A `Vector` of [`Observation`](@ref) representing a supernova lightcurve.
"""
Base.@kwdef mutable struct Lightcurve
    observations::Vector{Observation} = Vector{Observation}()
end

"""
    parse_file(lines::Vector{String}; delimiter::String=", ", comment::String="#")

Parse a file, splitting on `delimiter` and removing `comment`s.

# Arguments
- `lines::Vector{String}`: A vector containing each line of the file to parse
- `;delimiter::String=", "`: What `delimiter` to split on
- `;comment::String="#"`: What comments to remove. Will remove everything from this comment onwards, allowing for inline comments
"""
function parse_file(lines::Vector{String}; delimiter::String = ", ", comment::String = "#")
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

"""
    get_column_index(header::Vector{String}, header_keys::Dict{String,Any})

Determine the index of each column withing `header` associated with `header_keys`

# Arguments
- `header::Vector{String}`: The header, split by column names
- `header_keys::Dict{String, Any}`: Determine the index of these parameters. The `key::String` is the type of object stored in the column, for instance `"TIME"`, `"FLUX"`, `"MAG_ERR"`, and so on. The `values::Any` can be an `Int64` or a `String` where the former indicates the column index (which is simply returned) and the latter represents the name of the `key` object inside `header`. For instance `key = "FLUX"` might map to a column in the `header` title `"Flux"`, `"F"`, `"emmission"`, or `"uJy"`.
"""
function get_column_index(header::Vector{String}, header_keys::Dict{String,Any})
    columns = Dict{String,Tuple{Any,Any}}()
    for key in keys(header_keys)
        opts = header_keys[key]
        column_id = opts["COL"]
        unit = get(opts, "UNIT", nothing)
        unit_column_id = get(opts, "UNIT_COL", nothing)
        column_index = get_column_id(header, column_id)
        if !isnothing(unit)
            if unit == "DEFAULT"
                column_unit = get_default_unit(header, column_id, column_index)
            else
                column_unit = uparse(unit, unit_context = UNITS)
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

"""
    get_column_id(::Vector{String}, column_id::Int64)

Convenience function which simply returns the `column_id` passed in.

# Arguments
- `column_id::Int64`: Return this column id
"""
function get_column_id(::Vector{String}, column_id::Int64)
    return column_id
end

"""
    get_column_id(header::Vector{String}, column_id::String)

Find the column in `header` which contains the given `column_id` and return its index.

# Arguments
- `header::Vector{String}`: The header, split by column
- `column_id::String`: The column title to search for in `header`
"""
function get_column_id(header::Vector{String}, column_id::String)
    first = findfirst(f -> occursin(column_id, f), header)
    if !isnothing(first)
        return first
    end
    error("Can not find column $(column_id) in header: $header")
end

"""
   get_default_unit(header::Vector{String}, column_id::String, column_index::Int64)
    
If no unit is provided for a parameter, it is assumed that the unit is listed in the header via `"paramater_name[unit]"`. Under this system you might have `"time[d]"`, `"flux[μJy]"`, or `"mag[AB_mag]"`.

# Arguments
- `header::Vector{String}`: The header, split by column
- `column_id::String`: The name of the parameter in the column title
- `column_index::Int64`: The index of the column in `header`
"""
function get_default_unit(header::Vector{String}, column_id::String, column_index::Int64)
    column_head = header[column_index]
    unit = foldl(replace, [column_id => "", "[" => "", "]" => ""]; init = column_head)
    return uparse(unit, unit_context = UNITS)
end

"""
    Lightcurve(observations::Vector{Dict{String,Any}}, zeropoint::Magnitude, redshift::Float64, config::Dict{String,Any}; max_flux_err::Flux=Inf * 1.0u"μJy", peak_time::Union{Bool,Float64}=false)

Create a Lightcurve from a Vector of observations, modelled as a Vector of Dicts. Each observation must contains the keys `NAME`, and `PATH` which specify the name of the supernovae, and a path to the photometry respectively. `PATH` can either be absolute, or relative to `DATA_PATH` as specified in `[ GLOBAL ]` and is expected to be a delimited file of rows and columns, with a header row describing the content of each column, and a row for each individual photometric observation of the lightcurve. Each observation in `PATH` must contain a time, flux, and flux error column. You can also optionally pescribe a seperate facility, instrument, passband, and upperlimit column. If any of these column exist, they will be read per row. If not, you must specify a global value. The keys `DELIMITER::String=", "`, and `COMMENT::String="#"` allow you to specify the delimiter and comment characters used by `PATH`.

The rest of the keys in an observation are for reading or overwriting the photometry in `PATH`. You can overwrite the facility (`FACILITY`::String), instrument (`INSTRUMENT`::String), passband (`PASSBAND`::String), and whether the photometry is an upperlimit (`UPPERLIMIT`::Union{Bool, String}). Specifying any overwrites will apply that overwrite to every row of `PATH`. You can also specify a flux offset (`FLUX_OFFSET`) assumed to be of the same unit as the flux measurements in `PATH`. By default, the upplimit column / overwrite is assumed to be a string: `upperlimit∈["T", "TRUE", "F", "FALSE"]`, if you instead want a different string identifier, you can specify `UPPERLIMIT_TRUE::Union{String, Vector{String}}`, and `UPPERLIMIT_FALSE::Union{String, Vector{String}}`.

Each column of `PATH`, including the required time (`TIME`), flux (`FLUX`), and flux error (`FLUX_ERR`), and the optional facility (`FACILITY`), instrument (`INSTRUMENT`), passband (`PASSBAND`), and upperlimit (`UPPERLIMIT`) columns, can have both an identifier of the column, and the unit of the values be specified (units must be recognisable by [`Unitful`](https://painterqubits.github.io/Unitful.jl/stable/). There are three ways to do this. All of these methods are described by specifying identifiers through `HEADER.OBJECT_NAME.COL` and either `HEADER.OBJECT_NAME.UNIT` or `HEADER.OBJECT_NAME.UNIT_COL`. For example to given an identifier for time, you'd include `HEADER.TIME.COL` and `HEADER.TIME.UNIT`.  

The first method is to simply assume the headers have the syntax `name [unit]`, with time, flux, and flux error having the names `time`, `flux`, and `flux_err` respectively. This is the default when no identifiers are given, but can also be used for the unit identifier by specifying `HEADER.OBJECT_NAME.UNIT = "DEFAULT"`.

The next method involves specifying the name of the column containing data of the object in question. This is simply `HEADER.OBJECT_NAME.COL = "col_name"`. For the unit you can either specify a global unit for the object via `HEADER.OBJECT_NAME.UNIT = "unit"`, or you can specify a unit column by name via `HEADER.OBJECT_NAME.UNIT_COL = "unit_col_name"`.

The final method is to specify the index of the column containing data of the object in questions. This is done via `HEADER.OBJECT_NAME.COL = col_index`. Once again you can either specify a global unit or the index of the column containing unit information via `HEADER.OBJECT_NAME.UNIT_COL = unit_col_index`. Your choice of identifer can be different for each object and unit, for instance you could specify the name of the time column, and the index of the time unit column.

As for the rest of the inputs, it is required to specify a zeropoint (in some magnitude unit), the redshift, and provide a global config. You can specify a maximum error on the flux via `max_flux_err`, which will treat every observation with a flux error greater than this as an outlier which will not be included. Finally you can specify a peak time which all other time parameters will be relative to (i.e, the peak time will be 0 and all other times become time - peak_time). This can either be `true`, in which case the peak time will be set to the time of maximum flux, or a float with units equal to the units of the time column. If you don't want relative times, set `peak_time` to `false`, which is the default.

# Arguments
- `observations::Vector{Dict{String,Any}}`: A `Vector` of `Dicts` containing information and overwrites for the file containing photometry of the supernova.
- `zeropoint::Magnitude`: The zeropoint of the supernova 
- `redshift::Float64`: The redshift of the supernova
- `config::Dict{String,Any}`: The global config, containing information about paths
- `max_flux_err::Flux=Inf * 1.0u"μJy"`: An optional constrain on the maximum flux error. Any observation with flux error greater than this is considered an outlier and removed from the lightcurve.
- `peak_time::Union{Bool, Float64}=false`: If not `false`, times will be relative to `peak_time` (i.e, will transform from `time` to `time - peak_time`). If `true` times a relative to the time of peak flux, otherwise times are relative to `peak_time`, which is assumed to be of the same unit as the times.
"""
function Lightcurve(
    observations::Vector{Dict{String,Any}},
    zeropoint::Magnitude,
    redshift::Float64,
    config::Dict{String,Any};
    max_flux_err::Flux = Inf * 1.0u"μJy",
    peak_time::Union{Bool,Float64} = false,
)
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
            "FLUX_ERR" => Dict{String,Any}("COL" => "flux_err", "UNIT" => "DEFAULT"),
        )
        header_keys = get(observation, "HEADER", default_header_keys)

        obs_file = open(obs_path, "r") do io
            return parse_file(readlines(io); delimiter = delimiter, comment = comment)
        end
        header = obs_file[1]
        data = obs_file[2:end]

        columns::Dict{String,Tuple{Any,Any}} = get_column_index(header, header_keys)

        if "TIME" in keys(columns)
            time_col = columns["TIME"][1]
            time_unit_col = columns["TIME"][2]
            time_unit(row) = begin
                if isa(time_unit_col, Int64)
                    return uparse(row[time_unit_col], unit_context = UNITS)
                else
                    return time_unit_col
                end
            end
            time = [parse(Float64, d[time_col]) * time_unit(d) for d in data]
        else
            error("Missing time column. Please specify a time column.")
        end

        if "FLUX" in keys(columns)
            flux_col = columns["FLUX"][1]
            flux_unit_col = columns["FLUX"][2]
            flux_unit(row) = begin
                if isa(flux_unit_col, Int64)
                    return uparse(row[flux_unit_col], unit_context = UNITS)
                else
                    return flux_unit_col
                end
            end
            flux =
                [(parse(Float64, d[flux_col]) + flux_offset) * flux_unit(d) for d in data]
        else
            error("Missing flux column. Please specify a flux column.")
        end

        if "FLUX_ERR" in keys(columns)
            flux_err_col = columns["FLUX_ERR"][1]
            flux_err_unit_col = columns["FLUX_ERR"][2]
            flux_err_unit(row) = begin
                if isa(flux_err_unit_col, Int64)
                    return uparse(row[flux_err_unit_col], unit_context = UNITS)
                else
                    return flux_err_unit_col
                end
            end
            flux_err = [parse(Float64, d[flux_err_col]) * flux_err_unit(d) for d in data]
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
                facility = [d[facility_col] for d in data]
            else
                error(
                    "Missing Facility details. Please either specify a facility column, or provide a facility",
                )
            end
        else
            facility = [facility for _ in data]
        end

        if isnothing(instrument)
            if "INSTRUMENT" in keys(columns)
                instrument_col = columns["INSTRUMENT"][1]
                instrument = [d[instrument_col] for d in data]
            else
                error(
                    "Missing instrument details. Please either specify a instrument column, or provide a instrument",
                )
            end
        else
            instrument = [instrument for _ in data]
        end

        if isnothing(passband)
            if "PASSBAND" in keys(columns)
                passband_col = columns["PASSBAND"][1]
                passband = [d[passband_col] for d in data]
            else
                error(
                    "Missing passband details. Please either specify a passband column, or provide a passband",
                )
            end
        else
            passband = [passband for _ in data]
        end

        get_equiv = Dict("time" => time, "flux" => flux, "flux_err" => flux_err)
        if isnothing(upperlimit)
            if "UPPERLIMIT" in keys(columns)
                upperlimit_col = columns["UPPERLIMIT"][1]
                upperlimit = Vector{Bool}()
                for d in data
                    if d[upperlimit_col] in upperlimit_true
                        push!(upperlimit, true)
                    elseif d[upperlimit_col] in upperlimit_false
                        push!(upperlimit, false)
                    else
                        error(
                            "Unknown upperlimit specifier $d, truth options include: $upperlimit_true, false options include: $upperlimit_false",
                        )
                    end
                end
            else
                error(
                    "Missing upperlimit details. Please either specify a upperlimit column, or provide a upperlimit",
                )
            end
        else
            if typeof(upperlimit) == Bool
                upperlimit = [upperlimit for _ in data]
            elseif typeof(upperlimit) == String
                if upperlimit in keys(get_equiv)
                    upperlimit_equivalent = get_equiv[upperlimit]
                    upperlimit = [u < 0 * unit(u) for u in upperlimit_equivalent]
                else
                    error(
                        "Can not determine upperlimit from $(upperlimit), only 'time', 'flux', and 'flux_err' can be used.",
                    )
                end
            end
        end
        filter =
            [Filter(facility[i], instrument[i], passband[i], config) for i = 1:length(data)]

        obs = [
            Observation(
                obs_name,
                time[i],
                flux[i],
                flux_err[i],
                mag[i],
                mag_err[i],
                absmag[i],
                absmag_err[i],
                filter[i],
                upperlimit[i],
            ) for i = 1:length(data) if flux_err[i] < max_flux_err
        ]

        lightcurve.observations = vcat(lightcurve.observations, obs)
    end
    # If peak_time is a value, set all time relative to that value
    if peak_time isa Float64
        peak_time *= unit(time[1])
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

function Base.get(lightcurve::Lightcurve, key::String, default::Any = nothing)
    if Symbol(key) in fieldnames(Observation)
        return [getfield(obs, Symbol(key)) for obs in lightcurve.observations]
    end
    return default
end

"""
    flux_to_mag(flux::Unitful.Quantity{Float64}, zeropoint::Level)

Convert `flux` to magnitudes. Calculates `zeropoint - 2.5log10(flux)`. Returns `AB_mag` units

# Arguments
- `flux::Unitful.Quantity{Float64}`: The flux to convert, in units compatible with Jansky. If the flux is negative it will be set to 0.0 to avoid `log10` errors
- `zeropoint::Level`: The assumed zeropoint, used to convert the flux to magnitudes.
"""
function flux_to_mag(flux::Flux, zeropoint::Magnitude)
    if flux <= 0.0 * unit(flux)
        flux *= 0.0
    end
    return (ustrip(zeropoint |> u"AB_mag") - 2.5 * log10(ustrip(flux |> u"Jy"))) * u"AB_mag"
end

"""
    flux_err_to_mag_err(flux::Unitful.Quantity{Float64}, flux_err::Unitful.Quantity{Float64})

Converts `flux_err` to magnitude error. Calculates `(2.5 / log(10)) * (flux_err / flux)`.

# Arguments
- `flux::Unitful.Quantity{Float64}`: The flux associated with the error to be converted
- `flux_err::Unitful.Quantity{Float64}`: The flux error to be converted
"""
function flux_err_to_mag_err(flux::Flux, flux_err::Flux)
    return (2.5 / log(10)) * (flux_err / flux) * u"AB_mag"
end

"""
    mag_to_flux(mag::Level, zeropoint::Level)

Convert `flux` to magnitudes. Calculates `10^(0.4(zeropoint - mag))`. Return `Jy` units.

# Arguments
- `flux::Unitful.Quantity{Float64}`: The flux to convert, in units compatible with Jansky. If the flux is negative it will be set to 0.0 to avoid `log10` errors
- `zeropoint::Level`: The assumed zeropoint, used to convert the flux to magnitudes.
"""

function mag_to_flux(mag::Magnitude, zeropoint::Magnitude)
    return (10.0^(0.4 * (ustrip(zeropoint |> u"AB_mag") - ustrip(mag |> u"AB_mag")))) *
           u"Jy"
end

"""
    mag_to_absmag(mag::Level, redshift::Float64; H0::Unitful.Quantity{Float64}=70.0u"km/s/Mpc")

Converts `mag` to absolute magnitude. Calculates `mag - 5 log10(c * redshift / (H0 * 10pc))`

# Arguments
- `mag::Level`: The magnitude to convert
- `redshift::Float64`: The redshift, used to calculate the distance to the object
- `;H0::Unitful.Quantity{Float64}=70.0u"km/s/Mpc`: The assumed value of H0, used to calculate the distance to the object
"""
function mag_to_absmag(
    mag::Magnitude,
    redshift::Float64;
    H0::Unitful.Frequency = 70.0u"km/s/Mpc",
)
    d = c * redshift / H0
    μ = 5.0 * log10(d / 10.0u"pc")
    absmag = (ustrip(mag |> u"AB_mag") - μ) * u"AB_mag"
    return absmag
end

"""
    absmag_to_mag(absmag::Level, redshift::Float64; H0::Unitful.Quantity{Float64}=70.0u"km/s/Mpc")

Converts `absmag` to magnitudes. Calculates `absmag + 5 log10(c * redshift / (H0 * 10pc))` 

# Arguments
- `mag::Level`: The magnitude to convert
- `redshift::Float64`: The redshift, used to calculate the distance to the object
- `;H0::Unitful.Quantity{Float64}=70.0u"km/s/Mpc`: The assumed value of H0, used to calculate the distance to the object
"""

function absmag_to_mag(
    absmag::Magnitude,
    redshift::Float64;
    H0::Unitful.Frequency = 70.0u"km/s/Mpc",
)
    d = c * redshift / H0
    μ = 5.0 * log10(d / 10.0u"pc")
    mag = (ustrip(absmag |> u"AB_mag") + μ) * u"AB_mag"
    return mag
end


end
