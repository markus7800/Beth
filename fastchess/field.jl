
const Fields = UInt64

function first(fs::Fields)::Int
    # trailing_zeros is Int for UInt64
    trailing_zeros(fs) + 1
end

function removefirst(fs::Fields)::Fields
    fs & (fs - 1)
end

import Base.iterate
function Base.iterate(ss::Fields, state = ss)
    if state == 0
        nothing
    else
        (first(state), removefirst(state))
    end
end

function is_singleton(fields::Fields)::Bool
    fields != 0 && removefirst(fields) == 0
end


const Field = UInt64 # where only one bit set

function Field(rank::Int, file::Int)::Field
    f = UInt64(1)
    f = f << (8 * (rank - 1))
    f = f << (file - 1)
    return f
end

function Field(sn::String)::Field
    # conversion from ASCII Chars
    f = Int(sn[1]) - 96 # = a, ..., g
    r = Int(sn[2]) - 48 # = 1, ..., 8
    return Field(r, f)
end

function file(field::Field)::Int
    trailing_zeros(field) % 8 + 1
end

function rank(field::Field)::Int
    trailing_zeros(field) ÷ 8 + 1
end

function rankfile(field::Field)::Tuple{Int,Int}
    l = trailing_zeros(field)
    l ÷ 8 + 1, l % 8 + 1
end

function tostring(field::Field)
    rank, file = rankfile(field)
    return Char(96+file) * string(rank)
end

function tonumber(field::Field)::Int
    trailing_zeros(field) + 1
end # ∈ [1,64]

function tofield(number::Int)::Field
    UInt64(1) << (number - 1)
end

function rankfile(number::Int)::Tuple{Int,Int}
    (number-1) ÷ 8 + 1, (number-1) % 8 + 1
end

function tostring(number::Int)
    rank, file = rankfile(number)
    return Char(96+file) * string(rank)
end



const FILE_A = Field("a1") | Field("a2") | Field("a3") | Field("a4") | Field("a5") | Field("a6") | Field("a7") | Field("a8")
const FILE_B = Field("b1") | Field("b2") | Field("b3") | Field("b4") | Field("b5") | Field("b6") | Field("b7") | Field("b8")
const FILE_C = Field("c1") | Field("c2") | Field("c3") | Field("c4") | Field("c5") | Field("c6") | Field("c7") | Field("c8")
const FILE_D = Field("d1") | Field("d2") | Field("d3") | Field("d4") | Field("d5") | Field("d6") | Field("d7") | Field("d8")
const FILE_E = Field("e1") | Field("e2") | Field("e3") | Field("e4") | Field("e5") | Field("e6") | Field("e7") | Field("e8")
const FILE_F = Field("f1") | Field("f2") | Field("f3") | Field("f4") | Field("f5") | Field("f6") | Field("f7") | Field("f8")
const FILE_G = Field("g1") | Field("g2") | Field("g3") | Field("g4") | Field("g5") | Field("g6") | Field("g7") | Field("g8")
const FILE_H = Field("h1") | Field("h2") | Field("h3") | Field("h4") | Field("h5") | Field("h6") | Field("h7") | Field("h8")

const FILES = [FILE_A, FILE_B, FILE_C, FILE_D, FILE_E, FILE_F, FILE_G, FILE_H]

function get_file(i)
    @inbounds FILES[i]
end


const RANK_1 = Field("a1") | Field("b1") | Field("c1") | Field("d1") | Field("e1") | Field("f1") | Field("g1") | Field("h1")
const RANK_2 = Field("a2") | Field("b2") | Field("c2") | Field("d2") | Field("e2") | Field("f2") | Field("g2") | Field("h2")
const RANK_3 = Field("a3") | Field("b3") | Field("c3") | Field("d3") | Field("e3") | Field("f3") | Field("g3") | Field("h3")
const RANK_4 = Field("a4") | Field("b4") | Field("c4") | Field("d4") | Field("e4") | Field("f4") | Field("g4") | Field("h4")
const RANK_5 = Field("a5") | Field("b5") | Field("c5") | Field("d5") | Field("e5") | Field("f5") | Field("g5") | Field("h5")
const RANK_6 = Field("a6") | Field("b6") | Field("c6") | Field("d6") | Field("e6") | Field("f6") | Field("g6") | Field("h6")
const RANK_7 = Field("a7") | Field("b7") | Field("c7") | Field("d7") | Field("e7") | Field("f7") | Field("g7") | Field("h7")
const RANK_8 = Field("a8") | Field("b8") | Field("c8") | Field("d8") | Field("e8") | Field("f8") | Field("g8") | Field("h8")
