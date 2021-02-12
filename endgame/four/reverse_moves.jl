function NoUndo()
    Undo(0, 0, 0, 0, 0)
end


# checks if opponent would be in check if player undid move
function would_be_check(board::Board, white::Bool, move::Move)
    undo_move!(board, white, move, NoUndo())

    b = is_in_check(board, !white)

    make_move!(board, white, move)

    return b
end

function get_reverse_moves(board::Board, white::Bool; promotions=false)
    movelist = Move[]

    if is_in_check(board, white)
        # cant do move that leads to being in check
        return movelist
    end

    player = white ? board.whites : board.blacks
    opponent = white ? board.blacks : board.whites
    occupied = player | opponent

    get_rev_pawn_moves!(board, white, player, movelist)
    get_rev_knight_moves!(board, player, occupied, movelist)
    get_rev_bishop_moves!(board, player, occupied, movelist)
    get_rev_rook_moves!(board, player, occupied, movelist)
    get_rev_queen_moves!(board, white, player, occupied, promotions, movelist)
    get_rev_king_moves!(board, white, player, opponent, occupied, movelist)

    # opponent king can not have been in check when player was to move
    filter!(m -> !would_be_check(board, white, m), movelist)

    return movelist
end

function get_pseudo_reverse_capture_moves(board::Board, white::Bool; promotions=false)
    movelist = Move[]

    if is_in_check(board, white)
        # cant do move that leads to being in check
        return movelist
    end

    player = white ? board.whites : board.blacks
    opponent = white ? board.blacks : board.whites
    occupied = player | opponent

    get_rev_pawn_capture_moves!(board, white, player, movelist)
    get_rev_knight_moves!(board, player, occupied, movelist)
    get_rev_bishop_moves!(board, player, occupied, movelist)
    get_rev_rook_moves!(board, player, occupied, movelist)
    get_rev_queen_capture_moves!(board, white, player, occupied, promotions, movelist)
    get_rev_king_moves!(board, white, player, opponent, occupied, movelist)

    return movelist
end

function get_rev_pawn_moves!(board::Board, white::Bool, player::Fields, movelist::Vector{Move})
    for field_number in board.pawns & player
        rank, file = rankfile(field_number)
        if white
            if rank > 2 && !is_occupied(board, Field(rank-1, file))
                push!(movelist, Move(PAWN, Field(rank-1, file), Field(rank, file)))
            end
            if rank == 4 && !is_occupied(board, Field(rank-2, file)) && !is_occupied(board, Field(rank-1, file))
                push!(movelist, Move(PAWN, Field(rank-2, file), Field(rank, file)))
            end
        else
            if rank < 7 && !is_occupied(board, Field(rank+1, file))
                push!(movelist, Move(PAWN, Field(rank+1, file), Field(rank, file)))
            end
            if rank == 5 && !is_occupied(board, Field(rank+2, file)) && !is_occupied(board, Field(rank+1, file))
                push!(movelist, Move(PAWN, Field(rank+2, file), Field(rank, file)))
            end
        end
    end
end

function get_rev_pawn_capture_moves!(board::Board, white::Bool, player::Fields, movelist::Vector{Move})
    for field_number in board.pawns & player
        rank, file = rankfile(field_number)
        if white
            if rank > 2 && file-1 ≥ 1 && !is_occupied(board, Field(rank-1, file-1))
                push!(movelist, Move(PAWN, Field(rank-1, file-1), Field(rank, file)))
            end
            if rank > 2 && file+1 ≤ 8 && !is_occupied(board, Field(rank-1, file+1))
                push!(movelist, Move(PAWN, Field(rank-1, file+1), Field(rank, file)))
            end
        else
            if rank < 7 && file-1 ≥ 1 && !is_occupied(board, Field(rank+1, file-1))
                push!(movelist, Move(PAWN, Field(rank+1, file-1), Field(rank, file)))
            end
            if rank < 7 && file+1 ≤ 8 && !is_occupied(board, Field(rank+1, file+1))
                push!(movelist, Move(PAWN, Field(rank+1, file+1), Field(rank, file)))
            end
        end
    end
end

function get_rev_knight_moves!(board::Board, player::Fields, occupied::Fields, movelist::Vector{Move})
    for field_number in board.knights & player
        moves = knight_move_empty(field_number)
        moves &= ~occupied
        for n in moves
            push!(movelist, Move(KNIGHT, n, field_number))
        end
        # print_fields(moves)
    end
