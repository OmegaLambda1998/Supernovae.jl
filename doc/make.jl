using Documenter
push!(LOAD_PATH, "../src/")
using REPLACE_PKG

DocMeta.setdocmeta!(REPLACE_PKG, :DocTestSetup, :(using REPLACE_PKG); recursive=true)

makedocs(
    sitename="REPLACE_PKG Documentation",
    modules = [REPLACE_PKG],
    pages = [
        "REPLACE_PKG" => "index.md",
        "API" => "api.md"
    ],
    format = Documenter.HTML(
        assets = ["assets/favicon.ico"],
    )
)

deploydocs(
    repo = "github.com/OmegaLambda1998/REPLACE_PKG.jl.git"
)
