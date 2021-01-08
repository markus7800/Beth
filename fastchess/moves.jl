using StaticArrays

struct Move
    from_piece::Piece
    from::Int # field number
    to::Int # field number
    to_piece::Piece # promotion
end

include("movelist.jl")

include("FEN.jl")

function Move(piece::Piece, from::Int, to::Int)
    return Move(piece, from, to, piece)
end

function Base.show(io::IO, move::Move)
    if move.from_piece == move.to_piece
        print(io, "$(PIECE_SYMBOLS[move.from_piece]): $(tostring(move.from))-$(tostring(move.to))")
    else
        print(io, "$(PIECE_SYMBOLS[move.from_piece]): $(tostring(move.from))-$(tostring(move.to)) $(PIECE_SYMBOLS[move.to_piece])")
    end
end

mutable struct Undo
    captured::Piece
    capture_field::Field
    castle::UInt8
    did_castle::UInt8
    en_passant::UInt8
end

function make_move!(board::Board, white::Bool, move::Move)::Undo
    undo = Undo(
        get_piece(board, move.to), # potential captured piece
        move.to,
        board.castle,
        0,
        board.en_passant)

    @assert get_piece(board, move.from, white) == move.from_piece (board, move)
    @assert get_piece(board, move.to, white) == NO_PIECE (board, move)

    # disable en passant
    board.en_passant = 0

    # handle piece movement
    remove_piece!(board, move.from)
    remove_piece!(board, move.to)
    set_piece!(board, move.to, white, move.to_piece) # promotion handled in to_piece

    r1, f1 = rankfile(move.from)
    r2, f2 = rankfile(move.to)

    # enable en passant
    if move.from_piece == PAWN && abs(r1 - r2) == 2
        board.en_passant = f1
    end

    # capture en passant
    if move.from_piece == PAWN && abs(f1 - f2) == 1 && undo.captured == NO_PIECE
        @assert undo.en_passant == f2
        dir = white ? -1 : 1
        @assert get_piece(board, Field(r2 + dir, f2), !white) == PAWN
        undo.captured = PAWN
        undo.capture_field = Field(r2 + dir, f2)
        remove_piece!(board, undo.capture_field)
    end

    # handle castle
    if move.from_piece == KING
        # disable castling
        if white
            board.castle &= BLACK_SHORT_CASTLE | BLACK_LONG_CASTLE # only opponent has potential castling rights
        else
            board.castle &= WHITE_SHORT_CASTLE | WHITE_LONG_CASTLE
        end

        if f2 - f1 == 2 # castle short
            remove_piece!(board, Field(r1, 8))
            set_piece!(board, Field(r1, 6), white, ROOK)
            undo.did_castle = white ? WHITE_SHORT_CASTLE : BLACK_SHORT_CASTLE
        elseif f1 - f2 == 2 # castle long
            remove_piece!(board, Field(r1, 1))
            set_piece!(board, Field(r1, 4), white, ROOK)
            undo.did_castle = white ? WHITE_LONG_CASTLE : BLACK_LONG_CASTLE
        end
    end

    if move.from_piece == ROOK
        if white && r1 == 1
            if f1 == 1
                board.castle &= ~WHITE_LONG_CASTLE
            elseif f1 == 8
                board.castle &= ~WHITE_SHORT_CASTLE
            end
        elseif !white && r1 == 8
            if f1 == 1
                board.castle &= ~BLACK_LONG_CASTLE
            elseif f1 == 8
                board.castle &= ~BLACK_SHORT_CASTLE
            end
        end
    end

    if undo.captured == ROOK
        # no castling for opponent if player captures his rook
        if white && r2 == 1
            if f2 == 1
                board.castle &= ~WHITE_LONG_CASTLE
            elseif f2 == 8
                board.castle &= ~WHITE_SHORT_CASTLE
            end
        elseif !white && r2 == 8
            if f2 == 1
                board.castle &= ~BLACK_LONG_CASTLE
            elseif f2 == 8
                board.castle &= ~BLACK_SHORT_CASTLE
            end
        end
    end


    return undo
end

