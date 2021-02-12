include("../../chess/chess.jl")
include("reverse_moves.jl")
using ProgressMeter

# tables are from whites perspective
# one for white to move / one for black to move
struct Table
    d::Array{Int}
end

function Table(size...)
    return Table(fill(-1, size...))
end

struct TableBase
    mates::Table
    desperate_positions::Table
    key::Function
    fromkey!::Function
end

import Base.haskey
function haskey(tb::Table, key::CartesianIndex)::Bool
    if key == CartesianIndex(0)
        return false
    end
    tb.d[key] != -1
end

# function haskey(tb::Table, key::Int)::Bool
#     tb.d[key] != -1
# end

import Base.getindex
function getindex(tb::Table, key::CartesianIndex)
    @assert haskey(tb, key)
    tb.d[key]
end

import Base.setindex!
function setindex!(tb::Table, v::Int, key::CartesianIndex)
    tb.d[key] = v
end

import Base.length
function length(tb::Table)
    sum(tb.d .!= -1)
end

import Base.size
function size(tb::Table)
    prod(size(tb.d))
end

import Base.CartesianIndices
CartesianIndices(tb::Table) = CartesianIndices(tb.d)

function get_mate(tb::TableBase, board::Board)
    tb.mates[tb.key(board)]
end

function get_desperate_position(tb::TableBase, board::Board)
    tb.desperate_positions[tb.key(board)]
end

function three_men_key(board::Board)::CartesianIndex
    if count_pieces(board.whites) != 2 || count_pieces(board.blacks) != 1
        return CartesianIndex(0)
    end
    a = tonumber(board.kings & board.whites)
    b = tonumber((board.pawns | board.queens | board.rooks) & board.whites)
    c = tonumber(board.kings & board.blacks)

    if b == 65
        return CartesianIndex(0)
    end

    p = 0
    if board.queens & board.whites > 0
        p = 1
    elseif board.rooks & board.whites > 0
        p = 2
    elseif board.pawns & board.whites > 0
        p = 3
    else
        return CartesianIndex(0)
    end

    return CartesianIndex(p, a, b, c)
end

function three_men_fromkey!(board::Board, key::CartesianIndex)
    p = key[1]
    piece = QUEEN
    if p == 2
        piece = ROOK
    elseif p == 3
        piece = PAWN
    end

    remove_pieces!(board)
    set_piece!(board, tofield(key[2]), true, KING)
    set_piece!(board, tofield(key[3]), true, piece)
    set_piece!(board, tofield(key[4]), false, KING)
end

function ThreeMenTB()
    return TableBase(
        Table(3, 64, 64, 64),
        Table(3, 64, 64, 64),
        three_men_key,
        three_men_fromkey!
        )
end

function occupied_by(board::Board, piece::Piece)
    if piece == KING
        return board.kings
    elseif piece == PAWN
        return board.pawns
    elseif piece == BISHOP
        return board.bishops
    elseif piece == KNIGHT
        return board.knights
    elseif piece == ROOK
        return board.rooks
    elseif piece == QUEEN
        return board.queens
    end
end


function four_men_2v0_key(piece1::Piece, piece2::Piece)
    function key(board::Board)::CartesianIndex
        if count_pieces(board.whites) != 3 || count_pieces(board.blacks) != 1
            return CartesianIndex(0)
        end

        a = tonumber(board.kings & board.whites)
        local b
        local c
        fs_1 = occupied_by(board, piece1) & board.whites
        fs_2 = occupied_by(board, piece2) & board.whites
        if piece1 == piece2
            b = first(fs_1)
            fs_1 = removefirst(fs_1)
            c = first(fs_1)
        else
            b = tonumber(fs_1)
            c = tonumber(fs_2)
        end
        d = tonumber(board.kings & board.blacks)
        if b == 65 || c == 65 || count_pieces(fs_1 | fs_2 | board.kings) != 4
            return CartesianIndex(0)
        end

        return CartesianIndex(a, b, c, d)
    end
end

