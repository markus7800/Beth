include("../chess/chess.jl")

function generate_2_piece_boards()
    boards = Board[]
    black_king_positions = ["a1", "b1", "c1", "d1", "b2", "c2", "d2", "c3", "d3", "d4"]

    for bk_pos in black_king_positions
        bk_cart = cartesian(bk_pos)
        used_positions = [bk_cart]
        for wk_r in 1:8, wk_f in 1:8
            (wk_r, wk_f) in used_positions && continue
            max(abs(wk_r - bk_cart[1]), abs(wk_f - bk_cart[2])) ≤ 1 && continue

            push!(used_positions, (wk_r, wk_f))
            for p in [ROOK, QUEEN], wp1_r in 1:8, wp1_f in 1:8
                (wp1_r, wp1_f) in used_positions && continue

                board = Board(false)
                board.position[bk_cart..., [BLACK, KING]] .= 1
                board.position[wk_r, wk_f, [WHITE, KING]] .= 1
                board.position[wp1_r, wp1_f, [WHITE, p]] .= 1

                push!(boards, board)

                @assert is_valid(board)
            end
        end
    end

    return boards
end

# finds all positions where black king is mated
function find_mates(boards::Vector{Board})
    mates = Board[]
    for board in boards
        if is_in_check(board, BLACK) && length(get_moves(board, false)) == 0
            push!(mates, board)
        end
    end
    return mates
end


two_piece = generate_2_piece_boards()

board = find_mates(two_piece)[1]

board = Board(false)

board.position[1,1,[BLACK, KING]] .= 1
board.position[1,3,[WHITE, KING]] .= 1

println(get_reverse_moves(board, true))
