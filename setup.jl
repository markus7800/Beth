import Pkg

Pkg.add("StaticArrays")
Pkg.add("Genie")

include("endgame/generate_endgame_tablebase.jl")
