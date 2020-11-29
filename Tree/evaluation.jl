

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

    check = is_check(board, player, opponent, king_pos)
    ms = get_moves(board, white)

    if length(ms) == 0
        if check
            # checkmate
            score = white ? -Inf : + Inf
        else
            # stalemate
            score = 0.
        end
    end

    return score, ms
end

# simple_piece_count(Board(), true)
#
# board = Board()
# move!(board, true, 'P', "e2", "e4")
# move!(board, false, 'P', "e7", "e5")
# move!(board, true, 'B', "f1", "c4")
# move!(board, false, 'P', "d7", "d6")
# move!(board, true, 'Q', "d1", "f3")
# move!(board, false, 'N', "b8", "c6")
# move!(board, true, 'Q', "f3", "f7")
# simple_piece_count(board, false)
