
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
