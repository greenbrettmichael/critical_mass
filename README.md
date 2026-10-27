# CRITICAL MASS — mechanics prototype

A Godot 4.7 gameplay demo for the pitch: a reverse bullet-hell where everything
smaller than you welds onto your hull, and what you eat decides what you become.
No art yet: shapes, labels and colors only. The point is to test the mechanics.

```
./run.sh                 # play: pick a mode, then (WASD crawl · SPACE or click: lurch · SHIFT churn · Q/E nudge spin · 1/2/3 to pick a fork · F12 screenshot · R restart)
./run.sh --bot           # watch the autopilot play
./run.sh --minutes=8     # compressed run (the scale schedule compresses with it)
./run.sh --start_r=30 --start_t=720    # jump to a later zone for testing (ranks auto-picked)
./run.sh --bot --shots=/tmp/cm --shot_every=30 --quit_after=1260   # fast playtest + screenshots + telemetry
.tools/godot --headless --path . --fixed-fps 60 -- --bot --seed=6 --bot_focus=electric --quit_after=1260   # telemetry only, autopilot eats for one branch
```

`run.sh` uses the local Godot binary in `.tools/godot` (gitignored), or `godot` on your PATH if that's missing.

## Online play

Players race each other to the planet core in the same world. One player hosts and runs the simulation; everyone else joins by address.

```
./run.sh --host --players=3              # host a 3-player match on UDP port 7777; ENTER starts early
./run.sh --join=192.168.1.20 --name=ana  # join it (add :PORT if the host used --port=N)
./run.sh --players=3                     # offline: you against two autopiloted oozes
```

- **Lobby.** The host's clock waits until every slot is taken, or until the host presses ENTER. The autopilot plays any empty slot, and takes over if a player disconnects.
- **Player vs player.** Other players use the same size bands as rivals. Under 0.8× your size you can eat them, between 0.8× and 1.25× a ram knocks pieces off both of you, and above that they can eat you. Your abilities chip their hull too.
- **Nobody is knocked out.** If you're eaten or your core gives out, you reform 30 s later at a little under the smallest ooze still in play, as far as possible from anything that could eat you, inside a shimmering shell that can't be swallowed for 5 s. Your essence tree survives, but your hull doesn't. The first ooze to swallow the planet core wins the match.
- **Forks don't pause.** In a shared world the fork cards sit low on the screen while you keep playing. Press 1–3 when you're ready.
- AI rivals are off by default in multiplayer. Add them with `--rivals=N`.
- Internet play needs UDP 7777 forwarded to the host. There's no client-side prediction yet, so it's built for LAN and low-latency links. Snapshots are 4–10 KB at 20 Hz per client.

## The player: a black ooze

You're a slime mold, not a ball:
- **Crawl.** WASD moves you slowly and fluidly. Momentum carries, and the ooze sheds excess speed quickly.
- **Lurch.** Space, or a click near a target, shoots a pseudopod at something in your aim direction within range. It latches on, and the body snaps after it and overshoots. It only fires at a target (food, prey, or an enemy to ram), never into empty space. Swarm (organic) ranks and the Hunters node increase the range and shorten the cooldown. Lurching into something bigger than you still strips pieces off.
- **Feeding tentacles.** 3 + Swarm-rank feelers reach for nearby food and prey and drag it in, with cells streaming along them. They replace the old invisible gravity pull. Shed pieces still have to be rolled over.
- **Churn.** Shift churns the hull (the old spin-burst). Absorbed objects sit half-sunk in the membrane, and abilities still fire from the side where their material is concentrated.
- **Visibility floor.** Anything smaller than 12% of your radius fades out and is gone: no mass, no essence, no healing. Each size band has its own mix of tags, and once you outgrow a band you lose access to it, so what you eat while you're a given size shapes your tree.

Each zone has its own floor (terracotta tile, teal carpet, grass, asphalt, concrete, slate, sand), and anything outside the current zone's walls is shaded.

## What's implemented

