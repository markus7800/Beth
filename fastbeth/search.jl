
function get_capture_moves(board::Board, white::Bool, ms::MoveList)::Vector{Tuple{Int, Move}}
    mult = white ? 1 : -1

    ranked_captures = Vector{Tuple{Int, Move}}()
    for m in ms
        p = get_piece(board, tofield(m.to))

        if p != NO_PIECE # capture
            push!(ranked_captures, (PIECE_VALUES[p] * mult, m))
        end
    end

    return ranked_captures
end

function first_lt(x,y)
    x[1] < y[1]
end

# alpha beta search with only capture move and no caching and unlimited depth
function quiesce(beth::Beth, α::Int, β::Int, white::Bool)::Int
    beth.n_explored_nodes += 1
    # if beth.n_explored_nodes > 100
    #     return 0
    # end

    ms = get_moves(beth._board, white)
    capture_moves = get_capture_moves(beth._board, white, ms)
    sort!(capture_moves, rev=white, lt=first_lt)
    # println(beth.n_explored_nodes, ": ", capture_moves)


    # board_value, is_3_men = tb_3_men_lookup(beth.tb_3_men_mates, beth.tb_3_men_desperate_positions, beth._board, white)
    # if !is_3_men
    #     board_value = beth.value_heuristic(beth._board, white)
    # end
    board_value = beth.value_heuristic(beth._board, white)

    if length(capture_moves) == 0
        beth.n_leafes += 1
        return board_value
    else
        if white
            value = MIN_VALUE
            for (prescore, m) in capture_moves
                undo = make_move!(beth._board, white, m)
                value = max(value, quiesce(beth, α, β, !white))
                undo_move!(beth._board, white, m, undo)
                α = max(α, value)
                # α ≥ β && break # β cutoff
            end
            # if you dont take max here only the board values where the player
            # are forced to make all capture moves are taken into account
            final_value = max(value, board_value)
            return final_value
        else
            value = MAX_VALUE
            for (prescore, m) in capture_moves
                undo = make_move!(beth._board, white, m)
                value = min(value, quiesce(beth, α, β, !white))
                undo_move!(beth._board, white, m, undo)
                β = min(β, value)
                # β ≤ α && break # α cutoff
            end
            # if you dont take min here only the board values where the player
            # are forced to make all capture moves are taken into account
            final_value = min(value, board_value)
            return final_value
        end
    end
end

function perft_capture(board::Board, white::Bool, depth::Int)
    ms = get_moves(board, white)
    ms = get_capture_moves(board, white, ms)
    #println(ms)
    if depth == 1
        return length(ms)
    else
        nodes = 0
        for (i, m) in ms
            undo = make_move!(board, white, m)
            nodes += perft_capture(board, !white, depth-1) + 1
            undo_move!(board, white, m, undo)
        end
        return nodes
    end
end


board = Board("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")

board = Board("6k1/1p4bp/3p4/1q1P1pN1/1r2p3/4B2P/r4PP1/3Q1RK1 w - - 0 1")

board = Board("r2qkbnr/ppp2ppp/2n1p1b1/3p4/4PP2/3P1N2/PPPN2PP/R1BQKB1R w KQkq - 0 1")

beth = Beth(board=board, white=true, search_algorithm=()->nothing,
    value_heuristic=evaluation, rank_heuristic=rank_moves_by_eval)

quiesce(beth, MIN_VALUE, MAX_VALUE, true)

beth.n_leafes

beth.n_explored_nodes


perft_capture(board, true, 5)

perft(board, true, 5)

import Chess
function my_perftinternal_cap(b::Chess.Board, depth::Int, ply::Int)
    _movelist = Chess.moves(b)
    occ = Chess.occupiedsquares(b)

    movelist = []
    for m in _movelist
        if Chess.to(m) in occ
            push!(movelist, m)
        end
    end

    # println(movelist)

    if depth == 1
        return length(movelist)
    else
        result = 0
        for m ∈ movelist
            u = Chess.domove!(b, m)
            result += my_perftinternal_cap(b, depth - 1, ply + 1) + 1
            Chess.undomove!(b, u)
        end
        result
    end
end

function my_perft_cap(b::Chess.Board, depth::Int)::Int
    if depth == 0
        1
    else
        my_perftinternal_cap(b, depth, 0)
    end
end

cboard = Chess.fromfen("r2qkbnr/ppp2ppp/2n1p1b1/3p4/4PP2/3P1N2/PPPN2PP/R1BQKB1R w KQkq - 0 1")

my_perft_cap(cboard, 1000)

perft_capture(board, true, 1000)
