
function short_to_long(board::Board, white::Bool, s::String)
    ms = get_moves(board, white)
    if s == "O-O"
        if white
            piece_moves = filter(m->m.from_piece==KING && m.to == tonumber(Field("g1")), ms)
            @assert length(piece_moves) > 0 "No moves!"
            return Move(KING, Field("e1"), Field("g1"))
        else
            piece_moves = filter(m->m.from_piece==KING && m.to == tonumber(Field("g8")), ms)
            @assert length(piece_moves) > 0 "No moves!"
            return Move(KING, Field("e8"), Field("g8"))
        end
    end
    if s == "O-O-O"
        if white
            piece_moves = filter(m->m.from_piece==KING && m.to == tonumber(Field("c1")), ms)
            @assert length(piece_moves) > 0 "No moves!"
            return Move(KING, Field("e1"), Field("c1"))
        else
            piece_moves = filter(m->m.from_piece==KING && m.to == tonumber(Field("c8")), ms)
            @assert length(piece_moves) > 0 "No moves!"
            return Move(KING, Field("e8"), Field("c8"))
        end
    end

    s = replace(s, "x" => "") # remove captures
    s = replace(s, "+" => "") # remove check
    s = replace(s, "=" => "") # remove promotion

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
    @assert length(piece_moves) > 0 ("No moves!", piece, f, to_piece)

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
            # println("Move unique because rank and file given.")
            # rank and file given
            filtered_moves = filter(m -> tostring(m.from) == id, piece_moves)
            @assert length(filtered_moves) == 1
            return filtered_moves[1]
        end
    end
end
