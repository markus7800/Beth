include("../chess/chess.jl")

const NORMAL_KING_POSITIONS = map(cartesian, ["a1", "b1", "c1", "d1", "b2", "c2", "d2", "c3", "d3", "d4"])
function normalise_board(board)
    king_pos = (-10, -10)
    # find black king
    for r in 1:8, f in 1:8
        if board[r, f, KING] && board[r, f, BLACK]
            king_pos = (r, f)
            break
        end
    end

    rank, file = king_pos
    new_board = deepcopy(board)
    if rank > 4
        # mirror along horizontal axis
        new_board.position .= [new_board.position[r,f,p] for r in 8:-1:1, f in 1:8, p in 1:8]
        rank = 8 - rank
    end
    if file > 4
        # mirror along vertical axis
        new_board.position .= [new_board.position[r,f,p] for r in 1:8, f in 8:-1:1, p in 1:8]
        file = 8 - file
    end
    if rank > file
        # mirror along diagonal axis
        new_board.position .= [new_board.position[f,r,p] for r in 1:8, f in 1:8, p in 1:8]
    end

    return new_board
end

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

                board = Board(false, false)
                board.position[bk_cart..., [BLACK, KING]] .= 1
                board.position[wk_r, wk_f, [WHITE, KING]] .= 1
                board.position[wp1_r, wp1_f, [WHITE, p]] .= 1

                push!(boards, board)

                @assert is_valid(board)
            end

            pop!(used_positions)
        end
    end

    return boards
end

# finds all positions where black king is mated
function find_mate_positions(boards::Vector{Board})
    mates = Board[]
    for board in boards
        if is_in_check(board, BLACK) && length(get_moves(board, false)) == 0
            push!(mates, board)
        end
    end
    return mates
end

# function find_two_piece_mates()
#     two_piece = generate_2_piece_boards()
#     mates = find_mates(two_piece)
# end

# find all moves which lead to a position that is a known mate
function find_mate_position_in_1(mates::Vector{Board})
    mate_in_1 = Board[]

    for mate in mates
        rev_moves = get_reverse_moves(mate, true)
        for m in rev_moves
            board = deepcopy(mate)
            undo!(board, true, m[1], m[2], m[3], nothing, nothing, nothing)
            if !(board in mates) && !(board in mate_in_1)
                push!(mate_in_1, board)
            end
        end
    end
    return mate_in_1
end

# finds all position where all moves lead to a known mate
function find_desperate_positions(mates::Vector{Board})
    desperate_positions = Board[]

    for mate in mates
        rev_moves = get_reverse_moves(mate, false)
        for rm in rev_moves
            board = deepcopy(mate)

            # println(board)
            undo!(board, false, rm[1], rm[2], rm[3], nothing, nothing, nothing)
            # println("prev board")
            # println(board)

            board = normalise_board(board)

            if board in mates
                # println("prev board is known mate")
                continue
            end

            _board = deepcopy(board)
            # println(get_moves(_board, false))

            is_desparate = true
            for m in get_moves(_board, false) # forward moves
                move!(_board, false, m[1], m[2], m[3])

                if !(_board in mates)
                    is_desparate = false
                    break
                end

                undo!(_board, false, m[1], m[2], m[3], nothing, nothing, nothing)
            end

            # println("is desperate ", is_desparate)

            if is_desparate
                push!(desperate_positions, board)
            end
        end
    end
    return desperate_positions
end


two_piece = generate_2_piece_boards()
mps = find_mate_positions(two_piece)
mps1 = find_mate_position_in_1(find_mate_positions(two_piece))

find_desperate_positions(mps)
find_desperate_positions(mps1)


board = find_mate_in_1(two_piece)[end]
hash(board.position)
mates = find_mates(two_piece)

for mate in mates
    println(mate)
end

board = Board(false)

board.position[1,1,[BLACK, KING]] .= 1
board.position[1,3,[WHITE, KING]] .= 1

println(get_reverse_moves(board, true))


test_symmetry_board = find_desperate_positions(find_mate_positions(two_piece))[1]


board = Board(false, false)

board.position[5,8, [KING, BLACK]] .= 1

test_symmetry_board in find_mate_positions([test_symmetry_board])

test_symmetry_board in find_mate_positions(two_piece)

test_symmetry_board in two_piece
