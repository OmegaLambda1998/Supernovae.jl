using Documenter
using REPLACE_PKG

DocMeta.setdocmeta!(REPLACE_PKG, :DocTestSetup, :(using REPALCE_PKG); recursive=true)

makedocs(
    sitename="REPLACE_PKG Documentation",
    modules = [REPLACE_PKG, OLUtils.SetupModule],
    pages = [
        "REPLACE_PKG" => "index.md",
    ],
    format = Documenter.HTML(
        assets = ["assets/favicon.ico"],
    )
)

deploydocs(
    repo = "github.com/OmegaLambda1998/REPALCE_PKG.jl.git"
)
