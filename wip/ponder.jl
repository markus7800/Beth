using Distributed

mutable struct PonderManager
    beth::Beth
    board::Board
    white::Bool
    n::Int
    n_procs::Int
    moves::Vector{Int}
    busy_worker::Vector{Int}
    answers::Vector{Int}
end

# moves in correct order
function PonderManager(n_procs::Int, beth::Beth, board::Board, white::Bool, moves::Vector{Int})
    n = length(moves)
    answers = zeros(Int, n)
    busy_worker = zeros(Int, n)
    return PonderManager(beth, board, white, n, n_procs, moves, busy_worker, answers)
end

function work(pm::PonderManager, jobs::RemoteChannel, results::RemoteChannel)
    beth = deepcopy(pm.beth) # TODO: necessary?
    while true
        local j
        try
            j = take!(jobs)
            println("Worker $(myid()) took job $(j.id) (Move: $(j.move)).")
        catch exc
            # println("Exception:", exc)
            break
        end
        sleep(j.move)
        put!(results , (id=j.id, worker = myid(), answer=j.move))
    end
    println("Worker $(myid()) has no more jobs to do.")
end

function start_pondering(pm::PonderManager)

    if length(workers()) < pm.n_procs
        # add processes
        addprocs(pm.n_procs)

        # initialise
        for worker in workers()
            println(worker)
            @spawnat worker include(pwd()*"/Beth/Beth.jl")
        end
    end

    jobs = RemoteChannel(() -> Channel{NamedTuple}(pm.n))
    # beguns = RemoteChannel(() -> Channel{NamedTuple}(pm.n))
    results = RemoteChannel(() -> Channel{NamedTuple}(pm.n))

    # make jobs
    @async begin
        for i in 1:pm.n
            println("Make job $i $(pm.moves[i])")
            put!(jobs, (id=i, move=pm.moves[i]))
        end
        println("Close jobs")
        close(jobs)
    end

    # start remote work
    @async for worker in workers()
        remote_do(work, worker, pm, jobs, results)
    end

    # fetch beguns
    # @async for i in 1:pm.n
    #     b = take!(beguns)
    #     pm.beg
    # end

    # fetch answers
    @async for i in 1:pm.n
        r = take!(results)
        pm.answers[r.id] = r.answer
        pm.busy_worker[r.id] = 0
        println("Job $(r.id) done by worker $(r.worker) with result $(r.answer)")
    end
end

function force_get!(pm::PonderManager, id::Int)
    if pm.busy_worker[id] != 0
        # TODO: wait
        # kill all other in the meanwhile?
    else
        interrupt(workers())
        return pm.answers[id]
    end
end
