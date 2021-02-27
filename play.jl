
using Genie

import Genie.Router: route
import Genie.Renderer: respond
import JSON: json

using Printf

include("Beth/Beth.jl")

mutable struct Game
    history::Vector{Ply}
    beth::Beth
    board::Board
    white::Bool
    busy::Bool
end

function Game()
    beth = Beth(
        value_heuristic=evaluation,
        rank_heuristic=rank_moves_by_eval,
        search_algorithm=IterativeMTDF,
        search_args=Dict(
            "max_depth" => 20,
            "do_quiesce" => true,
            "quiesce_depth" => 50,
            "verbose" => 1,
            "time" => 5
        ))

    # beth = Beth(
    #     value_heuristic=evaluation,
    #     rank_heuristic=rank_moves_by_eval,
    #     search_algorithm=IterativeMTDF,
    #     search_args=Dict(
    #         "max_depth" => 6,
    #         "do_quiesce" => true,
    #         "quiesce_depth" => 50,
    #         "verbose" => 1,
    #         "time" => 5
    #     ))

    board = StartPosition()
    white = true
    busy = false
    return Game([Ply(0, 0, deepcopy(board), white, EMPTY_MOVE, 0.)], beth, board, white, busy)
end

function check_game_end(history::Vector{Ply}, board::Board, white::Bool)
    moves = get_moves(board, white)
    if length(moves) == 0
        if is_in_check(board, white)
            return true, "Checkmate!"
        else
            return true, "Stalemate!"
        end
    else
        piece_count = n_pieces(board, white)
        if piece_count ≤ 3
            if count_pieces(board.queens | board.rooks | board.pawns) == 0
                return true, "Draw by insufficient material!"
            end
        end

        board_rep = 0
        for i in 0:2:board.r50
            if board == history[end-i].board
                board_rep += 1
            end
            if board_rep ≥ 3
                return true, "Draw by repetition!"
            end
        end
    end
    return false, ""
end

game = Game()

route("/") do
    global game
    # game = Game()

    game.board = StartPosition()
    game.white = true
    game.history = [Ply(0, 0, deepcopy(game.board), game.white, EMPTY_MOVE, 0.)]
    game.busy = false

    init(game.beth, game.board, game.white)

    @info("Reset")

    serve_static_file("playgame.html")
end

function computer_move(game)
    game.busy = true
    @info("Start Search.")
    (next_move, value), t, = @timed game.beth(game.board, game.white)
    make_move!(game.board, game.white, next_move)
    make_move!(game.beth, next_move)
    game.white = !game.white
    game.busy = false
    @assert game.white == game.beth.white
    @assert game.board == game.beth.board

    n_ply = game.history[end].nr + 1
    push!(game.history, Ply(n_ply, (n_ply+1) ÷ 2, deepcopy(game.board), game.white, next_move, t))

    done, message = check_game_end(game.history, game.board, game.white)
    if done
        return respond(json(Dict("fen"=>FEN(game.board, game.white), "message"=>message)))
    end

    if value == :book
        message = @sprintf "Computer says: %s." next_move
    else
        message = ""
        if abs(value) ≥ WHITE_MATE -100*100
            message = @sprintf "Computer says: %s is forced mate.\n" next_move
        else
            message = @sprintf "Computer says: %s valued at %.2f.\n" next_move value/100
        end

        message *= @sprintf "Explored %d nodes in %.2fs (%.2f kN/s).\n" game.beth.n_explored_nodes t game.beth.n_explored_nodes/(t*1000)
        message *= @sprintf "Completely explored up to depth %d. Deepest node at depth %d." game.beth.max_depth game.beth.max_depth+game.beth.max_quiesce_depth
    end

    return json(Dict("fen"=>FEN(game.board, game.white), "message"=> message))
end

