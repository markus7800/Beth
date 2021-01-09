
function get_capture_moves(board::Board, white::Bool, ms::MoveList)::Vector{Tuple{Int, Move}}
    mult = white ? 1 : -1

    ranked_captures = Vector{Tuple{Int, Move}}()
    for m in ms
        p = get_piece(board, tofield(m.to))

        if p != NO_PIECE # capture
            push!(ranked_captures, (PIECE_VALUES[p] * mult, m))
        end
    end

    return ranked_captures
end

function first_lt(x,y)
    x[1] < y[1]
end

# alpha beta search with only capture move and no caching and unlimited depth
function quiesce(beth::Beth, α::Int, β::Int, white::Bool)::Int
    beth.n_explored_nodes += 1

    ms = get_moves(beth._board, white)
    capture_moves = get_capture_moves(beth._board, white, ms)
    sort!(capture_moves, rev=white, lt=first_lt)

    # board_value, is_3_men = tb_3_men_lookup(beth.tb_3_men_mates, beth.tb_3_men_desperate_positions, beth._board, white)
    # if !is_3_men
    #     board_value = beth.value_heuristic(beth._board, white)
    # end
    board_value = beth.value_heuristic(beth._board, white)

    if length(capture_moves) == 0
        beth.n_leafes += 1
        return board_value
    else
        if white
            value = MIN_VALUE
            for (prescore, m) in capture_moves
                undo = make_move!(beth._board, white, m)
                value = max(value, quiesce(beth, α, β, !white))
                undo_move!(beth._board, white, m, undo)
                α = max(α, value)
                α ≥ β && break # β cutoff
            end
            # if you dont take max here only the board values where the player
            # are forced to make all capture moves are taken into account
            final_value = max(value, board_value)
            node.value = final_value
            return final_value
        else
            value = MAX_VALUE
            for (prescore, m) in capture_moves
                undo = make_move!(beth._board, white, m)
                value = min(value, quiesce(beth, α, β, !white))
                undo_move!(beth._board, white, m, undo)
                β = min(β, value)
                β ≤ α && break # α cutoff
            end
            # if you dont take min here only the board values where the player
            # are forced to make all capture moves are taken into account
            final_value = min(value, board_value)
            return final_value
        end
    end
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
                value = beth.value_heuristic(beth._board, white, no_moves=true)
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

board = Board("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")

beth = Beth(board=board, white=true, search_algorithm=()->nothing,
    value_heuristic=evaluation, rank_heuristic=rank_moves_by_eval)

quiesce(beth, MIN_VALUE, MAX_VALUE, true)
