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

    println(io, "Chess Board")
    for rank in 8:-1:1
        print(io,"$rank ")
        for file in 1:8
            s = "⋅"
            if sum(board[rank,file,:]) != 0
                piece = argmax(board[rank,file,1:6])
                if any(board[rank,file,7:8])
                    si = findfirst(board[rank,file,7:8])
                    s = SYMBOLS[si, piece]
                end
            end

            print(io,"$s ")
        end
        print(io,"\n")
    end
    println(io,"  a b c d e f g h")
end
