using Test

@testset "Pawn Moves" begin
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

    # double attack
    board.position[cartesian("f6")...,[BISHOP,BLACK]] .= 1
    # if no king on board then it is assumed to be on a1
    board.position[cartesian("e1")...,[KING,WHITE]] .= 1
    board.can_en_passant .= 0
    ms = get_moves(board, true)
    @test (PAWN, symbol("e5"), symbol("d6")) in ms
    @test (PAWN, symbol("e5"), symbol("f6")) in ms

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
    @test !((PAWN, symbol("g2"), symbol("g1")) in get_moves(board, true))
    @test !((PAWN, symbol("c7"), symbol("c8")) in get_moves(board, false))

    move!(board, true, 'q', "c7", "c8")
    move!(board, false, 'n', "g2", "g1")

    @test all(board[cartesian("c8")..., [QUEEN, WHITE]])
    @test all(board[cartesian("g1")..., [KNIGHT, BLACK]])

    # promote with capture
    board = Board(false)
    board.position[cartesian("c7")..., [PAWN, WHITE]] .= 1
    board.position[cartesian("d8")..., [BISHOP, BLACK]] .= 1

    @test (PAWNTOKNIGHT, symbol("c7"), symbol("d8")) in get_moves(board, true)

    move!(board, true, PAWNTOKNIGHT, symbol("c7"), symbol("d8"))

    @test all(board[cartesian("d8")..., [KNIGHT, WHITE]])
    @test !any(board[cartesian("d8")..., [BISHOP, BLACK]])
end

@testset "Castling" begin
    # Loose castling rights afte king move
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

    # test rook position after castling
    board = Board(false)
    board.position[cartesian("e1")..., [KING, WHITE]] .= 1
    board.position[cartesian("a1")..., [ROOK, WHITE]] .= 1
    board.position[cartesian("h1")..., [ROOK, WHITE]] .= 1
    move!(board, true, 'K', "e1", "c1")
    @test all(board[cartesian("d1")..., [ROOK,WHITE]])


    ms = get_moves(board, true)
    @test !((KING, symbol("e1"), symbol("c1")) in ms)
    @test !((KING, symbol("e1"), symbol("g1")) in ms)


    # Move king back and forth
    board = Board(false)
    board.position[cartesian("e1")..., [KING, WHITE]] .= 1
    board.position[cartesian("a1")..., [ROOK, WHITE]] .= 1
    board.position[cartesian("h1")..., [ROOK, WHITE]] .= 1
    move!(board, true, 'K', "e1", "d1")
    move!(board, true, 'K', "d1", "e1")

    @test !((KING, symbol("e1"), symbol("c1")) in ms)
    @test !((KING, symbol("e1"), symbol("g1")) in ms)


    # Move rooks back and forth
    board = Board(false)
    board.position[cartesian("e8")..., [KING, BLACK]] .= 1
    board.position[cartesian("a8")..., [ROOK, BLACK]] .= 1
    board.position[cartesian("h8")..., [ROOK, BLACK]] .= 1

    move!(board, false, 'R', "a8", "a1")

    @test (KING, symbol("e8"), symbol("g8")) in get_moves(board, false)
    @test !((KING, symbol("e8"), symbol("c8")) in get_moves(board, false))

    move!(board, false, 'R', "a1", "a8")

    @test (KING, symbol("e8"), symbol("g8")) in get_moves(board, false)
    @test !((KING, symbol("e8"), symbol("c8")) in get_moves(board, false))

    move!(board, false, 'R', "h8", "g8")
    move!(board, false, 'R', "g8", "h8")

    @test !((KING, symbol("e8"), symbol("g8")) in get_moves(board, false))

    # castle not allowed due to attack
    board = Board(false)
    board.position[cartesian("e8")..., [KING, BLACK]] .= 1
    board.position[cartesian("a8")..., [ROOK, BLACK]] .= 1
    board.position[cartesian("h8")..., [ROOK, BLACK]] .= 1

    board.position[cartesian("d1")..., [ROOK, WHITE]] .= 1


    @test (KING, symbol("e8"), symbol("g8")) in get_moves(board, false)
    @test !((KING, symbol("e8"), symbol("c8")) in get_moves(board, false))

    board.position[cartesian("a2")..., [BISHOP, WHITE]] .= 1

    @test !((KING, symbol("e8"), symbol("g8")) in get_moves(board, false))
    @test !((KING, symbol("e8"), symbol("c8")) in get_moves(board, false))

    # no castling when rook was captured but did not move prior
    board = Board(false)
    board.position[cartesian("e8")..., [KING, BLACK]] .= 1
    board.position[cartesian("a8")..., [ROOK, BLACK]] .= 1
    board.position[cartesian("h8")..., [ROOK, BLACK]] .= 1

    board.position[cartesian("a1")..., [ROOK, WHITE]] .= 1

    @test (KING, symbol("e8"), symbol("g8")) in get_moves(board, false)
    @test (KING, symbol("e8"), symbol("c8")) in get_moves(board, false)

    move!(board, true, 'R', "a1", "a8")
    @test is_in_check(board, BLACK)
    move!(board, true, 'R', "a8", "a2")
    @test !is_in_check(board, BLACK)

    @test (KING, symbol("e8"), symbol("g8")) in get_moves(board, false)
    @test !((KING, symbol("e8"), symbol("c8")) in get_moves(board, false))

    # opponent piece also blocks castling
    board = Board(false)
    board.position[cartesian("e8")..., [KING, BLACK]] .= 1
    board.position[cartesian("a8")..., [ROOK, BLACK]] .= 1
    board.position[cartesian("h8")..., [ROOK, BLACK]] .= 1

    board.position[cartesian("g8")..., [KNIGHT, WHITE]] .= 1

    @test !((KING, symbol("e8"), symbol("g8")) in get_moves(board, false))
    @test (KING, symbol("e8"), symbol("c8")) in get_moves(board, false)

    # castling from check not allowed
    board = Board(false)
    board.position[cartesian("e1")..., [KING, WHITE]] .= 1
    board.position[cartesian("a1")..., [ROOK, WHITE]] .= 1
    board.position[cartesian("h1")..., [QUEEN, BLACK]] .= 1
    ms = get_moves(board, true)
    @test !(('K', symbol("e1"), symbol("c1")) in ms)
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


    board = Board(false)
    board.position[cartesian("c7")..., [PAWN, WHITE]] .= 1
    board.position[cartesian("g2")..., [PAWN, BLACK]] .= 1

    m = short_to_long(board, true, "c8Q")
    @test m in get_moves(board, true)
    m = short_to_long(board, false, "g1N")
    @test m in get_moves(board, false)
