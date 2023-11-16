# Filter Module
module FilterModule

# Internal Packages 

# External Packages 
using Unitful
using UnitfulAstro
using PyCall
using Trapz

# Exports
export Filter
export planck
export synthetic_flux

const h = 6.626e-34 * u"J / Hz" # Planck Constant
const k = 1.381e-23 * u"J / K" # Boltzmann Constant
const c = 299792458 * u"m / s" # Speed of light in a vacuum

"""
    svo(facility::String, instrument::String, passband::String)

Attempt to get filter transmission curve from [SVO](http://svo2.cab.inta-csic.es/theory/fps/). Uses the python package `astroquery` via PyCall.

# Arguments
- `facility::String`: SVO name for the filter's facility
- `instrument::String`: SVO name for the filter's instrument
- `passband::String`: SVO name for the filter's passband
"""
function svo(facility::String, instrument::String, passband::String)
    py"""
    from astroquery.svo_fps import SvoFps

    def svo(svo_name):
        try:
            return SvoFps.get_transmission_data(svo_name)
        except IndexError:
            return None
    """

    svo_name = "$facility/$instrument.$passband"
    return py"svo"(svo_name)
end

"""
    struct Filter

Photometric filter transmission curve.

# Fields
- `facility::String`: Name of the filter's facility (NewHorizons, Keper, Tess, etc...)
- `instrument::String`: Name of the filter's instrument (Bessell, CTIO, Landolt, etc...)
- `passband::String`: Name of the filter's passband (g, r, i, z, etc...)
- `wavelength::Vector{Å}`: Transmission curve wavelength
- `transmission::Vector{Float64}`: Transmission curve transmission
"""
struct Filter
    facility::String # Facility name (NewHorizons, Keper, Tess, etc...)
    instrument::String # Instrument name (Bessell, CTIO, Landolt, etc...)
    passband::String # Filter name (g, r, i, z, etc...)
    wavelength::Vector{typeof(1.0u"Å")} # Default unit of Angstrom
    transmission::Vector{Float64} # Unitless
end

"""
    Filter(facility::String, instrument::String, passband::String, svo::PyCall.PyObject)

Make [`Filter`](@ref) object from [`svo`](@ref) transmission curve.

# Arguments
- `facility::String`: Name of the filter's facility
- `instrument::String`: Name of the filter's instrument
- `passband::String`: Name of the filter's passband
- `svo::Pycall.PyObject`: SVO transmission curve
"""
function Filter(facility::String, instrument::String, passband::String, svo::PyCall.PyObject)
    wavelength = svo.__getitem__("Wavelength")
    transmission = svo.__getitem__("Transmission")
    return Filter(facility, instrument, passband, wavelength .* u"Å", transmission)
end

"""
    Filter(facility::String, instrument::String, passband::String, filter_file::AbstractString) 

Make [`Filter`](@ref) object from `filter_file` transmission curve.

# Arguments
- `facility::String`: Name of the filter's facility
- `instrument::String`: Name of the filter's instrument
- `passband::String`: Name of the filter's passband
- `filter_file::AbstractString`: Path to transmission curve file. Assumed to be a comma delimited wavelength,transmission file.
"""
function Filter(facility::String, instrument::String, passband::String, filter_file::AbstractString)
    lines = open(filter_file) do io
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
    return Filter(facility, instrument, passband, wavelength, transmission)
end

"""
    Filter(facility::String, instrument::String, passband::String, config::Dict{String, Any})

Make [`Filter`](@ref) object from `config` options. `config` must include "FILTER_PATH" => path/to/transmission_curve. If this file exists, the transmission curve will be loaded via [`Filter(facility::String, instrument::String, passband::String, filter_file::AbstractString)`](@ref), otherwise attempt to create Filter via [`Filter(facility::String, instrument::String, passband::String, svo::PyCall.PyObject)`](@ref) and the SVO FPS database.

# Arguments
- `facility::String`: Name of the filter's facility
- `instrument::String`: Name of the filter's instrument
- `passband::String`: Name of the filter's passband
- `config::Dict{String, Any}`: Options for creating a Filter.
"""
function Filter(facility::String, instrument::String, passband::String, config::Dict{String,Any})
    filter_directory = config["FILTER_PATH"]
    filter_file = "$(facility)__$(instrument)__$(passband)"
    if !isfile(joinpath(filter_directory, filter_file))
        @debug "Could not find $(filter_file) in $(filter_directory)"
        @debug "Attempting to find filter on SVO FPS"
        filter_svo = svo(facility, instrument, passband)
        if !isnothing(filter_svo)
            filter = Filter(facility, instrument, passband, filter_svo)
            save_filter(filter, filter_directory)
            return filter
        else
            error("Could not find $(filter_file) anywhere, no filter found with facility: $facility, instrument: $instrument, and passband: $passband")
        end
    else
        return Filter(facility, instrument, passband, joinpath(filter_directory, filter_file))
    end
end

"""
    save_filter(filter::Filter, filter_dir::AbstractString)

Save `filter` to directory `filter_dir`.

# Arguments
- `filter::Filter`: The [`Filter`](@ref) to save.
- `filter_dir::AbstractString`: The directory to save `filter` to.
"""
function save_filter(filter::Filter, filter_dir::AbstractString)
    filter_path = joinpath(filter_dir, "$(filter.facility)__$(filter.instrument)__$(filter.passband)")
    @debug "Saving filter to $filter_path"
    filter_str = ""
    for i in 1:length(filter.wavelength)
        filter_str *= "$(ustrip(filter.wavelength[i])),$(filter.transmission[i])\n"
    end
    open(filter_path, "w") do io
        write(io, filter_str)
    end
end

"""
    planck(T::Unitful.Unitful.Temperature, λ::Unitful.Length)

Planck's law: Calculates the specral radiance of a blackbody at temperature T, emitting at wavelength λ

# Arguments
- `T::Unitful.Temperature`: Temperature of blackbody
- `λ::Unitful.Length`: Wavelength of blackbody
"""
function planck(T::Unitful.Temperature, λ::Unitful.Length)
    if T <= 0u"K"
        throw(DomainError(T, "Temperature must be strictly greater than 0 K"))
    end
    if λ <= 0u"Å"
        throw(DomainError(λ, "Wavelength must be strictly greater than 0 Å"))
    end
    exponent = h * c / (λ * k * T)
    B = (2π * h * c * c / (λ^5)) / (exp(exponent) - 1) # Spectral Radiance
    return B
end

"""
    synthetic_flux(filter::Filter, T::Unitful.Temperature)

Calculates the flux of a blackbody at temperature `T`, as observed with the `filter`

# Arguments
- `filter::Filter`: The [`Filter`](@ref) through which the blackbody is observed
- `T::Unitful.Temperature`: The temperature of the blackbody
"""
function synthetic_flux(filter::Filter, T::Unitful.Temperature)
    numer = @. planck(T, filter.wavelength) * filter.transmission * filter.wavelength
    numer = trapz(numer, filter.wavelength)
    denom = @. filter.transmission / filter.wavelength
    denom = c .* trapz(denom, filter.wavelength)

    return abs(numer / denom)
end

end