function four_men_2v0_fromkey!(piece1::Piece, piece2::Piece)
    function fromkey!(board::Board, key::CartesianIndex)
        remove_pieces!(board)
        set_piece!(board, tofield(key[1]), true, KING)
        set_piece!(board, tofield(key[2]), true, piece1)
        set_piece!(board, tofield(key[3]), true, piece2)
        set_piece!(board, tofield(key[4]), false, KING)
    end
end

function FourMenTB2v0(piece1::Piece, piece2::Piece)
    return TableBase(
        Table(64, 64, 64, 64),
        Table(64, 64, 64, 64),
        four_men_2v0_key(piece1, piece2),
        four_men_2v0_fromkey!(piece1, piece2)
        )
end


function four_men_1v1_key(wpiece::Piece, bpiece::Piece)
    function key(board::Board)::CartesianIndex
        a = tonumber(board.kings & board.whites)
        b = tonumber(occupied_by(board, wpiece) & board.whites)
        c = tonumber(board.kings & board.blacks)
        d = tonumber(occupied_by(board, bpiece) & board.blacks)
        if b == 65 || d == 65 || count_pieces(board.whites | board.blacks) != 4
            return CartesianIndex(0)
        end

        return CartesianIndex(a, b, c, d)
    end
end

function four_men_1v1_fromkey!(wpiece::Piece, bpiece::Piece)
    function fromkey!(board::Board, key::CartesianIndex)
        remove_pieces!(board)
        set_piece!(board, tofield(key[1]), true, KING)
        set_piece!(board, tofield(key[2]), true, wpiece)
        set_piece!(board, tofield(key[3]), false, KING)
        set_piece!(board, tofield(key[4]), false, bpiece)
    end
end

function four_men_1v1_wp_key(wpiece::Piece, bpiece::Piece)
    function key(board::Board)::CartesianIndex
        if count_pieces(board.whites) != 2 || count_pieces(board.blacks) != 2
            return CartesianIndex(0)
        end

        a = tonumber(board.kings & board.whites)
        b = tonumber((occupied_by(board, wpiece) | board.pawns) & board.whites)
        c = tonumber(board.kings & board.blacks)
        d = tonumber(occupied_by(board, bpiece) & board.blacks)
        e = Int(n_pawns(board, true) > 0) + 1
        if b == 65 || d == 65 || count_pieces(board.whites | board.blacks) != 4
            return CartesianIndex(0)
        end

        return CartesianIndex(a, b, c, d, e)
    end
end

function four_men_1v1_wp_fromkey!(wpiece::Piece, bpiece::Piece)
    function fromkey!(board::Board, key::CartesianIndex)
        remove_pieces!(board)
        set_piece!(board, tofield(key[1]), true, KING)
        if key[5] == 1
            set_piece!(board, tofield(key[2]), true, wpiece)
        else
            set_piece!(board, tofield(key[2]), true, PAWN)
        end
        set_piece!(board, tofield(key[3]), false, KING)
        set_piece!(board, tofield(key[4]), false, bpiece)
    end
end

function FourMenTB1v1(wpiece::Piece, bpiece::Piece, promotions::Bool=false)
    if promotions
        return TableBase(
            Table(64, 64, 64, 64, 2),
            Table(64, 64, 64, 64, 2),
            four_men_1v1_wp_key(wpiece, bpiece),
            four_men_1v1_wp_fromkey!(wpiece, bpiece)
            )
    else
        return TableBase(
            Table(64, 64, 64, 64),
            Table(64, 64, 64, 64),
            four_men_1v1_key(wpiece, bpiece),
            four_men_1v1_fromkey!(wpiece, bpiece)
            )
    end
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

generate_3_men_mates() = find_mate_positions(generate_3_men_piece_boards())


