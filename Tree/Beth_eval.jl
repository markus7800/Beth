
function beth_eval(board::Board, white::Bool, check_mult=0)
    multiplier = white ? -1 : 1

    player = 7 + !white
    opponent = 7 + white


    white_piece_score = 0.
    black_piece_score = 0.

    king_pos = (0, 0)
    white_pawn_struct = zeros(Int, 8)
    black_pawn_struct = zeros(Int, 8)

    for rank in 1:8, file in 1:8
        if board[rank,file,KING] && board[rank,file,player]
            king_pos = (rank, file)
        end
        if board[rank,file,WHITE]
            white_piece_score += board[rank,file,PAWN] * 1 + (board[rank,file,KNIGHT] + board[rank,file,BISHOP]) * 3 + board[rank,file,ROOK] * 5 + board[rank,file,QUEEN] * 9
        elseif board[rank,file,BLACK]
            black_piece_score += board[rank,file,PAWN] * 1 + (board[rank,file,KNIGHT] + board[rank,file,BISHOP]) * 3 + board[rank,file,ROOK] * 5 + board[rank,file,QUEEN] * 9
        end

        if board[rank,file,PAWN]
            if board[rank,file,WHITE]
                white_pawn_struct[file] += 1
            else
                black_pawn_struct[file] += 1
            end
        end
    end

    piece_score = white_piece_score - black_piece_score

    check = is_attacked(board, player, opponent, king_pos)
    ms = get_moves(board, white)

    check_score = 0.
    if length(ms) == 0
        if check
            # checkmate
            check_score = 1000. * multiplier
        else
            # stalemate
            check_score = 0.
        end
    elseif check
        check_score = multiplier * check_mult
    end

    mobility_score = length(ms) * multiplier

    white_pawn_score = 0.
    black_pawn_score = 0.

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


    white_center_score = sum(board[4:5,4:5,WHITE])
    black_center_score = sum(board[4:5,4:5,BLACK])

    center_score = white_center_score - black_center_score


    white_development_score = -sum(board[1, [2,3,6,7], [BISHOP, KNIGHT]] .& board[1, [2,3,6,7], WHITE])
    white_development_score -= sum(board[2, [4,5], PAWN] .& board[2, [4,5], WHITE])
    black_development_score = -sum(board[8, [2,3,6,7], [BISHOP, KNIGHT]] .& board[8, [2,3,6,7], BLACK])
    black_development_score -= sum(board[7, [4,5], PAWN] .& board[7, [4,5], BLACK])

    development_score = white_development_score - black_development_score

    # @info("piece_score: $piece_score, $white_piece_score, $black_piece_score") # 39 at beginning
    # @info("check_score: $check_score") # ∈ ±{1, 1000}
    # @info("pawn_score: $pawn_score, $white_pawn_score, $black_pawn_score") # ∈ [-16, 16] each ∈ [-8, 8] all isolated to all passers
    # @info("center_score: $center_score, $white_center_score, $black_center_score") # ∈ [-8, 8] each ∈ [-4,4]
    # @info("development_score: $development_score, $white_development_score, $black_development_score") # ∈ [-12, 12] each ∈ [-6,6]

    score = piece_score +
        1 * check_score +
        # 0.1 * mobility_score +
        0.1 * pawn_score +
        0.1 * center_score +
        0.1 * development_score

    return score
end



function beth_rank_moves(board::Board, white::Bool, ms::Vector{Move})
    ranked_moves = []
    for (p, rf1, rf2) in ms
        # println((p, rf1, rf2))
        # print_board(board, white=white)
        # println()
        cap, enp, cas = move!(board, white, p, rf1, rf2)
        push!(ranked_moves, (beth_eval(board, !white, 30), (p, rf1, rf2)))
        undo!(board, white, p, rf1, rf2, cap, enp, cas)
    end
    return ranked_moves
end

# only use for leaf nodes
function beth_eval_til_quite(board::Board, white::Bool)
    current_score = beth_eval(board, white)
    while true
        ms = get_moves(board, white)
        length(ms) == 0 && break

        rms = beth_rank_moves(board, white, ms)

        score, m = white ? maximum(rms) : minimum(rms)
        # @info "current: $current_score, move: $m, score: $score"
        abs(current_score - score) < 1 && break


        move!(board, white, m[1], m[2], m[3])
        current_score = score
        white = !white
    end
end

# 25-30 μs on Desktop for both simple_piece_count and beth_eval
# board = Board(true)
# @btime simple_piece_count(board, true)
# @btime beth_eval(board, true)

# beth_eval(Board(true), true)
#
# board = Board(false)
# board.position[2,:,[PAWN,WHITE]] .= 1
# beth_eval(board, true)
#
# board.position[[7,6],[1,3,5,7],[PAWN,BLACK]] .= 1
# beth_eval(board, true)
#
# board = Board(false)
# board.position[4:5,4:5, [QUEEN, WHITE]] .= 1
# board.position[4,4, [QUEEN, WHITE]] .= 0
# board.position[4,4, [QUEEN, BLACK]] .= 1
# beth_eval(board, true)
