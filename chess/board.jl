struct Board
    position::BitArray{3}

    # first index player second LEFT/RIGHT
    # if pawn moves up 2 rows it sets to true
    # 1...black, 2...white (1+white)
    can_en_passant::BitArray{2}

    # first index player second LEFT/RIGHT
    # if king or rook moves will be set to false accordingly
    # 1...black, 2...white (1+white) to signal that pawn of white can be en passant captured
    can_castle::BitArray{2}
    # rows are ranks
    # columns are files
    # c2 -> (2,c) -> (2, 3)

    function Board(start=true, castle=true)
        position = falses(8, 8, 8)
        can_en_passant = falses(2, 8)
        can_castle = falses(2,2)
        can_castle .= castle

        if start
            position[[2,7],:,PAWN] .= 1
            position[[1,8], [3,6], BISHOP] .= 1
            position[[1,8], [2,7], KNIGHT] .= 1
            position[[1,8], [1,8], ROOK] .= 1
            position[[1,8], 4, QUEEN] .= 1 # d für dame
            position[[1,8], 5, KING] .= 1
            position[[1,2], :, WHITE] .= 1
            position[[7,8], :, BLACK] .= 1
            can_castle .= true
        end
        return new(position, can_en_passant, can_castle)
    end
end

import Base.==
function ==(b1::Board, b2::Board)
    return b1.position == b2.position && b1.can_en_passant == b2.can_en_passant && b1.can_castle == b2.can_castle
end

import Base.hash
function Base.hash(board::Board)
    h = hash(board.position)
    h = hash(board.can_en_passant, h)
    h = hash(board.can_castle, h)
end

function is_valid(board::Board)
    b1 = !any(sum(board.position[:,:,1:6], dims=3) .> 1) # no more than one piece per tile
    T = sum(board.position[:,:,1:6], dims=3) .== 1 # 1 if piece at tile
    W = board.position[:,:,WHITE]
    B = board.position[:,:,BLACK]

    b2 = !any(W .& B) # white and black cannot have piece at same tile

    b3 = all(xor.(T, W) .== B) && all(xor.(T, B) .== W) # if piece is not black it is white and vice versa

    # println(A)
    # println(B)
    # println(C)
    # println(xor.(A, B))
    # println(xor.(A, C))

    b1 && b2 && b3
end

import Base.getindex
function Base.getindex(b::Board, I...)
    Base.getindex(b.position, I...)
end

# import Base.setindex!
# function Base.setindex!(b::Board, v, I...)
#     #println("set: ", v, ", ", I)
#     Base.setindex!(b.position, v, I...)
# end




#=
    r1, f1: current field
    r2, f2: target field
    piece: 1-6
