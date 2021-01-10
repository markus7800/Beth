include("tree.jl")

function cap_lt(m1::Move, m2::Move)
    p1 = get_piece(board, tofield(m1.to))
    p2 = get_piece(board, tofield(m2.to))
    return piece_value(p1) < piece_value(p2)
end

# alpha beta search with only capture move and no caching and unlimited depth
function quiesce(beth::Beth, depth::Int, ply::Int, α::Int, β::Int, white::Bool,
        lists::Vector{MoveList}=[MoveList(100) for _ in 1:depth+1])::Int

    beth.n_explored_nodes += 1
    beth.n_quiesce_nodes += 1

    capture_moves = lists[ply+1]

    @assert length(capture_moves) == 0
    # println(ply+1, ", ", depth)

    get_captures!(beth._board, white, capture_moves)
    sort!(capture_moves, rev=true, lt=cap_lt)


    # if count_pieces(beth._board.blacks | beth._board.whites) ≤ 3
    #     board_value, is_3_men = tb_3_men_lookup(beth.tb_3_men_mates, beth.tb_3_men_desperate_positions, beth._board, white)
    #     if !is_3_men
    #         print_board(beth._board) # TODO
    #         println()
    #         println(n_pieces(beth._board, true) + n_pieces(beth._board, false))
    #         println(count_pieces(beth._board.blacks | beth._board.whites))
    #         print_fields(beth._board.blacks)
    #         print_fields(beth._board.whites)
    #         println(key_3_men(beth._board, white))
    #         @assert false
    #     end
    #     return board_value
    # end

    board_value = beth.value_heuristic(beth._board, white)


    if length(capture_moves) == 0 || depth == 0
        beth.max_quiesce_depth = max(beth.max_quiesce_depth, ply)
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

# TODO: alpha beta with only best move stored and fast rank moves
function AlphaBeta(beth::Beth, node::ABNode, depth::Int, ply::Int, α::Int, β::Int, white::Bool,
    use_stored_values=false, store_values=false, do_quiesce=false, quiesce_depth::Int=20,
    quiesce_lists::Vector{MoveList}=[MoveList(200) for _ in 1:quiesce_depth+1], iter_id::Int=0)::Int

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
            value = quiesce(beth, quiesce_depth, 0, α, β, white, quiesce_lists)
            beth.n_explored_nodes -= 1 # correction
            beth.n_quiesce_nodes -= 1 # correction
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

        # tb_value, is_3_men = tb_3_men_lookup(beth.tb_3_men_mates, beth.tb_3_men_desperate_positions, beth._board, white)
        # if is_3_men && ply > 0
        #     return tb_value
        # end

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
                sort!(ranked_moves, rev=white, lt=first_lt) # try to choose best moves first
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
                child = ABNode(move=m, parent=node, value=0)

                push!(node.children, child)
            end

            if white
                # maximise for white
                undo = make_move!(beth._board, white, child.move)
                value = max(value,
                            AlphaBeta(beth, child, depth-1, ply+1, α, β, !white,
                                use_stored_values, store_values, do_quiesce, quiesce_depth, quiesce_lists, iter_id)
                            )
                undo_move!(beth._board, white, child.move, undo)

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
                                use_stored_values, store_values, do_quiesce, quiesce_depth, quiesce_lists, iter_id)
                            )
                undo_move!(beth._board, white, child.move, undo)

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

function AlphaBeta_Search(beth::Beth; board=beth.board, white=beth.white)

    beth.board = deepcopy(board)
    beth._board = deepcopy(board)
    beth.white = white
    beth.n_leafes = 0
    beth.n_explored_nodes = 0
    beth.n_quiesce_nodes = 0
    beth.max_quiesce_depth = 0

    use_stored_values = false
    store_values = false

    depth = beth.search_args["depth"]
    ply = 0
    do_quiesce = get(beth.search_args, "do_quiesce", false)
    quiesce_depth = get(beth.search_args, "quiesce_depth", 20)
    quiese_lists = [MoveList(200) for _ in 1:quiesce_depth+1]

    verbose = get(beth.search_args, "verbose", false)

    root = ABNode()
    v, t, = @timed AlphaBeta(beth, root, depth, ply, MIN_VALUE, MAX_VALUE, white,
        use_stored_values, store_values, do_quiesce, quiesce_depth, quiese_lists)


    if verbose
        @info(@sprintf "%d nodes explored in %.4f seconds (%.2f/s)." beth.n_explored_nodes t (beth.n_explored_nodes/t) )
        if do_quiesce
            q_perc = beth.n_quiesce_nodes/beth.n_explored_nodes*100
            @info(@sprintf "%d leaf nodes" beth.n_leafes)
            @info(@sprintf "%d quiesce nodes (%.2f%%), %d/%d depth reached" beth.n_quiesce_nodes q_perc beth.max_quiesce_depth quiesce_depth)
        end
        @info(@sprintf "number of tree nodes: %d (%.2f MB)" count_nodes(root) Base.summarysize(root) / 10^6)
    end

    @assert beth.board == beth._board

    return v, root.children[root.best_child_index].move
