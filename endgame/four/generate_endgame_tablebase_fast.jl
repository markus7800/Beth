include("../../chess/chess.jl")

include("reverse_moves.jl")

import ProgressMeter

# tables are from whites perspective
# one for white to move / one for black to move
struct Table
    d::Array{Int}
end

struct TableBase
    mates::Table
    desperate_positions::Table
    key::Function
    fromkey!::Function
end

import Base.haskey
function haskey(tb::Table, key::NTuple)::Bool
    tb.d[key...] != -1
end

import Base.getindex
function getindex(tb::Table, key::NTuple)
    @assert haskey(tb, key)
    tb.d[key...]
end

import Base.setindex!
function setindex!(tb::Table, v::Int, key::NTuple)
    println(v, key)
    tb.d[key...] = v
end

import Base.length
function length(tb::Table)
    sum(tb .!= -1)
end

function three_men_key(board::Board)
    a = tonumber(board.kings & board.whites)
    b = tonumber((board.pawns | board.queens | board.rooks) & board.whites)
    c = tonumber(board.kings & board.blacks)
    p = 0
    if board.queens & board.whites > 0
        p = 1
    elseif board.rooks & board.whites > 0
        p = 2
    elseif board.pawns & board.whites > 0
        p = 3
    else
        println(board)
        error("Invalid board!")
    end

    return p, a, b, c
end

function three_men_fromkey!(board::Board, key)
    p, a, b, c = key

    piece = QUEEN
    if p == 1
        piece = ROOK
    elseif p == 2
        piece = PAWN
    end

    remove_pieces!(board)
    set_piece!(board, tofield(a), true, KING)
    set_piece!(board, tofield(b), true, piece)
    set_piece!(board, tofield(c), false, KING)
end

mates_3_men[1]
three_men_key.(mates_3_men[1])

@time for mate in mates_3_men[1]
    board = Board()
    key = three_men_key(mate)
    three_men_fromkey!(board, key)
    @assert board == mate (mate, board)
end

function ThreeMenTableBase()
    return TableBase(
        Table(fill(-1, 3, 64, 64, 64)),
        Table(fill(-1, 3, 64, 64, 64)),
        three_men_key,
        three_men_fromkey!
        )
end



function generate_3_men_piece_boards() # longest 28
    boards = Board[]
    counter = 0
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
                counter += 1
                push!(boards, board)
            end

            pop!(used_positions)
        end
    end

    @info "$counter total positions."

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


# find all moves which lead to a position that is a known mate (desperate position for black)
# the initial mates are the first desperate positions for black
# it is sufficient to only pass in newly found desperate positions
function find_mate_position_in_1(tb::TableBase, new_desperate_positions::Vector{NTuple})::Vector{NTuple}
    board = Board()
    mate_in_1 = NTuple[]

    for mate in new_desperate_positions
        rev_moves = get_reverse_moves(mate, true, promotions=true)
        for m in rev_moves
            tb.fromkey!(board, mate)
            # board = deepcopy(mate)
            undo_move!(board, true, m, NoUndo())

            push!(mate_in_1, tb.key(board))
        end
    end
    return unique(mate_in_1)
end

# finds all position where all moves lead to a known mate (where white is to move)
# for all known mates go one move backward and collect all positions
# where all moves lead to a known mates
#
# Have to pass in all mates, not only new mates
# maybe a mate in 1 is avoidable but a mate in 2 not ...
function find_desperate_positions(tb::TableBase)::Vector{NTuple}
    new_desperate_positions = NTuple[]
    board = Board()

    ProgressMeter.@showprogress for (mate, i) in tb.mates
        rev_moves = get_reverse_moves(mate, false, promotions=true)
        for rm in rev_moves
            tb.fromkey!(board, mate)

            undo_move!(board, false, rm, NoUndo())

            key = tb.key(board)
            if haskey(tb.desperate_positions, key)
                continue
            end

            is_desperate = true
            # check if all forward moves lead to known mate
            for m in get_moves(board, false)
                undo = make_move!(board, false, m)
                mate_key = tb.key(board)

                if !haskey(tb._mates, mate_key) # && !haskey(known_mates, mate_key)
                    is_desperate = false
                    break
                end

                undo_move!(board, false, m, undo)
            end


            if is_desperate
                push!(new_desperate_positions, board)
            end
        end
    end
    return unique(new_desperate_positions)