=#
function move!(board::Board, white::Bool, piece::Piece, r1::Int, f1::Int, r2::Int, f2::Int)
    captured = nothing
    en_passant = copy(board.can_en_passant)
    castle = copy(board.can_castle)

    player = 7 + !white
    opponent = 7 + white

    @assert board[r1,f1,player] "No piece for player ($white) at $r1, $(f1)!"
    @assert !board[r2,f2,player] "Player ($white) tried to capture own piece! $(SYMBOLS[1,piece]) $(field(r1,f1)) $(field(r2,f2))"

    # disable en passant
    board.can_en_passant[white+1, :] .= false

    # handle captures
    if board[r2,f2,opponent]
        captured = (findfirst(board[r2,f2,1:6]), r2, f2)
        @assert captured != nothing "Opponent ($(!white)) occupies square $(field(r2,f2)) with no piece!"
        board.position[r2,f2,captured[1]] = false
        board.position[r2,f2,opponent] = false
    end

    # handle promotions
    if piece == PAWNTOQUEEN || piece == PAWNTOKNIGHT
        @assert board[r1,f1,PAWN] "Piece not at field! $(SYMBOLS[1,PAWN]) $(field(r1,f1)) $(field(r2,f2))"
        @assert (white && r1 == 7) || (!white && r1 == 2)

        board.position[r1,f1,PAWN] = false
        board.position[r1,f1,player] = false

        newpiece = piece == PAWNTOQUEEN ? QUEEN : KNIGHT
        board.position[r2,f2,newpiece] = true
        board.position[r2,f2,player] = true

        return captured, en_passant, castle
    end

    # handle piece move
    @assert board[r1,f1,piece] "Piece not at field! $(SYMBOLS[1,piece]) $(field(r1,f1)) $(field(r2,f2))"

    board.position[r1,f1,piece] = false
    board.position[r1,f1,player] = false

    board.position[r2,f2,player] = true
    board.position[r2,f2,piece] = true

    # handle en passant
    # enable
    if (piece == PAWN) && abs(r1 - r2) == 2
        board.can_en_passant[white+1, f1] = true
    end

    # capture en passant
    if (piece == PAWN) && (abs(f1 - f2) == 1)
        if captured == nothing
            # landed on empty field -> must be en passant
            @assert board.can_en_passant[!white+1, f2] "Pawn moved diagonally but no en passant allowed."
            dir = white ? -1 : 1
            @assert board[r2+dir,f2,PAWN] && board[r2+dir,f2,opponent] "No pawn to capture in en passant"
            captured = (PAWN, r2+dir, f2)
            board.position[r2+dir,f2,PAWN] = false
            board.position[r2+dir,f2,opponent] = false
        end
    end


    # handle castle
    if piece == KING
        board.can_castle[white+1,:] .= false
        if f2 - f1 == 2 # castle short
            board.position[r1, 8, ROOK] = false
            board.position[r1, 8, player] = false

            board.position[r1, 6, ROOK] = true
            board.position[r1, 6, player] = true

            castle = (SHORTCASTLE, castle)
        elseif f1 - f2 == 2 # castle long
            board.position[r1, 1, ROOK] = false
            board.position[r1, 1, player] = false

            board.position[r1, 4, ROOK] = true
            board.position[r1, 4, player] = true

            castle = (LONGCASTLE, castle)
        end
    elseif piece == ROOK
        if (white && r1 == 1) || (!white && r1 == 8)
            if f1 == 1
                board.can_castle[white+1,LONGCASTLE] = false
            elseif f1 == 8
                board.can_castle[white+1,SHORTCASTLE] = false
            end
        end
    elseif captured != nothing
        # no castling for opponent if player captures his rook
        p, r, f = captured
        if p == ROOK
            if f2 == 1
                board.can_castle[!white+1,LONGCASTLE] = false
            elseif f2 == 8
                board.can_castle[!white+1,SHORTCASTLE] = false
            end
        end
    end

    return captured, en_passant, castle
end

function undo!(board::Board, white::Bool, piece::Piece, r1::Int, f1::Int, r2::Int, f2::Int, captured, en_passant, castle)
    player = 7 + !white
    opponent = 7 + white

    # handle promotions
    if piece == PAWNTOQUEEN || piece == PAWNTOKNIGHT
        board.position[r1,f1,PAWN] = true
        board.position[r1,f1,player] = true

        newpiece = piece == PAWNTOQUEEN ? QUEEN : KNIGHT
        board.position[r2,f2,newpiece] = false
        board.position[r2,f2,player] = false
    else
        # undo piece move
        board.position[r1,f1,piece] = true
        board.position[r1,f1,player] = true

        board.position[r2,f2,player] = false
        board.position[r2,f2,piece] = false
    end

    # undo capture (AFTER piece move (field must be free, important for same piece capture))
    if captured != nothing
        p, r, f = captured
        board.position[r,f,opponent] = true
        board.position[r,f,p] = true
    end


    if en_passant != nothing
        board.can_en_passant .= en_passant
    end

    if castle != nothing
        if piece == KING && castle isa Tuple
            i, bcastle = castle
            if i == LONGCASTLE # long castle
                board.position[r1, 4, ROOK] = false
                board.position[r1, 4, player] = false

                board.position[r1, 1, ROOK] = true
                board.position[r1, 1, player] = true
            end

            if i == SHORTCASTLE # short castle
                board.position[r1, 6, ROOK] = false
                board.position[r1, 8, player] = true

                board.position[r1, 8, ROOK] = true
                board.position[r1, 6, player] = false
            end
            board.can_castle .= bcastle
        else
            board.can_castle .= castle
        end
    end
