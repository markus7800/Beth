
function short_to_long(board::Board, white::Bool, s::String)
    ms = get_moves(board, white)
    if s == "O-O"
        piece_moves = filter(m->m.from_piece==KING && m.to ==Field("g1"), ms)
        @assert length(piece_moves) > 0 "No moves!"
        return Move(KING, Field("e1"), Field("g1"))
    end
    if s == "O-O-O"
        piece_moves = filter(m->m.from_piece==KING && m.to == Field("c1"), ms)
        @assert length(piece_moves) > 0 "No moves!"
        return Move(KING, Field("e1"), Field("c1"))
    end

    s = replace(s, "x" => "") # remove captures
    s = replace(s, "+" => "") # remove check

    # handle pawn
    if islowercase(s[1])
        s = 'P' * s
    end

    p = s[1]
    @assert p in PIECES.keys "Invalid piece!"
    piece = PIECES[p]
    to_piece = piece

    # handle promotion
    if s[end] in PIECES.keys && s[1] == 'P'
        to_piece = PIECES[s[end]]
        s = s[1:end-1]
    end


    s = s[2:end]

    # println("Piece: $p")

    f = s[end-1:end] # field
    # println(f)
    piece_moves = filter(m->m.from_piece==piece && m.to == tonumber(Field(f)) && m.to_piece == to_piece, ms)
    # println(piece_moves)
    @assert length(piece_moves) > 0 "No moves!"

    if length(s) == 2
        # println("Move unique because of target tile.")
        @assert length(piece_moves) == 1 "Not unique move!"
        return piece_moves[1]
    else
        id = s[1:end-2]
        if length(id) == 1
            x = Int(id[1])
            if x ≥ 96
                # println("Move unique because file given.")
                # file given
                file = x - 96
                filtered_moves = filter(m -> rankfile(m.from)[2] == file, piece_moves)
                @assert length(filtered_moves) == 1 "Not unique move!"
                return filtered_moves[1]
            else
                # println("Move unique because rank given.")
                # rank given
                rank = x - 48
                filtered_moves = filter(m -> rankfile(m.from)[1] == rank, piece_moves)
                @assert length(filtered_moves) == 1 "Not unique move!"
                return filtered_moves[1]
            end
        else
            @assert length(id) == 2
            println("Move unique because rank and file given.")
            # rank and file given
            filtered_moves = filter(m -> tostring(m.from) == id, piece_moves)
            @assert length(filtered_moves) == 1
            return filtered_moves[1]
        end
    end
end


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
    return m
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
    try
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
            if length(game_history) ≥ 3
                for ply in game_history
                    board_rep = 0
                    for ply´ in game_history
                        if ply.board == ply´.board
                            board_rep += 1
                        end
                    end
                    if board_rep ≥ 3
                        done = true
                        println("Draw by repetition!")
                        break
                    end
                end
            end

            m = ""

            v,move_time, = @timed if !done
                if white
                    m = white_player(board, true)
                else
                    m = black_player(board, false)
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

            n_ply += 1
        end
    catch e
        if e isa InterruptException
            return
        end
        println(e)
    end
    return game_history
end
