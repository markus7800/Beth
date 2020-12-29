# https://people.csail.mit.edu/plaat/mtdf.html#abmem

#                                       depth lower upper
TranspositionTable = Dict{Board, Tuple{Int,Float64,Float64}}
AlphaBetaMemory = Dict{Node, Tuple{Int,Float64,Float64}}

function AlphaBetaWithMemory(beth::Beth, node::Node, depth::Int, α::Float64, β::Float64, white::Bool, tt::AlphaBetaMemory)
    beth.n_explored_nodes += 1
    _white, = restore_board_position(beth, node)
    @assert _white == white

    # transposition table look up
    if haskey(tt, node)
        d, lower, upper = tt[node]
        if lower ≥ β
            return lower
        end
        if upper ≤ α
            return upper
        end
        α = max(α, lower)
        β = min(β, upper)
    end

    value = 0.
    _α = α # store
    _β = β # store

    if depth == 0
        beth.n_leafes += 1
        value, = beth.value_heuristic(beth._board, white)
        node.score = value
    else
        ms = get_moves(beth._board, white)
        ranked_moves = beth.rank_heuristic(beth._board, white, ms)
        sort!(ranked_moves, rev=white) # try to choose best moves first

        if white
            value = -Inf
            for (i,(prescore, m)) in enumerate(ranked_moves)
                child = Node(move=m, parent=node, score=prescore, visits=0)
                push!(node.children, child)

                value = max(value, AlphaBetaWithMemory(beth, child, depth-1, α, β, false, tt))
                α = max(α, value)
                α ≥ β && break ## β cutoff
            end
            node.score = value
        else
            value = Inf
            for (i,(prescore, m)) in enumerate(ranked_moves)
                child = Node(move=m, parent=node, score=prescore, visits=0)
                push!(node.children, child)

                value = min(value, AlphaBetaWithMemory(beth, child, depth-1, α, β, true, tt))
                β = min(β, value)
                β ≤ α && break # α cutoff
            end
            node.score = value
        end
    end

    # if depth > 0
    #     _white, = restore_board_position(beth, node)
    # end
    @assert _α ≤ _β

    if value ≤ _α
        # Fail low result implies an upper bound
        tt[node] = (depth, -Inf, value)
    end
    if α < value && value < β
        # Found an accurate minimax value - will not occur if called with zero window (α = 1 - β)
        tt[node] = (depth, value, value)
    end
    if β ≤ value
        # Fail high result implies a lower bound
        tt[node] = (depth, value, Inf)
    end

    return value
end

function alphabeta_search(beth::Beth; board=beth.board, white=beth.white, verbose=true, lower=-Inf, upper=Inf, mem = AlphaBetaMemory())
    beth.board = board
    beth.white = white
    beth.n_leafes = 0
    beth.n_explored_nodes = 0

    root = Node()

    v,t = @timed AlphaBetaWithMemory(beth, root, depth, lower, upper, white, mem)

    verbose && @info(@sprintf "%d nodes (%d leafes) explored in %.4f seconds (%.2f/s)." beth.n_explored_nodes beth.n_leafes t (beth.n_explored_nodes/t) )

    return root, mem
end


function MTDF(root::Node, guess::Float64, depth::Integer)

end

function IMTDF(;max_depth::Integer, max_time::Float64)

end

pz = rush_20_12_13[20]
print_puzzle(pz)

bfs = [Inf,Inf,Inf,Inf]
depth = 4
beth = Beth(value_heuristic=beth_eval, rank_heuristic=beth_rank_moves, search_args=Dict("depth"=>depth, "branching_factors"=>bfs))

root = minimax_search(beth, board=deepcopy(pz.board), white=pz.white_to_move)

print_tree(root, max_depth=1)

root, mem = alphabeta_search(beth, board=deepcopy(pz.board), white=pz.white_to_move)


root, mem = alphabeta_search(beth, board=deepcopy(pz.board), white=pz.white_to_move, mem=mem)
