## Chess Engine written in JULIA

named after main protagonist from Queen's Gambit Netflix series.

### Usage

Run
```
> julia setup.jl
```
to install all dependencies
Downlaad the endgame tablebase [here](https://www.icloud.com/iclouddrive/0FXNdqCATQ04yeF2syZwjDWpg#tb), unzip and place it in `endgame/four/`.
Alternatively, one can generate it by running the file `endgame\four\generate_endgame_tablebase.jl` which takes a few hours.


The command
```
> julia play.jl
```
will start a server at `localhost:8000` where you can play against the default engine which takes about 10-20 seconds to move.
It is on par with chess.com engines of advanced to expert level strength.
For now the search configuration can only be changed un `play.jl`

### About

For a detailed description see my [blog post](https://markus7800.github.io/blog/AI/chess_engine.html).

Move generation and board logic can be found in the `chess` folder.
It can generate up to 100 million board positions per second on a Intel i5@3.5GHz single threaded.
At its core eight unsigned 64-bit integer represent the board with additional flags for en-passant and castling rights.

As search function MTD(f) with iterative deepening is used.
A bit of bookkeeping (close to transposition tables) is done to speed up search.
At the leaf nodes quiescence search is performed where all capture moves are tried out.

For comparison:  
From `r2qkb1r/1Q3pp1/pN1p3p/3P1P2/3pP3/4n3/PP4PP/1R3RK1 b - -` there can be 872_389_934 positions reached after six plies which takes me 7.7 seconds to generate.
AlphaBeta searches 832,634 positions in 1.092s, MTD(f) searches 658,447 positions in 850ms and MTD(f) with iterative deepening searches only 518,774 in 626ms. That's only 0.06 % of all possible positions.

The evaluation function is built above the usual cumulative piece value evaluation.
Further, it takes pawn structure, development, central pieces and basic king safety into account.

The main algorithms and evaluation function can be found in the `Beth` folder.

The engine also uses a 20 board queens gambit opening book. See `opening/opening_book.jl`.

For endgames a self generated 3-men tablebase is employed. See `endgame/generate_endgame_tablebase.jl`.

The browser frontend is built with `Genie.jl` and `chessboardjs`.

#### Possible Improvement

- multi thread
- generate 5-men tablebase
- more openings
- anticipate opponent move and search while opponent is thinking
- add null move pruning and razoring (add more pruning)
- better time management
- add configuration possibilities to frontend
