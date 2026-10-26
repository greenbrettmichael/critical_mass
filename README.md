# CRITICAL MASS — mechanics prototype

A Godot 4.7 gameplay demo for the pitch: a reverse bullet-hell where everything
smaller than you welds onto your hull and keeps working as an auto-turret.
No art yet: shapes, labels and colors only. The point is to test the mechanics.

```
./run.sh                 # play (WASD roll · Q/E nudge spin · SPACE spin-burst · F12 screenshot · R restart)
./run.sh --bot           # watch the autopilot play
./run.sh --minutes=8     # compressed run (the scale schedule compresses with it)
./run.sh --start_r=30 --start_t=720    # jump to macro tier for testing
./run.sh --bot --shots=/tmp/cm --shot_every=30 --quit_after=1260   # fast playtest + screenshots + telemetry
```

`run.sh` uses the local Godot binary in `.tools/godot` (gitignored), or `godot` on your PATH if that's missing.

## What's implemented

| Pitch mechanic | Prototype |
|---|---|
| Eat smaller, avoid bigger | Edible things have a green outline. Bigger props are walls, and bigger enemies knock pieces off you. Live enemies can be eaten when they're under 0.42× your radius, props under 0.5×. |
| Dynamic surface topology | Items stick at the angle where they hit you. Each takes up arc length, and larger new items bury smaller ones. Buried pieces add mass but don't fire. |
| Emergent auto-turrets | ~25 weapon behaviours (projectile, beam, sweeping siren, zap, aura, cone, homing missile, grapple). Each fires outward from where it sits on the hull. Creatures you assimilate keep kicking and keep shooting. |
| Rotational firing arcs | The hull spins from steering, a pendulum torque from the heavy side, and a slow rolling drift. Q/E nudges the spin. SPACE does a spin-burst: a big spin plus double fire rate. |
| Asymmetric physics | Center of mass comes from the live surface. Heavy items (anvil, safe, bank vault, gold reserve) make you lopsided, which slows you down and swings like a pendulum. When the heavy side whips across your leading edge you get a **SLAM** shockwave. |
| Shedding (mass is armor) | Hits knock off the live pieces facing the attacker. They fly loose for 5 s with a countdown ring and explode if you don't roll back over them. Gravity pull does *not* collect them for you. Buried pieces resurface into the gaps. Once the surface is stripped, hits breach the core (3 integrity, regenerates). |
| Gravitational collapse | At 10 size thresholds, buried and small surface junk gets crushed into the core. Tag counts become auras: Iron Core, Lightning Trail, Ember Halo, Biomass, Momentum, Shrapnel Bloom. Each level needs twice as many pieces as the last. |
| Synergy recipes | Adjacency on the hull: **Junkyard Tesla** (transformer + carts), **Medieval Blender** (knight + mowers), **Kaiju Buffet** (crane + sushi train), **Code Three** (police cruiser + electric). Themed "kits" spawn together, so if you roll through one from one side its pieces land next to each other. |
| Scale tiers | Micro (10 cm → 2 m), Meso (→ 50 m), Macro (→ km). The camera keeps a fixed zoom relative to your size, and a power-of-10 grid plus a scale bar show how big you are. Anything below 3% of your size turns into "ambient dust" that heals you. |
| Threats | Swarmers, chasers, ranged shooters, ram-chargers with telegraphed wind-ups, elites (gold ring), hordes every ~40 s, and orbital strikes with reticles in the macro tier. |
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

Still open: the autopilot never breached its core in a full run, so difficulty for a real player is unknown. The Medieval Blender and Junkyard Tesla synergies show up less often than the meso/macro ones. Every enemy at the 2 km+ range is a "serpent" or "leviathan" because the roster runs out.

## Layout

- `scripts/game.gd`: the whole simulation and renderer. It draws manually in screen space, so a single scene spans 4+ orders of magnitude.
- `scripts/defs.gd`: props, enemies, weapons, synergies, themes and auras. All tunable data lives here.
- `scripts/bot.gd`: the autopilot used for simulated playtests.
- `screenshots/`: frames from simulated runs.
