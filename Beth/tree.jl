using Printf

const NOT_STORED = 0x0
const EXACT = 0x1
const UPPER = 0x2
const LOWER = 0x3

mutable struct ABNode
    move::Move
    best_child_index::Int
    parent::Union{Nothing, ABNode}
    children::Vector{ABNode}
    ranked_moves::Vector{Tuple{Int, Move}}
    value::Int
    flag::UInt8
    stored_at_iteration::Int
    is_expanded::Bool
    hash::UInt # hash of board after move

    function ABNode(;move=EMPTY_MOVE, best_move=EMPTY_MOVE, parent=nothing, children=ABNode[],
        value::Int=0, flag::UInt8=NOT_STORED, hash=UInt(0))

        this = new()

        this.parent = parent
        this.move = move
        this.best_child_index = 0
        this.children = children
        this.value = value
        this.flag = flag
        this.stored_at_iteration = 0
        this.is_expanded = false
        this.hash = hash

        return this
    end
end

import Base.show
function Base.show(io::IO, n::ABNode)
    if n.move == EMPTY_MOVE
        print(io, "Root Node, ")
    else
        print(io, "$(n.move), ")
    end
    print(io, @sprintf "value %.2f, " n.value/100)

    # i = n.best_child_index
    # if i > 0 && length(n.children) ≥ i
    #     best_move = n.children[i].move
    #     print(io, "best move: $best_move, ")
    # end

    print(io, @sprintf "%d children, hash %d" length(n.children) n.hash)
end

function Base.getindex(node::ABNode, s::String)
    p = PIECES[s[1]]
    rf1 = Field(s[2:3])
    rf2 = Field(s[4:5])
    m = (p, rf1, rf2)
    for c in node.children
        if c.move == m
            return c
        end
    end
end

function get_parents(node::ABNode, parents=ABNode[])
    if node.parent != nothing
        pushfirst!(parents, node.parent)
        get_parents(node.parent, parents)
    else
        return parents
    end
end

function count_nodes(node::ABNode)
    if length(node.children) == 0
        # leaf
        return 1
    else
        return sum(count_nodes(c) for c in node.children) + 1
    end
end

function print_parents(node::ABNode)
    ps = get_parents(node)
    for p in ps
        println(p)
    end
    println(node)
end


function best_continuation(root::ABNode)
    current = root
    moves = Move[]
    while current.best_child_index != 0
        current = current.children[current.best_child_index]
        push!(moves, current.move)
    end
    return moves
end
