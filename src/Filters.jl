module Filters

# External packages
using Unitful
using UnitfulAstro
using PyCall
using Trapz

# Exports
export Filter
export planck
export synthetic_flux

function svo(facility, instrument, name)
    py"""
    from astroquery.svo_fps import SvoFps

    def svo(svo_name):
        try:
            return SvoFps.get_transmission_data(svo_name)
        except IndexError:
            return None
    """

    svo_name = "$facility/$instrument.$name"
    data = py"svo"(svo_name)
end

# Defines a filter curve
struct Filter
    facility :: AbstractString # Facility name (NewHorizons, Kepler, Tess, etc...)
    instrument :: AbstractString # Instrument name (Bessell, CTIO, Landolt, etc...)
    name :: AbstractString # Filter name (g, r, i, z, etc...)
    wavelength :: Vector{typeof(1.0u"Å")} # Default unit of Angstrom
    transmission :: Vector{Float64} # Unitless 
end

function Filter(identifier, svo::PyCall.PyObject)
    facility, instrument, name = identifier
    wavelength = svo.__getitem__("Wavelength")
    transmission = svo.__getitem__("Transmission")
    filter = Filter(facility, instrument, name, wavelength .* u"Å", transmission)
    return filter
end

function Filter(identifier, path::AbstractString) 
    facility, instrument, name = identifier
    lines = open(path) do io
        ls = [line for line in readlines(io) if line != ""]
        return ls
    end
    wavelength = []
    transmission = []
    for line in lines
        w, t = split(line, ',')
        w = parse(Float64, w) * u"Å"
        t = parse(Float64, t)
        push!(wavelength, w)
        push!(transmission, t)
    end
    return Filter(facility, instrument, name, wavelength, transmission)
end

function Filter(filter_dir::AbstractString, facility::AbstractString, instrument::AbstractString, name::AbstractString)
    # First see if the requested filter is stored locally
    for filter_file in readdir(filter_dir, join=false)
        if filter_file == "$(facility)__$(instrument)__$(name)"
            return Filter((facility, instrument, name), joinpath(filter_dir, filter_file))
        end
    end
    @debug "Could not find $(facility)__$(instrument)__$(name) in local files, attempting to find it on SVO FPS"
    # Next see if the filter can be found on SVO FPS
    filter_svo = svo(facility, instrument, name)
    if !isnothing(filter_svo)
        filter = Filter((facility, instrument, name), filter_svo)
        save(filter_dir, filter)
        return filter
    end
    # Finally, give up
    @error "Could not find $(facility)__$(instrument)__$(name) anywhere"
    throw(ErrorException("No filter found with facilty: $facility, instrument: $instrument, and name: $name"))
end

# Functions on a filter curve
function save(filter_dir::AbstractString, filter::Filter)
    filter_path = joinpath(filter_dir, "$(filter.facility)__$(filter.instrument)__$(filter.name)")
    @debug "Saving filter to $filter_path"
    filter_str = ""
    for i in 1:length(filter.wavelength)
        filter_str *= "$(ustrip(filter.wavelength[i])),$(filter.transmission[i])\n"
    end
    open(filter_path, "w") do io
        write(io, filter_str)
    end
end

# Planck's law
# Calculates the specral radiance of a blackbody at temperature T, emitting at wavelength λ
function planck(T, λ)
    h = 6.626e-34 * u"J / Hz" # Planck Constant
    k = 1.381e-23 * u"J / K" # Boltzmann Constant
    c = 299792458 * u"m / s" # Speed of light in a vacuum
    exponent = h * c / (λ * k * T)
    B = (2π * h * c * c / (λ ^ 5)) / (exp(exponent) - 1) # Spectral Radiance
    return B
end

# Calculates the flux of a blackbody at temperature T, as seen through the filter
function synthetic_flux(filter::Filter, T)
    c = 299792458 * u"m / s" # Speed of light in a vacuum
    numer = @. planck(T, filter.wavelength) * filter.transmission * filter.wavelength
    numer = trapz(numer, filter.wavelength)
    @info numer
    denom = @. filter.transmission / filter.wavelength
    denom = c .* trapz(denom, filter.wavelength)
    @info denom

    return abs(numer / denom)
end

end
