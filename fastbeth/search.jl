

function cap_lt(m1::Move, m2::Move)
    p1 = get_piece(board, tofield(m1.to))
    p2 = get_piece(board, tofield(m2.to))
    return piece_value(p1) < piece_value(p2)

end

function quiesce(beth::Beth, α::Int, β::Int, white::Bool)::Int
    beth.n_explored_nodes += 1
    # if beth.n_explored_nodes > 100
    #     return 0
    # end

    # ms = get_moves(beth._board, white)
    capture_moves = get_captures(beth._board, white)
    sort!(capture_moves, rev=true, lt=cap_lt)
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
            for m in capture_moves
                undo = make_move!(beth._board, white, m)
                value = max(value, quiesce(beth, α, β, !white))
                undo_move!(beth._board, white, m, undo)
                α = max(α, value)
                α ≥ β && break # β cutoff
            end
            # if you dont take max here only the board values where the player
            # are forced to make all capture moves are taken into account
            final_value = max(value, board_value)
            return final_value
        else
            value = MAX_VALUE
            for m in capture_moves
                undo = make_move!(beth._board, white, m)
                value = min(value, quiesce(beth, α, β, !white))
                undo_move!(beth._board, white, m, undo)
                β = min(β, value)
                β ≤ α && break # α cutoff
            end
            # if you dont take min here only the board values where the player
            # are forced to make all capture moves are taken into account
            final_value = min(value, board_value)
            return final_value
        end
    end
end

# alpha beta search with only capture move and no caching and unlimited depth
function quiesce_mem(beth::Beth, depth::Int, ply::Int, α::Int, β::Int, white::Bool,
        lists::Vector{MoveList}=[MoveList(100) for _ in 1:depth])::Int
        
    beth.n_explored_nodes += 1
    # if beth.n_explored_nodes > 100
    #     return 0
    # end

    capture_moves = lists[ply+1]

    get_captures!(beth._board, white, capture_moves)
    sort!(capture_moves, rev=true, lt=cap_lt)


    # board_value, is_3_men = tb_3_men_lookup(beth.tb_3_men_mates, beth.tb_3_men_desperate_positions, beth._board, white)
    # if !is_3_men
    #     board_value = beth.value_heuristic(beth._board, white)
    # end
    board_value = beth.value_heuristic(beth._board, white)

    if length(capture_moves) == 0 || depth == 0
        beth.n_leafes += 1
        recycle!(capture_moves)
        return board_value
    else
        if white
            value = MIN_VALUE
            for m in capture_moves
                undo = make_move!(beth._board, white, m)
                value = max(value, quiesce_mem(beth, depth-1, ply+1, α, β, !white, lists))
                undo_move!(beth._board, white, m, undo)
                α = max(α, value)
                α ≥ β && break # β cutoff
            end
            recycle!(capture_moves)

            # if you dont take max here only the board values where the player
            # are forced to make all capture moves are taken into account
            final_value = max(value, board_value)
            return final_value
        else
            value = MAX_VALUE
            for m in capture_moves
                undo = make_move!(beth._board, white, m)
                value = min(value, quiesce_mem(beth, depth-1, ply+1, α, β, !white, lists))
                undo_move!(beth._board, white, m, undo)
                β = min(β, value)
                β ≤ α && break # α cutoff
            end
            recycle!(capture_moves)

            # if you dont take min here only the board values where the player
            # are forced to make all capture moves are taken into account
            final_value = min(value, board_value)
            return final_value
        end
    end
end

function perft_capture(board::Board, white::Bool, depth::Int)
    # ms = get_moves(board, white)
    # ms = get_capture_moves(board, white, ms)
    ms = get_captures(board, white)
    #println(ms)
    if depth == 1
        return length(ms)
    else
        nodes = 0
        # for (i, m) in ms
        for m in ms
            undo = make_move!(board, white, m)
            nodes += perft_capture(board, !white, depth-1) + 1
            undo_move!(board, white, m, undo)
        end
        return nodes
    end
end


board = Board("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")

# board = Board("6k1/1p4bp/3p4/1q1P1pN1/1r2p3/4B2P/r4PP1/3Q1RK1 w - - 0 1")
# board = Board("r2qkbnr/ppp2ppp/2n1p1b1/3p4/4PP2/3P1N2/PPPN2PP/R1BQKB1R w KQkq - 0 1")

beth = Beth(board=board, white=true, search_algorithm=()->nothing,
    value_heuristic=evaluation, rank_heuristic=rank_moves_by_eval)

@time quiesce(beth, MIN_VALUE, MAX_VALUE, true)
@time quiesce_mem(beth, 100, 0, MIN_VALUE, MAX_VALUE, true)

beth.n_leafes

# 10802327
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
cboard = Chess.fromfen("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
@btime my_perft_cap($deepcopy(cboard), 8)

board = Board("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")
@btime perft_capture($deepcopy(board), true, 8)
