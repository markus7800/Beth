
struct Puzzle
    board::Board
    solution::Vector{String}
    white_to_move::Bool

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

        return new(board, solution, white_to_move)
    end
end

function print_puzzle(puzzle::Puzzle)
    print_board(puzzle.board)

    println()

    println("Solution:")

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

        i = i+1
    end

end

puzzle_1 = Puzzle(
    white=["Kg1", "Pa2", "Pb2", "Nd2", "Ph2", "Pe3", "Pg3", "Rd5", "Rd8"],
    black=["Ra8", "Pg7", "Kh7", "Pb6", "Rf6", "Ph6", "Pa5", "Pe4", "Bd3"],
    solution=["Ra8"],
    white_to_move = true
    )

print_puzzle(puzzle_1)

simple_piece_count(puzzle_1.board, puzzle_1.white_to_move)

@time root = MCTreeSearch(puzzle1.board, puzzle1.white_to_move, N=10^5)

print_tree(root, max_depth=1)

print_board(puzzle1.board, highlight="Rd5")

Board().can_en_passant

puzzle_1.board.can_castle
