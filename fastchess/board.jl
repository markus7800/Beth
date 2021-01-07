mutable struct Board
    pawns::UInt64
    bishops::UInt64
    knights::UInt64
    rooks::UInt64
    queens::UInt64
    kings::UInt64
    whites::UInt64
    blacks::UInt64

    white_castle_q::Bool
    white_castle_k::Bool

    black_castle_q::Bool
    black_castle_k::Bool

    en_passant::UInt64
end

function Board()
    return Board(0,0,0,0,0,0,0,0, 0,0, 0,0, 0)
end

const Field = UInt64

function Field(rank::Int, file::Int)::Field
    f = UInt64(1)
    f = f << (8 * (rank - 1))
    f = f << (file - 1)
    return f
end

function Field(sn::String)::Field
    # conversion from ASCII Chars
    f = Int(sn[1]) - 96 # = a, ..., g
    r = Int(sn[2]) - 48 # = 1, ..., 8
    return Field(r, f)
end


const FILE_A = Field("a1") | Field("a2") | Field("a3") | Field("a4") | Field("a5") | Field("a6") | Field("a7") | Field("a8")
const FILE_B = Field("b1") | Field("b2") | Field("b3") | Field("b4") | Field("b5") | Field("b6") | Field("b7") | Field("b8")
const FILE_C = Field("c1") | Field("c2") | Field("c3") | Field("c4") | Field("c5") | Field("c6") | Field("c7") | Field("c8")
const FILE_D = Field("d1") | Field("d2") | Field("d3") | Field("d4") | Field("d5") | Field("d6") | Field("d7") | Field("d8")
const FILE_E = Field("e1") | Field("e2") | Field("e3") | Field("e4") | Field("e5") | Field("e6") | Field("e7") | Field("e8")
const FILE_F = Field("f1") | Field("f2") | Field("f3") | Field("f4") | Field("f5") | Field("f6") | Field("f7") | Field("f8")
const FILE_G = Field("g1") | Field("g2") | Field("g3") | Field("g4") | Field("g5") | Field("g6") | Field("g7") | Field("g8")
const FILE_H = Field("h1") | Field("h2") | Field("h3") | Field("h4") | Field("h5") | Field("h6") | Field("h7") | Field("h8")

const RANK_1 = Field("a1") | Field("b1") | Field("c1") | Field("d1") | Field("e1") | Field("f1") | Field("g1") | Field("h1")
const RANK_2 = Field("a2") | Field("b2") | Field("c2") | Field("d2") | Field("e2") | Field("f2") | Field("g2") | Field("h2")
const RANK_3 = Field("a3") | Field("b3") | Field("c3") | Field("d3") | Field("e3") | Field("f3") | Field("g3") | Field("h3")
const RANK_4 = Field("a4") | Field("b4") | Field("c4") | Field("d4") | Field("e4") | Field("f4") | Field("g4") | Field("h4")
const RANK_5 = Field("a5") | Field("b5") | Field("c5") | Field("d5") | Field("e5") | Field("f5") | Field("g5") | Field("h5")
const RANK_6 = Field("a6") | Field("b6") | Field("c6") | Field("d6") | Field("e6") | Field("f6") | Field("g6") | Field("h6")
const RANK_7 = Field("a7") | Field("b7") | Field("c7") | Field("d7") | Field("e7") | Field("f7") | Field("g7") | Field("h7")
const RANK_8 = Field("a8") | Field("b8") | Field("c8") | Field("d8") | Field("e8") | Field("f8") | Field("g8") | Field("h8")


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

    board.white_castle_q = true
    board.white_castle_k = true

    board.black_castle_q = true
    board.black_castle_k = true

    board.en_passant = 0

    return board
end


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

const PIECE_SYMBOLS = ['P', 'B', 'N', 'R', 'Q', 'K']

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


import Base.show
function Base.show(io::IO, board::Board)
    println(io, "Chess Board")
    for rank in 8:-1:1
        print(io,"$rank ")
        for file in 1:8
            s = "⋅"
            wp = get_piece(board, Field(rank, file), true)
            if wp != NO_PIECE
                s = PIECE_SYMBOLS[wp]
            end

            bp = get_piece(board, Field(rank, file), false)
            if bp != NO_PIECE
                s = lowercase(PIECE_SYMBOLS[bp])
            end

            print(io, "$s ")
            end
        print(io,"\n")
    end
    println(io,"  a b c d e f g h")
end