function undo_move!(board::Board, white::Bool, move::Move, undo::Undo)
    # undo piece move
    remove_piece!(board, move.to) # promotion handled
    set_piece!(board, move.from, white, move.from_piece)

    # undo capture
    if undo.captured != NO_PIECE
        @assert get_piece(board, undo.capture_field) == NO_PIECE
        set_piece!(board, undo.capture_field, !white, undo.captured)
    end

    board.en_passant = undo.en_passant
    board.castle = undo.castle

    if undo.did_castle > 0
        r1, f1 = rankfile(move.from)
        if undo.did_castle == WHITE_SHORT_CASTLE || undo.did_castle == BLACK_SHORT_CASTLE
            @assert get_piece(board, Field(r1, 6), white) == ROOK (move, board, undo)
            remove_piece!(board, Field(r1, 6))
            set_piece!(board, Field(r1, 8), white, ROOK)
        elseif undo.did_castle == WHITE_LONG_CASTLE || undo.did_castle == BLACK_LONG_CASTLE
            @assert get_piece(board, Field(r1, 4), white) == ROOK (move, board, undo)
            remove_piece!(board, Field(r1, 4))
            set_piece!(board, Field(r1, 1), white, ROOK)
        end
    end

end

const PAWNPUSH = [[(-1, 0)], [(1, 0)]] # black at 1, white at 2
const PAWNDIAG = [[(-1, 1), (-1, -1)], [(1, 1), (1, -1)]] # black at 1, white at 2
const DIAG = [(-1,-1), (1,-1), (-1, 1), (1, 1)]
const CROSS = [(0,1), (0,-1), (1,0), (-1,0)]
const KNIGHTDIRS = [
        (1,2), (1,-2), (-1,2), (-1,-2),
        (2,1), (2,-1), (-2,1), (-2,-1)
        ]
const DIAGCROSS = vcat(DIAG, CROSS)

function get_moves(board::Board, white::Bool)::Vector{Move}
    moves = Move[]

    king_rank = -10
    king_file = -10 # move off board for evaluation without kings

    for rank in 1:8, file in 1:8
        piece = get_piece(board, Field(rank, file), white)

        piece == NO_PIECE && continue

        if piece == PAWN
            append!(moves, pawn_moves(board, white, rank, file))

        elseif piece == BISHOP
            append!(moves, direction_moves(board, white, BISHOP, rank, file, DIAG, 8))

        elseif piece == KNIGHT
            append!(moves, direction_moves(board, white, KNIGHT, rank, file, KNIGHTDIRS, 1))

        elseif piece == ROOK
            append!(moves, direction_moves(board, white, ROOK, rank, file, CROSS, 8))

        elseif piece == QUEEN
            append!(moves, direction_moves(board, white, QUEEN, rank, file, DIAGCROSS, 8))

        elseif piece == KING
            king_rank = rank
            king_file = file
            kingmoves = king_moves(board, white, rank, file)
            append!(moves, kingmoves)
        end
    end

    filter!(m -> !is_check(board, white, king_rank, king_file, m), moves)

    return moves
end


function king_moves(board::Board, white::Bool, rank::Int, file::Int)::Vector{Move}
    kingmoves = direction_moves(board, white, KING, rank, file, DIAGCROSS, 1)

    if !is_attacked(board, white, rank, file)
        if board.castle & (WHITE_LONG_CASTLE | BLACK_LONG_CASTLE) > 0
            if !is_occupied(board, Field(rank, 2) | Field(rank, 3) | Field(rank, 4)) && get_piece(board, Field(rank,1), white) == ROOK
                if !is_attacked(board, white, rank, 3) && !is_attacked(board, white, rank, 4)
                # castle long
                push!(kingmoves, Move(KING, Field(rank, file), Field(rank, file-2)))
                end
            end
        end
        if board.castle & (WHITE_SHORT_CASTLE | BLACK_SHORT_CASTLE) > 0
            if !is_occupied(board, Field(rank, 6) | Field(rank, 7)) && get_piece(board, Field(rank,8), white) == ROOK
                if !is_attacked(board, white, rank, 6) && !is_attacked(board, white, rank, 7)
                # castle long
                push!(kingmoves, Move(KING, Field(rank, file), Field(rank, file+2)))
                end
            end
        end
    end
    return kingmoves
end