end

dp0 = find_mate_positions(generate_3_men_piece_boards())
tb = ThreeMenTableBase()
for dp in dp0
    key = tb.key(dp)
    println(key)
    tb.desperate_positions[key] = 0
end

""
# known mates allow mate check when simplification through capture
# mate in i -> move -> dp in i-1
# dp in i -> move -> mate in i
function find_all_mates(max_depth; verbose=true)

    new_desperate_positions = find_mate_positions(generate_3_men_piece_boards())
    tb = ThreeMenTableBase()

    for dp in new_desperate_positions
        key = tb.key(dp)
        tb.desperate_positions[dp] = 0
    end

    mates = []

    m_ts = []
    m_counts = []
    dp_ts = []
    dp_counts = []


    @progress for i in 1:max_depth
        verbose && @info("Iteration $i:")
        for dp in new_desperate_positions
            key = tb.key(dp)
            @assert tb.desperate_positions[dp] == i-1 dp
        end

        found_mates, t = @timed find_mate_position_in_1(tb, new_desperate_positions) # ::Vector{NTuple}
        l = length(found_mates)
        l1 = length(all_mates)


        new_mates = Board[]
        for mate in found_mates
            key = tb.key(mate)
            if !haskey(tb.all_mates, key)
                tb.all_mates[key] = i
                push!(new_mates, mate)
            end
        end
        push!(mates, new_mates)

        l2 = length(tb.all_mates)
        verbose && @info("Found $(l2 - l1) new mates in $t seconds.")
        verbose && @info("Currently $l2 mates known.")
        push!(m_ts, t)
        push!(m_counts, l2)

        new_desperate_positions, t = @timed find_desperate_positions!(tb)
        for dp in new_desperate_positions
            key = tb.key(dp)
            @assert !haskey(tb.desperate_positions, key)
            all_desperate_positions[key] = i
        end

        verbose && @info("Found $(length(desperate_positions)) new desperate positions in $t seconds.")
        verbose && @info("Currently $(length(all_desperate_positions)) desperate positions known.")
        verbose && println()

        push!(dp_ts, t)
        push!(dp_counts, length(tb.desperate_positions))

        length(desperate_positions) == 0 && break
    end

    return mates, all_mates, all_desperate_positions, m_ts, m_counts, dp_ts, dp_counts
end

function make_consistent(all_mates, all_desperate_positions, known_mates, known_dps, max_depth)
    did_change = true
    counter = 0
    while did_change # call multiple times to propagate
        counter += 1
        println("Loop $counter")
        did_change = false

        # i can be lowered if a simplification leads to faster mate
        for (mate, i) in all_mates
            j = 100
            for move in get_moves(mate, true)
                undo = make_move!(mate, true, move)
                if haskey(known_dps, mate)
                    # move should be capture
                    j = min(j, known_dps[mate]+1)
                end
                if haskey(all_desperate_positions, mate)
                    j = min(j, all_desperate_positions[mate]+1)
                end
                undo_move!(mate, true, move, undo)
            end
            if j != i
                did_change = true
            end
            all_mates[mate] = j
        end

        # i can be lowered if a simplification after black move leads to faster mate
        # cannot be a simplification here as black moves (-> all_mates)
        # basically adjusting here if move leads to adjusted mate from above
        for (dp, i) in all_desperate_positions
            j = 0
            for move in get_moves(dp, false)
                undo = make_move!(dp, false, move)
                if haskey(all_mates, dp)
                    j = max(j, all_mates[dp])
                end
                if haskey(known_mates, dp)
                    j = max(j, known_mates[dp])
                end
                undo_move!(dp, false, move, undo)
            end
            if j == 0
                @assert is_in_check(dp, false) dp
            end
            if j != i
                did_change = true
            end
            all_desperate_positions[dp] = j
        end
    end
end

