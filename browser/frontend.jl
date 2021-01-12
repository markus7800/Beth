
using Genie
import DefaultApplication

import Genie.Router: route
import Genie.Renderer: respond

include("../fastbeth/Beth.jl")

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

board = StartPosition()
white = true
busy = false

route("/") do
    global board
    global white
    global busy

    board = StartPosition()
    white = true
    busy = false

    println("start up")
    println(board)

    serve_static_file("playgame.html")
end

route("/move") do
    global board
    global white
    global beth
    global busy

    from_str = @params(:from)
    to_str = @params(:to)
    promote = parse(Bool, @params(:promotion))

    println("$from_str, $to_str, $promote")
    if busy
        println("I am busy!!")
        return FEN(board, true)
    end


    from = Field(from_str)
    to = Field(to_str)

    moves = get_moves(board, white)

    filtered_moves = []
    if promote
        filtered_moves = filter(m -> tofield(m.from) == from && tofield(m.to) == to && m.to_piece == QUEEN, moves)
    else
        filtered_moves = filter(m -> tofield(m.from) == from && tofield(m.to) == to, moves)
    end
    println(filtered_moves)

    if length(filtered_moves) == 1
        move = filtered_moves[1]
        make_move!(board, white, move)

        println(board)

        white = !white

        busy = true
        next_move = beth(board, white)
        make_move!(board, white, next_move)

        println(board)

        white = !white

        busy = false

        return respond(FEN(board, white))
    else
        return respond(FEN(board, white))
    end
end

Genie.AppServer.startup(async=false)


DefaultApplication.open("http://localhost:8000")
