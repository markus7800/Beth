
const PAWNPUSH = [[(-1, 0)], [(1, 0)]] # black at 1, white at 2
const PAWNDIAG = [[(-1, 1), (-1, -1)], [(1, 1), (1, -1)]] # black at 1, white at 2
const DIAG = [(-1,-1), (1,-1), (-1, 1), (1, 1)]
const CROSS = [(0,1), (0,-1), (1,0), (-1,0)]
const KNIGHTDIRS = [
        (1,2), (1,-2), (-1,2), (-1,-2),
        (2,1), (2,-1), (-2,1), (-2,-1)
        ]
const DIAGCROSS = vcat(DIAG, CROSS)

function gen_direction_fields(rank::Int, file::Int, directions::Vector{Tuple{Int,Int}}, max_multiple::Int)::Fields
    fields = Fields(0)
    for dir in directions
        for i in 1:max_multiple

            r2, f2 = (rank, file) .+ i .* dir

            if r2 < 1 || r2 > 8 || f2 < 1 || f2 > 8
                # direction out of bounds
                break # direction finished
            end

            to = Field(r2, f2)
            fields |= to
        end
    end

    fields
end

function gen_direction_fields(n::Int, directions::Vector{Tuple{Int,Int}}, max_multiple::Int)::Fields
    return gen_direction_fields(rankfile(n)..., directions, max_multiple)
end

const WHITE_PAWN_PUSH_EMPTY = @SVector [gen_direction_fields(n, PAWNPUSH[2], 1) for n in 1:64]
const BLACK_PAWN_PUSH_EMPTY = @SVector [gen_direction_fields(n, PAWNPUSH[1], 1) for n in 1:64]

const WHITE_PAWN_CAP_EMPTY = @SVector [gen_direction_fields(n, PAWNDIAG[2], 1) for n in 1:64]
const BLACK_PAWN_CAP_EMPTY = @SVector [gen_direction_fields(n, PAWNDIAG[1], 1) for n in 1:64]

const KNIGHT_MOVES_EMPTY = @SVector [gen_direction_fields(n, KNIGHTDIRS, 1) for n in 1:64]
const BISHOP_MOVES_EMPTY = @SVector [gen_direction_fields(n, DIAG, 8) for n in 1:64]
const ROOK_MOVES_EMPTY = @SVector [gen_direction_fields(n, CROSS, 8) for n in 1:64]
const QUEEN_MOVES_EMPTY = @SVector [gen_direction_fields(n, vcat(DIAG,CROSS), 8) for n in 1:64]
const KING_MOVES_EMPTY = @SVector [gen_direction_fields(n, vcat(DIAG,CROSS), 1) for n in 1:64]

function white_pawn_push_empty(number::Int)::Fields
    @inbounds WHITE_PAWN_PUSH_EMPTY[number]
end
function black_pawn_push_empty(number::Int)::Fields
    @inbounds BLACK_PAWN_PUSH_EMPTY[number]
end

function white_pawn_cap_empty(number::Int)::Fields
    @inbounds WHITE_PAWN_CAP_EMPTY[number]
end
function black_pawn_cap_empty(number::Int)::Fields
    @inbounds BLACK_PAWN_CAP_EMPTY[number]
end

function knight_move_empty(number::Int)::Fields
    @inbounds KNIGHT_MOVES_EMPTY[number]
end
function bishop_move_empty(number::Int)::Fields
    @inbounds BISHOP_MOVES_EMPTY[number]
end
function rook_move_empty(number::Int)::Fields
    @inbounds ROOK_MOVES_EMPTY[number]
end
function queen_move_empty(number::Int)::Fields
    @inbounds QUEEN_MOVES_EMPTY[number]
end
function king_move_empty(number::Int)::Fields
    @inbounds KING_MOVES_EMPTY[number]
end


# diags and crosses only
function gen_fields_between(r1::Int, f1::Int, r2::Int, f2::Int, exc1=true, exc2=true)::Fields
    fields = Fields(0)

    if r1 > r2
        t = r2; r2 = r1; r1 = t;
        t = exc1; exc1 = exc2; exc2 = t;
        t = f2; f2 = f1; f1 = t;
    end


    if f1 == f2
        for r in r1+exc1:r2-exc2
            fields |= Field(r, f1)
        end
    elseif r1 == r2
        if f1 < f2
            for f in f1+exc1:f2-exc2
                fields |= Field(r1, f)
            end
        else
            for f in f2+exc2:f1-exc1
                fields |= Field(r1, f)
            end
        end
    elseif abs(f2 - f1) == abs(r2 - r1)
        if f1 < f2
            for i in exc1:(f2-f1)-exc2
                fields |= Field(r1+i, f1+i)
            end
        else
            for i in exc2:(f1-f2)-exc1
                fields |= Field(r1+i, f1-i)
            end
        end
    end


    fields
