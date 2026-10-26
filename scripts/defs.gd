class_name Defs
## Static game data. Sizes are radii in meters. Absorbed things feed "essence"
## into the ability tree through their tags; they don't fire on their own.

# --- Props -------------------------------------------------------------------
# sh: 0 circle 1 box 2 tri 3 hex 4 diamond. den: density (mass per area).
const PROPS := [
	{"name": "Fork", "lbl": "fk", "r": 0.035, "col": Color(0.75, 0.78, 0.82), "sh": 4, "tags": ["metal", "blade"]},
	{"name": "Birthday Candle", "lbl": "cndl", "r": 0.03, "col": Color(1.0, 0.75, 0.4), "sh": 2, "tags": ["fire"]},
	{"name": "Battery", "lbl": "bat", "r": 0.045, "col": Color(0.95, 0.8, 0.2), "sh": 1, "tags": ["electric"]},
	{"name": "Lighter", "lbl": "ltr", "r": 0.045, "col": Color(0.95, 0.35, 0.2), "sh": 1, "tags": ["fire"]},
	{"name": "Soda Can", "lbl": "can", "r": 0.05, "col": Color(0.85, 0.2, 0.25), "sh": 0, "tags": ["metal"]},
	{"name": "Scissors", "lbl": "scis", "r": 0.06, "col": Color(0.9, 0.3, 0.4), "sh": 2, "tags": ["blade"]},
	{"name": "Toy Car", "lbl": "toy", "r": 0.07, "col": Color(0.3, 0.6, 0.95), "sh": 1, "tags": ["wheel"]},
	{"name": "Anvil", "lbl": "ANVIL", "r": 0.09, "col": Color(0.3, 0.3, 0.35), "sh": 1, "tags": ["metal"], "den": 14.0},
	{"name": "Toaster", "lbl": "TST", "r": 0.11, "den": 2.5, "col": Color(0.85, 0.85, 0.9), "sh": 1, "tags": ["fire"]},
	{"name": "Fire Extinguisher", "lbl": "ext", "r": 0.13, "den": 3.0, "col": Color(0.9, 0.15, 0.15), "sh": 0, "tags": ["metal"]},
	{"name": "Desk Lamp", "lbl": "lmp", "r": 0.15, "col": Color(0.95, 0.9, 0.5), "sh": 2, "tags": ["electric"]},
	{"name": "Space Heater", "lbl": "HEAT", "r": 0.18, "col": Color(0.9, 0.45, 0.25), "sh": 1, "tags": ["fire", "electric"]},
	{"name": "Nail Gun", "lbl": "NAIL", "r": 0.2, "col": Color(0.95, 0.55, 0.15), "sh": 1, "tags": ["metal", "blade"]},
	{"name": "Chainsaw", "lbl": "SAW", "r": 0.28, "col": Color(0.95, 0.5, 0.1), "sh": 4, "tags": ["blade", "fire"]},
	{"name": "Lawn Mower", "lbl": "MOW", "r": 0.35, "col": Color(0.35, 0.75, 0.3), "sh": 1, "tags": ["mower", "blade", "fire"]},
	{"name": "Shopping Cart", "lbl": "CART", "r": 0.45, "col": Color(0.7, 0.75, 0.8), "sh": 1, "tags": ["cart", "wheel"]},
	{"name": "BBQ Grill", "lbl": "BBQ", "r": 0.5, "col": Color(0.25, 0.25, 0.28), "sh": 0, "tags": ["fire"]},
	{"name": "Gym Safe", "lbl": "SAFE", "r": 0.5, "col": Color(0.4, 0.42, 0.45), "sh": 1, "tags": ["metal"], "den": 14.0},
	{"name": "Bicycle", "lbl": "BIKE", "r": 0.55, "col": Color(0.2, 0.8, 0.8), "sh": 4, "tags": ["wheel"]},
	{"name": "Transformer Box", "lbl": "XFMR", "r": 0.6, "col": Color(0.45, 0.6, 0.45), "sh": 1, "tags": ["transformer", "electric"]},
	{"name": "Knight Statue", "lbl": "KNT", "r": 0.7, "col": Color(0.6, 0.6, 0.65), "sh": 2, "tags": ["knight", "blade"], "den": 4.0},
	{"name": "Vending Machine", "lbl": "VEND", "r": 0.8, "den": 4.0, "col": Color(0.85, 0.25, 0.3), "sh": 1, "tags": ["electric"]},
	{"name": "Hot Tub", "lbl": "TUB", "r": 1.2, "col": Color(0.4, 0.7, 0.9), "sh": 3, "tags": []},
	{"name": "Fireworks Stand", "lbl": "BOOM", "r": 1.4, "col": Color(0.95, 0.3, 0.5), "sh": 3, "tags": ["fire"]},
	{"name": "Streetlamp", "lbl": "LAMP", "r": 1.6, "col": Color(0.9, 0.9, 0.6), "sh": 2, "tags": ["electric"]},
	{"name": "Sedan", "lbl": "CAR", "r": 2.0, "col": Color(0.3, 0.5, 0.85), "sh": 1, "tags": ["wheel", "metal"]},
	{"name": "Police Cruiser", "lbl": "COP", "r": 2.2, "col": Color(0.15, 0.2, 0.35), "sh": 1, "tags": ["wheel", "police"]},
	{"name": "Bank Vault", "lbl": "VAULT", "r": 2.4, "col": Color(0.55, 0.5, 0.35), "sh": 1, "tags": ["metal"], "den": 14.0},
	{"name": "Oak Tree", "lbl": "TREE", "r": 2.6, "col": Color(0.25, 0.55, 0.25), "sh": 0, "tags": ["organic"]},
	{"name": "Food Truck", "lbl": "FOOD", "r": 3.2, "col": Color(0.95, 0.75, 0.3), "sh": 1, "tags": ["fire", "wheel"]},
	{"name": "Combine Harvester", "lbl": "COMBINE", "r": 4.0, "col": Color(0.3, 0.65, 0.25), "sh": 1, "tags": ["blade", "wheel"]},
	{"name": "City Bus", "lbl": "BUS", "r": 4.5, "col": Color(0.95, 0.6, 0.15), "sh": 1, "tags": ["wheel", "fire"]},
	{"name": "Container", "lbl": "BOX", "r": 6.0, "den": 4.0, "col": Color(0.7, 0.3, 0.2), "sh": 1, "tags": ["metal"]},
	{"name": "Gas Station", "lbl": "GAS", "r": 8.0, "col": Color(0.9, 0.3, 0.2), "sh": 1, "tags": ["fire"]},
	{"name": "Rocket", "lbl": "ROCKET", "r": 9.0, "col": Color(0.92, 0.92, 0.95), "sh": 2, "tags": ["fire", "wheel"]},
	{"name": "Water Tower", "lbl": "H2O", "r": 10.0, "col": Color(0.6, 0.75, 0.85), "sh": 0, "tags": ["metal"]},
	{"name": "Sushi Train", "lbl": "SUSHI", "r": 12.0, "col": Color(0.95, 0.5, 0.55), "sh": 3, "tags": ["sushi", "organic"]},
	{"name": "Harbour Crane", "lbl": "CRANE", "r": 17.0, "col": Color(0.95, 0.8, 0.15), "sh": 2, "tags": ["crane", "metal"]},
	{"name": "Wind Turbine", "lbl": "TURBINE", "r": 22.0, "col": Color(0.9, 0.92, 0.95), "sh": 2, "tags": ["blade", "electric"]},
	{"name": "Ferris Wheel", "lbl": "FERRIS", "r": 26.0, "col": Color(0.85, 0.4, 0.8), "sh": 0, "tags": ["wheel"]},
	{"name": "Gold Reserve", "lbl": "GOLD", "r": 30.0, "col": Color(0.9, 0.75, 0.2), "sh": 1, "tags": ["metal"], "den": 14.0},
	{"name": "Office Tower", "lbl": "OFFICE", "r": 40.0, "col": Color(0.5, 0.6, 0.75), "sh": 1, "tags": ["metal"]},
	{"name": "Radio Tower", "lbl": "RADIO", "r": 60.0, "col": Color(0.85, 0.3, 0.3), "sh": 2, "tags": ["electric"]},
	{"name": "City Block", "lbl": "BLOCK", "r": 75.0, "col": Color(0.55, 0.5, 0.45), "sh": 1, "tags": ["organic"]},
	{"name": "Stadium", "lbl": "STADIUM", "r": 130.0, "col": Color(0.4, 0.75, 0.45), "sh": 3, "tags": ["organic"]},
	{"name": "Oil Refinery", "lbl": "REFINERY", "r": 140.0, "col": Color(0.55, 0.4, 0.3), "sh": 3, "tags": ["fire"]},
	{"name": "Battleship", "lbl": "BSHIP", "r": 160.0, "den": 5.0, "col": Color(0.45, 0.5, 0.55), "sh": 4, "tags": ["metal"]},
	{"name": "Nuclear Plant", "lbl": "NUKE", "r": 200.0, "col": Color(0.6, 0.9, 0.5), "sh": 3, "tags": ["electric"]},
	{"name": "Cruise Ship", "lbl": "CRUISE", "r": 260.0, "col": Color(0.95, 0.95, 0.95), "sh": 4, "tags": ["organic"]},
	{"name": "Aircraft Carrier", "lbl": "CARRIER", "r": 380.0, "col": Color(0.4, 0.45, 0.5), "sh": 4, "tags": ["metal"]},
	{"name": "Mountain", "lbl": "MTN", "r": 600.0, "col": Color(0.5, 0.45, 0.4), "sh": 2, "tags": [], "den": 3.0},
	{"name": "Glacier Shelf", "lbl": "GLACIER", "r": 750.0, "col": Color(0.75, 0.9, 1.0), "sh": 4, "tags": ["blade"]},
	{"name": "Volcano", "lbl": "VOLCANO", "r": 900.0, "col": Color(0.6, 0.25, 0.15), "sh": 2, "tags": ["fire"]},
	{"name": "Megacity", "lbl": "MEGACITY", "r": 1400.0, "col": Color(0.6, 0.6, 0.7), "sh": 3, "tags": ["organic", "electric"]},
	{"name": "Moon Shard", "lbl": "MOON", "r": 2600.0, "col": Color(0.8, 0.8, 0.75), "sh": 0, "tags": [], "den": 3.0},
]

