using Test

@testset "Moves:Pawn" begin
    board = Board(false)
    board.position[cartesian("e5")...,[PAWN,WHITE]] .= 1
    # single forward move
    ms = get_moves(board, true)
    p, rf1, rf2 = ms[1]
    @test length(ms) == 1 && rf1 == symbol("e5") && rf2 == symbol("e6")

    # en passant
    board.position[cartesian("f5")...,[PAWN,BLACK]] .= 1
    board.can_en_passant[2, 6] = true
    ms = get_moves(board, true)
    print_board(board)
    println(string.(ms))
    @test length(ms) == 2 && (PAWN, symbol("e5"), symbol("f6")) in ms

    # capture
    board.position[cartesian("d6")...,[QUEEN,BLACK]] .= 1
    ms = get_moves(board, true)
    print_board(board)
    println(string.(ms))
    @test length(ms) == 3 && (PAWN, symbol("e5"), symbol("d6")) in ms

    # block
    board.position[cartesian("e6")...,[KING,BLACK]] .= 1
    ms = get_moves(board, true)
    @test length(ms) == 2

    # en passant
    board = Board()
    move!(board, true, 'P', "e2", "e4")
    move!(board, false, 'P', "d7", "d5")
    move!(board, true, 'P', "e4", "e5")
    # check no en passant
    ms = get_moves(board, true)
    @test !((PAWN, symbol("e5"), symbol("d6")) in ms)

    move!(board, false, 'P', "f7", "f5")
    # check yes en passant
    @test !((PAWN, symbol("e5"), symbol("f6")) in ms)
end

@testset "Moves:Knight" begin
    @test true



end

board = Board(false)
board[5,5,[PAWN,WHITE]] .= 1

print_board(board)

board[5,5,[1,2]] = 1


board = Board(false)
board.position[cartesian("e5")...,[PAWN,WHITE]] .= 1



board.position[cartesian("f5")...,[PAWN,BLACK]] .= 1
ms = get_moves(board, true)

string.(ms)

('P', symbol("e5"), symbol("f6"))
print_board(board)
# single forward move
ms = get_moves(board, true)
p, rf1, rf2 = ms[1]

board = Board()
print_board(board)
move!(board, true, 'P', "e2", "e4")
print_board(board)
move!(board, false, 'P', "d7", "d5")
print_board(board)
move!(board, true, 'P', "e4", "e5")
print_board(board)
# check no en passant
move!(board, false, 'P', "f7", "f5")
print_board(board)
# check yes en passant
