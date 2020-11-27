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
