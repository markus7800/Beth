
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
end

puzzle_1 = Puzzle(
    white=["Kg1", "Pa2", "Pb2", "Nd2", "Ph2", "Pe3", "Pg3", "Rd5", "Rd8"],
    black=["Ra8", "Pg7", "Kh7", "Pb6", "Rf6", "Ph6", "Pa5", "Pe4", "Bd3"],
    solution=["Ra8"],
    white_to_move = true,
    difficulty = 133
    )

puzzle_1 = PuzzleFEN(
    FEN="r2R2k1/6p1/1p3r1p/p2R4/3Pp3/3bP1P1/PP1N3P/6K1 b - - 0 1",
    solution="Rxa8",
    firstmove="Kh7",
    difficulty=133)

solve_puzzle(puzzle_1)

puzzle = PuzzleFEN(
    FEN="",
    solution="",
    firstmove="",
    difficulty=)

puzzle = PuzzleFEN(
    FEN="6N1/1p6/1k2N2b/1p2P2p/8/P4b1r/2P2R2/4RK2 w - - 0 36",
    solution="",
    firstmove="Nf6",
    difficulty=175)

puzzle = PuzzleFEN(
    FEN="2r3k1/pR1p4/3Pp2p/P4p1q/5Pp1/R3QNKP/2r5/8 w - - 0 41",
    solution="Qxg4#",
    firstmove="hg4",
    difficulty=297)

puzzle = PuzzleFEN(
    FEN="4rrk1/p2p4/npp2q2/5Np1/8/P5Q1/5PPP/R3R1K1 w - - 0 24",
    solution="Qxa1+ Re1 Qxe1#",
    firstmove="Rxe8",
    difficulty=341)

puzzle = PuzzleFEN(
    FEN="3R4/p4pkp/6pb/4R3/8/8/PPr2PPP/6K1 w - - 3 29",
    solution="Rc1+ Kg2 Bf4+ Pg3 Be5",
    firstmove="h3",
    difficulty=381)

puzzle = PuzzleFEN(
    FEN="1r3b1k/7p/5p2/2pRp2p/pqN1PP2/2Q5/1PK3PP/8 b - - 0 1",
    solution="Qf6+ Bg7 Rd8+ Rd8 Qd8+ Bf8 Qf8#",
    firstmove="ef4",
    difficulty=406)

puzzle = PuzzleFEN(
    FEN="2r3k1/5p1p/p1q3p1/8/5P2/1N4Q1/PP5P/1K2R3 w - - 0 1",
    solution="Qc2+ Ka1 Qc1+ Rc1 Rc1#",
    firstmove="Nc1",
    difficulty=492)

puzzle = PuzzleFEN(
    FEN="5r2/p5RR/1p2r1k1/2pP2p1/2n1P1P1/2Nb2K1/PP6/8 b - - 0 1",
    solution="de6",
    firstmove="Kf6",
    difficulty=507)

puzzle = PuzzleFEN(
    FEN="r1q4r/ppp4k/3b2pp/3Q1n2/4R3/2N3P1/PPP2P1P/3R2K1 b - - 10 24",
    solution="Qf7+ Rd6",
    firstmove="c6",
    difficulty=551)

puzzle = PuzzleFEN(
    FEN="r7/p1r3k1/1n2pp1p/6p1/3P2P1/1R2PNKP/5P2/R7 b - - 5 29",
    solution="Rb6 ab6 Ra8",
    firstmove="Kg6",
    difficulty=610)

puzzle = PuzzleFEN(
    FEN="4r3/p4qpk/1p2p1rp/3p3Q/3B4/6R1/P4PPP/5RK1 w - - 4 25",
    solution="Rg2+ Kg2 Qh5",
    firstmove="Rf3",
    difficulty=655)

puzzle = PuzzleFEN(
    FEN="8/7p/5k2/3p1n2/2pP2Q1/7P/1P4PK/5r2 w - - 5 42",
    solution="Rh1+ Kh1 Ng3+ Kh2 Ne2",
    firstmove="Qe2",
    difficulty=747)

puzzle = PuzzleFEN(
    FEN="r2r2k1/pp3ppp/2p5/2b1qN1Q/4Pp2/1P1P4/1PP3PP/R4R1K b - - 0 1",
    solution="Nh6+ Kg2 Qe5",
    firstmove="g6",
    difficulty=767)

solve_puzzle(puzzle, N=10^5)

@time root = MCTreeSearch(puzzle.board, puzzle.white_to_move, N=10^4)

print_tree(root, max_depth=5, expand_best=3, has_to_have_children=false)

print_tree(root, max_depth=1, expand_best=Inf, has_to_have_children=false)
