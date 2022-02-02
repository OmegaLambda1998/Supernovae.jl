module Data

# External packages
using Unitful, UnitfulAstro

# Internal files
using ..Filters
using ..Photometrics

# Exports
export Supernova

mutable struct Supernova
    name :: AbstractString # Human readable name
    zeropoint :: typeof(1u"AB_mag") 
    redshift :: Real
    lightcurve :: Lightcurve
end

function Base.get(supernova::Supernova, key::AbstractString, default::Any=nothing)
    return get(supernova.lightcurve, key, default)
end

function Base.get!(supernova::Supernova, key::AbstractString, default::Any=nothing)
    return get!(supernova.lightcurve, key, default)
end

function Base.filter(f::Function, supernova::Supernova)
    filt = filter(f, supernova.lightcurve.observations)
    lc = Lightcurve(filt)
    return Supernova(supernova.name, supernova.zeropoint, supernova.redshift, lc)
end

function Base.filter!(f::Function, supernova::Supernova)
    filt = filter(f, supernova.lightcurve.observations)
    lc = Lightcurve(filt)
    supernova.lightcurve = lightcurve
end

# Read in a supernova object from a toml dictionary
function Supernova(data::Dict)
    # TODO add checks for other supernova properties
    # Redshift, zero point, etc.
    # TODO add magnitudes
    name = data["name"]
    @info "Loading in Supernova $name"
    zeropoint = data["zeropoint"]
    zeropoint_unit = uparse(get(data, "zeropoint_unit", "AB_mag"), unit_context = [Unitful, UnitfulAstro])
    zeropoint = zeropoint * zeropoint_unit
    redshift = data["redshift"]
    max_flux_err = nothing
    max_flux_err_val = get(data, "max_flux_err", nothing)
    if !isnothing(max_flux_err_val)
        max_flux_error_unit = get(data, "max_flux_err_unit", "μJy")
        max_flux_err = max_flux_err_val * uparse(max_flux_error_unit, unit_context = [Unitful, UnitfulAstro])
    end
    @debug "Max flux error set to $max_flux_err"
    # Loading in lightcurve
    observations = get(data, "observations", [])
    @info "Found $(length(observations)) photometry sources"
    for obs in observations
        obs["base_path"] = data["base_path"]
        obs["output_path"] = data["output_path"]
        obs["filter_path"] = data["filter_path"]
        obs["data_path"] = data["data_path"]
    end
    peak_time = get(data, "peak_time", nothing)
    @info "Loading in lightcurves"
    @debug "Loading lightcurve with peak_time = $peak_time"
    if !isnothing(peak_time)
        if peak_time == true
            lightcurve = Lightcurve(observations, zeropoint, redshift, max_flux_err, peak_time)
        else
            peak_time_unit = uparse(get(data, "peak_time_unit", "d"), unit_context = [Unitful, UnitfulAstro])
            lightcurve = Lightcurve(observations, zeropoint, redshift, max_flux_err, peak_time, peak_time_unit)
        end
    else
        lightcurve = Lightcurve(observations, zeropoint, redshift, max_flux_err)
    end
    @info "Loading supernova"
    supernova = Supernova(name, zeropoint, redshift, lightcurve)
    @info "All done"
    return supernova
end

end