function pawn_moves(board::Board, white::Bool, rank::Int, file::Int)::Vector{Move}
    moves = Move[]

    # normal moves
    if white && !is_occupied(board, Field(rank+1, file))
        push!(moves, Move(PAWN, Field(rank, file), Field(rank+1, file)))
    elseif !white && !is_occupied(board, Field(rank-1, file))
        push!(moves, Move(PAWN, Field(rank, file), Field(rank-1, file)))
    end

    # start moves
    if white && rank == 2 && !is_occupied(board, Field(rank+1, file) | Field(rank+2, file))
        push!(moves, Move(PAWN, Field(rank, file), Field(rank+2, file)))
    elseif !white && rank == 7 && !is_occupied(board, Field(rank-1, file) | Field(rank-2, file))
        push!(moves, Move(PAWN, Field(rank, file), Field(rank-2, file)))
    end

    # captures
    if white && file-1≥1 && is_occupied_by_black(board, Field(rank+1, file-1))
        push!(moves, Move(PAWN, Field(rank, file), Field(rank+1, file-1)))
    end
    if white && file+1≤8 && is_occupied_by_black(board, Field(rank+1, file+1))
        push!(moves, Move(PAWN, Field(rank, file), Field(rank+1, file+1)))
    end
    if !white && file-1≥1 && is_occupied_by_white(board, Field(rank-1, file-1))
        push!(moves, Move(PAWN, Field(rank, file), Field(rank-1, file-1)))
    end
    if !white && file+1≤8 && is_occupied_by_white(board, Field(rank-1, file+1))
        push!(moves, Move(PAWN, Field(rank, file), Field(rank-1, file+1)))
    end

    # en passant
    if white && rank == 5
        if file+1≤8 && board.en_passant == file + 1
            push!(moves, Move(PAWN, Field(rank, file), Field(rank+1, file+1)))
        elseif file-1≥1 && board.en_passant == file - 1
            push!(moves, Move(PAWN, Field(rank, file), Field(rank+1, file-1)))
        end
    elseif !white && rank == 4
        if file+1≤8 && board.en_passant == file + 1
            push!(moves, Move(PAWN, Field(rank, file), Field(rank-1, file+1)))
        elseif file-1≥1 && board.en_passant == file - 1
            push!(moves, Move(PAWN, Field(rank, file), Field(rank-1, file-1)))
        end
    end

    # promotions
    if (white && rank == 7) || (!white && rank == 2)
        knight_promo = map(m -> Move(PAWN, m.from, m.to, KNIGHT), moves)
        bishop_promo = map(m -> Move(PAWN, m.from, m.to, BISHOP), moves)
        rook_promo = map(m -> Move(PAWN, m.from, m.to, ROOK), moves)
        queen_promo = map(m -> Move(PAWN, m.from, m.to, QUEEN), moves)
        moves = vcat(moves, knight_promo, bishop_promo, rook_promo, queen_promo)
    end

    return moves
end

function direction_moves(board::Board, white::Bool, piece::Piece, rank::Int, file::Int, directions::Vector{Tuple{Int,Int}}, max_multiple::Int)
    moves = Move[]
    for dir in directions
        for i in 1:max_multiple

            r2, f2 = (rank, file) .+ i .* dir

            if r2 < 1 || r2 > 8 || f2 < 1 || f2 > 8
                # direction out of bounds
                break # direction finished
            end

            to = Field(r2, f2)
            if is_occupied(board, !white, to)
                # capture
                push!(moves, Move(piece, Field(rank, file), to))
                break # direction finished
            else
                if !is_occupied(board, white, to)
                    # free tile
                    push!(moves, Move(piece, Field(rank, file), to))
                else
                    # direction blocked by own piece
                    break # direction finished
                end
            end
        end
    end

    return moves
end

# checks if king of player is in check after move
# kingpos is position of king before move
function is_check(board::Board, white::Bool, king_rank::Int, king_file::Int, move::Move)

    undo = make_move!(board, white, move)

    if move.from_piece == KING
        # update king position for king move
        king_rank, king_file = rankfile(move.to)
    end

    b = is_attacked(board, white, king_rank, king_file)

    undo_move!(board, white, move, undo)

    return b
end

