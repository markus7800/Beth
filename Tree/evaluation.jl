

function simple_piece_count(board::Board, white::Bool)
    player = 7 + !white
    opponent = 7 + white

    white_score = 0.
    black_score = 0.

    king_pos = (0, 0)
    for rank in 1:8, file in 1:8
        if board[rank,file,KING] && board[rank,file,player]
            king_pos = (rank, file)
        end
        if board[rank,file,WHITE]
            white_score += board[rank,file,PAWN] * 1 + (board[rank,file,KNIGHT] + board[rank,file,BISHOP]) * 3 + board[rank,file,ROOK] * 5 + board[rank,file,QUEEN] * 9
        elseif board[rank,file,BLACK]
            black_score += board[rank,file,PAWN] * 1 + (board[rank,file,KNIGHT] + board[rank,file,BISHOP]) * 3 + board[rank,file,ROOK] * 5 + board[rank,file,QUEEN] * 9
        end
    end
    score = white_score - black_score

    check = is_attacked(board, player, opponent, king_pos)
    ms = get_moves(board, white)

    if length(ms) == 0
        if check
            # checkmate
            score = white ? -1000 : 1000
        else
            # stalemate
            score = 0.
        end
    end

    return score, ms
end

# just a preranking is discarded after evaluation
# imposes an order of expansion of children
function rank_moves(board::Board, white::Bool, ms::Vector{Move})
    # Checks, captures, attacks ...
    check = 30
    captures = 1
    attacks = 0.3
    defends = 0.1

    player = 7 + !white
    opponent = 7 + white

    ranked_moves = Vector{Tuple{Float64, Move}}(undef, length(ms))
    for (j, m) in enumerate(ms)
        score = 0.
        p = m[1]
        r2, f2 = cartesian(field(m[3]))
        if board[r2, f2, opponent]
            # capture
            score += captures * (board[r2,f2,PAWN] * 1 + (board[r2,f2,KNIGHT] + board[r2,f2,BISHOP]) * 3 + board[r2,f2,ROOK] * 5 + board[r2,f2,QUEEN] * 9)
        end

        # look at next moves

        max_multiple = 0
        dirs = []
        if p == PAWN
            max_multiple = 1; dirs = PAWNDIAG[1+white]
        elseif p == KNIGHT
            max_multiple = 1; dirs = KNIGHTMOVES
        elseif p == BISHOP
            max_multiple = 8; dirs = DIAG
        elseif p == ROOK
            max_multiple = 8; dirs = CROSS
        elseif p == QUEEN
            max_multiple = 8; dirs = DIAGCROSS
        elseif p == KING
            max_multiple = 1; dirs = DIAGCROSS
        elseif p == PAWNTOQUEEN
            score += 9 # promotion
            max_multiple = 8; dirs = DIAGCROSS
        elseif p == PAWNTOKNIGHT
            score += 3 # promotion
            max_multiple = 1; dirs = KNIGHTMOVES
        end

        for dir in dirs
            for i in 1:max_multiple
                r3, f3 = (r2, f2) .+ i .* dir

                if r3 < 1 || r3 > 8 || f3 < 1 || f3 > 8
                    # direction out of bounds
                    break # direction finished
                end

                if board[r3, f3, opponent]
                    if board[r3, f3, KING]
                        # check
                        score += check
                    else
                        # attack
                        # TODO: maybe remove
                        # score += attacks * (board[r3,f3,PAWN] * 1 + (board[r3,f3,KNIGHT] + board[r3,f3,BISHOP]) * 3 + board[r3,f3,ROOK] * 5 + board[r3,f3,QUEEN] * 9)
                    end
                    break # direction finished
                elseif board[r3, f3, player]
                    # defend
                    if !(r3 == r2 && f3 == f3)
                        # cant defend self
                        # score += defends * (board[r3,f3,PAWN] * 1 + (board[r3,f3,KNIGHT] + board[r3,f3,BISHOP]) * 3 + board[r3,f3,ROOK] * 5 + board[r3,f3,QUEEN] * 9)
                        break # direction finished
                    end
                end # else empty field
            end
        end

        if !white
            score *= -1
        end

        ranked_moves[j] = (score, m)
    end

    return ranked_moves
end
