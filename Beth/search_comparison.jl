include("Beth.jl")

# QUIESCE

pz = rush_20_12_13[9]
print_puzzle(pz)

beth = Beth(
    value_heuristic=evaluation,
    rank_heuristic=rank_moves_by_eval,
    search_algorithm=AlphaBeta_Search,
    search_args=Dict(
        "depth" => 6,
        "do_quiesce" => false,
        "verbose" => true
    ))

beth(pz.board, pz.white_to_move)

beth = Beth(
    value_heuristic=evaluation,
    rank_heuristic=rank_moves_by_eval,
    search_algorithm=AlphaBeta_Search,
    search_args=Dict(
        "depth" => 6,
        "do_quiesce" => true,
        "verbose" => true
    ))

beth(pz.board, pz.white_to_move)


# BENCHMARKS
using BenchmarkTools

# 872_389_934
# 27.908 s (92130592 allocations: 154.81 GiB)
@btime perft(pz.board, pz.white_to_move, 6)

# 7.694 s (41859037 allocations: 1.25 GiB)
@btime perft_mem(pz.board, pz.white_to_move, 6)

# 873_377_600
count_nodes(pz.board, pz.white_to_move, 6)

# ALPHA BETA PRUNING

beth = Beth(
    value_heuristic=evaluation,
    rank_heuristic=rank_moves_by_eval,
    search_algorithm=AlphaBeta_Search,
    search_args=Dict(
        "depth" => 6,
        "do_quiesce" => true,
        "quiesce_depth" => 50
    ))

beth(pz.board, pz.white_to_move)
beth.n_explored_nodes # 832634

# 1.092 s (8812924 allocations: 402.12 MiB)
@btime beth(pz.board, pz.white_to_move)

beth = Beth(
    value_heuristic=evaluation,
    rank_heuristic=rank_moves_by_eval,
    search_algorithm=MTDF_Search,
    search_args=Dict(
        "depth" => 6,
        "do_quiesce" => true,
        "quiesce_depth" => 50
    ))

beth(pz.board, pz.white_to_move)
beth.n_explored_nodes # 658447

# 850.846 ms (7057015 allocations: 316.94 MiB)
@btime beth(pz.board, pz.white_to_move)

beth = Beth(
    value_heuristic=evaluation,
    rank_heuristic=rank_moves_by_eval,
    search_algorithm=IterativeMTDF,
    search_args=Dict(
        "max_depth" => 6,
        "do_quiesce" => true,
        "quiesce_depth" => 50
    ))

beth(pz.board, pz.white_to_move)
beth.n_explored_nodes # 518774

# 626.393 ms (5396779 allocations: 231.70 MiB)
@btime beth(pz.board, pz.white_to_move)
