
function perft_interval(board::Board, white::Bool, depth::Int)::Int
    ms = get_moves(board, white)
    if depth == 1
        return length(ms)
    else
        nodes = 0
        for m in ms
            a, b, c = move!(board, white, m[1], m[2], m[3])
            nodes += perft_interval(board, !white, depth-1)
            undo!(board, white, m[1], m[2], m[3], a, b, c)
        end
        return nodes
    end
end

function perft(board::Board, white::Bool, depth::Int)
    perft_interval(board, white, depth)
end

using BenchmarkTools
@btime perft(Board(), true, 5) # 8.52s vs 30ms of Chess.jl
