
board = Board("2r2bk1/2r2p1p/p2q2p1/P2Pp3/2p1P3/3B1P2/2R1Q1PP/3R2K1 w - - 0 30")

get_moves(board, true)

tonumber(Field("e1"))

get_moves(StartPosition(), true)

get_bishop_moves!(board.bishops, board.whites, board.whites | board.blacks, MoveList(200))
get_rook_moves!(board.rooks, board.whites, board.whites | board.blacks, MoveList(200))
get_queen_moves!(board.queens, board.whites, board.whites | board.blacks, MoveList(200))

board = Board("2p3p1/2P1P2P/8/Pp6/3rr3/1b1P1p2/PP2P3/8 w - - 0 1")

get_pawn_moves!(board.pawns, true, board.whites, board.blacks, board.whites | board.blacks, 0x2, MoveList(200))

print_fields(get_file(0x2))


board = Board()
set_piece!(board, Field("e1"), true, KING)
set_piece!(board, Field("e2"), true, PAWN)
set_piece!(board, Field("f2"), true, BISHOP)
set_piece!(board, Field("d2"), true, QUEEN)
set_piece!(board, Field("c3"), true, KNIGHT)
set_piece!(board, Field("b4"), false, QUEEN)
set_piece!(board, Field("e5"), false, ROOK)
set_piece!(board, Field("h4"), false, BISHOP)
set_piece!(board, Field("h1"), true, ROOK)
board.castle |= WHITE_SHORT_CASTLE

print_fields(get_pinned(board, board.whites, board.blacks, board.whites | board.blacks))

using BenchmarkTools
board = Board("rnbqkbnr/1ppppppp/8/8/1pP5/P7/3PPPPP/RNBQKBNR b KQkq c3 0 1")
get_moves(board, false)

for m in get_moves(board, false)
    println(m)
end

is_attacked(board, board.whites, board.blacks, board.whites | board.blacks, tonumber(Field("c3")))
is_attacked(board, board.whites, board.blacks, board.whites | board.blacks, tonumber(Field("d2")))
is_attacked(board, board.whites, board.blacks, board.whites | board.blacks, tonumber(Field("e1")))

is_attacked(board, board.blacks, board.whites, board.whites | board.blacks, tonumber(Field("c3")))
is_attacked(board, board.blacks, board.whites, board.whites | board.blacks, tonumber(Field("b3")))

board = Board("r2qkb1r/1Q3pp1/p2p3p/3P1P2/N2pP3/4n3/PP4PP/1R3RK1 w - - 0 1")
@btime get_moves(board, true)



for m in get_moves(StartPosition(), true)
    println(m)
end


board = StartPosition()
make_move!(board, true, Move(PAWN, Field("e2"), Field("e4")))
move = Move(QUEEN, Field("d1"), Field("g4"))
undo = make_move!(board, true, move)

undo_move!(board, true, move, undo)


import Chess

b = Chess.startboard()
@btime Chess.moves($b)

@btime get_moves($StartPosition(), $true)


""
function check_consistency(board::Board, white::Bool, depth::Int)
    fen = FEN(board, white)
    board2 = Chess.fromfen(fen)


    _b = deepcopy(board)
    _b2 = deepcopy(board2)


    f1 = FEN(board, white)
    f2 = Chess.fen(board2) * " 0 1"
    if f1 != f2
        print_board(board)
        println()
        println(f1)
        println(board2)
        @assert false
    end
    ms = []
    try
        _board = deepcopy(board)
        ms = get_moves(board, white)
        @assert board == _board (_board, board)
    catch e
        @info "Error generating moves: " f1
        rethrow(e)
    end

    ms2 = Chess.moves(board2)
    for m2 in ms2
        m_string = Chess.tostring(m2)
        f = filter(m->m.from==tonumber(Field(m_string[1:2])) && m.to==tonumber(Field(m_string[3:4])), ms)
        if length(f) != 1
            for m in ms
                println(m)
            end
            for m in ms2
                println(m)
            end
            display(board)
            display(board.en_passant)
            display(board.castle)
            @info "$m2 $white"
            @info f1
            @info f2
            @assert false
        end
    end

    if length(ms) != length(ms2)
        for m in ms
            println(m)
        end
        for m in ms2
            println(m)
        end
        display(board)
        @info f1
        @info f2
        @assert false
    end

    if depth == 1
        return length(ms)
    else
        nodes = 0
        for m in ms
            m2 = ms2[findfirst(m2 -> Chess.tostring(m2) == tostring(m.from)*tostring(m.to), ms2)]

            undo = make_move!(board, white, m)
            board2 = Chess.domove(_b2, m2)

            if FEN(board, !white) != Chess.fen(board2) * " 0 1"
                @info(FEN(board, !white))
                @info(Chess.fen(board2) * " 0 1")
                display(_b)
                display(board)
                println("\n$m")
                println(board.en_passant)
                println(board2)

                @info(FEN(_b, white))
                @info(Chess.fen(_b2) * " 0 1")
                @assert false
            end


            nodes += check_consistency(board, !white, depth-1)

            undo_move!(board, white, m, undo)
            @assert _b == board _b m
        end
        return nodes
    end
end

check_consistency(StartPosition(), true, 6)

FEN(StartPosition(), true)

board = Board("rnbqkbnr/ppp1pppp/8/3p4/Q7/2P5/PP1PPPPP/RNB1KBNR b KQkq - 0 1")

pinned = get_pinned(board, board.whites, board.blacks, board.whites | board.blacks)
ml = MoveList(100)
get_pawn_moves!(board, true, board.whites, board.blacks, board.whites | board.blacks, pinned, ml)

for m in ml
    println(m)
end

get_moves(board, true)
