module Supernovae

# External packages
using TOML
using ArgParse

# Internal files
include("Filters.jl")
using .Filters
include("Photometrics.jl")
using .Photometrics
include("Data.jl")
using .Data
include("Plotting.jl")
using .Plotting

# Exports
export Filter
export Observation, Lightcurve, Supernova
export plot_lightcurve, plot_lightcurve!

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
    toml = TOML.parsefile(toml_path)
    println("Building supernova")
    supernova = Supernova(toml)
    @show supernova.name
    plot_config = get(toml, "plot", nothing)
    if !isnothing(plot_config)
        println("Plotting")
        lightcurve_config = get(plot_config, "lightcurve", nothing) 
        if !isnothing(lightcurve_config)
            plot_lightcurve(supernova, lightcurve_config)
        end
    end
end
 

end # module
