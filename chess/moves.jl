
struct Move
    from_piece::Piece
    from::Int # field number
    to::Int # field number
    to_piece::Piece # promotion
end

const EMPTY_MOVE = Move(0x0, 0, 0, 0x0)

# TODO: maybe leads to confusion
function Move(piece::Piece, from::Field, to::Field)
    return Move(piece, tonumber(from), tonumber(to), piece)
end

function Move(from_piece::Piece, from::Field, to::Field, to_piece::Piece)
    return Move(from_piece, tonumber(from), tonumber(to), to_piece)
end

function Move(piece::Piece, from::Int, to::Int)
    return Move(piece, from, to, piece)
end

import Base.==
function ==(left::Move, right::Move)
    return left.from_piece == right.from_piece &&
        left.from == right.from &&
        left.to == right.to &&
        left.to_piece == right.to_piece
end

function Base.show(io::IO, move::Move)
    if move == EMPTY_MOVE
        print(io, "Empty Move")
        return
    end

    if move.from_piece == move.to_piece
        print(io, "$(PIECE_SYMBOLS[move.from_piece]): $(tostring(move.from))-$(tostring(move.to))")
    else
        print(io, "$(PIECE_SYMBOLS[move.from_piece]): $(tostring(move.from))-$(tostring(move.to)) $(PIECE_SYMBOLS[move.to_piece])")
    end
end

function toPGNformat(move::Move)
    if move.from_piece == move.to_piece
        return "$(PIECE_SYMBOLS[move.from_piece])$(tostring(move.from))$(tostring(move.to))"
    else
        return "$(PIECE_SYMBOLS[move.from_piece])$(tostring(move.from))$(tostring(move.to))=$(PIECE_SYMBOLS[move.to_piece])"
    end
end

mutable struct Undo
    captured::Piece
    capture_field::Field # field number
    castle::UInt8
    did_castle::UInt8
    en_passant::UInt8
end

function Base.show(io::IO, undo::Undo)
    print(io, "Undo(")
    if undo.captured > 0
        print(io, "captured ", PIECE_SYMBOLS[undo.captured], " at ", tostring(undo.capture_field))
    end
    if undo.did_castle > 0
        undo.did_castle == WHITE_SHORT_CASTLE && print(io, "K")
        undo.did_castle == WHITE_LONG_CASTLE && print(io, "Q")
        undo.did_castle == BLACK_SHORT_CASTLE && print(io, "k")
        undo.did_castle == BLACK_LONG_CASTLE && print(io, "q")
    end
    if undo.en_passant > 0
        print(io, " en passant: ", undo.en_passant)
    end
    print(io, ")")
end

const DEBUG_MOVE = false

include("movelist.jl")


function make_move!(board::Board, white::Bool, move::Move)::Undo

    from = tofield(move.from)
    to = tofield(move.to)

    undo = Undo(
        get_piece(board, to), # potential captured piece
        to,
        board.castle,
        0,
        board.en_passant)


    DEBUG_MOVE && @assert get_piece(board, from, white) == move.from_piece ("no piece at from", board, move, white)
    DEBUG_MOVE && @assert get_piece(board, to, white) == NO_PIECE ("own piece at to", board, move, white)

    # disable en passant
    board.en_passant = 0

    # handle piece movement
    remove_piece!(board, from)
    remove_piece!(board, to)
    set_piece!(board, to, white, move.to_piece) # promotion handled in to_piece

    r1, f1 = rankfile(from)
    r2, f2 = rankfile(to)

    # enable en passant
    if move.from_piece == PAWN && abs(r1 - r2) == 2
        board.en_passant = f1
    end

    # capture en passant
    if move.from_piece == PAWN && abs(f1 - f2) == 1 && undo.captured == NO_PIECE
        DEBUG_MOVE && @assert undo.en_passant == f2
        dir = white ? -1 : 1
        DEBUG_MOVE && @assert get_piece(board, Field(r2 + dir, f2), !white) == PAWN
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
        if !white && r2 == 1
            if f2 == 1
                board.castle &= ~WHITE_LONG_CASTLE
            elseif f2 == 8
                board.castle &= ~WHITE_SHORT_CASTLE
            end
        elseif white && r2 == 8
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

    from = tofield(move.from)
    to = tofield(move.to)

    # undo piece move
    remove_piece!(board, to) # promotion handled
    set_piece!(board, from, white, move.from_piece)

    # undo capture
    if undo.captured != NO_PIECE
        DEBUG_MOVE && @assert get_piece(board, undo.capture_field) == NO_PIECE
        set_piece!(board, undo.capture_field, !white, undo.captured)
    end

    board.en_passant = undo.en_passant
    board.castle = undo.castle

    if undo.did_castle > 0
        r1, f1 = rankfile(move.from)
        if undo.did_castle == WHITE_SHORT_CASTLE || undo.did_castle == BLACK_SHORT_CASTLE
            DEBUG_MOVE && @assert get_piece(board, Field(r1, 6), white) == ROOK (move, board, undo)
            remove_piece!(board, Field(r1, 6))
            set_piece!(board, Field(r1, 8), white, ROOK)
        elseif undo.did_castle == WHITE_LONG_CASTLE || undo.did_castle == BLACK_LONG_CASTLE
            DEBUG_MOVE && @assert get_piece(board, Field(r1, 4), white) == ROOK (move, board, undo)
            remove_piece!(board, Field(r1, 4))
            set_piece!(board, Field(r1, 1), white, ROOK)
        end
    end
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
function is_attacked(board::Board, white::Bool, player::Fields, opponent::Fields, occupied::Fields, field_number::Int)
    if opponent & board.knights & knight_move_empty(field_number) > 0
        return true
    end
    if white && (opponent & board.pawns & white_pawn_cap_empty(field_number) > 0)
        return true
    end
    if !white && (opponent & board.pawns & black_pawn_cap_empty(field_number) > 0)
        return true
    end
    if opponent & board.kings & king_move_empty(field_number) > 0
        return true
    end

    sliders = ((bishop_move_empty(field_number) & bishop_like(board)) |
        (rook_move_empty(field_number) & rook_like(board))) & opponent

    # print_fields(sliders)

    for s in sliders
        # println(tostring(s))
        blockers = fields_between(s, field_number) & occupied
        # print_fields(blockers)
        if blockers == 0
            return true
        end
    end

    return false
