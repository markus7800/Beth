
function perft(board::Board, white::Bool, depth::Int)
    ms = get_moves(board, white)
    if depth == 1
        return length(ms)
    else
        nodes = 0
        for m in ms
            a, b, c = move!(board, white, m[1], m[2], m[3])
            nodes += perft(board, !white, depth-1)
            undo!(board, white, m[1], m[2], m[3], a, b, c)
        end
        return nodes
    end
end

function divide(board::Board, white::Bool, depth::Int)
    println("Divide")
    ms = get_moves(board, white)
    sort!(ms, lt=(x,y)->field(x[2]) < field(y[2]))
    nodes = 0
    for m in ms
        a,b,c = move!(board, white, m[1], m[2], m[3])
        nodes += perft(board, !white, depth-1)
        undo!(board, white, m[1], m[2], m[3], a, b, c)
        println("$m $nodes")
    end
    return nodes
end

using BenchmarkTools
@btime perft(Board(), true, 5) # 8.52s


import Chess
function my_perftinternal(b::Chess.Board, depth::Int, ply::Int)
    if depth == 1
        Chess.movecount(b)
    else
        movelist = Chess.moves(b)
        result = 0
        for m ∈ movelist
            u = Chess.domove!(b, m)
            result += my_perftinternal(b, depth - 1, ply + 1)
            Chess.undomove!(b, u)
        end
        result
    end
end

function my_perft(b::Chess.Board, depth::Int)::Int
    if depth == 0
        1
    else
        my_perftinternal(b, depth, 0)
    end
end

@btime my_perft(Chess.startboard(), 5) # 27.501 ms (29669 allocations: 16.53 MiB)

@btime Chess.perft(Chess.startboard(), 5) # 28.886 ms (29680 allocations: 16.54 MiB)

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

    ms = get_moves(board, white)
    ms2 = Chess.moves(board2)
    for m2 in ms2
        m_string = Chess.tostring(m2)
        f = filter(m->m[2]==symbol(m_string[1:2]) && m[3]==symbol(m_string[3:4]), ms)
        if length(f) != 1
            for m in ms
                println(m)
            end
            for m in ms2
                println(m)
            end
            print_board(board)
            display(board.can_en_passant)
            display(board.can_castle)
            @info "$m2 $white"
            @info f1
            @info f2
            @assert false
        end
    end

    if length(ms) != length(ms2)
        for m in ms
            println(ms)
        end
        for m in ms2
            println(ms2)
        end
        @assert false
    end

    if depth == 1
        return length(ms)
    else
        nodes = 0
        for m in ms
            m2 = ms2[findfirst(m2 -> Chess.tostring(m2) ==field(m[2])*field(m[3]), ms2)]

            a, b, c = move!(board, white, m[1], m[2], m[3])
            board2 = Chess.domove(_b2, m2)

            if FEN(board, !white) != Chess.fen(board2) * " 0 1"
                @info(FEN(board, !white))
                @info(Chess.fen(board2) * " 0 1")
                print_board(_b)
                print_board(board)
                println("\n$m")
                println(board.can_en_passant)
                println(board2)

                @info(FEN(_b, white))
                @info(Chess.fen(_b2) * " 0 1")
                @assert false
            end


            nodes += check_consistency(board, !white, depth-1)

            undo!(board, white, m[1], m[2], m[3], a, b, c)
            @assert _b == board _b m
        end
        return nodes
    end
end
Chess.Move(Chess.Square()

Chess.perft(Chess.startboard(), 6)
check_consistency(Board(), true, 6)

m = Chess.moves(Chess.startboard())[10]


@time Chess.divide(Chess.startboard(), 5)
@time divide(Board(), true, 5)


@btime my_perft($(Chess.fromfen("7R/5p2/4b1kp/4B1p1/2pP2P1/2P4P/1rr5/4R1K1 w - - 0 1")), 5)
b = Board("7R/5p2/4b1kp/4B1p1/2pP2P1/2P4P/1rr5/4R1K1 w - - 0 1")
@time n = perft(b, true, 5)

n / (81 / 1000)
n / 25


@time Chess.divide(Chess.fromfen("7R/5p2/4b1kp/4B1p1/2pP2P1/2P4P/1rr5/4R1K1 w - - 0 1"), 6)
@time divide(Board("7R/5p2/4b1kp/4B1p1/2pP2P1/2P4P/1rr5/4R1K1 w - - 0 1"), true, 6)
