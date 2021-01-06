function key_3_men(board::Board, white::Bool)
    player = 7 + !white
    opponent = 7 + white

    player_king = ""
    opponent_king = ""
    player_piece = ""
    opponent_piece = ""

    white_count = sum(board[:,:,WHITE])
    black_count = sum(board[:,:,BLACK])
    if white_count + black_count > 3
        return "", false
    end

    for rank in 1:8, file in 1:8
        _rank = black_count == 2 ? 8 - rank + 1 : rank # flip rank to get blacks perspective
        if board[rank, file, player]
            if board[rank, file, KING]
                player_king = 'K' * field(_rank, file)
            elseif board[rank, file, PAWN]
                player_piece = 'P' * field(_rank, file)
            elseif board[rank, file, ROOK]
                player_piece = 'R' * field(_rank, file)
            elseif board[rank, file, QUEEN]
                player_piece = 'Q' * field(_rank, file)
            end
        elseif board[rank, file, opponent]
            if board[rank, file, KING]
                opponent_king = 'K' * field(_rank, file)
            elseif board[rank, file, PAWN]
                opponent_piece = 'P' * field(_rank, file)
            elseif board[rank, file, ROOK]
                opponent_piece = 'R' * field(_rank, file)
            elseif board[rank, file, QUEEN]
                opponent_piece = 'Q' * field(_rank, file)
            end
        end
    end

    key = player_king * player_piece * opponent_king * opponent_piece
    return key, true
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

function tb_3_men_lookup(mates::Dict{String,Int}, desperate_positions::Dict{String,Int}, board::Board, white::Bool)
    key, is_3_men = key_3_men(board, white)
    mult = white ? 1 : -1
    if is_3_men
        win_in = get(mates, key, NaN)
        if !isnan(win_in)
            return (1000. - win_in) * mult, true
        end

        lose_in = get(desperate_positions, key, NaN)
        if !isnan(lose_in)
            return (1000. - lose_in) * -mult, true
        end

        # draw
        return 0., true

    else
        return NaN, false
    end
end
