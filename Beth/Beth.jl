include("../chess/chess.jl")
include("evaluation.jl")
include("../endgame/four/tablebase.jl")
include("../opening/opening_book.jl")
include("tree.jl")


using Printf

mutable struct Beth
    search_algorithm::Function
    search_args::Dict{String, Any}

    value_heuristic::Function
    rank_heuristic::Function

    root::ABNode
    current::ABNode
    current_ply::Int

    board::Board # board capturing current position, playing starts here
    white::Bool # current next player to move

    _board::Board # board used for playing in tree search

    n_leafes::Int
    n_explored_nodes::Int
    n_quiesce_nodes::Int

    max_depth::Int
    max_quiesce_depth::Int

    tbs::TableBases
    ob::OpeningBook

    function Beth(;board=StartPosition(), white=true, search_algorithm, search_args=Pair[], value_heuristic, rank_heuristic)
        beth = new()
        @info "Heuristics: $value_heuristic, $rank_heuristic"
        @info "Search: $search_algorithm"
        @info "Args: $search_args"

        beth.search_algorithm = search_algorithm
        beth.search_args = search_args

        beth.value_heuristic = value_heuristic
        beth.rank_heuristic = rank_heuristic

        beth.root = ABNode()
        beth.current = beth.root
        beth.current_ply = 0

        beth.board = board
        beth.white = white

        beth._board = deepcopy(board)

        beth.n_leafes = 0
        beth.n_explored_nodes = 0

        beth.n_quiesce_nodes = 0
        beth.max_quiesce_depth = 0

        beth.tbs = TableBases([
            "3_men", "KBBK", "KBNK",
            "KQKB", "KQKN", "KQKR", "KQKQ",
            "KRKB", "KRKN", "KRKR", "KRKQ"
        ])

        beth.ob = get_queens_gambit()

        return beth
    end
end

function (beth::Beth)(board::Board, white::Bool)
    if haskey(beth.ob, board)
        move = beth.ob[board]
        @info("Computer says: Position known. Move is $move.")
        return move, :book
    end

    value, move = beth.search_algorithm(beth, board=board, white=white)
    println(@sprintf "Computer says: %s valued with %.2f." move value/100)
    return move, value
end

function make_move!(beth::Beth, move::Move; keep_tree=false)
    node_count = count_nodes(beth.root)
    child = nothing
    if keep_tree
        for c in beth.current.children
            if c.move == move
                child = c
            else
                # remove
                c.parent = nothing
            end
        end
        if isnothing(child)
            error("Did not find move $move.")
        end
    else
        child = ABNode(move=move, parent=beth.current)
    end

    beth.current.children = [child]
    beth.current = child
    beth.current_ply += 1

    node_diff = node_count - count_nodes(beth.root)
    @info @sprintf "Threw away %d nodes (%.2f%%)" node_diff node_diff/node_count*100

    make_move!(beth.board, beth.white, move)
    beth.white = !beth.white

    beth._board = deepcopy(beth.board)
end

function reset_node_count(beth::Beth)
    beth.n_leafes = 0
    beth.n_quiesce_nodes = 0
    beth.n_explored_nodes = 0
end

include("search.jl")


beth = Beth(
    value_heuristic=evaluation,
    rank_heuristic=rank_moves_by_eval,
    search_algorithm=AlphaBeta_Search,
    search_args=Dict(
        "depth" => 2,
        "do_quiesce" => true,
        "quiesce_depth" => 20,
        "verbose" => true
    ))




depth = 5
v, move, _ = MTDF(beth; depth=depth, do_quiesce=true, quiesce_depth=50, verbose=true,
   guess=0, root=beth.current, t1=Inf, iter_id=1)
reset_node_count(beth)

make_move!(beth, move, keep_tree=true)

depth = 4
v, move, _ = MTDF(beth; depth=depth, do_quiesce=true, quiesce_depth=50, verbose=true,
   guess=0, root=beth.current, t1=Inf, iter_id=1)

print_parents(beth.current)
