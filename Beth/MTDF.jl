# https://people.csail.mit.edu/plaat/mtdf.html#abmem

#                                       depth lower upper
#TranspositionTable = Dict{String, Tuple{Int,Float64,Float64}}
AlphaBetaMemory = Dict{String, Tuple{Int,UInt8,Float64}}

const EXACT = 0x1
const UPPER = 0x2
const LOWER = 0x3

function key(node::Node)::String
    key = ""
    if node.move != (0x00, 0x00, 0x00)
        while node.parent != nothing
            key = string(node.move) * " " * key
            node = node.parent
        end
    end
    return key
end

function AlphaBeta(beth::Beth, node::Node, depth::Int, α::Float64, β::Float64, white::Bool, use_tt=true, tt::AlphaBetaMemory=AlphaBetaMemory())
    value = 0.
    _α = α # store
    _β = β # store

    beth.n_explored_nodes += 1
    _white, = restore_board_position(beth, node)
    @assert _white == white

    # transposition table look up
    if use_tt && haskey(tt, key(node))
        d, flag, value = tt[key(node)]
        if flag == EXACT
            node.score = value
            return value, (0x0, 0x0, 0x0)
        elseif flag == LOWER
            α = max(α, value)
        elseif flag == UPPER
            β = min(β, value)
        end

        if α ≥ β
            node.score = value
            return value, (0x0, 0x0, 0x0)
        end
    end

    best_move = (0x0, 0x0, 0x0)
    best_value = 0.

    if depth == 0
        beth.n_leafes += 1
        value, = beth.value_heuristic(beth._board, white)
        node.score = value
    else
        ms = get_moves(beth._board, white)

        if length(ms) == 0
            beth.n_leafes += 1
            value, = beth.value_heuristic(beth._board, white)
            node.score = value
        else
            ranked_moves = beth.rank_heuristic(beth._board, white, ms)
            sort!(ranked_moves, rev=white) # try to choose best moves first

            if white
                best_value = -Inf
                value = -Inf
                for (prescore, m) in ranked_moves
                    child = Node(move=m, parent=node, score=prescore, visits=0)
                    #push!(node.children, child)
                    value = max(value, AlphaBeta(beth, child, depth-1, α, β, false, use_tt, tt)[1])

                    if value > best_value
                        best_value = value
                        best_move = m
                    end

                    α = max(α, value)
                    α ≥ β && break ## β cutoff
                end
                node.score = value
            else
                best_value = Inf
                value = Inf
                for (prescore, m) in ranked_moves
                    child = Node(move=m, parent=node, score=prescore, visits=0)
                    #push!(node.children, child)

                    value = min(value, AlphaBeta(beth, child, depth-1, α, β, true, use_tt, tt)[1])

                    if value < best_value
                        best_value = value
                        best_move = m
                    end

                    β = min(β, value)
                    β ≤ α && break # α cutoff
                end
                node.score = value
            end
        end
    end

    if use_tt
        if value ≤ _α
            # Fail low result implies an upper bound
            tt[key(node)] = (depth, UPPER, value)
        elseif β ≤ value
            # Fail high result implies a lower bound
            tt[key(node)] = (depth, LOWER, value)
        else
            # Found an accurate minimax value - will not occur if called with zero window (α = β-
            tt[key(node)] = (depth, EXACT, value)
        end
    end
    return value, best_move
end

function alphabeta_search(beth::Beth; board=beth.board, white=beth.white, verbose=true, lower=-Inf, upper=Inf, mem=nothing)
    beth.board = board
    beth.white = white
    beth.n_leafes = 0
    beth.n_explored_nodes = 0

    root = Node()

    if mem != nothing
        (v,m), t = @timed AlphaBeta(beth, root, depth, lower, upper, white, true, mem)
    else
        (v,m), t = @timed AlphaBeta(beth, root, depth, lower, upper, white, false)
    end

    verbose && @info(@sprintf "%d nodes (%d leafes) explored in %.4f seconds (%.2f/s)." beth.n_explored_nodes beth.n_leafes t (beth.n_explored_nodes/t) )

    return v, m,  mem
end


function MTDF(beth::Beth; board=beth.board, white=beth.white, guess::Float64, depth::Int, verbose=true)
    beth.board = board
    beth.white = white
    beth.n_leafes = 0
    beth.n_explored_nodes = 0

    value = guess
    upper = Inf
    lower = -Inf

    mem = AlphaBetaMemory()
    best_move = (0x0, 0x0, 0x0)
    _,t = @timed while true
        β = value == lower ? value + 0.1 : value
        root = Node()
        value, best_move = AlphaBeta(beth, Node(), depth, β-0.1, β, white, true, mem)
        if value < β
            upper = value
        else
            lower = value
        end

        @info("value: $value, alpha: $(β-1), beta: $β, lower: $lower, $upper")

        if lower ≥ upper
            break
        end
    end

    verbose && @info(@sprintf "%d nodes (%d leafes) explored in %.4f seconds (%.2f/s)." beth.n_explored_nodes beth.n_leafes t (beth.n_explored_nodes/t) )


    return value, best_move
