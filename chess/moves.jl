# TODO: check @inbounds

Move = Tuple{Piece, FieldSymbol, FieldSymbol}

function Base.show(io::IO, m::Move)
    if m == (0x00, 0x00, 0x00)
        print(io, "Empty Move")
    else
        try
            print(io, "$(SYMBOLS[1,m[1]]): $(FIELDS[m[2]])-$(FIELDS[m[3]])")
        catch
            print(io, "Unknown Move")
        end
    end
end

const PAWNDIAG = [[(-1, 1), (-1, -1)], [(1, 1), (1, -1)]] # black at 1, white at 2
const DIAG = [(-1,-1), (1,-1), (-1, 1), (1, 1)]
const CROSS = [(0,1), (0,-1), (1,0), (-1,0)]
const KNIGHTMOVES = [
        (1,2), (1,-2), (-1,2), (-1,-2),
        (2,1), (2,-1), (-2,1), (-2,-1)
        ]
const DIAGCROSS = vcat(DIAG, CROSS)

function get_moves(board::Board, white::Bool)
    player = 7 + !white
    opponent = 7 + white
    moves = Move[]
    kingpos = (-10, -10) # move off board for evaluation without kings
    for rank in 1:8, file in 1:8
        !board[rank, file, player] && continue
        #println("Piece: $(SYMBOLS[1,findfirst(board[rank,file,:])]) at $(field(rank,file)) ($rank $file)")

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
            append!(moves, direction_moves(board,player,opponent,QUEEN,rank,file,DIAGCROSS,8))

        elseif board[rank, file, KING]
            kingpos = (rank, file)
            kingmoves = king_moves(board,white,player,opponent,rank,file)
            append!(moves, kingmoves)
        end
    end

    filter!(m -> !is_check(board, player, opponent, kingpos, m), moves)

    return moves
end

function get_pseudo_legal_moves(board::Board, white::Bool)
    player = 7 + !white
    opponent = 7 + white
    moves = Move[]
    kingpos = (-10, -10) # move off board for evaluation without kings
    for rank in 1:8, file in 1:8
        !board[rank, file, player] && continue
        #println("Piece: $(SYMBOLS[1,findfirst(board[rank,file,:])]) at $(field(rank,file)) ($rank $file)")

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
            append!(moves, direction_moves(board,player,opponent,QUEEN,rank,file,DIAGCROSS,8))

        elseif board[rank, file, KING]
            kingpos = (rank, file)
            kingmoves = king_moves(board,white,player,opponent,rank,file)
            append!(moves, kingmoves)
        end
    end

    return moves
end


function king_moves(board, white, player, opponent, rank, file)
    kingmoves = direction_moves(board,player,opponent,KING,rank,file,DIAGCROSS,1)

    if !is_attacked(board, player, opponent, (rank, file))
        if board.can_castle[white+1, LONGCASTLE] && !any(board[rank, 2:4, 7:8]) && all(board[rank,1,[ROOK,player]])
            if !is_attacked(board, player, opponent, (rank, 3)) && !is_attacked(board, player, opponent, (rank, 4))
                # castle long
                push!(kingmoves, (KING, symbol(rank, file), symbol(rank, file-2)))
            end
        end
        if board.can_castle[white+1, SHORTCASTLE] && !any(board[rank, 6:7, 7:8]) && all(board[rank,8,[ROOK,player]])
            if !is_attacked(board, player, opponent, (rank, 6)) && !is_attacked(board, player, opponent, (rank, 7))
                # castle short
                push!(kingmoves, (KING, symbol(rank, file), symbol(rank, file+2)))
            end
        end
    end
    return kingmoves
end

