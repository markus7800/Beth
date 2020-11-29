
FieldSymbol = UInt8
Field = String

function cartesian(sn::Field)
    # conversion from ASCII Chars
    s = Int(sn[1]) - 96 # = a, ..., g
    n = Int(sn[2]) - 48 # = 1, ..., 8

    return (n, s)
end

function field(rank::Int, file::Int)::Field
    Char(96+file) * string(rank)
end

fields = Dict{FieldSymbol, Field}()
fti = Dict{Field, FieldSymbol}()

begin
    local i = 1
    for rank in 1:8
        for file in 1:8
            global fields[UInt8(i)] = field(rank, file)
            i += 1
        end
    end
end

const FIELDS = fields

for (k,v) in FIELDS
    fti[v] = k
end
const FtI = fti # Field to Index , a1 -> a etc



function symbol(field::Field)::FieldSymbol
    FtI[field]
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

# promotions
const PAWNTOQUEEN = Piece(9)
const PAWNTOKNIGHT = Piece(10)

const LONGCASTLE = 1
const SHORTCASTLE = 2

PieceSymbol = Char

const PIECES = Dict{PieceSymbol, Piece}(
    'P' => PAWN,
    'B' => BISHOP,
    'N' => KNIGHT,
    'R' => ROOK,
    'Q' => QUEEN,
    'K' => KING,
    'n' => PAWNTOKNIGHT,
    'q' => PAWNTOQUEEN
)

const SYMBOLS = [
    "P" "B" "N" "R" "Q" "K" "W" "B" "PQ" "PN";
    "p" "b" "n" "r" "q" "k" "W" "B" "pq" "pn"
]
