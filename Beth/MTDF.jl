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
                for (i,(prescore, m)) in enumerate(ranked_moves)
                    child = Node(move=m, parent=node, score=prescore, visits=0)
                    #push!(node.children, child)

                    # println(@sprintf "Pre %d %s %.2f %.2f %.2f" i child α β value)
                    value = max(value, AlphaBeta(beth, child, depth-1, α, β, false, use_tt, tt)[1])
                    # println(@sprintf "After %d %s %.2f %.2f %.2f" i child α β value)

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
                for (i,(prescore, m)) in enumerate(ranked_moves)
                    child = Node(move=m, parent=node, score=prescore, visits=0)
                    #push!(node.children, child)

                    # println(@sprintf "Pre %d %s %.2f %.2f %.2f" i child α β value)
                    value = min(value, AlphaBeta(beth, child, depth-1, α, β, true, use_tt, tt)[1])
                    # println(@sprintf "After %d %s %.2f %.2f %.2f" i child α β  value)

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


function MTDF(beth::Beth; board=beth.board, white=beth.white, guess::Float64, depth::Integer, verbose=true)
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

        #@info("value: $value, alpha: $(β-1), beta: $β, lower: $lower, $upper")

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

v, root = start_beth_search(beth, board=deepcopy(pz.board), white=pz.white_to_move, depth=6)

# [ Info: 71352 nodes (63444 leafes) explored in 2.6775 seconds (26648.43/s).
@profiler v, m = MTDF(beth, board=deepcopy(pz.board), white=pz.white_to_move, guess=0., depth=4)

IMTDF(beth, board=deepcopy(pz.board), white=pz.white_to_move, max_depth=4)

pvs_search(beth, board=deepcopy(pz.board), white=pz.white_to_move, depth=4)


