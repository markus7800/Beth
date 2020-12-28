include("../chess/chess.jl")

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

function is_normalised(board)
    king_pos = (-10, -10)
    # find black king
    for r in 1:8, f in 1:8
        if board[r, f, KING] && board[r, f, BLACK]
            king_pos = (r, f)
            break
        end
    end
    rank, file = king_pos

    return rank ≤ 4 && file ≤ 4 && rank ≤ file
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
# input are normalised boards
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

# find all moves which lead to a position that is a known mate (desperate position for black)
# the initial mates are the first desperate positions for black
# it is sufficient to only pass in newly found desperate positions
function find_mate_position_in_1(desperate_position::Vector{Board})
    mate_in_1 = Board[]

    for mate in desperate_position
        rev_moves = get_reverse_moves(mate, true)
        for m in rev_moves
            board = deepcopy(mate)
            undo!(board, true, m[1], m[2], m[3], nothing, nothing, nothing)
            board = normalise_board(board)
            if !(board in mate_in_1)
                push!(mate_in_1, board)
            end
        end
    end
    return mate_in_1
end

function mirror_horizontally(board::Board)
    new_board = deepcopy(board)
    for r in 1:8, f in 1:8, p in 1:8
        new_board.position[r,f,p] = board.position[8-r+1, f, p]
    end
    return new_board
end
function mirror_vertically(board::Board)
    new_board = deepcopy(board)
    for r in 1:8, f in 1:8, p in 1:8
        new_board.position[r,f,p] = board.position[r,8-f+1, p]
    end
    return new_board
end
function mirror_diagonally(board::Board)
    new_board = deepcopy(board)
    for r in 1:8, f in 1:8, p in 1:8
        new_board.position[r,f,p] = board.position[f, r, p]
    end
    return new_board
end

# finds all position where all moves lead to a known mate (where white is to move)
# for all known mates go one move backward and collect all positions
# where all moves lead to a known mates
#
# Have to pass in all mates, not only new mates
# maybe a mate in 1 is avoidable but a mate in 2 not ...
function find_desperate_positions(all_mates::Vector{Board})
    desperate_positions = Board[]

    for _mate in all_mates, trafo in [identity, mirror_horizontally, mirror_vertically, mirror_diagonally]
        mate = trafo(_mate)
        rev_moves = get_reverse_moves(mate, false)
        for rm in rev_moves
            board = deepcopy(mate)

            # println(board)
            undo!(board, false, rm[1], rm[2], rm[3], nothing, nothing, nothing)
            # println("prev board")
            # println(board)

            board = normalise_board(board)

            if board in desperate_positions
                # println("prev board is known mate")
                continue
            end

            _board = deepcopy(board)
            # println(get_moves(_board, false))

            is_desparate = true
            # check if all forward moves lead to known mate
            for m in get_moves(_board, false)
                move!(_board, false, m[1], m[2], m[3])

                if !(normalise_board(_board) in all_mates)
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

function find_all_mates()
    two_piece = generate_2_piece_boards()

    desperate_positions = find_mate_positions(two_piece)
    all_desperate_positions = copy(desperate_positions)

    mates = []
    all_mates = Board[]

    for i in 1:4
        @info("Iteration $i:")
        new_mates = find_mate_position_in_1(desperate_positions)
        l = length(new_mates)
        @info("Found $l mates.")
        new_mates = setdiff(new_mates, all_mates)
        @info("New ones: $(length(new_mates))")
        push!(mates, new_mates)
        append!(all_mates, new_mates)
        @info("Currently $(length(all_mates)) mates known.")

        desperate_positions = find_desperate_positions(all_mates)
        @info("Found $(length(desperate_positions)) desperate positions.")
        desperate_positions = setdiff(desperate_positions, all_desperate_positions)
        @info("New ones: $(length(desperate_positions))")

        append!(all_desperate_positions, desperate_positions)
        @info("Currently $(length(all_desperate_positions)) desperate positions known.")

        println()
    end

    return mates
end

mates = find_all_mates()

