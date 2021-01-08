mutable struct MoveList <: AbstractArray{Move,1}
    moves::Array{Move,1}
    count::Int
end


function Base.iterate(list::MoveList, state = 1)
    if state > list.count
        nothing
    else
        (list.moves[state], state + 1)
    end
end


function Base.length(list::MoveList)
    list.count
end


function Base.eltype(::Type{MoveList})
    Move
end


function Base.size(list::MoveList)
    (list.count,)
end


function Base.IndexStyle(::Type{<:MoveList})
    IndexLinear()
end


function Base.getindex(list::MoveList, i::Int)
    list.moves[i]
end


function MoveList(capacity::Int)
    MoveList(Array{Move}(undef, capacity), 0)
end

import Base.push!
function push!(list::MoveList, m::Move)
    list.count += 1
    list.moves[list.count] = m
end
