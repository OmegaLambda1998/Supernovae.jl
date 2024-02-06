module Supernovae

# External packages
using TOML
using BetterInputFiles
using ArgParse
using StatProfilerHTML
using OrderedCollections

# Internal Packages
include("RunModule.jl")
using .RunModule

# Exports
export main
export run_Supernovae
export Supernova
export Observation
export synthetic_flux
export flux_to_mag, mag_to_flux
export absmag_to_mag, mag_to_absmag
export plot_lightcurve

"""
    get_args()

Helper function to get the ARGS passed to julia.
"""
function get_args()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--verbose", "-v"
        help = "Increase level of logging verbosity"
        action = :store_true
        "--profile", "-p"
        help = "Run profiler"
        action = :store_true
        "input"
        help = "Path to .toml file"
        required = true
    end
    return parse_args(s)
end

"""
    main()

Read the args, prepare the input TOML and run the actual package functionality. Runs [`main(toml_path, verbose, profile)`](@ref).
"""
function main()
    args = get_args()
    toml_path = args["input"]
    verbose = args["verbose"]
    profile = args["profile"]
    main(toml_path, verbose, profile)
end

"""
    main(toml_path::AbstractString, verbose::Bool, profile::Bool)

Loads `toml_path`, and sets up logging with verbosity based on `verbose`. Runs [`run_Supernovae`](@ref) and if `profile` is `true`, also profiles the code.

# Arguments
- `toml_path::AbstractString`: Path to toml input file.
- `verbose::Bool`: Set verbosity of logging
- `profile::Bool`: If true, profile [`run_Supernovae`](@ref)
"""
function main(toml_path::AbstractString, verbose::Bool, profile::Bool)
    paths = OrderedDict(
        "data_path" => ("base_path", "Data"),
        "filter_path" => ("base_path", "Filters")
    )
    toml = setup_input(toml_path, verbose; paths=paths)
    if profile
        @warn "Running everything once to precompile before profiling"
        run_Supernovae(toml)
        @profilehtml run_Supernovae(toml)
    else
        run_Supernovae(toml)
    end

end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end
