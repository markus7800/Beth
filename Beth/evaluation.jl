const PIECE_VALUES = [1, 3, 3, 5, 9]
const MAX_VALUE = 1_000_000
const MIN_VALUE = -1_000_000
const WHITE_MATE = 100_000
const BLACK_MATE = -100_000

function piece_value(p)
    @inbounds PIECE_VALUES[p]
end

function pawn_struct(pawns::Fields)
    (count_ones(pawns & FILE_A),
    count_ones(pawns & FILE_B),
    count_ones(pawns & FILE_C),
    count_ones(pawns & FILE_D),
    count_ones(pawns & FILE_E),
    count_ones(pawns & FILE_F),
    count_ones(pawns & FILE_G),
    count_ones(pawns & FILE_H)
    )
end

const CENTER = Field("d4") | Field("e4") |
                Field("d5") |  Field("e5")
const EXTENDED_CENTER = Field("c3") | Field("d3") | Field("e3") | Field("f3") |
                        Field("c4") | Field("d4") | Field("e4") | Field("f4") |
                        Field("c5") | Field("d5") | Field("e5") | Field("f5") |
                        Field("c6") | Field("d6") | Field("e6") | Field("f6")

const WHITE_PIECE_DEV_FIELDS = Field("b1") | Field("c1") | Field("f1") | Field("g1")
const WHITE_PAWN_DEV_FIELDS = Field("d2") | Field("e2")

const BLACK_PIECE_DEV_FIELDS = Field("b8") | Field("c8") | Field("f8") | Field("g8")
const BLACK_PAWN_DEV_FIELDS = Field("d7") | Field("e7")

const KING_SHIELD = Field("a1") | Field("b1") | Field("c1") | Field("f1") | Field("g1") | Field("h1")


function white_pawn_adv(pawns::Fields)::Int
    if count_ones(pawns) == 0
        return 0
    end
    if pawns & RANK_7 > 0
        return 7
    end
    if pawns & RANK_6 > 0
        return 6
    end
    if pawns & RANK_5 > 0
        return 5
    end
    if pawns & RANK_4 > 0
        return 4
    end
    if pawns & RANK_3 > 0
        return 3
    end

    return 2
end

function black_pawn_adv(pawns::Fields)::Int
    if count_ones(pawns) == 0
        return 0
    end
    if pawns & RANK_2 > 0
        return 2
    end
    if pawns & RANK_3 > 0
        return 3
    end
    if pawns & RANK_4 > 0
        return 4
    end
    if pawns & RANK_5 > 0
        return 5
    end
    if pawns & RANK_6 > 0
        return 6
    end

    return 7
end

