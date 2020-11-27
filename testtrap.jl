
board = Board()
print_board(board)

move!(board, true, 'P', "e2", "e4", verbose=true)
move!(board, false, 'P', "e7", "e5", verbose=true)
print_board(board)

move!(board, true, 'N', "g1", "f3", verbose=true)
move!(board, false, 'N', "b8", "c6", verbose=true)
print_board(board)

move!(board, true, 'B', "f1", "c4", verbose=true)
move!(board, false, 'P', "d7", "d6", verbose=true)
print_board(board)

move!(board, true, 'N', "b1", "c3", verbose=true)
move!(board, false, 'B', "c8", "g4", verbose=true)
print_board(board)

move!(board, true, 'N', "f3", "e5", verbose=true)
move!(board, false, 'B', "g4", "d1", verbose=true)
print_board(board)

move!(board, true, 'B', "c4", "f7", verbose=true)
print_board(board)
is_check(board, BLACK, verbose=true)
string.(get_moves(board, false))
move!(board, false, 'K', "e8", "e7", verbose=true)
is_check(board, BLACK, verbose=true)

print_board(board)
move!(board, true, 'N', "c3", "d5", verbose=true)

print_board(board)
