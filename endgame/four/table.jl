
# tables are from whites perspective
# one for white to move / one for black to move
struct Table
    d::Array{Int8}
end

function Table(size...)
    return Table(fill(-1, size...))
end

struct TableBase
    mates::Table
    desperate_positions::Table
    key::Function
    fromkey!::Function
end

import Base.haskey
function haskey(tb::Table, key::CartesianIndex)::Bool
    if key == CartesianIndex(0)
        return false
    end
    tb.d[key] != -1
end

# function haskey(tb::Table, key::Int)::Bool
#     tb.d[key] != -1
# end

import Base.getindex
function getindex(tb::Table, key::CartesianIndex)
    @assert haskey(tb, key)
    tb.d[key]
end

import Base.setindex!
function setindex!(tb::Table, v::Int, key::CartesianIndex)
    tb.d[key] = v
end

import Base.length
function length(tb::Table)
    sum(tb.d .!= -1)
end

import Base.size
function size(tb::Table)
    prod(size(tb.d))
end

import Base.CartesianIndices
CartesianIndices(tb::Table) = CartesianIndices(tb.d)

function get_mate(tb::TableBase, board::Board)
    tb.mates[tb.key(board)]
end

function get_desperate_position(tb::TableBase, board::Board)
    tb.desperate_positions[tb.key(board)]
end

function get_mate_line(tb::TableBase, board::Board, known_tb=nothing; printPGN=false)
    line = Move[]
    i = tb.mates[tb.key(board)]
    j = i-1
    _board = deepcopy(board)
    counter = 1
    printPGN && println("[FEN \"$(FEN(board, true))\"]")
    while true
        # mate in i -> move -> dp in i-1
        wms = get_moves(_board, true)
        j = -1
        for move in wms
            undo = make_move!(_board, true, move)
            dp_key = tb.key(_board)
            if haskey(tb.desperate_positions, dp_key)
                j = tb.desperate_positions[dp_key]
            end
            if !isnothing(known_tb)
                known_dp_key = known_tb.key(_board)
                if haskey(known_tb.desperate_positions, known_dp_key)
                    j = known_tb.desperate_positions[known_dp_key]
                end
            end
            if j == i - 1
                printPGN && print("$counter. $(toPGNformat(move))\t")
                push!(line, move)
                break
            end
            undo_move!(_board, true, move, undo)
        end

        # dp in i -> move -> mate in i
        bms = get_moves(_board, false)
        if length(bms) == 0
            printPGN && println("*")
            break
        end
        i = -1
        for move in bms
            undo = make_move!(_board, false, move)
            mate_key = tb.key(_board)
            if haskey(tb.mates, mate_key)
                i = tb.mates[mate_key]

            end
            if !isnothing(known_tb)
                known_mate_key = known_tb.key(_board)
                if haskey(known_tb.mates, known_mate_key)
                    i = known_tb.mates[known_mate_key]
                end
            end
            if i == j
                printPGN && println(toPGNformat(move))
                push!(line, move)
                break
            end
            undo_move!(_board, false, move, undo)
        end
        counter += 1
    end

    return line
end


function three_men_key(board::Board)::CartesianIndex
    if count_pieces(board.whites) != 2 || count_pieces(board.blacks) != 1
        return CartesianIndex(0)
    end
    a = tonumber(board.kings & board.whites)
    b = tonumber((board.pawns | board.queens | board.rooks) & board.whites)
    c = tonumber(board.kings & board.blacks)

    if b == 65
        return CartesianIndex(0)
    end

    p = 0
    if board.queens & board.whites > 0
        p = 1
    elseif board.rooks & board.whites > 0
        p = 2
    elseif board.pawns & board.whites > 0
        p = 3
    else
        return CartesianIndex(0)
    end

    return CartesianIndex(p, a, b, c)
end

