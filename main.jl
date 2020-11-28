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
