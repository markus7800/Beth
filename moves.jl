Move = Tuple{Piece, FieldSymbol, FieldSymbol}

function Base.show(io::IO, m::Move)
    print(io, "$(SYMBOLS[1,m[1]]): $(FIELDS[m[2]])-$(FIELDS[m[3]])")
end


function get_moves(board::Board, white::Bool)
    player = 7 + !white
    opponent = 7 + white
    moves = Move[]
    for rank in 1:8, file in 1:8
        !board[rank, file, player] && continue
        #println("Piece: $(SYMBOLS[1,findfirst(board[rank,file,:])]) at $(field(rank,file)) ($rank $file)")

        DIAG = [(-1,-1), (1,-1), (-1, 1), (1, 1)]
        CROSS = [(0,1), (0,-1), (1,0), (-1,0)]
        KNIGHTMOVES = [
                (1,2), (1,-2), (-1,2), (-1,-2),
                (2,1), (2,-1), (-2,1), (-2,-1)
                ]

        if board[rank, file, PAWN]
            # rank cannot be 1, 8 since then AUTOQUEEN
            append!(moves, pawn_moves(board, white, rank, file))

        elseif board[rank, file, BISHOP]
            append!(moves, direction_moves(board,player,opponent,BISHOP,rank,file,DIAG,8))

        elseif board[rank, file, KNIGHT]
            append!(moves, direction_moves(board,player,opponent,KNIGHT,rank,file,KNIGHTMOVES,1))

        elseif board[rank, file, ROOK]
            append!(moves, direction_moves(board,player,opponent,ROOK,rank,file,CROSS,8))

        elseif board[rank, file, QUEEN]
            append!(moves, direction_moves(board,player,opponent,QUEEN,rank,file,vcat(DIAG, CROSS),8))

        elseif board[rank, file, KING]
            kingmoves = direction_moves(board,player,opponent,KING,rank,file,vcat(DIAG, CROSS),1)
            # TODO: filter for checks
            append!(moves, kingmoves)
        end
    end
    return moves
end

function pawn_moves(board, white, rank, file)
    moves = Move[]
    if white && !any(board[rank+1, file, 7:8])
        push!(moves, (PAWN, symbol(rank, file), symbol(rank+1, file)))
    elseif !white && !any(board[rank-1, file, 7:8])
        push!(moves, (PAWN, symbol(rank, file), symbol(rank-1, file)))
    end

    # captures
    if white && file-1≥1 && board[rank+1, file-1, BLACK]
        push!(moves, (PAWN, symbol(rank, file), symbol(rank+1, file-1)))
    elseif white && file+1≤8 && board[rank+1, file+1, BLACK]
        push!(moves, (PAWN, symbol(rank, file), symbol(rank+1, file+1)))
    elseif !white && file-1≥1 && board[rank-1, file-1, BLACK]
        push!(moves, (PAWN, symbol(rank, file), symbol(rank-1, file-1)))
    elseif !white && file+1≤8 && board[rank-1, file+1, BLACK]
        push!(moves, (PAWN, symbol(rank, file), symbol(rank-1, file+1)))
    end

    # TODO: EN PASSANT
    return moves
end

function direction_moves(board, player, opponent, piece, rank, file, directions, max_multiple)
    moves = Move[]
    dirs_finished = falses(length(directions))
    for i in 1:max_multiple
        for (d, dir) in enumerate(directions)
            dirs_finished[d] && continue

            r2, f2 = (rank, file) .+ i .* dir

            if r2 < 1 || r2 > 8 || f2 < 1 || f2 > 8
                # direction out of bounds
                dirs_finished[d] = true
                continue
            end

            if board[r2, f2, opponent] || !board[r2, f2, player]
                # capture || free tile
                push!(moves, (piece, symbol(rank, file), symbol(r2, f2)))
            else # == board[r2, f2, player]
                # directiob blocked by own piece
                dirs_finished[d] = true
            end
        end

        all(dirs_finished) && break
    end
    return moves
end
# diags = [(-1,-1), (1,-1), (-1, 1), (1, 1)]
# diags_finished = [false, false, false, false]
# for i in 1:8, (d, diag) in enumerate(diags)
#     diags_finished[d] && continue
#
#     r2, f2 = (rank, file) .+ i * diag
#     if board[r2, f2, opponent] || !board[r2, f2, player]
#         # capture || free tile
#         push!(moves, (BISHOP, symbol(rank, file), symbol(r2, f2)))
#     else # == board[r2, f2, player]
#         diags_finished[d] = true
#     end
#
#     if r2 in [1,8] || f2 in [1,8]
#         # border reached
#         diags_finished[d] = true
#     end
# end
