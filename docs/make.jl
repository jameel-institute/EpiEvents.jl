using EpiEvents
using Documenter

DocMeta.setdocmeta!(EpiEvents, :DocTestSetup, :(using EpiEvents); recursive = true)

makedocs(;
    modules = [EpiEvents],
    authors = "Pratik Gupte <pratikgupte16@gmail.com> and contributors",
    sitename = "EpiEvents.jl",
    format = Documenter.HTML(;
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://jameel-institute.github.io/EpiEvents.jl",
        edit_link = "main",
        assets = String[],
        size_threshold_ignore = [
            "ensemble.md",
            "country_data.md"  # prevent HTML size errors during docs build
        ]
    ),
    checkdocs = :exports,
    pages = [
        "Home" => "index.md",
        "Usage Guide" => "guide.md",
        "SIR Example" => "sir_example.md",
        "Index" => "pkg_index.md",
        "Function Reference" => "reference.md"
    ]
)

deploydocs(;
    repo = "github.com/jameel-institute/EpiEvents.jl",
    devbranch = "main"
)