# --- Enemies -----------------------------------------------------------------
# spd: move speed in own radii/sec. beh: swarm | chase | ranged | ram (chase/ram/aggro are aggressive)
# atk: hostile projectile attack while alive (rng/spd in PLAYER radii so threats
# stay on-screen). Creatures wander near home; aggressive ones chase on a leash.
const ENEMIES := [
	{"name": "Rat", "lbl": "rat", "r": 0.06, "col": Color(0.55, 0.45, 0.4), "hp": 1.0, "spd": 9.0, "beh": "swarm", "flee": true, "tags": ["organic"]},
	{"name": "Chihuahua", "lbl": "chi", "r": 0.12, "col": Color(0.85, 0.7, 0.45), "hp": 1.5, "spd": 7.0, "beh": "swarm", "tags": ["organic", "blade"]},
	{"name": "Roomba", "lbl": "RMB", "r": 0.17, "col": Color(0.3, 0.3, 0.35), "hp": 4.0, "spd": 3.0, "beh": "chase", "tags": ["electric", "wheel"]},
	{"name": "Goblin Archer", "lbl": "GOB", "r": 0.25, "col": Color(0.4, 0.7, 0.3), "hp": 2.0, "spd": 4.0, "beh": "ranged", "tags": ["organic", "blade"],
		"atk": {"cd": 2.2, "spd": 4.0, "rng": 7.0, "pow": 1.0}},
	{"name": "Mall Cop", "lbl": "COP", "r": 0.4, "col": Color(0.3, 0.35, 0.6), "hp": 3.0, "spd": 3.5, "beh": "chase", "tags": ["organic", "electric"]},
	{"name": "Guard Dog", "lbl": "DOG", "r": 0.6, "col": Color(0.35, 0.25, 0.2), "hp": 2.5, "spd": 5.0, "beh": "swarm", "tags": ["organic", "blade"]},
	{"name": "Soldier", "lbl": "SOL", "r": 0.9, "col": Color(0.4, 0.5, 0.3), "hp": 2.5, "spd": 2.8, "beh": "ranged", "tags": ["organic", "metal"],
		"atk": {"cd": 1.6, "spd": 6.0, "rng": 6.5, "pow": 1.0}},
	{"name": "Riot Horse", "lbl": "HRS", "r": 1.5, "col": Color(0.5, 0.35, 0.25), "hp": 3.0, "spd": 3.5, "beh": "chase", "tags": ["organic", "wheel"]},
	{"name": "SWAT Van", "lbl": "SWAT", "r": 2.8, "col": Color(0.15, 0.15, 0.2), "hp": 4.0, "spd": 2.5, "beh": "ram", "tags": ["metal", "wheel"]},
	{"name": "Attack Heli", "lbl": "HELI", "r": 4.5, "col": Color(0.35, 0.4, 0.35), "hp": 3.0, "spd": 2.2, "beh": "ranged", "fly": true, "tags": ["metal"],
		"atk": {"cd": 2.0, "spd": 5.0, "rng": 8.0, "pow": 1.2, "homing": true}},
	{"name": "Tank", "lbl": "TANK", "r": 5.5, "col": Color(0.35, 0.45, 0.25), "hp": 6.0, "spd": 1.4, "beh": "ranged", "tags": ["metal"],
		"atk": {"cd": 2.6, "spd": 7.0, "rng": 7.0, "pow": 1.6}},
	{"name": "Giant Mech", "lbl": "MECH", "r": 11.0, "col": Color(0.6, 0.6, 0.7), "hp": 5.0, "spd": 1.8, "beh": "chase", "tags": ["metal", "electric"]},
	{"name": "Gunship", "lbl": "GUNSHIP", "r": 26.0, "col": Color(0.3, 0.35, 0.4), "hp": 4.0, "spd": 1.8, "beh": "ranged", "fly": true, "tags": ["metal"],
		"atk": {"cd": 0.9, "spd": 7.0, "rng": 8.0, "pow": 0.8}},
	{"name": "Mega Robot", "lbl": "ROBOT", "r": 55.0, "col": Color(0.75, 0.3, 0.3), "hp": 5.0, "spd": 2.0, "beh": "ram", "tags": ["metal", "electric", "blade"]},
	{"name": "Kaiju", "lbl": "KAIJU", "r": 95.0, "col": Color(0.3, 0.55, 0.45), "hp": 6.0, "spd": 2.0, "beh": "chase", "tags": ["organic", "fire"]},
	{"name": "Walking Skyscraper", "lbl": "TOWER", "r": 190.0, "col": Color(0.5, 0.55, 0.7), "hp": 4.0, "spd": 1.3, "beh": "ranged", "tags": ["metal"],
		"atk": {"cd": 1.2, "spd": 6.0, "rng": 8.0, "pow": 1.0}},
	{"name": "Eldritch Titan", "lbl": "TITAN", "r": 330.0, "col": Color(0.45, 0.25, 0.55), "hp": 7.0, "spd": 1.6, "beh": "chase", "tags": ["organic", "blade"]},
	{"name": "Sky Leviathan", "lbl": "LEVIATHAN", "r": 750.0, "col": Color(0.3, 0.3, 0.6), "hp": 6.0, "spd": 1.8, "beh": "ranged", "fly": true, "tags": ["organic", "electric"],
		"atk": {"cd": 1.5, "spd": 6.0, "rng": 8.0, "pow": 1.4}},
	{"name": "World Serpent", "lbl": "SERPENT", "r": 1600.0, "col": Color(0.25, 0.5, 0.35), "hp": 7.0, "spd": 2.2, "beh": "chase", "tags": ["organic"]},
]

