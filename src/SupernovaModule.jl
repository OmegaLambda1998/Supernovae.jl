# Supernova Module
module SupernovaModule

# Internal Packages 
using ..PhotometryModule

# External Packages
using Unitful
using UnitfulAstro
const UNITS = [Unitful, UnitfulAstro]

# Exports
export Supernova

"""
    mutable struct Supernova

A Supernova

# Fields
- `name::String`: Supernova name
- `zeropoint::typeof(1.0u"AB_mag")`: Zeropoint of the supernova
- `redshift::Float64`: Redshift of the supernova
- `lightcurve::[`Lightcurve`](@ref)`: The lightcurve of the supernova
"""
mutable struct Supernova
    name::String
    zeropoint::typeof(1.0u"AB_mag")
    redshift::Float64
    lightcurve::Lightcurve
end

"""
    Supernova(data::Dict{String,Any}, config::Dict{String,Any})

Load in a supernova from `data`, which has a number of keys containing supernova data and options.

- `NAME::String`: Name of the supernova
- `ZEROPOINT::Float64`: Supernova zeropoint
- `ZEROPOINT_UNIT::String`: Unitful unit of zeropoint, default to AB_mag
- `REDSHIFT::Float64`: Supernova redshift
- `MAX_FLUX_ERR::Float64`: Maximum allowed flux error, default to inf
- `MAX_FLUX_ERR_UNIT::String`: Unitful unit of maximum flux error
- `PEAK_TIME::Union{Bool, Float64}`: If bool, whether to set time relative to peak flux, if Float64, set time relative to PEAK_TIME
- `PEAK_TIME_UNIT::String`: Unitful unit of peak time
- `OBSERVATIONS::Vector{Dict{String,Any}}`: Data to be turned into a [`Lightcurve`](@ref)
"""
function Supernova(data::Dict{String,Any}, config::Dict{String,Any})
    # Supernova Details
    name = data["NAME"]
    @info "Loading Supernova: $name"
    zeropoint = data["ZEROPOINT"]
    zeropoint_unit = get(data, "ZEROPOINT_UNIT", "AB_mag")
    zeropoint = zeropoint * uparse(zeropoint_unit, unit_context=UNITS)
    @debug "Supernova has zeropoint: $zeropoint"
    redshift = data["REDSHIFT"]
    @debug "Supernova has redshift: $redshift"

    # Maximum error in flux
    max_flux_err = get(data, "MAX_FLUX_ERR", Inf)
    max_flux_err_units = get(data, "MAX_FLUX_ERR_UNIT", "μJy")
    max_flux_err = max_flux_err * uparse(max_flux_err_units, unit_context=UNITS)
    @debug "Maximum flux error set to: $max_flux_err"

    # Whether times are absolute or relative to the peak
    # Alternative choose a time for other times to be relative to
    peak_time = get(data, "PEAK_TIME", false)
    peak_time_unit = uparse(get(data, "PEAK_TIME_UNIT", "d"), unit_context=UNITS)

    # Load in observations
    observations = get(data, "OBSERVATIONS", Vector{Dict{String,Any}}())
    @info "Found $(length(observations)) observations"
    lightcurve = Lightcurve(observations, zeropoint, redshift, config; max_flux_err=max_flux_err, peak_time=peak_time)
    @info "Finished loading Supernova"

    return Supernova(name, zeropoint, redshift, lightcurve)
end

function Base.get(supernova::Supernova, key::AbstractString, default::Any=nothing)
    return get(supernova.lightcurve, key, default)
end

function Base.filter(f::Function, supernova::Supernova)
    filt = filter(f, supernova.lightcurve.observations)
    return Supernova(supernova.name, supernova.zeropoint, supernova.redshift, Lightcurve(filt))
end

function Base.filter!(f::Function, supernova::Supernova)
    supernova.lightcurve = Lightcurve(filter(f, supernova.lightcurve.observations))
end


end