end

function get_rev_bishop_moves!(board::Board, player::Fields, occupied::Fields, movelist::Vector{Move})
    for field_number in board.bishops & player
        moves = bishop_move_empty(field_number)
        occupied_moves = moves & occupied
        for n in occupied_moves
            moves &= ~shadow(field_number, n) # remove fields behind closest pieces
        end
        moves &= ~occupied
        # print_fields(moves)

        for n in moves
            push!(movelist, Move(BISHOP, n, field_number))
        end

    end
end

function get_rev_rook_moves!(board::Board, player::Fields, occupied::Fields, movelist::Vector{Move})
    for field_number in board.rooks & player
        moves = rook_move_empty(field_number)
        occupied_moves = moves & occupied
        for n in occupied_moves
            moves &= ~shadow(field_number, n) # remove fields behind closest pieces
        end
        moves &= ~occupied
        # print_fields(moves)

        for n in moves
            push!(movelist, Move(ROOK, n, field_number))
        end
    end
end

function get_rev_queen_moves!(board::Board, white::Bool, player::Fields, occupied::Fields, promotions::Bool, movelist::Vector{Move})
    for field_number in board.queens & player
        moves = queen_move_empty(field_number)
        occupied_moves = moves & occupied
        for n in occupied_moves
            moves &= ~shadow(field_number, n) # remove fields behind closest pieces
        end
        moves &= ~occupied
        # print_fields(moves)

        for n in moves
            push!(movelist, Move(QUEEN, n, field_number))
        end
        if promotions
            field = tofield(field_number)
            promote = white ? (field & RANK_8 > 0) : (field & RANK_1 > 0)
            if promote
                rank, file = rankfile(field_number)
                if white
                    if rank == 8 && !is_occupied(board, Field(rank-1, file))
                        push!(movelist, Move(PAWN, Field(rank-1, file), Field(rank, file), QUEEN))
                    end
                else
                    if rank == 1 && !is_occupied(board, Field(rank+1, file))
                        push!(movelist, Move(PAWN, Field(rank+1, file), Field(rank, file), QUEEN))
                    end
                end
            end
        end
    end
end

function get_rev_queen_capture_moves!(board::Board, white::Bool, player::Fields, occupied::Fields, promotions::Bool, movelist::Vector{Move})
    for field_number in board.queens & player
        moves = queen_move_empty(field_number)
        occupied_moves = moves & occupied
        for n in occupied_moves
            moves &= ~shadow(field_number, n) # remove fields behind closest pieces
        end
        moves &= ~occupied
        # print_fields(moves)

        for n in moves
            push!(movelist, Move(QUEEN, n, field_number))
        end
        if promotions
            field = tofield(field_number)
            promote = white ? (field & RANK_8 > 0) : (field & RANK_1 > 0)
            if promote
                rank, file = rankfile(field_number)
                if white
                    if rank > 2 && file-1 ≥ 1 && !is_occupied(board, Field(rank-1, file-1))
                        push!(movelist, Move(PAWN, Field(rank-1, file-1), Field(rank, file), QUEEN))
                    end
                    if rank > 2 && file+1 ≤ 8 && !is_occupied(board, Field(rank-1, file+1))
                        push!(movelist, Move(PAWN, Field(rank-1, file+1), Field(rank, file), QUEEN))
                    end
                else
                    if rank < 7 && file-1 ≥ 1 && !is_occupied(board, Field(rank+1, file-1))
                        push!(movelist, Move(PAWN, Field(rank+1, file-1), Field(rank, file), QUEEN))
                    end
                    if rank < 7 && file+1 ≤ 8 && !is_occupied(board, Field(rank+1, file+1))
                        push!(movelist, Move(PAWN, Field(rank+1, file+1), Field(rank, file), QUEEN))
                    end
                end
            end
        end
    end
end

function get_rev_king_moves!(board::Board, white::Bool, player::Fields, opponent::Fields, occupied::Fields, movelist::Vector{Move})
    king_field = board.kings & player
    king_field_number = tonumber(king_field)
    moves = king_move_empty(king_field_number) & ~occupied

    for n in moves
        # move back in check is allowed (but no check from oppponent king)
        if !is_attacked(board, white, player, opponent & board.kings, occupied, n)
            push!(movelist, Move(KING, n, king_field_number))
        end
    end
end
