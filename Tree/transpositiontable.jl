
mutable struct TranspositionTable
    d::Dict{UInt, Number}
    n_fetched_stored_val::Int
    n_total::Int
    function TranspositionTable()
        return new(Dict{UInt, Number}(), 0, 0)
    end
end

import Base.hash
function Base.hash(board::Board, white::Bool)
    h = hash(board)
    return hash(white, h)
end

function get!(tt::TranspositionTable, h::UInt)
    tt.n_total += 1
    value = get(tt.d, h, NaN)
    if !isnan(value)
        # @info("Retrieve $value for $h")
        tt.n_fetched_stored_val += 1
    end
    return value
end

function get!(tt::TranspositionTable, board::Board, white::Bool)
    return get!(tt, hash(board, white))
end

function set!(tt::TranspositionTable, h::UInt, value:: Number)
    # @info("Store $value for $h")
    tt.d[h] = value
end

#
# function set!(tt::TranspositionTable, board::Board, white::Bool, value::Float64)
#     set!(tt, hash((board, white)), value)
# end
