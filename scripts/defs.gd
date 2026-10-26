class_name Defs
## Static game data. Sizes are radii in meters. Weapon ranges/speeds are in
## multiples of the carrying item's radius, so a weapon's reach scales with the
## object that provides it (a toaster stops mattering once you're a city block).

# --- Weapons (used by hull items) -------------------------------------------
# t: proj | beam | sweep | zap | aura | cone | missile | grapple | none
const W_NONE := {"t": "none"}
const W_TOAST := {"t": "proj", "cd": 1.1, "dmg": 4.0, "rng": 45.0, "spd": 30.0, "n": 1, "spread": 0.06, "br": 0.35, "col": Color(0.95, 0.65, 0.25)}
const W_NAILS := {"t": "proj", "cd": 0.28, "dmg": 1.6, "rng": 40.0, "spd": 55.0, "n": 1, "spread": 0.12, "br": 0.12, "col": Color(0.8, 0.85, 0.9)}
const W_SODA := {"t": "proj", "cd": 0.9, "dmg": 2.5, "rng": 14.0, "spd": 12.0, "n": 3, "spread": 0.35, "br": 0.12, "col": Color(0.9, 0.2, 0.25)}
const W_ARROW := {"t": "proj", "cd": 0.9, "dmg": 3.5, "rng": 30.0, "spd": 30.0, "n": 1, "spread": 0.18, "br": 0.15, "col": Color(0.75, 0.6, 0.35)}
const W_RIFLE := {"t": "proj", "cd": 0.35, "dmg": 2.0, "rng": 22.0, "spd": 30.0, "n": 1, "spread": 0.1, "br": 0.08, "col": Color(1.0, 0.95, 0.5)}
const W_SHELL := {"t": "proj", "cd": 1.6, "dmg": 9.0, "rng": 14.0, "spd": 9.0, "n": 1, "spread": 0.02, "br": 0.22, "col": Color(1.0, 0.6, 0.2)}
const W_BROADSIDE := {"t": "proj", "cd": 1.4, "dmg": 4.0, "rng": 8.0, "spd": 6.0, "n": 6, "spread": 0.6, "br": 0.06, "col": Color(1.0, 0.75, 0.3)}
const W_DESKS := {"t": "proj", "cd": 0.7, "dmg": 2.5, "rng": 6.0, "spd": 4.0, "n": 4, "spread": 0.5, "br": 0.1, "col": Color(0.6, 0.65, 0.7)}
const W_ZAP := {"t": "zap", "cd": 0.9, "dmg": 3.5, "rng": 16.0, "col": Color(0.55, 0.85, 1.0)}
const W_TRANSFORMER := {"t": "zap", "cd": 0.6, "dmg": 2.5, "rng": 9.0, "col": Color(0.6, 0.9, 1.0)}
const W_LAMP := {"t": "beam", "cd": 0.5, "dmg": 1.6, "rng": 14.0, "w": 0.4, "col": Color(1.0, 0.95, 0.6)}
const W_HEADLIGHTS := {"t": "beam", "cd": 0.4, "dmg": 1.4, "rng": 7.0, "w": 0.3, "twin": true, "col": Color(1.0, 1.0, 0.75)}
const W_SIREN := {"t": "sweep", "cd": 0.12, "dmg": 0.7, "rng": 8.0, "w": 0.25, "col": Color(1.0, 0.25, 0.25), "col2": Color(0.3, 0.4, 1.0)}
const W_PLASMA := {"t": "beam", "cd": 0.25, "dmg": 2.2, "rng": 9.0, "w": 0.35, "col": Color(0.4, 1.0, 0.6)}
const W_RADIO := {"t": "sweep", "cd": 0.1, "dmg": 0.8, "rng": 6.0, "w": 0.2, "col": Color(0.9, 0.5, 1.0), "col2": Color(0.6, 0.3, 1.0)}
const W_MOWER := {"t": "aura", "cd": 0.2, "dmg": 1.2, "rng": 2.2, "col": Color(0.6, 1.0, 0.4)}
const W_BITE := {"t": "aura", "cd": 0.25, "dmg": 0.8, "rng": 1.8, "col": Color(1.0, 0.5, 0.5)}
const W_STOMP := {"t": "aura", "cd": 0.5, "dmg": 2.0, "rng": 1.8, "col": Color(0.9, 0.6, 1.0)}
const W_FLAME := {"t": "cone", "cd": 0.18, "dmg": 0.9, "rng": 6.0, "half": 0.32, "col": Color(1.0, 0.45, 0.1)}
const W_FOAM := {"t": "cone", "cd": 0.3, "dmg": 0.6, "rng": 8.0, "half": 0.25, "push": 6.0, "col": Color(0.9, 0.95, 1.0)}
const W_BARK := {"t": "cone", "cd": 0.8, "dmg": 0.4, "rng": 10.0, "half": 0.6, "push": 10.0, "col": Color(1.0, 0.9, 0.5)}
const W_WATER := {"t": "cone", "cd": 0.25, "dmg": 0.7, "rng": 3.0, "half": 0.15, "push": 4.0, "col": Color(0.4, 0.7, 1.0)}
const W_BREATH := {"t": "cone", "cd": 0.15, "dmg": 1.3, "rng": 3.5, "half": 0.3, "col": Color(0.4, 0.8, 1.0)}
const W_MISSILE := {"t": "missile", "cd": 1.4, "dmg": 6.0, "rng": 20.0, "spd": 14.0, "n": 2, "br": 0.15, "col": Color(1.0, 0.5, 0.2)}
const W_GRAPPLE := {"t": "grapple", "cd": 3.0, "dmg": 0.0, "rng": 9.0, "col": Color(1.0, 0.85, 0.2)}