| Pitch mechanic | Prototype |
|---|---|
| Eat smaller, avoid bigger | Edible things have a green outline. Bigger props are walls, and bigger enemies knock pieces off you. Live enemies can be eaten when they're under 0.42× your radius, props under 0.5×. |
| Dynamic surface topology | Items stick at the angle where they hit you. Each takes up arc length, and larger new items bury smaller ones. Each ability fires from the side of the hull where its material is concentrated (colored markers on the rim), so where things stuck and how you spin still matter. |
| Essence tree (replaces turrets) | Every object has tags. Eating it feeds essence into the matching branch: **Inferno** (fire), **Storm** (electric), **Bulwark** (metal), **Swarm** (organic), **Momentum** (wheel), **Shrapnel** (blade). Essence scales with relative size and is split across an object's tags. At 0:00 you pick a starting branch. After that, a branch's first rank unlocks its base ability, and every later rank pauses the game for a two-option fork, for 4 forks per branch. The price of the next rank goes up with every rank you own in *any* branch, so you can't max everything and your diet decides which branch levels next. A colored dot on each edible object shows which branch it feeds. |
| Rotational firing arcs | The hull spins from steering, a pendulum torque from the heavy side, and a slow rolling drift. Q/E nudges the spin. SPACE does a spin-burst: a big spin plus 1.6× ability rate (with Momentum's Dash it also launches you). |
| Asymmetric physics | Center of mass comes from the live surface. Heavy items (anvil, safe, bank vault, gold reserve) make you lopsided, which slows you down and swings like a pendulum. When the heavy side whips across your leading edge you get a **SLAM** shockwave. |
| Shedding (mass is armor) | Anything that can hurt you can kill you. Hits knock off the live pieces facing the attacker, and buried pieces resurface into the gaps one at a time, not instantly, so sustained pressure from wildlife, a rival or a corrosive spill strips you down to the core. They fly loose for 5 s with a countdown ring and explode if you don't roll back over them. Gravity pull does *not* collect them for you. Buried pieces resurface into the gaps. Once the surface is stripped, hits breach the core (3 integrity, regenerates). |
| Gravitational collapse | At 10 size thresholds, buried and small surface junk gets crushed into the core, which frees hull surface and sends out a shockwave. |
| Synergy recipes | Adjacency on the hull: **Junkyard Tesla** (transformer + carts), **Medieval Blender** (knight + mowers), **Kaiju Buffet** (crane + sushi train), **Code Three** (police cruiser + electric). Themed "kits" spawn together, so if you roll through one from one side its pieces land next to each other. |
| Size zones | Nested arenas: Kitchen Floor → Living Room → Backyard → Street → Downtown → Metropolis → Coastline → open world. Each is ringed by a wall (cabinets, drywall, fence, townhouses, skyscrapers, overpasses, mountains) whose pieces only become edible at the zone's exit size. That locks you in until you've grown into the zone, and then lets you eat your way out. Each zone also places about 28 pieces of furniture that are too big to eat when you arrive and mostly edible by the exit, plus two hidden synergy kits worth exploring for. Anything below 3% of your size turns into "ambient dust" that heals you. |
| Terrain hazards | Floor patches per zone that slow, dry out, corrode, push or unbalance the ooze. Kitchen: salt lines and bleach. Living room: soda spills and carpet cleaner. Backyard: mud and weed killer. Street: oil slicks (you slide) and hot asphalt. Downtown: wet cement and chemical spills. Metropolis: river currents. Coastline: sand and riptides. Open world: lava. Drying and corrosion knock pieces off while you sit in them. Harmful spills have food sitting in the middle as bait. Lurching across a patch ignores its slow. Patches keep appearing at your current scale, and a patch stops mattering once you're much bigger than it. Wildlife isn't affected. |
| Relative-size damage | All of your damage (abilities, rams, slams) falls off against targets bigger than you: full damage up to your own size, 0.73× at 1.5×, 0.4× at 2×, 0.17× at 2.8×. Peers die as fast as before, but a big apex or the rival can't be melted. |
| Apex predators | One roaming miniboss per zone: Rat King, Roomba Prime, Junkyard Hound, SWAT Command, Warden Mech, Kaiju Matriarch, Elder Titan. Each is about 3× your size when you arrive. It patrols the zone and shows a faint sight ring. When it spots you it flashes "!", hunts at 95% of your speed, fires red volleys, and crouches before a pounce. **It's deadly.** Contact tears straight into your core: you lose a core integrity point no matter how much armor you have, plus a chunk of hull. After each strike it backs off for a few seconds, which is your window to break line of sight. Three strikes before your core regenerates and you're dead. An edge-of-screen arrow tracks it. Late in the zone you can kill it, which floods your branches with essence and drops loot. Outgrow it and it runs from you, and you can eat it. The rival avoids apexes too. |
| Local wildlife | Nothing crosses the map to hunt you. Creatures wander around a home point. Prey (anything you can eat) flees at a speed you can run down. Predators bigger than you chase only inside a leash around their home, ranged ones hold position and shoot, and rammers telegraph a charge. Elites have a gold ring. Orbital strikes with reticles start in Downtown. |
| Rival oozes | Rivals spawn next to you at the start and play the same game. They forage for the same food near you, grow on the same pacing curve with no ceiling, flee apexes and bigger rivals, and follow you out through each zone wall. Each rival hunts whichever ooze nearby is meaningfully smaller, you or another rival. Contact depends on relative size. Under 0.8× your size, you eat it. Between 0.8× and 1.2×, a ram knocks pieces off both of you. Above 1.2×, it hunts you, lunges, and spits rings of globs. Big enough and it eats you. Rivals use the same bands with each other. Anything eaten reforms 45 s later at your size. |
| Modes | A mode screen before the starting essence: **Duel** (one rival), **Free-for-all** (three rivals that also eat each other), **Solo** (no rivals). `--rivals=N` skips the screen. **Multiplayer** (`--players=N`, up to 4) puts other oozes in the same world: online players, or the autopilot offline. See "Online play" above. |
| The goal | In the open world, the planet core sits at the center of the map. It's the one thing you can eat at your own size: a molten sphere nearly as big as the target, edible once you reach 2.8 km across. Eat it first and you win. If the rival eats it first, you lose. The HUD shows a goal progress bar and the rival's size relative to yours. Edge arrows track the rival and the core. |

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

Third round (ooze movement, visibility floor):

- **Is diet strategic?** With the floor in, a bot that favors one branch ends noticeably higher in it on the same seed: electric-focused reached Storm 4 vs 2, and blade-focused reached Shrapnel 3 vs 2. Swarm used to max in every run because most creatures were tagged only organic. Creatures now carry a second tag (dogs: blade, soldiers: metal, kaiju: fire...).
- **Movement.** With the slower crawl, the autopilot lurches about 900 times per run, and zone pacing is unchanged. Apexes got a telegraphed pounce so lurching away isn't a free escape (about 8 apex hits per run, up from about 4).

Fourth round (rival ooze, relative-size damage):

- **What kills apexes.** Damage attribution showed apexes mostly die at about your size, to a mix of sources: Swarm critters up to 47%, lurch rams up to 44%, shards up to 44%, plus fire. The reported one-shot came from a jump-ahead start, which hands you all your earned ranks at once while the apex is about 2.8× your size. The size falloff targets exactly that case. In full runs no apex dies in the first minute of its zone, and peer kill counts stay close to baseline.
- **Rival regeneration.** The first version let it grow by eating, and its growth cap followed your size, so it kept pace forever and was unbeatable. Meals now only heal it back toward its arrival size.
- **Autopilot kiting.** The bot used to kite the rival from outside every ability's range, so fights only ended when it outgrew the rival. It now fights at close range and backs off when the rival winds up a lunge. In full 20-minute runs the duel lasts 30–66 s (3 seeds, all wins). Runs started from a jump-ahead save give the player fewer forks, so their duels run longer, up to 3 minutes when the rival arrives at 2× your size and keeps eating back to full.

Fifth round (terrain hazards):

- **Spread too thin.** The first pass placed 20 features per zone, and the bot walked around them: about 6–9% of the run on patches, 13–24 pieces lost. It's now 34 per zone plus patches that keep appearing at your scale, with bait in the harmful ones. The autopilot now spends about 12% of a run on patches and loses about 30 pieces to them, while still dodging harmful spills on purpose. A player going for the bait will feel them more.

Sixth round (deadly apex):

- **Apex hits didn't show.** Debug runs (`--apex_test` puts the zone's apex next to an idle player and logs every hit) showed the apex was landing hits all along. Each one knocked off about 4 pieces, but buried pieces resurfaced right away, so the player just shrank slowly and never visibly took damage. Three of the seven apexes had no ranged attack at all.
- **Fix.** Contact is now a direct core strike. Every apex has a ranged attack with distinct red shots, and hits show "−N" pieces lost plus a red flash. The first version killed one autopilot run at 0:56 because the apex re-struck faster than anyone could escape, and a breach on a player with no surface armor counted twice. With a post-strike retreat and the double count fixed, four full runs survived 7–11 apex strikes each and all won.

