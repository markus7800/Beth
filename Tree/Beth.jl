
include("../chess/chess.jl")

include("tree.jl")
include("evaluation.jl")
using Printf

mutable struct TranspositionTable
    d::Dict{UInt, Number}
    n_fetched_stored_val::Int
    n_total::Int
    function TranspositionTable()
        return new(Dict{UInt, Number}(), 0, 0)
    end
end

import Base.hash
function Base.hash(board::Board, white::Bool)
    h = hash(board)
    return hash(white, h)
end

function get!(tt::TranspositionTable, h::UInt)
    tt.n_total += 1
    value = get(tt.d, h, NaN)
    if !isnan(value)
        # @info("Retrieve $value for $h")
        tt.n_fetched_stored_val += 1
    end
    return value
end

function get!(tt::TranspositionTable, board::Board, white::Bool)
    return get!(tt, hash(board, white))
end

function set!(tt::TranspositionTable, h::UInt, value:: Number)
    # @info("Store $value for $h")
    tt.d[h] = value
end

#
# function set!(tt::TranspositionTable, board::Board, white::Bool, value::Float64)
#     set!(tt, hash((board, white)), value)
# end

mutable struct Beth
    value_heuristic::Function
    rank_heuristic::Function

    board::Board # board capturing current position, playing starts here
    white::Bool # current next player to move
    _board::Board # board used for playing in tree search, reset to board

    n_leafes::Int
    n_explored_nodes::Int

    depth::Int
    bfs::Vector # max_branching_factors

    use_tt::Bool
    tt::TranspositionTable

    function Beth(;value_heuristic, rank_heuristic, board=Board(), white=true, depth=5, bfs=fill(Inf, depth), use_tt=true)
        beth = new()
        beth.value_heuristic = value_heuristic
        beth.rank_heuristic = rank_heuristic

        beth.board = board
        beth.white = white
        beth._board = deepcopy(board)

        beth.n_leafes = 0
        beth.n_explored_nodes = 0

        beth.depth = depth
        beth.bfs = bfs

        beth.use_tt = use_tt
        beth.tt = TranspositionTable()

        return beth
    end
end

function restore_board_position(beth::Beth, node::Node)
    restore_board_position(beth.board, beth.white, beth._board, node)
end

function search(beth::Beth; board=beth.board, white=beth.white)
    beth.board = board
    beth.white = white
    beth.n_leafes = 0
    beth.n_explored_nodes = 0
    root = Node()

    v,t = @timed minimax(beth, root, beth.depth, -Inf, Inf, white)

    @info(@sprintf "%d nodes (%d leafes) explored in %.4f seconds (%.2f/s)." beth.n_explored_nodes beth.n_leafes t (beth.n_explored_nodes/t) )
    @info(@sprintf "Transposition table reduces node evaluations by %d. Fetch ratio: %.4f." beth.tt.n_fetched_stored_val (beth.tt.n_fetched_stored_val / beth.tt.n_total))

    return root
end

function (beth::Beth)(board::Board, white::Bool)
    root = search(beth, board=board, white=white)
    node = sort(root.children, lt=(x,y)->x.score<y.score, rev=white)[1]
    println("Computer says: ", node.move, " valued with ", node.score, ".")
    return node.move
end

function minimax(beth::Beth, node::Node, depth::Int, α::Float64, β::Float64, white::Bool)
    beth.n_explored_nodes += 1

    # no need to deep copy boards and we dont reach a deep depth anyways
    # proved to be faster in BFS
    _white, = restore_board_position(beth, node)
    @assert _white == white
    # position_hash = hash(beth._board, white)
    #
    # if beth.use_tt
    #     value = get!(beth.tt, position_hash)
    #     if !isnan(value)
    #         node.score = value
    #         return value
    #     end
    # end

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
        bf = beth.bfs[depth] # max branching factor
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
        bf = beth.bfs[depth] # max branching factor
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


include("../puzzles/puzzle.jl")


pz = puzzles[7]
print_puzzle(pz)

bfs = reverse([Inf,Inf,Inf,Inf,Inf])
depth = 5
b = Beth(value_heuristic=simple_piece_count, rank_heuristic=rank_moves, depth=depth, bfs=bfs, use_tt=false)
root = search(b, board=pz.board, white=pz.white_to_move)

b = Beth(value_heuristic=simple_piece_count, rank_heuristic=rank_moves, depth=depth, bfs=bfs, use_tt=true)
root2 = search(b, board=pz.board, white=pz.white_to_move)

print_tree(root, white=pz.white_to_move, max_depth=1, has_to_have_children=false)
print_tree(root2, white=pz.white_to_move, max_depth=1, has_to_have_children=false)


print_tree(root, has_to_have_children=false, expand_best=1, white=pz.white_to_move)

print_tree(root, white=pz.white_to_move, max_depth=1, has_to_have_children=false)

string(b(pz.board, pz.white_to_move))

bfs = reverse([Inf,Inf,Inf,Inf])
depth = 4
b = Beth(value_heuristic=simple_piece_count, rank_heuristic=rank_moves, depth=depth, bfs=bfs, use_tt=false)
game_history = play_game(black_player=b)

# e4 d4 Qd3 d5 Qf3 Bc4

board, white, m = game_history[22]

root = search(b, board=board, white=white)

print_tree(root, has_to_have_children=false, expand_best=1, white=pz.white_to_move)

print_tree(root, has_to_have_children=false, white=pz.white_to_move)


d = Dict()

board = Board()
b1 = deepcopy(board)

hash(board, true)
d[hash(board,true)] = 1

b1 == board
hash(b1, true) == hash(board, true)
hash(b1, true)

move!(board, true, 'P', "e2", "e4")

hash(board, true)

b1 == board
d[hash(b1,true)]
d[hash(b1,false)]


d[hash(Board(),true)]
d2[Board()]





b = Beth(value_heuristic=simple_piece_count, rank_heuristic=rank_moves, depth=3, bfs=[10,10,10], use_tt=false)
root = search(b, board=pz.board, white=pz.white_to_move)
