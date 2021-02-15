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

function get_mate_line(tb::TableBase, board::Board, known_tb=nothing; verbose=false)
    line = Move[]
    i = tb.mates[tb.key(board)]
    j = i-1
    _board = deepcopy(board)
    counter = 1
    while true
        # mate in i -> move -> dp in i-1
        wms = get_moves(_board, true)
        j = -1
        for move in wms
            undo = make_move!(_board, true, move)
            dp_key = tb.key(_board)
            if haskey(tb.desperate_positions, dp_key)
                j = tb.desperate_positions[dp_key]
            end
            if !isnothing(known_tb)
                known_dp_key = known_tb.key(_board)
                if haskey(known_tb.desperate_positions, known_dp_key)
                    j = known_tb.desperate_positions[known_dp_key]
                end
            end
            if j == i - 1
                verbose && print("$counter. $move\t")
                push!(line, move)
                break
            end
            undo_move!(_board, true, move, undo)
        end

        # dp in i -> move -> mate in i
        bms = get_moves(_board, false)
        if length(bms) == 0
            verbose && println("########")
            break
        end
        i = -1
        for move in bms
            undo = make_move!(_board, false, move)
            mate_key = tb.key(_board)
            if haskey(tb.mates, mate_key)
                i = tb.mates[mate_key]

            end
            if !isnothing(known_tb)
                known_mate_key = known_tb.key(_board)
                if haskey(known_tb.mates, known_mate_key)
                    i = known_tb.mates[known_mate_key]
                end
            end
            if i == j
                verbose && println(move)
                push!(line, move)
                break
            end
            undo_move!(_board, false, move, undo)
        end
        counter += 1
    end

    return line
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
function gen_cap_piece_mate_position_in_1!(tb::TableBase, known_tb::TableBase, piece::Piece, captured::Piece, promotions::Bool, max_iter::Int)
    board = Board()
    @showprogress "Generate simplification mates " for dp_key in CartesianIndices(known_tb.desperate_positions)
        !haskey(known_tb.desperate_positions, dp_key) && continue

        known_tb.fromkey!(board, dp_key)
        i = known_tb.desperate_positions[dp_key]
        !(i+1 ≤ max_iter) && continue

        if count_pieces(board, true, piece) == 1 || (promotions && count_pieces(board, true, PAWN) == 1)
            # allow the opponent king to be in check and be blocked with new piece
            for move in get_pseudo_reverse_capture_moves(board, true, promotions=promotions)

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
# Have to consider only new mates
# if position is dp in i then there has to be a move that leads to mate in i
# and all other moves lead to mate in <i (here all mates have to be checked)
function find_desperate_positions(tb::TableBase, i::Int, known_tb, mates=CartesianIndices(tb.mates))::Vector{<:CartesianIndex}
    new_desperate_positions = CartesianIndex[]
    board = Board()

    @showprogress for mate in mates
        !haskey(tb.mates, mate) && continue
        tb.mates[mate] != i && continue

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
                        if !haskey(known_tb.mates, known_mate_key) || known_tb.mates[known_mate_key] > i
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

        new_mates = Vector{eltype(new_desperate_positions)}()
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

        _,t, = @timed if isnothing(known_tb)
            # faster
            new_desperate_positions = find_desperate_positions(tb, i, known_tb, new_mates)
        else
            new_desperate_positions = find_desperate_positions(tb, i, known_tb)
        end

        for dp_key in new_desperate_positions
            @assert !haskey(tb.desperate_positions, dp_key)
            tb.desperate_positions[dp_key] = i
        end

        verbose && @info("Found $(length(new_desperate_positions)) new desperate positions in $t seconds.")
        verbose && @info("Currently $(length(tb.desperate_positions)) desperate positions known.")
        verbose && println()

        if isnothing(known_tb)
            length(new_desperate_positions) == 0 && break
        else
            (length(new_desperate_positions) == 0 && i > maximum(known_tb.mates.d)) && break
        end
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
    gen_cap_piece_mate_position_in_1!(tb, known_tb, player_piece, opponent_piece, promotions, max_iter)

    tb = find_all_mates(tb, max_iter, initial_mates, known_tb, verbose=verbose)
    return tb
end

# 28, 30s
@time three_men_tb = gen_3_men_TB()
test_consistency(three_men_tb)

