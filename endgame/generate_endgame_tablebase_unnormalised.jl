include("../chess/chess.jl")


function generate_3_men_piece_boards() #
    boards = Board[]

    for bk_r in 1:8, bk_f in 1:8
        used_positions = [(bk_r, bk_f)]
        for wk_r in 1:8, wk_f in 1:8
            (wk_r, wk_f) in used_positions && continue
            max(abs(wk_r - bk_r), abs(wk_f - bk_f)) ≤ 1 && continue
            push!(used_positions, (wk_r, wk_f))

            for p in [ROOK, QUEEN], wp1_r in 1:8, wp1_f in 1:8
                (wp1_r, wp1_f) in used_positions && continue

                board = Board(false, false)
                board.position[bk_r, bk_f, [BLACK, KING]] .= 1
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
        rev_moves = get_reverse_moves(mate, true, promotions=true)
        for m in rev_moves
            board = deepcopy(mate)
            undo!(board, true, m[1], m[2], m[3], nothing, nothing, nothing)

            # safety check
            @assert (m in get_moves(board, true)) ("mate in 1: for != back", mate, board, m)

            # board = normalise_board(board
            push!(mate_in_1, board)

            # safety check
            _board = deepcopy(board)
            move!(_board, true, m[1], m[2], m[3])
            @assert _board == mate ("mate in 1: invalid move", mate, _board, m)
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

    for (_mate, i) in all_mates# , trafo in [identity, mirror_horizontally, mirror_vertically, mirror_diagonally]
        mate = _mate # trafo(_mate)
        rev_moves = get_reverse_moves(mate, false, promotions=true) # should be no promotions here since only king
        for rm in rev_moves
            board = deepcopy(mate)

            # println(board)
            undo!(board, false, rm[1], rm[2], rm[3], nothing, nothing, nothing)

            # safety check
            @assert (rm in get_moves(board, false)) ("desp position: for != back", mate, board, rm)

            # board = normalise_board(board)

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

                # normalise_board(_board)
                if !haskey(all_mates, _board)
                    is_desparate = false
                    break
                end

                undo!(_board, false, m[1], m[2], m[3], nothing, nothing, nothing)
            end

            # println("is desperate ", is_desparate)

            if is_desparate
                push!(desperate_positions, board)
            end

            # safety check
            _board = deepcopy(board)
            move!(_board, false, rm[1], rm[2], rm[3])
            @assert _board == mate ("desp position: invalid move", mate, _board, rm)
        end
    end
    return unique(desperate_positions)
end

function find_all_3_men_mates(max_depth)
    two_piece = generate_3_men_piece_boards()

    desperate_positions = find_mate_positions(two_piece)
    all_desperate_positions = Tablebase()
    for dp in desperate_positions
        all_desperate_positions[dp] = 0
    end

    mates = []
    all_mates = Tablebase()

    for i in 1:max_depth
        @info("Iteration $i:")
        for dp in desperate_positions
            @assert all_desperate_positions[dp] == i-1 dp
        end

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

# if king in check there are no backward moves


@time mates, all_mates, all_desperate_positions = find_all_3_men_mates(30)

function test_consistency(mates, all_mates::Tablebase, all_desperate_positions::Tablebase)
    counts = zeros(Int, length(mates))
    for (board, i) in all_mates
        counts[i] += 1
    end
    @assert all(length.(mates) .== counts)

    for (_board, i) in all_mates
        board = deepcopy(_board)
        best = 10^6
        # from mating position in i there has to be at least one move that leads to a desperate position in i-1
        # but there should also be no move that leads to a desperate position in <i-1
        for wm in get_moves(board, true)
            move!(board, true, wm[1], wm[2], wm[3])
            key = board # normalise_board(board)
            if haskey(all_desperate_positions, key)
                j = get(all_desperate_positions, key, NaN)
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
            key = board # normalise_board(board)
            @assert haskey(all_mates, key) (board, bm, i, j, _board)
            i = get(all_mates, key, NaN)
            @assert i ≤ j
            best = max(best, j)
            undo!(board, false, bm[1], bm[2], bm[3], nothing, nothing, nothing)
        end
        @assert best == j (board, best, j)
    end
end


@time test_consistency(mates, all_mates, all_desperate_positions)

board = Board(false, false)
board.position[cartesian("c2")..., [PAWN, WHITE]] .= 1
board.position[cartesian("c3")..., [KING, WHITE]] .= 1
board.position[cartesian("e2")..., [KING, BLACK]] .= 1
print_board(board)
for m in get_reverse_moves(board, true, promotions=true)
    println(m)
