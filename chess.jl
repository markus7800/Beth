const FIELDS = Dict{Char, String}(
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


index_for_fields = Dict{String, Char}()
for (k,v) in FIELDS
    index_for_fields[v] = k
end
const FtI = index_for_fields # Field to Index , a1 -> a etc

const PAWN = 1
const BISHOP = 2
const KNIGHT = 3
const ROOK = 4
const QUEEN = 5
const KING = 6
const WHITE = 7
const BLACK = 8 # redundant but whatever

const PIECES = Dict{Char, Int}(
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

struct Board
    position::BitArray{3}
    # rows are ranks
    # columns are files
    # c2 -> (2,c) -> (2, 3)
    function Board()
        position = falses(8, 8, 8)
        position[[2,7],:,PAWN] .= 1
        position[[1,8], [3,6], BISHOP] .= 1
        position[[1,8], [2,7], KNIGHT] .= 1
        position[[1,8], [1,8], ROOK] .= 1
        position[[1,8], 4, QUEEN] .= 1 # d für dame
        position[[1,8], 5, KING] .= 1
        position[[1,2], :, WHITE] .= 1
        position[[7,8], :, BLACK] .= 1
        return new(position)
    end
end

import Base.getindex
function Base.getindex(b::Board, I...)
    Base.getindex(b.position, I...)
end
import Base.setindex!
function Base.setindex!(b::Board, I...)
    Base.setindex!(b.position, I...)
end

function cartesian(sn::String)
    # conversion from ASCII Chars
    s = Int(sn[1]) - 96 # = a, ..., g
    n = Int(sn[2]) - 48 # = 1, ..., 8

    return (n, s)
end

#=
    r1, f1: current field
    r2, f2: target field
    piece: 1-6
=#
function move!(board::Board, white::Bool, piece::Int, r1::Int, f1::Int, r2::Int, f2::Int)
    player = 7 + !white
    opponent = 7 + white
    @assert board[r1,f1,player] "No piece for player at $r1, $(f1)!"
    @assert !board[r2,f2,player] "Player tried to capture own piece!"
    if board[r2,f2,opponent]
        println("Captures!")
    end

    board[r2,f2,:] .= false # remove all figures from target field

    board[r1,f1,piece] = false
    board[r2,f2,piece] = true

    board[r1,f1,player] = false
    board[r2,f2,player] = true
end

#=
    rf1: current field as per FIELDS
    rf2: target field as per FIELDS
    p: piece as per PIECES
=#
function move!(board::Board, white::Bool, p::Char, rf1::Char, rf2::Char)
    move!(board, white, PIECES[p], cartesian(FIELDS[rf1])..., cartesian(FIELDS[rf2])...)
end

function move!(board::Board, white::Bool, p::Char, rf1::String, rf2::String)
    move!(board, white, PIECES[p], cartesian(rf1)..., cartesian(rf2)...)
end



import Base.show
function Base.show(io::IO, board::Board)

    println(io, "Chess Board")
    for rank in 8:-1:1
        print(io,"$rank ")
        for file in 1:8
            s = "⋅"
            if sum(board[rank,file,:]) != 0
                piece = argmax(board[rank,file,1:6])
                s = SYMBOLS[board[rank,file,BLACK]+1, piece]
            end

            print(io,"$s ")
        end
        print(io,"\n")
    end
    println(io,"  a b c d e f g h")
end

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
