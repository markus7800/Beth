
function FEN(board::Board, white::Bool)
    first_group = ""
    count = 0
    for rank in 8:-1:1
        for file in 1:8
            if any(board[rank, file, [WHITE, BLACK]])
                if count > 0
                    first_group *= string(count)
                    count = 0
                end
                p = findfirst(board[rank, file, 1:6])
                p = SYMBOLS[1, p]
                if board[rank, file, BLACK]
                    p = lowercase(p)
                end

                first_group *= p
            else
                count += 1
            end
        end
        if !(any(board[rank, 8, [WHITE, BLACK]]))
            first_group *= string(count)
        end
        count = 0

        if rank != 1
            first_group *= "/"
        end
    end

    second_group = white ? "w" : "b"

    third_group = ""
    if board.can_castle[2, SHORTCASTLE]
        third_group *= "K"
    end
    if board.can_castle[2, LONGCASTLE]
        third_group *= "Q"
    end

    if board.can_castle[1, SHORTCASTLE]
        third_group *= "k"
    end
    if board.can_castle[1, LONGCASTLE]
        third_group *= "q"
    end

    if third_group == ""
        third_group = "-"
    end

    fourth_group = "-"
    if any(board.can_en_passant)
        r, f = Tuple(findfirst(board.can_en_passant))
        f = white ? 6 : 3
        fourth_group = field(r, f)
    end

    return first_group * " " * second_group * " " * third_group * " " * fourth_group * " 0 1"
end


println("'" ,FEN(history[1].board, history[1].white), "',")
for ply in history[2:end]
    println("'" * field(ply.move[2]) * "-" * field(ply.move[3]), "',")
end

game_strings = String[]
for ply in history
    println("'" ,FEN(ply.board, ply.white), "',")
    push!(game_strings, FEN(ply.board, ply.white))
end


import JSON
import FileIO

open("../browser_showoff/games/beth_vs_beth_3.json","w") do f
    write(f, JSON.json(game_strings))
end

import JLD2

JLD2.@save "backlog/21_01_05/beth_vs_markus.jld2" history
