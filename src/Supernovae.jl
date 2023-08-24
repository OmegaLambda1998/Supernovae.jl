module Supernovae

# External packages
using TOML
using BetterInputFiles
using ArgParse
using StatProfilerHTML
using OrderedCollections

# Internal Packages
include("RunModule.jl")
using .RunModule: run_Supernovae

# Exports
export main
export run_Supernovae
export Supernova

"""
    get_args()

Helper function to get the ARGS passed to julia.
"""
function get_args()
    s = ArgParseSettings()
    @add_arg_table s begin
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

Read the args, prepare the input TOML and run the actual package functionality.
"""
function main()
    args = get_args()
    verbose = args["verbose"]
    toml_path = args["input"]
    paths = OrderedDict(
        "data_path" => ("base_path", "Data"),
        "filter_path" => ("base_path", "Filters")
    )
    toml = setup_input(toml_path, verbose; paths=paths)
    if args["profile"]
        @profilehtml run_Supernovae(toml)
    else
        run_Supernovae(toml)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end