end

function gen_fields_between(n1::Int, n2::Int)::Fields
    return gen_fields_between(rankfile(n1)..., rankfile(n2)...)
end

# exclusive input fields
const FIELDS_BETWEEN = [gen_fields_between(n1, n2) for n1 in 1:64, n2 in 1:64]

function fields_between(n1::Int, n2::Int)::Fields
    @inbounds FIELDS_BETWEEN[n1, n2]
end


# generates shadow of (r2,f2) from (r1,f1), (r2, f2) not in shadow
function gen_shadow(r1::Int, f1::Int, r2::Int, f2::Int)::Fields
    fields = Fields(0)

    if f1 == f2 && r1 == r2
        return fields
    end

    if f1 == f2
        if r1 < r2
            fields |= gen_fields_between(r2, f2, 8, f2, false, false)

        else
            fields |= gen_fields_between(r2, f2, 1, f2, false, false)
        end
    elseif r1 == r2
        if f1 < f2
            fields |= gen_fields_between(r2, f2, r2, 8, false, false)
        else
            fields |= gen_fields_between(r2, f2, r2, 1, false, false)
        end
    elseif abs(f2 - f1) == abs(r2 - r1)
        Δ = abs(f2 - f1)
        # diagonally
        if f1 < f2
            if r1 < r2
                # field 2 is to the topright of field 1
                Δ = min(8 - r2, 8 - f2) # minimal distance to right or top border
                fields |= gen_fields_between(r2, f2, r2 + Δ, f2 + Δ, false, false)

            else
                # field 2 is to the bottomright of field 1
                Δ = min(r2 - 1, 8 - f2) # minimal distance to right or bottom border
                fields |= gen_fields_between(r2, f2, r2 - Δ, f2 + Δ, false, false)
            end
        else
            if r1 < r2
                # field 2 is to the topleft of field 1
                Δ = min(8 - r2, f2 - 1) # minimal distance to top or left border
                fields |= gen_fields_between(r2, f2, r2 + Δ, f2 - Δ, false, false)
            else
                # field 2 is to the bottomleft of field 1
                Δ = min(r2 - 1, f2 - 1) # minimal distance to bottom or keft border
                fields |= gen_fields_between(r2, f2, r2 - Δ, f2 - Δ, false, false)
            end
        end
    end

    fields &= ~Field(r2, f2)

    return fields
end

function gen_shadow(n1::Int, n2::Int)::Fields
    return gen_shadow(rankfile(n1)..., rankfile(n2)...)
end

const SHADOW = [gen_shadow(n1, n2) for n1 in 1:64, n2 in 1:64]

function shadow(n1::Int, n2::Int)::Fields
    @inbounds SHADOW[n1, n2]
end

#=
print_fields(gen_fields_between(tonumber(Field("a1")), tonumber(Field("g7"))))
print_fields(gen_fields_between(tonumber(Field("e6")), tonumber(Field("c4"))))

print_fields(gen_fields_between(tonumber(Field("b7")), tonumber(Field("g7"))))
print_fields(gen_fields_between(tonumber(Field("b7")), tonumber(Field("b1"))))


print_fields(gen_fields_between(tonumber(Field("b7")), tonumber(Field("f3"))))
print_fields(gen_fields_between(tonumber(Field("f3")), tonumber(Field("b7"))))



print_fields(gen_shadow(tonumber(Field("c2")),tonumber(Field("d3"))))
print_fields(gen_shadow(tonumber(Field("d3")),tonumber(Field("c2"))))

print_fields(gen_shadow(tonumber(Field("b5")),tonumber(Field("d3"))))
print_fields(gen_shadow(tonumber(Field("d3")),tonumber(Field("b5"))))

print_fields(gen_shadow(tonumber(Field("d3")),tonumber(Field("f5"))))
print_fields(gen_shadow(tonumber(Field("f5")),tonumber(Field("d3"))))

print_fields(gen_shadow(tonumber(Field("d3")),tonumber(Field("d5"))))
print_fields(gen_shadow(tonumber(Field("d5")),tonumber(Field("d3"))))


print_fields(gen_shadow(tonumber(Field("d3")),tonumber(Field("d7"))))
print_fields(gen_shadow(tonumber(Field("d7")),tonumber(Field("d3"))))

print_fields(gen_shadow(tonumber(Field("d7")),tonumber(Field("e3"))))
=#