const BOSS := {"name": "RIVAL SINGULARITY", "lbl": "RIVAL", "r": 1.0, "col": Color(0.9, 0.2, 0.4), "hp": 1.0, "spd": 2.6, "beh": "boss", "tags": []}

# --- Synergies (adjacency on the hull) ----------------------------------------
# A catalyst item activates the synergy when enough tagged items sit within
# `win` radians of it on the hull surface.
const SYNERGIES := [
	{"id": "tesla", "name": "Junkyard Tesla", "cat": "transformer", "need": "cart", "n": 2, "win": 1.6,
		"desc": "Faraday cage: chain lightning arcs to near-misses"},
	{"id": "blender", "name": "Medieval Blender", "cat": "knight", "need": "mower", "n": 2, "win": 1.6,
		"desc": "Spectral halberds orbit faster the faster you roll"},
	{"id": "buffet", "name": "Kaiju Buffet", "cat": "crane", "need": "sushi", "n": 1, "win": 1.6,
		"desc": "the crane grapples big prey into your crush radius"},
	{"id": "lightshow", "name": "Code Three", "cat": "police", "need": "electric", "n": 1, "win": 1.6,
		"desc": "twin siren beams sweep from the cruiser"},
]

# Themed clusters: synergy kits that spawn together. First item is the catalyst.
const THEMES := [
	{"name": "junkyard", "items": ["Transformer Box", "Shopping Cart", "Shopping Cart", "Shopping Cart", "Bicycle"]},
	{"name": "castle garden", "items": ["Knight Statue", "Lawn Mower", "Lawn Mower", "Lawn Mower", "BBQ Grill"]},
	{"name": "precinct", "items": ["Police Cruiser", "Streetlamp", "Streetlamp", "Sedan", "Police Cruiser"]},
	{"name": "harbour", "items": ["Harbour Crane", "Sushi Train", "Container", "Container"]},
]