function generate_2w_mates(P1::Piece, P2::Piece)
    boards = Board[]
    counter = 0

    for bk_r in 1:8, bk_f in 1:8
        used_positions = [(bk_r, bk_f)]
        for wk_r in 1:8, wk_f in 1:8
            (wk_r, wk_f) in used_positions && continue
            max(abs(wk_r - bk_r), abs(wk_f - bk_f)) ≤ 1 && continue
            push!(used_positions, (wk_r, wk_f))

            for w1_r in 1:8, w1_f in 1:8
                (w1_r, w1_f) in used_positions && continue
                push!(used_positions, (w1_r, w1_f))

                for w2_r in 1:8, w2_f in 1:8
                    (w2_r, w2_f) in used_positions && continue
                    counter += 1

                    board = Board()
                    set_piece!(board, Field(bk_r, bk_f), false, KING)
                    set_piece!(board, Field(wk_r, wk_f), true, KING)
                    set_piece!(board, Field(w1_r, w1_f), true, P1)
                    set_piece!(board, Field(w2_r, w2_f), true, P2)

                    # check if black king is in checkmate
                    if is_in_check(board, false) && length(get_moves(board, false)) == 0
                        push!(boards, board)
                    end
                end

                pop!(used_positions)
            end

            pop!(used_positions)
        end
    end

    @info "$counter total positions."

    return boards
end

function generate_1v1_mates(P1::Piece, P2::Piece)
    boards = Board[]
    counter = 0

    @showprogress "Generate initial mates " for bk_r in 1:8, bk_f in 1:8
        used_positions = [(bk_r, bk_f)]
        for wk_r in 1:8, wk_f in 1:8
            (wk_r, wk_f) in used_positions && continue
            max(abs(wk_r - bk_r), abs(wk_f - bk_f)) ≤ 1 && continue
            push!(used_positions, (wk_r, wk_f))

            for w1_r in 1:8, w1_f in 1:8
                (w1_r, w1_f) in used_positions && continue
                push!(used_positions, (w1_r, w1_f))

                for b2_r in 1:8, b2_f in 1:8
                    (b2_r, b2_f) in used_positions && continue
                    counter += 1

                    board = Board()
                    set_piece!(board, Field(bk_r, bk_f), false, KING)
                    set_piece!(board, Field(wk_r, wk_f), true, KING)
                    set_piece!(board, Field(w1_r, w1_f), true, P1)
                    set_piece!(board, Field(b2_r, b2_f), false, P2)

                    # check if black king is in checkmate
                    if is_in_check(board, false) && !is_in_check(board, true) && length(get_moves(board, false)) == 0
                        push!(boards, board)
                        continue
                    end
                end

                pop!(used_positions)
            end

            pop!(used_positions)
        end
    end

    @info "$counter total positions."

    return boards
end

# mate in i -> move -> dp in i-1
function gen_cap_piece_mate_position_in_1!(tb::TableBase, known_tb::TableBase, piece::Piece, captured::Piece, max_iter::Int)
    board = Board()
    @showprogress "Generate simplification mates " for dp_key in CartesianIndices(known_tb.desperate_positions)
        !haskey(known_tb.desperate_positions, dp_key) && continue

        known_tb.fromkey!(board, dp_key)
        i = known_tb.desperate_positions[dp_key]
        !(i+1 ≤ max_iter) && continue

        if count_pieces(board, true, piece) == 1 || count_pieces(board, true, PAWN) == 1
            # allow the opponent king to be in check and be blocked with new piece
            for move in get_pseudo_reverse_capture_moves(board, true, promotions=true)

                new_mate = Board()
                known_tb.fromkey!(new_mate, dp_key)

                undo_move!(new_mate, true, move, NoUndo())
                set_piece!(new_mate, tofield(move.to), false, captured)

                if is_in_check(new_mate, false)
                    continue
                end

                new_mate_key = tb.key(new_mate)

                if haskey(tb.mates, new_mate_key)
                    # king can also capture
                    tb.mates[new_mate_key] = min(i+1, tb.mates[new_mate_key])
                else
                    tb.mates[new_mate_key] = i+1
                end
            end
        end
    end
end