# checks if field rf (cartesian) is attacked by opponent
function is_attacked(board::Board, white::Bool, rank::Int, file::Int; verbose=false)

    # check knight moves
    for dir in KNIGHTDIRS
        r2, f2 = (rank, file) .+ dir # TODO
        (r2 < 1 || r2 > 8 || f2 < 1 || f2 > 8) && continue

        if get_piece(board, Field(r2, f2), !white) == KNIGHT # TODO: occupied by piece function
            verbose && println("Knight check from $(field(r2, f2)) ($r2, $f2).")
            return true
        end
    end

    # check diags
    for dir in DIAG
        for i in 1:8
            r2, f2 = (rank, file) .+ i .* dir # TODO

            if r2 < 1 || r2 > 8 || f2 < 1 || f2 > 8
                # direction out of bounds
                break
            end

            to = Field(r2, f2)

            if is_occupied(board, !white, to)
                p = get_piece(board, to, !white)

                if i == 1 && p == KING
                    verbose && println("King diag check from $to ($r2, $f2).")
                    return true
                end

                if p == BISHOP || p == QUEEN
                    verbose && println("Diag check from $to ($r2, $f2).")
                    return true
                else
                    # direction blocked by opponent piece
                    break
                end
            elseif is_occupied(board, white, to)
                # direction blocked by own piece
                break
            end
        end
    end

    # check crosses
    for dir in CROSS
        for i in 1:8
            r2, f2 = (rank, file) .+ i .* dir # TODO

            if r2 < 1 || r2 > 8 || f2 < 1 || f2 > 8
                # direction out of bounds
                break
            end

            to = Field(r2, f2)

            if is_occupied(board, !white, to)
                p = get_piece(board, to, !white)

                if i == 1 && p == KING
                    verbose && println("King diag check from $to ($r2, $f2).")
                    return true
                end

                if p == ROOK || p == QUEEN
                    verbose && println("Diag check from $to ($r2, $f2).")
                    return true
                else
                    # direction blocked by opponent piece
                    break
                end
            elseif is_occupied(board, white, to)
                # direction blocked by own piece
                break
            end
        end
    end

    # check pawn
    dir = white ? 1 : -1
    if rank+dir ≥ 1 && rank+dir ≤ 8
        if file-1 ≥ 1 && get_piece(board, Field(rank+dir, file-1), !white) == PAWN
            verbose && println("Pawn check from $((rank+dir, file-1)).")
            return true
        elseif file+1 ≤ 8 && get_piece(board, Field(rank+dir, file+1), !white) == PAWN
            verbose && println("Pawn check from $((rank+dir, file+1)).")
            return true
        end
    end

    return false
end


function perft(board::Board, white::Bool, depth::Int)
    _board = deepcopy(board)
    ms = get_moves(board, white)
    @assert _board == board (white, _board, board)

    if depth == 1
        return length(ms)
    else
        nodes = 0
        for m in ms
            undo = make_move!(board, white, m)
            nodes += perft(board, !white, depth-1)
            undo_move!(board, white, m, undo)
        end
        return nodes
    end
end

function divide(board::Board, white::Bool, depth::Int)
    println("Divide")
    ms = get_moves(board, white)
    sort!(ms, lt=(x,y)->field(x[2]) < field(y[2]))
    nodes = 0
    for m in ms
        undo = make_move!(board, white, m)
        nodes += perft(board, !white, depth-1)
        undo_move!(board, white, m, undo)
        println("$m $nodes")
    end
    return nodes
end


get_moves(StartPosition(), true)

using BenchmarkTools
@btime perft(StartPosition(), true, 5) # 2.428 s (14932604 allocations: 1.32 GiB)

perft(StartPosition(), true, 5)

board = StartPosition()
make_move!(board, true, Move(PAWN, Field("e2"), Field("e4")))
move =Move(QUEEN, Field("d1"), Field("g4"))
undo = make_move!(board, true, move)

undo_move!(board, true, move, undo)


function gen_direction_fields(rank::Int, file::Int, directions::Vector{Tuple{Int,Int}}, max_multiple::Int)::Fields
    fields = Fields(0)
    for dir in directions
        for i in 1:max_multiple

            r2, f2 = (rank, file) .+ i .* dir

            if r2 < 1 || r2 > 8 || f2 < 1 || f2 > 8
                # direction out of bounds
                break # direction finished
            end

            to = Field(r2, f2)
            fields |= to
        end
    end

    fields
end

function gen_direction_fields(n::Int, directions::Vector{Tuple{Int,Int}}, max_multiple::Int)::Fields
    return gen_direction_fields(rankfile(n)..., directions, max_multiple)
end

const WHITE_PAWN_PUSH_EMPTY = @SVector [gen_direction_fields(n, PAWNPUSH[2], 1) for n in 1:64]
const BLACK_PAWN_PUSH_EMPTY = @SVector [gen_direction_fields(n, PAWNPUSH[1], 1) for n in 1:64]

const WHITE_PAWN_CAP_EMPTY = @SVector [gen_direction_fields(n, PAWNDIAG[2], 1) for n in 1:64]
const BLACK_PAWN_CAP_EMPTY = @SVector [gen_direction_fields(n, PAWNDIAG[1], 1) for n in 1:64]

const KNIGHT_MOVES_EMPTY = @SVector [gen_direction_fields(n, KNIGHTDIRS, 1) for n in 1:64]
const BISHOP_MOVES_EMPTY = @SVector [gen_direction_fields(n, DIAG, 8) for n in 1:64]
const ROOK_MOVES_EMPTY = @SVector [gen_direction_fields(n, CROSS, 8) for n in 1:64]
const QUEEN_MOVES_EMPTY = @SVector [gen_direction_fields(n, vcat(DIAG,CROSS), 8) for n in 1:64]
const KING_MOVES_EMPTY = @SVector [gen_direction_fields(n, vcat(DIAG,CROSS), 1) for n in 1:64]