# --- Props -------------------------------------------------------------------
# sh: 0 circle 1 box 2 tri 3 hex 4 diamond. den: density (mass per area).
const PROPS := [
	{"name": "Fork", "lbl": "fk", "r": 0.035, "col": Color(0.75, 0.78, 0.82), "sh": 4, "tags": ["metal"], "w": W_NONE},
	{"name": "Battery", "lbl": "bat", "r": 0.045, "col": Color(0.95, 0.8, 0.2), "sh": 1, "tags": ["electric"], "w": W_ZAP},
	{"name": "Soda Can", "lbl": "can", "r": 0.05, "col": Color(0.85, 0.2, 0.25), "sh": 0, "tags": ["metal"], "w": W_NONE},
	{"name": "Toy Car", "lbl": "toy", "r": 0.07, "col": Color(0.3, 0.6, 0.95), "sh": 1, "tags": ["wheel"], "w": W_NONE},
	{"name": "Anvil", "lbl": "ANVIL", "r": 0.09, "col": Color(0.3, 0.3, 0.35), "sh": 1, "tags": ["metal"], "den": 14.0, "w": W_NONE},
	{"name": "Toaster", "lbl": "TST", "r": 0.11, "den": 2.5, "col": Color(0.85, 0.85, 0.9), "sh": 1, "tags": ["fire"], "w": W_TOAST},
	{"name": "Fire Extinguisher", "lbl": "ext", "r": 0.13, "den": 3.0, "col": Color(0.9, 0.15, 0.15), "sh": 0, "tags": ["metal"], "w": W_FOAM},
	{"name": "Desk Lamp", "lbl": "lmp", "r": 0.15, "col": Color(0.95, 0.9, 0.5), "sh": 2, "tags": ["electric"], "w": W_LAMP},
	{"name": "Nail Gun", "lbl": "NAIL", "r": 0.2, "col": Color(0.95, 0.55, 0.15), "sh": 1, "tags": ["metal"], "w": W_NAILS},
	{"name": "Lawn Mower", "lbl": "MOW", "r": 0.35, "col": Color(0.35, 0.75, 0.3), "sh": 1, "tags": ["mower", "blade", "fire"], "w": W_MOWER},
	{"name": "Shopping Cart", "lbl": "CART", "r": 0.45, "col": Color(0.7, 0.75, 0.8), "sh": 1, "tags": ["cart", "metal", "wheel"], "w": W_NONE},
	{"name": "BBQ Grill", "lbl": "BBQ", "r": 0.5, "col": Color(0.25, 0.25, 0.28), "sh": 0, "tags": ["fire"], "w": W_FLAME},
	{"name": "Gym Safe", "lbl": "SAFE", "r": 0.5, "col": Color(0.4, 0.42, 0.45), "sh": 1, "tags": ["metal"], "den": 14.0, "w": W_NONE},
	{"name": "Bicycle", "lbl": "BIKE", "r": 0.55, "col": Color(0.2, 0.8, 0.8), "sh": 4, "tags": ["wheel", "metal"], "w": W_NONE},
	{"name": "Transformer Box", "lbl": "XFMR", "r": 0.6, "col": Color(0.45, 0.6, 0.45), "sh": 1, "tags": ["transformer", "electric"], "w": W_TRANSFORMER},
	{"name": "Knight Statue", "lbl": "KNT", "r": 0.7, "col": Color(0.6, 0.6, 0.65), "sh": 2, "tags": ["knight", "metal"], "den": 4.0, "w": W_NONE},
	{"name": "Vending Machine", "lbl": "VEND", "r": 0.8, "den": 4.0, "col": Color(0.85, 0.25, 0.3), "sh": 1, "tags": ["metal", "electric"], "w": W_SODA},
	{"name": "Hot Tub", "lbl": "TUB", "r": 1.2, "col": Color(0.4, 0.7, 0.9), "sh": 3, "tags": [], "w": W_WATER},
	{"name": "Streetlamp", "lbl": "LAMP", "r": 1.6, "col": Color(0.9, 0.9, 0.6), "sh": 2, "tags": ["electric", "metal"], "w": W_LAMP},
	{"name": "Sedan", "lbl": "CAR", "r": 2.0, "col": Color(0.3, 0.5, 0.85), "sh": 1, "tags": ["wheel", "metal"], "w": W_HEADLIGHTS},
	{"name": "Police Cruiser", "lbl": "COP", "r": 2.2, "col": Color(0.15, 0.2, 0.35), "sh": 1, "tags": ["wheel", "metal", "police"], "w": W_SIREN},
	{"name": "Bank Vault", "lbl": "VAULT", "r": 2.4, "col": Color(0.55, 0.5, 0.35), "sh": 1, "tags": ["metal"], "den": 14.0, "w": W_NONE},
	{"name": "Oak Tree", "lbl": "TREE", "r": 2.6, "col": Color(0.25, 0.55, 0.25), "sh": 0, "tags": ["organic"], "w": W_NONE},
	{"name": "Food Truck", "lbl": "FOOD", "r": 3.2, "col": Color(0.95, 0.75, 0.3), "sh": 1, "tags": ["fire", "wheel"], "w": W_FLAME},
	{"name": "City Bus", "lbl": "BUS", "r": 4.5, "col": Color(0.95, 0.6, 0.15), "sh": 1, "tags": ["wheel", "fire"], "w": W_FLAME},
	{"name": "Container", "lbl": "BOX", "r": 6.0, "den": 4.0, "col": Color(0.7, 0.3, 0.2), "sh": 1, "tags": ["metal"], "w": W_NONE},
	{"name": "Gas Station", "lbl": "GAS", "r": 8.0, "col": Color(0.9, 0.3, 0.2), "sh": 1, "tags": ["fire"], "w": W_FLAME},
	{"name": "Water Tower", "lbl": "H2O", "r": 10.0, "col": Color(0.6, 0.75, 0.85), "sh": 0, "tags": ["metal"], "w": W_WATER},
	{"name": "Sushi Train", "lbl": "SUSHI", "r": 12.0, "col": Color(0.95, 0.5, 0.55), "sh": 3, "tags": ["sushi", "organic"], "w": W_NONE},
	{"name": "Harbour Crane", "lbl": "CRANE", "r": 17.0, "col": Color(0.95, 0.8, 0.15), "sh": 2, "tags": ["crane", "metal"], "w": W_GRAPPLE},
	{"name": "Ferris Wheel", "lbl": "FERRIS", "r": 26.0, "col": Color(0.85, 0.4, 0.8), "sh": 0, "tags": ["wheel", "metal"], "w": W_STOMP},
	{"name": "Gold Reserve", "lbl": "GOLD", "r": 30.0, "col": Color(0.9, 0.75, 0.2), "sh": 1, "tags": ["metal"], "den": 14.0, "w": W_NONE},
	{"name": "Office Tower", "lbl": "OFFICE", "r": 40.0, "col": Color(0.5, 0.6, 0.75), "sh": 1, "tags": ["metal"], "w": W_DESKS},
	{"name": "Radio Tower", "lbl": "RADIO", "r": 60.0, "col": Color(0.85, 0.3, 0.3), "sh": 2, "tags": ["electric", "metal"], "w": W_RADIO},
	{"name": "City Block", "lbl": "BLOCK", "r": 75.0, "col": Color(0.55, 0.5, 0.45), "sh": 1, "tags": ["organic"], "w": W_NONE},
	{"name": "Stadium", "lbl": "STADIUM", "r": 130.0, "col": Color(0.4, 0.75, 0.45), "sh": 3, "tags": ["organic"], "w": W_STOMP},
	{"name": "Battleship", "lbl": "BSHIP", "r": 160.0, "den": 5.0, "col": Color(0.45, 0.5, 0.55), "sh": 4, "tags": ["metal"], "w": W_BROADSIDE},
	{"name": "Nuclear Plant", "lbl": "NUKE", "r": 200.0, "col": Color(0.6, 0.9, 0.5), "sh": 3, "tags": ["electric"], "w": W_PLASMA},
	{"name": "Cruise Ship", "lbl": "CRUISE", "r": 260.0, "col": Color(0.95, 0.95, 0.95), "sh": 4, "tags": ["organic"], "w": W_NONE},
	{"name": "Aircraft Carrier", "lbl": "CARRIER", "r": 380.0, "col": Color(0.4, 0.45, 0.5), "sh": 4, "tags": ["metal"], "w": W_MISSILE},
	{"name": "Mountain", "lbl": "MTN", "r": 600.0, "col": Color(0.5, 0.45, 0.4), "sh": 2, "tags": [], "den": 3.0, "w": W_NONE},
	{"name": "Volcano", "lbl": "VOLCANO", "r": 900.0, "col": Color(0.6, 0.25, 0.15), "sh": 2, "tags": ["fire"], "w": W_FLAME},
	{"name": "Megacity", "lbl": "MEGACITY", "r": 1400.0, "col": Color(0.6, 0.6, 0.7), "sh": 3, "tags": ["organic", "electric"], "w": W_PLASMA},
	{"name": "Moon Shard", "lbl": "MOON", "r": 2600.0, "col": Color(0.8, 0.8, 0.75), "sh": 0, "tags": [], "den": 3.0, "w": W_NONE},
]

