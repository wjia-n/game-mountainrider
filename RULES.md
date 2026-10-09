# Mountain Rider — Rules of the Game

The authoritative source of truth for Mountain Rider gameplay. The engine
(`lib/engine/rider_engine.dart`) must enforce every rule below. If the
implementation diverges, fix the implementation.

## 1. Objective

Ride your mountain bike as far as possible down an endless procedurally
generated trail (Endless), or score as many points as possible in 60 seconds
(Score Attack). Score = distance in metres + 10 points per coin.

## 2. Setup

- Choose a mode: **Endless** (ride until you crash or run out of steam) or
  **Score Attack** (60-second timer, most points wins).
- Choose a tier: **Training** (gentle slopes, no rocks — free), **Trail**
  (real slopes, some rocks — free), **Enduro** (steep, dense rocks — PRO).
- Every ride starts with a 3-second countdown (3… 2… 1… GO!). Resuming from
  pause uses a shorter 1.5-second countdown.

## 3. Turn order

There are no turns — the ride is continuous real-time. The rider always moves
forward (left to right); speed is the only variable.

## 4. Legal moves

- **PEDAL** (right side of screen): accelerates the bike up to the tier's top
  speed. In the air, pedaling tips the nose UP (rotates backward).
- **BRAKE** (left side of screen): slows the bike. In the air, braking tips
  the nose DOWN (rotates forward).
- **Coast** (neither pressed): the bike rolls; gravity accelerates it on
  downhills and decelerates it on uphills; stamina slowly regenerates.
- Pedaling only works while stamina remains.

## 5. Illegal moves

- There are no discrete illegal inputs, but these situations end the ride:
  - Landing with the bike tilted more than ~72° from flat → "Landed on your
    roof!" crash.
  - Landing with downward velocity beyond the tier's hard-landing threshold
    → "What a landing… not." crash.
  - Touching a rock while grounded → "Hit a rock!" crash (Training tier has
    no rocks; they cannot appear in the first 600 px of any ride).
  - Pedaling to 0 stamina with speed below 8 px/s on flat or uphill ground
    → "Out of steam!" (downhills still carry you; stamina regenerates while
    coasting).

## 6. Captures

Not applicable (no opponents, no captures).

## 7. Special rules

- **Crest jumps:** leaving a crest at speed over 200 px/s launches the bike
  airborne with upward velocity proportional to slope × speed.
- **Air control:** nose-up with PEDAL, nose-down with BRAKE. Landing flat is
  safe; landing tilted more than ~26° costs 25% of speed ("Wobbly!").
- **BIG AIR:** airtime over 1.2 s awards bonus coins = round(airtime × 2)
  on landing, with fanfare.
- **Pickups:** coins (+1 coin, +10 score each) and water bottles (+32
  stamina, capped at 100). Pickup layout is deterministic per distance —
  the same trail always has the same pickups at the same spots.
- **Rocks:** deterministic per distance (same trail, same rocks). Visible
  well ahead; jump over them via crest jumps.

## 8. Scoring

- 1 metre travelled = 1 point (distance = world-x ÷ 50).
- 1 coin = 10 points.
- BIG AIR bonus coins count as coins (10 points each) immediately.
- Score Attack final score is frozen when the 60-second timer expires.

## 9. Winning conditions

- **Endless:** there is no win — the ride ends on crash, exhaustion, or quit.
  Beating your personal best is the victory ("NEW BEST!" badge).
- **Score Attack:** the ride ends when the timer hits zero; the final score
  is compared against the personal best for that tier.

## 10. Draw conditions

Not applicable (single-player score game).

## 11. AI strategy

Not applicable (no AI opponents). Difficulty comes from the tier: terrain
amplitude, top speed, rock density, stamina drain and landing tolerance all
scale from Training → Trail → Enduro.

## 12. Edge cases

- App backgrounded mid-ride → engine pauses automatically; resume via the
  pause dialog (never loses progress).
- Ride can never soft-lock: the engine's watchdog verifies every phase has
  a live driver (riding/countdown) every 500 ms and restarts it if missing.
- Pause is only legal from countdown or riding phases; pause during
  countdown resumes with a fresh short countdown.
- Restart always begins a fresh ride (state fully reset) with the full
  3-second countdown.
- Score Attack timer reaching zero finishes the ride immediately, even
  mid-air — no post-timer crashes can override the "Time!" result.
- Finish reason is set exactly once per ride; the finish dialog shows
  exactly once.

## 13. Test cases

1. Countdown advances 3 → 2 → 1 → GO and enters riding (unit test).
2. Watchdog restarts a dead ticker while riding (unit test).
3. Roof landing (tilt > 72°) crashes the ride (unit test).
4. Flat landing keeps full speed; tilted landing (>26°) costs speed but does
   not crash (unit test).
5. Rock collision while grounded crashes; no rocks in Training (unit test).
6. Stamina hits 0 with no speed on flat ground → "Out of steam!" (unit test).
7. Score Attack ends exactly at 60 s with frozen score (unit test).
8. Coin pickup increments coins and score (unit test).
9. Profile JSON round-trips name/theme/style/bests; legacy `rider_best`
   migrates into `trail_endless` (unit test).
10. Pause/resume/restart transitions never leave a phase without a driver
    (unit test).
