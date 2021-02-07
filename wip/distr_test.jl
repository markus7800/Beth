using Distributed

addprocs(2)

@everywhere include("Beth/Beth.jl")



@everywhere begin
    pz = rush_21_02_02[23]
    beth = Beth(
        value_heuristic=evaluation,
        rank_heuristic=rank_moves_by_eval,
        search_algorithm=IterativeMTDF,
        search_args=Dict(
            "max_depth" => 20,
            "do_quiesce" => true,
            "quiesce_depth" => 50,
            "verbose" => 1,
            "time" => 5
        ))

    beth(pz.board, pz.white_to_move)
end

procs()

rmprocs(1)

addprocs(2)
rmprocs(procs()...)

begin
    F = @spawnat 12 include("Beth/Beth.jl")
    println("nonblock?")
end



isready(F)

include("Beth/Beth.jl")
struct PonderManager
    beth::Beth
    n_processes::Int
    move_to_pid::Dict{Move, Int}
    move_to_answer::Dict{Move, Move}
end

function kill_and_reset!(pm::PonderManager)
    rmprocs(pm.pids...)
    pm.pids = Int[]
    # pm.move_to_pid = Dict{Move,Int}()
    @assert nprocs() == 1
    pm.pids = addprocs(pm.n_pids)
    for pid in pm.pids
        @spawnat pid include("Beth/Beth.jl")
    end
end

function ponder(pm::PonderManager, moves::Vector{Move})


end


beth = Beth(
    value_heuristic=evaluation,
    rank_heuristic=rank_moves_by_eval,
    search_algorithm=IterativeMTDF,
    search_args=Dict(
        "max_depth" => 20,
        "do_quiesce" => true,
        "quiesce_depth" => 50,
        "verbose" => 1,
        "time" => 5
    ))


@spawnat 12 b2 = deepcopy(beth)

F = @spawnat 12 begin
    b2 = deepcopy(beth)
    @info b2 == beth
    @info b2
end

@spawnat 12 @info b2


addprocs(4)

@everywhere function sleep_print(t)
    sleep(t)
    println(" Slept for $t seconds.")
    return t^2
end

A = [10, 20, 5, 5, 5, 10, 20, 5, 10, 10]

t = @async pmap(sleep_print, A)

rmprocs(procs()...)


t.state
t.donenotify
t.result

Fs = begin
    Fs = []
    @async for a in A
        f = @spawnat :any sleep_print(a)
        println("$a -> $f")
        push!(Fs, f)
    end
    return Fs
end

using Distributed

A = [10, 20, 5, 5, 5, 10, 20, 5, 10, 10]


function make_jobs(jobs::RemoteChannel, n::Integer)
    for i in 1:n
        println("Made job $i")
        put!(jobs , (id = i, workload = A[i]))
    end
    close(jobs)
end

addprocs(4)

@everywhere function work(jobs::RemoteChannel, results::RemoteChannel)
    try
        while true
            local j
            try
                j = take!(jobs)
                println("Worker $(myid()) took job $(j.id).")
            catch exc
                break
            end
            sleep(j.workload)
            put!(results , (id = j.id, worker = myid(), time = j.workload))
        end
    catch exc
        println(exc)
    end
    println("Worker $(myid()) has no more jobs to do.")
end


let n = 10
    local jobs = RemoteChannel(() -> Channel{NamedTuple}(10))
    local results = RemoteChannel(() -> Channel{NamedTuple}(10))

    @async make_jobs(jobs, n)

    @async for w in workers()
        remote_do(work, w, jobs, results)
    end
    t0 = time()
    # t = @async for i in 1:10
    @time for i in 1:10
        # if time() - t0 >  22
        #     println("Time over")
        #     break
        # end
        local r = take!(results)
        println("Job $(r.id) performed by worker $(r.worker) " *
        "took $(round(r.time; digits = 3)) seconds.")
    end

end

interrupt(workers())
workers()

@time addprocs(4)

@time

workers()


@time @async begin
    addprocs(4)
    for w in workers()
        println(w)
        @spawnat w include("Beth/Beth.jl")
    end
end

interrupt(workers())


include("Beth/Beth.jl")

A = [10, 20, 5, 5, 5, 10, 20, 5, 10, 10]

beth = Beth(
    value_heuristic=evaluation,
    rank_heuristic=rank_moves_by_eval,
    search_algorithm=IterativeMTDF,
    search_args=Dict(
        "max_depth" => 20,
        "do_quiesce" => true,
        "quiesce_depth" => 50,
        "verbose" => 1,
        "time" => 5
    ))

ponder = PonderManager(4, beth, StartPosition(), true, A)
start_pondering(ponder)
interrupt(workers())

@spawnat 2 throw(InterruptException())

ponder.answers

workers()

function empty_channel!(ch::RemoteChannel)
    try
        while true
            r = take!(ch)
        end
    catch exc
    end
end

rch = RemoteChannel(() -> Channel(5))

put!(rch, 1)
put!(rch, 2)
put!(rch, 3)
close(rch)

empty_channel!(rch)
