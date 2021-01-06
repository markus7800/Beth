using BenchmarkTools

board = Board("r2qkb1r/1Q3pp1/p2p3p/3P1P2/N2pP3/4n3/PP4PP/1R3RK1 w - - 0 1")

# inital

@btime get_moves(board, true) # 49.950 μs (688 allocations: 31.02 KiB)
@btime get_pseudo_legal_moves(board, true) # 29.574 μs (471 allocations: 18.05 KiB)

@btime perft(Board(), true, 5) # 8.731 s (98176316 allocations: 4.36 GiB)



UInt64(1) + UInt64(2) + UInt64(2^5)

215 + 1 + 2

UInt64(1) | UInt64(2) == UInt64(1) + UInt64(2)

Int64(-1) | Int64(2) == Int64(-1) + Int64(2)
