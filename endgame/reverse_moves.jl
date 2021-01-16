function NoUndo()
    Undo(0, 0, 0, 0, 0)
end

function chebyshev_distance(f1::Int, rank, file)
    c1 = rankfile(f1)
    return max(abs(c1[1] - rank), abs(c1[2] - file))
end

# checks if opponent would be in check if player undid move
function would_be_check(board::Board, white::Bool, move::Move)
    undo_move!(board, white, move, NoUndo())

    b = is_in_check(board, !white)

    make_move!(board, white, move)

    return b
end

const revDIAG = [(-1,-1), (1,-1), (-1, 1), (1, 1)]
const revCROSS = [(0,1), (0,-1), (1,0), (-1,0)]
const revKNIGHTMOVES = [
        (1,2), (1,-2), (-1,2), (-1,-2),
        (2,1), (2,-1), (-2,1), (-2,-1)
        ]
const revDIAGCROSS = vcat(revDIAG, revCROSS)

function reverse_direction_moves(board, piece, rank, file, directions, max_multiple)
    moves = Move[]
    for dir in directions
        for i in 1:max_multiple

            r2, f2 = (rank, file) .+ i .* dir

            if r2 < 1 || r2 > 8 || f2 < 1 || f2 > 8
                # direction out of bounds
                break # direction finished
            end

            if !is_occupied(board, Field(r2, f2))
                # free tile
                push!(moves, Move(piece, Field(r2, f2), Field(rank, file)))
            else
                # direction blocked by own piece or opponent piece
                break # direction finished
            end
        end
    end
    return moves
end

function king_pos(board::Board, white::Bool)
    if white
        return rankfile(board.kings & board.whites)
    else
        return rankfile(board.kings & board.blacks)
    end
end

function get_reverse_moves(board::Board, white::Bool; promotions=false)
    moves = Move[]
    king_moves = Move[]

    if is_in_check(board, white)
        # cant do move that leads to being in check
        return moves
    end

    for rank in 1:8, file in 1:8
        piece = get_piece(board, Field(rank, file), white)

        piece == NO_PIECE && continue

        if piece == PAWN
            if white
                if rank > 2 && !is_occupied(board, Field(rank-1, file))
                    push!(moves, Move(PAWN, Field(rank-1, file), Field(rank, file)))
                end
                if rank == 4 && !is_occupied(board, Field(rank-2, file)) && !is_occupied(board, Field(rank-1, file))
                    push!(moves, Move(PAWN, Field(rank-2, file), Field(rank, file)))
                end
            else
                if rank < 7 && !is_occupied(board, Field(rank+1, file))
                    push!(moves, Move(PAWN, Field(rank+1, file), Field(rank, file)))
                end
                if rank == 5 && !is_occupied(board, Field(rank+2, file)) && !is_occupied(board, Field(rank+1, file))
                    push!(moves, Move(PAWN, Field(rank+2, file), Field(rank, file)))
                end
            end
        elseif piece == BISHOP
            append!(moves, reverse_direction_moves(board,BISHOP,rank,file,revDIAG,8))

        elseif piece == KNIGHT
            append!(moves, reverse_direction_moves(board,KNIGHT,rank,file,revKNIGHTMOVES,1))

        elseif piece == ROOK
            append!(moves, reverse_direction_moves(board,ROOK,rank,file,revCROSS,8))

        elseif piece == QUEEN
            append!(moves, reverse_direction_moves(board,QUEEN,rank,file,revDIAGCROSS,8))
            if promotions
                if white
                    if rank == 8 && !is_occupied(board, Field(rank-1, file))
                        push!(moves, Move(PAWN, Field(rank-1, file), Field(rank, file), QUEEN))
                    end
                else
                    if rank == 1 && !is_occupied(board, Field(rank+1, file))
                        push!(moves, Move(PAWN, Field(rank+1, file), Field(rank, file), QUEEN))
                    end
                end
            end
        elseif piece == KING
            king_moves = reverse_direction_moves(board,KING,rank,file,revDIAGCROSS,1)
        end
    end
    opponent_kingpos = king_pos(board, !white)
    filter!(m -> chebyshev_distance(m.from, opponent_kingpos...) > 1, king_moves)

    append!(moves, king_moves)

    # opponent king can not have been in check when player was to move
    filter!(m -> !would_be_check(board, white, m), moves)

    return moves
end
