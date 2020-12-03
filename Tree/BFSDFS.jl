
function expand!(node::Node, board::Board, white::Bool)
    ms = get_moves(board, white)
    node.children = Vector{Node}(undef, length(ms))
    for (i, m) in enumerate(ms)
        score = 0 # todo evaluate
        node.children[i] = Node(move=m, parent=node, score=score)
    end
end


function TreeSearchSlow(board=Board(); N=10^5, kind=:BFS)
    _board = deepcopy(board)
    root = Node()

    Q = [(root, deepcopy(board), true, 0)]
    n = 0
    max_depth = 0

    if kind == :BFS
        get_node! = popfirst!
    elseif kind == :DFS
        get_node! = pop!
    else
        error("Unknown search kind!")
    end

    while !isempty(Q) && n < N
        node, _board, white, depth = get_node!(Q)
        if depth > max_depth && kind == :BFS
            #@info("Depth $depth reached.")
            max_depth = depth
        end
        n += 1

        expand!(node, _board, white)
        for c in node.children
            c_board = deepcopy(_board)
            p, rf1, rf2 = c.move
            move!(c_board, white, p, rf1, rf2)
            push!(Q, (c, c_board, !white, depth+1))
        end
    end
    return root
end


function TreeSearch(board=Board(), white=true; N=10^5, kind=:BFS)
    _board = deepcopy(board)
    _white = white
    root = Node()

    Q = [root]
    n = 0
    max_depth = 0

    if kind == :BFS
        get_node! = popfirst!
    elseif kind == :DFS
        get_node! = pop!
    else
        error("Unknown search kind!")
    end

    while !isempty(Q) && n < N
        node = get_node!(Q)
        n += 1

        _white, depth = restore_board_position(board, white, _board, node)

        if depth > max_depth && kind == :BFS
            @info("Depth $depth reached.")
            max_depth = depth
        end

        # expand new moves
        expand!(node, _board, _white)
        for c in node.children
            push!(Q, c)
        end
    end
    return root
end
