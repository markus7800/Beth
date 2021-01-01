const UNEXPLORED = 0x0
const EXACT = 0x1
const UPPER = 0x2
const LOWER = 0x3

const SMALLEST_VALUE_Δ = 0.1

const EMPTY_MOVE = (0x0, 0x0, 0x0)

mutable struct ABNode
    move::Move
    best_move::Move
    parent::Union{Nothing, ABNode}
    children::Vector{ABNode}
    ranked_moves::Vector{Tuple{Float64, Move}}
    value::Float64
    flag::UInt8
    visits::UInt
    function ABNode(;move=EMPTY_MOVE, best_move=EMPTY_MOVE, parent=nothing, children=Node[], value=0., visits=0, flag=UNEXPLORED)
        this = new()

        this.parent = parent
        this.move = move
        this.best_move = EMPTY_MOVE
        this.children = children
        this.value = value
        this.visits = visits
        this.flag = flag

        return this
    end
end

import Base.show
function Base.show(io::IO, n::ABNode)
    if n.move == (0x00, 0x00, 0x00)
        print(io, @sprintf "Root Node, score: %.4f, visits: %d, %d children" n.value n.visits (length(n.children)))

    else
        print(io, @sprintf "%s, score: %.4f, visits: %d, %d children" n.move n.value n.visits (length(n.children)))
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

function BethSearch(beth::Beth, node::ABNode, depth::Int, α::Float64, β::Float64, white::Bool, use_stored_values=true)
    beth.n_explored_nodes += 1
    _α = α # store
    _β = β # store

    # look up
    if use_stored_values && node.flag != UNEXPLORED
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

    _white, = restore_board_position(beth, node)
    @assert _white == white

    if depth == 0
        # if node.flag != UNEXPLORED
        #     value = node.value
        # else
        value = beth.value_heuristic(beth._board, white)
        beth.n_leafes += 1
        node.value = value
    else
        best_value = white ? -Inf : Inf
        value = white ? -Inf : Inf

        if node.flag != UNEXPLORED && length(node.children) == 0 # terminal explored node
            return node.value
        end

        if node.flag == UNEXPLORED
            ms = get_moves(beth._board, white)
            if length(ms) == 0 # terminal unexplored node
                beth.n_leafes += 1
                value = beth.value_heuristic(beth._board, white)
                node.value = value
                node.ranked_moves = []
            else
                ranked_moves = beth.rank_heuristic(beth._board, white, ms)
                sort!(ranked_moves, rev=white) # try to choose best moves first
                node.ranked_moves = ranked_moves
            end
        end

        n_children = length(node.children)
        i = 1
        while true
            if i ≤ n_children
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
                child = ABNode(move=m, parent=node, value=prescore, visits=0)

                push!(node.children, child)
            end

            if white
                # maximise for white
                value = max(value, BethSearch(beth, child, depth-1, α, β, !white, use_stored_values))

                # keep track of best move
                if value > best_value
                    best_value = value
                    node.best_move = m
                end

                α = max(α, value)
                α ≥ β && break # β cutoff
            else
                # minimise for black
                value = min(value, BethSearch(beth, child, depth-1, α, β, !white, use_stored_values))

                # keep track of best move
                if value < best_value
                    best_value = value
                    node.best_move = m
                end

                β = min(β, value)
                β ≤ α && break # α cutoff
            end

            i += 1
        end

        node.value = value
    end

    if use_stored_values
        if node.value ≤ _α
            # Fail low result implies an upper bound
            node.flag = UPPER
        elseif β ≤ node.value
            # Fail high result implies a lower bound
            node.flag = LOWER
        else
            # Found an accurate minimax value - will not occur if called with zero window (α = β-
            node.flag = EXACT
        end
    end

    return node.value
end

function start_beth_search(beth::Beth; board=beth.board, white=beth.white, verbose=true,
    lower=-Inf, upper=Inf, use_stored_values=false, root=ABNode(), depth=beth.search_args["depth"])

    beth.board = board
    beth.white = white
    beth.n_leafes = 0
    beth.n_explored_nodes = 0

    v,t = @timed BethSearch(beth, root, depth, lower, upper, white, use_stored_values)


    verbose && @info(@sprintf "%d nodes (%d leafes) explored in %.4f seconds (%.2f/s)." beth.n_explored_nodes beth.n_leafes t (beth.n_explored_nodes/t) )

    return v, root
end

function BethMTDF(beth::Beth; board=beth.board, white=beth.white,
    guess::Float64, depth::Int,
    root=ABNode(), verbose=true)

    beth.board = board
    beth.white = white
    beth.n_leafes = 0
    beth.n_explored_nodes = 0

    value = guess
    upper = Inf
    lower = -Inf

    _,t = @timed while true
        β = value == lower ? value + SMALLEST_VALUE_Δ : value
        value = BethSearch(beth, root, depth, β-SMALLEST_VALUE_Δ, β, white, true)
        if value < β
            upper = value
        else
            lower = value
        end

        # @info(@sprintf "value: %.2f, alpha: %.2f, beta: %.2f, lower: %.2f, %.2f" value β-1 β lower upper)

        if lower ≥ upper
            break
        end
    end

    verbose && @info(@sprintf "%d nodes (%d leafes) explored in %.4f seconds (%.2f/s)." beth.n_explored_nodes beth.n_leafes t (beth.n_explored_nodes/t) )

    return value
end

v, root = start_beth_search(beth, board=deepcopy(pz.board), white=pz.white_to_move, depth=6)

v = BethMTDF(beth, board=deepcopy(pz.board), white=pz.white_to_move, guess=0., depth=6)
