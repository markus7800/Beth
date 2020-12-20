include("../chess/chess.jl")

include("tree.jl")
include("simple_evaluation.jl")
using Printf

# include("transpositiontable.jl")

mutable struct Beth
    search_algorithm::Function
    search_args::Dict

    value_heuristic::Function
    rank_heuristic::Function

    board::Board # board capturing current position, playing starts here
    white::Bool # current next player to move
    _board::Board # board used for playing in tree search, reset to board

    n_leafes::Int
    n_explored_nodes::Int


    function Beth(;search_algorithm=minimax_search, value_heuristic, rank_heuristic, board=Board(), white=true, search_args::Dict)
        beth = new()
        @info "Heuristics: $value_heuristic, $rank_heuristic"
        @info "Search: $search_algorithm"
        @info "Args: $search_args"

        beth.search_algorithm = search_algorithm
        beth.search_args = search_args

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

function minimax_search(beth::Beth; board=beth.board, white=beth.white)
    beth.board = board
    beth.white = white
    beth.n_leafes = 0
    beth.n_explored_nodes = 0
    root = Node()

    depth = get(beth.search_args, "depth", 0)
    bfs = get(beth.search_args, "branching_factors", fill(Inf, depth))
    @assert length(bfs) ≥ depth
    if depth == 0
        depth = length(bfs)
    end
    beth.search_args["branching_factors"] = reverse(bfs) # depth is descending

    v,t = @timed minimax(beth, root, depth, -Inf, Inf, white)

    @info(@sprintf "%d nodes (%d leafes) explored in %.4f seconds (%.2f/s)." beth.n_explored_nodes beth.n_leafes t (beth.n_explored_nodes/t) )
    return root
end

function (beth::Beth)(board::Board, white::Bool)
    # beth.board = board
    # beth.white = white

    # root = beam_search(beth)

    # nodes = sort(root.children, lt=(x,y)->x.score<y.score, rev=white)
    # for n in nodes
    #     println(n)
    # end

    root = beth.search_algorithm(beth, board=board, white=white)
    nodes = sort(root.children, lt=(x,y)->x.score<y.score, rev=white)

    if length(nodes) > 0
        node = nodes[1]
        println(@sprintf "Computer says: %s valued with %.2f." node.move node.score)
        return node.move
    end
end

function minimax(beth::Beth, node::Node, depth::Int, α::Float64, β::Float64, white::Bool)
    beth.n_explored_nodes += 1

    # no need to deep copy boards and we dont reach a deep depth anyways
    # proved to be faster in BFS
    _white, = restore_board_position(beth, node)
    @assert _white == white

    # TODO: switch around to remove checking for game end in simple_piece_count
    # TODO: expand until quite for piececount

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
    sort!(ranked_moves, rev=white)

    if white
        value = -Inf
        bf = beth.search_args["branching_factors"][depth] # max branching factor
        for (i,(prescore, m)) in enumerate(ranked_moves)
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
        bf = beth.search_args["branching_factors"][depth] # max branching factor
        for (i,(prescore, m)) in enumerate(ranked_moves)
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

function beam_search(beth::Beth, full_depth=4, beam_depth=16, beam_width=10_000)

    white = beth.white
    root = Node()
    first_layer = map(m->Node(move=m, parent=root), get_moves(beth.board, white))
    root.children = first_layer
    white = !white

    layers = [first_layer]

    v,t1, = @timed for d in 1:full_depth-1
        push!(layers, Node[])
        for node in layers[d]
            _white, = restore_board_position(beth, node)
            @assert _white == white

            children = map(m->Node(move=m, parent=node), get_moves(beth._board, white))
            append!(layers[d+1], children)
        end
        white = !white
    end
    @info @sprintf "Expanded to depth %d in %.2fs." full_depth t1
    @info @sprintf "Layers sizes: %s" map(l -> length(l), layers)

    v,t2, = @timed for d in 1:beam_depth
        l = d - 1 + full_depth
        ranked_moves = []
        v,t, = @timed @progress for node in layers[l]
            _white, = restore_board_position(beth, node)
            @assert _white == white
            ms = get_moves(beth._board, white)
            rms = beth.rank_heuristic(beth._board, white, ms)

            children = map(x->(x[1],Node(move=x[2], parent=node)), rms)
            append!(ranked_moves, children)
        end
        @info @sprintf "Expanded depth %d in %.2fs." l+1 t
        sort!(ranked_moves, rev=white)

        push!(layers, map(x -> x[2], ranked_moves[1:min(beam_width, length(ranked_moves))]))
        white = !white
    end

    @info @sprintf "Expanded to depth %d in %.2fs." full_depth+beam_depth t1+t2
    @info @sprintf "Layers sizes: %s" map(l -> length(l), layers)

    v,t, = @timed begin
        for leaf in layers[end]
            _white, = restore_board_position(beth, leaf)
            leaf.score = beth.value_heuristic(beth._board, _white)
        end

        for d in full_depth+beam_depth:-1:2
            for node in layers[d]
                node.parent.visits += 1
                node.parent.score = max(node.parent.score, node.score)
                # node.parent.score += node.score
            end
        end
    end
    @info @sprintf "Backpropagated in %.2fs." t

    for c in root.children
        println(c)
    end
    @info "Beam end"
    return root
end

include("Beth_eval.jl")

include("../puzzles/puzzle.jl")
include("../puzzles/puzzle_rush_20_12_13.jl")


pz = puzzles[12]
print_puzzle(pz)

bfs = [Inf,Inf,10,Inf,10,Inf]
depth = 6
b = Beth(value_heuristic=simple_piece_count, rank_heuristic=simple_rank_moves, search_args=Dict("depth"=>depth, "branching_factors"=>bfs))
b = Beth(value_heuristic=beth_eval, rank_heuristic=beth_rank_moves, search_args=Dict("depth"=>depth, "branching_factors"=>bfs))
game_history = play_game(black_player=b)

play_puzzle(rush_20_12_13[14], b)

puzzle_rush(rush_20_12_13, b, print_solution=true)
pz = rush_20_12_13[end]
print_puzzle(pz)
root = search(b, board=deepcopy(pz.board), white=pz.white_to_move)
print_tree(root, max_depth=1, has_to_have_children=false, white=pz.white_to_move)

print_tree(root["Rc4c5"], max_depth=1, has_to_have_children=false, white=!pz.white_to_move)
print_tree(root["Rc4c5"]["Pd4c5"], max_depth=1, has_to_have_children=false, white=pz.white_to_move)

for ply in game_history
    println(ply)
end
board = game_history[end][3]
#=
  MiniMax:
  simple_piece_count, rank_moves, [Inf, Inf, 10, Inf, 10, 10] fast 10s

  simple_piece_count, rank_moves, [Inf, Inf, 10, Inf, 10, Inf] still possible but approx 1 minute, won an exchange

  beth_eval, beth_rank_moves, [Inf, Inf, Inf, Inf] Really fast (<1s) but stupid

  beth_eval, beth_rank_moves, [Inf,Inf,10,Inf,10,10] 80s, gets faster, is good (won a piece)
=#

b = Beth(value_heuristic=beth_eval, rank_heuristic=rank_moves, depth=depth, bfs=bfs, use_tt=false)
beam_search(b, 4, 16)
game_history = play_game(black_player=b)
