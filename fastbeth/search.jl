include("tree.jl")

function cap_lt(m1::Move, m2::Move)
    p1 = get_piece(board, tofield(m1.to))
    p2 = get_piece(board, tofield(m2.to))
    return piece_value(p1) < piece_value(p2)
end

function quiesce_nomem(beth::Beth, α::Int, β::Int, white::Bool)::Int
    beth.n_explored_nodes += 1

    capture_moves = get_captures(beth._board, white)
    sort!(capture_moves, rev=true, lt=cap_lt)


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
            for m in capture_moves
                undo = make_move!(beth._board, white, m)
                value = max(value, quiesce_nomem(beth, α, β, !white))
                undo_move!(beth._board, white, m, undo)
                α = max(α, value)
                α ≥ β && break # β cutoff
            end
            # if you dont take max here only the board values where the player
            # are forced to make all capture moves are taken into account
            final_value = max(value, board_value)
            return final_value
        else
            value = MAX_VALUE
            for m in capture_moves
                undo = make_move!(beth._board, white, m)
                value = min(value, quiesce_nomem(beth, α, β, !white))
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

# alpha beta search with only capture move and no caching and unlimited depth
function quiesce(beth::Beth, depth::Int, ply::Int, α::Int, β::Int, white::Bool,
        lists::Vector{MoveList}=[MoveList(100) for _ in 1:depth])::Int

    beth.n_explored_nodes += 1
    beth.n_quiesce_nodes += 1

    capture_moves = lists[ply+1]
    # println(ply+1, ", ", depth)

    get_captures!(beth._board, white, capture_moves)
    sort!(capture_moves, rev=true, lt=cap_lt)


    # board_value, is_3_men = tb_3_men_lookup(beth.tb_3_men_mates, beth.tb_3_men_desperate_positions, beth._board, white)
    # if !is_3_men
    #     board_value = beth.value_heuristic(beth._board, white)
    # end
    board_value = beth.value_heuristic(beth._board, white)

    if length(capture_moves) == 0 || depth == 0
        beth.n_leafes += 1
    else
        if white
            value = MIN_VALUE
            for m in capture_moves
                undo = make_move!(beth._board, white, m)
                value = max(value, quiesce(beth, depth-1, ply+1, α, β, !white, lists))
                undo_move!(beth._board, white, m, undo)
                α = max(α, value)
                α ≥ β && break # β cutoff
            end

            # if you dont take max here only the board values where the player
            # are forced to make all capture moves are taken into account
            board_value = max(value, board_value)
        else
            value = MAX_VALUE
            for m in capture_moves
                undo = make_move!(beth._board, white, m)
                value = min(value, quiesce(beth, depth-1, ply+1, α, β, !white, lists))
                undo_move!(beth._board, white, m, undo)
                β = min(β, value)
                β ≤ α && break # α cutoff
            end

            # if you dont take min here only the board values where the player
            # are forced to make all capture moves are taken into account
            board_value = min(value, board_value)
        end
    end

    recycle!(capture_moves)
    return board_value
end

function first_lt(x, y)
    return x[1] < y[1]
end

function AlphaBeta(beth::Beth, node::ABNode, depth::Int, ply::Int, α::Int, β::Int, white::Bool,
    use_stored_values=false, store_values=false, do_quiesce=false, quiesce_depth::Int=20, iter_id::Int=0,
    lists::Vector{MoveList}=[MoveList(200) for _ in 1:depth+quiesce_depth+2])::Int

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

    if depth == 0
        value = 0
        # cannot retrieve since dependent on α, β which are changing by the input
        if do_quiesce
            # println(ply + 1)
            value = quiesce(beth, quiesce_depth, ply+1, α, β, white, lists)
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

        best_value = white ? MIN_VALUE : MAX_VALUE
        value = white ? MIN_VALUE : MAX_VALUE

        # successor moves were not generated yet
        if !node.is_expanded
            ms = lists[ply+1]
            get_moves!(beth._board, white, ms)
            if length(ms) == 0 # terminal unexplored node
                beth.n_leafes += 1
                value = beth.value_heuristic(beth._board, white, no_moves=true)
                node.value = value
                node.ranked_moves = []
            else
                ranked_moves = beth.rank_heuristic(beth._board, white, ms)
                sort!(ranked_moves, rev=white, lt=first_lt) # try to choose best moves first
                node.ranked_moves = ranked_moves
            end
            recycle!(ms)
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
                child = ABNode(move=m, parent=node, value=0)

                push!(node.children, child)
            end

            if white
                # maximise for white
                undo = make_move!(beth._board, white, child.move)
                value = max(value,
                            AlphaBeta(beth, child, depth-1, ply+1, α, β, !white,
                                use_stored_values, store_values, do_quiesce, quiesce_depth, iter_id, lists)
                            )
                undo_move!(beth.board, white, child.move, undo)

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
                undo = make_move!(beth._board, white, child.move)
                value = min(value,
                            AlphaBeta(beth, child, depth-1, ply+1, α, β, !white,
                                use_stored_values, store_values, do_quiesce, quiesce_depth, iter_id, lists)
                            )
                undo_move!(beth.board, white, child.move, undo)

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

function AlphaBeta_search(beth::Beth; board=beth.board, white=beth.white)

    beth.board = board
    beth._board = board
    beth.white = white
    beth.n_leafes = 0
    beth.n_explored_nodes = 0
    beth.n_quiesce_nodes = 0

    use_stored_values = false
    store_values = false

    depth = beth.search_args["depth"]
    ply = 0
    do_quiesce = get(beth.search_args, "do_quiesce", false)
    quiesce_depth = get(beth.search_args, "quiesce_depth", 20)

    verbose = get(beth.search_args, "verbose", false)

    root = ABNode()
    v, t, = @timed AlphaBeta(beth, root, depth, ply, MIN_VALUE, MAX_VALUE, white,
        use_stored_values, store_values, do_quiesce, quiesce_depth)


    if verbose
        @info(@sprintf "%d nodes (%d leafes, %d quiesce) explored in %.4f seconds (%.2f/s)." beth.n_explored_nodes beth.n_leafes beth.n_quiesce_nodes t (beth.n_explored_nodes/t) )
        @info(@sprintf "number of tree nodes: %d (%d MB)" count_nodes(root) Base.summarysize(root) / 10^6)
    end


    return v, root.children[root.best_child_index].move
end



board = Board("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")

# board = Board("6k1/1p4bp/3p4/1q1P1pN1/1r2p3/4B2P/r4PP1/3Q1RK1 w - - 0 1")
# board = Board("r2qkbnr/ppp2ppp/2n1p1b1/3p4/4PP2/3P1N2/PPPN2PP/R1BQKB1R w KQkq - 0 1")

beth = Beth(
    board=board, white=true,
    value_heuristic=evaluation,
    rank_heuristic=rank_moves_by_eval,
    search_algorithm=AlphaBeta_search,
    search_args=Dict(
        "depth" => 5,
        "do_quiesce" => true,
        "verbose" => true
    ))

@time quiesce_nomem(beth, MIN_VALUE, MAX_VALUE, true)
v,t, = @timed quiesce(beth, 100, 0, MIN_VALUE, MAX_VALUE, true)

beth.n_explored_nodes

beth(board, true)