function three_men_fromkey!(board::Board, key::CartesianIndex)
    p = key[1]
    piece = QUEEN
    if p == 2
        piece = ROOK
    elseif p == 3
        piece = PAWN
    end

    remove_pieces!(board)
    set_piece!(board, tofield(key[2]), true, KING)
    set_piece!(board, tofield(key[3]), true, piece)
    set_piece!(board, tofield(key[4]), false, KING)
end

function ThreeMenTB()
    return TableBase(
        Table(3, 64, 64, 64),
        Table(3, 64, 64, 64),
        three_men_key,
        three_men_fromkey!
        )
end

function occupied_by(board::Board, piece::Piece)
    if piece == KING
        return board.kings
    elseif piece == PAWN
        return board.pawns
    elseif piece == BISHOP
        return board.bishops
    elseif piece == KNIGHT
        return board.knights
    elseif piece == ROOK
        return board.rooks
    elseif piece == QUEEN
        return board.queens
    end
end


function four_men_2v0_key(piece1::Piece, piece2::Piece)
    function key(board::Board)::CartesianIndex
        if count_pieces(board.whites) != 3 || count_pieces(board.blacks) != 1
            return CartesianIndex(0)
        end

        a = tonumber(board.kings & board.whites)
        local b
        local c
        fs_1 = occupied_by(board, piece1) & board.whites
        fs_2 = occupied_by(board, piece2) & board.whites
        if piece1 == piece2
            b = first(fs_1)
            fs_1 = removefirst(fs_1)
            c = first(fs_1)
        else
            b = tonumber(fs_1)
            c = tonumber(fs_2)
        end
        d = tonumber(board.kings & board.blacks)
        if b == 65 || c == 65 || count_pieces(fs_1 | fs_2 | board.kings) != 4
            return CartesianIndex(0)
        end

        return CartesianIndex(a, b, c, d)
    end
end

function four_men_2v0_fromkey!(piece1::Piece, piece2::Piece)
    function fromkey!(board::Board, key::CartesianIndex)
        remove_pieces!(board)
        set_piece!(board, tofield(key[1]), true, KING)
        set_piece!(board, tofield(key[2]), true, piece1)
        set_piece!(board, tofield(key[3]), true, piece2)
        set_piece!(board, tofield(key[4]), false, KING)
    end
end

function FourMenTB2v0(piece1::Piece, piece2::Piece)
    return TableBase(
        Table(64, 64, 64, 64),
        Table(64, 64, 64, 64),
        four_men_2v0_key(piece1, piece2),
        four_men_2v0_fromkey!(piece1, piece2)
        )
end


function four_men_1v1_key(wpiece::Piece, bpiece::Piece)
    function key(board::Board)::CartesianIndex
        a = tonumber(board.kings & board.whites)
        b = tonumber(occupied_by(board, wpiece) & board.whites)
        c = tonumber(board.kings & board.blacks)
        d = tonumber(occupied_by(board, bpiece) & board.blacks)
        if b == 65 || d == 65 || count_pieces(board.whites | board.blacks) != 4
            return CartesianIndex(0)
        end

        return CartesianIndex(a, b, c, d)
    end
end

function four_men_1v1_fromkey!(wpiece::Piece, bpiece::Piece)
    function fromkey!(board::Board, key::CartesianIndex)
        remove_pieces!(board)
        set_piece!(board, tofield(key[1]), true, KING)
        set_piece!(board, tofield(key[2]), true, wpiece)
        set_piece!(board, tofield(key[3]), false, KING)
        set_piece!(board, tofield(key[4]), false, bpiece)
    end
end

