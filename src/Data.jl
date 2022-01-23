module Data

# External packages
using Unitful, UnitfulAstro

# Fix for uparse context
function Unitful.uparse(s)
    try
        uparse(s, unit_context=Unitful)
    catch
        uparse(s, unit_context=UnitfulAstro)
    end
end

# Internal files
using ..Filters
using ..Photometrics

# Exports
export Supernova

mutable struct Supernova
    name :: AbstractString # Human readable name
    redshift :: Real # Unitless
    distance_modulus :: Real # Unitless
    lightcurve :: Lightcurve
end

# Read in a supernova object from a toml dictionary
function Supernova(data::Dict)
    name = data["name"]
    @info "Loading in Supernova $name"
    redshift = data["redshift"]
    distance_modulus = data["distance_modulus"]
    max_flux_err = nothing
    max_flux_err_val = get(data, "max_flux_err", nothing)
    if !isnothing(max_flux_err_val)
        max_flux_error_unit = get(data, "max_flux_err_unit", "μJy")
        max_flux_err = max_flux_err_val * uparse(max_flux_error_unit)
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
            lightcurve = Lightcurve(observations, max_flux_err, peak_time)
        else
            peak_time_unit = uparse(data, "peak_time_unit", "d")
            lightcurve = Lightcurve(observations, max_flux_err, peak_time, peak_time_unit)
        end
    else
        lightcurve = Lightcurve(observations, max_flux_err)
    end
    @info "Loading supernova"
    supernova = Supernova(name, redshift, distance_modulus, lightcurve)
    @info "All done"
    return supernova
end

end