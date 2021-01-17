
function UCB1(node::Node)
    if node.visits == 0
        # prescore set at init. gets overriden once evaluated
        # therefore it is not propagated
        # set to Inf if all children should get evaluated before going deeper
        return node.score + 20 * √(2 * log(node.parent.visits))
    else
        return node.score + 20 * √(2 * log(node.parent.visits) / node.visits)
    end
end

function negUCB1(node::Node)
    if node.visits == 0

            # prescore set at init. gets overriden once evaluated
            # therefore it is not propagated
            # set to Inf if all children should get evaluated before going deeper
        return -node.score + 20 * √(2 * log(node.parent.visits))
    else
        return -node.score + 20 * √(2 * log(node.parent.visits) / node.visits)
    end
end

exploration_UCB1(ratio, λ) = λ * √(2 * log(1/ratio))
power_UCB1(v, λ) = exp(-(v/λ)^2 / 2)

# power_UCB1(1, 3)
# power_UCB1(3, 3)
# power_UCB1(5, 3)
# power_UCB1(9, 3)


function select_node!(root::Node, white::Bool)
    node = root
    _white = white
    while !isempty(node.children)
        if _white
            node = my_argmax(UCB1, node.children)
        else
            node = my_argmax(negUCB1, node.children)
        end
        _white = !_white
    end
    return node
end

function backpropagate!(leaf::Node)
    node = leaf
    v = leaf.score
    while node.parent != nothing
        node = node.parent
        n = node.visits
        node.score += (v - node.score) / (n+1)
        node.visits = n + 1
    end
end

function MCTreeSearch(board=Board(), white=true; N=10)
    _board = deepcopy(board)    # board used to play in tree search
    _white = white              # keep track of player in tree search
    root = Node()

    n = 0
    max_depth = 0
    while n < N
        node = select_node!(root, white) # select leaf node
        n += 1
        #println("ITER $n:")
        # print_tree(root)
        #println("selected node: $node")

        _white, depth = restore_board_position(board, white, _board, node)

        v, mms = simple_piece_count(_board, _white)
        rms = rank_moves(_board, _white, ms)
        sort!(rms, rev=_white)

        node.score = v
        node.visits += 1
        backpropagate!(node)

        # expand new moves
        for (m, prescore) in rms
            c = Node(move=m, parent=node, score=prescore, visits=0)
            push!(node.children, c)
        end


        if depth > max_depth
            # @info("Depth $depth reached.")
            max_depth = depth
        end
    end
    @info("Depth $max_depth reached.")
    return root
end
function lt_childrenMCTS(x,y,white)
    if x.visits == y.visits
        if white
            UCB1(x) < UCB1(y)
        else
            negUCB1(x) < negUCB1(y)
        end
    else
        x.visits < y.visits
    end
end # TODO: arg in print_tree