# --- Size zones ----------------------------------------------------------------
# Nested arenas centred on the origin. Each is ringed by a wall that only becomes
# edible at the zone's exit size, so you have to master the zone to leave it.
# lo/hi: player radius range. Arena radius = ARENA_K * hi.
const ZONES := [
	{"name": "KITCHEN FLOOR", "floor": Color(0.66, 0.47, 0.38), "lo": 0.05, "hi": 0.22,
		"wall": {"name": "Cabinet", "lbl": "CABINET", "col": Color(0.55, 0.4, 0.3), "sh": 1, "tags": ["organic"]},
		"apex": {"name": "Rat King", "lbl": "RAT KING", "col": Color(0.5, 0.33, 0.3), "tags": ["organic"]}},
	{"name": "LIVING ROOM", "floor": Color(0.3, 0.45, 0.48), "lo": 0.22, "hi": 1.0,
		"wall": {"name": "Drywall", "lbl": "WALL", "col": Color(0.72, 0.7, 0.62), "sh": 1, "tags": ["metal"]},
		"apex": {"name": "Roomba Prime", "lbl": "ROOMBA PRIME", "col": Color(0.22, 0.22, 0.27), "tags": ["electric", "wheel"],
			"atk": {"cd": 1.8, "spd": 5.0, "rng": 7.0, "pow": 1.2}}},
	{"name": "BACKYARD", "floor": Color(0.36, 0.52, 0.3), "lo": 1.0, "hi": 4.5,
		"wall": {"name": "Fence", "lbl": "FENCE", "col": Color(0.6, 0.45, 0.25), "sh": 1, "tags": ["organic"]},
		"apex": {"name": "Junkyard Hound", "lbl": "HOUND", "col": Color(0.4, 0.28, 0.2), "tags": ["organic", "blade"]}},
	{"name": "STREET", "floor": Color(0.36, 0.37, 0.41), "lo": 4.5, "hi": 20.0,
		"wall": {"name": "Townhouse", "lbl": "HOUSE", "col": Color(0.7, 0.45, 0.4), "sh": 1, "tags": ["organic", "fire"]},
		"apex": {"name": "SWAT Command", "lbl": "SWAT CMD", "col": Color(0.12, 0.12, 0.18), "tags": ["metal", "wheel"],
			"atk": {"cd": 1.2, "spd": 6.0, "rng": 8.0, "pow": 1.4}}},
	{"name": "DOWNTOWN", "floor": Color(0.5, 0.5, 0.47), "lo": 20.0, "hi": 90.0,
		"wall": {"name": "Skyscraper", "lbl": "TOWER", "col": Color(0.45, 0.55, 0.7), "sh": 1, "tags": ["metal", "electric"]},
		"apex": {"name": "Warden Mech", "lbl": "WARDEN", "col": Color(0.6, 0.6, 0.72), "tags": ["metal", "electric"],
			"atk": {"cd": 1.0, "spd": 6.0, "rng": 9.0, "pow": 1.4, "homing": true}}},
	{"name": "METROPOLIS", "floor": Color(0.34, 0.38, 0.46), "lo": 90.0, "hi": 400.0,
		"wall": {"name": "Overpass", "lbl": "HIGHWAY", "col": Color(0.5, 0.5, 0.52), "sh": 1, "tags": ["metal", "wheel"]},
		"apex": {"name": "Kaiju Matriarch", "lbl": "MATRIARCH", "col": Color(0.25, 0.5, 0.4), "tags": ["organic", "fire"]}},
	{"name": "COASTLINE", "floor": Color(0.68, 0.61, 0.46), "lo": 400.0, "hi": 1200.0,
		"wall": {"name": "Mountain Range", "lbl": "MOUNTAINS", "col": Color(0.5, 0.45, 0.4), "sh": 2, "tags": ["metal"]},
		"apex": {"name": "Elder Titan", "lbl": "ELDER TITAN", "col": Color(0.4, 0.22, 0.5), "tags": ["organic", "electric"],
			"atk": {"cd": 1.4, "spd": 6.0, "rng": 9.0, "pow": 1.6}}},
	{"name": "OPEN WORLD", "floor": Color(0.3, 0.26, 0.3), "lo": 1200.0, "hi": 0.0},
]

