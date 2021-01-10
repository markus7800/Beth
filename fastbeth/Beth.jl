include("../fastchess/chess.jl")
include("evaluation.jl")

import Base.Iterators.Pairs

mutable struct Beth
    search_algorithm::Function
    search_args::Vector{Pair{Symbol,Any}}

    value_heuristic::Function
    rank_heuristic::Function

    board::Board # board capturing current position, playing starts here
    white::Bool # current next player to move
    _board::Board # board used for playing in tree search, reset to board

    n_leafes::Int
    n_explored_nodes::Int

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

        # mates, dps = load_3_men_tablebase()
        # beth.tb_3_men_mates = mates
        # beth.tb_3_men_desperate_positions = dps
        #
        # beth.ob = get_queens_gambit()

        return beth
    end
end

#
# function restore_board_position(beth::Beth, node::ABNode)
#     restore_board_position(beth.board, beth.white, beth._board, node)
# end
