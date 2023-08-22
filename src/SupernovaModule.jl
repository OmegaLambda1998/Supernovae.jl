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

mutable struct Supernova
    name::String
    zeropoint::typeof(1.0u"AB_mag")
    redshift::Float64
    lightcurve::Lightcurve
end

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
    peak_time = get(data, "PEAK_TIME", false)

    # Load in observations
    observations = get(data, "OBSERVATIONS", Vector{Dict{String,Any}}())
    @info "Found $(length(observations)) observations"
    lightcurve = Lightcurve(observations, zeropoint, redshift, config; max_flux_err=max_flux_err, peak_time=peak_time)
    @info "Finished loading Supernova"

    return Supernova(name, zeropoint, redshift, lightcurve)
end

end
