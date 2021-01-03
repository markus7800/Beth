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
        rank = 8 - rank + 1
    end
    if file > 4
        # mirror along vertical axis
        new_board.position .= [new_board.position[r,f,p] for r in 1:8, f in 8:-1:1, p in 1:8]
        file = 8 - file + 1
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

function generate_2_piece_boards() # 69936
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
            push!(mate_in_1, board)
        end
    end
    return unique(mate_in_1)
end


Tablebase = Dict{Board, Int}

# finds all position where all moves lead to a known mate (where white is to move)
# for all known mates go one move backward and collect all positions
# where all moves lead to a known mates
#
# Have to pass in all mates, not only new mates
# maybe a mate in 1 is avoidable but a mate in 2 not ...
function find_desperate_positions!(all_mates::Tablebase, all_desperate_positions::Tablebase)
    desperate_positions = Board[]

    for (_mate, i) in all_mates, trafo in [identity, mirror_horizontally, mirror_vertically, mirror_diagonally]
        mate = trafo(_mate)
        rev_moves = get_reverse_moves(mate, false)
        for rm in rev_moves
            board = deepcopy(mate)

            # println(board)
            undo!(board, false, rm[1], rm[2], rm[3], nothing, nothing, nothing)
            # println("prev board")
            # println(board)

            board = normalise_board(board)

            if haskey(all_desperate_positions, board)
                # println("prev board is known mate")
                continue
            end

            _board = deepcopy(board)
            # println(get_moves(_board, false))

            is_desparate = true
            # check if all forward moves lead to known mate
            for m in get_moves(_board, false)
                move!(_board, false, m[1], m[2], m[3])

                if !haskey(all_mates, normalise_board(_board))
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
    return unique(desperate_positions)
end

function find_all_mates(max_depth=4)
    two_piece = generate_2_piece_boards()

    desperate_positions = find_mate_positions(two_piece)
    all_desperate_positions = Tablebase()
    for dp in desperate_positions
        all_desperate_positions[dp] = 0
    end

    mates = []
    all_mates = Tablebase()

    for i in 1:max_depth
        @info("Iteration $i:")
        found_mates = find_mate_position_in_1(desperate_positions)
        l = length(found_mates)
        @info("Found $l mates.")
        l1 = length(all_mates)

        new_mates = Board[]
        for mate in found_mates
            if !haskey(all_mates, mate)
                all_mates[mate] = i
                push!(new_mates, mate)
            end
        end
        push!(mates, new_mates)

        l2 = length(all_mates)
        @info("New ones: $(l2 - l1)")
        @info("Currently $l2 mates known.")

        desperate_positions = find_desperate_positions!(all_mates, all_desperate_positions)
        for dp in desperate_positions
            @assert !haskey(all_desperate_positions, dp)
            all_desperate_positions[dp] = i
        end

        @info("Found $(length(desperate_positions)) new desperate positions.")

        @info("Currently $(length(all_desperate_positions)) desperate positions known.")

        println()

        length(desperate_positions) == 0 && break
    end

    return mates, all_mates, all_desperate_positions
end

@time mates, all_mates, all_desperate_positions = find_all_mates(20)

function test_consistency(mates, all_mates::Tablebase, all_desperate_positions::Tablebase)
    counts = zeros(Int, length(mates))
    for (board, i) in all_mates
        counts[i] += 1
    end
    @assert all(length.(mates) .== counts)

    for (board, i) in all_mates
        @assert is_normalised(board) board
    end
    for (board, i) in all_desperate_positions
        @assert is_normalised(board) board
    end

    for (_board, i) in all_mates
        board = deepcopy(_board)
        best = 10^6
        # from mating position in i there has to be at least one move that leads to a desperate position in i-1
        # but there should also be no move that leads to a desperate position in <i-1
        for wm in get_moves(board, true)
            move!(board, true, wm[1], wm[2], wm[3])
            key = normalise_board(board)
            if haskey(all_desperate_positions, key)
                j = all_desperate_positions[key]
                @assert j ≥ i - 1 (board, wm, j, i, _board)
                best = min(best, j)
            end
            undo!(board, true, wm[1], wm[2], wm[3], nothing, nothing, nothing)
        end
        @assert best == i - 1 (board, best, i)
    end

    for (_board, j) in all_desperate_positions
        j == 0 && continue # no moves for black (initial mates)

        # from a desperate position in j all moves should lead to a mating position in <=j
        # there should be at least one move that leads to a mating position in j
        board = deepcopy(_board)
        best = -1
        for bm in get_moves(board, false)
            move!(board, false, bm[1], bm[2], bm[3])
            key = normalise_board(board)
            @assert haskey(all_mates, key) (board, bm, i, j, _board)
            i = all_mates[key]
            @assert i ≤ j
            best = max(best, j)
            undo!(board, false, bm[1], bm[2], bm[3], nothing, nothing, nothing)
        end
        @assert best == j (board, best, j)
    end
