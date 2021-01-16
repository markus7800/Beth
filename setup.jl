import Pkg

Pkg.add("StaticArrays")
Pkg.add("Genie")
Pkg.add("BenchmarkTools")

include("endgame/generate_endgame_tablebase.jl")
