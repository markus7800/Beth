
BOARD = String
# first 16 white, second 16 black
# white encoding
# 1-8 pawns a-h
# 9,16 rook
# 10, 15 knight
# 11, 14 bishop
# 12 queen
# 13 king
# black encoding = white + 32
# 65-80 denoting whether pawn promoted, first 16 white, last 16 black a-h

const FIGURES = "PPPPPPPPRNBQKBNRpppppppprnbqkbnrQQQQQQQQqqqqqqq"

const START_POSITION = String([
    # white
    FtI["a2"],FtI["b2"],FtI["c2"],FtI["d2"],FtI["e2"],FtI["f2"],FtI["g2"],FtI["h2"],
    FtI["a1"],FtI["b1"],FtI["c1"],FtI["d1"],FtI["e1"],FtI["f1"],FtI["g1"],FtI["h1"],
    #black
    FtI["a7"],FtI["b7"],FtI["c7"],FtI["d7"],FtI["e7"],FtI["f7"],FtI["g7"],FtI["h7"],
    FtI["a8"],FtI["b8"],FtI["c8"],FtI["d8"],FtI["e8"],FtI["f8"],FtI["g8"],FtI["h8"],
]) * "0"^16

for i in START_POSITION[1:32]
    println(FIELDS[i])
end

function print_board(position, perspective=:white)
    ranks = (perspective == :white) ? (8:-1:1) : (1:8)

    tile = ["⋅", "⋅"]
    board = String[tile[((r+f)%2==0)+1] for r in 1:8, f in 1:8]

    # place figures
    for (i,c) in enumerate(position[1:32])
        r,f = cartesian(FIELDS[c])
        fig = string(FIGURES[i])
        board[r,f] = fig
        #println("$fig with $c at $(FIELDS[c]) ($r $f)")
    end
    # for (k,v) in FIELDS
    #     r,f = cartesian(v)
    #     board[r,f] = v
    # end

    for r in ranks # rank is row
        print("$r  ")
        for f in 1:8 # file is column
            print(board[r,f], " ")
        end
        print("\n")
    end
    println()
    println("   a b c d e f g h")
    println()
end
