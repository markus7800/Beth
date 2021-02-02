using Printf

struct Puzzle
    board::Board
    solution::Vector{String}
    white_to_move::Bool
    difficulty::Int
end

function PuzzleFEN(;FEN::String, solution::String, firstmove=nothing, difficulty::Int)
    board = Board(FEN)
    groups = split(FEN, " ")
    white_to_move = groups[2] == "w"

    if firstmove != nothing
        try
            m = short_to_long(board, white_to_move, firstmove)
            make_move!(board, white_to_move, m)
            white_to_move = !white_to_move
        catch e
            println(e)
            print_board(board, white=white_to_move)
            println()
            println(firstmove)
            println(difficulty)
        end
    end

    # @assert is_valid(board) "Invalid chess board!"

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


function play_puzzle(puzzle::Puzzle, player=user_input)
    board = deepcopy(puzzle.board)
    white = puzzle.white_to_move

    n_moves = length(puzzle.solution)
    i = 1
    while true
        print_board(board, white=white)
        println()

        m,  = player(board, white)
        if m == "abort"
            return false
        end

        try
            m´ = short_to_long(board, white, puzzle.solution[i])
        catch e
            println(e)
            println(puzzle.solution[i])
            for m in get_moves(board, white)
                println(m)
            end
            return false
        end

        m´ = short_to_long(board, white, puzzle.solution[i])

        if m == m´
            # correct move
            @info "Move was correct!"
            make_move!(board, white, m)
        else
            @info "Puzzle failed! (Difficulty: $(puzzle.difficulty), played: $m, correct$(m´))"
            return false
        end

        i += 1
        i > n_moves && break

        m = short_to_long(board, !white, puzzle.solution[i])
        @info "Computer says $(puzzle.solution[i])!"
        make_move!(board, !white, m)

        i += 1
        i > n_moves && break
    end

    print_board(board, white=white)
    # println(board)
    println()
    @info "Puzzle solved! (Difficulty: $(puzzle.difficulty))"
    return true
end

function puzzle_rush(rush::Vector{Puzzle}, player; print_solution=false)
    solveds = []
    times = []

    for (i,puzzle) in enumerate(rush)
        @info "Puzzle $i:"
        solved,t, = @timed play_puzzle(puzzle, player)
        push!(solveds, solved)
        push!(times, t)

        if print_solution && !solved
            print_puzzle(puzzle)
        end
        @info @sprintf "Spent %.2fs." t
        println(("="^80)*"\n\n")
    end

    for (i, puzzle) in enumerate(rush)
        printstyled("Puzzle $i ", color=:blue)
        print("(Difficulty $(puzzle.difficulty)):\t")

        t = times[i]
        if solveds[i]
            printstyled("Solved", color=:green)
        else
            printstyled("Failed", color=:red)
        end
        println(@sprintf " in %.2fs" t)
    end

    @info @sprintf "Solved %d out of %d." sum(solveds) length(rush)
end
