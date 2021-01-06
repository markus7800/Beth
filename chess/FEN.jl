
function FEN(board::Board, white::Bool)
    first_group = ""
    count = 0
    for rank in 8:-1:1
        for file in 1:8
            if any(board[rank, file, [WHITE, BLACK]])
                if count > 0
                    first_group *= string(count)
                    count = 0
                end
                p = findfirst(board[rank, file, 1:6])
                p = SYMBOLS[1, p]
                if board[rank, file, BLACK]
                    p = lowercase(p)
                end

                first_group *= p
            else
                count += 1
            end
        end
        if !(any(board[rank, 8, [WHITE, BLACK]]))
            first_group *= string(count)
        end
        count = 0

        if rank != 1
            first_group *= "/"
        end
    end

    second_group = white ? "w" : "b"

    third_group = ""
    if board.can_castle[2, SHORTCASTLE]
        third_group *= "K"
    end
    if board.can_castle[2, LONGCASTLE]
        third_group *= "Q"
    end

    if board.can_castle[1, SHORTCASTLE]
        third_group *= "k"
    end
    if board.can_castle[1, LONGCASTLE]
        third_group *= "q"
    end

    if third_group == ""
        third_group = "-"
    end

    fourth_group = "-"
    if any(board.can_en_passant)
        r, f = Tuple(findfirst(board.can_en_passant))
        r = white ? 6 : 3
        if white
            if f - 1 > 0 && all(board[r-1, f-1, [PAWN, WHITE]])
                fourth_group = field(r, f)
            end
            if f + 1 ≤ 8 && all(board[r-1, f+1, [PAWN, WHITE]])
                fourth_group = field(r, f)
            end
        else
            if f - 1 > 0 && all(board[r+1, f-1, [PAWN, BLACK]])
                fourth_group = field(r, f)
            end
            if f + 1 ≤ 8 && all(board[r+1, f+1, [PAWN, BLACK]])
                fourth_group = field(r, f)
            end
        end
    end

    return first_group * " " * second_group * " " * third_group * " " * fourth_group * " 0 1"
end

function Board(FEN::String)
    groups = split(FEN, " ")

    # group 1: position
    board = Board(false)
    for (s, rank) in zip(split(groups[1], "/"), 8:-1:1)
        file = 1
        for c in s
            if isdigit(c)
                file += Int(c) - 48
                continue
            end
            white = isuppercase(c)
            p = PIECES[uppercase(c)]
            board.position[rank, file, [p, 7+!white]] .= 1
            file += 1
        end
    end

    # group 2: right to move
    white_to_move = groups[2] == "w"

    # group 3: castling rights
    board.can_castle .= false
    if occursin('K', groups[3])
        white=true
        board.can_castle[white+1, SHORTCASTLE] = true
    end
    if occursin('Q', groups[3])
        white=true
        board.can_castle[white+1, LONGCASTLE] = true
    end
    if occursin('k', groups[3])
        white=false
        board.can_castle[white+1, SHORTCASTLE] = true
    end
    if occursin('q', groups[3])
        white=false
        board.can_castle[white+1, LONGCASTLE] = true
    end

    # group 4: en passant right
    if groups[4] != "-"
        rank, file = cartesian(string(groups[4]))
        board.can_en_passant[!white_to_move+1, file] = 1
    end

    return board
end
