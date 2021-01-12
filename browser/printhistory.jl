

println("'" ,FEN(history[1].board, history[1].white), "',")
for ply in history[2:end]
    println("'" * field(ply.move[2]) * "-" * field(ply.move[3]), "',")
end

# FEN strings
for ply in history
    println("'" ,FEN(ply.board, ply.white), "',")
end

# PGN
for (i,ply) in enumerate(history[2:end])
    if i % 2 == 1
        print(ply.n_move, ". ")
    end
    m = ply.move
    if m[1] == PAWNTOQUEEN
        print("P$(FIELDS[m[2]])$(FIELDS[m[3]])Q")
    elseif m[1] == PAWNTOKNIGHT
        print("P$(FIELDS[m[2]])$(FIELDS[m[3]])K")
    else
        print("$(SYMBOLS[1,m[1]])$(FIELDS[m[2]])$(FIELDS[m[3]])")
    end
    
    if i % 2 == 0
        print("\n")
    else
        print(" ")
    end
end


import JSON
import FileIO

open("../browser_showoff/games/beth_vs_beth_3.json","w") do f
    write(f, JSON.json(game_strings))
end

import JLD2

JLD2.@save "backlog/21_01_05/beth_vs_markus.jld2" history