# --- Enemies -----------------------------------------------------------------
# spd: chase speed in own radii/sec. beh: swarm | chase | ranged | ram | fly
# atk: hostile projectile attack while alive (rng/spd in PLAYER radii so threats
# stay on-screen). w: weapon granted once assimilated (legs kicking, still firing).
const ENEMIES := [
	{"name": "Rat", "lbl": "rat", "r": 0.06, "col": Color(0.55, 0.45, 0.4), "hp": 1.0, "spd": 9.0, "beh": "swarm", "flee": true, "tags": ["organic"], "w": W_BITE},
	{"name": "Chihuahua", "lbl": "chi", "r": 0.12, "col": Color(0.85, 0.7, 0.45), "hp": 1.5, "spd": 7.0, "beh": "swarm", "tags": ["organic"], "w": W_BARK},
	{"name": "Roomba", "lbl": "RMB", "r": 0.17, "col": Color(0.3, 0.3, 0.35), "hp": 4.0, "spd": 3.0, "beh": "chase", "tags": ["electric", "wheel"], "w": W_ZAP},
	{"name": "Goblin Archer", "lbl": "GOB", "r": 0.25, "col": Color(0.4, 0.7, 0.3), "hp": 2.0, "spd": 4.0, "beh": "ranged", "tags": ["organic"], "w": W_ARROW,
		"atk": {"cd": 2.2, "spd": 4.0, "rng": 7.0, "pow": 1.0}},
	{"name": "Mall Cop", "lbl": "COP", "r": 0.4, "col": Color(0.3, 0.35, 0.6), "hp": 3.0, "spd": 3.5, "beh": "chase", "tags": ["organic"], "w": W_ZAP},
	{"name": "Guard Dog", "lbl": "DOG", "r": 0.6, "col": Color(0.35, 0.25, 0.2), "hp": 2.5, "spd": 5.0, "beh": "swarm", "tags": ["organic"], "w": W_BITE},
	{"name": "Soldier", "lbl": "SOL", "r": 0.9, "col": Color(0.4, 0.5, 0.3), "hp": 2.5, "spd": 2.8, "beh": "ranged", "tags": ["organic"], "w": W_RIFLE,
		"atk": {"cd": 1.6, "spd": 6.0, "rng": 6.5, "pow": 1.0}},
	{"name": "Riot Horse", "lbl": "HRS", "r": 1.5, "col": Color(0.5, 0.35, 0.25), "hp": 3.0, "spd": 3.5, "beh": "chase", "tags": ["organic"], "w": W_STOMP},
	{"name": "SWAT Van", "lbl": "SWAT", "r": 2.8, "col": Color(0.15, 0.15, 0.2), "hp": 4.0, "spd": 2.5, "beh": "ram", "tags": ["metal", "wheel"], "w": W_HEADLIGHTS},
	{"name": "Attack Heli", "lbl": "HELI", "r": 4.5, "col": Color(0.35, 0.4, 0.35), "hp": 3.0, "spd": 2.2, "beh": "ranged", "fly": true, "tags": ["metal"], "w": W_MISSILE,
		"atk": {"cd": 2.0, "spd": 5.0, "rng": 8.0, "pow": 1.2, "homing": true}},
	{"name": "Tank", "lbl": "TANK", "r": 5.5, "col": Color(0.35, 0.45, 0.25), "hp": 6.0, "spd": 1.4, "beh": "ranged", "tags": ["metal"], "w": W_SHELL,
		"atk": {"cd": 2.6, "spd": 7.0, "rng": 7.0, "pow": 1.6}},
	{"name": "Giant Mech", "lbl": "MECH", "r": 11.0, "col": Color(0.6, 0.6, 0.7), "hp": 5.0, "spd": 1.8, "beh": "chase", "tags": ["metal", "electric"], "w": W_MISSILE},
	{"name": "Gunship", "lbl": "GUNSHIP", "r": 26.0, "col": Color(0.3, 0.35, 0.4), "hp": 4.0, "spd": 1.8, "beh": "ranged", "fly": true, "tags": ["metal"], "w": W_RIFLE,
		"atk": {"cd": 0.9, "spd": 7.0, "rng": 8.0, "pow": 0.8}},
	{"name": "Mega Robot", "lbl": "ROBOT", "r": 55.0, "col": Color(0.75, 0.3, 0.3), "hp": 5.0, "spd": 2.0, "beh": "ram", "tags": ["metal", "electric"], "w": W_PLASMA},
	{"name": "Kaiju", "lbl": "KAIJU", "r": 95.0, "col": Color(0.3, 0.55, 0.45), "hp": 6.0, "spd": 2.0, "beh": "chase", "tags": ["organic"], "w": W_BREATH},
	{"name": "Walking Skyscraper", "lbl": "TOWER", "r": 190.0, "col": Color(0.5, 0.55, 0.7), "hp": 4.0, "spd": 1.3, "beh": "ranged", "tags": ["metal"], "w": W_DESKS,
		"atk": {"cd": 1.2, "spd": 6.0, "rng": 8.0, "pow": 1.0}},
	{"name": "Eldritch Titan", "lbl": "TITAN", "r": 330.0, "col": Color(0.45, 0.25, 0.55), "hp": 7.0, "spd": 1.6, "beh": "chase", "tags": ["organic"], "w": W_STOMP},
	{"name": "Sky Leviathan", "lbl": "LEVIATHAN", "r": 750.0, "col": Color(0.3, 0.3, 0.6), "hp": 6.0, "spd": 1.8, "beh": "ranged", "fly": true, "tags": ["organic"], "w": W_BREATH,
		"atk": {"cd": 1.5, "spd": 6.0, "rng": 8.0, "pow": 1.4}},
	{"name": "World Serpent", "lbl": "SERPENT", "r": 1600.0, "col": Color(0.25, 0.5, 0.35), "hp": 7.0, "spd": 2.2, "beh": "chase", "tags": ["organic"], "w": W_BREATH},
]

