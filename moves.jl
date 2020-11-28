# TODO: check @inbounds

Move = Tuple{Piece, FieldSymbol, FieldSymbol}

function Base.show(io::IO, m::Move)
    print(io, "$(SYMBOLS[1,m[1]]): $(FIELDS[m[2]])-$(FIELDS[m[3]])")
end

const DIAG = [(-1,-1), (1,-1), (-1, 1), (1, 1)]
const CROSS = [(0,1), (0,-1), (1,0), (-1,0)]
const KNIGHTMOVES = [
        (1,2), (1,-2), (-1,2), (-1,-2),
        (2,1), (2,-1), (-2,1), (-2,-1)
        ]

function get_moves(board::Board, white::Bool)
    player = 7 + !white
    opponent = 7 + white
    moves = Move[]
    kingpos = (0,0)
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
            append!(moves, direction_moves(board,player,opponent,QUEEN,rank,file,vcat(DIAG, CROSS),8))

        elseif board[rank, file, KING]
            kingpos = (rank, file)
            kingmoves = king_moves(board,white,player,opponent,rank,file)
            append!(moves, kingmoves)
        end
    end

    filter!(m -> !is_check(board, player, opponent, kingpos, m), moves)

    return moves
end


function king_moves(board, white, player, opponent, rank, file)
    kingmoves = direction_moves(board,player,opponent,KING,rank,file,vcat(DIAG, CROSS),1)

    if board.can_castle[white+1, 1] && !any(board[rank, 2:4, player])
        # castle long
        push!(kingmoves, (KING, symbol(rank, file), symbol(rank, file-2)))
    end
    if board.can_castle[white+1, 2] && !any(board[rank, 6:7, player])
        # castle short
        push!(kingmoves, (KING, symbol(rank, file), symbol(rank, file+2)))
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
    if white && rank == 2 && !any(board[rank+2, file, 7:8])
        push!(moves, (PAWN, symbol(rank, file), symbol(rank+2, file)))
    elseif !white && rank == 7 && !any(board[rank-2, file, 7:8])
        push!(moves, (PAWN, symbol(rank, file), symbol(rank-2, file)))
    end

    # captures
    if white && file-1≥1 && board[rank+1, file-1, BLACK]
        push!(moves, (PAWN, symbol(rank, file), symbol(rank+1, file-1)))
    elseif white && file+1≤8 && board[rank+1, file+1, BLACK]
        push!(moves, (PAWN, symbol(rank, file), symbol(rank+1, file+1)))
    elseif !white && file-1≥1 && board[rank-1, file-1, WHITE]
        push!(moves, (PAWN, symbol(rank, file), symbol(rank-1, file-1)))
    elseif !white && file+1≤8 && board[rank-1, file+1, WHITE]
        push!(moves, (PAWN, symbol(rank, file), symbol(rank-1, file+1)))
    end

    # en passant
    if white && rank == 5
        if file+1≤8 && board.can_en_passant[2,file+1] && all(board[rank, file+1, [PAWN, BLACK]])
            push!(moves, (PAWN, symbol(rank, file), symbol(rank+1, file+1)))
        elseif file-1≥1 && board.can_en_passant[2,file-1] && all(board[rank, file-1, [PAWN, BLACK]])
            push!(moves, (PAWN, symbol(rank, file), symbol(rank+1, file-1)))
        end
    elseif !white && rank == 7
        if file+1≤8 && board.can_en_passant[1,file+1] && all(board[rank, file+1, [PAWN, WHITE]])
            push!(moves, (PAWN, symbol(rank, file), symbol(rank-1, file+1)))
        elseif file-1≥1 && board.can_en_passant[1,file-1] && all(board[rank, file-1, [PAWN, WHITE]])
            push!(moves, (PAWN, symbol(rank, file), symbol(rank-1, file-1)))
        end
    end

    # promotions
    if white && rank == 7 && !any(board[8, file, [WHITE, BLACK]])
        push!(moves, (PAWNTOQUEEN, symbol(rank, file), symbol(8, file)))
        push!(moves, (PAWNTOKNIGHT, symbol(rank, file), symbol(8, file)))
    elseif !white && rank == 2 && !any(board[1, file, [WHITE, BLACK]])
        push!(moves, (PAWNTOQUEEN, symbol(rank, file), symbol(1, file)))
        push!(moves, (PAWNTOKNIGHT, symbol(rank, file), symbol(1, file)))
    end

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

# checks if king of player is in check after move
# kingpos is position of king before move
function is_check(board::Board, player::Int, opponent::Int, king_pos::Tuple{Int,Int}, move::Move)
    p, rf1, rf2 = move
    captured, can_enpassant, can_castle = move!(board, player==WHITE, p, rf1, rf2)
    if p == KING
        # update king position for king move
        king_pos = cartesian(field(rf2))
    end
    b = is_check(board, player, opponent, king_pos)
    undo!(board, player==WHITE, p, rf1, rf2, captured, can_enpassant, can_castle)
    return b
end

# checks if king of player os om check at king_pos
function is_check(board::Board, player, opponent, king_pos; verbose=false)
    r, f = king_pos

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
    diags_finished = falses(length(DIAG))
    for i in 1:8
        for (d, dir) in enumerate(DIAG)
            diags_finished[d] && continue

            r2, f2 = (r,f) .+ i .* dir

            if r2 < 1 || r2 > 8 || f2 < 1 || f2 > 8
                # direction out of bounds
                diags_finished[d] = true
                continue
            end

            if board[r2, f2, opponent] && (board[r2, f2, BISHOP] || board[r2, f2, QUEEN])
                verbose && println("Diag check from $(field(r2, f2)) ($r2, $f2).")
                return true
            elseif board[r2, f2, player]
                # directiob blocked by own piece
                diags_finished[d] = true
            end
        end
        all(diags_finished) && break
    end

    # check crosses
    crosses_finished = falses(length(CROSS))
    for i in 1:8
        for (d, dir) in enumerate(CROSS)
            crosses_finished[d] && continue

            r2, f2 = (r,f) .+ i .* dir

            if r2 < 1 || r2 > 8 || f2 < 1 || f2 > 8
                # direction out of bounds
                crosses_finished[d] = true
                continue
            end

            if board[r2, f2, opponent] && (board[r2, f2, ROOK] || board[r2, f2, QUEEN])
                verbose && println("Cross check from $(field(r2, f2)) ($r2, $f2).")
                return true
            elseif board[r2, f2, player]
                # directiob blocked by own piece
                crosses_finished[d] = true
            end
        end
        all(crosses_finished) && break
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

function is_check(board::Board, player; kw...)
    opponent = player == WHITE ? BLACK : WHITE
    kingpos = findall(board[:,:,KING])
    r, f = Tuple(kingpos[1])
    if board[r, f, opponent]
        r, f = Tuple(kingpos[2])
    end
    return is_check(board, player, opponent, (r,f); kw...)
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
    s = s[2:end]

    # println("Piece: $p")

    ms = get_moves(board, white)

    piece = PIECES[p]
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
