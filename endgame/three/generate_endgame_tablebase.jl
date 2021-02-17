include("../chess/chess.jl")

include("reverse_moves.jl")

import ProgressMeter

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

                board = Board()
                set_piece!(board, Field(bk_r, bk_f), false, KING)
                set_piece!(board, Field(wk_r, wk_f), true, KING)
                set_piece!(board, Field(wp1_r, wp1_f), true, p)
                push!(boards, board)
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
        if is_in_check(board, false) && length(get_moves(board, false)) == 0
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
            undo_move!(board, true, m, NoUndo())

            # safety check
            # @assert (m in get_moves(board, true)) ("mate in 1: for != back", mate, board, m)

            # board = normalise_board(board
            push!(mate_in_1, board)

            # safety check
            # _board = deepcopy(board)
            # move!(_board, true, m[1], m[2], m[3])
            # @assert _board == mate ("mate in 1: invalid move", mate, _board, m)
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

    for (_mate, i) in all_mates
        mate = _mate
        rev_moves = get_reverse_moves(mate, false, promotions=true) # should be no promotions here since only king
        for rm in rev_moves
            board = deepcopy(mate)

            # println(board)
            undo_move!(board, false, rm, NoUndo())

            # safety check
            # @assert (rm in get_moves(board, false)) ("desp position: for != back", mate, board, rm)

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
                undo = make_move!(_board, false, m)

                # normalise_board(_board)
                if !haskey(all_mates, _board)
                    is_desparate = false
                    break
                end

                undo_move!(_board, false, m, undo)
            end

            # println("is desperate ", is_desparate)

            if is_desparate
                push!(desperate_positions, board)
            end

            # safety check
            # _board = deepcopy(board)
            # move!(_board, false, rm[1], rm[2], rm[3])
            # @assert _board == mate ("desp position: invalid move", mate, _board, rm)
        end
    end
    return unique(desperate_positions)
end

function find_all_3_men_mates(max_depth; verbose=true)
    two_piece = generate_3_men_piece_boards()

    desperate_positions = find_mate_positions(two_piece)
    all_desperate_positions = Tablebase()
    for dp in desperate_positions
        all_desperate_positions[dp] = 0
    end

    mates = []
    all_mates = Tablebase()

    ProgressMeter.@showprogress for i in 1:max_depth
        verbose && @info("Iteration $i:")
        for dp in desperate_positions
            @assert all_desperate_positions[dp] == i-1 dp
        end

        found_mates = find_mate_position_in_1(desperate_positions)
        l = length(found_mates)
        verbose && @info("Found $l mates.")
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
        verbose && @info("New ones: $(l2 - l1)")
        verbose && @info("Currently $l2 mates known.")

        desperate_positions = find_desperate_positions!(all_mates, all_desperate_positions)
        for dp in desperate_positions
            @assert !haskey(all_desperate_positions, dp)
            all_desperate_positions[dp] = i
        end

        verbose && @info("Found $(length(desperate_positions)) new desperate positions.")

        verbose && @info("Currently $(length(all_desperate_positions)) desperate positions known.")

        verbose && println()

        length(desperate_positions) == 0 && break
    end

    return mates, all_mates, all_desperate_positions
end

function test_consistency(mates, all_mates::Tablebase, all_desperate_positions::Tablebase)
    counts = zeros(Int, length(mates))
    for (board, i) in all_mates
        counts[i] += 1
    end
    @assert all(length.(mates) .== counts)

    ProgressMeter.@showprogress for (_board, i) in all_mates
        board = deepcopy(_board)
        best = 10^6
        moves = Move[]
        for m in get_moves(board, true)
            if m.from_piece == m.to_piece || m.to_piece == QUEEN # only queen promotions
                push!(moves, m)
            end
        end
        # from mating position in i there has to be at least one move that leads to a desperate position in i-1
        # but there should also be no move that leads to a desperate position in <i-1
        for wm in moves
            undo = make_move!(board, true, wm)
            board.en_passant = 0 # remove en passant as it is not used in keys
            key = board # normalise_board(board)
            if haskey(all_desperate_positions, key)
                j = get(all_desperate_positions, key, NaN)
                @assert j ≥ i - 1 (board, wm, j, i, _board)
                best = min(best, j)
            end
            undo_move!(board, true, wm, undo)
        end
        @assert best == i - 1 (board, best, i)
    end

    ProgressMeter.@showprogress for (_board, j) in all_desperate_positions
        j == 0 && continue # no moves for black (initial mates)

        # from a desperate position in j all moves should lead to a mating position in <=j
        # there should be at least one move that leads to a mating position in j
        board = deepcopy(_board)
        best = -1
        for bm in get_moves(board, false)
            undo = make_move!(board, false, bm)
            key = board # normalise_board(board)
            @assert haskey(all_mates, key) (board, bm, i, j, _board)
            i = get(all_mates, key, NaN)
            @assert i ≤ j
            best = max(best, j)
            undo_move!(board, false, bm, undo)
        end
        @assert best == j (board, best, j)
    end
end

include("tablebase.jl")

@info("Generate 3-men table base.")
@time mates, all_mates, all_desperate_positions = find_all_3_men_mates(30, verbose=false)

n_winning = length(all_mates) + length(all_desperate_positions)
@info("Found $n_winning winning positions.")

@info("Check consistency.")
@time test_consistency(mates, all_mates, all_desperate_positions)

@info("Save to endgame/tb3men.jld2.")
sm, sdp = slimify(all_mates, all_desperate_positions)

