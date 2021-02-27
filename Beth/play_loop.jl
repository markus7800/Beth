
function user_input(board, white)
    got_move = false
    m = EMPTY_MOVE
    while !got_move
        try
            print(white ? "White: " : "Black: ")
            s = readline()
            if occursin("highlight ", s)
                print_board(board, highlight=s[11:end], white=white)
                println()
                continue
            end
            if occursin("undo", s)
                return "undo"
            end
            if occursin("abort", s)
                return "abort"
            end
            if occursin("resign", s)
                return "resign"
            end

            m = short_to_long(board, white, s)
            got_move = true
        catch e
            if e isa InterruptException
                println("\nGame aborted!")
                return "abort"
            elseif e isa AssertionError
                println(e.msg)
            else
                println(e)
            end
        end
    end
    return m, NaN
end



struct Ply
    nr::Int
    n_move::Int
    board::Board # board after move
    white::Bool # white to move at board
    move # last move that lead to board
    time::Float64
end

import Base.show
using Printf
function Base.show(io::IO, ply::Ply)
    print(io, @sprintf "%d. %s %.2fs (%d)" ply.n_move ply.move ply.time ply.nr)
end

function play_game(board = StartPosition(), white = true; white_player=user_input, black_player=user_input)
    board = deepcopy(board)
    game_history = [Ply(0, 0, deepcopy(board), white, EMPTY_MOVE, 0.)] # current board, white to move, last move
    n_ply = 1

    board_orientation = black_player == user_input && white_player != user_input ? false : true
    # try
    while true
        n_move = (n_ply+1) ÷ 2
        println("\nMove $n_move, Ply $n_ply:")
        #print("\u1b[10F")
        print_board(board, white=board_orientation)
        println()

        n_moves = length(get_moves(board, white))
        check = is_in_check(board, white)
        done = n_moves == 0
        !done && check && println("Check!")
        done && check && println("Checkmate!")
        done && !check && println("Stalemate!")

        piece_count = n_pieces(board, white)
        if piece_count ≤ 3
            if count_pieces(board.queens | board.rooks | board.pawns) == 0
                done = true
                println("Draw!")
            end
        end
        board_rep = 0
        for i in 0:2:board.r50
            if board == history[end-i].board
                board_rep += 1
            end
            if board_rep ≥ 3
                done = true
                println("Draw by repetition!")
                break
            end
        end

        m = ""

        v,move_time, = @timed if !done
            if white
                m, value = white_player(board, true)
            else
                m, value = black_player(board, false)
            end
        end

        if !done && m == "undo"
            pop!(game_history) # opponent move
            pop!(game_history) # my move
            last_ply = game_history[end]
            n_ply -= 2
            board = deepcopy(last_ply.board)
            white = last_ply.white
            continue
        end
        if !done && (m == "abort" || m == "resign")
            break
        end


        done && break

        make_move!(board, white, m)
        white = !white
        push!(game_history, Ply(n_ply, n_move, deepcopy(board), white, m, move_time))

        if white_player isa Beth
            make_move!(white_player, move)
        end
        if black_player isa Beth
            make_move!(black_player, move)
        end

        n_ply += 1
    end
    # catch e
    #     if e isa InterruptException
    #         return
    #     end
    #     println(e)
    #     rethrow(e) # TODO
    # end
    return game_history
end
