# CRITICAL MASS — mechanics prototype

A Godot 4.7 gameplay demo for the pitch: a reverse bullet-hell where everything
smaller than you welds onto your hull, and what you eat decides what you become.
No art yet: shapes, labels and colors only. The point is to test the mechanics.

```
./run.sh                 # play (WASD roll · Q/E nudge spin · SPACE spin-burst · 1/2/3 or click to pick a fork · F12 screenshot · R restart)
./run.sh --bot           # watch the autopilot play
./run.sh --minutes=8     # compressed run (the scale schedule compresses with it)
./run.sh --start_r=30 --start_t=720    # jump to a later zone for testing (ranks auto-picked)
./run.sh --bot --shots=/tmp/cm --shot_every=30 --quit_after=1260   # fast playtest + screenshots + telemetry
```

`run.sh` uses the local Godot binary in `.tools/godot` (gitignored), or `godot` on your PATH if that's missing.

## What's implemented

| Pitch mechanic | Prototype |
|---|---|
| Eat smaller, avoid bigger | Edible things have a green outline. Bigger props are walls, and bigger enemies knock pieces off you. Live enemies can be eaten when they're under 0.42× your radius, props under 0.5×. |
| Dynamic surface topology | Items stick at the angle where they hit you. Each takes up arc length, and larger new items bury smaller ones. Each ability fires from the side of the hull where its material is concentrated (colored markers on the rim), so where things stuck and how you spin still matter. |
| Essence tree (replaces turrets) | Every object has tags. Eating it feeds essence into the matching branch: **Inferno** (fire), **Storm** (electric), **Bulwark** (metal), **Swarm** (organic), **Momentum** (wheel), **Shrapnel** (blade). Essence scales with relative size and is split across an object's tags. At 0:00 you pick a starting branch. After that, a branch's first rank unlocks its base ability, and every later rank pauses the game for a two-option fork, for 4 forks per branch. The price of the next rank goes up with every rank you own in *any* branch, so you can't max everything and your diet decides which branch levels next. A colored dot on each edible object shows which branch it feeds. |
| Rotational firing arcs | The hull spins from steering, a pendulum torque from the heavy side, and a slow rolling drift. Q/E nudges the spin. SPACE does a spin-burst: a big spin plus 1.6× ability rate (with Momentum's Dash it also launches you). |
| Asymmetric physics | Center of mass comes from the live surface. Heavy items (anvil, safe, bank vault, gold reserve) make you lopsided, which slows you down and swings like a pendulum. When the heavy side whips across your leading edge you get a **SLAM** shockwave. |
| Shedding (mass is armor) | Hits knock off the live pieces facing the attacker. They fly loose for 5 s with a countdown ring and explode if you don't roll back over them. Gravity pull does *not* collect them for you. Buried pieces resurface into the gaps. Once the surface is stripped, hits breach the core (3 integrity, regenerates). |
| Gravitational collapse | At 10 size thresholds, buried and small surface junk gets crushed into the core, which frees hull surface and sends out a shockwave. |
| Synergy recipes | Adjacency on the hull: **Junkyard Tesla** (transformer + carts), **Medieval Blender** (knight + mowers), **Kaiju Buffet** (crane + sushi train), **Code Three** (police cruiser + electric). Themed "kits" spawn together, so if you roll through one from one side its pieces land next to each other. |
| Size zones | Nested arenas: Kitchen Floor → Living Room → Backyard → Street → Downtown → Metropolis → Coastline → open world. Each is ringed by a wall (cabinets, drywall, fence, townhouses, skyscrapers, overpasses, mountains) whose pieces only become edible at the zone's exit size. That locks you in until you've grown into the zone, and then lets you eat your way out. Each zone also places about 28 pieces of furniture that are too big to eat when you arrive and mostly edible by the exit, plus two hidden synergy kits worth exploring for. Anything below 3% of your size turns into "ambient dust" that heals you. |
| Apex predators | One roaming miniboss per zone: Rat King, Roomba Prime, Junkyard Hound, SWAT Command, Warden Mech, Kaiju Matriarch, Elder Titan. Each is about 3× your size when you arrive. It patrols the zone and shows a faint sight ring. When it spots you it flashes "!" and hunts at 95% of your speed for 4 s after losing sight, so you escape by breaking line of sight, dashing, or using furniture. An edge-of-screen arrow tracks it. It hits very hard. Late in the zone you can kill it, which floods your branches with essence and drops loot. Outgrow it and it runs from you, and you can eat it. |
| Local wildlife | Nothing crosses the map to hunt you. Creatures wander around a home point. Prey (anything you can eat) flees at a speed you can run down. Predators bigger than you chase only inside a leash around their home, ranged ones hold position and shoot, and rammers telegraph a charge. Elites have a gold ring. Orbital strikes with reticles start in Downtown. |
| The Reaper | At 20:00 the **Rival Singularity** arrives at 1.8× your size. It eats props, fights you for loose debris, and fires bullet rings and lunges. Shoot chunks off it, eat the chunks, and absorb it once it's under 0.8× your size. |

## Tuning notes from simulated playtests

All tuning came from autopilot runs (`scripts/bot.gd`). Each run logs telemetry every 10 s and takes screenshots. Things that came up:

- **Runaway exponential growth.** Pure "eat things relative to your size" went super-exponential and hit absurd sizes by 15:00. Now a **growth governor** (`SCHEDULE` + `growth_eff()` in `game.gd`) bends absorption efficiency toward the designed arc: 0.08× when far ahead, up to 2× when behind. Autopilot runs now land at about 2.5 m @ 5:00, about 50 m @ 11–12:00, and about 3 km @ 20:00.
- **No danger.** When buried junk counted as armor, the core never got hit. Only the live surface layer is armor now.
- **Instant death.** Then the opposite problem: back-to-back breaches with 0.4 s i-frames killed the core in under 4 s. A breach now gives 1.6 s of i-frames and a repelling core flare.
- **Turrets didn't matter.** Peer-sized enemies took about 30 hits and auras did all the killing. Enemy HP is ×0.3 now, and concurrent elites are capped.
- **Wrecks blocked the player.** Dead-enemy wrecks acted as walls and trapped the bot for 2 minutes. They're now pushable debris that fade after 9 s.
- **Synergies almost never formed.** Added themed kit spawns and loosened the adjacency rules. Now about 35 activations per run.
- **Boss melted in 2 s.** Most damage is R²-scaled, but boss HP is area. The conversion is now tuned for a duel of about 30 s.

Second round (zones, apexes, local wildlife, essence tree):

- **Essence economy.** First pass: about 25 picks with every branch maxed by 7:00. Then 8 picks with only Bulwark maxed, because half the objects carried a metal tag. Now an object's essence is split across its tags, incidental metal tags are gone, and rank price scales with your total ranks.
- **Late zones starved.** By the end of a zone the whole arena fits on screen, so "spawn just off-screen, inside the walls" found nowhere to put things. Food and wildlife stopped, the player shrank, and the rival out-ate them for a loss. Things can now spawn in view, away from the player, with a grow-in animation.
- **Rival snowball.** The rival could keep eating props and outgrow you indefinitely. Its growth from eating is now capped at 2.2× your size.

Still open: the autopilot dodges well and almost never has its core breached outside the rival fight, so difficulty for a real player is unknown. The bot picks forks at random, so it doesn't test build strategy. Every enemy at the 2 km+ range is a "serpent" or "leviathan" because the roster runs out.

## Layout

- `scripts/game.gd`: the whole simulation and renderer. It draws manually in screen space, so a single scene spans 4+ orders of magnitude.
- `scripts/defs.gd`: props, enemies, synergies, themes, zones and the essence tree. All tunable data lives here.
- `scripts/bot.gd`: the autopilot used for simulated playtests.
- `screenshots/`: frames from simulated runs.
