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
    return py"svo"(svo_name)
end

struct Filter
    facility::String # Facility name (NewHorizons, Keper, Tess, etc...)
    instrument::String # Instrument name (Bessell, CTIO, Landolt, etc...)
    passband::String # Filter name (g, r, i, z, etc...)
    wavelength::Vector{typeof(1.0u"Å")} # Default unit of Angstrom
    transmission::Vector{Float64} # Unitless
end

function Filter(facility::String, instrument::String, passband::String, svo::PyCall.PyObject)
    wavelength = svo.__getitem__("Wavelength")
    transmission = svo.__getitem__("Transmission")
    return Filter(facility, instrument, passband, wavelength .* u"Å", transmission)
end

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

function Filter(facility::String, instrument::String, passband::String, config::Dict{String,Any})
    filter_directory = config["FILTER_PATH"]
    filter_file = "$(facility)|$(instrument)|$(passband)"
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

function save_filter(filter::Filter, filter_dir::AbstractString)
    filter_path = joinpath(filter_dir, "$(filter.facility)|$(filter.instrument)|$(filter.passband)")
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
