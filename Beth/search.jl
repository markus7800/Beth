const NOT_STORED = 0x0
const EXACT = 0x1
const UPPER = 0x2
const LOWER = 0x3

const SMALLEST_VALUE_Δ = 0.1

const EMPTY_MOVE = (0x0, 0x0, 0x0)

mutable struct ABNode
    move::Move
    best_child_index::Int
    parent::Union{Nothing, ABNode}
    children::Vector{ABNode}
    ranked_moves::Vector{Tuple{Float64, Move}}
    value::Float64
    flag::UInt8
    visits::UInt
    stored_at_iteration::Int
    is_expanded::Bool

    function ABNode(;move=EMPTY_MOVE, best_move=EMPTY_MOVE, parent=nothing, children=Node[], value=0., visits=0, flag=NOT_STORED)
        this = new()

        this.parent = parent
        this.move = move
        this.best_child_index = 0
        this.children = children
        this.value = value
        this.visits = visits
        this.flag = flag
        this.stored_at_iteration = 0
        this.is_expanded = false

        return this
    end
end

import Base.show
function Base.show(io::IO, n::ABNode)
    if n.move == (0x00, 0x00, 0x00)
        print(io, @sprintf "Root Node, value: %.4f, %d children" n.value (length(n.children)))

    else
        i = n.best_child_index
        if i > 0
            best_move = n.children[i].move
        else
            best_move = EMPTY_MOVE
        end
        print(io, @sprintf "%s, value: %.4f, best move: %s, %d children" n.move n.value best_move (length(n.children)))
    end
end

function Base.getindex(node::ABNode, s::String)
    p = PIECES[s[1]]
    rf1 = symbol(s[2:3])
    rf2 = symbol(s[4:5])
    m = (p, rf1, rf2)
    for c in node.children
        if c.move == m
            return c
        end
    end
end

function lt_children(x::ABNode,y::ABNode,white)
    if white
        x.value < y.value
    else
        y.value < x.value
    end
end



function restore_board_position(beth::Beth, node::ABNode)
    restore_board_position(beth.board, beth.white, beth._board, node)
end

# TODO
function get_parents(node::ABNode, parents=ABNode[])
    if node.parent != nothing
        pushfirst!(parents, node.parent)
        get_parents(node.parent, parents)
    else
        return parents
    end
end

# TODO
function restore_board_position(board::Board, white::Bool, _board::Board, node::ABNode)
    # restore root board position
    _board.position .= board.position
    _board.can_castle .= board.can_castle
    _board.can_en_passant .= board.can_en_passant
    _white = white
    depth = 0

    # update board to current position
    if node.move != (0x00, 0x00, 0x00)
        parents = get_parents(node)
        for p in parents
            if p.move != (0x00, 0x00, 0x00)
                move!(_board, _white, p.move[1], p.move[2], p.move[3])
                _white = !_white
            end
        end
        move!(_board, _white, node.move[1], node.move[2], node.move[3])
        _white = !_white
        depth = length(parents) - 1
    end

    return _white, depth
end


function get_capture_moves(board::Board, white::Bool, ms::Vector{Move})
    player = 7 + !white
    opponent = 7 + white
    mult = white ? 1 : -1

    ranked_captures = Vector{Tuple{Float64, Move}}()
    for m in ms
        r, f = cartesian(m[3]) # destination field
        if board[r,f,opponent] # capture
            v = 1*board[r,f,PAWN] + 3*board[r,f,BISHOP] + 3*board[r,f,KNIGHT] + 5*board[r,f,ROOK] + 9*board[r,f,QUEEN]
            push!(ranked_captures, (v*mult, m))
        end
    end

    # TODO: sort here
    return ranked_captures
end