end

#=
    rf1: current field as per FIELDS
    rf2: target field as per FIELDS
    p: piece as per PIECES
=#
function move!(board::Board, white::Bool, p::Piece, rf1::FieldSymbol, rf2::FieldSymbol)
    # moves are assumed to be valid
    move!(board, white, p, cartesian(FIELDS[rf1])..., cartesian(FIELDS[rf2])...)
end

function undo!(board::Board, white::Bool, p::Piece, rf1::FieldSymbol, rf2::FieldSymbol, captured, can_en_passant, can_castle)
    undo!(board, white, p, cartesian(FIELDS[rf1])..., cartesian(FIELDS[rf2])..., captured, can_en_passant, can_castle)
end

function move!(board::Board, white::Bool, p::PieceSymbol, rf1::Field, rf2::Field; verbose=false)
    @assert (PIECES[p], symbol(rf1), symbol(rf2)) in get_moves(board, white) "Invalid move!"

    captured, can_en_passant, can_castle = move!(board, white, PIECES[p], cartesian(rf1)..., cartesian(rf2)...)
    if verbose
        captured != nothing && println("Captured $(SYMBOLS[1,captured[1]]).")
        opponent = 7 + white
        check = is_check(board, opponent)
        n_moves = length(get_moves(board, !white))
        (check && n_moves > 0) && println("Check!")
        (check && n_moves == 0) && println("Checkmate!")
        (!check && n_moves == 0) && println("Stalemate!")
    end
    return captured, can_en_passant, can_castle
end

function undo!(board::Board, white::Bool, p::PieceSymbol, rf1::Field, rf2::Field, captured, cen_passant, castle)
    undo!(board, white, PIECES[p], cartesian(rf1)..., cartesian(rf2)..., captured, en_passant, castle)
end

import Base.show
function Base.show(io::IO, board::Board)
    cols = [:white, :blue, :red]

    println(io, "Chess Board")
    for rank in 8:-1:1
        print(io,"$rank ")
        for file in 1:8
            s = "⋅"
            if sum(board[rank,file,:]) != 0
                piece = argmax(board[rank,file,1:6])
                s = SYMBOLS[1, piece]

                if any(board[rank,file,7:8])
                    si = 0
                    if board[rank,file,7]
                        si = 1
                    end
                    if board[rank,file,8]
                        if si == 0
                            si = 2
                        else
                            # error
                            si = 3
                        end
                        s = lowercase(s)
                    end

                    print(io, "$s ")

                    # printstyled(io, "$s ", color=cols[si], bold=true)
                    continue
                end
            end

            printstyled(io,"$s ", bold=true)
        end
        print(io,"\n")
    end
    println(io,"  a b c d e f g h")
end

function print_board(board::Board; highlight=nothing, white=true)
    cols = [:white, :blue, :red]

    highlight_fields = []
    if highlight != nothing && white != nothing
        if highlight != "."
            p = PIECES[highlight[1]]
            rf = symbol(highlight[2:3])
            moves = get_moves(board, white)
            highlight_moves = filter(m -> m[1] == p && m[2] == rf, moves)
        else
            highlight_moves = get_moves(board, white)
        end
        highlight_fields = map(m -> cartesian(field(m[3])), highlight_moves)
    end

    println("Chess Board")

    ranks = white ? (8:-1:1) : (1:8)
    files = white ? (1:8) : (8:-1:1)

    for rank in ranks
        printstyled("$rank ", color=:magenta) # col = 13
        for file in files
            s = "•" #"⦿" # "⋅"
            if sum(board[rank,file,:]) != 0
                piece = findfirst(board[rank,file,1:6])
                if piece == nothing
                    printstyled("X ", color=:red, bold=true)
                    continue
                end
                if any(board[rank,file,7:8])
                    si = 0
                    if board[rank,file,7]
                        si = 1
                    end
                    if board[rank,file,8]
                        if si == 0
                            si = 2
                        else
                            # error
                            si = 3
                        end
                    end

                    s = SYMBOLS[1, piece]

                    col = cols[si]
                    if (rank, file) in highlight_fields
                        col = :red
                    end

                    if all(board[rank,file,7:8])
                        col = :magenta
                    end

                    printstyled("$s ", color=col, bold=true)
                    continue
                end
            end
            col = :light_black # 8
            if (rank, file) in highlight_fields
                col = :green
            end

            printstyled("$s ", bold=true, color=col)
        end
        print("\n")
    end
    if white
        printstyled("  a b c d e f g h", color=:magenta) # col = 13
    else
        printstyled("  h g f e d c b a", color=:magenta) # col = 13
    end