function pawn_moves(board, white, rank, file)
    moves = Move[]
    # normal moves
    if white && !any(board[rank+1, file, 7:8])
        push!(moves, (PAWN, symbol(rank, file), symbol(rank+1, file)))
    elseif !white && !any(board[rank-1, file, 7:8])
        push!(moves, (PAWN, symbol(rank, file), symbol(rank-1, file)))
    end

    # start moves
    if white && rank == 2 && !any(board[rank+1:rank+2, file, 7:8])
        push!(moves, (PAWN, symbol(rank, file), symbol(rank+2, file)))
    elseif !white && rank == 7 && !any(board[rank-2:rank-1, file, 7:8])
        push!(moves, (PAWN, symbol(rank, file), symbol(rank-2, file)))
    end

    # captures
    if white && file-1≥1 && board[rank+1, file-1, BLACK]
        push!(moves, (PAWN, symbol(rank, file), symbol(rank+1, file-1)))
    end
    if white && file+1≤8 && board[rank+1, file+1, BLACK]
        push!(moves, (PAWN, symbol(rank, file), symbol(rank+1, file+1)))
    end
    if !white && file-1≥1 && board[rank-1, file-1, WHITE]
        push!(moves, (PAWN, symbol(rank, file), symbol(rank-1, file-1)))
    end
    if !white && file+1≤8 && board[rank-1, file+1, WHITE]
        push!(moves, (PAWN, symbol(rank, file), symbol(rank-1, file+1)))
    end

    # en passant
    if white && rank == 5
        if file+1≤8 && board.can_en_passant[1,file+1] && all(board[rank, file+1, [PAWN, BLACK]])
            push!(moves, (PAWN, symbol(rank, file), symbol(rank+1, file+1)))
        elseif file-1≥1 && board.can_en_passant[1,file-1] && all(board[rank, file-1, [PAWN, BLACK]])
            push!(moves, (PAWN, symbol(rank, file), symbol(rank+1, file-1)))
        end
    elseif !white && rank == 4
        if file+1≤8 && board.can_en_passant[2,file+1] && all(board[rank, file+1, [PAWN, WHITE]])
            push!(moves, (PAWN, symbol(rank, file), symbol(rank-1, file+1)))
        elseif file-1≥1 && board.can_en_passant[2,file-1] && all(board[rank, file-1, [PAWN, WHITE]])
            push!(moves, (PAWN, symbol(rank, file), symbol(rank-1, file-1)))
        end
    end

    # promotions
    if (white && rank == 7) || (!white && rank == 2)
        knight_promo = map(m-> (PAWNTOKNIGHT, m[2], m[3]), moves)
        queen_promo = map(m-> (PAWNTOQUEEN, m[2], m[3]), moves)
        moves = vcat(knight_promo, queen_promo)
    end

    return moves
end

function direction_moves(board, player, opponent, piece, rank, file, directions, max_multiple)
    moves = Move[]
    for dir in directions
        for i in 1:max_multiple

            r2, f2 = (rank, file) .+ i .* dir

            if r2 < 1 || r2 > 8 || f2 < 1 || f2 > 8
                # direction out of bounds
                break # direction finished
            end

            if board[r2, f2, opponent]
                # capture
                push!(moves, (piece, symbol(rank, file), symbol(r2, f2)))
                break # direction finished
            elseif !board[r2, f2, player]
                # free tile
                push!(moves, (piece, symbol(rank, file), symbol(r2, f2)))
            elseif board[r2, f2, player]
                # direction blocked by own piece
                break # direction finished
            end
        end
    end
    return moves
end



# checks if king of player is in check after move
# kingpos is position of king before move
function is_check(board::Board, player::Int, opponent::Int, king_pos::Tuple{Int,Int}, move::Move)
    p, rf1, rf2 = move

    # TODO: remove
    # _board = deepcopy(board)
    #
    # ass = true
    # if !is_valid(board)
    #     @info("Invalid Board!")
    #     print_board(board, white=false)
    #     println()
    #     display(board.position)
    #     ass = false
    # end


    captured, can_enpassant, can_castle = move!(board, player==WHITE, p, rf1, rf2)
    if p == KING
        # update king position for king move
        king_pos = cartesian(field(rf2))
    end

    # if !is_valid(board)
    #     @info("Move invalid: Position $player $king_pos $move")
    #     print_board(board, white=white)
    #     println()
    #     display(board.position)
    #     ass = false
    # end

    b = is_attacked(board, player, opponent, king_pos)
    undo!(board, player==WHITE, p, rf1, rf2, captured, can_enpassant, can_castle)

    # if any(board.position .!= _board.position)
    #     @info("Undo failed: Position $player $king_pos $move")
    #     print_board(board, white=false)
    #     println()
    #     print_board(_board, white=false)
    #     display(board.position)
    #     display(_board.position)
    #     println()
    #     ass = false
    # end
    # if any(board.can_en_passant .!= _board.can_en_passant)
    #     @info("Undo failed: Enpassant $player $king_pos $move")
    #     print_board(board, white=false)
    #     println()
    #     display(board.can_en_passant)
    #     display(_board.can_en_passant)
    #     ass = false
    # end
    # if any(board.can_castle .!= _board.can_castle)
    #     @info("Undo failed: Castle $player $king_pos $move")
    #     print_board(board, white=false)
    #     println()
    #     display(board.can_castle)
    #     display(_board.can_castle)
    #     ass = false
    # end
    # @assert ass "UNDO FAILED!"

    return b
end

