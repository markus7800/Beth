
struct Puzzle
    board::Board
    solution::Vector{String}
    white_to_move::Bool
    difficulty::Int
end

# piece position encoding like "Ke1" "!Qd1"
function Puzzle(board=Board(false); white::Vector{String}, black::Vector{String},
    solution::Vector{String}, white_to_move::Bool, difficulty::Int)

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

    return Puzzle(board, solution, white_to_move, difficulty)
end


function PuzzleFEN(;FEN::String, solution::String, firstmove=nothing, difficulty::Int)
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

    return Puzzle(board, [solution], white_to_move, difficulty)
end


function print_puzzle(puzzle::Puzzle)
    printstyled("Puzzle\n", bold=true, color=:yellow)
    print_board(puzzle.board, white=puzzle.white_to_move)

    println()

    println("Difficulty:\n$(puzzle.difficulty)")

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

function solve_puzzle(puzzle::Puzzle; N=10^4)
    print_puzzle(puzzle)

    @time root = MCTreeSearch(puzzle.board, puzzle.white_to_move, N=N)
    println()

    node = root
    proposed_solution = []
    while !isempty(node.children)
        most_visited = my_argmax(n->n.visits, node.children)
        push!(proposed_solution, string(most_visited.move))
        node = most_visited
    end

    println("Proposed Solution:")
    println(join(proposed_solution, " "))
    println("Evaluation:")
    println(root.score)
end

# puzzle_1 = Puzzle(
#     white=["Kg1", "Pa2", "Pb2", "Nd2", "Ph2", "Pe3", "Pg3", "Rd5", "Rd8"],
#     black=["Ra8", "Pg7", "Kh7", "Pb6", "Rf6", "Ph6", "Pa5", "Pe4", "Bd3"],
#     solution=["Ra8"],
#     white_to_move = true,
#     difficulty = 133
#     )


# puzzle = PuzzleFEN(
#     FEN="",
#     solution="",
#     firstmove="",
#     difficulty=)
