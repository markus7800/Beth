function key_3_men(board::Board, white::Bool)
    white_count = n_pieces(board, true)
    black_count = n_pieces(board, false)

    if white_count + black_count > 3
        return "", false
    end

    player = white
    opponent = !white

    player_king = ""
    opponent_king = ""
    player_piece = ""
    opponent_piece = ""

    for rank in 1:8, file in 1:8
        _rank = black_count == 2 ? 8 - rank + 1 : rank # flip rank to get blacks perspective
        field = Field(rank, file)
        _field = Field(_rank, file)

        if is_occupied(board, player, field)
            p = get_piece(board, field)

            if p == KING
                player_king = 'K' * tostring(_field)
            elseif p == PAWN
                player_piece = 'P' * tostring(_field)
            elseif p == ROOK
                player_piece = 'R' * tostring(_field)
            elseif p == QUEEN
                player_piece = 'Q' * tostring(_field)
            end
        elseif is_occupied(board, opponent, field)
            p = get_piece(board, field)

            if p == KING
                opponent_king = 'K' * tostring(_field)
            elseif p == PAWN
                opponent_piece = 'P' * tostring(_field)
            elseif p == ROOK
                opponent_piece = 'R' * tostring(_field)
            elseif p == QUEEN
                opponent_piece = 'Q' * tostring(_field)
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

const TableBase = Dict{String, Int}
function tb_3_men_lookup(mates::Dict{String,Int}, desperate_positions::Dict{String,Int}, board::Board, white::Bool)::Tuple{Int,Bool}
    key, is_3_men = key_3_men(board, white)
    if is_3_men
        mult = white ? 1 : -1
        win_in = get(mates, key, NaN)
        # add 100 to avoid other found mates as this is fastest
        if !isnan(win_in)
            return (WHITE_MATE + 100 - win_in) * mult, true
        end

        lose_in = get(desperate_positions, key, NaN)
        if !isnan(lose_in)
            return (WHITE_MATE + 100 - lose_in) * -mult, true
        end

        # draw
        return 0, true

    else
        return 0, false
    end
end