end

function IMTDF(beth::Beth; board=beth.board, white=beth.white, max_depth::Int)
    guesses = [0.]
    for depth in 2:2:max_depth
        guess = guesses[end]
        # @info "Depth: $depth, guess: $guess"
        @time value, best_move = MTDF(beth, board=board, white=white, guess=guess, depth=depth, verbose=false)
        push!(guesses, value)
    end
    return guesses[end]
end

function pvs(beth::Beth, node::Node, depth::Int, α::Float64, β::Float64, white::Bool)
    value = 0.

    beth.n_explored_nodes += 1
    _white, = restore_board_position(beth, node)
    @assert _white == white

    if depth == 0
        beth.n_leafes += 1
        value = beth.value_heuristic(beth._board, white)
        node.score = value
        return value
    else
        ms = get_moves(beth._board, white)

        if length(ms) == 0
            beth.n_leafes += 1
            value = abs(beth.value_heuristic(beth._board, white))
            node.score = value
            return value
        else
            ranked_moves = beth.rank_heuristic(beth._board, white, ms)
            sort!(ranked_moves, rev=white) # try to choose best moves first

            for (i,(prescore, m)) in enumerate(ranked_moves)
                child = Node(move=m, parent=node, score=prescore, visits=0)

                if i == 1 # first child
                    value = -pvs(beth, child, depth-1, -β, -α, !white)
                else
                    # null window search
                    value = -pvs(beth, child, depth-1, -α-0.1, -α, !white)
                    if α < value && value < β
                        # research if it failed high
                        value = -pvs(beth, child, depth-1, -β, -value, !white)
                    end
                end

                α = max(α, value)
                if α ≥ β
                    break # beta cut off
                end
            end
            node.score = α
            return α
        end
    end
end

function pvs_search(beth::Beth; board=beth.board, white=beth.white, verbose=true, lower=-Inf, upper=Inf, depth=6)
    beth.board = board
    beth.white = white
    beth.n_leafes = 0
    beth.n_explored_nodes = 0

    root = Node()

    v,t, = @timed pvs(beth, root, depth, lower, upper, white)

    verbose && @info(@sprintf "%d nodes (%d leafes) explored in %.4f seconds (%.2f/s)." beth.n_explored_nodes beth.n_leafes t (beth.n_explored_nodes/t) )

    return v
end

function distributed_search(beth::Beth; board, white)
    ms = get_moves(board, white)
    ranked_moves = beth.rank_heuristic(board, white, ms)
    sort!(ranked_moves, rev=white)

    for (i,(prescore, rm)) in enumerate(ranked_moves)
        _board = deepcopy(board)
        move!(_board, white, rm[1], rm[2], rm[3])
        v = minimax_search(beth, board=_board, white=!white, verbose=false).score
        @info(@sprintf "%d: %s prescore: %.2f, value: %.2f" i rm prescore v)
    end

end

using BenchmarkTools

pz = rush_20_12_13[9]
print_puzzle(pz)

bfs = [Inf,Inf,Inf,Inf,Inf,Inf,Inf,Inf]
depth = 6
beth = Beth(value_heuristic=beth_eval, rank_heuristic=beth_rank_moves, search_args=Dict("depth"=>depth, "branching_factors"=>bfs))
# beth(pz.board, pz.white_to_move)

# [ Info: 96401 nodes (83717 leafes) explored in 3.7522 seconds (25691.85/s).
root = minimax_search(beth, board=deepcopy(pz.board), white=pz.white_to_move)

print_tree(root, max_depth=1, white=pz.white_to_move, has_to_have_children=false)

distributed_search(beth, board=deepcopy(pz.board), white=pz.white_to_move)

# [ Info: 96401 nodes (83717 leafes) explored in 3.5562 seconds (27107.75/s).
v, m, mem = alphabeta_search(beth, board=deepcopy(pz.board), white=pz.white_to_move)

v, m, mem = alphabeta_search(beth, board=deepcopy(pz.board), white=pz.white_to_move, mem=mem)


# [ Info: 71352 nodes (63444 leafes) explored in 2.6775 seconds (26648.43/s).
@profiler v, m = MTDF(beth, board=deepcopy(pz.board), white=pz.white_to_move, guess=0., depth=4)

IMTDF(beth, board=deepcopy(pz.board), white=pz.white_to_move, max_depth=4)

pvs_search(beth, board=deepcopy(pz.board), white=pz.white_to_move, depth=4)
