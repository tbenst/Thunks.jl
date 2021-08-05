using Thunks
using Documenter

DocMeta.setdocmeta!(Thunks, :DocTestSetup, :(using Thunks); recursive=true)

makedocs(;
    modules=[Thunks],
    authors="Tyler Benster <thunks.jl@tylerbenster.com> and contributors",
    repo="https://github.com/tbenst/Thunks.jl/blob/{commit}{path}#{line}",
    sitename="Thunks.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://tbenst.github.io/Thunks.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/tbenst/Thunks.jl",
)