# --- Ability tree ---------------------------------------------------------------
# Each branch is fed by the tag of what you absorb. Rank 1 grants the base
# ability; ranks 2-5 each offer a fork of two nodes: [id, name, description].
const TREE := [
	{"tag": "fire", "name": "INFERNO", "col": Color(1.0, 0.5, 0.15),
		"base": ["Flame Jet", "a flame cone vents from your fire-heavy side"],
		"ranks": [
			[["twin", "Twin Jets", "a second jet from the opposite side"], ["long", "Long Burn", "+60% flame reach"]],
			[["halo", "Ember Halo", "burn everything touching you"], ["hot", "White Hot", "+70% flame damage"]],
			[["napalm", "Napalm", "jets leave burning ground"], ["wildfire", "Wildfire", "burning enemies explode on death"]],
			[["sun", "Sun Core", "four jets around the hull"], ["inferno", "Inferno Halo", "a huge, hotter halo"]]]},
	{"tag": "electric", "name": "STORM", "col": Color(0.5, 0.85, 1.0),
		"base": ["Arc Lash", "lightning leaps from your charged side to the nearest foe"],
		"ranks": [
			[["chain", "Chain Lightning", "arcs jump to 2 more targets"], ["cap", "Capacitor", "+70% arc damage"]],
			[["trail", "Lightning Trail", "leave a sparking wake"], ["rapid", "Rapid Discharge", "arcs 80% more often"]],
			[["field", "Tesla Field", "constant zaps to anything close"], ["overload", "Overload", "arcs stun their targets"]],
			[["crown", "Storm Crown", "arcs from three sides at once"], ["clap", "Thunderclap", "a huge shock ring every 5s"]]]},
	{"tag": "metal", "name": "BULWARK", "col": Color(0.75, 0.78, 0.85),
		"base": ["Plating", "hits knock off 20% fewer pieces"],
		"ranks": [
			[["spikes", "Spiked Hull", "anything that hits you gets hurt"], ["magnet", "Magnet", "+50% gravity pull radius"]],
			[["reactive", "Reactive Armor", "getting hit fires shrapnel back"], ["reinforce", "Reinforce", "another -20% pieces lost"]],
			[["heavy", "Heavy Core", "slams hit twice as hard, trigger easier"], ["riveted", "Riveted", "shed pieces last 10s and drift back"]],
			[["fortress", "Fortress", "4 core integrity, regen twice as fast"], ["juggernaut", "Juggernaut", "at speed, big hits strip half as much"]]]},
	{"tag": "organic", "name": "SWARM", "col": Color(0.55, 0.95, 0.45),
		"base": ["Brood", "two critters orbit you and bite nearby enemies"],
		"ranks": [
			[["brood", "Bigger Brood", "+2 critters"], ["ravenous", "Ravenous", "+80% bite damage"]],
			[["regrow", "Regrowth", "core integrity regenerates twice as fast"], ["hunters", "Hunters", "critters range further and faster"]],
			[["spores", "Spore Burst", "kills near you burst into spores"], ["frenzy", "Feeding Frenzy", "critters drag small prey into you"]],
			[["hive", "Hive", "+4 critters"], ["symbiosis", "Symbiosis", "eating creatures repairs the core"]]]},
	{"tag": "wheel", "name": "MOMENTUM", "col": Color(1.0, 0.85, 0.3),
		"base": ["Ram", "+10% speed; rolling into enemies hurts them"],
		"ranks": [
			[["afterburn", "Afterburner", "+15% top speed"], ["traction", "Traction", "+60% acceleration"]],
			[["wake", "Shockwake", "shock rings pulse while at full speed"], ["battering", "Battering Ram", "ram damage x2.5 with knockback"]],
			[["dash", "Dash", "spin-burst also launches you forward"], ["thunder", "Rolling Thunder", "slams recharge twice as fast"]],
			[["unstoppable", "Unstoppable", "at full speed, hits strip half as much"], ["comet", "Comet Trail", "leave a burning trail"]]]},
	{"tag": "blade", "name": "SHRAPNEL", "col": Color(0.85, 0.85, 1.0),
		"base": ["Shard Spray", "sprays piercing shards from your sharp side"],
		"ranks": [
			[["fan", "Fan of Knives", "+4 shards, wider arc"], ["serrated", "Serrated", "+60% damage, +2 pierce"]],
			[["bloom", "Slam Bloom", "slams spray shards"], ["quick", "Quick Release", "sprays 65% more often"]],
			[["orbit", "Halo Blades", "three blades orbit you"], ["ricochet", "Ricochet", "shards bounce to a new target"]],
			[["circle", "Full Circle", "spray in all directions"], ["steel", "Storm of Steel", "twice the shards"]]]},
]