Pre 1 Q: b7-f7, score: 24.5000, visits: 0, 0 children -Inf Inf -Inf
After 1 Q: b7-f7, score: -5.5000, visits: 0, 0 children -Inf Inf -5.50
Pre 2 Q: b7-e7, score: 23.5000, visits: 0, 0 children -5.50 Inf -5.50
After 2 Q: b7-e7, score: -6.5000, visits: 0, 0 children -5.50 Inf -5.50
Pre 3 Q: b7-d7, score: 23.5000, visits: 0, 0 children -5.50 Inf -5.50
After 3 Q: b7-d7, score: -6.5000, visits: 0, 0 children -5.50 Inf -5.50
Pre 4 Q: b7-c6, score: 23.5000, visits: 0, 0 children -5.50 Inf -5.50
After 4 Q: b7-c6, score: -6.5000, visits: 0, 0 children -5.50 Inf -5.50
Pre 5 Q: b7-a8, score: -1.5000, visits: 0, 0 children -5.50 Inf -5.50
After 5 Q: b7-a8, score: -1.5000, visits: 0, 0 children -5.50 Inf -1.50
Pre 6 N: b6-a8, score: -1.5000, visits: 0, 0 children -1.50 Inf -1.50
After 6 N: b6-a8, score: -1.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 7 K: g1-f1, score: -3.5000, visits: 0, 0 children -1.50 Inf -1.50
After 7 K: g1-f1, score: -3.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 8 R: b1-f1, score: -3.5000, visits: 0, 0 children -1.50 Inf -1.50
After 8 R: b1-f1, score: -3.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 9 Q: b7-a6, score: -5.2000, visits: 0, 0 children -1.50 Inf -1.50
After 9 Q: b7-a6, score: -5.2000, visits: 0, 0 children -1.50 Inf -1.50
Pre 10 K: g1-f2, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 10 K: g1-f2, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 11 K: g1-h1, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 11 K: g1-h1, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 12 Q: b7-c8, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 12 Q: b7-c8, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 13 Q: b7-b8, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 13 Q: b7-b8, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 14 Q: b7-c7, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 14 Q: b7-c7, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 15 Q: b7-a7, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 15 Q: b7-a7, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 16 R: b1-e1, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 16 R: b1-e1, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 17 R: b1-d1, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 17 R: b1-d1, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 18 R: b1-c1, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 18 R: b1-c1, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 19 R: b1-a1, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 19 R: b1-a1, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 20 N: b6-c8, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 20 N: b6-c8, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 21 N: b6-d7, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 21 N: b6-d7, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 22 N: b6-c4, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 22 N: b6-c4, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 23 N: b6-a4, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 23 N: b6-a4, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 24 P: f5-f6, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 24 P: f5-f6, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 25 P: e4-e5, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 25 P: e4-e5, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 26 P: h2-h4, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 26 P: h2-h4, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 27 P: h2-h3, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 27 P: h2-h3, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 28 P: g2-g4, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 28 P: g2-g4, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 29 P: g2-g3, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 29 P: g2-g3, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 30 P: b2-b4, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 30 P: b2-b4, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 31 P: b2-b3, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 31 P: b2-b3, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 32 P: a2-a4, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 32 P: a2-a4, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
Pre 33 P: a2-a3, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 33 P: a2-a3, score: -6.5000, visits: 0, 0 children -1.50 Inf -1.50
After 1 N: e3-f1, score: -1.5000, visits: 0, 0 children -Inf Inf -1.50
Pre 2 Q: d8-b6, score: -4.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-a8, score: 30.5000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-a8, score: 0.5000, visits: 0, 0 children -Inf -1.50 0.50
After 2 Q: d8-b6, score: 0.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 3 N: e3-d5, score: -2.7000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-f7, score: 28.3000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-f7, score: -1.7000, visits: 0, 0 children -Inf -1.50 -1.70
Pre 2 Q: b7-e7, score: 27.3000, visits: 0, 0 children -1.70 -1.50 -1.70
After 2 Q: b7-e7, score: -2.7000, visits: 0, 0 children -1.70 -1.50 -1.70
Pre 3 Q: b7-d7, score: 27.3000, visits: 0, 0 children -1.70 -1.50 -1.70
After 3 Q: b7-d7, score: -2.7000, visits: 0, 0 children -1.70 -1.50 -1.70
Pre 4 Q: b7-c6, score: 27.3000, visits: 0, 0 children -1.70 -1.50 -1.70
After 4 Q: b7-c6, score: -2.7000, visits: 0, 0 children -1.70 -1.50 -1.70
Pre 5 Q: b7-a8, score: 2.3000, visits: 0, 0 children -1.70 -1.50 -1.70
After 5 Q: b7-a8, score: 2.3000, visits: 0, 0 children -1.70 -1.50 2.30
After 3 N: e3-d5, score: 2.3000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 4 N: e3-g2, score: -2.6000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-f7, score: 28.4000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-f7, score: -1.6000, visits: 0, 0 children -Inf -1.50 -1.60
Pre 2 Q: b7-e7, score: 27.4000, visits: 0, 0 children -1.60 -1.50 -1.60
After 2 Q: b7-e7, score: -2.6000, visits: 0, 0 children -1.60 -1.50 -1.60
Pre 3 Q: b7-d7, score: 27.4000, visits: 0, 0 children -1.60 -1.50 -1.60
After 3 Q: b7-d7, score: -2.6000, visits: 0, 0 children -1.60 -1.50 -1.60
Pre 4 Q: b7-c6, score: 27.4000, visits: 0, 0 children -1.60 -1.50 -1.60
After 4 Q: b7-c6, score: -2.6000, visits: 0, 0 children -1.60 -1.50 -1.60
Pre 5 Q: b7-a8, score: 2.4000, visits: 0, 0 children -1.60 -1.50 -1.60
After 5 Q: b7-a8, score: 2.4000, visits: 0, 0 children -1.60 -1.50 2.40
After 4 N: e3-g2, score: 2.4000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 5 N: e3-f5, score: -2.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-f7, score: 28.5000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-f7, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
After 5 N: e3-f5, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 6 B: f8-e7, score: -1.6000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-e7, score: 31.4000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-e7, score: 1.4000, visits: 0, 0 children -Inf -1.50 1.40
After 6 B: f8-e7, score: 1.4000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 7 P: a6-a5, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-f7, score: 29.5000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-f7, score: -0.5000, visits: 0, 0 children -Inf -1.50 -0.50
After 7 P: a6-a5, score: -0.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 8 P: h6-h5, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-f7, score: 29.5000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-f7, score: -0.5000, visits: 0, 0 children -Inf -1.50 -0.50
After 8 P: h6-h5, score: -0.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 9 P: f7-f6, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-f7, score: 28.5000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-f7, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
After 9 P: f7-f6, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 10 P: g7-g5, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-f7, score: 29.5000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-f7, score: -0.5000, visits: 0, 0 children -Inf -1.50 -0.50
After 10 P: g7-g5, score: -0.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 11 P: g7-g6, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-f7, score: 29.5000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-f7, score: -0.5000, visits: 0, 0 children -Inf -1.50 -0.50
After 11 P: g7-g6, score: -0.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 12 N: e3-d1, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-f7, score: 29.5000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-f7, score: -0.5000, visits: 0, 0 children -Inf -1.50 -0.50
After 12 N: e3-d1, score: -0.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 13 N: e3-c2, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-f7, score: 29.5000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-f7, score: -0.5000, visits: 0, 0 children -Inf -1.50 -0.50
After 13 N: e3-c2, score: -0.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 14 N: e3-c4, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-f7, score: 29.5000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-f7, score: -0.5000, visits: 0, 0 children -Inf -1.50 -0.50
After 14 N: e3-c4, score: -0.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 15 N: e3-g4, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-f7, score: 29.5000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-f7, score: -0.5000, visits: 0, 0 children -Inf -1.50 -0.50
After 15 N: e3-g4, score: -0.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 16 R: a8-a7, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-f7, score: 29.5000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-f7, score: -0.5000, visits: 0, 0 children -Inf -1.50 -0.50
After 16 R: a8-a7, score: -0.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 17 R: a8-b8, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-f7, score: 29.5000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-f7, score: -0.5000, visits: 0, 0 children -Inf -1.50 -0.50
After 17 R: a8-b8, score: -0.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 18 R: a8-c8, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-f7, score: 29.5000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-f7, score: -0.5000, visits: 0, 0 children -Inf -1.50 -0.50
After 18 R: a8-c8, score: -0.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 19 R: h8-h7, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-f7, score: 29.5000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-f7, score: -0.5000, visits: 0, 0 children -Inf -1.50 -0.50
After 19 R: h8-h7, score: -0.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 20 R: h8-g8, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-f7, score: 29.5000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-f7, score: -0.5000, visits: 0, 0 children -Inf -1.50 -0.50
After 20 R: h8-g8, score: -0.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 21 Q: d8-h4, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-d7, score: 1000.0000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-d7, score: 1000.0000, visits: 0, 0 children -Inf -1.50 1000.00
After 21 Q: d8-h4, score: 1000.0000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 22 Q: d8-g5, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-d7, score: 1000.0000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-d7, score: 1000.0000, visits: 0, 0 children -Inf -1.50 1000.00
After 22 Q: d8-g5, score: 1000.0000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 23 Q: d8-f6, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-d7, score: 1000.0000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-d7, score: 1000.0000, visits: 0, 0 children -Inf -1.50 1000.00
After 23 Q: d8-f6, score: 1000.0000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 24 Q: d8-c7, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-a8, score: 33.5000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-a8, score: 3.5000, visits: 0, 0 children -Inf -1.50 3.50
After 24 Q: d8-c7, score: 3.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 25 Q: d8-d7, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-d7, score: 1000.0000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-d7, score: 1000.0000, visits: 0, 0 children -Inf -1.50 1000.00
After 25 Q: d8-d7, score: 1000.0000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 26 Q: d8-e7, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-e7, score: 37.5000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-e7, score: 7.5000, visits: 0, 0 children -Inf -1.50 7.50
After 26 Q: d8-e7, score: 7.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 27 Q: d8-b8, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-d7, score: 1000.0000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-d7, score: 1000.0000, visits: 0, 0 children -Inf -1.50 1000.00
After 27 Q: d8-b8, score: 1000.0000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 28 Q: d8-c8, score: -1.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-c8, score: 37.5000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-c8, score: 7.5000, visits: 0, 0 children -Inf -1.50 7.50
After 28 Q: d8-c8, score: 7.5000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 29 P: d4-d3, score: -1.4000, visits: 0, 0 children -Inf -1.50 -1.50
Pre 1 Q: b7-f7, score: 29.6000, visits: 0, 0 children -Inf -1.50 -Inf
After 1 Q: b7-f7, score: -0.4000, visits: 0, 0 children -Inf -1.50 -0.40
After 29 P: d4-d3, score: -0.4000, visits: 0, 0 children -Inf -1.50 -1.50
[ Info: 99 nodes (69 leafes) explored in 0.0817 seconds (1211.07/s).
