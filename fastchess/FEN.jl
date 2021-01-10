
function Board(FEN::String)
    groups = split(FEN, " ")

    # group 1: position
    board = Board()
    for (s, rank) in zip(split(groups[1], "/"), 8:-1:1)
        file = 1
        for c in s
            if isdigit(c)
                file += Int(c) - 48
                continue
            end
            white = isuppercase(c)
            p = PIECES[uppercase(c)]
            set_piece!(board, Field(rank, file), white, p)
            file += 1
        end
    end

    # group 2: right to move
    white_to_move = groups[2] == "w"

    # group 3: castling rights
    board.castle = 0
    if occursin('K', groups[3])
        board.castle |= WHITE_SHORT_CASTLE
    end
    if occursin('Q', groups[3])
        board.castle |= WHITE_LONG_CASTLE
    end
    if occursin('k', groups[3])
        board.castle |= BLACK_SHORT_CASTLE
    end
    if occursin('q', groups[3])
        board.castle |= BLACK_LONG_CASTLE
    end

    # group 4: en passant right
    if groups[4] != "-"
        rank, file = rankfile(Field(string(groups[4])))
        board.en_passant = file
    end

    return board
end


function FEN(board::Board, white::Bool)
    first_group = ""
    count = 0
    for rank in 8:-1:1
        for file in 1:8
            field = Field(rank, file)
            p = get_piece(board, field)
            if p != NO_PIECE
                if count > 0
                    first_group *= string(count)
                    count = 0
                end
                p = PIECE_SYMBOLS[p]
                if board.blacks & field > 0
                    p = lowercase(p)
                end

                first_group *= p
            else
                count += 1
            end
        end
        if  Field(rank, 8) & (board.blacks | board.whites) == 0
            first_group *= string(count)
        end
        count = 0

        if rank != 1
            first_group *= "/"
        end
    end

    second_group = white ? "w" : "b"

    third_group = ""
    if board.castle & WHITE_SHORT_CASTLE > 0
        third_group *= "K"
    end
    if board.castle & WHITE_LONG_CASTLE > 0
        third_group *= "Q"
    end

    if board.castle & BLACK_SHORT_CASTLE > 0
        third_group *= "k"
    end
    if board.castle & BLACK_LONG_CASTLE > 0
        third_group *= "q"
    end

    if third_group == ""
        third_group = "-"
    end

    fourth_group = "-"
    if board.en_passant > 0
        f = Int(board.en_passant)
        r = white ? 6 : 3
        field = Field(r, f)
        if white
            if f - 1 > 0 && (Field(r-1,f-1) & board.pawns & board.whites > 0)
                fourth_group = tostring(field)
            end
            if f + 1 ≤ 8 && (Field(r-1,f+1) & board.pawns & board.whites > 0)
                fourth_group = tostring(field)
            end
        else
            if f - 1 > 0 && (Field(r+1,f-1) & board.pawns & board.blacks > 0)
                fourth_group = tostring(field)
            end
            if f + 1 ≤ 8 && (Field(r+1,f+1) & board.pawns & board.blacks > 0)
                fourth_group = tostring(field)
            end
        end
    end

    return first_group * " " * second_group * " " * third_group * " " * fourth_group * " 0 1"
end
