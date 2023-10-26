push!(LOAD_PATH, joinpath(@__DIR__, "../src/"))
using Supernovae
using Documenter

DocMeta.setdocmeta!(Supernovae, :DocTestSetup, :(using Supernovae); recursive=true)

makedocs(
    sitename="Supernovae Documentation",
    modules = [Supernovae],
    pages = [
        "Supernovae" => "index.md",
        "Usage" => "usage.md",
        "API" => "api.md"
    ],
    format = Documenter.HTML(
        assets = ["assets/favicon.ico"],
    )
)

deploydocs(
    repo = "github.com/OmegaLambda1998/Supernovae.jl.git"
)
