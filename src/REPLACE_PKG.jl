module REPLACE_PKG

# External packages
using TOML
using OLUtils

# Internal Packages

# Exports
export run_REPLACE_PKG

function run_REPLACE_PKG(toml::Dict, verbose::Bool)
    setup_global!(toml, verbose)
    config = toml["global"]
end

function run_REPLACE_PKG(toml_path::AbstractString, verbose::Bool)
    toml = TOML.parsefile(toml_path)
    if !("global" in keys(toml))
        toml["global"] = Dict()
    end
    toml["global"]["toml_path"] = dirname(abspath(toml_path))
    return run_REPLACE_PKG(toml, verbose)
end

end