Seventh round (rival from the start, planet core goal):

- **Rival as a snack.** In the first pass the rival reformed at 0.6× your size and could never catch up, so the autopilot ate it 11–13 times per run and the competition was over by about 5 minutes. It now reforms at 0.95× your size, after 45 s instead of 60, with stronger catch-up growth while it's behind. Across three full runs its size stayed between 0.86× and 1.19× of the player's most of the time. Outcomes: a core win at 19:17, a loss when the rival consumed the core first at 18:25, and a Rat King kill at 1:51 while the rival was crowding the player.

Eighth round (uncapped rivals, lethality, modes):

- **Anything can kill.** Buried pieces used to refill your surface the instant it was stripped, so only apex strikes ever reached the core. Now they resurface one at a time. An idle player with no rivals dies to wildlife and terrain about 20 s after its armor starts going.
- **Uncapped rival growth.** The pacing curve alone holds it. In Duel runs the rival stayed between 0.87× and 1.41× the player's size, and both seeds won at about 19 minutes.
- **Free-for-all.** At first all three rivals hunted only the player, and both test runs died in the kitchen. Now each rival hunts the nearest smaller ooze, including other rivals, and they eat each other 2–10 times per run. Four seeds: 3 wins at 18:50–19:21 and 1 loss at 2:22.

