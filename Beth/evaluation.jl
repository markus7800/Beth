
# does not check for stalemate
function beth_eval(board::Board, unused::Bool, check_value=0.)
    # move off board for evaluation without kings
    white_king_pos = (-10, -10)
    black_king_pos = (-10, -10)

    white_piece_score = 0.
    black_piece_score = 0.

    white_pawn_struct = zeros(Int, 8)
    black_pawn_struct = zeros(Int, 8)

    piece_count = 0
    for rank in 1:8, file in 1:8
        if board[rank,file,KING]
            if board[rank,file,WHITE]
                white_king_pos = (rank, file)
            else
                black_king_pos = (rank, file)
            end
        end

        if board[rank,file,WHITE]
            white_piece_score += board[rank,file,PAWN] * 1 + (board[rank,file,KNIGHT] + board[rank,file,BISHOP]) * 3 + board[rank,file,ROOK] * 5 + board[rank,file,QUEEN] * 9
            piece_count += 1
        elseif board[rank,file,BLACK]
            black_piece_score += board[rank,file,PAWN] * 1 + (board[rank,file,KNIGHT] + board[rank,file,BISHOP]) * 3 + board[rank,file,ROOK] * 5 + board[rank,file,QUEEN] * 9
            piece_count += 1
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

    white_in_check = is_attacked(board, WHITE, BLACK, white_king_pos)
    black_in_check = is_attacked(board, BLACK, WHITE, black_king_pos)

    check_score = 0.
    if white_in_check
        if length(get_moves(board, true)) == 0
            return -1000. # checkmate
        else
            check_score += -check_value
        end
    end
    if black_in_check
        if length(get_moves(board, false)) == 0
            return 1000. # checkmate
        else
            check_score += check_value
        end
    end


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

    # TODO: king safety
    white_king_score = 0.
    black_king_score = 0.

    white_king_score += all(board[1, 3, [KING,WHITE]]) || all(board[1, 7, [KING,WHITE]])
    black_king_score += all(board[8, 3, [KING,BLACK]]) || all(board[8, 7, [KING,BLACK]])


    king_score = white_king_score - black_king_score

    score = piece_score +
        1 * check_score +
        0.1 * pawn_score +
        0.1 * center_score +
        0.1 * development_score +
        0.5 * king_score

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
    return current_score
end

# using BenchmarkTools
#
# board = Board(true)
# @btime simple_piece_count(board, true) # 26.599 μs (392 allocations: 18.50 KiB)
# @btime beth_eval(board, true) # 28.099 μs (434 allocations: 21.83 KiB)
# # 25-30 μs on Desktop for both simple_piece_count and beth_eval
# ms = get_moves(board, true)
# @btime rank_moves(board, true, ms) # 57.600 μs (721 allocations: 25.83 KiB)
# @btime beth_rank_moves(board, true, ms) # 584.100 μs (8805 allocations: 444.05 KiB)
#
#
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
#
#
# board = Board(false)
# board.position[4:5,4:5, [QUEEN, WHITE]] .= 1
# board.position[4,4, [QUEEN, WHITE]] .= 0
# board.position[4,4, [QUEEN, BLACK]] .= 1
# board.position[1,1, [KING, WHITE]] .= 1
#
# beth_eval(board, true, 30)
#
# print_board(board)