# checks if field rf (cartesian) is attacked by opponent
function is_attacked(board::Board, player, opponent, rf; verbose=false)
    r, f = rf

    # check knight moves
    for dir in KNIGHTMOVES
        r2, f2 = (r,f) .+ dir
        (r2 < 1 || r2 > 8 || f2 < 1 || f2 > 8) && continue

        if board[r2, f2, opponent] && board[r2, f2, KNIGHT]
            verbose && println("Knight check from $(field(r2, f2)) ($r2, $f2).")
            return true
        end
    end

    # check diags
    for (d, dir) in enumerate(DIAG)
        for i in 1:8
            r2, f2 = (r,f) .+ i .* dir

            if r2 < 1 || r2 > 8 || f2 < 1 || f2 > 8
                # direction out of bounds
                break
            end

            if board[r2, f2, opponent]
                if i == 1 && board[r2, f2, KING]
                    verbose && println("King diag check from $(field(r2, f2)) ($r2, $f2).")
                    return true
                end
                if (board[r2, f2, BISHOP] || board[r2, f2, QUEEN])
                    verbose && println("Diag check from $(field(r2, f2)) ($r2, $f2).")
                    return true
                else
                    # direction blocked by opponent piece
                    break
                end
            elseif board[r2, f2, player]
                # direction blocked by own piece
                break
            end
        end
    end

    # check crosses
    for (d, dir) in enumerate(CROSS)
        for i in 1:8
            r2, f2 = (r,f) .+ i .* dir

            if r2 < 1 || r2 > 8 || f2 < 1 || f2 > 8
                # direction out of bounds
                break
            end

            if board[r2, f2, opponent]
                if i == 1 && board[r2, f2, KING]
                    verbose && println("King cross check from $(field(r2, f2)) ($r2, $f2).")
                    return true
                end
                if (board[r2, f2, ROOK] || board[r2, f2, QUEEN])
                    verbose && println("Cross check from $(field(r2, f2)) ($r2, $f2).")
                    return true
                else
                    # direction blocked by opponent piece
                    break
                end
            elseif board[r2, f2, player]
                # directiob blocked by own piece
                break
            end
        end
    end

    # check pawn
    dir = player == WHITE ? 1 : -1
    if r+dir ≥ 1 && r+dir ≤ 8
        if f-1 ≥ 1 && board[r+dir, f-1, opponent] && board[r+dir, f-1, PAWN]
            verbose && println("Pawn check from $(field(r+dir, f-1)) $((r+dir, f-1)).")
            return true
        elseif f+1 ≤ 8 && board[r+dir, f+1, opponent] && board[r+dir, f+1, PAWN]
            verbose && println("Pawn check from $(field(r+dir, f+1)) $((r+dir, f+1)).")
            return true
        end
    end
    return false
end

function is_in_check(board::Board, player; kw...)
    opponent = player == WHITE ? BLACK : WHITE
    kingpos = findall(board[:,:,KING])
    r, f = Tuple(kingpos[1])
    if board[r, f, opponent]
        r, f = Tuple(kingpos[2])
    end
    return is_attacked(board, player, opponent, (r,f); kw...)
end

function chebyshev_distance(f1::FieldSymbol, rank, file)
    c1 = cartesian(field(f1))
    return max(abs(c1[1] - rank), abs(c1[2] - file))
end

function reverse_direction_moves(board, player, opponent, piece, rank, file, directions, max_multiple)
    moves = Move[]
    for dir in directions
        for i in 1:max_multiple

            r2, f2 = (rank, file) .+ i .* dir

            if r2 < 1 || r2 > 8 || f2 < 1 || f2 > 8
                # direction out of bounds
                break # direction finished
            end

            if !board[r2, f2, player] && !board[r2, f2, opponent]
                # free tile
                push!(moves, (piece, symbol(r2, f2), symbol(rank, file)))
            else
                # direction blocked by own piece or opponent piece
                break # direction finished
            end
        end
    end
    return moves
end

# checks if king_pos (opponent) would be in check if player undid move
function would_be_check(board::Board, player::Int, opponent::Int, king_pos::Tuple{Int,Int}, move::Move)
    p, rf1, rf2 = move

    undo!(board, player==WHITE, p, rf1, rf2, nothing, nothing, nothing)

    b = is_attacked(board, opponent, player, king_pos)

    move!(board, player==WHITE, p, rf1, rf2)

    return b
end