end

function MTDF(beth::Beth; depth::Int, do_quiesce::Bool, quiesce_depth::Int, verbose::Bool=false,
    guess::Int=0, root=ABNode(), iter_id=0)

    white = beth.white

    use_stored_values = true
    store_values = true
    ply = 0

    quiese_lists = [MoveList(200) for _ in 1:quiesce_depth+1]

    value = guess
    upper = MAX_VALUE
    lower = MIN_VALUE
    _,t = @timed while true
        β = value == lower ? value + 1 : value
        value = AlphaBeta(beth, root, depth, ply, β-1, β, white,
            use_stored_values, store_values, do_quiesce, quiesce_depth, quiese_lists, iter_id)

        if value < β
            upper = value
        else
            lower = value
        end
        if verbose
            best_move = root.children[root.best_child_index].move
            @info(@sprintf "\tmove: %s, value: %.2f, alpha: %.2f, beta: %.2f, lower: %.2f, upper: %.2f" best_move value/100 β-1/100 β/100 lower/100 upper/100)
        end

        if lower ≥ upper
            break
        end
    end

    if verbose
        @info(@sprintf "%d nodes explored in %.4f seconds (%.2f/s)." beth.n_explored_nodes t (beth.n_explored_nodes/t) )
        if do_quiesce
            q_perc = beth.n_quiesce_nodes/beth.n_explored_nodes*100
            @info(@sprintf "%d quiesce nodes (%.2f%%), %d/%d depth reached" beth.n_quiesce_nodes q_perc beth.max_quiesce_depth quiesce_depth)
        end
        @info(@sprintf "number of tree nodes: %d (%.2f MB)" count_nodes(root) Base.summarysize(root) / 10^6)
    end

    return value, root.children[root.best_child_index].move
end

function MTDF_Search(beth::Beth; board=beth.board, white=beth.white)
    beth.board = deepcopy(board)
    beth._board = deepcopy(board)
    beth.white = white
    beth.n_leafes = 0
    beth.n_explored_nodes = 0
    beth.n_quiesce_nodes = 0
    beth.max_quiesce_depth = 0

    depth = beth.search_args["depth"]
    do_quiesce = get(beth.search_args, "do_quiesce", false)
    quiesce_depth = get(beth.search_args, "quiesce_depth", 20)

    verbose = get(beth.search_args, "verbose", false)

    return MTDF(beth, depth=depth, do_quiesce=do_quiesce, quiesce_depth=quiesce_depth, verbose=verbose, guess=0, root=ABNode(), iter_id=0)
end

function IterativeMTDF(beth::Beth; board=beth.board, white=beth.white)
    beth.board = deepcopy(board)
    beth._board = deepcopy(board)
    beth.white = white
    beth.n_leafes = 0
    beth.n_explored_nodes = 0
    beth.n_quiesce_nodes = 0
    beth.max_quiesce_depth = 0

    Δt = get(beth.search_args, "time", Inf)
    t1 = time() + Δt

    min_depth = get(beth.search_args, "min_depth", 2)
    max_depth = beth.search_args["max_depth"]

    do_quiesce = get(beth.search_args, "do_quiesce", false)
    quiesce_depth = get(beth.search_args, "quiesce_depth", 20)

    verbose = get(beth.search_args, "verbose", 0)

    guesses = Int[0]
    root = ABNode() # reuse
    reached_depth = 0

    v,t, = @timed for depth in min_depth:1:max_depth
        reached_depth = depth
        guess = guesses[end]
        if verbose ≥ 2
            @info @sprintf "Depth: %d, guess: %.2f" depth guess/100
        end

        value, best_move = MTDF(beth, depth=depth, do_quiesce=do_quiesce, quiesce_depth=quiesce_depth, verbose=verbose ≥ 3,
            guess=guess, root=root, iter_id=depth)

        push!(guesses, value)

        abs(value) ≥ WHITE_MATE && break # stop early for mates

        time() > t1 && break
    end

    if verbose ≥ 1
        @info(@sprintf "%d nodes explored in %.4f seconds (%.2f/s)." beth.n_explored_nodes t (beth.n_explored_nodes/t) )
        if do_quiesce
            q_perc = beth.n_quiesce_nodes/beth.n_explored_nodes*100
            @info(@sprintf "%d quiesce nodes (%.2f%%), %d/%d depth reached" beth.n_quiesce_nodes q_perc beth.max_quiesce_depth quiesce_depth)
        end
        @info(@sprintf "number of tree nodes: %d (%.2f MB)" count_nodes(root) Base.summarysize(root) / 10^6)
        @info("Reached depth: $reached_depth")
    end

    return guesses[end], root.children[root.best_child_index].move
end
