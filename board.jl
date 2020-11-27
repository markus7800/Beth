struct Board
    position::BitArray{3}
    # rows are ranks
    # columns are files
    # c2 -> (2,c) -> (2, 3)

    # TODO: validate by xoring
    function Board(start=true)
        position = falses(8, 8, 8)
        if start
            position[[2,7],:,PAWN] .= 1
            position[[1,8], [3,6], BISHOP] .= 1
            position[[1,8], [2,7], KNIGHT] .= 1
            position[[1,8], [1,8], ROOK] .= 1
            position[[1,8], 4, QUEEN] .= 1 # d für dame
            position[[1,8], 5, KING] .= 1
            position[[1,2], :, WHITE] .= 1
            position[[7,8], :, BLACK] .= 1
        end
        return new(position)
    end
end

import Base.getindex
function Base.getindex(b::Board, I...)
    Base.getindex(b.position, I...)
end
import Base.setindex!
function Base.setindex!(b::Board, I...)
    Base.setindex!(b.position, I...)
end


#=
    r1, f1: current field
    r2, f2: target field
    piece: 1-6
=#
function move!(board::Board, white::Bool, piece::Piece, r1::Int, f1::Int, r2::Int, f2::Int)
    player = 7 + !white
    opponent = 7 + white
    @assert board[r1,f1,player] "No piece for player at $r1, $(f1)!"
    @assert !board[r2,f2,player] "Player tried to capture own piece! $(SYMBOLS[1,piece]) $(field(r1,f1)) $(field(r2,f2))"

    captured = nothing
    if board[r2,f2,opponent]
        # remove captured piece
        captured = findfirst(board[r2,f2,1:6])
        board[r2,f2,captured] = false
        board[r2,f2,opponent] = false
    end

    board[r1,f1,piece] = false
    board[r2,f2,piece] = true

    board[r1,f1,player] = false
    board[r2,f2,player] = true

    return captured
end

function undo!(board::Board, white::Bool, piece::Piece, r1::Int, f1::Int, r2::Int, f2::Int, captured)
    player = 7 + !white
    opponent = 7 + white

    board[r1,f1,piece] = true
    board[r2,f2,piece] = false

    board[r1,f1,player] = true
    board[r2,f2,player] = false

    if captured != nothing
        board[r2,f2,opponent] = true
        board[r2,f2,captured] = true
    end
end

#=
    rf1: current field as per FIELDS
    rf2: target field as per FIELDS
    p: piece as per PIECES
=#
function move!(board::Board, white::Bool, p::Piece, rf1::FieldSymbol, rf2::FieldSymbol)
    move!(board, white, p, cartesian(FIELDS[rf1])..., cartesian(FIELDS[rf2])...)
end

function undo!(board::Board, white::Bool, p::Piece, rf1::FieldSymbol, rf2::FieldSymbol, captured)
    undo!(board, white, p, cartesian(FIELDS[rf1])..., cartesian(FIELDS[rf2])..., captured)
end

function move!(board::Board, white::Bool, p::PieceSymbol, rf1::Field, rf2::Field; verbose=false)
    captured = move!(board, white, PIECES[p], cartesian(rf1)..., cartesian(rf2)...)
    if verbose
        captured != nothing && println("Captured $(SYMBOLS[1,captured]).")
        opponent = 7 + white
        check = is_check(board, opponent)
        n_moves = length(get_moves(board, !white))
        (check && n_moves > 0) && println("Check!")
        (check && n_moves == 0) && println("Checkmate!")
        (!check && n_moves == 0) && println("Stalemate!")
    end
    return captured
end

function undo!(board::Board, white::Bool, p::PieceSymbol, rf1::Field, rf2::Field, captured)
    undo!(board, white, PIECES[p], cartesian(rf1)..., cartesian(rf2)..., captured)
end

import Base.show
function Base.show(io::IO, board::Board)
    cols = [:white, :blue]

    println(io, "Chess Board")
    for rank in 8:-1:1
        print(io,"$rank ")
        for file in 1:8
            s = "⋅"
            if sum(board[rank,file,:]) != 0
                piece = argmax(board[rank,file,1:6])
                if any(board[rank,file,7:8])
                    si = findfirst(board[rank,file,7:8])
                    s = SYMBOLS[1, piece]

                    printstyled(io, "$s ", color=cols[si], bold=true)
                    continue
                end
            end

            printstyled(io,"$s ", bold=true)
        end
        print(io,"\n")
    end
    println(io,"  a b c d e f g h")
end

function print_board(board::Board; highlight=nothing, player=:white)
    cols = [:white, :blue]

    highlight_fields = []
    if highlight != nothing && player != nothing
        p = PIECES[highlight[1]]
        rf = symbol(highlight[2:3])
        moves = get_moves(board, player==:white)
        highlight_moves = filter(m -> m[1] == p && m[2] == rf, moves)
        highlight_fields = map(m -> cartesian(field(m[3])), highlight_moves)
    end

    println("Chess Board")
    for rank in 8:-1:1
        printstyled("$rank ", color=13)
        for file in 1:8
            s = "•" #"⦿" # "⋅"
            if sum(board[rank,file,:]) != 0
                piece = argmax(board[rank,file,1:6])
                if any(board[rank,file,7:8])
                    si = findfirst(board[rank,file,7:8])
                    s = SYMBOLS[1, piece]

                    col = cols[si]
                    if (rank, file) in highlight_fields
                        col = :red
                    end

                    printstyled("$s ", color=col, bold=true)
                    continue
                end
            end
            col = 8
            if (rank, file) in highlight_fields
                col = :green
            end

            printstyled("$s ", bold=true, color=col)
        end
        print("\n")
    end
    printstyled("  a b c d e f g h", color=13)
end
