
include("../Beth/Beth.jl")
include("../puzzles/puzzle.jl")

board = Board("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")

# board = Board("6k1/1p4bp/3p4/1q1P1pN1/1r2p3/4B2P/r4PP1/3Q1RK1 w - - 0 1")
# board = Board("r2qkbnr/ppp2ppp/2n1p1b1/3p4/4PP2/3P1N2/PPPN2PP/R1BQKB1R w KQkq - 0 1")

board = Board("r2qkb1r/1Q3pp1/pN1p3p/3P1P2/3pP3/4n3/PP4PP/1R3RK1 w - -")

@time perft(board, true, 6)
@time count_nodes(board, true, 6) - 1
@time perft_mem(board, true, 6)

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

play_puzzle(pz, beth)

@time beth(board, true)

beth = Beth(
    value_heuristic=evaluation,
    rank_heuristic=rank_moves_by_eval,
    search_algorithm=MTDF_Search,
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
        "time" => 5
    ))

@time beth(pz.board, pz.white_to_move)

puzzle_rush(rush_20_12_31, beth, print_solution=true)
puzzle_rush(rush_21_02_02, beth, print_solution=true)

play_puzzle(rush_20_12_31[13], beth)


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

board = Board()
set_piece!(board, Field("e2"), true, PAWN)
set_piece!(board, Field("d3"), true, KING)
set_piece!(board, Field("e5"), false, KING)
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

beth(board, true)

history = play_game(board, true, black_player=beth, white_player=beth)

function print_fens(history)
    out = ""
    for (i,ply) in enumerate(history)
        n_move = (i-1) ÷ 2 + 1
        out *= string("'" ,FEN(ply.board, ply.white, n_move), "'")
        if i < length(history)
            out *= ",\n"
        end
    end
    println(out)
end


# TODO:
# quiesce lt function
# browser frontend
# faster AlphaBeta with less memory (only save best move)
# blog entry
# null move pruning
# razoring
# todos scathered throughout repo
# play forced moves immediately
# penalize early king move to "safety", maybe assert development first
# full opening book?
# pawn endgame tablebase to avaid wrong simplifications
# fast principal variation search instead of alphabeta
# faster move order
# last position eval used in next guess
# keep search tree throughout game
# fix move by rep blunders
# improve quiesce: rethink not forcing captures
# move white into board

board = Board("3Q4/3b1p1k/3b4/8/8/1Pq1PN2/P4PrP/1K5R w - - 0 37")
board = Board("8/3b1pk1/3b4/8/7Q/1Pq1PN2/P4PrP/1K5R w - - 2 38")
board = Board("8/3b1pk1/3b4/8/3Q4/1Pq1PN2/P4PrP/1K5R b - - 3 38")

beth(board, true)


board = Board("r3k1r1/5b2/2pQqb1p/p1B2p2/P3p3/5B2/5PPP/3RR1K1 w - - 0 1")

beth = Beth(
    value_heuristic=evaluation,
    rank_heuristic=rank_moves_by_eval,
    search_algorithm=IterativeMTDF,
    search_args=Dict(
        "max_depth" => 20,
        "do_quiesce" => false,
        "verbose" => 3
    ))

beth(board, true)
