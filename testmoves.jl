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
    @test length(ms) == 2 && (PAWN, symbol("e5"), symbol("f6")) in ms

    # capture
    board.position[cartesian("d6")...,[QUEEN,BLACK]] .= 1
    ms = get_moves(board, true)
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

    # check promotions
    board = Board(false)
    board.position[cartesian("c7")..., [PAWN, WHITE]] .= 1
    board.position[cartesian("g2")..., [PAWN, BLACK]] .= 1

    @test (PAWNTOQUEEN, symbol("c7"), symbol("c8")) in get_moves(board, true)
    @test (PAWNTOKNIGHT, symbol("g2"), symbol("g1")) in get_moves(board, false)

    move!(board, true, 'q', "c7", "c8")
    move!(board, false, 'n', "g2", "g1")

    @test all(board[cartesian("c8")..., [QUEEN, WHITE]])
    @test all(board[cartesian("g1")..., [KNIGHT, BLACK]])

end

@testset "Moves:King" begin
    board = Board(false)
    board.position[cartesian("e1")..., [KING, WHITE]] .= 1
    board.position[cartesian("a1")..., [ROOK, WHITE]] .= 1
    board.position[cartesian("h1")..., [ROOK, WHITE]] .= 1

    ms = get_moves(board, true)

    @test ((KING, symbol("e1"), symbol("c1")) in ms)
    @test ((KING, symbol("e1"), symbol("g1")) in ms)


    move!(board, true, 'K', "e1", "g1")
    @test all(board[cartesian("f1")..., [ROOK,WHITE]])

    ms = get_moves(board, true)
    @test !((KING, symbol("e1"), symbol("c1")) in ms)
    @test !((KING, symbol("e1"), symbol("g1")) in ms)


    board = Board(false)
    board.position[cartesian("e1")..., [KING, WHITE]] .= 1
    board.position[cartesian("a1")..., [ROOK, WHITE]] .= 1
    board.position[cartesian("h1")..., [ROOK, WHITE]] .= 1
    move!(board, true, 'K', "e1", "c1")
    @test all(board[cartesian("d1")..., [ROOK,WHITE]])


    ms = get_moves(board, true)
    @test !((KING, symbol("e1"), symbol("c1")) in ms)
    @test !((KING, symbol("e1"), symbol("g1")) in ms)


    board = Board(false)
    board.position[cartesian("e1")..., [KING, WHITE]] .= 1
    board.position[cartesian("a1")..., [ROOK, WHITE]] .= 1
    board.position[cartesian("h1")..., [ROOK, WHITE]] .= 1
    move!(board, true, 'K', "e1", "d1")
    move!(board, true, 'K', "d1", "e1")

    @test !((KING, symbol("e1"), symbol("c1")) in ms)
    @test !((KING, symbol("e1"), symbol("g1")) in ms)

end

@testset "Chess notation" begin
    board = Board(false)
    board.position[cartesian("c5")..., [KNIGHT, WHITE]] .= 1
    board.position[cartesian("c7")..., [KNIGHT, WHITE]] .= 1
    board.position[cartesian("d6")..., [KNIGHT, WHITE]] .= 1
    board.position[cartesian("e3")..., [KNIGHT, WHITE]] .= 1
    board.position[cartesian("g7")..., [KNIGHT, WHITE]] .= 1

    @test (short_to_long(board, true, "Na8") == (KNIGHT, symbol("c7"), symbol("a8")))

    #string(short_to_long(board, true, "Na6"))
    @test (short_to_long(board, true, "N7a6") == (KNIGHT, symbol("c7"), symbol("a6")))

    #string(short_to_long(board, true, "Nb5"))
    @test (short_to_long(board, true, "Ncb5") == (KNIGHT, symbol("c7"), symbol("b5")))

    #string(short_to_long(board, true, "Nb5"))
    @test (short_to_long(board, true, "Ncd5") == (KNIGHT, symbol("c7"), symbol("d5")))

    #string(short_to_long(board, true, "Ne6"))
    #string(short_to_long(board, true, "Nce6"))
    #string(short_to_long(board, true, "N7e6"))
    @test (short_to_long(board, true, "Nc7e6") == (KNIGHT, symbol("c7"), symbol("e6")))

    #string(short_to_long(board, true, "Ne8"))
    @test (short_to_long(board, true, "Nce8") == (KNIGHT, symbol("c7"), symbol("e8")))

    @test (short_to_long(board, true, "O-O") == (KING, symbol("e1"), symbol("g1")))

    @test (short_to_long(board, true, "O-O-O") == (KING, symbol("e1"), symbol("c1")))
end