# alpha beta search with only capture move and no caching and unlimited depth
function quiesce(beth::Beth, node::ABNode, α::Float64, β::Float64, white::Bool)
    beth.n_explored_nodes += 1

    _white, = restore_board_position(beth, node)
    @assert _white == white

    ms = get_moves(beth._board, white)
    capture_moves = get_capture_moves(beth._board, white, ms)
    sort!(capture_moves, rev=white)

    board_value, is_3_men = tb_3_men_lookup(beth.tb_3_men_mates, beth.tb_3_men_desperate_positions, beth._board, white)
    if !is_3_men
        board_value = beth.value_heuristic(beth._board, white)
    end

    if length(capture_moves) == 0
        beth.n_leafes += 1
        node.value = board_value
        return board_value
    else
        if white
            value = -Inf
            for (prescore, m) in capture_moves
                child = ABNode(move=m, parent=node, value=prescore, visits=0)
                push!(node.children, child)
                value = max(value, quiesce(beth, child, α, β, !white))

                α = max(α, value)
                α ≥ β && break # β cutoff
            end
            # if you dont take max here only the board values where the player
            # are forced to make all capture moves are taken into account
            final_value = max(value, board_value)
            node.value = final_value
            return final_value
        else
            value = Inf
            for (prescore, m) in capture_moves
                child = ABNode(move=m, parent=node, value=prescore, visits=0)
                push!(node.children, child)
                value = min(value, quiesce(beth, child, α, β, !white))

                β = min(β, value)
                β ≤ α && break # α cutoff
            end
            # if you dont take min here only the board values where the player
            # are forced to make all capture moves are taken into account
            final_value = min(value, board_value)
            node.value = final_value
            return final_value
        end
    end
end

function prune!(node::ABNode)
    for child in node.children
        child.parent = nothing
    end
    node.children = []
end

function BethSearch(beth::Beth, node::ABNode, depth::Int, α::Float64, β::Float64, white::Bool,
    use_stored_values=true, store_values=true, do_quiesce=false, iter_id::Int=0)

    beth.n_explored_nodes += 1
    _α = α # store
    _β = β # store

    # look up only if node was stored in this iteration of BethSearch
    # used for multiple null window searches
    # but not used in iterative deepening
    if use_stored_values && node.flag != NOT_STORED && node.stored_at_iteration == iter_id
        value = node.value
        if node.flag == EXACT
            return value
        elseif node.flag == LOWER
            α = max(α, value)
        elseif node.flag == UPPER
            β = min(β, value)
        end

        if α ≥ β
            return value
        end
    end

    # restore board position, playing all moves that lead node
    # this is faster than copying the board
    _white, = restore_board_position(beth, node)
    @assert _white == white

    if depth == 0
        value = 0.
        # cannot retrieve since dependent on α, β which are changing by the input
        if do_quiesce
            value = quiesce(beth, node, α, β, white)
            prune!(node)
        else
            value = beth.value_heuristic(beth._board, white)
        end

        beth.n_leafes += 1
        node.value = value
        # leaf nodes are in general not terminal
        # and not expanded but can be stored
    else

        # terminal explored node, retrieve regardless of iteration id
        if node.is_expanded && length(node.children) == 0 && length(node.ranked_moves) == 0
            return node.value
        end

        best_value = white ? -Inf : Inf
        value = white ? -Inf : Inf

        # successor moves were not generated yet
        if !node.is_expanded
            ms = get_moves(beth._board, white)
            if length(ms) == 0 # terminal unexplored node
                beth.n_leafes += 1
                value = beth.value_heuristic(beth._board, white) # TODO: stale mate, check mate etc. here
                node.value = value
                node.ranked_moves = []
            else
                ranked_moves = beth.rank_heuristic(beth._board, white, ms)
                sort!(ranked_moves, rev=white) # try to choose best moves first
                node.ranked_moves = ranked_moves
            end
            node.is_expanded = true
        end

        n_children = length(node.children)
        i = 0
        while true
            if i == 0
                # try previous best move first
                if node.best_child_index > 0
                    child = node.children[node.best_child_index]
                    m = child.move
                else
                    i += 1
                    continue
                end
                i += 1
                continue
            elseif i ≤ n_children
                # first process all exiting children
                # these were previously the best moves if node was explored
                # children are in correct prevalue order
                child = node.children[i]
                m = child.move
            else
                # existing children exhausted
                # create new nodes if unexplored ranked moves are available
                length(node.ranked_moves) == 0 && break

                prescore, m = popfirst!(node.ranked_moves)
                child = ABNode(move=m, parent=node, value=0., visits=0)

                push!(node.children, child)
            end

            if white
                # maximise for white
                value = max(value, BethSearch(beth, child, depth-1, α, β, !white, use_stored_values, store_values, do_quiesce, iter_id))

                # keep track of best move
                if value > best_value
                    best_value = value
                    if i != 0
                        node.best_child_index = i
                    end # otherwise: current child is previous best move
                end

                α = max(α, value)
                α ≥ β && break # β cutoff
            else
                # minimise for black
                value = min(value, BethSearch(beth, child, depth-1, α, β, !white, use_stored_values, store_values, do_quiesce, iter_id))

                # keep track of best move
                if value < best_value
                    best_value = value
                    if i != 0
                        node.best_child_index = i
                    end # otherwise: current child is previous best move
                end

                β = min(β, value)
                β ≤ α && break # α cutoff
            end

            i += 1
        end
        node.value = value
    end

    if store_values
        # keep track of "deepening iteration" for reuse in null window search in MTDF
        node.stored_at_iteration = iter_id
        if node.value ≤ _α
            # Fail low result implies an upper bound
            node.flag = UPPER
        elseif _β ≤ node.value
            # Fail high result implies a lower bound
            node.flag = LOWER
        else
            # Found an accurate minimax value - will not occur if called with null window
            node.flag = EXACT
        end
    end

    return node.value
