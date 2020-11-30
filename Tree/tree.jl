include("evaluation.jl")

mutable struct Node
    move::Move
    parent::Union{Nothing, Node}
    children::Vector{Node}
    score::Float64
    visits::Int
    function Node(;move=(0x00,0x00,0x00), parent=nothing, children=Node[], score=0., visits=0)
        this = new()

        this.parent = parent
        this.move = move
        this.children = children
        this.score = score
        this.visits = visits

        return this
    end
end

import Base.getindex
# s is long notation
function Base.getindex(node::Node, s::String)
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


function lt_children(x,y,white)
    if x.visits == y.visits
        if white
            UCB1(x) < UCB1(y)
        else
            negUCB1(x) < negUCB1(y)
        end
    else
        x.visits < y.visits
    end
end

function print_tree(root::Node; number=0, depth=0, max_depth=Inf, has_to_have_children=true, highlight_best=5, expand_best=Inf, white=true, color=:white)
    if root.parent == nothing
        color = :yellow
    end
    printstyled("\t"^depth * "$number. " * string(root)  * "\n", color=color)

    if depth + 1 > max_depth
        return
    end

    cs = sort(root.children, lt=(x,y)->lt_children(x,y,white), rev=true)

    count = 0
    for (i,c) in enumerate(cs)
        if isempty(c.children) && has_to_have_children
            continue
        end
        if count < expand_best
            color = :light_gray
            if count < highlight_best
                color = white ? :white : :light_blue
            end
            print_tree(c, number=i, depth=depth+1, max_depth=max_depth, has_to_have_children=has_to_have_children,
                highlight_best=highlight_best, expand_best=expand_best, white=!white, color=color)
            count += 1
        end
    end
end

using DataStructures
function find_most_visited(root::Node, N::Int)
    explore = [root]
    sorted = SortedSet([root], Base.Order.ReverseOrdering())
    while !isempty(explore)
        node = pop!(explore)
        push!(sorted, node)
        append!(explore, node.children)
    end

    return collect(sorted)[1:N]
end

import Base.isless
function isless(n1::Node, n2::Node)
    return n1.visits < n2.visits
end

ss = SortedSet([Node(visits=1), Node(), Node(visits=2)], Base.Order.ReverseOrdering())


function print_most_visited(root::Node, N=100; number=0, white=true, nodes=[], depth=0, n_alternatives=0)

    color = white ? :white : :light_blue

    if root.parent == nothing
        color = :yellow
        white = !white
        nodes = find_most_visited(root, N)
    end

    printstyled("\t"^depth * "$number. " * string(root)  * "\n", color=color)

    cs = sort(root.children, lt=(x,y)->x.visits<y.visits, rev=true)

    count = 0
    for (i,c) in enumerate(cs)
        if c in nodes
            print_most_visited(c, number=i, white=!white, nodes=nodes, depth=depth+1, n_alternatives=n_alternatives)
        elseif count < n_alternatives
            print_most_visited(c, number=i, white=!white, nodes=nodes, depth=depth+1, n_alternatives=0)
            count += 1
        end

    end
end

using Printf
import Base.show
function Base.show(io::IO, n::Node)
    if n.move == (0x00, 0x00, 0x00)
        print(io, @sprintf "Root Node, score: %.4f, visits: %d, %d children" n.score n.visits (length(n.children)))

    else
        print(io, @sprintf "%s, score: %.4f, visits: %d, UCB1: %.4f, %d children" n.move n.score n.visits (UCB1(n)) (length(n.children)))
    end
end


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


function get_parents(node::Node, parents=Node[])
    if node.parent != nothing
        pushfirst!(parents, node.parent)
        get_parents(node.parent, parents)
    else
        return parents
    end
end


function count_nodes(node::Node)
    if length(node.children) == 0
        # leaf
        return 1
    else
        return sum(count_nodes(c) for c in node.children)
    end
end

function restore_board_position(board::Board, white::Bool, _board::Board, node::Node)
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

function my_argmax(f, A)
    a = A[1]
    fa = f(a)
    for a´ in A
        fa´ = f(a´)
        if fa´ > fa
            a = a´
            fa = fa´
        end
    end
    return a
end

const λ = 2.55

# factor 8 leads to ≈35 of 10000 visits if one can capture rook and 0 for other
# 8: Rook capture gets 8757 others 33
# 15: Rook capture gets 6058 orhers 113
# 20: Rook capture gets 4128 others 170


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

        v, rms = simple_piece_count(_board, _white)

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


#=
Base.summarysize(Board())
Base.summarysize(Node())



node1 = TreeSearchSlow(N=100, kind=:BFS)
node2 = TreeSearch(N=1000, kind=:BFS)
count_nodes(node1)
count_nodes(node2)

for c in node2.children[9].children[4].children
    println(c)
end

using BenchmarkTools

@btime TreeSearchSlow(N=1000, kind=:BFS) # 173.067 ms (1300939 allocations: 67.89 MiB)
@btime TreeSearch(N=1000, kind=:BFS) # 51.722 ms (732223 allocations: 32.94 MiB)

@time root = TreeSearch(N=10^5, kind=:BFS) # 7.924567 seconds (77.93 M allocations: 3.377 GiB, 22.01% gc time)
@time TreeSearchSlow(N=10^5, kind=:BFS) # 25.268137 seconds (138.03 M allocations: 6.890 GiB, 24.82% gc time)

treesize = Base.summarysize(root)

treesize / 10^6 # MB
treesize / count_nodes(root) # byte per node

@time MCTreeSearch(N=10^5) # 7.702969 seconds (70.67 M allocations: 3.192 GiB, 21.73% gc time)
=#
#@time MCTreeSearch(N=10^5)
