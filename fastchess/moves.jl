struct Move
    from_piece::Piece
    from::Field
    to::Field
    to_piece::Piece # promotion
end

function Move(piece::Piece, from::Field, to::Field)
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

const PAWNDIAG = [[(-1, 1), (-1, -1)], [(1, 1), (1, -1)]] # black at 1, white at 2
const DIAG = [(-1,-1), (1,-1), (-1, 1), (1, 1)]
const CROSS = [(0,1), (0,-1), (1,0), (-1,0)]
const KNIGHTMOVES = [
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
            append!(moves, direction_moves(board, white, KNIGHT, rank, file, KNIGHTMOVES, 1))

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
    for dir in KNIGHTMOVES
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
@btime perft(StartPosition(), true, 5)

perft(StartPosition(), true, 5)

board = StartPosition()
make_move!(board, true, Move(PAWN, Field("e2"), Field("e4")))
move =Move(QUEEN, Field("d1"), Field("g4"))
undo = make_move!(board, true, move)

undo_move!(board, true, move, undo)
