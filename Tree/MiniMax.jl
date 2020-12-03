
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

function search(beth::Beth; board=beth.board, white=beth.white, depth=5)
    beth.n_leafes = 0
    beth.n_explored_nodes = 0
    root = Node()
    v,t = @timed minimax(beth, root, depth, -Inf, Inf, white)

    println(@sprintf "%d nodes (%d leafes) explored in %.4f seconds" beth.n_explored_nodes beth.n_leafes t)
end

function minimax(beth::Beth, node::Node, depth::Int, α::Float64, β::Float64, white::Bool)
    beth.n_explored_nodes += 1

    # no need to deep copy boards and we dont reach a deep depth anyways
    # proved to be faster in BFS
    _white, = restore_board_position(beth, node)
    @assert _white == white

    if depth == 0
        beth.n_leafes += 1
        score, = beth.value_heuristic(beth._board, white)
        return score
    end

    # handle game endings
    ms = get_moves(beth._board, white)
    if length(ms) == 0
        beth.n_leafes += 1
        if white
            if is_check(beth._board, WHITE)
                return -1000. # black checkmated white
            end
        else
            if is_check(beth._board, BLACK)
                return 1000. # white checkmated black
            end
        end
        return 0. # stalemate
    end

    ranked_moves = beth.rank_heuristic(beth._board, white, ms) # try to choose best moves first

    if white
        value = -Inf
        for (m, prescore) in ranked_moves
            child = Node(move=m, parent=node, score=prescore, visits=0)
            push!(node.children, child)

            value = max(value, minimax(beth, child, depth-1, α, β, false))
            α = max(α, value)
            α ≥ β && break ## β cutoff
        end
        return value
    else
        value = Inf
        for (m, prescore) in ranked_moves
            child = Node(move=m, parent=node, score=prescore, visits=0)
            push!(node.children, child)

            value = min(value, minimax(beth, child, depth-1, α, β, true))
            β = min(β, value)
            β ≤ α && break # α cutoff
        end
        return value
    end
end

b = Beth(value_heuristic=simple_piece_count, rank_heuristic=rank_moves)

search(b, depth=2)
