
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

        i = i+2
    end

end

# 133
puzzle_1 = Puzzle(
    white=["Kg1", "Pa2", "Pb2", "Nd2", "Ph2", "Pe3", "Pg3", "Rd5", "Rd8"],
    black=["Ra8", "Pg7", "Kh7", "Pb6", "Rf6", "Ph6", "Pa5", "Pe4", "Bd3"],
    solution=["Ra8"],
    white_to_move = true
    )

print_puzzle(puzzle_1)

simple_piece_count(puzzle_1.board, puzzle_1.white_to_move)

@time root = MCTreeSearch(puzzle_2.board, puzzle_2.white_to_move, N=10^4)

print_tree(root, max_depth=1)

print_board(puzzle1.board, highlight="Rd5")

print_board(puzzle_1.board)
simple_piece_count(puzzle_1.board, puzzle_1.white_to_move)

move!(puzzle_1.board, true, 'R', "d8", "a8")
print_board(puzzle_1.board)
simple_piece_count(puzzle_1.board, puzzle_1.white_to_move)




puzzle = Puzzle(
    white=[],
    black=[],
    solution=[""],
    white_to_move = true
    )
print_puzzle(puzzle)


# 175
puzzle = Puzzle(
    white=["Kf1", "Re1", "Rf2", "Pc2", "Pa3", "Pe5", "Nf6", "Ne6"],
    black=["Pb7", "Bh6", "Kb6", "Ph5", "Pb5", "Rh3", "Bf3"],
    solution=["Rh1"],
    white_to_move = false
    )
print_puzzle(puzzle)

# 297
puzzle = Puzzle(
    white=["Ra3", "Qe3", "Nf3", "Kg3", "Pf4", "Pg4", "Pa5", "Pd6", "Rb7"],
    black=["Rc2", "Pf5", "Qh5", "Pe6", "Ph6", "Pa7", "Pd7", "Rc8", "Kg8"],
    solution=["Qg4"],
    white_to_move = false
    )
print_puzzle(puzzle)

# 341
puzzle_2 = Puzzle(
    white=["Kg1", "Ra1", "Ph2", "Pg2", "Pf2", "Qg3", "Pa3", "Nf5", "Re8"],
    black=["Kg8", "Rf8", "Pd7", "Pa7", "Qf6", "Pc6", "Pb6", "Na6", "Pg5"],
    solution=["Qa1", "Re1", "Qe1"],
    white_to_move = false
    )
print_puzzle(puzzle_2)

# 381
puzzle = Puzzle(
    white=["Kg1", "Ph3", "Pg2",  "Pf2", "Pb2", "Pa2", "Re5", "Rd8"],
    black=["Ph7", "Kg7", "Pf7", "Pg6", "Bh6", "Pa7", "Rc2"],
    solution=["Rc1", "Kh2", "Bf6", "g3", "Be5"],
    white_to_move = false
    )
print_puzzle(puzzle)