# TODO: inbounds

function white_pawn_push_empty(number::Int)::Fields
    WHITE_PAWN_PUSH_EMPTY[number]
end
function black_pawn_push_empty(number::Int)::Fields
    BLACK_PAWN_PUSH_EMPTY[number]
end

function white_pawn_cap_empty(number::Int)::Fields
    WHITE_PAWN_CAP_EMPTY[number]
end
function black_pawn_cap_empty(number::Int)::Fields
    BLACK_PAWN_CAP_EMPTY[number]
end

function knight_move_empty(number::Int)::Fields
    KNIGHT_MOVES_EMPTY[number]
end
function bishop_move_empty(number::Int)::Fields
    BISHOP_MOVES_EMPTY[number]
end
function rook_move_empty(number::Int)::Fields
    ROOK_MOVES_EMPTY[number]
end
function queen_move_empty(number::Int)::Fields
    QUEEN_MOVES_EMPTY[number]
end
function king_move_empty(number::Int)::Fields
    KING_MOVES_EMPTY[number]
end


# diags and crosses only
function gen_fields_between(r1::Int, f1::Int, r2::Int, f2::Int, exc1=true, exc2=true)::Fields
    fields = Fields(0)

    if r1 > r2
        t = r2; r2 = r1; r1 = t;
        t = exc1; exc1 = exc2; exc2 = t;
        t = f2; f2 = f1; f1 = t;
    end


    if f1 == f2
        for r in r1+exc1:r2-exc2
            fields |= Field(r, f1)
        end
    elseif r1 == r2
        if f1 < f2
            for f in f1+exc1:f2-exc2
                fields |= Field(r1, f)
            end
        else
            for f in f2+exc2:f1-exc1
                fields |= Field(r1, f)
            end
        end
    elseif abs(f2 - f1) == abs(r2 - r1)
        if f1 < f2
            for i in exc1:(f2-f1)-exc2
                fields |= Field(r1+i, f1+i)
            end
        else
            for i in exc2:(f1-f2)-exc1
                fields |= Field(r1+i, f1-i)
            end
        end
    end


    fields
end

function gen_fields_between(n1::Int, n2::Int)::Fields
    return gen_fields_between(rankfile(n1)..., rankfile(n2)...)
end

print_fields(gen_fields_between(tonumber(Field("a1")), tonumber(Field("g7"))))
print_fields(gen_fields_between(tonumber(Field("e6")), tonumber(Field("c4"))))

print_fields(gen_fields_between(tonumber(Field("b7")), tonumber(Field("g7"))))
print_fields(gen_fields_between(tonumber(Field("b7")), tonumber(Field("b1"))))


print_fields(gen_fields_between(tonumber(Field("b7")), tonumber(Field("f3"))))
print_fields(gen_fields_between(tonumber(Field("f3")), tonumber(Field("b7"))))


# exclusive input fields
const FIELDS_BETWEEN = [gen_fields_between(n1, n2) for n1 in 1:64, n2 in 1:64]

function fields_between(n1::Int, n2::Int)::Fields
    FIELDS_BETWEEN[n1, n2]
end


# generates shadow of (r2,f2) from (r1,f1), (r2, f2) not in shadow
function gen_shadow(r1::Int, f1::Int, r2::Int, f2::Int)::Fields
    fields = Fields(0)

    if f1 == f2 && r1 == r2
        return fields
    end

    if f1 == f2
        if r1 < r2
            fields |= gen_fields_between(r2, f2, 8, f2, false, false)

        else
            fields |= gen_fields_between(r2, f2, 1, f2, false, false)
        end
    elseif r1 == r2
        if f1 < f2
            fields |= gen_fields_between(r2, f2, r2, 8, false, false)
        else
            fields |= gen_fields_between(r2, f2, r2, 1, false, false)
        end
    elseif abs(f2 - f1) == abs(r2 - r1)
        Δ = abs(f2 - f1)
        # diagonally
        if f1 < f2
            if r1 < r2
                # field 2 is to the topright of field 1
                Δ = min(8 - r2, 8 - f2) # minimal distance to right or top border
                fields |= gen_fields_between(r2, f2, r2 + Δ, f2 + Δ, false, false)

            else
                # field 2 is to the bottomright of field 1
                Δ = min(r2 - 1, 8 - f2) # minimal distance to right or bottom border
                fields |= gen_fields_between(r2, f2, r2 - Δ, f2 + Δ, false, false)
            end
        else
            if r1 < r2
                # field 2 is to the topleft of field 1
                Δ = min(8 - r2, f2 - 1) # minimal distance to top or left border
                fields |= gen_fields_between(r2, f2, r2 + Δ, f2 - Δ, false, false)
            else
                # field 2 is to the bottomleft of field 1
                Δ = min(r2 - 1, f2 - 1) # minimal distance to bottom or keft border
                fields |= gen_fields_between(r2, f2, r2 - Δ, f2 - Δ, false, false)
            end
        end
    end

    fields &= ~Field(r2, f2)

    return fields