# finds all positions where black king is mated
# input are normalised boards
function find_mate_positions(boards::Vector{Board})::Vector{Board}
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
function find_mate_position_in_1(tb::TableBase, new_desperate_positions::Vector{<:CartesianIndex})::Vector{<:CartesianIndex}
    board = Board()
    mate_in_1 = CartesianIndex[]

    @showprogress for mate in new_desperate_positions
        tb.fromkey!(board, mate)
        rev_moves = get_reverse_moves(board, true, promotions=true)
        for m in rev_moves
            tb.fromkey!(board, mate)
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
function find_desperate_positions(tb::TableBase, i::Int, known_tb)::Vector{<:CartesianIndex}
    new_desperate_positions = CartesianIndex[]
    board = Board()

    @showprogress for mate in CartesianIndices(tb.mates)
        !haskey(tb.mates, mate) && continue

        tb.fromkey!(board, mate)
        rev_moves = get_reverse_moves(board, false, promotions=false)
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

                if !haskey(tb.mates, mate_key) || tb.mates[mate_key] > i
                    if !isnothing(known_tb)
                        known_mate_key = known_tb.key(board)
                        if !haskey(known_tb.mates, known_mate_key) || known_tb.mates[known_mate_key] > i # && !haskey(known_mates, mate_key)
                            is_desperate = false
                            break
                        end
                    else
                        is_desperate = false
                        break
                    end
                end


                undo_move!(board, false, m, undo)
            end


            if is_desperate
                push!(new_desperate_positions, key)
            end
        end
    end
    return unique(new_desperate_positions)
end


# known mates allow mate check when simplification through capture
# mate in i -> move -> dp in i-1
# dp in i -> move -> mate in i
function find_all_mates(tb::TableBase, max_depth::Int, initial_mates::Vector{Board}, known_tb=nothing; verbose=true)
    new_desperate_positions = tb.key.(initial_mates)

    for dp_key in new_desperate_positions
        tb.desperate_positions[dp_key] = 0
    end

    for i in 1:max_depth
        verbose && @info("Iteration $i:")
        for dp_key in new_desperate_positions
            @assert tb.desperate_positions[dp_key] == i-1 dp
        end

        found_mates, t = @timed find_mate_position_in_1(tb, new_desperate_positions)

        l1 = length(tb.mates)

        new_mates = []
        for mate_key in found_mates
            if !haskey(tb.mates, mate_key)
                tb.mates[mate_key] = i
                push!(new_mates, mate_key)
            else
                # if initial mate is created from simpler tb then a mate
                # can be reached faster with new piece
                # 8/8/8/8/8/4K3/Q7/r4k2 w - - 0 1
                tb.mates[mate_key] = min(tb.mates[mate_key], i)
            end
        end

        l2 = length(tb.mates)
        verbose && @info("Found $(l2 - l1) new mates in $t seconds.")
        verbose && @info("Currently $l2 mates known.")

        new_desperate_positions, t = @timed find_desperate_positions(tb, i, known_tb)
        for dp_key in new_desperate_positions
            @assert !haskey(tb.desperate_positions, dp_key)
            tb.desperate_positions[dp_key] = i
        end

        verbose && @info("Found $(length(new_desperate_positions)) new desperate positions in $t seconds.")
        verbose && @info("Currently $(length(tb.desperate_positions)) desperate positions known.")
        verbose && println()

        length(new_desperate_positions) == 0 && break
    end

    return tb
end