end
for m in get_reverse_moves(board, false, promotions=true)
    println(m)
end

for m in get_moves(board, true)
    println(m)
end
for m in get_moves(board, false)
    println(m)
end



two_piece = generate_3_men_piece_boards()
dp0 = find_mate_positions(two_piece)
find_mate_position_in_1(dp0)

board = Board(false, false)
board.position[cartesian("e2")..., [PAWN, WHITE]] .= 1
board.position[cartesian("e3")..., [KING, WHITE]] .= 1
board.position[cartesian("e5")..., [KING, BLACK]] .= 1
print_board(board)

all_desperate_positions[board]

all_desperate_positions

length.(mates)

mates[28][1]

board = Board(false, false)
board.position[cartesian("e7")..., [PAWN, WHITE]] .= 1
board.position[cartesian("b6")..., [KING, WHITE]] .= 1
board.position[cartesian("b8")..., [KING, BLACK]] .= 1
print_board(board)

all_mates[board]

@time all_mates[mates[16][1]]
@time get(all_mates, mates[16][1], 0)
@time haskey(all_mates, mates[16][1])


length(all_mates)
length(all_desperate_positions)


board = Board(false, false)
board.position[cartesian("e8")..., [QUEEN, WHITE]] .= 1
board.position[cartesian("b6")..., [KING, WHITE]] .= 1
board.position[cartesian("b8")..., [KING, BLACK]] .= 1
print_board(board)

for m in get_reverse_moves(board, true, promotions=true)
    println(m)
end

undo!(board, true, PAWNTOQUEEN, symbol("e7"), symbol("e8"), nothing, nothing, nothing)

