
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

using Printf
import Base.show
function Base.show(io::IO, n::Node)
    if n.move == (0x00, 0x00, 0x00)
        print(io, @sprintf "Root Node, score: %.4f, visits: %d, %d children" n.score n.visits (length(n.children)))

    else
        print(io, @sprintf "%s, score: %.4f, visits: %d, %d children" n.move n.score n.visits (length(n.children)))
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
    if white
        x.score < y.score
    else
        y.score < x.score
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




function get_parents(node::Node, parents=Node[])
    if node.parent != nothing
        pushfirst!(parents, node.parent)
        get_parents(node.parent, parents)
    else
        return parents
    end
end

function is_terminal(node::Node)
    return length(node.children) == 0 && visited > 0
end


function count_nodes(node::Node)
    if length(node.children) == 0
        # leaf
        return 1
    else
        return sum(count_nodes(c) for c in node.children) + 1
    end
end

# restores board position up to (including) move of node
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