route("/move") do
    global game

    from_str = @params(:from)
    to_str = @params(:to)
    promote = parse(Bool, @params(:promotion))

    if game.busy
        return respond(json(Dict("fen"=>FEN(game.board, game.white), "message"=>"I am busy!!")))
    end

    from = Field(from_str)
    to = Field(to_str)

    moves = get_moves(game.board, game.white)

    filtered_moves = []
    if promote
        filtered_moves = filter(m -> tofield(m.from) == from && tofield(m.to) == to && m.to_piece == QUEEN, moves)
    else
        filtered_moves = filter(m -> tofield(m.from) == from && tofield(m.to) == to, moves)
    end

    if length(filtered_moves) != 1
        return respond(json(Dict("fen"=>FEN(game.board, game.white), "message"=>"Invalid Move!")))
    end


    # player move
    move = filtered_moves[1]
    make_move!(game.board, game.white, move)
    make_move!(game.beth, move)
    game.white = !game.white
    @assert(game.white == game.beth.white)
    @assert(game.board == game.beth.board)

    n_ply = game.history[end].nr + 1
    push!(game.history, Ply(n_ply, (n_ply+1) ÷ 2, deepcopy(game.board), game.white, move, 0.))

    done, message = check_game_end(game.history, game.board, game.white)
    if done
        return respond(json(Dict("fen"=>FEN(game.board, game.white), "message"=>message)))
    end

    response = computer_move(game)

    return respond(response)
end

route("/newgame") do
    global game
    start_as_white = parse(Bool, @params(:white))
    println("newgame: white: ", start_as_white)

    game.board = StartPosition()
    game.white = true
    game.history = [Ply(0, 0, deepcopy(game.board), game.white, EMPTY_MOVE, 0.)]
    game.busy = false
    init(game.beth, game.board, game.white)

    if !start_as_white
        response = computer_move(game)
        return respond(response)
    else
        return respond(json(Dict("fen"=>FEN(game.board, game.white), "message"=> "")))
    end
end

route("/undo") do
    println("undo")
    global game
    if length(game.history) ≤ 1
        return respond(FEN(game.board, game.white))
    end

    pop!(game.history)
    pop!(game.history)

    ply = game.history[end]
    game.board = deepcopy(ply.board)
    game.beth.board = deepcopy(game.board)
    game.beth.current = game.beth.current.parent.parent

    println("return")
    return respond(FEN(game.board, game.white))
end

route("/load") do
    global game
    fen = @params(:fen)
    if fen == ""
        game.board = StartPosition()
        game.white = true
    else
        game.board = Board(fen)

        groups = split(fen, " ")
        white_to_move = groups[2] == "w"

        game.white = white_to_move
    end
    game.busy = false
    game.history = [Ply(0, 0, deepcopy(game.board), game.white, EMPTY_MOVE, 0.)]
    init(game.beth, game.board, game.white)

    orientation = game.white ? "white" : "black"

    return respond(json(Dict("fen"=>FEN(game.board, game.white), "orientation"=>orientation, "message"=> "FEN loaded.")))
end

route("/flip") do
    @info "flip"
    global game
    orientation = parse(Bool, @params(:white))

    println("orientation $orientation")
    message = "Flipped board!"

    if game.white != orientation
        response = computer_move(game)
        return respond(response)
    else
        return respond(json(Dict("fen"=>FEN(game.board, game.white), "message"=> message)))
    end
end

route("/printgame") do
    global game
    out = ""

    # PGN
    for (i,ply) in enumerate(game.history[2:end])
        if i % 2 == 1
            out *= string(ply.n_move, ". ")
        end
        m = ply.move

        if m.from_piece == KING
            r1,f1 = rankfile(m.from)
            r2,f2 = rankfile(m.to)
            if f1 - f2 == 2
                out *= string("O-O-O")
                if i % 2 == 0
                    out *= string("\n")
                else
                    out *= string(" ")
                end
                continue
            elseif f2 - f1 == 2
                out *= string("O-O")
                if i % 2 == 0
                    out *= string("\n")
                else
                    out *= string(" ")
                end
                continue
            end
        end

        if m.from_piece != m.to_piece
            out *= string(PIECE_SYMBOLS[m.from_piece] * tostring(m.from) * tostring(m.to) * PIECE_SYMBOLS[m.to_piece])
        else
            out *= string(PIECE_SYMBOLS[m.from_piece] * tostring(m.from) * tostring(m.to))
        end

        if i % 2 == 0
            out *= string("\n")
        else
            out *= string(" ")
        end
    end
    out *= "\n\n"


    # FEN strings
    for (i,ply) in enumerate(game.history)
        n_move = (i-1) ÷ 2 + 1
        out *= string("'" ,FEN(ply.board, ply.white, n_move), "'")
        if i < length(game.history)
            out *= ",\n"
        end
    end
    return respond(out)
end

@info "Start listening at localhost:8000"
Genie.AppServer.startup(async=false)
