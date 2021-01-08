
function perftinternal(board::Board, white::Bool, depth::Int, ply::Int, lists)::Int
    movelist = lists[ply+1]
    ms = get_moves!(board, white, movelist)

    if depth == 1
        nodes = length(ms)
        recycle!(movelist)
        return nodes
    else
        result = 0
        nodes = 0
        for m in ms
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

import Chess

using BenchmarkTools
@btime perft(StartPosition(), true, 5) # 2.428 s (14932604 allocations: 1.32 GiB)

@time n = perft(StartPosition(), true, 6) # 7.474199 seconds (15.96 M allocations: 31.208 GiB, 57.63% gc time)

@time perft_mem(StartPosition(), true, 6) # 1.581127 seconds (5.82 M allocations: 224.643 MiB, 3.81% gc time)


@time Chess.perft(Chess.startboard(), 6) # 0.868299 seconds (937.20 k allocations: 370.547 MiB, 5.22% gc time)
