FieldSymbol = Char

const FIELDS = Dict{FieldSymbol, String}(
    'a' => "a1",
    'b' => "b1",
    'c' => "c1",
    'd' => "d1",
    'e' => "e1",
    'f' => "f1",
    'g' => "g1",
    'h' => "h1",
    'i' => "a2",
    'j' => "b2",
    'k' => "c2",
    'l' => "d2",
    'm' => "e2",
    'n' => "f2",
    'o' => "g2",
    'p' => "h2",
    'q' => "a3",
    'r' => "b3",
    's' => "c3",
    't' => "d3",
    'u' => "e3",
    'v' => "f3",
    'w' => "g3",
    'x' => "h3",
    'y' => "a4",
    'z' => "b4",
    'A' => "c4",
    'B' => "d4",
    'C' => "e4",
    'D' => "f4",
    'E' => "g4",
    'F' => "h4",
    'G' => "a5",
    'H' => "b5",
    'I' => "c5",
    'J' => "d5",
    'K' => "e5",
    'L' => "f5",
    'M' => "g5",
    'N' => "h5",
    'O' => "a6",
    'P' => "b6",
    'Q' => "c6",
    'R' => "d6",
    'S' => "e6",
    'T' => "f6",
    'U' => "g6",
    'V' => "h6",
    'W' => "a7",
    'X' => "b7",
    'Y' => "c7",
    'Z' => "d7",
    '0' => "e7",
    '1' => "f7",
    '2' => "g7",
    '3' => "h7",
    '4' => "a8",
    '5' => "b8",
    '6' => "c8",
    '7' => "d8",
    '8' => "e8",
    '9' => "f8",
    '!' => "g8",
    '?' => "h8"
)


Field = String

fti = Dict{Field, FieldSymbol}()
for (k,v) in FIELDS
    fti[v] = k
end
const FtI = fti # Field to Index , a1 -> a etc

function symbol(field::Field)::FieldSymbol
    FtI[field]
end

function cartesian(sn::Field)
    # conversion from ASCII Chars
    s = Int(sn[1]) - 96 # = a, ..., g
    n = Int(sn[2]) - 48 # = 1, ..., 8

    return (n, s)
end

function field(rank::Int, file::Int)::Field
    Char(96+file) * string(rank)
end

symbol(rank::Int, file::Int) = symbol(field(rank,file))
field(symbol::FieldSymbol) = FIELDS[symbol]

Piece = UInt8
const PAWN = Piece(1)
const BISHOP = Piece(2)
const KNIGHT = Piece(3)
const ROOK = Piece(4)
const QUEEN = Piece(5)
const KING = Piece(6)
const WHITE = Piece(7)
const BLACK = Piece(8) # redundant but whatever

PieceSymbol = Char

const PIECES = Dict{PieceSymbol, Piece}(
    'P' => PAWN,
    'B' => BISHOP,
    'N' => KNIGHT,
    'R' => ROOK,
    'Q' => QUEEN,
    'K' => KING
)

const SYMBOLS = [
    "P" "B" "N" "R" "Q" "K";
    "p" "b" "n" "r" "q" "k"
]

# AS OF NOW AUTOQUEEN


#=
b = Board()

move!(b, true, 'P', "e2", "e4")
println(b)
move!(b, false, 'P', "d7", "d5")
println(b)

function short_to_long(board::Board, white::Bool, s::String)
    println("Input: $s")
    # todo
    if s == "O-O" || s == "O-O-O"
        return s
    end

    s = replace(s, "x" => "") # remove captures
    s = replace(s, "+" => "") # remove check

    # handle pawn
    if islowercase(s[1])
        s = 'P' * s
    end

    piece = s[1]
    @assert piece in PIECES.keys "Invalid piece!"
    s = s[2:end]
    println("Piece: $piece")

    println(s)
end

examples = [
    "Bc4",
    "Bxc4",
    "axb4",
    "fxg6",
    "Nec4",
    "Nexc4",
    "R1c7",
    "cxd8+"
]

s = "cxd8+"
s .in ["x","+"]

short_to_long.(examples)
=#