function test_consistency(tb::TableBase, known_tb=nothing)
    board = Board()
    @showprogress for mate_key in CartesianIndices(tb.mates)
        !haskey(tb.mates, mate_key) && continue

        tb.fromkey!(board, mate_key)
        i = tb.mates[mate_key]

        _board = deepcopy(board)

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
            key = tb.key(board)
            if haskey(tb.desperate_positions, key)
                j = tb.desperate_positions[key]
                @assert j ≥ i - 1 (_board, i, wm, j, board)
                best = min(best, j)
            end
            if !isnothing(known_tb)
                known_key = known_tb.key(board)
                if haskey(known_tb.desperate_positions, known_key)
                    j = known_tb.desperate_positions[known_key]
                    @assert j ≥ i - 1 (_board, i, wm, j, board)
                    best = min(best, j)
                end
            end
            undo_move!(board, true, wm, undo)
        end
        @assert best == i - 1 (_board, best, i)
    end

    @showprogress for dp_key in CartesianIndices(tb.desperate_positions)
        !haskey(tb.desperate_positions, dp_key) && continue

        tb.fromkey!(board, dp_key)
        j = tb.desperate_positions[dp_key]
        j == 0 && continue # no moves for black (initial mates)

        _board = deepcopy(board)

        # from a desperate position in j all moves should lead to a mating position in <=j
        # there should be at least one move that leads to a mating position in j
        best = -1
        for bm in get_moves(board, false)
            undo = make_move!(board, false, bm)
            key = tb.key(board)
            i = -1
            if haskey(tb.mates, key)
                i = tb.mates[key]
            elseif !isnothing(known_tb)
                known_key = known_tb.key(board)
                if haskey(known_tb.mates, known_key)
                    i = known_tb.mates[known_key]
                end
            end
            @assert i != -1 (_board, j, bm, i, board)

            @assert i ≤ j
            best = max(best, i)
            undo_move!(board, false, bm, undo)
        end
        # also guarantees that no stalemate (black has moves that lead to mate)
        @assert best == j (_board, best, j)
    end
end

function gen_3_men_TB(verbose=true)
    initial_mates = generate_3_men_mates()
    @info "$(length(initial_mates)) initial mates."
    tb = ThreeMenTB()
    tb = find_all_mates(tb, 100, initial_mates, verbose=verbose)
    return tb
end

function gen_4_men_2v0_TB(piece1::Piece, piece2::Piece, verbose=true)
    initial_mates = generate_2w_mates(piece1, piece2)
    @info "$(length(initial_mates)) initial mates."
    tb = FourMenTB2v0(piece1, piece2)
    tb = find_all_mates(tb, 100, initial_mates, verbose=verbose)
    return tb
end

function gen_4_men_1v1_TB(player_piece::Piece, opponent_piece::Piece, known_tb::TableBase; max_iter=100, verbose=true)
    initial_mates = generate_1v1_mates(player_piece, opponent_piece)
    @info "$(length(initial_mates)) initial mates."
    promotions = player_piece == QUEEN
    tb = FourMenTB1v1(player_piece, opponent_piece, promotions)
    gen_cap_piece_mate_position_in_1!(tb, known_tb, player_piece, opponent_piece, max_iter)

    tb = find_all_mates(tb, max_iter, initial_mates, known_tb, verbose=verbose)
    return tb
end

# 28, 60s
@time three_men_tb = gen_3_men_TB()

@time test_consistency(three_men_tb)

import JLD2
JLD2.@save "endgame/tb3men.jld2" mates=sm desperate_positions=sdp

# 33, 1700s
@time gen_4_men_2v0_TB(BISHOP, KNIGHT)

# 19, 340s
@time gen_4_men_2v0_TB(BISHOP, BISHOP)


# 35,
@time qr_tb = gen_4_men_1v1_TB(QUEEN, ROOK, three_men_tb, max_iter=8)
@time test_consistency(qr_tb, three_men_tb)


initial_mates = generate_1v1_mates(QUEEN, ROOK)
@info "$(length(initial_mates)) initial mates."
tb = FourMenTB1v1(QUEEN, ROOK, true)
dp0 = tb.key.(initial_mates)
for dp in dp0
    tb.desperate_positions[dp] = 0
end

gen_cap_piece_mate_position_in_1!(tb, three_men_tb, QUEEN, ROOK, 1)

length(tb.mates)
get_mate(tb, board)

mp1 = find_mate_position_in_1(tb, dp0)

filter(mp -> mp == CartesianIndex(0), mp1)

tb = find_all_mates(tb, 100, initial_mates, three_men_tb, verbose=true)


for move in get_moves(board, false)
    println(move)
    _board = deepcopy(board)
    make_move!(_board, false, move)
    try
        println("qr: ", get_desperate_position(tb, _board))
    catch
    end
    try
        println("3m: ", get_desperate_position(three_men_tb, _board))
    catch
    end
end



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