two_piece = generate_2_piece_boards()
mps = find_mate_positions(two_piece)
mps1 = find_mate_position_in_1(find_mate_positions(two_piece))

#dp1 = find_desperate_positions(mps1)
dp2 = find_desperate_positions(mps1, mps)

find_mate_position_in_1(find_desperate_positions(mps1))

board = find_mate_in_1(two_piece)[end]
hash(board.position)
mates = find_mates(two_piece)

b = find_desperate_positions(mps1)[1]


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




mates = find_all_mates()


begin
    bfs = [Inf,Inf,Inf, Inf, Inf, Inf]
    depth = 2
    b = Beth(value_heuristic=beth_eval, rank_heuristic=beth_rank_moves, search_args=Dict("depth"=>depth, "branching_factors"=>bfs))


    for board in mates[1]
        root = minimax_search(b, board=board, white=true, verbose=false)
        @assert root.score == 1000.0 board
    end
    @info("Mate in 1 check")


    @progress for board in mates[2]
        root = minimax_search(b, board=board, white=true, verbose=false)
        @assert root.score < 1000.0 board
    end

    @info("Mate in 2 is not Mate in 1 check")

    b.search_args["depth"] = 4
    @progress for board in mates[2]
        root = minimax_search(b, board=board, white=true, verbose=false)
        @assert root.score == 1000.0 board
    end
    @info("Mate in 2 check")

    @progress for board in mates[3]
        root = minimax_search(b, board=board, white=true, verbose=false)
        if root.score == 1000.0
            println(board)
            println()
            print_tree(root, expand_best=1, has_to_have_children=false)
        end
        @assert root.score < 1000.0 board
    end
    @info("Mate in 3 is not Mate in 2 check")

    b.search_args["depth"] = 6
    @progress for board in mates[3]
        root = minimax_search(b, board=board, white=true, verbose=false)
        @assert root.score == 1000.0 board
    end
    @info("Mate in 3 check")
end

print_tree(root, expand_best=1, has_to_have_children=false)

sum(map(length, mates))
map(length, mates)

dp0 = find_mate_positions(two_piece)
m1 = find_mate_position_in_1(dp0)
dp1 = find_desperate_positions(m1, dp0)
m2 = setdiff(find_mate_position_in_1(dp1), m1)

all(is_normalised.(dp0))
all(is_normalised.(m1))
all(is_normalised.(dp1))
all(is_normalised.(m2))


board = Board(false, false)
board.position[1, 1, [KING, BLACK]] .= 1
board.position[3, 3, [KING, WHITE]] .= 1
board.position[4, 3, [ROOK, WHITE]] .= 1
board
is_normalised(board)
normalise_board(board) in m2

board = Board(false, false)
board.position[1, 1, [KING, BLACK]] .= 1
board.position[3, 3, [KING, WHITE]] .= 1
board.position[3, 4, [ROOK, WHITE]] .= 1
board
is_normalised(board)
normalise_board(board) in m2


#### HERE LIES THE KEY
board = Board(false, false)
board.position[1, 1, [KING, BLACK]] .= 1
board.position[2, 3, [KING, WHITE]] .= 1
board.position[4, 3, [ROOK, WHITE]] .= 1
board
is_normalised(board)
normalise_board(board) in dp1

board = Board(false, false)
board.position[1, 1, [KING, BLACK]] .= 1
board.position[3, 2, [KING, WHITE]] .= 1
board.position[3, 4, [ROOK, WHITE]] .= 1
board
is_normalised(board)
normalise_board(board) in dp1
####

board = Board(false, false)
board.position[2, 1, [KING, BLACK]] .= 1
board.position[2, 3, [KING, WHITE]] .= 1
board.position[4, 3, [ROOK, WHITE]] .= 1
board
is_normalised(board)
normalise_board(board)
normalise_board(board) in m1



println(get_reverse_moves(normalise_board(board), false))



board = Board(false, false)
board.position[1, 1, [KING, BLACK]] .= 1
board.position[3, 2, [KING, WHITE]] .= 1
board.position[3, 4, [ROOK, WHITE]] .= 1
board
