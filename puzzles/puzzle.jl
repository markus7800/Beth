
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
        file, rank = cartesian(groups[4])
        board.can_en_passant[white_to_move+1, file] .= 1
    end

    if firstmove != nothing
        try
            p, rf1, rf2 = short_to_long(board, white_to_move, firstmove)
            move!(board, white_to_move, p, rf1, rf2)
            white_to_move = !white_to_move
        catch e
            println(e)
            print_board(board, white=white_to_move)
            println()
            println(firstmove)
            println(difficulty)
        end
    end

    @assert is_valid(board) "Invalid chess board!"

    sol = split(solution, " ")

    return Puzzle(board, sol, white_to_move, difficulty)
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


function play_puzzle(puzzle::Puzzle, player=user_input)
    board = deepcopy(puzzle.board)
    white = puzzle.white_to_move

    n_moves = length(puzzle.solution)
    i = 1
    while true
        print_board(board, white=white)
        println()

        p, rf1, rf2 = player(board, white)
        if p == "abort"
            return false
        end

        try
            p´, rf1´, rf2´ = short_to_long(board, white, puzzle.solution[i])
        catch e
            println(e)
            println(puzzle.solution[i])
            for m in get_moves(board, white)
                println(m)
            end
            return false
        end

        p´, rf1´, rf2´ = short_to_long(board, white, puzzle.solution[i])

        if p == p´ && rf1 == rf1´ && rf2 == rf2´
            # correct move
            @info "Move was correct!"
            move!(board, white, p, rf1, rf2)
        else
            @info "Move was wrong!"
            return false
        end

        i += 1
        if i > n_moves
            print_board(board, white=white)
            println()
            @info "Puzzle solved! (Difficulty: $(puzzle.difficulty))"
            return true
        end

        p, rf1, rf2 = short_to_long(board, !white, puzzle.solution[i])
        @info "Computer says $(puzzle.solution[i])!"
        move!(board, !white, p, rf1, rf2)


        i += 1
    end
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

include("puzzle_rush_20_12_13.jl")

play_puzzle(puzzle_rush[24])