end

# is king of player in check ?
function is_in_check(board::Board, white::Bool, player::Fields, opponent::Fields, occupied::Fields)
    king_field_number = tonumber(board.kings & player)
    is_attacked(board, white, player, opponent, occupied, king_field_number)
end

function is_in_check(board::Board, white::Bool)
    player = white ? board.whites : board.blacks
    opponent = white ? board.blacks : board.whites
    occupied = player | opponent

    king_field_number = tonumber(board.kings & player)
    is_attacked(board, white, player, opponent, occupied, king_field_number)
end

function get_moves!(board::Board, white::Bool, movelist::MoveList)
    player = white ? board.whites : board.blacks
    opponent = white ? board.blacks : board.whites
    occupied = player | opponent
    pinned = get_pinned(board, player, opponent, occupied)

    filter = UInt64(0) - 1 # no filter
    get_pawn_moves!(board, white, player, opponent, occupied, pinned, filter, movelist)
    get_knight_moves!(board, player, pinned, filter, movelist)
    get_bishop_moves!(board, player, occupied, pinned, filter, movelist)
    get_rook_moves!(board, player, occupied, pinned, filter, movelist)
    get_queen_moves!(board, player, occupied, pinned, filter,  movelist)
    get_king_moves!(board, white, player, opponent, occupied, filter, movelist)

    if is_in_check(board, white, player, opponent, occupied)
        filter_evasions!(board, white, movelist)
    end
end

function get_moves(board::Board, white::Bool)::MoveList
    movelist = MoveList(200) # maximum 200 moves
    get_moves!(board, white, movelist)
    return movelist
end

function get_captures!(board::Board, white::Bool, movelist::MoveList)
    player = white ? board.whites : board.blacks
    opponent = white ? board.blacks : board.whites
    occupied = player | opponent
    pinned = get_pinned(board, player, opponent, occupied)

    filter = opponent
    get_pawn_moves!(board, white, player, opponent, occupied, pinned, filter, movelist)
    get_knight_moves!(board, player, pinned, filter, movelist)
    get_bishop_moves!(board, player, occupied, pinned, filter, movelist)
    get_rook_moves!(board, player, occupied, pinned, filter, movelist)
    get_queen_moves!(board, player, occupied, pinned, filter,  movelist)
    get_king_moves!(board, white, player, opponent, occupied, filter, movelist)

    if is_in_check(board, white, player, opponent, occupied)
        filter_evasions!(board, white, movelist)
    end
end

function get_captures(board::Board, white::Bool)::MoveList
    movelist = MoveList(100) # maximum 200 moves
    get_captures!(board, white, movelist)
    return movelist
end


function filter_evasions!(board::Board, white::Bool, movelist::MoveList)
    n_moves = length(movelist)
    count = 0
    for i in 1:n_moves
        move = movelist[i]
        undo = make_move!(board, white, move)
        if !is_in_check(board, white)
            count += 1
            movelist.moves[count] = move
        end
        undo_move!(board, white, move, undo)
    end
    movelist.count = count
end

