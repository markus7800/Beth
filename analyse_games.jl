
include("chess/chess.jl")

const Analysis = Dict{String, Dict{Move,Vector{String}}}
function create_analysis(path::String)
    white_analysis = Analysis()
    black_analysis = Analysis()
    for (root, dirs, files) in walkdir(path)
        println(root)
        println(last(split(root, "\\")))
        for file in joinpath.(root, files)
            !(occursin("black",file) || occursin("white",file)) && continue
            white = occursin("white",file)

            file_string = read(file, String)
            println(file)
            game_moves = extract_moves(file_string)
            add!(white_analysis, black_analysis, game_moves, white, file)
        end
    end

    return white_analysis, black_analysis
end

function extract_moves(s::String)::Vector{String}
    moves = []
    move_nr = 1
    for line in split(s, '\n')
        line = rstrip(line, '\r')
        line_splitted = split(line, ' ')
        first_group = line_splitted[1]
        if occursin(string(move_nr), first_group)
            popfirst!(line_splitted)
            move_nr += 1
            append!(moves, line_splitted)
        end
    end
    moves
end

function add!(white_analysis::Analysis, black_analysis::Analysis, game_moves::Vector{String}, white::Bool, file_string::String)
    board = StartPosition()
    _white = true
    for move_str in game_moves
        move = short_to_long(board, _white, move_str)

        fen = FEN(board, _white)

        analysis = white ? white_analysis : black_analysis
        if !haskey(analysis, fen)
            analysis[fen] = Dict{Move, Vector{String}}()
        end
        board_dict = analysis[fen]

        encounters = get(board_dict, move, String[])
        push!(encounters, file_string)
        board_dict[move] = encounters


        make_move!(board, _white, move)
        _white = !_white
    end
end

function get_played_moves_message(fen::String, ana::Analysis, my_move::Bool)
    move_dict = ana[fen]
    move_vec = collect(move_dict)
    sort!(move_vec, lt=(x,y) -> length(x[2]) < length(y[2]), rev=true)

    out = ""

    if my_move
        out *= "I played:\n"
    else
        out *= "Opponent played:\n"
    end

    for (move, games) in move_vec
        wins = 0
        losses = 0
        draws = 0
        for game in games
            file_string = read(game, String)
            if occursin("Result: won", file_string)
                wins += 1
            elseif occursin("Result: lost", file_string)
                losses += 1
            elseif occursin("Result: draw", file_string)
                draws += 1
            end
        end

        out *= "$move, games played: $(length(games)), wins: $wins, draws: $draws, losses: $losses\n"
        if length(games) < 3
            for game in games
                res = ""
                file_string = read(game, String)
                if occursin("Result: won", file_string)
                    res = "won"
                elseif occursin("Result: lost", file_string)
                    res = "lost"
                elseif occursin("Result: draw", file_string)
                    res = "draw"
                end

                out *= "\t$game $res\n"
            end
        end
    end
    return out
end

using Genie

import Genie.Router: route
import Genie.Renderer: respond
import JSON: json

using Printf

mutable struct AnalysisController
    white_analysis::Analysis
    black_analysis::Analysis

    perspective::Bool

    board::Board
    white::Bool

    fen_history::Vector{String}
end

function AnalysisController(path)
    white_analysis, black_analysis = create_analysis(path)

    board = StartPosition()
    perspective = true
    white = true

    return AnalysisController(white_analysis, black_analysis, perspective, board, white, [FEN(board, white)])
end

function get_played_moves_message(ac::AnalysisController)
    my_move = ac.white == ac.perspective
    ana = ac.perspective ? ac.white_analysis : ac.black_analysis
    try
        return get_played_moves_message(FEN(ac.board, ac.white), ana, my_move)
    catch e
        if e isa KeyError
            return "No games found!"
        else
            rethrow(e)
        end
    end
end


ac = AnalysisController("backlog/chess.com_engines")

route("/") do
    @info "Reset"
    global ac
    # game = Game()

    ac.board = StartPosition()
    ac.white = true
    ac.perspective = true
    ac.fen_history = [FEN(ac.board, ac.white)]

    serve_static_file("analysis.html")
end

route("/move") do
    @info "make move"
    global ac

    from_str = @params(:from)
    to_str = @params(:to)
    promote = parse(Bool, @params(:promotion))

    from = Field(from_str)
    to = Field(to_str)

    if from == to
        message = get_played_moves_message(ac)
        return respond(json(Dict("fen"=>FEN(ac.board, ac.white), "message"=> message)))
    end


    moves = get_moves(ac.board, ac.white)

    filtered_moves = []
    if promote
        filtered_moves = filter(m -> tofield(m.from) == from && tofield(m.to) == to && m.to_piece == QUEEN, moves)
    else
        filtered_moves = filter(m -> tofield(m.from) == from && tofield(m.to) == to, moves)
    end

    if length(filtered_moves) == 1
        # player move
        move = filtered_moves[1]
        make_move!(ac.board, ac.white, move)
        ac.white = !ac.white
        push!(ac.fen_history, FEN(ac.board, ac.white))

        message = get_played_moves_message(ac)

        return respond(json(Dict("fen"=>FEN(ac.board, ac.white), "message"=> message)))
    else
        message = get_played_moves_message(ac)
        return respond(json(Dict("fen"=>FEN(ac.board, ac.white), "message"=>message)))
    end
end

route("/flip") do
    @info "flip"
    global ac
    white = parse(Bool, @params(:white))

    ac.perspective = white

    message = get_played_moves_message(ac)

    return respond(json(Dict("fen"=>FEN(ac.board, ac.white), "message"=> message)))
end


route("/load") do
    @info "load"
    fen = @params(:fen)
    if fen == ""
        ac.board = StartPosition()
        ac.white = true
    else
        ac.board = Board(fen)

        groups = split(fen, " ")
        white_to_move = groups[2] == "w"

        ac.white = white_to_move
    end

    message = get_played_moves_message(ac)

    return respond(json(Dict("fen"=>FEN(ac.board, ac.white), "message"=> message)))
end

route("/undo") do
    @info "undo"
    global ac

    display(ac.fen_history)

    if length(ac.fen_history) > 1
        pop!(ac.fen_history)
    end

    ac.board = Board(ac.fen_history[end])
    ac.white = !ac.white

    message = get_played_moves_message(ac)

    return respond(json(Dict("fen"=>FEN(ac.board, ac.white), "message"=> message)))
end

@info "Start listening at localhost:8000"
Genie.AppServer.startup(async=false)