function four_men_1v1_wp_key(wpiece::Piece, bpiece::Piece)
    function key(board::Board)::CartesianIndex
        if count_pieces(board.whites) != 2 || count_pieces(board.blacks) != 2
            return CartesianIndex(0)
        end

        a = tonumber(board.kings & board.whites)
        b = tonumber((occupied_by(board, wpiece) | board.pawns) & board.whites)
        c = tonumber(board.kings & board.blacks)
        d = tonumber((occupied_by(board, bpiece) | board.pawns) & board.blacks)
        e = Int(n_pawns(board, true) + n_pawns(board, false) > 0) + 1
        if b == 65 || d == 65 || count_pieces(board.whites | board.blacks) != 4 ||
            n_pawns(board, true) + n_pawns(board, false) > 1

            return CartesianIndex(0)
        end

        return CartesianIndex(a, b, c, d, e)
    end
end

function four_men_1v1_wp_fromkey!(wpiece::Piece, bpiece::Piece)
    function fromkey!(board::Board, key::CartesianIndex)
        remove_pieces!(board)
        set_piece!(board, tofield(key[1]), true, KING)
        set_piece!(board, tofield(key[3]), false, KING)
        if wpiece == QUEEN
            if key[5] == 1
                set_piece!(board, tofield(key[2]), true, wpiece)
            else
                set_piece!(board, tofield(key[2]), true, PAWN)
            end
            set_piece!(board, tofield(key[4]), false, bpiece)
        elseif bpiece == QUEEN
            if key[5] == 1
                set_piece!(board, tofield(key[4]), false, bpiece)
            else
                set_piece!(board, tofield(key[4]), false, PAWN)
            end
            set_piece!(board, tofield(key[2]), true, wpiece)
        end
    end
end


function four_men_1v1_wp_bp_key(wpiece::Piece, bpiece::Piece)
    function key(board::Board)::CartesianIndex
        if count_pieces(board.whites) != 2 || count_pieces(board.blacks) != 2
            return CartesianIndex(0)
        end

        a = tonumber(board.kings & board.whites)
        b = tonumber((occupied_by(board, wpiece) | board.pawns) & board.whites)
        c = tonumber(board.kings & board.blacks)
        d = tonumber((occupied_by(board, bpiece) | board.pawns) & board.blacks)
        e = Int(n_pawns(board, true) > 0) + 1
        f = Int(n_pawns(board, false) > 0) + 1
        if b == 65 || d == 65 || count_pieces(board.whites | board.blacks) != 4
            return CartesianIndex(0)
        end

        return CartesianIndex(a, b, c, d, e, f)
    end
end

function four_men_1v1_wp_bp_fromkey!(wpiece::Piece, bpiece::Piece)
    function fromkey!(board::Board, key::CartesianIndex)
        remove_pieces!(board)
        set_piece!(board, tofield(key[1]), true, KING)
        if key[5] == 1
            set_piece!(board, tofield(key[2]), true, wpiece)
        else
            set_piece!(board, tofield(key[2]), true, PAWN)
        end
        set_piece!(board, tofield(key[3]), false, KING)
        if key[6] == 1
            set_piece!(board, tofield(key[4]), false, wpiece)
        else
            set_piece!(board, tofield(key[4]), false, PAWN)
        end
    end
end

function FourMenTB1v1(wpiece::Piece, bpiece::Piece)
    wpromo = wpiece == QUEEN
    bpromo = bpiece == QUEEN
    if wpromo && bpromo
            return TableBase(
                Table(64, 64, 64, 64, 2, 2),
                Table(64, 64, 64, 64, 2, 2),
                four_men_1v1_wp_bp_key(wpiece, bpiece),
                four_men_1v1_wp_bp_fromkey!(wpiece, bpiece)
                )
    end
    if wpromo || bpromo
        return TableBase(
            Table(64, 64, 64, 64, 2),
            Table(64, 64, 64, 64, 2),
            four_men_1v1_wp_key(wpiece, bpiece),
            four_men_1v1_wp_fromkey!(wpiece, bpiece)
            )
    end

    return TableBase(
        Table(64, 64, 64, 64),
        Table(64, 64, 64, 64),
        four_men_1v1_key(wpiece, bpiece),
        four_men_1v1_fromkey!(wpiece, bpiece)
        )

end
