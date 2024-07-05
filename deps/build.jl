using Pkg
ENV["PYTHON"] = ""
ENV["CONDA_JL_USE_MINIFORGE"] = "1"

Pkg.build("Conda")
using Conda

Pkg.build("PyCall")
using PyCall