import JLD2
JLD2.@save "endgame/tb3men.jld2" mates=sm desperate_positions=sdp


# board = Board()
# set_piece!(board, Field("e2"), true, PAWN)
# set_piece!(board, Field("e3"), true, KING)
# set_piece!(board, Field("e5"), false, KING)
# print_board(board)
#
# get(all_desperate_positions, board, NaN)
# get(all_mates, board, NaN)
#
# board = Board()
# set_piece!(board, Field("e2"), true, PAWN)
# set_piece!(board, Field("d3"), true, KING)
# set_piece!(board, Field("e5"), false, KING)
# print_board(board)
#
# get(all_desperate_positions, board, NaN)
# get(all_mates, board, NaN)


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
[ Info: Found 145646 mates.
[ Info: New ones: 35814
[ Info: Currently 293660 mates known.
[ Info: Found 31642 new desperate positions.
[ Info: Currently 306338 desperate positions known.

[ Info: Iteration 11:
[ Info: Found 130206 mates.
[ Info: New ones: 37678
[ Info: Currently 331338 mates known.
[ Info: Found 37218 new desperate positions.
[ Info: Currently 343556 desperate positions known.

[ Info: Iteration 12:
[ Info: Found 143248 mates.
[ Info: New ones: 37836
[ Info: Currently 369174 mates known.
[ Info: Found 40418 new desperate positions.
[ Info: Currently 383974 desperate positions known.

[ Info: Iteration 13:
[ Info: Found 144116 mates.
[ Info: New ones: 31262
[ Info: Currently 400436 mates known.
[ Info: Found 41886 new desperate positions.
[ Info: Currently 425860 desperate positions known.

[ Info: Iteration 14:
[ Info: Found 138276 mates.
[ Info: New ones: 23794
[ Info: Currently 424230 mates known.
[ Info: Found 41374 new desperate positions.
[ Info: Currently 467234 desperate positions known.

[ Info: Iteration 15:
[ Info: Found 108362 mates.
[ Info: New ones: 7374
[ Info: Currently 431604 mates known.
[ Info: Found 19336 new desperate positions.
[ Info: Currently 486570 desperate positions known.

[ Info: Iteration 16:
[ Info: Found 60176 mates.
[ Info: New ones: 3224
[ Info: Currently 434828 mates known.
[ Info: Found 5444 new desperate positions.
[ Info: Currently 492014 desperate positions known.

[ Info: Iteration 17:
[ Info: Found 23146 mates.
[ Info: New ones: 2132
[ Info: Currently 436960 mates known.
[ Info: Found 1804 new desperate positions.
[ Info: Currently 493818 desperate positions known.

[ Info: Iteration 18:
[ Info: Found 7122 mates.
[ Info: New ones: 1742
[ Info: Currently 438702 mates known.
[ Info: Found 1422 new desperate positions.
[ Info: Currently 495240 desperate positions known.

[ Info: Iteration 19:
[ Info: Found 5742 mates.
[ Info: New ones: 1316
[ Info: Currently 440018 mates known.
[ Info: Found 1194 new desperate positions.
[ Info: Currently 496434 desperate positions known.

[ Info: Iteration 20:
[ Info: Found 4346 mates.
[ Info: New ones: 1116
[ Info: Currently 441134 mates known.
[ Info: Found 872 new desperate positions.
[ Info: Currently 497306 desperate positions known.

[ Info: Iteration 21:
[ Info: Found 3446 mates.
[ Info: New ones: 1212
[ Info: Currently 442346 mates known.
[ Info: Found 1130 new desperate positions.
[ Info: Currently 498436 desperate positions known.

[ Info: Iteration 22:
[ Info: Found 4032 mates.
[ Info: New ones: 1124
[ Info: Currently 443470 mates known.
[ Info: Found 860 new desperate positions.
[ Info: Currently 499296 desperate positions known.

[ Info: Iteration 23:
[ Info: Found 2974 mates.
[ Info: New ones: 686
[ Info: Currently 444156 mates known.
[ Info: Found 584 new desperate positions.
[ Info: Currently 499880 desperate positions known.

[ Info: Iteration 24:
[ Info: Found 1812 mates.
[ Info: New ones: 288
[ Info: Currently 444444 mates known.
[ Info: Found 218 new desperate positions.
[ Info: Currently 500098 desperate positions known.

[ Info: Iteration 25:
[ Info: Found 746 mates.
[ Info: New ones: 128
[ Info: Currently 444572 mates known.
[ Info: Found 62 new desperate positions.
[ Info: Currently 500160 desperate positions known.

[ Info: Iteration 26:
[ Info: Found 238 mates.
[ Info: New ones: 38
[ Info: Currently 444610 mates known.
[ Info: Found 28 new desperate positions.
[ Info: Currently 500188 desperate positions known.

[ Info: Iteration 27:
[ Info: Found 136 mates.
[ Info: New ones: 14
[ Info: Currently 444624 mates known.
[ Info: Found 8 new desperate positions.
[ Info: Currently 500196 desperate positions known.

[ Info: Iteration 28:
[ Info: Found 36 mates.
[ Info: New ones: 6
[ Info: Currently 444630 mates known.
[ Info: Found 4 new desperate positions.
[ Info: Currently 500200 desperate positions known.

[ Info: Iteration 29:
[ Info: Found 16 mates.
[ Info: New ones: 0
[ Info: Currently 444630 mates known.
[ Info: Found 0 new desperate positions.
[ Info: Currently 500200 desperate positions known.

1191.028092 seconds (4.22 G allocations: 205.816 GiB, 5.43% gc time)
=#