end

function start_beth_search(beth::Beth; board=beth.board, white=beth.white, verbose=true,
    lower=-Inf, upper=Inf, use_stored_values=false, store_values=false, root=ABNode(), depth=beth.search_args["depth"], do_quiesce=false, iter_id=0)

    beth.board = board
    beth.white = white
    beth.n_leafes = 0
    beth.n_explored_nodes = 0

    v,t = @timed BethSearch(beth, root, depth, lower, upper, white, use_stored_values, store_values, do_quiesce, iter_id)


    verbose && @info(@sprintf "%d nodes (%d leafes) explored in %.4f seconds (%.2f/s)." beth.n_explored_nodes beth.n_leafes t (beth.n_explored_nodes/t) )

    return v, root.children[root.best_child_index].move
end

function BethMTDF(beth::Beth; board=beth.board, white=beth.white,
    guess::Float64=0., depth::Int=beth.search_args["depth"],
    root=ABNode(), verbose=true, do_quiesce=beth.search_args["do_quiesce"], iter_id=0)

    beth.board = board
    beth.white = white
    beth.n_leafes = 0
    beth.n_explored_nodes = 0

    value = guess
    upper = Inf
    lower = -Inf

    use_stored_values = true
    store_values = true

    count = 1

    _,t = @timed while true
        β = value == lower ? value + SMALLEST_VALUE_Δ : value
        value = BethSearch(beth, root, depth, β-SMALLEST_VALUE_Δ, β, white, use_stored_values, store_values, do_quiesce, iter_id)
        if value < β
            upper = value
        else
            lower = value
        end
        best_move = root.children[root.best_child_index].move
        @info(@sprintf "\tmove: %s value: %.2f, alpha: %.2f, beta: %.2f, lower: %.2f, %.2f" best_move value β-1 β lower upper)

        if lower ≥ upper
            break
        end

        count += 1
    end

    verbose && @info(@sprintf "%d nodes (%d leafes) explored in %.4f seconds (%.2f/s)." beth.n_explored_nodes beth.n_leafes t (beth.n_explored_nodes/t) )

    return value, root.children[root.best_child_index].move
end