const BOSS := {"name": "RIVAL SINGULARITY", "lbl": "RIVAL", "r": 1.0, "col": Color(0.9, 0.2, 0.4), "hp": 1.0, "spd": 2.6, "beh": "boss", "tags": [], "w": W_NONE}

# --- Synergies (adjacency on the hull) ----------------------------------------
# A catalyst item activates the synergy when enough tagged items sit within
# `win` radians of it on the hull surface.
const SYNERGIES := [
	{"id": "tesla", "name": "Junkyard Tesla", "cat": "transformer", "need": "cart", "n": 2, "win": 1.6,
		"desc": "Faraday cage: chain lightning arcs to near-misses"},
	{"id": "blender", "name": "Medieval Blender", "cat": "knight", "need": "mower", "n": 2, "win": 1.6,
		"desc": "Spectral halberds orbit faster the faster you roll"},
	{"id": "buffet", "name": "Kaiju Buffet", "cat": "crane", "need": "sushi", "n": 1, "win": 1.6,
		"desc": "Crane grapples elites into your crush radius"},
	{"id": "lightshow", "name": "Code Three", "cat": "police", "need": "electric", "n": 1, "win": 1.6,
		"desc": "Sirens sweep twice as wide and twice as hard"},
]

# Themed clusters: synergy kits that spawn together. First item is the catalyst.
const THEMES := [
	{"name": "junkyard", "items": ["Transformer Box", "Shopping Cart", "Shopping Cart", "Shopping Cart", "Bicycle"]},
	{"name": "castle garden", "items": ["Knight Statue", "Lawn Mower", "Lawn Mower", "Lawn Mower", "BBQ Grill"]},
	{"name": "precinct", "items": ["Police Cruiser", "Streetlamp", "Streetlamp", "Sedan", "Police Cruiser"]},
	{"name": "harbour", "items": ["Harbour Crane", "Sushi Train", "Container", "Container"]},
]

# --- Collapse auras (crushed core composition) --------------------------------
const AURAS := [
	{"tag": "metal", "name": "Iron Core", "per": 40, "desc": "hits knock off fewer pieces"},
	{"tag": "electric", "name": "Lightning Trail", "per": 20, "desc": "leave a sparking wake"},
	{"tag": "fire", "name": "Ember Halo", "per": 20, "desc": "burn everything close"},
	{"tag": "organic", "name": "Biomass", "per": 30, "desc": "stronger gravity pull, core regen"},
	{"tag": "wheel", "name": "Momentum", "per": 25, "desc": "+roll speed"},
	{"tag": "blade", "name": "Shrapnel Bloom", "per": 12, "desc": "slams spray shrapnel"},
]