function find_all_3_men_mates(max_depth; verbose=true)
    two_piece = generate_3_men_piece_boards()
    initial_mates = find_mate_positions(two_piece)

    find_all_mates(max_depth, initial_mates; verbose = verbose)
end

function test_consistency(mates, all_mates::Tablebase, all_desperate_positions::Tablebase,
    known_mates=Tablebase(), known_dps=Tablebase())
    # counts = zeros(Int, length(mates))
    # for (board, i) in all_mates
    #     counts[i] += 1
    # end
    # @assert all(length.(mates) .== counts)

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
            if haskey(known_dps, key)
                j = get(known_dps, key, NaN)
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
            i = 0
            if haskey(all_mates, key)
                i = get(all_mates, key, NaN)
            elseif haskey(known_mates, key)
                i = get(known_mates, key, NaN)
            else
                @assert false (board, bm, i, j, _board)
            end
            @assert i ≤ j
            best = max(best, i)
            undo_move!(board, false, bm, undo)
        end
        # also guarantees that no stalemate (black has moves that lead to mate)
        @assert best == j (board, best, j)
    end
end

include("tablebase.jl")

@info("Generate 3-men table base.")
# 28, 450s
@time mates_3_men, all_mates_3_men, all_desperate_positions_3_men, m_ts, m_counts, dp_ts, dp_counts = find_all_3_men_mates(30, verbose=true)

n_winning = length(all_mates_3_men) + length(all_desperate_positions_3_men)
@info("Found $n_winning winning positions.")

@info("Check consistency.")
@time test_consistency(mates_3_men, all_mates_3_men, all_desperate_positions_3_men)

@info("Save to endgame/tb3men.jld2.")
sm, sdp = slimify(all_mates_3_men, all_desperate_positions_3_men, key_3_men)

import JLD2
JLD2.@save "endgame/tb3men.jld2" mates=sm desperate_positions=sdp

# 33, 9000s
KB_mates = generate_2w_mates(KNIGHT, BISHOP)
@time mates, all_mates, all_desperate_positions, = find_all_mates(35, KB_mates, verbose=true)
test_consistency(mates, all_mates, all_desperate_positions)
sm, sdp = slimify(all_mates, all_desperate_positions, key_4_men)

@time CSV.write("test.csv", sm)

# 19, 1500s
BB_mates = generate_2w_mates(BISHOP, BISHOP)
@time mates, all_mates, all_desperate_positions, m_ts, m_counts, dp_ts, dp_counts = find_all_mates(20, BB_mates, verbose=true)
test_consistency(mates, all_mates, all_desperate_positions)


QvR_mates = generate_1v1_mates(QUEEN, ROOK)
simplification_mates = gen_cap_piece_mate_position_in_1(all_desperate_positions_3_men, QUEEN, ROOK)
mates, all_mates, all_desperate_positions = find_all_mates(4,
    QvR_mates,
    all_mates=simplification_mates,
    known_mates=all_mates_3_men,
    known_dps=all_desperate_positions_3_men,
    verbose=true)

test_consistency(mates, all_mates, all_desperate_positions, all_mates_3_men, all_desperate_positions_3_men)

all_desperate_positions

#=
KNB_K KBB_K KQ_KN KQ_KB KQ_KR KQ_KQ KR_KN KR_KB KR_KQ KR_KR
 33    19    21    17    35    13    40    29    19    19

KQB_K KQN_K KRB_K KRN_K KRR_K
  8     9    16    16     7
=#

board = mates[4][2]

board = Board()
set_piece!(board, Field("e2"), true, PAWN)
set_piece!(board, Field("e3"), true, KING)
set_piece!(board, Field("e5"), false, KING)
print_board(board)

get(all_desperate_positions_3_men, board, NaN)
get(all_mates_3_men, board, NaN)

board = Board()
set_piece!(board, Field("e2"), true, PAWN)
set_piece!(board, Field("d3"), true, KING)
set_piece!(board, Field("e5"), false, KING)
print_board(board)

get(all_desperate_positions_3_men, board, NaN)
get(all_mates_3_men, board, NaN)


#=
3 men
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