#=
[ Info: Iteration 1:
[ Info: Found 4040 mates.
[ Info: New ones: 4040
[ Info: Currently 4040 mates known.
[ Info: Found 1994 new desperate positions.
[ Info: Currently 2574 desperate positions known.

[ Info: Iteration 2:
[ Info: Found 13238 mates.
[ Info: New ones: 9878
[ Info: Currently 13918 mates known.
[ Info: Found 4948 new desperate positions.
[ Info: Currently 7522 desperate positions known.

[ Info: Iteration 3:
[ Info: Found 24952 mates.
[ Info: New ones: 13344
[ Info: Currently 27262 mates known.
[ Info: Found 8256 new desperate positions.
[ Info: Currently 15778 desperate positions known.

[ Info: Iteration 4:
[ Info: Found 41400 mates.
[ Info: New ones: 22714
[ Info: Currently 49976 mates known.
[ Info: Found 16034 new desperate positions.
[ Info: Currently 31812 desperate positions known.

[ Info: Iteration 5:
[ Info: Found 72876 mates.
[ Info: New ones: 32848
[ Info: Currently 82824 mates known.
[ Info: Found 29916 new desperate positions.
[ Info: Currently 61728 desperate positions known.

[ Info: Iteration 6:
[ Info: Found 114838 mates.
[ Info: New ones: 44042
[ Info: Currently 126866 mates known.
[ Info: Found 46258 new desperate positions.
[ Info: Currently 107986 desperate positions known.

[ Info: Iteration 7:
[ Info: Found 151158 mates.
[ Info: New ones: 49664
[ Info: Currently 176530 mates known.
[ Info: Found 63678 new desperate positions.
[ Info: Currently 171664 desperate positions known.

[ Info: Iteration 8:
[ Info: Found 173668 mates.
[ Info: New ones: 43466
[ Info: Currently 219996 mates known.
[ Info: Found 63700 new desperate positions.
[ Info: Currently 235364 desperate positions known.

[ Info: Iteration 9:
[ Info: Found 173146 mates.
[ Info: New ones: 37850
[ Info: Currently 257846 mates known.
[ Info: Found 39332 new desperate positions.
[ Info: Currently 274696 desperate positions known.

[ Info: Iteration 10:
[ Info: Found 145652 mates.
[ Info: New ones: 35820
[ Info: Currently 293666 mates known.
[ Info: Found 31642 new desperate positions.
[ Info: Currently 306338 desperate positions known.

[ Info: Iteration 11:
[ Info: Found 130224 mates.
[ Info: New ones: 37692
[ Info: Currently 331358 mates known.
[ Info: Found 37236 new desperate positions.
[ Info: Currently 343574 desperate positions known.

[ Info: Iteration 12:
[ Info: Found 143270 mates.
[ Info: New ones: 37844
[ Info: Currently 369202 mates known.
[ Info: Found 40428 new desperate positions.
[ Info: Currently 384002 desperate positions known.

[ Info: Iteration 13:
[ Info: Found 144146 mates.
[ Info: New ones: 31264
[ Info: Currently 400466 mates known.
[ Info: Found 41868 new desperate positions.
[ Info: Currently 425870 desperate positions known.

[ Info: Iteration 14:
[ Info: Found 138242 mates.
[ Info: New ones: 23808
[ Info: Currently 424274 mates known.
[ Info: Found 41378 new desperate positions.
[ Info: Currently 467248 desperate positions known.

[ Info: Iteration 15:
[ Info: Found 108326 mates.
[ Info: New ones: 7370
[ Info: Currently 431644 mates known.
[ Info: Found 19334 new desperate positions.
[ Info: Currently 486582 desperate positions known.

[ Info: Iteration 16:
[ Info: Found 60168 mates.
[ Info: New ones: 3216
[ Info: Currently 434860 mates known.
[ Info: Found 5452 new desperate positions.
[ Info: Currently 492034 desperate positions known.

[ Info: Iteration 17:
[ Info: Found 23194 mates.
[ Info: New ones: 2162
[ Info: Currently 437022 mates known.
[ Info: Found 1892 new desperate positions.
[ Info: Currently 493926 desperate positions known.

[ Info: Iteration 18:
[ Info: Found 7404 mates.
[ Info: New ones: 1896
[ Info: Currently 438918 mates known.
[ Info: Found 1628 new desperate positions.
[ Info: Currently 495554 desperate positions known.

[ Info: Iteration 19:
[ Info: Found 6418 mates.
[ Info: New ones: 1442
[ Info: Currently 440360 mates known.
[ Info: Found 1318 new desperate positions.
[ Info: Currently 496872 desperate positions known.

[ Info: Iteration 20:
[ Info: Found 4648 mates.
[ Info: New ones: 1142
[ Info: Currently 441502 mates known.
[ Info: Found 920 new desperate positions.
[ Info: Currently 497792 desperate positions known.

[ Info: Iteration 21:
[ Info: Found 3560 mates.
[ Info: New ones: 1212
[ Info: Currently 442714 mates known.
[ Info: Found 1134 new desperate positions.
[ Info: Currently 498926 desperate positions known.

[ Info: Iteration 22:
[ Info: Found 4044 mates.
[ Info: New ones: 1120
[ Info: Currently 443834 mates known.
[ Info: Found 860 new desperate positions.
[ Info: Currently 499786 desperate positions known.

[ Info: Iteration 23:
[ Info: Found 2974 mates.
[ Info: New ones: 686
[ Info: Currently 444520 mates known.
[ Info: Found 584 new desperate positions.
[ Info: Currently 500370 desperate positions known.

[ Info: Iteration 24:
[ Info: Found 1812 mates.
[ Info: New ones: 288
[ Info: Currently 444808 mates known.
[ Info: Found 218 new desperate positions.
[ Info: Currently 500588 desperate positions known.

[ Info: Iteration 25:
[ Info: Found 746 mates.
[ Info: New ones: 128
[ Info: Currently 444936 mates known.
[ Info: Found 62 new desperate positions.
[ Info: Currently 500650 desperate positions known.

[ Info: Iteration 26:
[ Info: Found 238 mates.
[ Info: New ones: 38
[ Info: Currently 444974 mates known.
[ Info: Found 28 new desperate positions.
[ Info: Currently 500678 desperate positions known.

[ Info: Iteration 27:
[ Info: Found 136 mates.
[ Info: New ones: 14
[ Info: Currently 444988 mates known.
[ Info: Found 8 new desperate positions.
[ Info: Currently 500686 desperate positions known.

[ Info: Iteration 28:
[ Info: Found 36 mates.
[ Info: New ones: 6
[ Info: Currently 444994 mates known.
[ Info: Found 4 new desperate positions.
[ Info: Currently 500690 desperate positions known.

[ Info: Iteration 29:
[ Info: Found 16 mates.
[ Info: New ones: 0
[ Info: Currently 444994 mates known.
[ Info: Found 0 new desperate positions.
[ Info: Currently 500690 desperate positions known.

1166.182357 seconds (4.19 G allocations: 203.324 GiB, 5.46% gc time)
=#