end




function user_input(board, white)
    got_move = false
    p, rf1, rf2 = (nothing, nothing, nothing)
    while !got_move
        try
            print(white ? "White: " : "Black: ")
            s = readline()
            if occursin("highlight ", s)
                print_board(board, highlight=s[11:end], white=white)
                println()
                continue
            end
            if occursin("undo", s)
                return "undo", false, false
            end
            if occursin("abort", s)
                return "abort", false, false
            end
            if occursin("resign", s)
                return "resign", false, false
            end

            p, rf1, rf2 = short_to_long(board, white, s)
            got_move = true
        catch e
            if e isa InterruptException
                println("\nGame aborted!")
                return "abort", false, false
            elseif e isa AssertionError
                println(e.msg)
            else
                println(e)
            end
        end
    end
    return p, rf1, rf2
end


struct Ply
    nr::Int
    n_move::Int
    board::Board # board after move
    white::Bool # white to move at board
    move # last move that lead to board
    time::Float64
end

import Base.show
using Printf
function Base.show(io::IO, ply::Ply)
    print(io, @sprintf "%d. %s %.2fs (%d)" ply.n_move ply.move ply.time ply.nr)
end

function play_game(board = Board(), white = true; white_player=user_input, black_player=user_input)
    game_history = [Ply(0, 0, deepcopy(board), white, (0x0, 0x0, 0x0), 0.)] # current board, white to move, last move
    n_ply = 1
    # try
    while true
        n_move = (n_ply+1) ÷ 2
        println("\nMove $n_move, Ply $n_ply:")
        #print("\u1b[10F")
        print_board(board)
        println()

        n_moves = length(get_moves(board, white))
        check = is_in_check(board, white ? WHITE : BLACK)
        done = n_moves == 0
        !done && check && println("Check!")
        done && check && println("Checkmate!")
        done && !check && println("Stalemate!")

        piece_count = sum(board[:,:,BLACK]) + sum(board[:,:,WHITE])
        if piece_count ≤ 3
            if !(any(board[:,:,QUEEN]) || any(board[:,:,ROOK]) || any(board[:,:,PAWN]))
                done = true
                println("Draw!")
            end
        end
        if length(game_history) ≥ 3
            for ply in game_history
                board_rep = 0
                for ply´ in game_history
                    if ply.board == ply´.board
                        board_rep += 1
                    end
                end
                if board_rep ≥ 3
                    done = true
                    println("Draw by repetition!")
                    break
                end
            end
        end



        v,move_time, = @timed if !done
            if white
                p, rf1, rf2 = white_player(board, true)
            else
                p, rf1, rf2 = black_player(board, false)
            end
        end

        done && break

        if p == "undo"
            pop!(game_history) # opponent move
            pop!(game_history) # my move
            last_ply = game_history[end]
            n_ply -= 2
            board = last_ply.board
            white = last_ply.white
            continue
        end
        if p == "abort" || p == "resign"
            break
        end

        move!(board, white, p, rf1, rf2)
        white = !white
        push!(game_history, Ply(n_ply, n_move, deepcopy(board), white, (p, rf1, rf2), move_time))

        n_ply += 1
    end
    # catch e
    #     println(e)
    # end
    return game_history
end


function testbool(r1::Int, r2::Int, piece::UInt8)
    println(r2 - r1)
    b1 = piece==PAWN
    println(b1, typeof(b1))
    b2 = (abs(r1 - r2) == 2)
    println(b2, typeof(b2))
    println(b1 && b2)
    println((piece==PAWN) && (abs(r1 - r2) == 2))
    println((piece == PAWN) && (abs((r1 - r2) == 2)))
end
