module Filters

# External packages
using Unitful
using UnitfulAstro
using PyCall

# Exports
export Filter

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
    wavelength :: Vector{typeof(1.0u"A")} # Default unit of Angstrom
    transmission :: Vector{Float64} # Unitless 
end

function Filter(facility::AbstractString, instrument::AbstractString, name::AbstractString, svo::PyCall.PyObject)
    wavelength = svo.__getitem__("Wavelength")
    transmission = svo.__getitem__("Transmission")
    filter = Filter(facility, instrument, name, wavelength .* u"A", transmission)
    save(filter)
    return filter
end

function Filter(facility::AbstractString, instrument::AbstractString, name::AbstractString, path::AbstractString) 
    lines = open(path) do io
        ls = [line for line in readlines(io) if line != ""]
        return ls
    end
    wavelength = []
    transmission = []
    for line in lines
        w, t = split(line, ',')
        w = parse(Float64, w) * u"A"
        t = parse(Float64, t)
        push!(wavelength, w)
        push!(transmission, t)
    end
    return Filter(facility, instrument, name, wavelength, transmission)
end

function Filter(facility::AbstractString, instrument::AbstractString, name::AbstractString)
    # First see if the requested filter is stored locally
    @debug "Attempting to find $(facility)__$(instrument)__$(name) in local files"
    filter_dir = joinpath(@__DIR__, "filters")
    for filter_file in readdir(filter_dir, join=false)
        if filter_file == "$(facility)__$(instrument)__$(name)"
            return Filter(facility, instrument, name, joinpath(filter_dir, filter_file))
        end
    end
    @debug "Could not find $(facility)__$(instrument)__$(name) in local files, attempting to find it on SVO FPS"
    # Next see if the filter can be found on SVO FPS
    filter_svo = svo(facility, instrument, name)
    if !isnothing(filter_svo)
        return Filter(facility, instrument, name, filter_svo)
    end
    # Finally, give up
    @debug "Count not find $(facility)__$(instrument)__$(name) anywhere"
    throw(ErrorException("No filter found with facilty: $facility, instrument: $instrument, and name: $name"))
end

# Functions on a filter curve
function save(filter::Filter)
    filter_dir = joinpath(@__DIR__, "filters")
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

end