end

function gen_shadow(n1::Int, n2::Int)::Fields
    return gen_shadow(rankfile(n1)..., rankfile(n2)...)
end

print_fields(gen_shadow(tonumber(Field("c2")),tonumber(Field("d3"))))
print_fields(gen_shadow(tonumber(Field("d3")),tonumber(Field("c2"))))

print_fields(gen_shadow(tonumber(Field("b5")),tonumber(Field("d3"))))
print_fields(gen_shadow(tonumber(Field("d3")),tonumber(Field("b5"))))

print_fields(gen_shadow(tonumber(Field("d3")),tonumber(Field("f5"))))
print_fields(gen_shadow(tonumber(Field("f5")),tonumber(Field("d3"))))

print_fields(gen_shadow(tonumber(Field("d3")),tonumber(Field("d5"))))
print_fields(gen_shadow(tonumber(Field("d5")),tonumber(Field("d3"))))


print_fields(gen_shadow(tonumber(Field("d3")),tonumber(Field("d7"))))
print_fields(gen_shadow(tonumber(Field("d7")),tonumber(Field("d3"))))

print_fields(gen_shadow(tonumber(Field("d7")),tonumber(Field("e3"))))

const SHADOW = [gen_shadow(n1, n2) for n1 in 1:64, n2 in 1:64]

function shadow(n1::Int, n2::Int)::Fields
    SHADOW[n1, n2]
end

function get_pinned(board::Board, player::Fields, opponent::Fields, occupied::Fields)
    king_field = board.kings & player
    king_field_number = tonumber(king_field)

    attackers = ((bishop_move_empty(king_field_number) & bishop_like(board)) |
        (rook_move_empty(king_field_number) & rook_like(board))) & opponent

    pinned = Fields(0)

    for a in attackers
        blockers = fields_between(a, king_field_number) & occupied
        # print_fields(blockers)
        if is_singleton(blockers)
            pinned |= blockers & player
        end
    end

    return pinned
end

# by opponent
function is_attacked(board::Board, player::Fields, opponent::Fields, occupied::Fields, field_number::Int)
    if opponent & board.knights & knight_move_empty(field_number) > 0
        return true
    end
    if opponent & board.pawns & white_pawn_cap_empty(field_number) > 0
        return true
    end
    if opponent & board.kings & king_move_empty(field_number) > 0
        return true
    end

    sliders = ((bishop_move_empty(field_number) & bishop_like(board)) |
        (rook_move_empty(field_number) & rook_like(board))) & opponent

    for s in sliders
        blockers = fields_between(s, field_number) & occupied
        # print_fields(blockers)
        if blockers == 0
            return true
        end
    end

    return false
end


function get_moves(board::Board, white::Bool)::MoveList
    movelist = MoveList(200) # maximum 200 moves
    player = white ? board.whites : board.blacks
    opponent = white ? board.blacks : board.whites
    occupied = player | opponent
    pinned = get_pinned(board, player, opponent, occupied)

    get_pawn_moves!(board, white, player, opponent, occupied, pinned, movelist)
    get_knight_moves!(board, player, pinned, movelist)
    get_bishop_moves!(board, player, occupied, pinned, movelist)
    get_rook_moves!(board, player, occupied, pinned, movelist)
    get_queen_moves!(board, player, occupied, pinned, movelist)
    get_king_moves!(board, white, player, opponent, occupied, movelist)

    return movelist
end

