struct Board
    position::BitArray{3}
    # rows are ranks
    # columns are files
    # c2 -> (2,c) -> (2, 3)
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
function move!(board::Board, white::Bool, piece::Int, r1::Int, f1::Int, r2::Int, f2::Int)
    player = 7 + !white
    opponent = 7 + white
    @assert board[r1,f1,player] "No piece for player at $r1, $(f1)!"
    @assert !board[r2,f2,player] "Player tried to capture own piece!"
    if board[r2,f2,opponent]
        println("Captures!")
    end

    board[r2,f2,:] .= false # remove all figures from target field

    board[r1,f1,piece] = false
    board[r2,f2,piece] = true

    board[r1,f1,player] = false
    board[r2,f2,player] = true
end

#=
    rf1: current field as per FIELDS
    rf2: target field as per FIELDS
    p: piece as per PIECES
=#
function move!(board::Board, white::Bool, p::Char, rf1::Char, rf2::Char)
    move!(board, white, PIECES[p], cartesian(FIELDS[rf1])..., cartesian(FIELDS[rf2])...)
end

function move!(board::Board, white::Bool, p::Char, rf1::String, rf2::String)
    move!(board, white, PIECES[p], cartesian(rf1)..., cartesian(rf2)...)
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
        println(highlight_moves)
    end

    println("Chess Board")
    for rank in 8:-1:1
        print("$rank ")
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
            col = :white
            if (rank, file) in highlight_fields
                col = :green
            end

            printstyled("$s ", bold=true, color=col)
        end
        print("\n")
    end
    println("  a b c d e f g h")
end
