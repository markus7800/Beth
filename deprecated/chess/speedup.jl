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

a1 = UInt64(2^0)
b1 = UInt64(2^1)
c1 = UInt64(2^2)
d1 = UInt64(2^3)
e1 = UInt64(2^4)
f1 = UInt64(2^5)
g1 = UInt64(2^6)
h1 = UInt64(2^7)

a2 = a1 << 8
log2(a2)

c3 = c1 << 16
log2(c3)

d1 << 1 # e1
d1 >> 1 # c1

log2(c3 >> 8) # c2

log2(h1 << 1) # a2 hmmm

a8 = UInt64(2^56)

a8 << 8
a1 >> 8

c8 = UInt64(2^58)
c8 << 8
c1 >> 8

a1 >> 1

a = UInt64(2^0+2^8+2^16+2^24+2^32+2^40+2^48+2^56)

a1 & a > 0

a8 & a > 0