function get_reverse_moves(board::Board, white::Bool; promotions=false)
    player = 7 + !white
    opponent = 7 + white
    moves = Move[]
    opponent_kingpos = (-10, -10) # move off board for evaluation without kings
    king_moves = Move[]

    if is_in_check(board, player)
        # cant do move that leads to being in check
        return moves
    end

    for rank in 1:8, file in 1:8
        if board[rank, file, KING] && board[rank, file, opponent]
            opponent_kingpos = (rank, file)
        end

        !board[rank, file, player] && continue
        #println("Piece: $(SYMBOLS[1,findfirst(board[rank,file,:])]) at $(field(rank,file)) ($rank $file)")

        if board[rank, file, PAWN]
            if white
                if rank > 2 && !any(board[rank-1,file,:])
                    push!(moves, (PAWN, symbol(rank-1, file), symbol(rank, file)))
                end
                if rank == 4 && !any(board[rank-2,file,:]) && !any(board[rank-1,file,:])
                    push!(moves, (PAWN, symbol(rank-2, file), symbol(rank, file)))
                end
            else
                if rank < 7 && !any(board[rank+1,file,:])
                    push!(moves, (PAWN, symbol(rank+1, file), symbol(rank, file)))
                end
                if rank == 5 && !any(board[rank+2,file,:]) && !any(board[rank+1,file,:])
                    push!(moves, (PAWN, symbol(rank+2, file), symbol(rank, file)))
                end
            end
        elseif board[rank, file, BISHOP]
            append!(moves, reverse_direction_moves(board,player,opponent,BISHOP,rank,file,DIAG,8))

        elseif board[rank, file, KNIGHT]
            append!(moves, reverse_direction_moves(board,player,opponent,KNIGHT,rank,file,KNIGHTMOVES,1))

        elseif board[rank, file, ROOK]
            append!(moves, reverse_direction_moves(board,player,opponent,ROOK,rank,file,CROSS,8))

        elseif board[rank, file, QUEEN]
            append!(moves, reverse_direction_moves(board,player,opponent,QUEEN,rank,file,DIAGCROSS,8))
            if promotions
                if white
                    if rank == 8 && !any(board[rank-1,file,:])
                        push!(moves, (PAWNTOQUEEN, symbol(rank-1, file), symbol(rank, file)))
                    end
                else
                    if rank == 1 && !any(board[rank+1,file,:])
                        push!(moves, (PAWNTOQUEEN, symbol(rank+1, file), symbol(rank, file)))
                    end
                end
            end
        elseif board[rank, file, KING]
            king_moves = reverse_direction_moves(board,player,opponent,KING,rank,file,DIAGCROSS,1)
        end
    end

    filter!(m -> chebyshev_distance(m[2], opponent_kingpos...) > 1, king_moves)

    append!(moves, king_moves)

    # opponent king can not have been in check when player was to move
    filter!(m -> !would_be_check(board, player, opponent, opponent_kingpos, m), moves)

    return moves
end

function short_to_long(board::Board, white::Bool, s::String)
    # println("Input: $s")
    # todo
    if s == "O-O"
        return (KING, symbol("e1"), symbol("g1"))
    end
    if s == "O-O-O"
        return (KING, symbol("e1"), symbol("c1"))
    end

    s = replace(s, "x" => "") # remove captures
    s = replace(s, "+" => "") # remove check

    # handle pawn
    if islowercase(s[1])
        s = 'P' * s
    end

    p = s[1]
    @assert p in PIECES.keys "Invalid piece!"
    piece = PIECES[p]

    # handle promotion
    if s[end] in PIECES.keys && s[1] == 'P'
        if s[end] == 'N'
            piece = PAWNTOKNIGHT
        else
            piece = PAWNTOQUEEN
        end
        s = s[1:end-1]
    end


    s = s[2:end]

    # println("Piece: $p")

    ms = get_moves(board, white)

    f = s[end-1:end] # field
    piece_moves = filter(m->m[1]==piece && m[3] == symbol(f), ms)
    @assert length(piece_moves) > 0 "No moves!"

    if length(s) == 2
        # println("Move unique because of target tile.")
        @assert length(piece_moves) == 1 "Not unique move!"
        return first(piece_moves)
    else
        id = s[1:end-2]
        if length(id) == 1
            x = Int(id[1])
            if x ≥ 96
                # println("Move unique because file given.")
                # file given
                file = x - 96
                filtered_moves = filter(m-> cartesian(field(m[2]))[2] == file, piece_moves)
                @assert length(filtered_moves) == 1 "Not unique move!"
                return first(filtered_moves)
            else
                # println("Move unique because rank given.")
                # rank given
                rank = x - 48
                filtered_moves = filter(m-> cartesian(field(m[2]))[1] == rank, piece_moves)
                @assert length(filtered_moves) == 1 "Not unique move!"
                return first(filtered_moves)
            end
        else
            @assert length(id) == 2
            # println("Move unique because rank and file given.")
            # rank and file given
            filtered_moves = filter(m-> field(m[2]) == id, piece_moves)
            @assert length(filtered_moves) == 1
            return first(filtered_moves)
        end
    end
end