function BethIMTDF(beth::Beth; board=beth.board, white=beth.white, max_depth::Int, do_quiesce=true)
    beth.board = board
    beth.white = white

    guesses = [0.]
    root = ABNode()
    @time for depth in 2:1:max_depth
        guess = guesses[end]
        @info @sprintf "Depth: %d, guess: %.2f" depth guess
        value, best_move = BethMTDF(beth, guess=guess, depth=depth, root=root, verbose=true, iter_id=depth, do_quiesce=do_quiesce)
        push!(guesses, value)
    end

    return guesses[end], root.children[root.best_child_index].move
end

function BethTimedIMTDF(beth::Beth; board=beth.board, white=beth.white,
    Δt::Float64=beth.search_args["time"],
    min_depth::Int=beth.search_args["min_depth"],
    max_depth::Int=beth.search_args["max_depth"],
    do_quiesce=beth.search_args["do_quiesce"])

    beth.board = board
    beth.white = white

    t0 = time()
    t1 = t0 + Δt

    guesses = [0.]
    root = ABNode()
    @time for depth in min_depth:1:max_depth
        guess = guesses[end]
        @info @sprintf "Depth: %d, guess: %.2f" depth guess
        value, best_move = BethMTDF(beth, guess=guess, depth=depth, root=root, verbose=true, iter_id=depth, do_quiesce=do_quiesce)
        push!(guesses, value)

        time() > t1 && break
    end

    return guesses[end], root.children[root.best_child_index].move
end

function BethIterAlphaBeta(beth::Beth; board=beth.board, white=beth.white, max_depth::Int, do_quiesce=true)
    beth.board = board
    beth.white = white

    root = ABNode()
    @time for depth in 2:1:max_depth
        value, best_move = start_beth_search(beth, depth=depth, root=root, verbose=true, iter_id=depth, do_quiesce=do_quiesce)
        @info @sprintf "depth %d: value %.2f move: %s" depth value best_move
    end

    return root.value, root.children[root.best_child_index].move
end

pz = rush_20_12_13[9]
print_puzzle(pz)

beth = Beth(value_heuristic=beth_eval, rank_heuristic=beth_rank_moves,
    search_algorithm=BethTimedIMTDF, search_args=Dict("do_quiesce"=>true, "depth"=>10, "time"=>10.))

beth(pz.board, pz.white_to_move)

beth = Beth(value_heuristic=beth_eval, rank_heuristic=beth_rank_moves,
    search_algorithm=BethMTDF, search_args=Dict("do_quiesce"=>true, "depth"=>4))

history = play_game(black_player=beth)

v, best_move, root = start_beth_search(beth, board=deepcopy(pz.board), white=pz.white_to_move, depth=4, do_quiesce=true)

v, best_move = BethMTDF(beth, board=deepcopy(pz.board), white=pz.white_to_move, guess=0., depth=4, do_quiesce=true)

v, best_move = BethIMTDF(beth, board=deepcopy(pz.board), white=pz.white_to_move, max_depth=4)

v, root = start_beth_search(beth, board=deepcopy(pz.board), white=pz.white_to_move, depth=8,
    lower=-0.1, upper=0., use_stored_values=false)

v, best_move = BethIMTDF(beth, board=deepcopy(pz.board), white=pz.white_to_move, max_depth=6, do_quiesce=true)
v, best_move = BethIterAlphaBeta(beth, board=deepcopy(pz.board), white=pz.white_to_move, max_depth=4, do_quiesce=true)

root = ABNode()
v, best_move = BethMTDF(beth, board=deepcopy(pz.board), white=pz.white_to_move, guess=0., depth=6, do_quiesce=true, root=root, iter_id=1)
v, best_move = BethMTDF(beth, board=deepcopy(pz.board), white=pz.white_to_move, guess=0., depth=4, do_quiesce=true, root=root, iter_id=2)

root = ABNode()
v, best_move = BethMTDF(beth, board=deepcopy(pz.board), white=pz.white_to_move, guess=0., depth=4, do_quiesce=true, root=root, iter_id=2)

start_beth_search(beth, depth=2, root=ABNode(), verbose=true, iter_id=2)

