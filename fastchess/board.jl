

mutable struct Board
    pawns::Fields
    bishops::Fields
    knights::Fields
    rooks::Fields
    queens::Fields
    kings::Fields
    whites::Fields
    blacks::Fields

    castle::UInt8
    en_passant::UInt8 # file
end

const WHITE_SHORT_CASTLE = 0x1
const WHITE_LONG_CASTLE = 0x2
const BLACK_SHORT_CASTLE = 0x4
const BLACK_LONG_CASTLE = 0x8

const Piece = UInt8
const NO_PIECE = Piece(0)
const PAWN = Piece(1)
const BISHOP = Piece(2)
const KNIGHT = Piece(3)
const ROOK = Piece(4)
const QUEEN = Piece(5)
const KING = Piece(6)
const WHITE = Piece(7)
const BLACK = Piece(8)


function rook_like(board::Board)
    board.rooks | board.queens
end

function bishop_like(board::Board)
    board.bishops | board.queens
end

import Base.==
function ==(left::Board, right::Board)
    return left.pawns == right.pawns &&
        left.bishops == right.bishops &&
        left.knights == right.knights &&
        left.rooks == right.rooks &&
        left.queens == right.queens &&
        left.kings == right.kings &&
        left.whites == right.whites &&
        left.blacks == right.blacks &&
        left.castle == right.castle &&
        left.en_passant == right.en_passant
end

function Board()
    return Board(0,0,0,0,0,0,0,0, 0, 0)
end


function StartPosition()
    board = Board()

    board.pawns = RANK_2 | RANK_7
    board.bishops = Field("c1") | Field("f1") | Field("c8") | Field("f8")
    board.knights = Field("b1") | Field("g1") | Field("b8") | Field("g8")
    board.rooks = Field("a1") | Field("h1") | Field("a8") | Field("h8")
    board.queens = Field("d1") | Field("d8")
    board.kings = Field("e1") | Field("e8")

    board.whites = RANK_1 | RANK_2
    board.blacks = RANK_7 | RANK_8

    board.castle = WHITE_SHORT_CASTLE | WHITE_LONG_CASTLE | BLACK_SHORT_CASTLE | BLACK_LONG_CASTLE

    board.en_passant = 0

    return board
end

function get_piece(board::Board, field::Field)::Piece
    if board.pawns & field > 0
        return PAWN

    elseif board.bishops & field > 0
        return BISHOP

    elseif board.knights & field > 0
        return KNIGHT

    elseif board.rooks & field > 0
        return ROOK

    elseif board.queens & field > 0
        return QUEEN

    elseif board.kings & field > 0
        return KING

    else
        return NO_PIECE
    end
end

function get_piece(board::Board, field::Field, white::Bool)::Piece
    player = white ? board.whites : board.blacks

    if board.pawns & player & field > 0
        return PAWN
    elseif board.bishops & player & field > 0
        return BISHOP
    elseif board.knights & player & field > 0
        return KNIGHT
    elseif board.rooks & player & field > 0
        return ROOK
    elseif board.queens & player & field > 0
        return QUEEN
    elseif board.kings & player & field > 0
        return KING
    else
        return NO_PIECE
    end
end

function set_piece!(board::Board, field::Field, white::Bool, piece::Piece)
    @assert 1 ≤ piece && piece ≤ 6

    if white
        board.whites |=  field
    else
        board.blacks |=  field
    end

    if piece == PAWN
        board.pawns |= field

    elseif piece == BISHOP
        board.bishops |= field

    elseif piece == KNIGHT
        board.knights |= field

    elseif piece == ROOK
        board.rooks |= field

    elseif piece == QUEEN
        board.queens |= field

    elseif piece == KING
        board.kings |= field
    end
end

function remove_piece!(board::Board, field::Field)
    board.whites &= ~field
    board.blacks &= ~field

    board.pawns &= ~field
    board.bishops &= ~field
    board.knights &= ~field
    board.rooks &= ~field
    board.queens &= ~field
    board.kings &= ~field
end

function is_occupied(board::Board, fields::UInt64)
    (board.whites | board.blacks) & fields > 0
end

function is_occupied(board::Board, by::Bool, fields::UInt64)
    if by
        return is_occupied_by_white(board, fields)
    else
        return is_occupied_by_black(board, fields)
    end
end

function is_occupied_by_white(board::Board, fields::UInt64)
    board.whites & fields > 0
end

function is_occupied_by_black(board::Board, fields::UInt64)
    board.blacks & fields > 0
end


function n_pawns(board::Board, white::Bool)
    white ? count_ones(board.pawns & board.whites) : count_ones(board.pawns & board.blacks)
end

function n_knights(board::Board, white::Bool)
    white ? count_ones(board.knights & board.whites) : count_ones(board.knights & board.blacks)
end

function n_bishops(board::Board, white::Bool)
    white ? count_ones(board.bishops & board.whites) : count_ones(board.bishops & board.blacks)
end

function n_rooks(board::Board, white::Bool)
    white ? count_ones(board.rooks & board.whites) : count_ones(board.rooks & board.blacks)
end

function n_queens(board::Board, white::Bool)
    white ? count_ones(board.queens & board.whites) : count_ones(board.queens & board.blacks)
end

function n_pieces(board::Board, white::Bool)
    white ? count_ones(board.whites)-1 : count_ones(board.blacks)-1
end

function count_pieces(fields::Fields)
    return count_ones(fields)
end
