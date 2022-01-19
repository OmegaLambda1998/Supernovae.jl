#!/usr/bin/env julia

# Activate project directory 
using Pkg
Pkg.activate(normpath(joinpath(@__DIR__, "..")))

# External packages
using ArgParse
using TOML
include("../src/Supernovae.jl")
using .Supernovae

function get_args()
    s = ArgParseSettings()
    @add_arg_table s begin
        "--verbose", "-v"
            help = "Increase level of logging verbosity"
            action = :store_true
        "toml"
            help = "Path to toml input file"
            required = true
    end

    return parse_args(s)
end

if abspath(PROGRAM_FILE) == @__FILE__
    args = get_args()
    verbose = args["verbose"]
    toml_path = args["toml"]
    main(toml_path, verbose)
end

