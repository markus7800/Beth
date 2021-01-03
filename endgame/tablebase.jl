import JLD

function key_3_men(board::Board, white::Bool)
    player = 7 + !white
    opponent = 7 + white

    player_king = ""
    opponent_king = ""
    player_piece = ""
    opponent_piece = ""

    piece_count = 0
    for rank in 1:8, file in 1:8
        if board[rank, file, player]
            if board[rank, file, KING]
                player_king = 'K' * field(rank, file)
            elseif board[rank, file, PAWN]
                player_piece = 'P' * field(rank, file)
            elseif board[rank, file, ROOK]
                player_piece = 'R' * field(rank, file)
            elseif board[rank, file, QUEEN]
                player_piece = 'Q' * field(rank, file)
            end
            piece_count += 1
        elseif board[rank, file, opponent]
            if board[rank, file, KING]
                opponent_king = 'K' * field(rank, file)
            elseif board[rank, file, PAWN]
                opponent_piece = 'P' * field(rank, file)
            elseif board[rank, file, ROOK]
                opponent_piece = 'R' * field(rank, file)
            elseif board[rank, file, QUEEN]
                opponent_piece = 'Q' * field(rank, file)
            end
            piece_count += 1
        end
    end

    key = player_king * player_piece * opponent_king * opponent_piece
    return key, piece_count == 3
end

function slimify(all_mates, all_desperate_positions)
    slim_mates = Dict{String, Int}()
    for (mate, i) in all_mates
        key, is_3_men = key_3_men(mate, true) # white to move
        @assert is_3_men
        slim_mates[key] = i
    end

    slim_desperate_positions = Dict{String, Int}()
    for (mate, i) in all_desperate_positions
        key, is_3_men = key_3_men(mate, false) # black to move
        @assert is_3_men
        slim_desperate_positions[key] = i
    end

    return slim_mates, slim_desperate_positions
end

import FileIO
function load_3_men_tablebase()
    return FileIO.load("endgame/tb3men.jld2", "mates", "desperate_positions")
end

load_3_men_tablebase()
