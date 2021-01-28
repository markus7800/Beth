const PIECE_SYMBOLS = ['P', 'B', 'N', 'R', 'Q', 'K']

const PIECES = Dict{Char, Piece}(
    'P' => PAWN,
    'B' => BISHOP,
    'N' => KNIGHT,
    'R' => ROOK,
    'Q' => QUEEN,
    'K' => KING
)

function print_fields(fs::Fields)
    println("Fields")
    for rank in 8:-1:1
        print("$rank ")
        for file in 1:8
            s = "⋅"
            if fs & Field(rank, file) > 0
                s = "X"
            end

            print("$s ")
            end
        print("\n")
    end
    println("  a b c d e f g h")
end

import Base.show
function Base.show(io::IO, board::Board)
    println(io, "Chess Board")
    for rank in 8:-1:1
        print(io,"$rank ")
        for file in 1:8
            s = "⋅"
            wp = get_piece(board, Field(rank, file), true)
            if wp != NO_PIECE
                s = PIECE_SYMBOLS[wp]
            end

            bp = get_piece(board, Field(rank, file), false)
            if bp != NO_PIECE
                s = lowercase(PIECE_SYMBOLS[bp])
            end

            print(io, "$s ")
            end
        print(io,"\n")
    end
    println(io,"  a b c d e f g h")

    # if board.castle > 0
    #     third_group = ""
    #     if board.castle & WHITE_SHORT_CASTLE > 0
    #         third_group *= "K"
    #     end
    #     if board.castle & WHITE_LONG_CASTLE > 0
    #         third_group *= "Q"
    #     end
    #
    #     if board.castle & BLACK_SHORT_CASTLE > 0
    #         third_group *= "k"
    #     end
    #     if board.castle & BLACK_LONG_CASTLE > 0
    #         third_group *= "q"
    #     end
    #     print(io, " $third_group ")
    # else
    #     print(io, " - ")
    # end
    # if board.en_passant > 0
    #     print(io, "$(Char(96 + board.en_passant))")
    # else
    #     print(io, "-")
    # end
    # println(io)
    println(io, FEN(board, true))
end

function print_board(board::Board; highlight=nothing, white=true)
    cols = [:white, :blue]

    highlight_fields = []
    if highlight != nothing && white != nothing
        if highlight != "."
            p = PIECES[highlight[1]]
            rf = Field(highlight[2:3])
            moves = get_moves(board, white)
            highlight_moves = filter(m -> m.from_piece == p && m.from == tonumber(rf), moves)
        else
            highlight_moves = get_moves(board, white)
        end
        highlight_fields = map(m -> rankfile(m.to), highlight_moves)
    end

    println("Chess Board")

    ranks = white ? (8:-1:1) : (1:8)
    files = white ? (1:8) : (8:-1:1)

    for rank in ranks
        printstyled("$rank ", color=:magenta) # col = 13
        for file in files
            s = "•" #"⦿" # "⋅"
            piece = get_piece(board, Field(rank, file))
            is_highlighted = (rank, file) in highlight_fields

            if piece != NO_PIECE

                s = PIECE_SYMBOLS[piece]

                if is_occupied_by_white(board, Field(rank, file))
                    col = is_highlighted ? :red : cols[1]
                    printstyled("$s ", color=col, bold=true)
                elseif is_occupied_by_black(board, Field(rank, file))
                    col = is_highlighted ? :red : cols[2]
                    printstyled("$s ", color=col, bold=true)
                else
                    printstyled("X ", color=:red, bold=true)
                end
            else

                col = is_highlighted ? :green : :light_black # 8

                printstyled("$s ", bold=true, color=col)
            end
        end
        print("\n")
    end
    if white
        printstyled("  a b c d e f g h", color=:magenta) # col = 13
    else
        printstyled("  h g f e d c b a", color=:magenta) # col = 13
    end
end
