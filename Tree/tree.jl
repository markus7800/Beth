

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


import Base.show
function Base.show(io::IO, n::Node)
    print(io, "$(n.move), score: $(n.score), visits: $(n.visits), $(length(n.children)) children")
end


function expand!(node::Node, board::Board, white::Bool)
    ms = get_moves(board, white)
    node.children = Vector{Node}(undef, length(ms))
    for (i, m) in enumerate(ms)
        score = 0 # todo evaluate
        node.children[i] = Node(move=m, parent=node, score=score)
    end
end


n = Node()
board = Board()

expand!(n, board, true)

Base.summarysize(n)
Base.sizeof(n) * 21


for c in n.children
    println(c)
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

        if depth == 4 && kind == :BFS
            break
        end

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

    Q = [(root, 0)]
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
        node, depth = get_node!(Q)
        if depth > max_depth && kind == :BFS
            #@info("Depth $depth reached.")
            max_depth = depth
        end
        n += 1

        if depth == 4 && kind == :BFS
            break
        end

        # restore root board position
        _board.position .= board.position
        _board.can_castle .= board.can_castle
        _board.can_en_passant .= board.can_en_passant
        _white = white

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
        end


        # expand new moves
        expand!(node, _board, _white)
        for c in node.children
            push!(Q, (c, depth+1))
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

@time root = BFS(N=10^4) # 18s

count_nodes(root)

Base.summarysize(Board())
Base.summarysize(Node())


root.children[3]

n = Node()
expand!(n, Board(), true)

n.children[1]

@time node = TreeSearch(N=10^5, kind=:BFS)

count_nodes(node)

for (i,c) in enumerate(node.children[14].children[10].children)
    println(i,": ", c)
end

board = Board()
move!(board, true, 'P', "e2", "e4")
move!(board, false, 'P', "e7", "e5")
print_board(board, highlight = ".")
string.(get_moves(board, true))

test_node = Node()
expand!(test_node, board, false)
test_node

map(c->string(c.move), node.children[14].children[10].children)

node = TreeSearchSlow(N=10^4, kind=:BFS)

get_parents(node.children[1].children[1].children[1])

Juno.profiler()

if undef
    print("s")
end

node1 = TreeSearchSlow(N=1000, kind=:BFS)
node2 = TreeSearch(N=1000, kind=:BFS)
count_nodes(node1)
count_nodes(node2)

for c in node2.children[9].children[4].children
    println(c)
end

using BenchmarkTools

@btime TreeSearchSlow(N=1000, kind=:BFS) # 173.067 ms (1300939 allocations: 67.89 MiB)
@btime TreeSearch(N=1000, kind=:BFS) # 51.722 ms (732223 allocations: 32.94 MiB)
