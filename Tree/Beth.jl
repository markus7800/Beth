
include("evaluation.jl")
using Printf

mutable struct Beth
    value_heuristic::Function
    rank_heuristic::Function

    board::Board # board capturing current position, playing starts here
    white::Bool # current next player to move
    _board::Board # board used for playing in tree search, reset to board

    n_leafes::Int
    n_explored_nodes::Int

    function Beth(;value_heuristic, rank_heuristic, board=Board(), white=true)
        beth = new()
        beth.value_heuristic = value_heuristic
        beth.rank_heuristic = rank_heuristic

        beth.board = board
        beth.white = white
        beth._board = deepcopy(board)

        beth.n_leafes = 0
        beth.n_explored_nodes = 0

        return beth
    end

end

function restore_board_position(beth::Beth, node::Node)
    restore_board_position(beth.board, beth.white, beth._board, node)
end

function search(beth::Beth; board=beth.board, white=beth.white, depth=5, bfs=fill(Inf, depth))
    beth.board = board
    beth.white = white
    beth.n_leafes = 0
    beth.n_explored_nodes = 0
    root = Node()

    v,t = @timed minimax(beth, root, depth, -Inf, Inf, white, bfs)

    @info(@sprintf "%d nodes (%d leafes) explored in %.4f seconds (%.2f /s)" beth.n_explored_nodes beth.n_leafes t (beth.n_explored_nodes/t) )

    return root
end

function minimax(beth::Beth, node::Node, depth::Int, α::Float64, β::Float64, white::Bool, max_branching_factors::Vector)
    beth.n_explored_nodes += 1

    # no need to deep copy boards and we dont reach a deep depth anyways
    # proved to be faster in BFS
    _white, = restore_board_position(beth, node)
    @assert _white == white

    if depth == 0
        beth.n_leafes += 1
        score, = beth.value_heuristic(beth._board, white)
        node.score = score
        return score
    end

    # handle game endings
    ms = get_moves(beth._board, white)
    if length(ms) == 0
        beth.n_leafes += 1
        score = 0. # stalemate
        if white
            if is_check(beth._board, WHITE)
                score = -1000. # black checkmated white
            end
        else
            if is_check(beth._board, BLACK)
                score = 1000. # white checkmated black
            end
        end
        node.score = score
        return score
    end

    ranked_moves = beth.rank_heuristic(beth._board, white, ms) # try to choose best moves first

    if white
        value = -Inf
        bf = max_branching_factors[depth]
        for (i,(m, prescore)) in enumerate(ranked_moves)
            i > bf && break

            child = Node(move=m, parent=node, score=prescore, visits=0)
            push!(node.children, child)

            value = max(value, minimax(beth, child, depth-1, α, β, false))
            α = max(α, value)
            α ≥ β && break ## β cutoff
        end
        node.score = value
        return value
    else
        value = Inf
        bf = max_branching_factors[depth]
        for (i,(m, prescore)) in enumerate(ranked_moves)
            i > bf && break
            child = Node(move=m, parent=node, score=prescore, visits=0)
            push!(node.children, child)

            value = min(value, minimax(beth, child, depth-1, α, β, true))
            β = min(β, value)
            β ≤ α && break # α cutoff
        end
        node.score = value
        return value
    end
end

b = Beth(value_heuristic=simple_piece_count, rank_heuristic=rank_moves)

root = search(b, depth=5)

count_nodes(root)

pz = puzzles[7]
print_puzzle(pz)

bfs = reverse([Inf,Inf,Inf,10,10])
root = search(b, board=pz.board, white=pz.white_to_move, depth=5, bfs=bfs)

print_tree(root, has_to_have_children=false, expand_best=1, white=pz.white_to_move)

print_tree(root, white=pz.white_to_move, max_depth=1, has_to_have_children=false)
