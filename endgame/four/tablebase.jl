
include("table.jl")


function tb_key_4_men(board::Board, white::Bool)
    white_count = n_pieces(board, true)
    black_count = n_pieces(board, false)

    if white_count + black_count > 4
        return ""
    end

    if white_count + black_count == 3
        if white && white_count == 2 && black_count == 1
            return "3_men"
        end
        if !white && white_count == 1 && black_count == 2
            return "3_men"
        end
        return ""
    end

    player_king = ""
    opponent_king = ""
    player_piece = String[]
    opponent_piece = String[]

    player_str = "K"
    player_str *= PIECE_SYMBOLS[BISHOP] ^ n_bishops(board, white)
    player_str *= PIECE_SYMBOLS[KNIGHT] ^ n_knights(board, white)
    player_str *= PIECE_SYMBOLS[ROOK] ^ n_rooks(board, white)
    player_str *= PIECE_SYMBOLS[QUEEN] ^ n_queens(board, white)
    player_str *= PIECE_SYMBOLS[QUEEN] ^ n_pawns(board, white)

    opponent_str = "K"
    opponent_str *= PIECE_SYMBOLS[BISHOP] ^ n_bishops(board, !white)
    opponent_str *= PIECE_SYMBOLS[KNIGHT] ^ n_knights(board, !white)
    opponent_str *= PIECE_SYMBOLS[ROOK] ^ n_rooks(board, !white)
    opponent_str *= PIECE_SYMBOLS[QUEEN] ^ n_queens(board, !white)
    opponent_str *= PIECE_SYMBOLS[QUEEN] ^ n_pawns(board, !white)

    return player_str * opponent_str
end

struct TableBases
    d::Dict{String, TableBase}
    function TableBases(keys::Vector{String})
        tbs = new(Dict{String, TableBase}())
        for key in keys
            tbs.d[key] = TableBase(key)
        end
        return tbs
    end
end

function TableBase(key::String)
    mates = FileIO.load("endgame/four/tb/tb_$(lowercase(key)).jld2", "mates")
    dps = FileIO.load("endgame/four/tb/tb_$(lowercase(key)).jld2", "dps")

    if key == "3_men"
        tb = ThreeMenTB(mates, dps)
        return tb
    end

    _, player, opponent = split(key, "K")
    if length(player) == 2 && length(opponent) == 0
        piece1 = PIECES[player[1]]
        piece2 = PIECES[player[2]]
        tb = FourMenTB2v0(piece1, piece2, mates, dps)
        return tb
    end
    if length(player) == 1 && length(opponent) == 1
        piece1 = PIECES[player[1]]
        piece2 = PIECES[opponent[1]]
        tb = FourMenTB1v1(piece1, piece2, mates, dps)
        return tb
    end
end

const WHITE_MATE = 1000 * 100
function tb_4_men_lookup(tbs::TableBases, board::Board, white::Bool)::Tuple{Int,Bool}
    if n_pieces(board) > 4
        return false, 0
    end

    found_key = false
    mult = white ? 1 : -1

    key = tb_key_4_men(board, white)
    if haskey(tbs.d, key)
        # tb is from players perspective materialwise
        tb = tbs.d[key]
        if white
            # println("white to move, no flip")
            board_key = tb.key(board)
        else
            # println("black to move, flip")
            # tb are from whites perspective
            # turn black pieces to white (draw/winning position)
            flipped_board = flip_colors(board)
            board_key = tb.key(flipped_board)
        end

        if haskey(tb.mates, board_key)
            # println("mate")
            win_in = tb.mates[board_key]
            return (WHITE_MATE - win_in*100) * mult, true
        end

        found_key = true
    end

    key = tb_key_4_men(board, !white)
    if haskey(tbs.d, key)
        # tb is from opponent perspective materialwise
        tb = tbs.d[key]
        if white
            # println("white to move, flip")
            # tb are from whites perspective
            # turn white pieces to black (draw/losing position)
            flipped_board = flip_colors(board)
            board_key = tb.key(flipped_board)
        else
            # println("black to move, no flip")
            board_key = tb.key(board)
        end

        if haskey(tb.desperate_positions, board_key)
            lose_in = tb.desperate_positions[board_key]
            return (WHITE_MATE - lose_in*100) * -mult, true
        end

        found_key = true
    end

    # draw
    return 0, found_key # underpromotions to mate not considered
end

function flip_colors(board::Board)
    flipped_board = Board()
    # does not regard en passant & castle
    for field_number in board.whites
        rank, file = rankfile(field_number)
        rank = 8 - rank + 1
        field = Field(rank, file)
        set_piece!(flipped_board, field, false, get_piece(board, tofield(field_number)))
    end
    for field_number in board.blacks
        rank, file = rankfile(field_number)
        rank = 8 - rank + 1
        field = Field(rank, file)
        set_piece!(flipped_board, field, true, get_piece(board, tofield(field_number)))
    end
    return flipped_board
end

# tbs = TableBases(["3_men", "KRKN"])
#
# m28 = Board("8/8/8/1k6/8/8/K5P1/8 w - - 0 1")
# get_mate(tbs.d["3_men"], m28)
#
# tb_4_men_lookup(tbs, m28, true)
#
#
# dp_not_m = Board("8/8/8/4k3/8/4K3/4P3/8 w - - 0 1")
#
# tb_4_men_lookup(tbs, dp_not_m, false)
# tb_4_men_lookup(tbs, dp_not_m, true)
#
# m_not_dp = Board("8/8/8/4k3/8/3K4/4P3/8 w - - 0 1")
#
# tb_4_men_lookup(tbs, m_not_dp, false)
# tb_4_men_lookup(tbs, m_not_dp, true)
#
#
# dp_not_m = flip_colors(Board("8/8/8/4k3/8/4K3/4P3/8 w - - 0 1"))
#
# tb_4_men_lookup(tbs, dp_not_m, false)
# tb_4_men_lookup(tbs, dp_not_m, true)
#
# m_not_dp = flip_colors(Board("8/8/8/4k3/8/3K4/4P3/8 w - - 0 1"))
#
# tb_4_men_lookup(tbs, m_not_dp, false)
# tb_4_men_lookup(tbs, m_not_dp, true)
#
# m40 = Board("8/2R5/8/8/7k/3K4/8/4n3 w - - 0 1")
#
# tb_4_men_lookup(tbs, m40, false)
