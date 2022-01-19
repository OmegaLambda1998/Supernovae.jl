module Data

# External packages
using Unitful, UnitfulAstro
using TOML

# Fix for uparse context
function Unitful.uparse(s)
    try
        uparse(s, unit_context=Unitful)
    catch
        uparse(s, unit_context=UnitfulAstro)
    end
end

# Internal files
include("Filters.jl")
using .Filters

include("Photometrics.jl")
using .Photometrics

# Exports
export Supernova

mutable struct Supernova
    name :: AbstractString # Human readable name
    redshift :: Real # Unitless
    distance_modulus :: Real # Unitless
    lightcurve :: Lightcurve
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
    # Loading in lightcurve
    peak_time = get(toml["data"], "peak_time", nothing)
    if !isnothing(peak_time)
        if peak_time == true
            lightcurve = Lightcurve(get(data, "observations", []), max_flux_err, peak_time)
        else
            peak_time_unit = uparse(toml["data"], "peak_time_unit", "d")
            lightcurve = Lightcurve(get(data, "observations", []), max_flux_err, peak_time, peak_time_unit)
        end
    else
        lightcurve = Lightcurve(get(data, "observations", []), max_flux_err)
    end
    supernova = Supernova(name, redshift, distance_modulus, lightcurve)
    return supernova
end

function Supernova(toml_path::AbstractString)
    toml = TOML.parsefile(toml_path)
    return Supernova(toml)
end


end
