using Documenter
push!(LOAD_PATH, "../src/")
using Supernovae

DocMeta.setdocmeta!(Supernovae, :DocTestSetup, :(using Supernovae); recursive=true)

makedocs(
    sitename="Supernovae Documentation",
    modules = [Supernovae],
    pages = [
        "Supernovae" => "index.md",
        "API" => "api.md"
    ],
    format = Documenter.HTML(
        assets = ["assets/favicon.ico"],
    )
)

deploydocs(
    repo = "github.com/OmegaLambda1998/Supernovae.jl.git"
)
