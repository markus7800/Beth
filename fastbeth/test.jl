

board = Board("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")

# board = Board("6k1/1p4bp/3p4/1q1P1pN1/1r2p3/4B2P/r4PP1/3Q1RK1 w - - 0 1")
# board = Board("r2qkbnr/ppp2ppp/2n1p1b1/3p4/4PP2/3P1N2/PPPN2PP/R1BQKB1R w KQkq - 0 1")


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


@time beth(board, true)


pz = rush_20_12_13[9]
print_puzzle(pz)

beth = Beth(
    value_heuristic=evaluation,
    rank_heuristic=rank_moves_by_eval,
    search_algorithm=AlphaBeta_Search,
    search_args=Dict(
        "depth" => 6,
        "do_quiesce" => true,
        "quiesce_depth" => 50,
        "verbose" => true
    ))

@time beth(pz.board, pz.white_to_move)

beth = Beth(
    value_heuristic=evaluation,
    rank_heuristic=rank_moves_by_eval,
    search_algorithm=MTDF_Search,
    search_args=Dict(
        "depth" => 6,
        "do_quiesce" => true,
        "quiesce_depth" => 50,
        "verbose" => true
    ))

@time beth(pz.board, pz.white_to_move)

beth = Beth(
    value_heuristic=evaluation,
    rank_heuristic=rank_moves_by_eval,
    search_algorithm=IterativeMTDF,
    search_args=Dict(
        "max_depth" => 6,
        "do_quiesce" => true,
        "quiesce_depth" => 50,
        "verbose" => 2
    ))

@time beth(pz.board, pz.white_to_move)

beth = Beth(
    value_heuristic=evaluation,
    rank_heuristic=rank_moves_by_eval,
    search_algorithm=IterativeMTDF,
    search_args=Dict(
        "max_depth" => 20,
        "do_quiesce" => true,
        "quiesce_depth" => 50,
        "verbose" => 1,
        "time" => 1
    ))

@time beth(pz.board, pz.white_to_move)

puzzle_rush(rush_20_12_31, beth, print_solution=true)

play_game(black_player=user_input, white_player=beth)

board = Board()
set_piece!(board, Field("e2"), true, PAWN)
set_piece!(board, Field("e3"), true, KING)
set_piece!(board, Field("e5"), false, KING)
print_board(board)

key_3_men(board, true)
key_3_men(board, false)

tb_3_men_lookup(beth.tb_3_men_mates, beth.tb_3_men_desperate_positions, board, true)
tb_3_men_lookup(beth.tb_3_men_mates, beth.tb_3_men_desperate_positions, board, false)

board = Board()
set_piece!(board, Field("e7"), false, PAWN)
set_piece!(board, Field("e6"), false, KING)
set_piece!(board, Field("e4"), true, KING)
print_board(board)

key_3_men(board, true)
key_3_men(board, false)

tb_3_men_lookup(beth.tb_3_men_mates, beth.tb_3_men_desperate_positions, board, true)
tb_3_men_lookup(beth.tb_3_men_mates, beth.tb_3_men_desperate_positions, board, false)

beth = Beth(
    value_heuristic=evaluation,
    rank_heuristic=rank_moves_by_eval,
    search_algorithm=AlphaBeta_Search,
    search_args=Dict(
        "depth" => 6,
        "do_quiesce" => true,
        "quiesce_depth" => 50,
        "verbose" => true
    ))

beth(board, true)

play_game(board, true, black_player=beth, white_player=beth)
