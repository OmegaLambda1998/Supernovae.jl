module REPLACE_PKG

# External packages
using TOML
using BetterInputFiles 
using ArgParse
using StatProfilerHTML

# Internal Packages
include("RunModule.jl")
using .RunModule: run_REPLACE_PKG

# Exports
export main 

Base.@ccallable function julia_main()::Cint
    try
        main()
    catch
        Base.invokelatest(Base.display_error, Base.catch_stack())
        return 1
    end
    return 0
end

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

function main()
    args = get_args()
    verbose = args["verbose"]
    toml_path = args["input"]
    toml = setup_input(toml_path, verbose)
    if args["profile"]
        @profilehtml run_REPLACE_PKG(toml)
    else
        run_REPLACE_PKG(toml)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end

end