function get_pawn_moves!(board::Board, white::Bool, player::Fields, opponent::Fields, occupied::Fields, pinned::Fields, movelist::MoveList)
    for field_number in board.pawns & player
        if white
            moves = white_pawn_push_empty(field_number) & ~occupied
            if moves & RANK_3 > 0
                moves |= white_pawn_push_empty(field_number + 8) & ~occupied
            end
            caps = white_pawn_cap_empty(field_number)
            moves |= caps & opponent

            if board.en_passant > 0 && 33 ≤ field_number && field_number ≤ 40 # check rank
                file = get_file(en_passant)
                moves |= caps & file
            end
        else
            moves = black_pawn_push_empty(field_number) & ~occupied
            if moves & RANK_6 > 0
                moves |= black_pawn_push_empty(field_number + 8) & ~occupied
            end

            caps = black_pawn_cap_empty(field_number)
            moves |= caps & opponent

            if board.en_passant > 0 && 17 ≤ field_number && field_number ≤ 24 # check rank
                file = get_file(en_passant)
                moves |= caps & file
            end
        end


        promote = white ? (moves & RANK_8 > 0) : (moves & RANK_1 > 0)

        # println(tostring(field_number))
        # print_fields(moves)
        # println("promote: ", promote)king_field_number = tonumber(board.kings & player)

        if pinned & tofield(field_number) > 0
            king_field_number = tonumber(board.kings & player)
            field = tofield(field_number)
            for n in moves
                n_field = tofield(n)

                # dont leave pin
                if fields_between(field_number, king_field_number) & n_field > 0 || # retreat
                    fields_between(king_field_number, n) & field > 0 # advance

                    if !promote
                        push!(movelist, Move(PAWN, field_number, n))
                    else
                        push!(movelist, Move(PAWN, field_number, n, KNIGHT))
                        push!(movelist, Move(PAWN, field_number, n, BISHOP))
                        push!(movelist, Move(PAWN, field_number, n, ROOK))
                        push!(movelist, Move(PAWN, field_number, n, QUEEN))
                    end
                end
            end
        else
            for n in moves
                if !promote
                    push!(movelist, Move(PAWN, field_number, n))
                else
                    push!(movelist, Move(PAWN, field_number, n, KNIGHT))
                    push!(movelist, Move(PAWN, field_number, n, BISHOP))
                    push!(movelist, Move(PAWN, field_number, n, ROOK))
                    push!(movelist, Move(PAWN, field_number, n, QUEEN))
                end
            end
        end
    end
end

function get_knight_moves!(board::Board, player::Fields, pinned::Fields, movelist::MoveList)
    for field_number in board.knights & player & ~pinned
        moves = knight_move_empty(field_number)
        moves &= ~player
        for n in moves
            push!(movelist, Move(KNIGHT, field_number, n))
        end
        # print_fields(moves)
    end
end

function get_bishop_moves!(board::Board, player::Fields, occupied::Fields, pinned::Fields, movelist::MoveList)
    for field_number in board.bishops & player
        moves = bishop_move_empty(field_number)
        occupied_moves = moves & occupied
        for n in occupied_moves
            moves &= ~shadow(field_number, n) # remove fields behind closest pieces
        end
        moves &= ~player
        # print_fields(moves)

        if pinned & tofield(field_number) > 0
            king_field_number = tonumber(board.kings & player)
            field = tofield(field_number)
            for n in moves
                n_field = tofield(n)
                # dont leave pin
                if fields_between(field_number, king_field_number) & n_field > 0 || # retreat
                    fields_between(king_field_number, n) & field > 0 # advance

                    push!(movelist, Move(BISHOP, field_number, n))
                end
            end
        else
            for n in moves
                push!(movelist, Move(BISHOP, field_number, n))
            end
        end
    end
end

function get_rook_moves!(board::Board, player::Fields, occupied::Fields, pinned::Fields, movelist::MoveList)
    for field_number in board.rooks & player
        moves = rook_move_empty(field_number)
        occupied_moves = moves & occupied
        for n in occupied_moves
            moves &= ~shadow(field_number, n) # remove fields behind closest pieces
        end
        moves &= ~player
        # print_fields(moves)

        if pinned & tofield(field_number) > 0
            king_field_number = tonumber(board.kings & player)
            field = tofield(field_number)
            for n in moves
                n_field = tofield(n)
                # dont leave pin
                if fields_between(field_number, king_field_number) & n_field > 0 || # retreat
                    fields_between(king_field_number, n) & field > 0 # advance

                    push!(movelist, Move(ROOK, field_number, n))
                end
            end
        else
            for n in moves
                push!(movelist, Move(ROOK, field_number, n))
            end
        end
    end
end