function get_pawn_moves!(board::Board, white::Bool, player::Fields, opponent::Fields, occupied::Fields, pinned::Fields, filter::Fields, movelist::MoveList)
    for field_number in board.pawns & player
        if white
            moves = white_pawn_push_empty(field_number) & ~occupied
            if moves & RANK_3 > 0
                moves |= white_pawn_push_empty(field_number + 8) & ~occupied
            end
            caps = white_pawn_cap_empty(field_number)
            moves |= caps & opponent

            if board.en_passant > 0 && 33 ≤ field_number && field_number ≤ 40 # check rank
                file = get_file(board.en_passant)
                moves |= caps & file
            end
        else
            moves = black_pawn_push_empty(field_number) & ~occupied
            if moves & RANK_6 > 0
                moves |= black_pawn_push_empty(field_number - 8) & ~occupied
            end

            caps = black_pawn_cap_empty(field_number)
            moves |= caps & opponent

            if board.en_passant > 0 && 25 ≤ field_number && field_number ≤ 32 # check rank
                file = get_file(board.en_passant)
                moves |= caps & file
            end
        end

        moves &= filter

        promote = white ? (moves & RANK_8 > 0) : (moves & RANK_1 > 0)

        # println(tostring(field_number))
        # print_fields(moves)
        # println("promote: ", promote)

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

function get_knight_moves!(board::Board, player::Fields, pinned::Fields, filter::Fields, movelist::MoveList)
    for field_number in board.knights & player & ~pinned
        moves = knight_move_empty(field_number)
        moves &= ~player
        moves &= filter
        for n in moves
            push!(movelist, Move(KNIGHT, field_number, n))
        end
        # print_fields(moves)
    end
end

function get_bishop_moves!(board::Board, player::Fields, occupied::Fields, pinned::Fields, filter::Fields, movelist::MoveList)
    for field_number in board.bishops & player
        moves = bishop_move_empty(field_number)
        occupied_moves = moves & occupied
        for n in occupied_moves
            moves &= ~shadow(field_number, n) # remove fields behind closest pieces
        end
        moves &= ~player
        moves &= filter
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

function get_rook_moves!(board::Board, player::Fields, occupied::Fields, pinned::Fields, filter::Fields, movelist::MoveList)
    for field_number in board.rooks & player
        moves = rook_move_empty(field_number)
        occupied_moves = moves & occupied
        for n in occupied_moves
            moves &= ~shadow(field_number, n) # remove fields behind closest pieces
        end
        moves &= ~player
        moves &= filter
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

function get_queen_moves!(board::Board, player::Fields, occupied::Fields, pinned::Fields, filter::Fields, movelist::MoveList)
    for field_number in board.queens & player
        moves = queen_move_empty(field_number)
        occupied_moves = moves & occupied
        for n in occupied_moves
            moves &= ~shadow(field_number, n) # remove fields behind closest pieces
        end
        moves &= ~player
        moves &= filter
        # print_fields(moves)

        if pinned & tofield(field_number) > 0
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
        else
            for n in moves
                push!(movelist, Move(QUEEN, field_number, n))
            end
        end
    end
end

function get_king_moves!(board::Board, white::Bool, player::Fields, opponent::Fields, occupied::Fields, filter::Fields, movelist::MoveList)
    king_field = board.kings & player
    king_field_number = tonumber(king_field)
    moves = king_move_empty(king_field_number) & ~player

    moves &= filter

    for n in moves
        if !is_attacked(board, white, player, opponent, occupied, n)
            push!(movelist, Move(KING, king_field_number, n))
        end
    end

    if board.castle > 0
        if !is_attacked(board, white, player, opponent, occupied, king_field_number)
            if ((king_field << 2) & filter > 0) &&
                ((white && (board.castle & WHITE_SHORT_CASTLE > 0)) ||
                (!white && (board.castle & BLACK_SHORT_CASTLE > 0)))
                if (king_field << 1) & occupied == 0 &&
                    (king_field << 2) & occupied == 0 &&
                    !is_attacked(board, white, player, opponent, occupied, king_field_number + 1) &&
                    !is_attacked(board, white, player, opponent, occupied, king_field_number + 2)


                    push!(movelist, Move(KING, king_field_number, king_field_number + 2))
                end
            end
            if ((king_field >> 2) & filter > 0) &&
                ((white && (board.castle & WHITE_LONG_CASTLE > 0)) ||
                (!white && (board.castle & BLACK_LONG_CASTLE > 0)))
                if (king_field >> 1) & occupied == 0 &&
                    (king_field >> 2) & occupied == 0 &&
                    (king_field >> 3) & occupied == 0 &&
                    !is_attacked(board, white, player, opponent, occupied, king_field_number - 1) &&
                    !is_attacked(board, white, player, opponent, occupied, king_field_number - 2)
                    push!(movelist, Move(KING, king_field_number, king_field_number - 2))
                end
            end
        end
    end
end
