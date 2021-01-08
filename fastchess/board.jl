
const Fields = UInt64

function first(fs::Fields)::Int
    # trailing_zeros is Int for UInt64
    trailing_zeros(fs) + 1
end

function removefirst(fs::Fields)::Fields
    fs & (fs - 1)
end

import Base.iterate
function Base.iterate(ss::Fields, state = ss)
    if state == 0
        nothing
    else
        (first(state), removefirst(state))
    end
end


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
    en_passant::UInt8
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

const Field = UInt64 # where only one bit set

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

# const tab64 = Int[0, 58, 1, 59, 47, 53, 2, 60, 39, 48, 27, 54, 33, 42, 3, 61,
#     51, 37, 40, 49, 18, 28, 20, 55, 30, 34, 11, 43, 14, 22, 4, 62,
#     57, 46, 52, 38, 26, 32, 41, 50, 36, 17, 19, 29, 10, 13, 21, 56,
#     45, 25, 31, 35, 16, 9, 12, 44, 24, 15, 8, 23, 7, 6, 5, 63 ]
#
# function log2_64(value::UInt64)
#     value |= value >> 1
#     value |= value >> 2
#     value |= value >> 4
#     value |= value >> 8
#     value |= value >> 16
#     value |= value >> 32
#     return tab64[((value * 0x03f6eaf2cd271461) >> 58)+1]
# end

function file(field::Field)::Int
    trailing_zeros(field) % 8 + 1
end

function rank(field::Field)::Int
    trailing_zeros(field) ÷ 8 + 1
end

function rankfile(field::Field)::Tuple{Int,Int}
    l = trailing_zeros(field)
    l ÷ 8 + 1, l % 8 + 1
end

function tostring(field::Field)
    rank, file = rankfile(field)
    return Char(96+file) * string(rank)
end

function tonumber(field::Field)
    trailing_zeros(field) + 1
end # ∈ [1,64]

function rankfile(number::Int)
    (number-1) ÷ 8 + 1, (number-1) % 8 + 1
end

function tostring(number::Int)
    rank, file = rankfile(number)
    return Char(96+file) * string(rank)
end


# rankfile(Field("a8"))
# rankfile(Field("b7"))
# rankfile(Field("c6"))
# rankfile(Field("d5"))
# rankfile(Field("e4"))
# rankfile(Field("f3"))
# rankfile(Field("g2"))
# rankfile(Field("h1"))


const FILE_A = Field("a1") | Field("a2") | Field("a3") | Field("a4") | Field("a5") | Field("a6") | Field("a7") | Field("a8")
const FILE_B = Field("b1") | Field("b2") | Field("b3") | Field("b4") | Field("b5") | Field("b6") | Field("b7") | Field("b8")
const FILE_C = Field("c1") | Field("c2") | Field("c3") | Field("c4") | Field("c5") | Field("c6") | Field("c7") | Field("c8")
const FILE_D = Field("d1") | Field("d2") | Field("d3") | Field("d4") | Field("d5") | Field("d6") | Field("d7") | Field("d8")
const FILE_E = Field("e1") | Field("e2") | Field("e3") | Field("e4") | Field("e5") | Field("e6") | Field("e7") | Field("e8")
const FILE_F = Field("f1") | Field("f2") | Field("f3") | Field("f4") | Field("f5") | Field("f6") | Field("f7") | Field("f8")
const FILE_G = Field("g1") | Field("g2") | Field("g3") | Field("g4") | Field("g5") | Field("g6") | Field("g7") | Field("g8")
const FILE_H = Field("h1") | Field("h2") | Field("h3") | Field("h4") | Field("h5") | Field("h6") | Field("h7") | Field("h8")

const FILES = [FILE_A, FILE_B, FILE_C, FILE_D, FILE_E, FILE_F, FILE_G, FILE_H]

# TODO: inbounds
function get_file(i)
    FILES[i]
end

const RANK_1 = Field("a1") | Field("b1") | Field("c1") | Field("d1") | Field("e1") | Field("f1") | Field("g1") | Field("h1")
const RANK_2 = Field("a2") | Field("b2") | Field("c2") | Field("d2") | Field("e2") | Field("f2") | Field("g2") | Field("h2")
const RANK_3 = Field("a3") | Field("b3") | Field("c3") | Field("d3") | Field("e3") | Field("f3") | Field("g3") | Field("h3")
const RANK_4 = Field("a4") | Field("b4") | Field("c4") | Field("d4") | Field("e4") | Field("f4") | Field("g4") | Field("h4")
const RANK_5 = Field("a5") | Field("b5") | Field("c5") | Field("d5") | Field("e5") | Field("f5") | Field("g5") | Field("h5")
const RANK_6 = Field("a6") | Field("b6") | Field("c6") | Field("d6") | Field("e6") | Field("f6") | Field("g6") | Field("h6")
const RANK_7 = Field("a7") | Field("b7") | Field("c7") | Field("d7") | Field("e7") | Field("f7") | Field("g7") | Field("h7")
const RANK_8 = Field("a8") | Field("b8") | Field("c8") | Field("d8") | Field("e8") | Field("f8") | Field("g8") | Field("h8")

const WHITE_SHORT_CASTLE = 0x1
const WHITE_LONG_CASTLE = 0x2
const BLACK_SHORT_CASTLE = 0x4
const BLACK_LONG_CASTLE = 0x8

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

function print_fields(fs::Fields)
    println("Fields")
    for rank in 8:-1:1
        print("$rank ")
        for file in 1:8
            s = "⋅"
            if fs & Field(rank, file) > 0
                s = "X"
            end

            print("$s ")
            end
        print("\n")
    end
    println("  a b c d e f g h")
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