function get_queen_moves!(board::Board, player::Fields, occupied::Fields, pinned::Fields, movelist::MoveList)
    for field_number in board.queens & player
        moves = queen_move_empty(field_number)
        occupied_moves = moves & occupied
        for n in occupied_moves
            moves &= ~shadow(field_number, n) # remove fields behind closest pieces
        end
        moves &= ~player
        # print_fields(moves)

        if pinned & tofield(field_number) > 0
            king_field_number = tonumber(board.kings & player)
            for n in moves
                king_field_number = tonumber(board.kings & player)
                field = tofield(field_number)
                for n in moves
                    n_field = tofield(n)
                    # dont leave pin
                    if fields_between(field_number, king_field_number) & n_field > 0 || # retreat
                        fields_between(king_field_number, n) & field > 0 # advance

                        push!(movelist, Move(QUEEN, field_number, n))
                    end
                end
            end
        else
            for n in moves
                push!(movelist, Move(QUEEN, field_number, n))
            end
        end
    end
end

function get_king_moves!(board::Board, white::Bool, player::Fields, opponent::Fields, occupied::Fields, movelist::MoveList)
    king_field = board.kings & player
    king_field_number = tonumber(king_field)
    moves = king_move_empty(king_field_number) & ~player
    for n in moves
        if !is_attacked(board, player, opponent, occupied, n)
            push!(movelist, Move(KING, king_field_number, n))
        end
    end

    if board.castle > 0
        if !is_attacked(board, player, opponent, occupied, king_field_number)
            if (white && (board.castle & WHITE_SHORT_CASTLE > 0)) ||
                (!white && (board.castle & BLACK_SHORT_CASTLE > 0))
                if !is_attacked(board, player, opponent, occupied, king_field_number + 1) &&
                    !is_attacked(board, player, opponent, occupied, king_field_number + 2)
                    push!(movelist, Move(KING, king_field_number, king_field_number + 2))
                end
            end
            if (white && (board.castle & WHITE_LONG_CASTLE > 0)) ||
                (!white && (board.castle & BLACK_LONG_CASTLE > 0))
                if !is_attacked(board, player, opponent, occupied, king_field_number - 1) &&
                    !is_attacked(board, player, opponent, occupied, king_field_number - 2)
                    push!(movelist, Move(KING, king_field_number, king_field_number - 2))
                end
            end
        end
    end
end

board = Board("2r2bk1/2r2p1p/p2q2p1/P2Pp3/2p1P3/3B1P2/2R1Q1PP/3R2K1 w - - 0 30")

get_moves(board, true)

tonumber(Field("e1"))

get_moves(StartPosition(), true)

get_bishop_moves!(board.bishops, board.whites, board.whites | board.blacks, MoveList(200))
get_rook_moves!(board.rooks, board.whites, board.whites | board.blacks, MoveList(200))
get_queen_moves!(board.queens, board.whites, board.whites | board.blacks, MoveList(200))

board = Board("2p3p1/2P1P2P/8/Pp6/3rr3/1b1P1p2/PP2P3/8 w - - 0 1")

get_pawn_moves!(board.pawns, true, board.whites, board.blacks, board.whites | board.blacks, 0x2, MoveList(200))

print_fields(get_file(0x2))


board = Board()
set_piece!(board, Field("e1"), true, KING)
set_piece!(board, Field("e2"), true, PAWN)
set_piece!(board, Field("f2"), true, BISHOP)
set_piece!(board, Field("d2"), true, QUEEN)
set_piece!(board, Field("c3"), true, KNIGHT)
set_piece!(board, Field("b4"), false, QUEEN)
set_piece!(board, Field("e5"), false, ROOK)
set_piece!(board, Field("h4"), false, BISHOP)
set_piece!(board, Field("h1"), true, ROOK)
board.castle |= WHITE_SHORT_CASTLE

print_fields(get_pinned(board, board.whites, board.blacks, board.whites | board.blacks))

using BenchmarkTools
get_moves(board, true)

for m in get_moves(board, true)
    println(m)
end

is_attacked(board, board.whites, board.blacks, board.whites | board.blacks, tonumber(Field("c3")))
is_attacked(board, board.whites, board.blacks, board.whites | board.blacks, tonumber(Field("d2")))
is_attacked(board, board.whites, board.blacks, board.whites | board.blacks, tonumber(Field("e1")))

is_attacked(board, board.blacks, board.whites, board.whites | board.blacks, tonumber(Field("c3")))
is_attacked(board, board.blacks, board.whites, board.whites | board.blacks, tonumber(Field("b3")))

board = Board("r2qkb1r/1Q3pp1/p2p3p/3P1P2/N2pP3/4n3/PP4PP/1R3RK1 w - - 0 1")
@btime get_moves(board, true)
