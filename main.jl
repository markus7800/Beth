include("chess.jl")
include("board.jl")
include("moves.jl")

board = Board(false)

board.position[4,4,[PAWN,WHITE]] .= 1
board.position[3,2,[PAWN,WHITE]] .= 1
board.position[4,2,[KNIGHT,WHITE]] .= 1
board.position[4,3,[KNIGHT,BLACK]] .= 1
board.position[1,7,[QUEEN,WHITE]] .= 1


println(board)

string.(get_moves(board, true))

printstyled("Hello", color=:blue, bold=true)

print_board(board, highlight="Qg1")

get_moves(board, true)


board = Board()

print_board(board)
move!(board, true, 'P', "e2", "e6")


m = (KING, symbol("e1"), symbol("c1"))

Base.summarysize(m)
Base.summarysize(KING)
Base.summarysize('e')
Base.summarysize('c')

Base.sizeof(m)

Base.summarysize(board)
Base.sizeof(board)


Base.summarysize(board.position)
Base.sizeof(board.position)

m = 0x01
Base.summarysize((m,m,m))
Base.summarysize(('A','c','d'))

using Dates
logg(x...) = println(now(), " ", join(x, " ")...); flush(stdout)

logg("test")

print("Download progress: $(2)%   ")
print("Download progress: $(2)%   \r")
flush(stdout)

function overprint(str)
    print("\u1b[2F")
    #Moves cursor to beginning of the line n (default 1) lines up
    print(str)   #prints the new line
    print("\u1b[0K")
   # clears  part of the line.
   #If n is 0 (or missing), clear from cursor to the end of the line.
   #If n is 1, clear from cursor to beginning of the line.
   #If n is 2, clear entire line.
   #Cursor position does not change.

    println() #prints a new line, i really don't like this arcane codes
end

#testing
println(1)
println(2)
println(3)
println(4)
println(5)
println("this is the number six")
overprint(7)
println(8)
