
const PIECES = Dict{Char, Piece}(
    'P' => PAWN,
    'B' => BISHOP,
    'N' => KNIGHT,
    'R' => ROOK,
    'Q' => QUEEN,
    'K' => KING
)

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
        board.en_passant[file] = 1
    end

    return board
end
