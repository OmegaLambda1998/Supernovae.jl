using Pkg
ENV["PYTHON"] = ""
ENV["CONDA_JL_USE_MINIFORGE"] = "1"

Pkg.build("Conda")
using Conda
@info "$(Conda.PYTHONDIR)"

Pkg.build("PyCall")
using PyCall
@info "$(PyCall.pyversion); $(PyCall.libpython); $(PyCall.pyprogramname); $(PyCall.conda)"
