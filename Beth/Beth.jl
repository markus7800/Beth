include("../chess/chess.jl")

include("../utils/tree.jl")
include("../utils/simple_evaluation.jl")
include("evaluation.jl")


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

function minimax_search(beth::Beth; board=beth.board, white=beth.white, verbose=true, lower=-Inf, upper=Inf)
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

    v,t = @timed minimax(beth, root, depth, lower, upper, white)

    verbose && @info(@sprintf "%d nodes (%d leafes) explored in %.4f seconds (%.2f/s)." beth.n_explored_nodes beth.n_leafes t (beth.n_explored_nodes/t) )

    if length(root.children) > 0
        nodes = sort(root.children, lt=(x,y)->x.score<y.score, rev=white)
        node = nodes[1]
        return node.score, node.move
    else
        return root.score, root.move
    end
end

function (beth::Beth)(board::Board, white::Bool)
    value, move = beth.search_algorithm(beth, board=board, white=white)
    println(@sprintf "Computer says: %s valued with %.2f." move value)
    return move
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
            if is_in_check(beth._board, WHITE)
                score = -1000. # black checkmated white
            end
        else
            if is_in_check(beth._board, BLACK)
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

function beam_search(beth::Beth; board=beth.board, white=beth.white)
    beth.board = board
    beth.white = white
    beth.n_leafes = 0
    beth.n_explored_nodes = 0

    full_depth = get(beth.search_args, "full_depth", 4)
    max_n_leafes = get(beth.search_args, "max_n_leafes", 50_000)
    beam_depth = get(beth.search_args, "beam_depth", 8)
    beam_width = get(beth.search_args, "beam_width", 10_000)

    root,t = @timed beam(beth, full_depth, max_n_leafes, beam_depth, beam_width)

    @info(@sprintf "%d nodes (%d leafes) explored in %.4f seconds (%.2f/s)." beth.n_explored_nodes beth.n_leafes t (beth.n_explored_nodes/t) )
    return root
end

function beam(beth::Beth, full_depth=4, max_n_leafes=50_000, beam_depth=16, beam_width=10_000; verbose=false)
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
            node.children = children

            append!(layers[d+1], children)
        end
        white = !white
    end

    for leaf in layers[end]
        white, = restore_board_position(beth, leaf)
        leaf.score = beth.value_heuristic(beth._board, white)
    end
    sort!(layers[end], lt=(x,y)->x.score<y.score, rev=white)
    layers[end] = layers[end][1:min(length(layers[end]), max_n_leafes)]

    verbose && @info @sprintf "Expanded to depth %d in %.2fs." full_depth t1
    verbose && @info @sprintf "Layers sizes: %s" length.(layers)

    v,t2, = @timed for d in 1:beam_depth
        l = d - 1 + full_depth
        ranked_moves = []
        v,t, = @timed for node in layers[l]
            _white, = restore_board_position(beth, node)
            @assert _white == white
            ms = get_moves(beth._board, white)
            rms = beth.rank_heuristic(beth._board, white, ms)

            children = map(x->(x[1],Node(move=x[2], parent=node)), rms)
            append!(ranked_moves, children)
        end
        verbose && @info @sprintf "Expanded depth %d in %.2fs." l+1 t
        sort!(ranked_moves, rev=white)

        push!(layers, map(x -> x[2], ranked_moves[1:min(beam_width, length(ranked_moves))]))
        white = !white
    end

    verbose && @info @sprintf "Expanded to depth %d in %.2fs." full_depth+beam_depth t1+t2
    verbose && @info @sprintf "Layers sizes: %s" length.(layers)

    v,t, = @timed begin
        white = iseven(full_depth+beam_width) ? beth.white : !beth.white

        for d in full_depth+beam_depth:-1:1
            for node in layers[d]
                if node.visits == 0
                    # leaf
                    _white, = restore_board_position(beth, node)
                    @assert _white == white
                    node.score = beth.value_heuristic(beth._board, white)
                    node.visits = 1
                end

                if node.parent.visits == 0
                    node.parent.score = node.score
                else
                    if white
                        node.parent.score = min(node.parent.score, node.score)
                    else
                        node.parent.score = max(node.parent.score, node.score)
                    end
                end

                node.parent.visits += node.visits
            end
            white = !white
        end
    end
    verbose && @info @sprintf "Backpropagated in %.2fs." t
    verbose && @info "Beam end"

    beth.n_explored_nodes = sum(length.(layers))
    beth.n_leafes = length(layers[end])
    return root
end


include("../puzzles/puzzle.jl")
include("../puzzles/puzzle_rush_20_12_13.jl")
include("../puzzles/puzzle_rush_20_12_30.jl")
include("../puzzles/puzzle_rush_20_12_31.jl")

puzzle_rush(rush_20_12_30, user_input)

bfs = [Inf,Inf,Inf,Inf,10,Inf]
depth = 6
b = Beth(value_heuristic=simple_piece_count, rank_heuristic=simple_rank_moves, search_args=Dict("depth"=>depth, "branching_factors"=>bfs))
b = Beth(value_heuristic=beth_eval, rank_heuristic=beth_rank_moves, search_args=Dict("depth"=>depth, "branching_factors"=>bfs))
game_history = play_game(black_player=b)

play_puzzle(rush_20_12_31[28], user_input)

puzzle_rush(rush_20_12_30, b, print_solution=true)


pz = rush_20_12_13[13]
print_puzzle(pz)
@time root = minimax_search(b, board=deepcopy(pz.board), white=pz.white_to_move)
print_tree(root, max_depth=1, has_to_have_children=false, white=pz.white_to_move)

@time root = minimax_search(b, board=deepcopy(pz.board), white=pz.white_to_move, lower=-1.85, upper=-1.75)



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

b = Beth(value_heuristic=beth_eval, rank_heuristic=beth_rank_moves, search_algorithm=beam_search, search_args=Dict("full_depth"=>4, "beam_width"=>10_000, "beam_depth"=>8, "max_n_leafes"=>50_000))
game_history = play_game(black_player=b)
puzzle_rush(rush_20_12_13, b, print_solution=true)

p = rush_20_12_13[1]
root_beam = beam_search(b, board=p.board, white=p.white_to_move)

board = Board()
move!(board, true, 'P', "e2", "e4")
root_beam = beam_search(b, board=board, white=false)


bfs = [Inf,Inf,Inf,Inf]
depth = 4
b = Beth(value_heuristic=beth_eval, rank_heuristic=beth_rank_moves, search_args=Dict("depth"=>depth, "branching_factors"=>bfs))
game_history = play_game(black_player=b)

board = Board()
move!(board, true, 'P', "e2", "e4")
root_minimax = minimax_search(b, board=board, white=false)

print_tree(root_beam, max_depth=1, white=false, has_to_have_children=false)
print_tree(root_minimax, max_depth=1, white=false, has_to_have_children=false)


print_tree(root_beam["Rc7c8"]["Re7e8"]["Rc8e8"], max_depth=1, has_to_have_children=false)
print_tree(root_minimax["Ng8f6"]["Qd1h5"]["Nf6h5"], max_depth=1, white=false, has_to_have_children=false)

board = deepcopy(p.board)
move!(board, p.white_to_move, 'R', "c7", "c8")
move!(board, !p.white_to_move, 'R', "e7", "e8")
move!(board, p.white_to_move, 'R', "c8", "e8")
print_board(board)

beth_eval(board, false, 30)