Still open: the autopilot dodges well. Two of five autopilot runs since the rival was added died to the Rat King in the kitchen (1:31 and 1:51). It's unclear whether the rival competing for kitchen food makes the opening harsher or those are just hard seeds. Apexes ignore the rival, so it forages freely while you hide. The README's "about 3 km @ 20:00" pacing note predates the core: runs now end at the core around 18–19 minutes. Also and almost never has its core breached outside the rival fight, so difficulty for a real player is unknown. The bot picks forks at random, so it doesn't test build strategy. Every enemy at the 2 km+ range is a "serpent" or "leviathan" because the roster runs out.

Ninth round (multiplayer):

- **One world, many sizes.** The world used to assume a single viewer: anything beneath your notice or off your screen was deleted. With oozes of different sizes in one world, that would delete the smaller player's food. Now a thing is only culled once it's beneath the notice of, and far from, every ooze. Wildlife and apexes react to whichever ooze is nearest. Each zone is built once, by the first ooze to reach it, and stragglers walk into the existing one.
- **Refactor check.** Moving player state into an `Ooze` object and making every random call seeded left single-player unchanged: seeded 300 s autopilot runs (duel and free-for-all) log byte-identical output before and after.
- **Online.** A headless host plus two headless clients (whose autopilots play from the streamed state alone) ran a full 3-player match over localhost. One client left at 5:00 and the autopilot took over its ooze. The host's ooze swallowed the core at 18:15, and the remaining client got the defeat screen. The client autopilot got eaten much more often than the host's (23 times), because it reformed right next to the ooze that ate it. Reforming away from bigger oozes, with a 5 s guard, halved early repeat-eating.
- **3-player autopilot matches** (offline, 3 seeds, with the reform guard). Players stayed within about 1.5× of each other for most of the run and ate each other 22–25 times per match. Each match ended with someone swallowing the core at 18:19–18:47, and the winner differed every seed (P1, P3, P2). Abilities landing on other players knocked 32 hull pieces off in a 4-minute sample.

Still open in multiplayer: the human-input path online (keyboard, click-to-lurch, picking forks, ENTER in the lobby) hasn't been exercised by a person yet, since every online test so far was autopilot on both ends. Over localhost the 4–10 KB snapshots never have to split into smaller packets. On a real LAN they will. If the client's view freezes or stutters while the host runs fine, switch `_net_snap` to reliable delivery. Whoever falls behind gets eaten a lot. In autopilot matches each ooze is eaten about once every 2–3 minutes, mostly the smallest by the largest, and it spends 30 s reforming each time. Real players may hunt less relentlessly than the autopilot, so this needs human playtests before tuning. Players in the same area also share one food budget, which squeezes whoever's on the edge. Online there's no client-side prediction, so your own ooze responds one round trip late.

## Layout

- `scripts/game.gd`: the whole simulation and renderer. It draws manually in screen space, so a single scene spans 4+ orders of magnitude.
- `scripts/defs.gd`: props, enemies, synergies, themes, zones and the essence tree. All tunable data lives here.
- `scripts/bot.gd`: the autopilot used for simulated playtests. It also plays empty multiplayer slots, and online clients can run it on the replicated state (`--join=... --bot`).
- `scripts/net.gd`: online play. Snapshot encoding (filtered to what each player can see) and client-side decoding and smoothing.
- `screenshots/`: frames from simulated runs.