end

@testset "Checks and Attacks" begin

    board = Board(false)
    # Knight check
    board.position[cartesian("c5")..., [KNIGHT, WHITE]] .= 1
    board.position[cartesian("e6")..., [KING, BLACK]] .= 1

    @test is_in_check(board, BLACK)

    # bishop check and !xray attack
    board.position[cartesian("c5")..., [KNIGHT, WHITE]] .= 0
    board.position[cartesian("a2")..., [BISHOP, WHITE]] .= 1
    board.position[cartesian("g8")..., [QUEEN, BLACK]] .= 1

    @test is_in_check(board, BLACK)

    @test !is_attacked(board, WHITE, BLACK, cartesian("g8"))
    @test is_attacked(board, BLACK, WHITE, cartesian("e6"))
    @test !is_attacked(board, BLACK, WHITE, cartesian("a2"))

    # !xray check, rook attack
    board.position[cartesian("d5")..., [ROOK, WHITE]] .= 1

    @test !is_in_check(board, BLACK)
    @test is_attacked(board, BLACK, WHITE, cartesian("d1"))

    # pawn checks and not checks (own king)
    board = Board(false)

    board.position[cartesian("c2")..., [KING, WHITE]] .= 1
    board.position[cartesian("e6")..., [KING, BLACK]] .= 1

    board.position[cartesian("b3")..., [PAWN, BLACK]] .= 1

    board.position[cartesian("d5")..., [PAWN, BLACK]] .= 1
    board.position[cartesian("f5")..., [PAWN, BLACK]] .= 1

    board.position[cartesian("d7")..., [PAWN, WHITE]] .= 1
    board.position[cartesian("f7")..., [PAWN, WHITE]] .= 1

    @test !is_in_check(board, BLACK)
    @test is_in_check(board, WHITE)
end

@testset "Undos" begin

    # one pawn move
    board = Board(false)
    board.position[cartesian("e7")..., [PAWN, BLACK]] .= 1

    _board = deepcopy(board)
    capture, en_passant, castle = move!(board, false, PAWN, symbol("e7"), symbol("e6"))
    undo!(board, false, PAWN, symbol("e7"), symbol("e6"), capture, en_passant, castle)

    @test all(board.position .== _board.position) && all(board.can_en_passant .== _board.can_en_passant) && all(board.can_castle .== _board.can_castle)


    # pawn en passant capture
    board = Board(false)
    board.position[cartesian("e7")..., [PAWN, BLACK]] .= 1
    board.position[cartesian("f5")..., [PAWN, WHITE]] .= 1
    capture, en_passant, castle = move!(board, false, PAWN, symbol("e7"), symbol("e5"))

    _board = deepcopy(board)
    capture, en_passant, castle = move!(board, true, PAWN, symbol("f5"), symbol("e6"))
    undo!(board, true, PAWN, symbol("f5"), symbol("e6"), capture, en_passant, castle)

    @test all(board.position .== _board.position) && all(board.can_en_passant .== _board.can_en_passant) && all(board.can_castle .== _board.can_castle)


    # same piece capture
    board = Board(false)
    board.position[cartesian("e7")..., [ROOK, BLACK]] .= 1
    board.position[cartesian("e1")..., [ROOK, WHITE]] .= 1


    _board = deepcopy(board)
    capture, en_passant, castle = move!(board, false, ROOK, symbol("e7"), symbol("e1"))
    undo!(board, false, ROOK, symbol("e7"), symbol("e1"), capture, en_passant, castle)

    @test all(board.position .== _board.position) && all(board.can_en_passant .== _board.can_en_passant) && all(board.can_castle .== _board.can_castle)


    # castle
    board = Board(false)
    board.position[cartesian("a1")..., [ROOK, WHITE]] .= 1
    board.position[cartesian("e1")..., [KING, WHITE]] .= 1

    _board = deepcopy(board)
    capture, en_passant, castle = move!(board, true, KING, symbol("e1"), symbol("c1"))
    undo!(board, true, KING, symbol("e1"), symbol("c1"), capture, en_passant, castle)

    @test all(board.position .== _board.position) && all(board.can_en_passant .== _board.can_en_passant) && all(board.can_castle .== _board.can_castle)
end

nothing