function evaluation(board::Board, white::Bool; check_value::Int=0, no_moves::Bool=false)::Int
    # move off board for evaluation without kings
    white_king_pos = rankfile(board.kings & board.whites)
    black_king_pos = rankfile(board.kings & board.blacks)

    white_n_pawns = n_pawns(board, true)
    black_n_pawns = n_pawns(board, false)

    white_piece_score = piece_value(PAWN) * white_n_pawns +
                        piece_value(KNIGHT) * n_knights(board, true) +
                        piece_value(BISHOP) * n_bishops(board, true) +
                        piece_value(ROOK) * n_rooks(board, true) +
                        piece_value(QUEEN) * n_queens(board, true)

    black_piece_score  = piece_value(PAWN) * black_n_pawns +
                        piece_value(KNIGHT) * n_knights(board, false) +
                        piece_value(BISHOP) * n_bishops(board, false) +
                        piece_value(ROOK) * n_rooks(board, false) +
                        piece_value(QUEEN) * n_queens(board, false)


    white_piece_count = n_pieces(board, true) - 1
    black_piece_count = n_pieces(board, false) - 1

    white_pawn_struct = pawn_struct(board.pawns & board.whites)
    black_pawn_struct = pawn_struct(board.pawns & board.blacks)

    white_most_adv_pawn = white_pawn_adv(board.pawns & board.whites)
    black_most_adv_pawn = black_pawn_adv(board.pawns & board.blacks)

    piece_count = white_piece_count + black_piece_count
    piece_score = white_piece_score - black_piece_score

    white_in_check = is_in_check(board, true)
    black_in_check = is_in_check(board, false)

    if no_moves
        if white_in_check
            return BLACK_MATE # checkmate
        elseif black_in_check
            return WHITE_MATE # checkmate
        else
            return 0 # stalemate
        end
    end

    check_score = 0
    check_score += white_in_check ? -check_value : 0
    check_score += black_in_check ? check_value : 0

    # king endgame
    if white
        if black_piece_count - black_n_pawns == 0 # TODO check if white has pieces
            if white_piece_count ≤ 1 && count_pieces((board.rooks | board.queens) & board.whites) == 0
                return 0 # theoretical draw
            end
            # only black king and pawns
            corner_distance = min(
                maximum(abs.(black_king_pos .- (1,1))),
                maximum(abs.(black_king_pos .- (1,8))),
                maximum(abs.(black_king_pos .- (8,1))),
                maximum(abs.(black_king_pos .- (8,8))))
            king_distance = sum(abs.(black_king_pos .- white_king_pos))
            return (8 - corner_distance + 8 - king_distance + piece_score) * 100
        end
    else
        if white_piece_count - white_n_pawns == 0
            if black_piece_count ≤ 1 && count_pieces((board.rooks | board.queens) & board.blacks) == 0
                return 0 # theoretical draw
            end
            # only white king and pawns
            corner_distance = min(
                sum(abs.(white_king_pos .- (1,1))),
                sum(abs.(white_king_pos .- (1,8))),
                sum(abs.(white_king_pos .- (8,1))),
                sum(abs.(white_king_pos .- (8,8))))
            king_distance = sum(abs.(black_king_pos .- white_king_pos))
            return (-(8 - corner_distance + 8 - king_distance) + piece_score) * 100
        end
    end


    white_pawn_score = 0
    black_pawn_score = 0

    # doubled pawns
    white_pawn_score -= sum(white_pawn_struct .> 1)
    black_pawn_score -= sum(black_pawn_struct .> 1)

    for file in 1:8
        w_center = white_pawn_struct[file]
        b_center = black_pawn_struct[file]

        w_left = 0; w_right = 0

        b_left = 0; b_right = 0

        if file > 1
            w_left = white_pawn_struct[file-1]
            b_left = black_pawn_struct[file-1]
        end
        if file < 8
            w_right = white_pawn_struct[file+1]
            b_right = black_pawn_struct[file+1]
        end

        # penalize isolated pawns
        if w_left + w_right == 0
            white_pawn_score -= 1
        end
        if b_left + b_right == 0
            black_pawn_score -= 1
        end

        # reward passed pawns
        if b_left + b_center + b_right == 0 && w_center > 0
            white_pawn_score += 1
        end
        if w_left + w_center + w_right == 0 && b_center > 0
            black_pawn_score += 1
        end
    end

    pawn_score = white_pawn_score - black_pawn_score


    white_center_score = count_pieces(CENTER & board.whites)
    black_center_score = count_pieces(CENTER & board.blacks)

    white_extended_center_score = count_pieces(EXTENDED_CENTER & board.whites)
    black_extended_center_score = count_pieces(EXTENDED_CENTER & board.blacks)

    # more importance to center
    center_score = (white_center_score - black_center_score) + (white_extended_center_score - black_extended_center_score)


    white_development_score = -count_pieces((board.knights | board.bishops) & board.whites & WHITE_PIECE_DEV_FIELDS)
    white_development_score -= count_pieces(board.pawns & board.whites & WHITE_PAWN_DEV_FIELDS)

    black_development_score = -count_pieces((board.knights | board.bishops) & board.blacks & BLACK_PIECE_DEV_FIELDS)
    black_development_score -= count_pieces(board.pawns & board.blacks & BLACK_PAWN_DEV_FIELDS)

    development_score = white_development_score - black_development_score

    white_king_score = 0
    black_king_score = 0

    if piece_count - white_n_pawns - black_n_pawns > 4
        # score doubled pawns as 1
        # penalize no pawn in front of king
        r, f = white_king_pos
        if r == 1
            s1 = KING_SHIELD << (8 * r)
            s2 = KING_SHIELD << (8 * min(8,r+1))
            shield = (s1 | s2) & board.pawns & board.whites
            shield_struct = pawn_struct(shield)
            if f ≤ 3
                white_king_score += 0 # sum(shield_struct[1:3] .!= 0)
            elseif f ≥ 7
                white_king_score += sum(shield_struct[6:8] .!= 0)
            end
        end

        r, f = black_king_pos
        if r == 8
            s1 = KING_SHIELD << (8*(r-2))
            s2 = KING_SHIELD << (8 * (max(1,r-1)-2))
            shield = (s1 | s2) & board.pawns & board.blacks
            shield_struct = pawn_struct(shield)
            if f ≤ 3
                black_king_score += 0 # sum(shield_struct[1:3] .!= 0)
            elseif f ≥ 7
                black_king_score += sum(shield_struct[6:8] .!= 0)
            end
        end
    end

    king_score = white_king_score - black_king_score # ∈ [-3,3]

    white_pawn_adv_score = 0
    black_pawn_adv_score = 0

    if piece_count - white_n_pawns - black_n_pawns ≤ 4
        white_pawn_adv_score = white_most_adv_pawn - 4 # ∈ [-2, 4]
        black_pawn_adv_score = 8-black_pawn_adv_score+1 - 4 # ∈ [-2, 4]
    end

    pawn_adv_score = white_pawn_adv_score - black_pawn_adv_score


    # @info("piece_score: $piece_score, $white_piece_score, $black_piece_score") # 39 at beginning
    # @info("check_score: $check_score") # ∈ ±{1, 1000}
    # @info("pawn_score: $pawn_score, $white_pawn_score, $black_pawn_score") # ∈ [-16, 16] each ∈ [-8, 8] all isolated to all passers
    # @info("center_score: $center_score, $white_center_score, $black_center_score") # ∈ [-8, 8] each ∈ [-4,4]
    # @info("development_score: $development_score, $white_development_score, $black_development_score") # ∈ [-12, 12] each ∈ [-6,6]
    # @info("king_score: $development_score, $white_king_score, $black_king_score")
    # @info("pawn_adv_score: $pawn_adv_score, $white_pawn_adv_score, $black_pawn_adv_score")


    score = 100 * piece_score +
        100 * check_score +
        10 * pawn_score +
        10 * center_score +
        10 * development_score +
        50 * king_score +
        10 * pawn_adv_score

    return score
end

# TODO: guestimate value change
function rank_moves_by_eval(board::Board, white::Bool, ms::MoveList)::Vector{Tuple{Int,Move}}
    ranked_moves = Vector{Tuple{Int,Move}}(undef, length(ms))

    player = 7 + !white
    opponent = 7 + white

    pawn_endgame = n_pieces(board, !white) == 1 && n_pawns(board, white) > 0
    check_value = pawn_endgame ? 0 : 30

    for (i,m) in enumerate(ms)
        undo = make_move!(board, white, m)
        v = evaluation(board, !white, check_value=check_value)
        if pawn_endgame && m.from_piece == PAWN
            v += white ? 3 : -1
        end
        ranked_moves[i] = (v, m)
        undo_move!(board, white, m, undo)
    end

    return ranked_moves
end
