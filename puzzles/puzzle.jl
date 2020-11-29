
struct Puzzle
    board::Board
    solution::Vector{String}
    white_to_move::Bool
end

# piece position encoding like "Ke1" "!Qd1"
function Puzzle(board=Board(false); white::Vector{String}, black::Vector{String},
    solution::Vector{String}, white_to_move::Bool)

    for (player, piecepositions) in [(WHITE, white), (BLACK, black)]
        for pieceposition in piecepositions
            v = true # add piece
            if length(pieceposition) == 4
                @assert pieceposition[1] == "!" pieceposition
                pieceposition = pieceposition[2:end]
                v = false # remove piece
            end
            @assert length(pieceposition) == 3 pieceposition

            p = PIECES[pieceposition[1]]
            r, f = cartesian(pieceposition[2:3])

            board.position[r,f, [player, p]] .= v
        end
    end

    # check castling rights
    board.can_castle .= true
    if !all(board[cartesian("e1")..., [KING, WHITE]])
        board.can_castle[1,:] .= false
    else
        if !all(board[cartesian("a1")..., [ROOK, WHITE]])
            board.can_castle[1,1] .= false
        end
        if !all(board[cartesian("h1")..., [ROOK, WHITE]])
            board.can_castle[1,2] .= false
        end
    end
    if !all(board[cartesian("e8")..., [KING, BLACK]])
        board.can_castle[2,:] .= false
    else
        if !all(board[cartesian("a8")..., [ROOK, BLACK]])
            board.can_castle[2,1] .= false
        end
        if !all(board[cartesian("h8")..., [ROOK, BLACK]])
            board.can_castle[2,2] .= false
        end
    end

    @assert is_valid(board) "Invalid chess board!"

    return Puzzle(board, solution, white_to_move)
end


function PuzzleFEN(;FEN::String, solution::String, firstmove=nothing)
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
        board.can_castle[white+1, LONGTCASTLE] = true
    end
    if occursin('k', groups[3])
        white=false
        board.can_castle[white+1, SHORTCASTLE] = true
    end
    if occursin('q', groups[3])
        white=false
        board.can_castle[white+1, LONGTCASTLE] = true
    end

    # group 3: en passant right
    if groups[3] != "-"
        file, rank = cartesian(groups[3])
        board.can_en_passant[white_to_move+1, file] .= 1
    end

    if firstmove != nothing
        p, rf1, rf2 = short_to_long(board, white_to_move, firstmove)
        move!(board, white_to_move, p, rf1, rf2)
        white_to_move = !white_to_move
    end

    @assert is_valid(board) "Invalid chess board!"

    return Puzzle(board, [solution], white_to_move)
end


function print_puzzle(puzzle::Puzzle)
    print_board(puzzle.board, white=puzzle.white_to_move)

    println()

    println("Solution:")

    if length(puzzle.solution) == 1
        println(puzzle.solution[1])
    else
        i = 1
        if !puzzle.white_to_move
            s2 = puzzle.solution[i]
            println("1:      $s2")
            i = 2
        end

        while true
            if i > length(puzzle.solution)
                break
            end
            if i+1 > length(puzzle.solution)
                s1 = puzzle.solution[i]
                println("$(i): $(s1)")
                break
            end

            s1 = puzzle.solution[i]
            s2 = puzzle.solution[i+1]
            println("$(i): $(s1), $(s2)")

            i = i+2
        end
    end
end

# 133
puzzle_1 = Puzzle(
    white=["Kg1", "Pa2", "Pb2", "Nd2", "Ph2", "Pe3", "Pg3", "Rd5", "Rd8"],
    black=["Ra8", "Pg7", "Kh7", "Pb6", "Rf6", "Ph6", "Pa5", "Pe4", "Bd3"],
    solution=["Ra8"],
    white_to_move = true
    )

puzzle_1 = PuzzleFEN(
    FEN="r2R2k1/6p1/1p3r1p/p2R4/3Pp3/3bP1P1/PP1N3P/6K1 b - - 0 1",
    solution="Rxa8",
    firstmove="Kh7")

print_puzzle(puzzle_1)



simple_piece_count(puzzle_1.board, puzzle_1.white_to_move)

@time root = MCTreeSearch(puzzle_2.board, puzzle_2.white_to_move, N=10^4)