root = ABNode()
v, best_move = start_beth_search(beth, board=deepcopy(pz.board), white=pz.white_to_move, depth=2, do_quiesce=true, root=root, iter_id=1)
v, best_move = start_beth_search(beth, board=deepcopy(pz.board), white=pz.white_to_move, depth=4, do_quiesce=true, root=root, iter_id=2)

root = ABNode()
v, best_move = start_beth_search(beth, board=deepcopy(pz.board), white=pz.white_to_move, depth=4, do_quiesce=true, root=root, iter_id=1)


print_tree(root, white=pz.white_to_move, has_to_have_children=false)

function F(;kw...)
    println(kw)
    println(kw...)
end

F(k="1", c="2")





beth = Beth(value_heuristic=beth_eval, rank_heuristic=beth_rank_moves,
    search_algorithm=BethMTDF ,search_args=Dict("depth"=>4, "do_quiesce"=>true))

puzzle_rush(rush_20_12_13, beth)
puzzle_rush(rush_20_12_30, beth)
puzzle_rush(rush_20_12_31, beth)



board = Board(false, false)
board.position[cartesian("e2")..., [PAWN, WHITE]] .= 1
board.position[cartesian("e3")..., [KING, WHITE]] .= 1
board.position[cartesian("e5")..., [KING, BLACK]] .= 1
print_board(board)

key_white, is_3_men = key_3_men(board, true)
key_black, is_3_men = key_3_men(board, false)

get(beth.tb_3_men_desperate_positions, key_white, NaN)
get(beth.tb_3_men_mates, key_white, NaN)

get(beth.tb_3_men_desperate_positions, key_black, NaN)
get(beth.tb_3_men_mates, key_black, NaN)

tb_3_men_lookup(beth.tb_3_men_mates, beth.tb_3_men_desperate_positions, board, true)
tb_3_men_lookup(beth.tb_3_men_mates, beth.tb_3_men_desperate_positions, board, false)

v, best_move = BethMTDF(beth, board=board, white=true, guess=0., depth=4, do_quiesce=true)
root = ABNode()
v, best_move = BethMTDF(beth, board=board, white=false, guess=0., depth=4, do_quiesce=true, root=root)
print_tree(root, white=false, has_to_have_children=false)

board = Board(false, false)
board.position[cartesian("e2")..., [PAWN, WHITE]] .= 1
board.position[cartesian("d3")..., [KING, WHITE]] .= 1
board.position[cartesian("e5")..., [KING, BLACK]] .= 1
print_board(board)

key_white, is_3_men = key_3_men(board, true)
key_black, is_3_men = key_3_men(board, false)

get(beth.tb_3_men_desperate_positions, key_white, NaN)
get(beth.tb_3_men_mates, key_white, NaN)

get(beth.tb_3_men_desperate_positions, key_black, NaN)
get(beth.tb_3_men_mates, key_black, NaN)

tb_3_men_lookup(beth.tb_3_men_mates, beth.tb_3_men_desperate_positions, board, true)
tb_3_men_lookup(beth.tb_3_men_mates, beth.tb_3_men_desperate_positions, board, false)


v, best_move = BethMTDF(beth, board=board, white=false, guess=0., depth=4, do_quiesce=true)
root = ABNode()
v, best_move = BethMTDF(beth, board=board, white=true, guess=0., depth=4, do_quiesce=true, root=root)
print_tree(root, white=true, has_to_have_children=false)

history = play_game(deepcopy(board), true, white_player=beth, black_player=beth)
play_game(deepcopy(board), false, white_player=beth, black_player=beth)



history = play_game(white_player=beth, black_player=beth)



beth = Beth(value_heuristic=beth_eval, rank_heuristic=beth_rank_moves,
    search_algorithm=BethTimedIMTDF, search_args=Dict("do_quiesce"=>true, "min_depth"=>4, "max_depth"=>100, "time"=>5.))

history = play_game(white_player=beth, black_player=beth)

# TODO:
# razoring
# null move pruning
# avoid draw by repetition
