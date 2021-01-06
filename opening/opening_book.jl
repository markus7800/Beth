
OpeningBook = Dict{Board,Move}

function generate_opening_book(d::Dict, board = Board(), white = true, player=WHITE, book::OpeningBook=OpeningBook())
    if 7 + !white == player
        @assert length(d) == 1
        short = first(d)[1]
        next = first(d)[2]
        @assert next isa Dict

        m = short_to_long(board, white, short)
        book[board] = m

        _board = deepcopy(board)
        move!(_board, white, m[1], m[2], m[3])
        # @info("$white, $short")
        generate_opening_book(next, _board, !white, player, book)
    else
        for (short, next) in d
            _board = deepcopy(board)
            m = short_to_long(_board, white, short)
            move!(_board, white, m[1], m[2], m[3])
            # @info("$white, $short")
            generate_opening_book(next, _board, !white, player, book)
        end
    end

    return book
end

function generate_opening_book(short::String, board = Board(), white = true, player=WHITE, book::OpeningBook=OpeningBook())
    @assert 7 + !white == player
    m = short_to_long(board, white, short)
    book[board] = m
end

function get_queens_gambit()
    queens_gambit = """
    1. d4 d5 2. c4 dxc4 (2... e6 3. Nf3 Nf6 4. Nc3) (2... Nf6 3. cxd5) (2... Nc6 3.
    Nf3) (2... e5 3. dxe5 d4 (3... Be6 4. cxd5) 4. Nf3) 3. Nf3 Nf6 (3... b5 4. a4)
    (3... a6 4. e3 Nf6 (4... e6 5. Bxc4) (4... c5 5. Bxc4) 5. Bxc4) (3... c5 4. e3
    cxd4 5. Bxc4 dxe3 6. Bxf7+) 4. e3 e6 5. Bxc4 *
    """

    queens_gambit_dict = Dict( # 1w
        "d4" => Dict( # 1b
            "d5" => Dict( # 2w
                "c4" => Dict( # 2b
                    "dxc4" => Dict(
                            "Nf3" => Dict("Nf6" => Dict( "e3" => Dict("e6" => "Bxc4" )),
                            "b5" => "a4", # 4w
                            "a6" => Dict("e3" => Dict(
                                                        "Nf6" => "Bxc4",
                                                        "e6" => "Bxc4",
                                                        "c5" => "Bxc4"
                                                        )
                            ),
                            "c5" => Dict("e3" => Dict("cxd4" => Dict("Bxc4" => Dict("dxe3" => "Bxf7+"))))
                        )
                    ),
                    "e6" => Dict("Nf3" => Dict("Nf6" => "Nc3")),
                    "Nf6" => "cxd5",
                    "Nc6" => "Nf3",
                    "e5" => Dict("dxe5" => Dict(
                                                "d4" => "Nf3",
                                                "Be6" => "cxd5"
                                                )
                                )
                ),

            )
        )
    )

    return generate_opening_book(queens_gambit_dict)
end

get_queens_gambit()