m28 = Board("8/8/8/1k6/8/8/K5P1/8 w - - 0 1")
get_mate(three_men_tb, m28)
get_mate_line(three_men_tb, m28, verbose = true)
m10 = Board("8/8/8/5k2/8/8/1Q6/K7 w - - 0 1")
get_mate(three_men_tb, m10)
m16 = Board("8/8/8/8/8/2k5/1R6/K7 w - - 0 1")
get_mate(three_men_tb, m16)

dp_not_m = Board("8/8/8/4k3/8/4K3/4P3/8 w - - 0 1")
get_mate(three_men_tb, dp_not_m)
get_desperate_position(three_men_tb, dp_not_m)

m_not_dp = Board("8/8/8/4k3/8/3K4/4P3/8 w - - 0 1")
get_mate(three_men_tb, m_not_dp)
get_desperate_position(three_men_tb, m_not_dp)

# 19, 150s
@time bb_tb = gen_4_men_2v0_TB(BISHOP, BISHOP)
test_consistency(bb_tb)

m19 = Board("8/8/8/8/7B/8/3k4/K2B4 w - - 0 1")
get_mate(bb_tb, m19)

# 33, 650s
@time bk_tb = gen_4_men_2v0_TB(BISHOP, KNIGHT)
test_consistency(bk_tb)

m33 = Board("8/8/7N/8/8/8/8/K1k1B3 w - - 0 1")
get_mate(bk_tb, m33)

# 43, 1200s
@time qr_tb = gen_4_men_1v1_TB(QUEEN, ROOK, three_men_tb)
test_consistency(qr_tb, three_men_tb)

m35 = Board("8/8/8/8/2r5/8/2k5/K6Q w - - 0 1")
get_mate(qr_tb, m35)
m43 = Board("8/5k2/2PK4/5r2/8/8/8/8 w - - 0 1")
get_mate(qr_tb, m43)
get_mate_line(qr_tb, m43, three_men_tb, verbose=true)

# 29 (21), 1000s
@time qk_tb = gen_4_men_1v1_TB(QUEEN, KNIGHT, three_men_tb)
test_consistency(qk_tb, three_men_tb)

m29 = Board("8/8/8/k7/8/n7/K5P1/8 w - - 0 1")
get_mate(qk_tb, m29)
m21 = Board("8/8/8/8/8/2k5/2n5/KQ6 w - - 0 1")
get_mate(qk_tb, m21)

# 29 (17),
@time qb_tb = gen_4_men_1v1_TB(QUEEN, BISHOP, three_men_tb)
test_consistency(qb_tb, three_men_tb)

m29 = Board("8/8/8/k7/8/b7/K5P1/8 w - - 0 1")
get_mate(qb_tb, m29)
m17 = Board("8/6Q1/8/4b3/3k4/8/8/K7 w - - 0 1")
get_mate(qb_tb, m17)

# 29 (13), 580s
# KQKP 3Q4/3K4/8/8/8/3k4/3p4/8 w - - 0 1
@time qq_tb = gen_4_men_1v1_TB(QUEEN, QUEEN, three_men_tb)
test_consistency(qq_tb, three_men_tb)

m29 = Board("8/8/8/k7/8/q7/K5P1/8 w - - 0 1")
get_mate(qq_tb, m29)
m13 = Board("8/8/8/8/8/8/8/qk1K2Q1 w - - 0 1")
get_mate(qq_tb, m13)

# 19, 170s
# KRKP 26 8/8/K7/3p4/8/3k4/4R3/8 w - - 0 1
@time rq_tb = gen_4_men_1v1_TB(ROOK, QUEEN, three_men_tb)
test_consistency(rq_tb, three_men_tb)

m19 = Board("8/8/8/8/8/1R6/6q1/K1k5 w - - 0 1")
get_mate(rq_tb, m19)


@time rk_tb = gen_4_men_1v1_TB(ROOK, KNIGHT, three_men_tb)
test_consistency(rk_tb, three_men_tb)

m40 = Board("8/2R5/8/8/7k/3K4/8/4n3 w - - 0 1")
get_mate(rk_tb, m40)


@time rb_tb = gen_4_men_1v1_TB(ROOK, BISHOP, three_men_tb)
test_consistency(rb_tb, three_men_tb)

m29 = Board("8/8/8/8/8/2R5/8/3K1bk1 w - - 0 1")
get_mate(rb_tb, m29)


@time rr_tb = gen_4_men_1v1_TB(ROOK, ROOK, three_men_tb)
test_consistency(rr_tb, three_men_tb)

m19 = Board("8/8/8/8/8/1R6/6r1/K1k5 w - - 0 1")
get_mate(rr_tb, m19)
