
# does not check for stalemate
function beth_eval(board::Board, white::Bool; check_value=0., no_moves=false)
    # move off board for evaluation without kings
    white_king_pos = (-10, -10)
    black_king_pos = (-10, -10)

    white_piece_score = 0.
    black_piece_score = 0.

    white_pawn_struct = zeros(Int, 8)
    black_pawn_struct = zeros(Int, 8)

    white_most_adv_pawn = 0
    black_most_adv_pawn = 0

    white_piece_count = -1
    black_piece_count = -1

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
            white_piece_count += 1
        elseif board[rank,file,BLACK]
            black_piece_score += board[rank,file,PAWN] * 1 + (board[rank,file,KNIGHT] + board[rank,file,BISHOP]) * 3 + board[rank,file,ROOK] * 5 + board[rank,file,QUEEN] * 9
            black_piece_count += 1
        end

        if board[rank,file,PAWN]
            if board[rank,file,WHITE]
                white_most_adv_pawn = max(white_most_adv_pawn, rank)
                white_pawn_struct[file] += 1
            else
                black_most_adv_pawn = min(black_most_adv_pawn, rank)
                black_pawn_struct[file] += 1
            end
        end
    end

    piece_count = white_piece_count + black_piece_count
    piece_score = white_piece_score - black_piece_score

    white_in_check = is_attacked(board, WHITE, BLACK, white_king_pos)
    black_in_check = is_attacked(board, BLACK, WHITE, black_king_pos)

    if no_moves
        if white_in_check
            return -1000. # checkmate
        elseif black_in_check
            return 1000. # checkmate
        else
            return 0. # stalemate
        end
    end

    check_score = 0.
    check_score += white_in_check ? -check_value : 0.
    check_score += black_in_check ? check_value : 0.

    # king endgame
    if white
        if black_piece_count - sum(black_pawn_struct) == 0
            if white_piece_count ≤ 1 && !any(board[:,:,[ROOK, QUEEN]] .& board[:,:,WHITE])
                return 0 # theoretical draw
            end
            # only black king and pawns
            corner_distance = min(
                maximum(abs.(black_king_pos .- (1,1))),
                maximum(abs.(black_king_pos .- (1,8))),
                maximum(abs.(black_king_pos .- (8,1))),
                maximum(abs.(black_king_pos .- (8,8))))
            king_distance = sum(abs.(black_king_pos .- white_king_pos))
            return 8 - corner_distance + 8 - king_distance + piece_score
        end
    else
        if white_piece_count - sum(white_pawn_struct) == 0
            if black_piece_count ≤ 1 && !any(board[:,:,[ROOK, QUEEN]] .& board[:,:,BLACK])
                return 0 # theoretical draw
            end
            # only white king and pawns
            corner_distance = min(
                sum(abs.(white_king_pos .- (1,1))),
                sum(abs.(white_king_pos .- (1,8))),
                sum(abs.(white_king_pos .- (8,1))),
                sum(abs.(white_king_pos .- (8,8))))
            king_distance = sum(abs.(black_king_pos .- white_king_pos))
            return -(8 - corner_distance + 8 - king_distance) + piece_score
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

    white_extended_center_score = sum(board[3:6,3:6,WHITE])
    black_extended_center_score = sum(board[3:6,3:6,BLACK])

    # more importance to center
    center_score = (white_center_score - black_center_score) + (white_extended_center_score - black_extended_center_score)


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

    white_king_score = 0.
    black_king_score = 0.

    if piece_count - sum(white_pawn_score) - sum(black_pawn_struct) > 4
        # score doubled pawns as 1
        # penalize no pawn in front of king
        r, f = white_king_pos
        if f ≤ 3 && r < 8
            white_king_score += sum(min.(1, sum(board[r+1:min(8,r+2), 1:3, PAWN] .& board[r+1:r+2, 1:3, WHITE], dims=1)))
        elseif f ≥ 7 && r < 8
            white_king_score += sum(min.(1, sum(board[r+1:min(8,r+2), 6:8, PAWN] .& board[r+1:r+2, 6:8, WHITE], dims=1)))
        end
        white_king_score -= !all(board[r+1, f, [WHITE,PAWN]])

        r, f = black_king_pos
        if f ≤ 3 && r > 1
            black_king_score += sum(min.(1, sum(board[max(1,r-2):r-1, 1:3, PAWN] .& board[r-2:r-1, 1:3, BLACK], dims=1)))
        elseif f ≥ 7 && r > 1
            black_king_score += sum(min.(1, sum(board[max(1,r-2):r-1, 6:8, PAWN] .& board[r-2:r-1, 6:8, BLACK], dims=1)))
        end
        black_king_score -= !all(board[r-1, f, [BLACK,PAWN]])
    end

    king_score = white_king_score - black_king_score # ∈ [-3,3]

    white_pawn_adv_score = 0.
    black_pawn_adv_score = 0.

    if piece_count - sum(white_pawn_score) - sum(black_pawn_struct) ≤ 4
        white_pawn_adv_score = white_most_adv_pawn - 4 # ∈ [-2, 4]
        black_pawn_adv_score = 8-black_pawn_adv_score+1 - 4 # ∈ [-2, 4]
    end

    pawn_adv_score = white_pawn_adv_score - black_pawn_adv_score

    score = piece_score +
        1 * check_score +
        0.1 * pawn_score +
        0.1 * center_score +
        0.1 * development_score +
        0.5 * king_score +
        0.1 * pawn_adv_score

    return score
end



function beth_rank_moves(board::Board, white::Bool, ms::Vector{Move})
    ranked_moves = []

    player = 7 + !white
    opponent = 7 + white

    pawn_endgame = sum(board[:,:,opponent]) == 1 && sum(board[:,:,PAWN]) > 0
    check_value = pawn_endgame ? 0. : 30.

    for (p, rf1, rf2) in ms
        cap, enp, cas = move!(board, white, p, rf1, rf2)
        v = beth_eval(board, !white, check_value=check_value)
        if pawn_endgame && p == PAWN
            v += white ? 3 : -1
        end
        push!(ranked_moves, (v, (p, rf1, rf2)))
        undo!(board, white, p, rf1, rf2, cap, enp, cas)
    end

    return ranked_moves
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


# board = Board(false, false)
# board.position[cartesian("d1")..., [BLACK, KING]] .= 1
# board.position[cartesian("d8")..., [WHITE, KING]] .= 1
# # board.position[cartesian("h3")..., [WHITE, KNIGHT]] .= 1
# board.position[cartesian("h2")..., [WHITE, QUEEN]] .= 1
#
#
# beth_eval(board, true)
#
# print_board(board)

board = Board(false, false)

board.position[cartesian("b1")..., [BLACK, KING]] .= 1
board.position[cartesian("b3")..., [WHITE, KING]] .= 1
board.position[cartesian("c3")..., [WHITE, QUEEN]] .= 1

get_moves(board, false)

beth_eval(board, false, no_moves=true)
board.position[cartesian("h1")..., [WHITE, QUEEN]] .= 1

beth_eval(board, false, no_moves=true)
