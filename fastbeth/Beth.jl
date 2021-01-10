include("../fastchess/chess.jl")
include("evaluation.jl")
using Printf

mutable struct Beth
    search_algorithm::Function
    search_args::Dict{String, Any}

    value_heuristic::Function
    rank_heuristic::Function

    board::Board # board capturing current position, playing starts here
    white::Bool # current next player to move
    _board::Board # board used for playing in tree search, reset to board

    n_leafes::Int
    n_explored_nodes::Int
    n_quiesce_nodes::Int

    max_quiesce_depth::Int

    function Beth(;board=StartPosition(), white=true, search_algorithm, search_args=Pair[], value_heuristic, rank_heuristic)
        beth = new()
        @info "Heuristics: $value_heuristic, $rank_heuristic"
        @info "Search: $search_algorithm"
        @info "Args: $search_args"

        beth.search_algorithm = search_algorithm
        beth.search_args = search_args

        beth.value_heuristic = value_heuristic
        beth.rank_heuristic = rank_heuristic

        beth.board = board
        beth.white = white
        beth._board = deepcopy(board)

        beth.n_leafes = 0
        beth.n_explored_nodes = 0

        beth.n_quiesce_nodes = 0
        beth.max_quiesce_depth = 0
        # mates, dps = load_3_men_tablebase()
        # beth.tb_3_men_mates = mates
        # beth.tb_3_men_desperate_positions = dps
        #
        # beth.ob = get_queens_gambit()

        return beth
    end
end

function (beth::Beth)(board::Board, white::Bool)
    # if haskey(beth.ob, board)
    #     @info("Position known.")
    #     return beth.ob[board]
    # end

    value, move = beth.search_algorithm(beth, board=board, white=white)
    println(@sprintf "Computer says: %s valued with %.2f." move value/100)
    return move
end


include("../puzzles/puzzle.jl")
include("../puzzles/puzzle_rush_20_12_13.jl")
include("../puzzles/puzzle_rush_20_12_30.jl")
include("../puzzles/puzzle_rush_20_12_31.jl")


println("13=========")
for (i, pz) in enumerate(rush_20_12_13)
    println(pz.board)
    println("$i: ", evaluation(pz.board, pz.white_to_move))
end
println("30=========")
for (i, pz) in enumerate(rush_20_12_30)
    println(pz.board)
    println("$i: ", evaluation(pz.board, pz.white_to_move))
end
println("31==========")
for (i, pz) in enumerate(rush_20_12_31)
    println(pz.board)
    println("$i: ", evaluation(pz.board, pz.white_to_move))
end