end


test_consistency(mates, all_mates, all_desperate_positions)

function test_consistency_with_minimax(mates)
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


d = Dict(1=>1, 2=>3)

#=
[[ Info: Iteration 1:
[ Info: Found 672 mates.
[ Info: New ones: 672
[ Info: Currently 672 mates known.
[ Info: Found 350 new desperate positions.
[ Info: Currently 451 desperate positions known.

[ Info: Iteration 2:
[ Info: Found 2056 mates.
[ Info: New ones: 1468
[ Info: Currently 2140 mates known.
[ Info: Found 785 new desperate positions.
[ Info: Currently 1236 desperate positions known.

[ Info: Iteration 3:
[ Info: Found 3755 mates.
[ Info: New ones: 1884
[ Info: Currently 4024 mates known.
[ Info: Found 1317 new desperate positions.
[ Info: Currently 2553 desperate positions known.

[ Info: Iteration 4:
[ Info: Found 6214 mates.
[ Info: New ones: 3347
[ Info: Currently 7371 mates known.
[ Info: Found 2475 new desperate positions.
[ Info: Currently 5028 desperate positions known.

[ Info: Iteration 5:
[ Info: Found 10686 mates.
[ Info: New ones: 4692
[ Info: Currently 12063 mates known.
[ Info: Found 4431 new desperate positions.
[ Info: Currently 9459 desperate positions known.

[ Info: Iteration 6:
[ Info: Found 16715 mates.
[ Info: New ones: 6372
[ Info: Currently 18435 mates known.
[ Info: Found 6923 new desperate positions.
[ Info: Currently 16382 desperate positions known.

[ Info: Iteration 7:
[ Info: Found 21766 mates.
[ Info: New ones: 6952
[ Info: Currently 25387 mates known.
[ Info: Found 9349 new desperate positions.
[ Info: Currently 25731 desperate positions known.

[ Info: Iteration 8:
[ Info: Found 23866 mates.
[ Info: New ones: 5128
[ Info: Currently 30515 mates known.
[ Info: Found 8695 new desperate positions.
[ Info: Currently 34426 desperate positions known.

[ Info: Iteration 9:
[ Info: Found 21616 mates.
[ Info: New ones: 3279
[ Info: Currently 33794 mates known.
[ Info: Found 3903 new desperate positions.
[ Info: Currently 38329 desperate positions known.

[ Info: Iteration 10:
[ Info: Found 15697 mates.
[ Info: New ones: 2951
[ Info: Currently 36745 mates known.
[ Info: Found 2491 new desperate positions.
[ Info: Currently 40820 desperate positions known.

[ Info: Iteration 11:
[ Info: Found 12652 mates.
[ Info: New ones: 2996
[ Info: Currently 39741 mates known.
[ Info: Found 3394 new desperate positions.
[ Info: Currently 44214 desperate positions known.

[ Info: Iteration 12:
[ Info: Found 14926 mates.
[ Info: New ones: 3135
[ Info: Currently 42876 mates known.
[ Info: Found 4225 new desperate positions.
[ Info: Currently 48439 desperate positions known.

[ Info: Iteration 13:
[ Info: Found 16297 mates.
[ Info: New ones: 3004
[ Info: Currently 45880 mates known.
[ Info: Found 5148 new desperate positions.
[ Info: Currently 53587 desperate positions known.

[ Info: Iteration 14:
[ Info: Found 17274 mates.
[ Info: New ones: 2714
[ Info: Currently 48594 mates known.
[ Info: Found 5728 new desperate positions.
[ Info: Currently 59315 desperate positions known.

[ Info: Iteration 15:
[ Info: Found 14587 mates.
[ Info: New ones: 1005
[ Info: Currently 49599 mates known.
[ Info: Found 2931 new desperate positions.
[ Info: Currently 62246 desperate positions known.

[ Info: Iteration 16:
[ Info: Found 8327 mates.
[ Info: New ones: 187
[ Info: Currently 49786 mates known.
[ Info: Found 534 new desperate positions.
[ Info: Currently 62780 desperate positions known.

[ Info: Iteration 17:
[ Info: Found 2270 mates.
[ Info: New ones: 0
[ Info: Currently 49786 mates known.
[ Info: Found 0 new desperate positions.
[ Info: Currently 62780 desperate positions known.

467.129298 seconds (1.56 G allocations: 143.366 GiB, 8.41% gc time)
=#
