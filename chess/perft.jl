
function perftinternal(board::Board, white::Bool, depth::Int, ply::Int, lists)::Int
    movelist = lists[ply+1]
    get_moves!(board, white, movelist)

    if depth == 1
        nodes = length(movelist)
        recycle!(movelist)
        return nodes
    else
        result = 0
        nodes = 0
        for m in movelist
            undo = make_move!(board, white, m)
            nodes += perftinternal(board, !white, depth-1, ply+1, lists)
            undo_move!(board, white, m, undo)
        end
        recycle!(movelist)
        return nodes
    end
end

function perft_mem(board::Board, white::Bool, depth::Int)::Int
    if depth == 0
        1
    else
        lists = [MoveList(200) for _ ∈ 1:depth]
        perftinternal(board, white, depth, 0, lists)
    end
end



function perft(board::Board, white::Bool, depth::Int)
    ms = get_moves(board, white)

    if depth == 1
        return length(ms)
    else
        nodes = 0
        for m in ms
            undo = make_move!(board, white, m)
            nodes += perft(board, !white, depth-1)
            undo_move!(board, white, m, undo)
        end
        return nodes
    end
end

function count_nodes(board::Board, white::Bool, depth::Int)
    ms = get_moves(board, white)

    if depth == 1
        return length(ms)
    else
        nodes = 1
        for m in ms
            undo = make_move!(board, white, m)
            nodes += count_nodes(board, !white, depth-1)
            undo_move!(board, white, m, undo)
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
        undo = make_move!(board, white, m)
        nodes += perft(board, !white, depth-1)
        undo_move!(board, white, m, undo)
        println("$m $nodes")
    end
    return nodes
end

function perft_capture(board::Board, white::Bool, depth::Int)
    # ms = get_moves(board, white)
    # ms = get_capture_moves(board, white, ms)
    ms = get_captures(board, white)
    #println(ms)
    if depth == 1
        return length(ms)
    else
        nodes = 0
        # for (i, m) in ms
        for m in ms
            undo = make_move!(board, white, m)
            nodes += perft_capture(board, !white, depth-1) + 1
            undo_move!(board, white, m, undo)
        end
        return nodes
    end
end

function Chess_perft_capture_int(b::Chess.Board, depth::Int, ply::Int)
    _movelist = Chess.moves(b)
    occ = Chess.occupiedsquares(b)

    movelist = []
    for m in _movelist
        if Chess.to(m) in occ
            push!(movelist, m)
        end
    end

    # println(movelist)

    if depth == 1
        return length(movelist)
    else
        result = 0
        for m ∈ movelist
            u = Chess.domove!(b, m)
            result += Chess_perft_capture_int(b, depth - 1, ply + 1) + 1
            Chess.undomove!(b, u)
        end
        result
    end
end

function Chess_perft_capture(b::Chess.Board, depth::Int)::Int
    if depth == 0
        1
    else
        Chess_perft_capture_int(b, depth, 0)
    end
end

import Chess

using BenchmarkTools

@btime perft(StartPosition(), true, 5) # 301.197 ms (631824 allocations: 1.27 GiB)
@time n = perft(StartPosition(), true, 6) # 8.916797 seconds (15.90 M allocations: 31.160 GiB, 56.41% gc time)

@btime perft_mem(StartPosition(), true, 5) # 50.824 ms (218627 allocations: 6.70 MiB)
@btime perft_mem(StartPosition(), true, 6) # 1.302 s (5759531 allocations: 175.80 MiB)

@btime Chess.perft(Chess.startboard(), 5) # 28.526 ms (29680 allocations: 16.54 MiB)
@btime Chess.perft(Chess.startboard(), 6) # 722.494 ms (937204 allocations: 370.55 MiB)


board = Board("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")

perft(board, true, 4) # 4085603
perft(board, true, 5) # 193690690
