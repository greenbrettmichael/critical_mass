extends Node2D
## CRITICAL MASS — mechanics prototype.
## Everything is simulated in world meters and drawn manually in screen space
## so a single scene can span 10 cm -> several km without float/camera issues.
##
## Structure of a run: nested size zones (kitchen floor -> living room -> ...),
## each walled in by things you can only eat at the zone's exit size, patrolled
## by an apex predator, and populated by local wildlife. What you eat feeds an
## ability tree; abilities fire from the side of the hull where their material
## is stuck.

const ABSORB := 0.5         # props / wrecks absorbable when r < ABSORB * R
const ABSORB_LIVE := 0.42   # live enemies absorbable when r < ABSORB_LIVE * R
const LOOSE_ABSORB := 0.75  # shed pieces can be re-grabbed up to this ratio
const BURY := 0.05          # surface items get buried once r < BURY * R
const SEE_MIN := 0.12       # things below SEE_MIN * R are beneath notice: they fade out
                            # and can't be eaten, so outgrown material stops feeding the tree
const VIEW_K := 7.0         # half screen height, in player radii
const R0 := 0.05            # 10 cm diameter start
const GROWTH := 0.16
const COLLAPSES := [0.15, 0.4, 1.0, 2.5, 7.0, 25.0, 70.0, 200.0, 600.0, 1500.0]
const MAX_BULLETS := 800
# Designed scale arc (seconds of a 20-min run -> radius). Absorption efficiency
# bends toward it so skilled play runs a bit ahead and sloppy play catches up.
const SCHEDULE := [[0.0, 0.05], [300.0, 1.0], [720.0, 25.0], [1200.0, 1000.0], [1500.0, 4000.0]]
const LOOSE_TIME := 5.0
const ARENA_K := 14.0       # zone arena radius in units of the zone's exit radius
const WALL_K := 0.47        # wall piece radius / zone exit radius (edible at ~0.94x)
const APEX_K := 0.62        # apex radius / zone exit radius
const APEX_HP := 70.0
const ESS_BASE := 3.0       # essence for the next rank; every rank you own (any branch)
const ESS_GROW := 1.2       # multiplies the price of the next one, so diet picks the branch
const MAX_RANK := 5

class Thing:
	var d: Dictionary
	var enemy := false      # live enemy
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var r := 1.0
	var hp := 1.0
	var max_hp := 1.0
	var rot := 0.0
	var age := 0.0
	var flash := 0.0
	var cd := 0.0
	var contact_cd := 0.0
	var loose := -1.0       # >= 0: shed hull piece, seconds until it detonates
	var was_enemy := false  # assimilated creature (keeps kicking on the hull)
	var wreck := false
	var fixed := false      # zone furniture / walls / kits: never despawned by distance
	var wall := false
	var apex := false
	var dead := false
	var gone := false
	var grabbed := false
	var carried := false
	var state := 0
	var st := 0.0
	var elite := false
	var shed_acc := 0.0
	var area_v := 0.0       # growth value carried by a shed hull piece
	var parts := []         # boss hull decoration
	var home := Vector2.ZERO
	var wtarget := Vector2.ZERO
	var leash := 1.0
	var stun := 0.0
	var burn := 0.0
	var pounce := 0.0       # apex pounce wind-up
	var pounce_cd := 0.0
	var dmg_by := {}        # apex/rival damage attribution, for tuning
	var feelers := []       # the rival's feeding tentacles

class HullItem:
	var d: Dictionary
	var r := 0.1
	var area := 0.01
	var mass := 0.01
	var ang := 0.0
	var surface := true
	var creature := false
	var wob := 0.0

class Bullet:
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var life := 1.0
	var dmg := 1.0
	var r := 0.01
	var col := Color.WHITE
	var pierce := 1
	var bounce := 0
	var hostile := false
	var power := 1.0
	var turn := 0.0
	var hit := {}

var rng := RandomNumberGenerator.new()
var run_len := 20.0 * 60.0
var t := 0.0
var bot_mode := false
var bot: Bot = null
var shot_dir := ""
var shot_every := 30.0
var next_shot := 0.0
var shot_n := 0
var quit_after := -1.0
var next_log := 0.0
var frames := 0

# --- player ---
var ppos := Vector2.ZERO
var pvel := Vector2.ZERO
var R := R0
var core_area := 0.0
var core_count := 0
var items: Array[HullItem] = []
var hull_ang := 0.0
var omega := 0.0
var integrity := 3.0
var max_integrity := 3.0
var iframes := 0.0
var burst_t := 0.0
var burst_cd := 0.0
var dash_t := 0.0
# slime-mold movement: a pseudopod reaches for a target, latches, and the body lurches after it
var lurch_state := 0     # 0 idle, 1 reaching, 2 pulling
var lurch_t := 0.0
var lurch_cd := 0.0
var lurch_target: Thing = null
var lurch_tip := Vector2.ZERO
var want_lurch := false
var click_world := Vector2.INF
var feelers := []        # passive feeding tentacles: {"target", "tip", "latched"}
var syn_active := {}    # id -> {"cat": HullItem, "links": Array}
var syn_seen := {}
var com := Vector2.ZERO # hull-local center-of-mass offset
var imbalance := 0.0
var slam_cd := 0.0
var collapse_idx := 0
var stats := {"rival_ate": 0, "lurches": 0, "synergies": 0, "absorbed": 0, "kills": 0, "shed": 0, "recovered": 0, "lost": 0, "slams": 0,
	"collapses": 0, "hits": 0, "core_hits": 0, "apex_kills": 0, "apex_hits": 0, "picks": 0}
var regen_t := 0.0
var game_over := false
var victory := false
var end_t := 0.0
var input_move := Vector2.ZERO
var manual_spin := 0.0
var want_burst := false
var pull_r := 0.0

# --- ability tree ---
var essence := {}       # tag -> float
var ranks := {}         # tag -> int
var nodes := {}         # "tag.id" -> true
var pending := []       # queued choices: {"title", "options": [{tag,id,name,desc,col}]}
var focus_local := {}   # tag -> hull-local angle where that material is concentrated
var tree_by_tag := {}
var cds := {}           # ability cooldowns
var critters := []
var patches := []       # burning ground {pos, r, t}
var bursts := []        # deferred explosions {pos, r, dmg, col}
var halberd_ang := 0.0
var blade_ang := 0.0

# --- zones ---
var zone := 0
var zone_def: Dictionary = {}
var arena_r := INF
var wall_r := 0.0
var zone_open := false
var apexes: Array[Thing] = []

# --- world ---
var props: Array[Thing] = []
var enemies: Array[Thing] = []
var bullets: Array[Bullet] = []
var boss: Thing = null
var boss_spawned := false
var strike_cd := 8.0
var strikes := []
var spawn_acc := 0.0
var grid := {}
var grid_cell := 1.0
var max_enemy_r := 0.0
var nearest_enemy_d := INF
var grabs := []          # [{"e": Thing, "from": HullItem}]

# --- fx ---
var fx_beams := []
var fx_rings := []
var fx_bolts := []
var fx_texts := []
var fx_cones := []
var dust := []
var sparks := []
var banners := []
var shake := 0.0
var shake_off := Vector2.ZERO

# --- camera ---
var cam := Vector2.ZERO
var view_r := R0 * VIEW_K
var zoom := 1.0
var screen := Vector2(1280, 720)
var font: Font
var polys := []
var floor_col := Color(0.66, 0.47, 0.38)
const OOZE := Color(0.045, 0.035, 0.06)
const RIVAL_OOZE := Color(0.17, 0.02, 0.05)
var card_rects := []
var dmg_src := ""       # tag for whatever is dealing player damage right now
var choice_wait := 0
var bot_focus := ""
var choice_hold := 20     # physics frames the autopilot lingers on a fork

var prop_sorted: Array = []
var enemy_sorted: Array = []
var prop_by_name := {}


func _ready() -> void:
	font = ThemeDB.fallback_font
	if "--write-movie" in OS.get_cmdline_args():
		# render at a fixed 1280x720 regardless of how the window manager sizes the
		# window, so recordings are never upscaled from a small tiled window
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		get_window().content_scale_size = Vector2i(1280, 720)
	var seed_v := int(Time.get_unix_time_from_system())
	var start_r := R0
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=")
		var k := kv[0]
		var v := kv[1] if kv.size() > 1 else ""
		match k:
			"bot": bot_mode = true
			"minutes": run_len = float(v) * 60.0
			"shots": shot_dir = v
			"shot_every": shot_every = float(v)
			"seed": seed_v = int(v)
			"quit_after": quit_after = float(v)
			"start_r": start_r = float(v)
			"start_t": t = float(v)
			"choice_hold": choice_hold = int(v)
			"bot_focus": bot_focus = v
	rng.seed = seed_v
	if bot_mode:
		bot = Bot.new()
		bot.rng.seed = seed_v
		bot.focus = bot_focus
	if shot_dir != "":
		DirAccess.make_dir_recursive_absolute(shot_dir)
		next_shot = t + 1.0
	next_log = t
	_build_polys()
	prop_sorted = Defs.PROPS.duplicate()
	for d in Defs.PROPS:
		prop_by_name[d["name"]] = d
	enemy_sorted = Defs.ENEMIES.duplicate()
	for b in Defs.TREE:
		tree_by_tag[b["tag"]] = b
		essence[b["tag"]] = 0.0
		ranks[b["tag"]] = 0
	if start_r > R0:
		_seed_hull(start_r)
	recompute_size()
	view_r = R * VIEW_K
	cam = ppos
	_update_zoom()
	var zi := 0
	while zi < Defs.ZONES.size() - 1 and R >= float(Defs.ZONES[zi]["hi"]) * WALL_K / ABSORB:
		zi += 1
	banners.clear()
	stats["synergies"] = 0
	_setup_zone(zi)
	for i in 50:
		spawn_prop_cluster(true)
	for i in 10:
		spawn_enemy()
	syn_seen = syn_active.duplicate()
	if start_r <= R0:
		_queue_start_choice()


func _seed_hull(target_r: float) -> void:
	# Debug: grow to target radius with a plausible hull for testing later zones.
	while R < target_r:
		var s := R * exp(rng.randf_range(log(0.12), log(0.45)))
		var d: Dictionary = _nearest_def(prop_sorted, s)
		var it := HullItem.new()
		it.d = d
		it.r = s
		it.area = s * s
		it.mass = it.area * float(d.get("den", 1.0))
		it.ang = rng.randf_range(-PI, PI)
		it.wob = rng.randf() * TAU
		place_item(it)
		items.append(it)
		_gain_essence(d, 0.06, true)
		recompute_size()
		while collapse_idx < COLLAPSES.size() and R >= COLLAPSES[collapse_idx]:
			do_collapse(true)
	# debug starts get the ranks their diet earned, with forks auto-picked
	for p in pending:
		_apply_option(p["options"][rng.randi() % p["options"].size()], true)
	pending.clear()


func _build_polys() -> void:
	polys.clear()
	var circ := PackedVector2Array()
	for i in 16:
		circ.append(Vector2.from_angle(TAU * i / 16.0))
	polys.append(circ)
	polys.append(PackedVector2Array([Vector2(-0.85, -0.85), Vector2(0.85, -0.85), Vector2(0.85, 0.85), Vector2(-0.85, 0.85)]))
	polys.append(PackedVector2Array([Vector2(1.1, 0), Vector2(-0.7, 0.95), Vector2(-0.7, -0.95)]))
	var hex := PackedVector2Array()
	for i in 6:
		hex.append(Vector2.from_angle(TAU * i / 6.0))
	polys.append(hex)
	polys.append(PackedVector2Array([Vector2(1.15, 0), Vector2(0, 0.65), Vector2(-1.15, 0), Vector2(0, -0.65)]))


# =============================================================================
# Main loop
# =============================================================================

func _physics_process(dt: float) -> void:
	frames += 1
	screen = get_viewport_rect().size
	if not pending.is_empty():
		# the game pauses while a tree fork is on screen
		if bot != null:
			# linger a moment so screenshots can catch the fork
			choice_wait += 1
			if choice_wait == 2 and shot_dir != "" and stats["picks"] < 6:
				_take_shot("choice")
			if choice_wait == 1:
				print("EVENT t=%.2f frame=%d CHOICE %s" % [t, frames, pending[0]["title"]])
			if choice_wait > choice_hold:
				choice_wait = 0
				_choose(bot.pick(self, pending[0]["options"]))
		return
	if not (game_over or victory):
		t += dt
	_read_input()
	if bot != null:
		var b := bot.think(self, dt)
		input_move = b["move"]
		want_burst = b["burst"]
		manual_spin = b["spin"]
		want_lurch = b.get("lurch", false)

	_build_grid()
	if not (game_over or victory):
		_update_player(dt)
		_update_abilities(dt)
		_update_synergies(dt)
	_update_enemies(dt)
	_update_bullets(dt)
	_update_props(dt)
	_process_bursts()
	if not (game_over or victory):
		_player_collisions()
		_spawning(dt)
		_update_strikes(dt)
		_check_collapse()
		_check_zone()
		_check_boss()
	_cleanup()
	_update_camera(dt)
	_update_floor(dt)
	_update_fx(dt)
	_telemetry()

	if game_over or victory:
		end_t += dt
		if bot_mode and end_t > 3.0 and end_t - dt <= 3.0:
			_take_shot("final")
		if bot_mode and end_t > 3.5:
			_print_log()
			get_tree().quit()
	if quit_after > 0 and t >= quit_after:
		_print_log()
		get_tree().quit()


func _process(_dt: float) -> void:
	queue_redraw()
	if shot_dir != "" and t >= next_shot:
		next_shot += shot_every
		_take_shot("")


func _take_shot(tag: String) -> void:
	if shot_dir == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	shot_n += 1
	var name := "%s/shot_%03d_t%04d%s.png" % [shot_dir, shot_n, int(t), ("_" + tag) if tag != "" else ""]
	img.save_png(name)


func _read_input() -> void:
	var m := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): m.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): m.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): m.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): m.x += 1
	input_move = m.normalized()
	manual_spin = 0.0
	if Input.is_key_pressed(KEY_Q): manual_spin -= 1
	if Input.is_key_pressed(KEY_E): manual_spin += 1
	want_lurch = Input.is_key_pressed(KEY_SPACE)
	want_burst = Input.is_key_pressed(KEY_SHIFT)


func _unhandled_input(ev: InputEvent) -> void:
	if not pending.is_empty():
		if ev is InputEventKey and ev.pressed and not ev.echo:
			var idx: int = ev.keycode - KEY_1
			if idx >= 0 and idx < pending[0]["options"].size():
				_choose(idx)
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			for i in card_rects.size():
				if card_rects[i].has_point(ev.position):
					_choose(i)
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		click_world = (ev.position - screen * 0.5 - shake_off) / zoom + cam
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_R and (game_over or victory):
			get_tree().reload_current_scene()
		elif ev.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif ev.keycode == KEY_F12:
			if shot_dir == "":
				shot_dir = "user://shots"
				DirAccess.make_dir_recursive_absolute(shot_dir)
			_take_shot("manual")


# =============================================================================
# Ability tree
# =============================================================================

func has(id: String) -> bool:
	return nodes.has(id)


func rank(tag: String) -> int:
	return int(ranks.get(tag, 0))


func rank_mult(tag: String) -> float:
	return 1.0 + 0.2 * maxf(0.0, rank(tag) - 1)


func total_ranks() -> int:
	var n := 0
	for tg in ranks:
		n += int(ranks[tg])
	return n


func ess_need(_tag: String) -> float:
	return ESS_BASE * pow(ESS_GROW, total_ranks())


func _queue_start_choice() -> void:
	var tags := tree_by_tag.keys()
	tags.shuffle()
	var opts := []
	for tg in tags.slice(0, 3):
		var b: Dictionary = tree_by_tag[tg]
		opts.append({"tag": tg, "id": "base", "name": "%s: %s" % [b["name"], b["base"][0]], "desc": b["base"][1], "col": b["col"]})
	pending.append({"title": "CHOOSE YOUR STARTING ESSENCE", "sub": "what you eat grows the other branches", "options": opts})


func _gain_essence(d: Dictionary, amount: float, silent: bool = false) -> void:
	# an object's essence is split between its tree tags
	var n := 0
	for tg in d.get("tags", []):
		if tree_by_tag.has(tg):
			n += 1
	if n > 1:
		amount /= n
	for tg in d.get("tags", []):
		if not tree_by_tag.has(tg):
			continue
		essence[tg] = float(essence[tg]) + amount
		while rank(tg) < MAX_RANK and float(essence[tg]) >= ess_need(tg):
			essence[tg] = float(essence[tg]) - ess_need(tg)
			ranks[tg] = rank(tg) + 1
			_on_rank_up(tg, silent)
		if rank(tg) >= MAX_RANK:
			essence[tg] = 0.0


func _on_rank_up(tg: String, silent: bool) -> void:
	var b: Dictionary = tree_by_tag[tg]
	var rk := rank(tg)
	if rk == 1:
		nodes[tg + ".base"] = true
		_recompute_derived()
		if not silent:
			banner("NEW BRANCH: %s" % b["name"], "%s — %s" % [b["base"][0], b["base"][1]])
		return
	var opts := []
	for n in b["ranks"][rk - 2]:
		opts.append({"tag": tg, "id": n[0], "name": n[1], "desc": n[2], "col": b["col"]})
	pending.append({"title": "%s  RANK %d" % [b["name"], rk], "sub": "you've eaten enough %s things — choose a fork" % tg, "options": opts})


func _choose(i: int) -> void:
	var p: Dictionary = pending.pop_front()
	_apply_option(p["options"][clampi(i, 0, p["options"].size() - 1)], false)


func _apply_option(o: Dictionary, silent: bool) -> void:
	var tg: String = o["tag"]
	nodes[tg + "." + String(o["id"])] = true
	if o["id"] == "base" and rank(tg) == 0:
		ranks[tg] = 1
	stats["picks"] += 1
	_recompute_derived()
	if not silent:
		text(ppos + Vector2(0, -R * 1.8), String(o["name"]).to_upper(), o["col"], 18)


func _recompute_derived() -> void:
	max_integrity = 4.0 if has("metal.fortress") else 3.0
	pull_r = R * 2.6 * (1.5 if has("metal.magnet") else 1.0)
	var n := 0
	if has("organic.base"):
		n = 2 + (2 if has("organic.brood") else 0) + (4 if has("organic.hive") else 0)
	while critters.size() < n:
		critters.append({"pos": ppos, "target": null, "cd": 0.0, "carry": null})


func _focus(tg: String) -> float:
	# where on the hull this branch's material sits; abilities fire from there
	var base := float(Defs.TREE.find(tree_by_tag[tg])) * TAU / 6.0
	return hull_ang + float(focus_local.get(tg, base))


func _update_abilities(dt: float) -> void:
	var rate := 1.6 if burst_t > 0.0 else 1.0
	for k in cds:
		cds[k] = float(cds[k]) - dt * rate
	var sp := pvel.length()

	# INFERNO -----------------------------------------------------------------
	dmg_src = "fire"
	if has("fire.base") and float(cds.get("fire", 0.0)) <= 0.0:
		cds["fire"] = 0.15
		var reach := R * 2.6 * (1.6 if has("fire.long") else 1.0)
		if nearest_enemy_d < reach + R:
			var a0 := _focus("fire")
			var angs := [a0]
			if has("fire.sun"):
				angs = [a0, a0 + PI * 0.5, a0 + PI, a0 + PI * 1.5]
			elif has("fire.twin"):
				angs = [a0, a0 + PI]
			var dmg := 0.3 * R * R * (1.7 if has("fire.hot") else 1.0) * rank_mult("fire")
			cds["napalm_tick"] = int(cds.get("napalm_tick", 0)) + 1
			for a: float in angs:
				var p := ppos + Vector2.from_angle(a) * R * 0.9
				_cone(p, a, 0.38, reach, dmg, Color(1.0, 0.45, 0.1), true)
				if has("fire.napalm") and int(cds["napalm_tick"]) % 3 == 0:
					patches.append({"pos": p + Vector2.from_angle(a) * reach * 0.75, "r": R * 0.8, "t": 2.5})
	if has("fire.halo") or has("fire.inferno"):
		if float(cds.get("halo", 0.0)) <= 0.0:
			cds["halo"] = 0.2
			var big := has("fire.inferno")
			for e: Thing in query(ppos, R * (3.2 if big else 1.9)):
				e.burn = 1.5
				hurt(e, R * R * (0.45 if big else 0.25) * rank_mult("fire"))

	# STORM --------------------------------------------------------------------
	dmg_src = "electric"
	if has("electric.base") and float(cds.get("arc", 0.0)) <= 0.0:
		cds["arc"] = 0.9 * (0.55 if has("electric.rapid") else 1.0)
		var srcs := [_focus("electric")]
		if has("electric.crown"):
			srcs = [srcs[0], srcs[0] + TAU / 3.0, srcs[0] + TAU * 2.0 / 3.0]
		var dmg := 2.4 * R * R * (1.7 if has("electric.cap") else 1.0) * rank_mult("electric")
		for a: float in srcs:
			var p := ppos + Vector2.from_angle(a) * R
			var tgt := _nearest_enemy(p, R * 4.5)
			var jumps := 1 + (2 if has("electric.chain") else 0)
			var from := p
			var hitset := {}
			while tgt != null and jumps > 0:
				hitset[tgt] = true
				_bolt(from, tgt.pos, Color(0.6, 0.9, 1.0))
				hurt(tgt, dmg)
				if has("electric.overload"):
					tgt.stun = 0.8
				from = tgt.pos
				jumps -= 1
				var nxt: Thing = null
				for e: Thing in query(from, R * 2.5):
					if not hitset.has(e):
						nxt = e
						break
				tgt = nxt
	if has("electric.trail"):
		if float(cds.get("spark", 0.0)) <= 0.0 and sp > R * 0.5:
			cds["spark"] = 0.12
			sparks.append({"pos": ppos - pvel.normalized() * R * 0.9, "t": 2.5, "r": R * 0.7})
		if float(cds.get("spark_tick", 0.0)) <= 0.0:
			cds["spark_tick"] = 0.2
			for s in sparks:
				for e: Thing in query(s["pos"], s["r"]):
					hurt(e, 0.5 * R * R * rank_mult("electric"))
	if has("electric.field") and float(cds.get("field", 0.0)) <= 0.0:
		cds["field"] = 0.6
		var near: Array = query(ppos, R * 3.2)
		near.shuffle()
		for e: Thing in near.slice(0, 3):
			_bolt(ppos, e.pos, Color(0.7, 0.95, 1.0))
			hurt(e, 1.0 * R * R * rank_mult("electric"))
	if has("electric.clap") and float(cds.get("clap", 0.0)) <= 0.0:
		cds["clap"] = 5.0
		for e: Thing in query(ppos, R * 6.0):
			hurt(e, 5.0 * R * R * rank_mult("electric"))
			e.vel += (e.pos - ppos).normalized() * R * 6.0
		ring(ppos, R * 6.0, Color(0.6, 0.9, 1.0), 0.5)
		shake = maxf(shake, 0.4)

	# SWARM --------------------------------------------------------------------
	dmg_src = "critter"
	if has("organic.base"):
		_update_critters(dt)

	# MOMENTUM -----------------------------------------------------------------
	dmg_src = "wheel"
	if has("wheel.wake") and sp > max_speed() * 0.8 and float(cds.get("wake", 0.0)) <= 0.0:
		cds["wake"] = 0.8
		for e: Thing in query(ppos, R * 2.4):
			hurt(e, 2.0 * R * R * rank_mult("wheel"))
		ring(ppos, R * 2.4, Color(1.0, 0.85, 0.3, 0.7), 0.3)
	if has("wheel.comet") and sp > R and float(cds.get("comet", 0.0)) <= 0.0:
		cds["comet"] = 0.15
		patches.append({"pos": ppos - pvel.normalized() * R, "r": R * 0.7, "t": 2.0})

	# SHRAPNEL -----------------------------------------------------------------
	dmg_src = "blade"
	if has("blade.base") and float(cds.get("spray", 0.0)) <= 0.0:
		cds["spray"] = 1.1 * (0.6 if has("blade.quick") else 1.0)
		if nearest_enemy_d < R * 7.0:
			var n := 5 + (4 if has("blade.fan") else 0)
			if has("blade.steel"):
				n *= 2
			var arc := 0.9 + (0.6 if has("blade.fan") else 0.0)
			if has("blade.circle"):
				arc = TAU
			_spray(ppos, _focus("blade"), n, arc)
	if has("blade.orbit"):
		blade_ang += dt * 4.0
		if float(cds.get("orbit", 0.0)) <= 0.0:
			cds["orbit"] = 0.1
			for i in 3:
				var bp := ppos + Vector2.from_angle(blade_ang + TAU * i / 3.0) * R * 2.0
				for e: Thing in query(bp, R * 0.35):
					hurt(e, 0.5 * R * R * rank_mult("blade"))

	# burning ground (napalm / comet trail)
	dmg_src = "patch"
	if not patches.is_empty() and float(cds.get("patch", 0.0)) <= 0.0:
		cds["patch"] = 0.2
		for pt in patches:
			for e: Thing in query(pt["pos"], pt["r"]):
				e.burn = 1.0
				hurt(e, 0.4 * R * R * maxf(rank_mult("fire"), rank_mult("wheel")))
	for pt in patches:
		pt["t"] -= dt
	patches = patches.filter(func(pt): return pt["t"] > 0.0)


func _spray(c: Vector2, a: float, n: int, arc: float) -> void:
	var dmg := 1.4 * R * R * (1.6 if has("blade.serrated") else 1.0) * rank_mult("blade")
	for i in n:
		var f := (float(i) + 0.5) / n - 0.5
		var ang := a + f * arc + rng.randf_range(-0.05, 0.05)
		var b := _spawn_bullet(c + Vector2.from_angle(ang) * R, Vector2.from_angle(ang) * R * 10.0 + pvel * 0.3, 0.55, dmg, R * 0.07, Color(0.9, 0.9, 1.0), 2 + (2 if has("blade.serrated") else 0))
		if b != null and has("blade.ricochet"):
			b.bounce = 1


func _cone(p: Vector2, a: float, half: float, reach: float, dmg: float, col: Color, burns: bool) -> void:
	for e: Thing in query(p, reach):
		var to := e.pos - p
		if absf(angle_difference(a, to.angle())) < half + e.r / maxf(to.length(), 0.001):
			if burns:
				e.burn = 1.5
			hurt(e, dmg)
	fx_cones.append({"pos": p, "a": a, "half": half, "len": reach, "col": col, "t": 0.12})


func _update_critters(dt: float) -> void:
	var hunt := R * (6.0 if has("organic.hunters") else 3.5)
	var spd := R * (11.0 if has("organic.hunters") else 8.0)
	var bite := 1.2 * R * R * (1.8 if has("organic.ravenous") else 1.0) * rank_mult("organic")
	var n := critters.size()
	for i in n:
		var c: Dictionary = critters[i]
		c["cd"] = float(c["cd"]) - dt
		var home := ppos + Vector2.from_angle(t * 1.5 + TAU * i / n) * R * 1.6
		var carry = c["carry"]
		if carry != null:
			if carry.gone:
				c["carry"] = null
			else:
				c["pos"] = (c["pos"] as Vector2).move_toward(ppos, spd * dt)
				carry.pos = c["pos"]
				if (c["pos"] as Vector2).distance_to(ppos) < R * 1.1:
					carry.carried = false
					if carry.enemy:
						absorb(carry)
					else:
						absorb(carry)
					c["carry"] = null
				continue
		var tgt = c["target"]
		if tgt == null or tgt.dead or tgt.gone or tgt.pos.distance_to(ppos) > hunt * 1.5:
			c["target"] = null
			tgt = _nearest_enemy(c["pos"], hunt)
			if tgt != null and tgt.pos.distance_to(ppos) > hunt:
				tgt = null
			c["target"] = tgt
		if tgt == null and has("organic.frenzy"):
			for p in props:
				if not p.gone and not p.fixed and not p.carried and p.loose < 0.0 and p.r < 0.3 * R and p.pos.distance_to(ppos) < hunt and p.pos.distance_to(ppos) > pull_r:
					if (c["pos"] as Vector2).distance_to(p.pos) < R * 0.4:
						p.carried = true
						c["carry"] = p
					else:
						c["pos"] = (c["pos"] as Vector2).move_toward(p.pos, spd * dt)
					break
			if c["carry"] != null:
				continue
		if tgt != null:
			c["pos"] = (c["pos"] as Vector2).move_toward(tgt.pos, spd * dt)
			if (c["pos"] as Vector2).distance_to(tgt.pos) < tgt.r + R * 0.2 and float(c["cd"]) <= 0.0:
				c["cd"] = 0.4
				hurt(tgt, bite)
		else:
			c["pos"] = (c["pos"] as Vector2).lerp(home, 1.0 - exp(-6.0 * dt))


func _process_bursts() -> void:
	dmg_src = "burst"
	var todo := bursts.slice(0, 24)
	bursts = bursts.slice(24)
	for b in todo:
		ring(b["pos"], b["r"], b["col"], 0.3)
		for e: Thing in query(b["pos"], b["r"]):
			hurt(e, b["dmg"])


# =============================================================================
# Player physics: rolling, spin, imbalance, slams
# =============================================================================

func max_speed() -> float:
	var m := 1.0
	if has("wheel.base"):
		m += 0.1 + (0.15 if has("wheel.afterburn") else 0.0)
	return 2.3 * R * m * (1.0 - 0.45 * imbalance)


func _update_player(dt: float) -> void:
	iframes -= dt
	burst_t -= dt
	burst_cd -= dt
	slam_cd -= dt
	dash_t -= dt
	var accel := 7.0 * R * (1.0 - 0.6 * imbalance) * (1.6 if has("wheel.traction") else 1.0)
	var target := input_move.limit_length(1.0) * max_speed()
	_update_lurch(dt)
	if dash_t <= 0.0 and lurch_state != 2:
		# an ooze crawl: sluggish to get going, and it bleeds off lurch momentum fast
		var over := pvel.length() > max_speed() * 1.05
		pvel = pvel.move_toward(target, (11.0 * R if over else accel) * dt)
	ppos += pvel * dt
	_update_feelers(dt)

	# Spin model: steering curls the hull, the heavy side swings to trail like a
	# pendulum, and plain rolling adds a slow drift so every side gets a turn.
	var sp := pvel.length()
	var tau := 0.0
	var heavy_ang := hull_ang + com.angle()
	if sp > 0.05 * R:
		var vdir := pvel / sp
		if input_move.length() > 0.1:
			tau += vdir.cross(input_move.normalized()) * (sp / R) * 2.2
		var back := (-vdir).angle()
		tau += sin(angle_difference(heavy_ang, back)) * imbalance * 10.0 * (sp / R)
		tau += 0.3 * (sp / R)
	tau += manual_spin * 9.0
	omega += tau * dt
	omega *= exp(-1.3 * dt)
	if want_burst and burst_cd <= 0.0 and not items.is_empty():
		omega += 12.0 * (signf(omega) if absf(omega) > 0.1 else 1.0)
		burst_t = 2.0
		burst_cd = 7.0
		ring(ppos, R * 2.5, Color(0.8, 0.6, 1.0, 0.8), 0.35)
		if has("wheel.dash"):
			var dir := input_move if input_move.length() > 0.1 else pvel.normalized()
			pvel = dir.normalized() * max_speed() * 2.4
			dash_t = 0.35
			iframes = maxf(iframes, 0.45)
	omega = clampf(omega, -15.0, 15.0)
	hull_ang = wrapf(hull_ang + omega * dt, -PI, PI)

	# Slam: lopsided hull whipping its heavy side across the leading edge.
	var thresh := 0.03 if has("metal.heavy") else 0.06
	if imbalance > thresh and slam_cd <= 0.0 and sp > 1.2 * R:
		heavy_ang = hull_ang + com.angle()
		if absf(angle_difference(pvel.angle(), heavy_ang)) < 0.35:
			_slam(heavy_ang)

	var regen := 1.0 * (2.0 if has("organic.regrow") else 1.0) * (2.0 if has("metal.fortress") else 1.0)
	regen_t += dt * regen
	if regen_t > 25.0:
		regen_t = 0.0
		if integrity < max_integrity:
			integrity = minf(max_integrity, integrity + 1.0)


func lurch_range() -> float:
	return R * (2.6 + 0.7 * rank("organic") + (1.5 if has("organic.hunters") else 0.0))


func lurch_cooldown() -> float:
	return 0.85 / (1.0 + 0.15 * rank("organic"))


func _lurchable(th: Thing) -> bool:
	if th.gone or th.dead or th.carried or th.grabbed or vis_alpha(th.r) <= 0.0:
		return false
	if th.enemy:
		return true
	return th.r < ABSORB * R or (th.loose >= 0.0 and th.r < LOOSE_ABSORB * R)


func _pick_lurch_target(aim: Vector2, point: Vector2) -> Thing:
	var reach := lurch_range()
	var best: Thing = null
	var bs := -INF
	for list in [props, enemies]:
		for th: Thing in list:
			if not _lurchable(th):
				continue
			var to := th.pos - ppos
			var gap := to.length() - th.r - R
			if gap > reach:
				continue
			var sc: float
			if point != Vector2.INF:
				var dp := th.pos.distance_to(point)
				if dp > th.r + R * 1.5:
					continue
				sc = -dp
			else:
				var align := aim.dot(to.normalized()) if aim.length() > 0.1 else 0.5
				if aim.length() > 0.1 and align < 0.35:
					continue
				sc = align * 2.0 + minf(pow(th.r / R, 2.0) * 4.0, 1.0) - maxf(gap, 0.0) / reach * 0.6
				if th.enemy and th.r >= ABSORB_LIVE * R:
					sc -= 0.4
			if sc > bs:
				bs = sc
				best = th
	return best


func _update_lurch(dt: float) -> void:
	lurch_cd -= dt
	match lurch_state:
		0:
			var clicked := click_world != Vector2.INF
			if (want_lurch or clicked) and lurch_cd <= 0.0:
				var aim := input_move if input_move.length() > 0.1 else pvel.normalized()
				var tgt := _pick_lurch_target(aim, click_world)
				if tgt != null:
					lurch_target = tgt
					lurch_state = 1
					lurch_tip = ppos + (tgt.pos - ppos).normalized() * R
					stats["lurches"] += 1
			click_world = Vector2.INF
		1:
			if lurch_target == null or not _lurchable(lurch_target):
				_end_lurch()
				return
			var tp := lurch_target.pos
			lurch_tip = lurch_tip.move_toward(tp, R * 40.0 * dt)
			if lurch_tip.distance_to(tp) <= lurch_target.r:
				lurch_state = 2
				lurch_t = 0.4
		2:
			if lurch_target == null or not _lurchable(lurch_target):
				_end_lurch()
				return
			lurch_t -= dt
			lurch_tip = lurch_target.pos
			# spring the body at the latch point; it overshoots and settles on its own
			var want := (lurch_target.pos - ppos) * 9.0
			want = want.limit_length(R * 16.0)
			pvel = pvel.lerp(want, 1.0 - exp(-18.0 * dt))
			if lurch_t <= 0.0 or ppos.distance_to(lurch_target.pos) < R * 0.5 + lurch_target.r * 0.3:
				_end_lurch()


func _end_lurch() -> void:
	lurch_state = 0
	lurch_target = null
	lurch_cd = lurch_cooldown()


func _update_feelers(dt: float) -> void:
	# Feeding tentacles: each one reaches for a morsel within reach and drags it in.
	var n := mini(3 + rank("organic"), 9)
	while feelers.size() < n:
		feelers.append({"target": null, "tip": ppos, "latched": false})
	var taken := {}
	for f in feelers:
		if f["target"] != null:
			taken[f["target"]] = true
	for f in feelers:
		var tg = f["target"]
		if tg != null and (tg.gone or tg.dead or tg.carried or vis_alpha(tg.r) <= 0.0 or tg.pos.distance_to(ppos) > pull_r * 1.4 + tg.r
				or tg.r >= (ABSORB_LIVE if tg.enemy else ABSORB) * R):
			taken.erase(tg)
			f["target"] = null
			f["latched"] = false
			tg = null
		if tg == null:
			var best: Thing = null
			var bd := INF
			for list in [props, enemies]:
				for th: Thing in list:
					if th.gone or th.dead or th.carried or taken.has(th) or th == lurch_target or th.age < 0.0:
						continue
					if th.loose >= 0.0 and not has("metal.riveted"):
						continue
					if th.r >= (ABSORB_LIVE if th.enemy else ABSORB) * R or vis_alpha(th.r) <= 0.0:
						continue
					var d := th.pos.distance_to(ppos) - th.r
					if d < pull_r and d < bd:
						bd = d
						best = th
			if best != null:
				f["target"] = best
				taken[best] = true
				tg = best
		var tip: Vector2 = f["tip"]
		if tg == null:
			f["tip"] = tip.lerp(ppos, 1.0 - exp(-10.0 * dt))
			continue
		if not f["latched"]:
			f["tip"] = tip.move_toward(tg.pos, R * 14.0 * dt)
			if (f["tip"] as Vector2).distance_to(tg.pos) <= tg.r + R * 0.05:
				f["latched"] = true
		else:
			var to: Vector2 = ppos - tg.pos
			var d := to.length()
			var k := 1.0 - clampf(d / (pull_r + tg.r), 0.0, 1.0)
			tg.pos += to / maxf(d, 0.000001) * R * (1.5 + 5.0 * k) * dt
			if tg.enemy:
				tg.vel = tg.vel * 0.5
			f["tip"] = tg.pos


func _slam(ang: float) -> void:
	dmg_src = "slam"
	slam_cd = 0.4 if has("wheel.thunder") else 0.8
	stats["slams"] += 1
	var c := ppos + Vector2.from_angle(ang) * R * 1.1
	var rad := R * (1.6 + 5.0 * imbalance)
	var dmg := 14.0 * imbalance * R * R * (2.0 if has("metal.heavy") else 1.0)
	for e: Thing in query(c, rad):
		hurt(e, dmg)
		if not e.apex:
			e.vel += (e.pos - c).normalized() * R * 6.0
	ring(c, rad, Color(1.0, 0.85, 0.4, 0.9), 0.4)
	shake = maxf(shake, 0.25 + imbalance)
	if imbalance > 0.12:
		text(c, "SLAM!", Color(1, 0.85, 0.4), 18)
	if has("blade.bloom"):
		_spray(c, ang, 12, 2.4)


# =============================================================================
# Hull: assimilation, placement, size, imbalance, collapse
# =============================================================================

func recompute_size() -> void:
	var total := core_area
	for it in items:
		total += it.area
	R = sqrt(R0 * R0 + GROWTH * total)
	for it in items:
		if it.surface and it.r < BURY * R:
			it.surface = false
	# inner layers sit near the middle; the live surface layer decides the wobble
	var m := Vector2.ZERO
	var mt := core_area * 0.15 + R0 * R0
	var fv := {}
	for it in items:
		if it.surface:
			m += Vector2.from_angle(it.ang) * R * it.mass
			mt += it.mass
			for tg in it.d.get("tags", []):
				fv[tg] = fv.get(tg, Vector2.ZERO) + Vector2.from_angle(it.ang) * it.r
		else:
			mt += it.mass * 0.3
	com = m / mt
	imbalance = clampf(com.length() / R, 0.0, 0.6)
	focus_local.clear()
	for tg in fv:
		if (fv[tg] as Vector2).length() > 0.0:
			focus_local[tg] = (fv[tg] as Vector2).angle()
	_recompute_synergies()
	_recompute_derived()


func sched_r() -> float:
	var tt := t * 1200.0 / run_len
	for i in range(1, SCHEDULE.size()):
		var a: Array = SCHEDULE[i - 1]
		var b: Array = SCHEDULE[i]
		if tt <= b[0] or i == SCHEDULE.size() - 1:
			var f := clampf((tt - a[0]) / (b[0] - a[0]), 0.0, 1.5)
			return exp(lerpf(log(a[1]), log(b[1]), f))
	return R0


func growth_eff() -> float:
	return clampf(pow(sched_r() / R, 1.5), 0.08, 2.0)


func surface_count() -> int:
	var n := 0
	for it in items:
		if it.surface:
			n += 1
	return n


func _angle_free(a: float, it: HullItem) -> bool:
	var w := it.r / R
	for s in items:
		if not s.surface or s == it:
			continue
		if absf(angle_difference(a, s.ang)) < (w + s.r / R) * 0.75 and s.r >= it.r * 0.8:
			return false
	return true


func place_item(it: HullItem) -> void:
	if it.r < BURY * R:
		it.surface = false
		return
	var found := false
	for step in 40:
		for sg: float in [1.0, -1.0]:
			var a: float = it.ang + sg * step * 0.08
			if _angle_free(a, it):
				it.ang = wrapf(a, -PI, PI)
				found = true
				break
		if found:
			break
	if not found:
		it.surface = false
		return
	it.surface = true
	var w := it.r / R
	for s in items:
		if s.surface and s != it and absf(angle_difference(it.ang, s.ang)) < (w + s.r / R) * 0.75:
			s.surface = false


func absorb(th: Thing) -> void:
	var it := HullItem.new()
	it.d = th.d
	it.r = th.r
	# re-absorbed pieces keep the growth value they had; new mass is governed
	it.area = th.area_v if th.loose >= 0.0 else th.r * th.r * growth_eff()
	it.mass = th.r * th.r * float(th.d.get("den", 1.0))
	it.creature = th.enemy or th.was_enemy
	it.ang = wrapf((th.pos - ppos).angle() - hull_ang, -PI, PI)
	it.wob = rng.randf() * TAU
	place_item(it)
	items.append(it)
	if th.loose >= 0.0:
		stats["recovered"] += 1
		if th.r > 0.12 * R:
			text(th.pos, "RECOVERED", Color(0.5, 1.0, 0.6), 14)
	else:
		stats["absorbed"] += 1
		_gain_essence(th.d, minf(1.2, 1.1 * pow(th.r / R, 2.0)))
		if it.creature and has("organic.symbiosis"):
			integrity = minf(max_integrity, integrity + 0.06)
		if th.apex:
			_apex_reward(th, "ATE")
		elif th.r > 0.3 * R:
			var nm: String = th.d["name"]
			if th.enemy:
				nm += " (alive!)"
			text(th.pos, "+" + nm, Color(1, 1, 1) if not th.enemy else Color(1.0, 0.7, 0.6), 13 + int(10 * th.r / R))
	th.gone = true
	th.dead = true
	recompute_size()


func shed(k: int, world_ang: float) -> void:
	var local := world_ang - hull_ang
	var surf: Array = []
	for it in items:
		if it.surface:
			surf.append(it)
	surf.sort_custom(func(a, b): return absf(angle_difference(local, a.ang)) < absf(angle_difference(local, b.ang)))
	# Only the live outer layer is armor. Run out of it and the core takes the hit.
	var taken: Array = surf.slice(0, k)
	var breach := taken.size() < k
	if breach:
		integrity -= 1.0
		stats["core_hits"] += 1
		iframes = 1.6
		# core flare: shove everything away so a breach is survivable
		for e: Thing in query(ppos, R * 5.0):
			if e != boss and not e.apex:
				e.vel += (e.pos - ppos).normalized() * R * 14.0
		ring(ppos, R * 5.0, Color(1, 0.2, 0.2), 0.5)
		shake = maxf(shake, 0.8)
		text(ppos + Vector2(0, -R * 1.6), "CORE BREACH", Color(1, 0.3, 0.3), 20)
		if integrity <= 0.0:
			game_over = true
			print("DEFEAT at T=%.1f" % t)
			banner("SINGULARITY COLLAPSED", "R to restart")
	var life := 10.0 if has("metal.riveted") else LOOSE_TIME
	for it: HullItem in taken:
		items.erase(it)
		var a := hull_ang + it.ang
		var th := Thing.new()
		th.d = it.d
		th.r = it.r
		th.pos = ppos + Vector2.from_angle(a) * (R + it.r * 0.4)
		th.vel = Vector2.from_angle(a + rng.randf_range(-0.5, 0.5)) * R * rng.randf_range(7.0, 11.0)
		th.loose = life
		th.area_v = it.area
		th.was_enemy = it.creature
		th.rot = a
		props.append(th)
		stats["shed"] += 1
	_resurface()
	recompute_size()


func _resurface() -> void:
	# knocked-off pieces expose the layer underneath
	var cands: Array = []
	for it in items:
		if not it.surface and it.r >= BURY * R:
			cands.append(it)
	cands.sort_custom(func(a, b): return a.r > b.r)
	for it: HullItem in cands:
		var w := it.r / R
		var ok := true
		for o in items:
			if o.surface and absf(angle_difference(it.ang, o.ang)) < (w + o.r / R) * 0.75:
				ok = false
				break
		if ok:
			it.surface = true


func _check_collapse() -> void:
	if collapse_idx < COLLAPSES.size() and R >= COLLAPSES[collapse_idx]:
		do_collapse(false)


func do_collapse(silent: bool) -> void:
	dmg_src = "collapse"
	collapse_idx += 1
	stats["collapses"] += 1
	var crushed := 0
	var keep: Array[HullItem] = []
	for it in items:
		if not it.surface or it.r < 0.16 * R:
			crushed += 1
			core_area += it.area
		else:
			keep.append(it)
	items = keep
	core_count += crushed
	recompute_size()
	if silent:
		return
	banner("GRAVITATIONAL COLLAPSE", "%d pieces crushed into the core · hull surface freed" % crushed)
	ring(ppos, R * 6.0, Color(0.9, 0.5, 1.0), 0.7)
	shake = maxf(shake, 0.6)
	for e: Thing in query(ppos, R * 6.0):
		hurt(e, 6.0 * R * R)
		if not e.apex:
			e.vel += (e.pos - ppos).normalized() * R * 8.0


func _roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V"][clampi(n, 0, 5)]


func item_world(it: HullItem) -> Array:
	var a := hull_ang + it.ang
	return [ppos + Vector2.from_angle(a) * (R + it.r * 0.2), a]


func _beam(p: Vector2, a: float, length: float, width: float, dmg: float, col: Color) -> void:
	var b := p + Vector2.from_angle(a) * length
	for e: Thing in query((p + b) * 0.5, length * 0.5 + width):
		var cp := Geometry2D.get_closest_point_to_segment(e.pos, p, b)
		if cp.distance_to(e.pos) < e.r + width:
			hurt(e, dmg)
	fx_beams.append({"a": p, "b": b, "w": width, "col": col, "t": 0.1})


func _bolt(a: Vector2, b: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	var n := 6
	var nrm := (b - a).orthogonal().normalized()
	var L := a.distance_to(b)
	for i in n + 1:
		var f := float(i) / n
		var j := 0.0 if (i == 0 or i == n) else rng.randf_range(-0.12, 0.12) * L
		pts.append(a.lerp(b, f) + nrm * j)
	fx_bolts.append({"pts": pts, "col": col, "t": 0.12})


func _spawn_bullet(p: Vector2, v: Vector2, life: float, dmg: float, r: float, col: Color, pierce: int) -> Bullet:
	if bullets.size() >= MAX_BULLETS:
		return null
	var b := Bullet.new()
	b.pos = p
	b.vel = v
	b.life = life
	b.dmg = dmg
	b.r = maxf(r, R * 0.03)
	b.col = col
	b.pierce = pierce
	bullets.append(b)
	return b


func _nearest_enemy(p: Vector2, rad: float) -> Thing:
	var best: Thing = null
	var bd := INF
	for e: Thing in query(p, rad):
		var d := e.pos.distance_squared_to(p)
		if d < bd:
			bd = d
			best = e
	return best


# =============================================================================
# Synergies (hull adjacency)
# =============================================================================

func _recompute_synergies() -> void:
	var prev := syn_active.keys()
	syn_active.clear()
	for s in Defs.SYNERGIES:
		for cat in items:
			if not cat.surface or not cat.d.get("tags", []).has(s["cat"]):
				continue
			var links := []
			for o in items:
				if o == cat or not o.surface:
					continue
				if o.d.get("tags", []).has(s["need"]) and absf(angle_difference(cat.ang, o.ang)) < float(s["win"]):
					links.append(o)
			if links.size() >= int(s["n"]):
				syn_active[s["id"]] = {"cat": cat, "links": links, "def": s}
				break
	for id in syn_active:
		if not prev.has(id):
			var sd: Dictionary = syn_active[id]["def"]
			stats["synergies"] += 1
			# announce a synergy once; it can flicker as pieces get buried and resurface
			if not syn_seen.has(id):
				syn_seen[id] = true
				banner("SYNERGY: " + String(sd["name"]).to_upper(), sd["desc"])


func _update_synergies(dt: float) -> void:
	dmg_src = "synergy"
	var sp := pvel.length()
	if syn_active.has("blender"):
		var n: int = 2 + syn_active["blender"]["links"].size()
		halberd_ang += (1.5 + 1.4 * sp / R) * dt
		for i in n:
			var hp := ppos + Vector2.from_angle(halberd_ang + TAU * i / n) * R * 2.1
			for e: Thing in query(hp, R * 0.4):
				hurt(e, 7.0 * R * R * dt)
	if syn_active.has("tesla") and float(cds.get("tesla", 0.0)) <= 0.0:
		cds["tesla"] = 0.35
		var cat: HullItem = syn_active["tesla"]["cat"]
		var near: Array = query(ppos, R * 4.0)
		near.sort_custom(func(a, b): return a.pos.distance_squared_to(ppos) < b.pos.distance_squared_to(ppos))
		var from: Vector2 = item_world(cat)[0]
		for e: Thing in near.slice(0, 5):
			_bolt(from, e.pos, Color(0.6, 0.9, 1.0))
			hurt(e, 3.5 * R * R)
			from = e.pos
	if syn_active.has("lightshow") and float(cds.get("siren", 0.0)) <= 0.0:
		cds["siren"] = 0.12
		var iw := item_world(syn_active["lightshow"]["cat"])
		var s := sin(t * 5.0) * 0.9
		_beam(iw[0], iw[1] + s, R * 5.0, R * 0.12, 0.25 * R * R, Color(1.0, 0.25, 0.25))
		_beam(iw[0], iw[1] - s, R * 5.0, R * 0.12, 0.25 * R * R, Color(0.3, 0.4, 1.0))
	if syn_active.has("buffet") and float(cds.get("crane", 0.0)) <= 0.0:
		cds["crane"] = 2.5
		var cat: HullItem = syn_active["buffet"]["cat"]
		var best: Thing = null
		var bs := 0.0
		for e: Thing in query(ppos, R * 9.0):
			if e == boss or e.grabbed or e.apex:
				continue
			var sc := e.r * (3.0 if e.elite else 1.0)
			if sc > bs:
				bs = sc
				best = e
		if best != null:
			best.grabbed = true
			grabs.append({"e": best, "from": cat})
			text(best.pos, "GRAPPLED", Color(1.0, 0.85, 0.2), 14)
	var keep := []
	for g in grabs:
		var e: Thing = g["e"]
		if e.dead or e.gone:
			continue
		var to := ppos - e.pos
		var d := to.length()
		e.pos += to / maxf(d, 0.0001) * minf(d, R * 10.0 * dt)
		e.vel = Vector2.ZERO
		if d < R + e.r * 1.05:
			e.grabbed = false
			hurt(e, 60.0 * R * R)
			ring(e.pos, e.r * 1.5, Color(1.0, 0.85, 0.2), 0.3)
			text(e.pos, "CRUNCH", Color(1.0, 0.85, 0.2), 16)
			if not e.dead:
				e.vel = -to.normalized() * R * 6.0
		else:
			keep.append(g)
	grabs = keep


# =============================================================================
# Zones: nested arenas with walls, furniture, kits and an apex predator
# =============================================================================

func _setup_zone(i: int) -> void:
	zone = i
	zone_def = Defs.ZONES[i]
	zone_open = false
	var hi := float(zone_def["hi"])
	if hi <= 0.0:
		arena_r = INF
		wall_r = 0.0
		banner(String(zone_def["name"]), "no walls left. grow.")
		return
	var lo := float(zone_def["lo"])
	arena_r = ARENA_K * hi
	wall_r = WALL_K * hi
	var hd := _view_half_diag()
	# boundary ring: overlapping pieces so there's no gap to squeeze through
	var wd: Dictionary = zone_def["wall"].duplicate()
	wd["r"] = wall_r
	wd["den"] = 2.0
	var n := ceili(TAU * arena_r / (1.45 * wall_r))
	for k in n:
		var th := Thing.new()
		th.d = wd
		th.r = wall_r * rng.randf_range(0.97, 1.03)
		th.pos = Vector2.from_angle(TAU * k / n) * arena_r
		th.rot = TAU * k / n
		th.fixed = true
		th.wall = true
		th.age = 10.0
		props.append(th)
	# furniture: too big to eat when you arrive, most of it edible by the exit
	var placed := 0
	var guard := 0
	while placed < 28 and guard < 600:
		guard += 1
		var s: float
		if rng.randf() < 0.7:
			s = exp(rng.randf_range(log(1.6 * lo), log(0.46 * hi)))
		else:
			s = exp(rng.randf_range(log(0.46 * hi), log(0.9 * hi)))
		var at := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * (arena_r - wall_r * 2.5 - s)
		if at.distance_to(ppos) < hd * 0.8 + s or at.length() < 6.0 * lo + s:
			continue
		if _overlaps_fixed(at, s, 2.5 * lo):
			continue
		var th := Thing.new()
		th.d = _pick_def(prop_sorted, s)
		th.r = s
		th.pos = at
		th.rot = rng.randf() * TAU
		th.fixed = true
		th.age = 10.0
		props.append(th)
		placed += 1
	# two synergy kits tucked away somewhere in the zone
	for k in 2:
		var at := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.4, 0.85) * arena_r
		_spawn_theme(at, sqrt(lo * hi) * 1.3, true)
	_spawn_apex()
	banner(String(zone_def["name"]), "the %ss give way at %s across" % [String(zone_def["wall"]["name"]).to_lower(), fmt_len(wall_r / ABSORB * 2.0)])


func _overlaps_fixed(at: Vector2, s: float, pad: float) -> bool:
	for o in props:
		if o.fixed and not o.gone and o.pos.distance_to(at) < o.r + s + pad:
			return true
	return false


func _spawn_apex() -> void:
	var ad: Dictionary = zone_def["apex"].duplicate()
	ad["hp"] = APEX_HP
	ad["spd"] = 1.0
	ad["beh"] = "apex"
	ad["r"] = APEX_K * float(zone_def["hi"])
	var e := Thing.new()
	e.d = ad
	e.enemy = true
	e.apex = true
	e.r = float(ad["r"])
	e.hp = APEX_HP * e.r * e.r
	e.max_hp = e.hp
	# start on the far side of the arena from the player
	var away := -ppos.normalized() if ppos.length() > 0.001 else Vector2.from_angle(rng.randf() * TAU)
	e.pos = away * arena_r * 0.6
	e.wtarget = e.pos
	e.home = Vector2.ZERO
	enemies.append(e)
	apexes.append(e)


func _check_zone() -> void:
	if wall_r <= 0.0:
		return
	if not zone_open and R * ABSORB > wall_r:
		zone_open = true
		banner("THE %sS ARE EDIBLE" % String(zone_def["wall"]["name"]).to_upper(), "eat through the wall and break out")
		shake = 0.6
	# you've left once you're past the wall line (or grossly outgrown the zone)
	if zone_open and (ppos.length() > arena_r - wall_r * 0.3 or R > float(zone_def["hi"]) * 1.8):
		_setup_zone(zone + 1)


func _apex_reward(e: Thing, how: String) -> void:
	stats["apex_kills"] += 1
	banner("APEX %s: %s" % [how, String(e.d["name"]).to_upper()], "its essence floods every branch you've grown")
	for tg in e.d.get("tags", []):
		if tree_by_tag.has(tg):
			essence[tg] = float(essence[tg]) + 10.0
	for tg in ranks:
		if rank(tg) > 0:
			essence[tg] = float(essence[tg]) + 3.0
	for tg in tree_by_tag:
		_gain_essence({"tags": [tg]}, 0.0)
	ring(e.pos, e.r * 2.5, Color(1.0, 0.4, 0.3), 0.8)
	shake = maxf(shake, 1.0)


# =============================================================================
# Enemies: local wildlife, apex predators, the rival
# =============================================================================

func _build_grid() -> void:
	grid.clear()
	grid_cell = maxf(R * 2.0, 0.0001)
	max_enemy_r = 0.0
	nearest_enemy_d = INF
	for e in enemies:
		if e.dead:
			continue
		var k := Vector2i(floori(e.pos.x / grid_cell), floori(e.pos.y / grid_cell))
		if grid.has(k):
			grid[k].append(e)
		else:
			grid[k] = [e]
		max_enemy_r = maxf(max_enemy_r, e.r)
		nearest_enemy_d = minf(nearest_enemy_d, e.pos.distance_to(ppos) - e.r)


func query(c: Vector2, q: float) -> Array:
	var out := []
	var span := q + max_enemy_r
	var x0 := floori((c.x - span) / grid_cell)
	var x1 := floori((c.x + span) / grid_cell)
	var y0 := floori((c.y - span) / grid_cell)
	var y1 := floori((c.y + span) / grid_cell)
	if (x1 - x0) * (y1 - y0) > 400:
		for e in enemies:
			if not e.dead and e.pos.distance_to(c) < q + e.r:
				out.append(e)
		return out
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var k := Vector2i(x, y)
			if grid.has(k):
				for e: Thing in grid[k]:
					if not e.dead and e.pos.distance_to(c) < q + e.r:
						out.append(e)
	return out


func size_falloff(r: float) -> float:
	# You can't do much to something much bigger than you: full damage up to
	# your own size, 0.73x at 1.5x, 0.4x at 2x, 0.17x at 2.8x.
	var rel := r / R
	if rel <= 1.0:
		return 1.0
	return 1.0 / (1.0 + 1.5 * pow(rel - 1.0, 2.0))


func hurt(e: Thing, dmg: float) -> void:
	if e.dead:
		return
	dmg *= size_falloff(e.r)
	if e.apex or e == boss:
		e.dmg_by[dmg_src] = float(e.dmg_by.get(dmg_src, 0.0)) + dmg
	if e == boss:
		_boss_hurt(dmg)
		return
	e.hp -= dmg
	e.flash = 0.08
	if e.apex:
		e.state = 1
		e.st = maxf(e.st, 3.0)
	if e.hp <= 0.0:
		kill(e)


func kill(e: Thing) -> void:
	e.dead = true
	stats["kills"] += 1
	if e.apex:
		var tot := 0.0
		for k in e.dmg_by:
			tot += float(e.dmg_by[k])
		var parts := []
		for k in e.dmg_by:
			parts.append("%s %d%%" % [k, int(100.0 * float(e.dmg_by[k]) / maxf(tot, 0.0001))])
		print("APEXDMG t=%.1f %s r/R=%.2f %s" % [t, e.d["lbl"], e.r / R, ", ".join(parts)])
		_apex_reward(e, "DOWN")
		for i in 8:
			var th := Thing.new()
			th.d = e.d
			th.r = e.r * 0.24
			var a := rng.randf() * TAU
			th.pos = e.pos + Vector2.from_angle(a) * e.r * 0.5
			th.vel = Vector2.from_angle(a) * R * 4.0
			th.was_enemy = true
			th.age = 10.0
			props.append(th)
		return
	if e.burn > 0.0 and has("fire.wildfire"):
		bursts.append({"pos": e.pos, "r": maxf(e.r * 2.0, R * 0.8), "dmg": 2.0 * R * R * rank_mult("fire"), "col": Color(1.0, 0.5, 0.15)})
	elif has("organic.spores") and e.pos.distance_to(ppos) < R * 8.0:
		bursts.append({"pos": e.pos, "r": maxf(e.r * 1.6, R * 0.8), "dmg": 1.2 * R * R * rank_mult("organic"), "col": Color(0.6, 1.0, 0.4)})
	var w := Thing.new()
	w.d = e.d
	w.r = e.r * 0.6
	w.pos = e.pos
	w.vel = e.vel * 0.3
	w.wreck = true
	w.was_enemy = true
	w.rot = rng.randf() * TAU
	props.append(w)
	if e.r > R * 0.5:
		ring(e.pos, e.r * 1.4, Color(1, 0.6, 0.3), 0.3)


func _wander_point(e: Thing) -> Vector2:
	var p := e.home + Vector2.from_angle(rng.randf() * TAU) * e.leash * sqrt(rng.randf())
	if p.length() > arena_r - wall_r * 1.5 - e.r:
		p = p.normalized() * (arena_r - wall_r * 1.5 - e.r)
	return p


func _update_enemies(dt: float) -> void:
	for e in enemies:
		if e.dead:
			continue
		e.age += dt
		e.flash -= dt
		e.contact_cd -= dt
		e.cd -= dt
		e.stun -= dt
		e.burn -= dt
		if e == boss:
			_boss_ai(e, dt)
			continue
		if e.grabbed:
			continue
		if e.apex:
			_apex_ai(e, dt)
		elif e.stun > 0.0:
			e.vel = e.vel.lerp(Vector2.ZERO, 1.0 - exp(-8.0 * dt))
		else:
			_local_ai(e, dt)
		e.pos += e.vel * dt
		e.rot = lerp_angle(e.rot, e.vel.angle(), 1.0 - exp(-6.0 * dt))
		# wildlife stays inside the zone walls
		if e.pos.length() > arena_r - wall_r - e.r and arena_r < INF and e.pos.length() < arena_r + wall_r * 4.0:
			e.pos = e.pos.normalized() * (arena_r - wall_r - e.r)
			e.wtarget = _wander_point(e)
	# soft separation
	for e in enemies:
		if e.dead or e == boss:
			continue
		for o: Thing in query(e.pos, e.r):
			if o == e or o == boss:
				continue
			var dv := e.pos - o.pos
			var dd := dv.length()
			var md := (e.r + o.r) * 0.9
			if dd < md and dd > 0.000001:
				e.pos += dv / dd * (md - dd) * (0.05 if e.apex else 0.25)


func _local_ai(e: Thing, dt: float) -> void:
	# Wildlife lives around a home point. Prey flees, predators chase on a leash,
	# shooters hold their ground. Nothing crosses the map to hunt you.
	var to := ppos - e.pos
	var d := to.length()
	var dir := to / maxf(d, 0.000001)
	var spd := minf(float(e.d["spd"]) * e.r * (1.15 if e.elite else 1.0), max_speed() * 0.9)
	var small := e.r < ABSORB_LIVE * R
	var beh: String = e.d["beh"]
	var aggressive: bool = not e.d.get("flee", false) and beh != "ranged"
	var desired := Vector2.ZERO
	var from_home := e.pos.distance_to(e.home)
	var gap := d - e.r - R
	if small and gap < R * 4.0:
		# flee, but slower than you: prey can be run down
		desired = -dir * minf(spd * 1.3, max_speed() * 0.7)
		e.state = 0
	elif not small and beh == "ranged" and gap < float(e.d["atk"]["rng"]) * R:
		var atk: Dictionary = e.d["atk"]
		desired = dir.orthogonal() * spd * (0.4 if (e.get_instance_id() % 2) == 0 else -0.4)
		if gap < R * 2.5:
			desired -= dir * spd * 0.6
		if e.cd <= 0.0 and e.age > 1.0:
			e.cd = float(atk["cd"]) * rng.randf_range(0.8, 1.2)
			_enemy_shoot(e, atk, dir)
	elif not small and aggressive and gap < R * 6.0 + e.r * 2.0 and from_home < e.leash * 2.2:
		if beh == "ram":
			match e.state:
				0:
					desired = dir * spd
					if gap < R * 3.0 and e.cd <= 0.0:
						e.state = 1
						e.st = 0.7
				1:
					desired = Vector2.ZERO
					e.st -= dt
					e.flash = 0.05 if int(e.st * 12) % 2 == 0 else 0.0
					if e.st <= 0.0:
						e.state = 2
						e.st = 0.7
						e.vel = dir * maxf(spd * 4.0, max_speed() * 1.2)
				2:
					e.st -= dt
					if e.st <= 0.0:
						e.state = 0
						e.cd = 2.5
					return
		else:
			desired = dir * spd
	else:
		e.state = 0
		# wander: stroll to a point near home, pause, repeat
		if e.pos.distance_to(e.wtarget) < e.r + R * 0.3 or from_home > e.leash * 1.6:
			e.st -= dt
			if e.st <= 0.0 or from_home > e.leash * 1.6:
				e.wtarget = _wander_point(e)
				e.st = rng.randf_range(0.5, 2.0)
		else:
			desired = (e.wtarget - e.pos).normalized() * spd * 0.45
	e.vel = e.vel.lerp(desired, 1.0 - exp(-4.0 * dt))


func _apex_ai(e: Thing, dt: float) -> void:
	# Patrol the zone; on sight, hunt you down for a while, then give up.
	var to := ppos - e.pos
	var d := to.length()
	var dir := to / maxf(d, 0.000001)
	var edible := e.r < ABSORB_LIVE * R
	var sight := e.r * 2.5 + R * 6.0
	e.st -= dt
	if edible:
		# outgrown: now it's the one running
		e.state = 0
		if d < R * 8.0:
			e.vel = e.vel.lerp(-dir * max_speed() * 0.75, 1.0 - exp(-3.0 * dt))
			return
	elif d - e.r < sight:
		if e.state == 0:
			print("EVENT t=%.2f frame=%d HUNT %s" % [t, frames, e.d["lbl"]])
			text(e.pos + Vector2(0, -e.r * 1.3), "!", Color(1, 0.3, 0.2), 34)
			ring(e.pos, e.r * 1.6, Color(1, 0.3, 0.2), 0.5)
		e.state = 1
		e.st = 4.0
	if e.state == 1 and e.st <= 0.0:
		e.state = 0
		e.wtarget = Vector2.from_angle(rng.randf() * TAU) * arena_r * rng.randf_range(0.2, 0.8)
	e.pounce_cd -= dt
	if e.pounce > 0.0:
		# telegraphed pounce: crouch, then launch at where you are now
		e.pounce -= dt
		e.vel = e.vel.lerp(Vector2.ZERO, 1.0 - exp(-10.0 * dt))
		e.flash = 0.05 if int(e.pounce * 14.0) % 2 == 0 else 0.0
		if e.pounce <= 0.0:
			e.vel = dir * max_speed() * 3.4
			e.pounce_cd = 3.5
		return
	if e.state == 1 and e.pounce_cd <= 0.0 and d - e.r - R < R * 4.0:
		e.pounce = 0.55
		return
	if e.state == 1 and e.pounce_cd > 2.6:
		e.vel = e.vel.lerp(Vector2.ZERO, 1.0 - exp(-1.5 * dt))
	elif e.state == 1:
		e.vel = e.vel.lerp(dir * max_speed() * 0.95, 1.0 - exp(-2.5 * dt))
		if e.d.has("atk") and e.cd <= 0.0:
			var atk: Dictionary = e.d["atk"]
			e.cd = float(atk["cd"])
			for k in 3:
				_enemy_shoot(e, atk, dir.rotated((k - 1) * 0.25))
	else:
		if e.pos.distance_to(e.wtarget) < e.r * 2.0 or e.wtarget == Vector2.ZERO:
			var limit := arena_r if arena_r < INF else R * 40.0
			e.wtarget = Vector2.from_angle(rng.randf() * TAU) * limit * rng.randf_range(0.2, 0.8)
		e.vel = e.vel.lerp((e.wtarget - e.pos).normalized() * max_speed() * 0.38, 1.0 - exp(-2.0 * dt))


func _enemy_shoot(e: Thing, atk: Dictionary, dir: Vector2) -> void:
	var spd := float(atk["spd"]) * R
	var b := Bullet.new()
	b.pos = e.pos + dir * e.r
	b.vel = dir.rotated(rng.randf_range(-0.08, 0.08)) * spd
	b.life = float(atk["rng"]) * R * 1.8 / spd
	b.r = maxf(R * 0.07, minf(e.r * 0.18, R * 0.3))
	b.col = Color(1.0, 0.35, 0.25)
	b.hostile = true
	b.power = float(atk.get("pow", 1.0)) * clampf(e.r / R, 0.15, 3.0) * (1.5 if e.elite else 1.0)
	if atk.get("homing", false):
		b.turn = 1.5
	bullets.append(b)


func _update_bullets(dt: float) -> void:
	dmg_src = "shard"
	for b in bullets:
		b.life -= dt
		if b.turn > 0.0 and b.hostile:
			var sp := b.vel.length()
			b.vel = Vector2.from_angle(lerp_angle(b.vel.angle(), (ppos - b.pos).angle(), minf(1.0, b.turn * dt))) * sp
		b.pos += b.vel * dt
		if b.hostile:
			if not (game_over or victory) and b.pos.distance_to(ppos) < R + b.r:
				player_hit(b.power, b.pos)
				b.life = -1.0
		else:
			for e: Thing in query(b.pos, b.r):
				if b.hit.has(e):
					continue
				b.hit[e] = true
				hurt(e, b.dmg)
				b.pierce -= 1
				if b.bounce > 0:
					b.bounce -= 1
					b.pierce += 1
					var nxt: Thing = null
					for o: Thing in query(b.pos, R * 3.0):
						if not b.hit.has(o):
							nxt = o
							break
					if nxt != null:
						b.vel = (nxt.pos - b.pos).normalized() * b.vel.length()
						b.life = maxf(b.life, 0.3)
				if b.pierce <= 0:
					b.life = -1.0
					break
	bullets = bullets.filter(func(b): return b.life > 0.0)


func player_hit(power: float, src: Vector2) -> void:
	if iframes > 0.0 or game_over or victory:
		return
	var n := power
	if has("metal.base"):
		n *= 0.8
	if has("metal.reinforce"):
		n *= 0.8
	var fast := pvel.length() > max_speed() * 0.75
	if fast and (has("wheel.unstoppable") or (has("metal.juggernaut") and power > 1.5)):
		n *= 0.5
	var k := floori(n)
	if rng.randf() < n - k:
		k += 1
	if k <= 0:
		return
	iframes = 0.4
	stats["hits"] += 1
	shake = maxf(shake, 0.2 + 0.1 * k)
	if has("metal.reactive"):
		_spray(ppos, (src - ppos).angle(), 8, 0.9)
	shed(k, (src - ppos).angle())


# =============================================================================
# Boss: rival singularity
# =============================================================================

func _check_boss() -> void:
	if boss_spawned or t < run_len:
		return
	boss_spawned = true
	var e := Thing.new()
	e.d = Defs.BOSS
	e.enemy = true
	e.r = R * 1.8
	e.hp = e.r * e.r
	e.max_hp = e.hp
	var a := rng.randf() * TAU
	e.pos = ppos + Vector2.from_angle(a) * view_r * 1.3
	for i in 26:
		e.parts.append({"a": rng.randf() * TAU, "s": rng.randf_range(0.12, 0.3), "c": Color.from_hsv(rng.randf(), 0.5, 0.7), "sh": rng.randi() % 5})
	boss = e
	enemies.append(e)
	banner("RIVAL SINGULARITY", "a planetary defense anomaly. out-mass it, then eat it.")
	shake = 1.2


func _boss_ai(e: Thing, dt: float) -> void:
	e.r = sqrt(maxf(e.hp, 0.0001))
	e.rot += dt * 0.8
	var to := ppos - e.pos
	var d := to.length()
	var dir := to / maxf(d, 0.0001)
	var spd := max_speed() * 0.78
	match e.state:
		0:
			e.vel = e.vel.lerp(dir * spd, 1.0 - exp(-2.5 * dt))
			e.st -= dt
			if e.st <= 0.0:
				e.st = 6.0
				e.state = 1
				e.cd = 0.6
		1:
			e.vel = e.vel.lerp(Vector2.ZERO, 1.0 - exp(-5.0 * dt))
			e.cd -= dt
			if e.cd <= 0.0:
				e.state = 2
				e.cd = 0.9
				e.vel = dir * spd * 2.6
				for i in 16:
					var b := Bullet.new()
					b.pos = e.pos
					b.vel = Vector2.from_angle(TAU * i / 16.0 + e.rot) * R * 5.0
					b.life = 3.0
					b.r = R * 0.15
					b.col = Color(1.0, 0.3, 0.5)
					b.hostile = true
					b.power = 1.0
					bullets.append(b)
		2:
			e.cd -= dt
			if e.cd <= 0.0:
				e.state = 0
	e.pos += e.vel * dt
	_rival_feed(e, dt)


func _rival_can_eat(e: Thing, th: Thing) -> bool:
	if th.gone or th.dead or th == e or th.carried or th.grabbed or th.fixed and th.r >= ABSORB * R:
		return false
	if th.enemy:
		return not th.apex and th.r < e.r * 0.45
	if th.loose >= 0.0 and th.age < 0.8:
		return false   # give the player a moment to grab their own shed pieces back
	return th.r < e.r * 0.5


func _rival_feed(e: Thing, dt: float) -> void:
	# The rival is an ooze too: its tentacles drag in wildlife, props and your
	# shed pieces, and every meal regrows it. Out-damage its eating.
	var reach := e.r * 2.4
	while e.feelers.size() < 6:
		e.feelers.append({"target": null, "tip": e.pos, "latched": false})
	var taken := {}
	for f in e.feelers:
		if f["target"] != null:
			taken[f["target"]] = true
	for f in e.feelers:
		var tg = f["target"]
		if tg != null and (not _rival_can_eat(e, tg) or tg.pos.distance_to(e.pos) > reach * 1.4 + tg.r):
			taken.erase(tg)
			f["target"] = null
			f["latched"] = false
			tg = null
		if tg == null:
			var best: Thing = null
			var bd := INF
			for list in [enemies, props]:
				for th: Thing in list:
					if taken.has(th) or not _rival_can_eat(e, th):
						continue
					var d := th.pos.distance_to(e.pos) - th.r
					if d < reach and d < bd:
						bd = d
						best = th
			if best != null:
				f["target"] = best
				taken[best] = true
				tg = best
		var tip: Vector2 = f["tip"]
		if tg == null:
			f["tip"] = tip.lerp(e.pos, 1.0 - exp(-10.0 * dt))
			continue
		if not f["latched"]:
			f["tip"] = tip.move_toward(tg.pos, e.r * 6.0 * dt)
			if (f["tip"] as Vector2).distance_to(tg.pos) <= tg.r + e.r * 0.05:
				f["latched"] = true
			continue
		var to: Vector2 = e.pos - tg.pos
		var d := to.length()
		tg.pos += to / maxf(d, 0.000001) * e.r * 2.0 * dt
		if tg.enemy:
			tg.vel *= 0.5
		f["tip"] = tg.pos
		if d < e.r + tg.r * 0.3:
			# meals regenerate it back toward its arrival size, never beyond
			var before := e.hp
			e.hp = minf(e.max_hp, e.hp + tg.r * tg.r * (0.9 if tg.enemy else 0.5))
			if e.hp > before + e.max_hp * 0.002:
				fx_rings.append({"pos": e.pos, "r": e.r * 1.1, "col": Color(1.0, 0.3, 0.35, 0.5), "t": 0.25, "tm": 0.25})
			if tg.enemy:
				tg.dead = true
			tg.gone = true
			stats["rival_ate"] += 1
			f["target"] = null
			f["latched"] = false


func _boss_hurt(dmg: float) -> void:
	var e := boss
	var loss := dmg * 0.004
	e.hp -= loss
	e.flash = 0.06
	e.shed_acc += loss
	var chunk := pow(0.2 * e.r, 2.0)
	var guard := 0
	while e.shed_acc > chunk and guard < 4:
		guard += 1
		e.shed_acc -= chunk
		var s := 0.2 * e.r * rng.randf_range(0.7, 1.2)
		var th := Thing.new()
		th.d = _nearest_def(prop_sorted, s)
		th.r = s
		var a := rng.randf() * TAU
		th.pos = e.pos + Vector2.from_angle(a) * e.r
		th.vel = Vector2.from_angle(a) * R * 5.0
		th.loose = LOOSE_TIME + 2.0
		th.area_v = s * s
		th.rot = a
		props.append(th)
	if e.hp < pow(R * 0.15, 2.0):
		e.hp = pow(R * 0.15, 2.0)


# =============================================================================
# Props, collisions, spawning
# =============================================================================

func _update_props(dt: float) -> void:
	var dt_pull := dt
	for p in props:
		if p.gone:
			continue
		p.age += dt
		if p.vel != Vector2.ZERO:
			p.pos += p.vel * dt
			p.vel *= exp(-3.0 * dt)
			if p.vel.length() < R * 0.02:
				p.vel = Vector2.ZERO
		if p.wreck and p.age > 9.0:
			p.gone = true
			continue
		if p.loose >= 0.0:
			p.loose -= dt
			if has("metal.riveted") and p.age > 1.0 and p.r < LOOSE_ABSORB * R:
				p.pos = p.pos.move_toward(ppos, R * 3.0 * dt_pull)
			if p.loose < 0.0:
				p.gone = true
				stats["lost"] += 1
				bursts.append({"pos": p.pos, "r": p.r * 6.0, "dmg": 6.0 * p.r * p.r, "col": Color(1.0, 0.5, 0.2)})


func _player_collisions() -> void:
	dmg_src = "contact"
	var dt := get_physics_process_delta_time()
	for p in props:
		if p.gone or p.carried:
			continue
		var to := ppos - p.pos
		var d := to.length()
		if d > R * 6.0 + p.r:
			continue
		var edible := p.r < ABSORB * R or (p.loose >= 0.0 and p.r < LOOSE_ABSORB * R)
		if edible:
			if d < R + p.r * 0.5 and not (p.loose >= 0.0 and p.age < 0.35):
				absorb(p)
		elif p.wreck or p.loose >= 0.0:
			# oversized debris gets shoved around instead of blocking
			var md2 := R + p.r * 0.8
			if d < md2 and d > 0.0:
				p.pos -= to / d * (md2 - d)
		else:
			var md := R + p.r * 0.85
			if d < md and d > 0.0:
				var n := to / d
				ppos = p.pos + n * md
				var vn := pvel.dot(n)
				if vn < 0.0:
					pvel -= n * vn * 1.3
	for e in enemies:
		if e.dead:
			continue
		var to := ppos - e.pos
		var d := to.length()
		if d > R + e.r:
			continue
		var n := to / maxf(d, 0.000001)
		if e == boss:
			if e.r < R * 0.8:
				_eat_boss()
				return
			if e.contact_cd <= 0.0:
				e.contact_cd = 1.2
				player_hit(2.5 * e.r / R, e.pos)
				pvel += n * R * 9.0
				_boss_hurt(10.0 * R * R)
			continue
		if e.r < ABSORB_LIVE * R and not e.grabbed:
			absorb(e)
			continue
		if e.contact_cd <= 0.0:
			e.contact_cd = 1.0
			if e.apex:
				stats["apex_hits"] += 1
			player_hit((2.0 if e.apex else 1.4) * e.r / R * (1.5 if e.elite else 1.0), e.pos)
			var spd_f := minf(pvel.length() / max_speed(), 3.0)
			var crush := 1.5 * R * R * (0.5 + spd_f)
			if has("wheel.base"):
				crush += 4.0 * R * R * spd_f * rank_mult("wheel") * (2.5 if has("wheel.battering") else 1.0)
			if lurch_state == 2 and lurch_target == e:
				_end_lurch()
			if has("metal.spikes"):
				crush += 3.0 * R * R * rank_mult("metal")
			hurt(e, crush)
			pvel += n * R * 4.0
			if not e.apex:
				e.vel -= n * R * (8.0 if has("wheel.battering") else 3.0)
		var overlap := R + e.r - d
		var share := 0.9 if e.apex else 0.4
		ppos += n * overlap * share
		e.pos -= n * overlap * (1.0 - share)


func _eat_boss() -> void:
	victory = true
	boss.dead = true
	core_area += boss.hp
	recompute_size()
	ring(ppos, R * 10.0, Color(1, 0.9, 0.5), 1.2)
	shake = 1.5
	print("VICTORY at T=%.1f (boss fight %.1fs)" % [t, t - run_len])
	banner("CRITICAL MASS ACHIEVED", "you ate the rival singularity · %s across" % fmt_len(R * 2.0))


func _nearest_def(arr: Array, s: float) -> Dictionary:
	var best: Dictionary = arr[0]
	var bd := INF
	for d in arr:
		var x := absf(log(s / float(d["r"])))
		if x < bd:
			bd = x
			best = d
	return best


func _pick_def(arr: Array, s: float) -> Dictionary:
	# nearest by log-size with a little jitter so neighbours appear too
	return _nearest_def(arr, s * exp(rng.randf_range(-0.45, 0.45)))


func _view_half_diag() -> float:
	return view_r * Vector2(screen.x / screen.y, 1.0).length()


func _in_arena(p: Vector2, s: float) -> bool:
	return p.length() < arena_r - wall_r * 1.6 - s


func _spawn_theme(center: Vector2, size_ref: float, fixed: bool) -> bool:
	# A ready-made synergy kit (e.g. carts around a transformer).
	var fits := []
	for th in Defs.THEMES:
		var cat: Dictionary = prop_by_name[th["items"][0]]
		var cr := float(cat["r"])
		if cr > 0.18 * size_ref and cr < 0.48 * size_ref:
			fits.append(th)
	if fits.is_empty():
		return false
	var theme: Dictionary = fits[rng.randi() % fits.size()]
	var k := 0
	for nm in theme["items"]:
		var d: Dictionary = prop_by_name[nm]
		var th := Thing.new()
		th.d = d
		th.r = float(d["r"]) * rng.randf_range(0.9, 1.1)
		th.pos = center + Vector2.from_angle(TAU * k / float(theme["items"].size()) + rng.randf_range(-0.2, 0.2)) * (th.r * 2.5 + size_ref)
		th.rot = rng.randf() * TAU
		th.fixed = fixed
		th.age = 10.0
		props.append(th)
		k += 1
	return true


func _arena_spawn_point(s: float) -> Vector2:
	# somewhere just off-screen, inside the walls, not inside furniture
	var hd := _view_half_diag()
	for tries in 10:
		var ang := rng.randf() * TAU
		if pvel.length() > R and rng.randf() < 0.5:
			ang = pvel.angle() + rng.randf_range(-1.2, 1.2)
		var p := ppos + Vector2.from_angle(ang) * rng.randf_range(hd * 1.05, hd * 1.8)
		if _in_arena(p, s) and not _inside_solid(p, s):
			return p
	if arena_r < INF:
		for tries in 12:
			var p := Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * (arena_r - wall_r * 2.0 - s)
			var far := hd if tries < 6 else R * 4.0 + s
			if p.distance_to(ppos) > far and not _inside_solid(p, s):
				return p
	return Vector2.INF


func _inside_solid(p: Vector2, s: float) -> bool:
	for o in props:
		if o.fixed and not o.gone and o.r >= ABSORB * R and o.pos.distance_to(p) < o.r + s:
			return true
	return false


func spawn_prop_cluster(initial: bool) -> void:
	var center: Vector2
	if initial:
		center = Vector2.INF
		for tries in 10:
			var p := ppos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(R * 4.0, _view_half_diag() * 1.6)
			if _in_arena(p, R) and not _inside_solid(p, R):
				center = p
				break
	else:
		center = _arena_spawn_point(R)
	if center == Vector2.INF:
		return
	if rng.randf() < 0.12 and _spawn_theme(center, R, false):
		return
	var ratio := exp(lerpf(log(0.16), log(0.48), pow(rng.randf(), 1.3)))
	var base_s := R * ratio
	var n := rng.randi_range(4, 10)
	var d0 := _pick_def(prop_sorted, base_s)
	for i in n:
		var s := base_s * rng.randf_range(0.6, 1.4)
		var d := d0 if rng.randf() < 0.55 else _pick_def(prop_sorted, s)
		var th := Thing.new()
		th.d = d
		th.r = s
		th.pos = center + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, base_s * 6.0 + R)
		th.rot = rng.randf() * TAU
		th.age = 10.0 if initial else 0.0
		if th.pos.distance_to(ppos) < R * 2.0 + s or not _in_arena(th.pos, s) or _inside_solid(th.pos, s):
			continue
		props.append(th)


func spawn_enemy(at: Vector2 = Vector2.INF) -> Thing:
	var p := clampf(t / run_len, 0.0, 1.0)
	var ratio: float
	var elite := false
	var roll := rng.randf()
	if roll < 0.07 + 0.1 * p and _elite_count() < 3 + int(3 * p):
		ratio = rng.randf_range(1.4, 2.4)
		elite = true
	elif roll < 0.4 + 0.15 * p:
		ratio = exp(rng.randf_range(log(0.55), log(1.3)))
	else:
		ratio = exp(rng.randf_range(log(0.17), log(0.42)))
	var s := R * ratio
	if at == Vector2.INF:
		at = _arena_spawn_point(s)
		if at == Vector2.INF:
			return null
	var d: Dictionary = _pick_def(enemy_sorted, s)
	var e := Thing.new()
	e.d = d
	e.enemy = true
	e.r = s
	e.elite = elite
	e.hp = float(d["hp"]) * s * s * 0.3 * (4.0 if elite else 1.0)
	e.max_hp = e.hp
	e.pos = at
	e.age = 0.0
	e.home = at
	e.leash = maxf(R * 6.0, s * 8.0)
	e.wtarget = at
	e.cd = rng.randf_range(0.5, 2.0)
	enemies.append(e)
	return e


func _elite_count() -> int:
	var n := 0
	for e in enemies:
		if e.elite and not e.dead:
			n += 1
	return n


func _spawning(dt: float) -> void:
	var hd := _view_half_diag()
	# props: keep a healthy buffet near the player (zone furniture persists)
	var near := 0
	for p in props:
		if p.gone or p.loose >= 0.0:
			continue
		if p.r < SEE_MIN * R:
			p.gone = true
			_vanish(p)
			continue
		if p.fixed or p.wreck:
			continue
		var d := p.pos.distance_to(ppos)
		if d > hd * 2.6:
			p.gone = true
		else:
			near += 1
	var guard := 0
	while near < 200 and guard < 6:
		guard += 1
		spawn_prop_cluster(false)
		near += 5

	# local wildlife density around the player
	var p := clampf(t / run_len, 0.0, 1.0)
	var target_n := int(36 + 70 * p)
	if boss != null:
		target_n = int(target_n * 0.8)
	var alive := 0
	for e in enemies:
		if e.dead or e == boss or e.apex:
			continue
		var d := e.pos.distance_to(ppos)
		if d > hd * 3.0:
			e.dead = true
			e.gone = true
		elif e.r < SEE_MIN * R:
			e.dead = true
			_vanish(e)
		else:
			alive += 1
	for e in apexes:
		if not e.dead and e.r < SEE_MIN * R:
			e.dead = true
			_vanish(e)
	spawn_acc += dt * (4.0 + 10.0 * p)
	while spawn_acc >= 1.0 and alive < target_n:
		spawn_acc -= 1.0
		if spawn_enemy() != null:
			alive += 1
	spawn_acc = minf(spawn_acc, 3.0)


func _vanish(th: Thing) -> void:
	# beneath notice: no mass, no essence, no healing. It just stops existing for you.
	th.gone = true


func vis_alpha(r: float) -> float:
	# things fade out as they approach the visibility floor
	return clampf((r / R - SEE_MIN) / (SEE_MIN * 0.4), 0.0, 1.0)


func _update_strikes(dt: float) -> void:
	dmg_src = "strike"
	if zone >= 4:
		strike_cd -= dt
		if strike_cd <= 0.0:
			var p := clampf(t / run_len, 0.0, 1.0)
			strike_cd = rng.randf_range(5.0, 9.0) * (1.0 - 0.4 * p)
			var at := ppos + pvel * 1.6 + Vector2.from_angle(rng.randf() * TAU) * R * rng.randf_range(0.0, 2.5)
			strikes.append({"pos": at, "r": R * 2.6, "t": 1.8, "tm": 1.8})
	var keep := []
	for s in strikes:
		s["t"] -= dt
		if s["t"] <= 0.0:
			var c: Vector2 = s["pos"]
			var rr: float = s["r"]
			ring(c, rr, Color(1.0, 0.95, 0.8), 0.5)
			shake = maxf(shake, 0.5)
			if c.distance_to(ppos) < rr + R * 0.5:
				player_hit(3.0, c)
			for e: Thing in query(c, rr):
				if e != boss:
					hurt(e, 20.0 * R * R)
		else:
			keep.append(s)
	strikes = keep


func _cleanup() -> void:
	if frames % 10 == 0:
		props = props.filter(func(p): return not p.gone)
		enemies = enemies.filter(func(e): return not e.dead)
		apexes = apexes.filter(func(e): return not e.dead)
	if boss != null and boss.dead and not victory:
		boss = null


# =============================================================================
# Camera / fx
# =============================================================================

func _update_camera(dt: float) -> void:
	var target := R * VIEW_K
	view_r = exp(lerpf(log(view_r), log(target), 1.0 - exp(-2.0 * dt)))
	cam = cam.lerp(ppos + pvel * 0.25, 1.0 - exp(-6.0 * dt))
	shake = maxf(0.0, shake - dt * 1.8)
	shake_off = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * shake * 10.0
	_update_zoom()


func _update_floor(dt: float) -> void:
	var want: Color = zone_def.get("floor", floor_col)
	floor_col = floor_col.lerp(want, 1.0 - exp(-1.5 * dt))


func _update_zoom() -> void:
	zoom = screen.y * 0.5 / view_r


func _update_fx(dt: float) -> void:
	for arr in [fx_beams, fx_bolts, fx_cones, fx_rings, fx_texts]:
		for f in arr:
			f["t"] -= dt
	fx_beams = fx_beams.filter(func(f): return f["t"] > 0.0)
	fx_bolts = fx_bolts.filter(func(f): return f["t"] > 0.0)
	fx_cones = fx_cones.filter(func(f): return f["t"] > 0.0)
	fx_rings = fx_rings.filter(func(f): return f["t"] > 0.0)
	for f in fx_texts:
		f["pos"] += Vector2(0, -R * 0.8) * dt
	fx_texts = fx_texts.filter(func(f): return f["t"] > 0.0)
	for s in sparks:
		s["t"] -= dt
	sparks = sparks.filter(func(s): return s["t"] > 0.0)
	for dd in dust:
		dd["t"] += dt
		dd["pos"] = dd["pos"].lerp(ppos, minf(1.0, dt * (2.0 + dd["t"] * 8.0)))
	dust = dust.filter(func(dd): return dd["t"] < 0.8 and dd["pos"].distance_to(ppos) > R * 0.8)
	for b in banners:
		b["t"] -= dt
	banners = banners.filter(func(b): return b["t"] > 0.0)


func ring(p: Vector2, r: float, col: Color, life: float) -> void:
	fx_rings.append({"pos": p, "r": r, "col": col, "t": life, "tm": life})


func text(p: Vector2, s: String, col: Color, size: int) -> void:
	if fx_texts.size() > 40:
		return
	fx_texts.append({"pos": p, "s": s, "col": col, "t": 1.1, "size": size})


func banner(title: String, sub: String) -> void:
	if banners.size() > 2:
		banners.pop_front()
	banners.append({"title": title, "sub": sub, "t": 3.5})
	print("EVENT t=%.2f frame=%d BANNER %s" % [t, frames, title])


func fmt_len(m: float) -> String:
	if m < 1.0:
		return "%.1f cm" % (m * 100.0)
	if m < 1000.0:
		return "%.2f m" % m if m < 10.0 else "%.0f m" % m
	return "%.2f km" % (m / 1000.0)


# =============================================================================
# Telemetry
# =============================================================================

func _telemetry() -> void:
	if t >= next_log:
		next_log += 10.0
		_print_log()


func _print_log() -> void:
	var alive := 0
	for e in enemies:
		if not e.dead:
			alive += 1
	var rk := []
	for b in Defs.TREE:
		if rank(b["tag"]) > 0:
			rk.append("%s%d" % [String(b["tag"]).substr(0, 3), rank(b["tag"])])
	var ap := ""
	for e in apexes:
		if not e.dead:
			ap += " apex=%s(%.2fxR,hp%d%%,%s)" % [e.d["lbl"], e.r / R, int(100.0 * e.hp / e.max_hp), "HUNT" if e.state == 1 else "patrol"]
	print("T=%5.1f D=%s zone=%d%s surf=%d integ=%.2f imb=%.2f en=%d props=%d ranks=%s %s%s%s" % [
		t, fmt_len(R * 2.0), zone, "(open)" if zone_open else "", surface_count(), integrity, imbalance,
		alive, props.size(), " ".join(rk), str(stats), ap,
		(" BOSS r=%.3f" % boss.r) if boss != null else ""])


# =============================================================================
# Drawing
# =============================================================================

func w2s(p: Vector2) -> Vector2:
	return (p - cam) * zoom + screen * 0.5 + shake_off


func _on_screen(p: Vector2, r: float) -> bool:
	var s := w2s(p)
	var rr := r * zoom
	return s.x > -rr and s.y > -rr and s.x < screen.x + rr and s.y < screen.y + rr


func _shape(sh: int, c: Vector2, sr: float, rot: float, fill: Color, outline: Color, ow: float) -> void:
	if sr < 1.2:
		draw_rect(Rect2(c - Vector2.ONE, Vector2(2, 2)), fill)
		return
	var base: PackedVector2Array = polys[sh]
	var pts := PackedVector2Array()
	pts.resize(base.size())
	for i in base.size():
		pts[i] = c + base[i].rotated(rot) * sr
	draw_colored_polygon(pts, fill)
	if ow > 0.0:
		pts.append(pts[0])
		draw_polyline(pts, outline, ow)


func _label(c: Vector2, s: String, sr: float, col: Color) -> void:
	if sr < 13.0:
		return
	var fs := clampi(int(sr * 0.55), 9, 20)
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, c + Vector2(-w * 0.5, fs * 0.35), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _branch_col(d: Dictionary) -> Color:
	for tg in d.get("tags", []):
		if tree_by_tag.has(tg):
			return tree_by_tag[tg]["col"]
	return Color(0, 0, 0, 0)


func _draw() -> void:
	_draw_grid()
	_draw_patches()
	_draw_props()
	_draw_strikes()
	_draw_enemies()
	_draw_player()
	_draw_fx()
	_draw_hud()
	if not pending.is_empty():
		_draw_choice()


func _draw_grid() -> void:
	# outside the current zone is in shadow; the arena itself is lit floor
	if arena_r < INF:
		draw_rect(Rect2(Vector2.ZERO, screen), floor_col.darkened(0.45))
		draw_circle(w2s(Vector2.ZERO), arena_r * zoom, floor_col)
	else:
		draw_rect(Rect2(Vector2.ZERO, screen), floor_col)
	var span := view_r * 2.0
	var s := pow(10.0, floorf(log(span / 4.0) / log(10.0)))
	for level in 2:
		var step := s * (10.0 if level == 1 else 1.0)
		var n_lines := span / step
		var alpha := clampf(1.0 - n_lines / 45.0, 0.0, 1.0) * (0.10 if level == 0 else 0.16)
		if alpha <= 0.005:
			continue
		var col := Color(floor_col.darkened(0.35), alpha * 2.2)
		var tl := cam - screen * 0.5 / zoom
		var br := cam + screen * 0.5 / zoom
		var x := floorf(tl.x / step) * step
		while x <= br.x:
			var sx := w2s(Vector2(x, 0)).x
			draw_line(Vector2(sx, 0), Vector2(sx, screen.y), col, 1.0)
			x += step
		var y := floorf(tl.y / step) * step
		while y <= br.y:
			var sy := w2s(Vector2(0, y)).y
			draw_line(Vector2(0, sy), Vector2(screen.x, sy), col, 1.0)
			y += step
	# outside the current zone is darker: you're not supposed to be there yet
	var bar_m := s
	var px := bar_m * zoom
	var o := Vector2(screen.x - 30 - px, screen.y - 28)
	draw_line(o, o + Vector2(px, 0), Color(1, 1, 1, 0.6), 2.0)
	draw_line(o + Vector2(0, -5), o + Vector2(0, 5), Color(1, 1, 1, 0.6), 2.0)
	draw_line(o + Vector2(px, -5), o + Vector2(px, 5), Color(1, 1, 1, 0.6), 2.0)
	draw_string(font, o + Vector2(px * 0.5 - 20, -8), fmt_len(bar_m), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.7))


func _draw_patches() -> void:
	for pt in patches:
		if not _on_screen(pt["pos"], pt["r"]):
			continue
		var a: float = clampf(pt["t"] / 2.5, 0.0, 1.0)
		draw_circle(w2s(pt["pos"]), pt["r"] * zoom, Color(1.0, 0.4, 0.1, 0.25 * a))


func _draw_props() -> void:
	for p in props:
		if p.gone or not _on_screen(p.pos, p.r):
			continue
		var c := w2s(p.pos)
		var sr := p.r * zoom
		var fill: Color = p.d["col"]
		var sh: int = int(p.d.get("sh", 0))
		var edible := p.r < ABSORB * R or (p.loose >= 0.0 and p.r < LOOSE_ABSORB * R)
		if p.wreck:
			fill = fill.darkened(0.45)
			fill.a = 0.75 * clampf((9.0 - p.age) / 2.0, 0.0, 1.0)
			sh = 0
		var va := vis_alpha(p.r)
		if va <= 0.0:
			continue
		fill.a *= va
		var grow := clampf(p.age / 0.3, 0.0, 1.0) if p.age >= 0.0 else 1.0
		sr *= grow
		var outline := Color(0.55, 1.0, 0.65, 0.9) if edible else Color(0.0, 0.0, 0.0, 0.7)
		var ow := maxf(1.0, sr * 0.08) if edible else maxf(1.5, sr * 0.12)
		if not edible:
			fill = fill.darkened(0.25)
		if p.wall:
			outline = Color(0.55, 1.0, 0.65, 0.9 * (0.6 + 0.4 * sin(t * 6.0))) if edible else Color(0, 0, 0, 0.85)
			ow = maxf(2.0, sr * 0.06)
		if p.loose >= 0.0:
			var blink := p.loose < 2.0 and int(p.loose * 8.0) % 2 == 0
			if blink:
				fill = Color(1, 0.4, 0.3)
			draw_arc(c, sr + 4.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(p.loose / LOOSE_TIME, 0.0, 1.0), 24, Color(1, 0.8, 0.3), 2.0)
		outline.a *= va
		_shape(sh, c, sr, p.rot, fill, outline, ow)
		if p.wreck:
			draw_line(c + Vector2(-sr, -sr) * 0.5, c + Vector2(sr, sr) * 0.5, Color(0, 0, 0, 0.6), maxf(1.0, sr * 0.12))
			draw_line(c + Vector2(-sr, sr) * 0.5, c + Vector2(sr, -sr) * 0.5, Color(0, 0, 0, 0.6), maxf(1.0, sr * 0.12))
		elif not p.wall or (sr > 30.0 and p.get_instance_id() % 14 == 0):
			_label(c, String(p.d["lbl"]), sr, Color(0, 0, 0, 0.75 * va) if fill.get_luminance() > 0.45 else Color(1, 1, 1, 0.8 * va))
		# essence hint: a dot in the colour of the branch this thing feeds
		var bc := _branch_col(p.d)
		if bc.a > 0.0 and sr > 5.0 and edible and not p.wreck:
			draw_circle(c + Vector2(sr * 0.6, -sr * 0.6), maxf(2.0, sr * 0.14), bc)


func _draw_strikes() -> void:
	for s in strikes:
		var c := w2s(s["pos"])
		var sr: float = s["r"] * zoom
		var f: float = 1.0 - s["t"] / s["tm"]
		draw_circle(c, sr * f, Color(1.0, 0.2, 0.15, 0.18))
		draw_arc(c, sr, 0, TAU, 48, Color(1.0, 0.3, 0.2, 0.8), 2.0)
		draw_line(c + Vector2(-sr * 0.2, 0), c + Vector2(sr * 0.2, 0), Color(1, 0.3, 0.2), 2.0)
		draw_line(c + Vector2(0, -sr * 0.2), c + Vector2(0, sr * 0.2), Color(1, 0.3, 0.2), 2.0)


func _draw_enemies() -> void:
	for e in enemies:
		if e.dead or not _on_screen(e.pos, e.r * 1.5):
			continue
		if e == boss:
			_draw_boss(e)
			continue
		var c := w2s(e.pos)
		var sr := e.r * zoom * clampf(e.age / 0.4, 0.05, 1.0)
		var fill: Color = e.d["col"]
		if e.flash > 0.0:
			fill = fill.lerp(Color(1, 1, 1), 0.5)
		var edible := e.r < ABSORB_LIVE * R
		var va := vis_alpha(e.r)
		if va <= 0.0:
			continue
		fill.a *= va
		var outline := Color(0.55, 1.0, 0.65, va) if edible else Color(1.0, 0.25, 0.2)
		if e.apex and not edible:
			var pulse := 0.5 + 0.5 * sin(t * (9.0 if e.state == 1 else 3.0))
			draw_arc(c, sr * 1.25, 0, TAU, 48, Color(1.0, 0.2, 0.15, 0.3 + 0.5 * pulse * (1.0 if e.state == 1 else 0.4)), maxf(2.0, sr * 0.08))
			if e.state == 0:
				# sight radius, so you can sneak around it
				draw_arc(c, (e.r * 3.5 + R * 6.0) * zoom, 0, TAU, 64, Color(1.0, 0.3, 0.2, 0.12), 1.5)
		elif e.elite:
			outline = Color(1.0, 0.8, 0.2)
			draw_arc(c, sr * 1.18, 0, TAU, 24, Color(1.0, 0.8, 0.2, 0.35), maxf(1.0, sr * 0.05))
		if e.stun > 0.0:
			draw_arc(c, sr * 1.1, 0, TAU, 24, Color(0.6, 0.9, 1.0, 0.8), 2.0)
		if e.burn > 0.0 and sr > 3.0:
			draw_circle(c, sr * 1.08, Color(1.0, 0.45, 0.1, 0.25))
		if e.d.get("fly", false):
			draw_circle(c + Vector2(sr * 0.3, sr * 0.5), sr * 0.9, Color(0, 0, 0, 0.25))
		if sr > 3.0 and not e.d.get("fly", false):
			var wig := sin(e.age * (18.0 if e.vel.length() > R * 0.2 else 4.0)) * 0.4
			for sgn: float in [-1.0, 1.0]:
				var la := e.rot + sgn * (PI * 0.5 + wig * sgn)
				draw_line(c, c + Vector2.from_angle(la) * sr * 1.25, fill.darkened(0.4), maxf(1.0, sr * 0.18))
		draw_circle(c, sr, fill)
		draw_arc(c, sr, 0, TAU, 24, outline, clampf(sr * 0.08, 1.5, 5.0))
		if sr > 4.0:
			var look := (ppos - e.pos).normalized() if (e.state == 1 or e.pos.distance_to(ppos) < R * 6.0) else Vector2.from_angle(e.rot)
			var eo := look.orthogonal() * sr * 0.32
			for sgn: float in [-1.0, 1.0]:
				var ec := c + look * sr * 0.45 + eo * sgn
				draw_circle(ec, sr * 0.18, Color.WHITE)
				draw_circle(ec + look * sr * 0.07, sr * 0.09, Color.BLACK)
		if e.state == 1 and e.d["beh"] == "ram":
			draw_line(c, c + (ppos - e.pos).normalized() * sr * 4.0, Color(1, 0.2, 0.2, 0.6), 2.0)
		if e.hp < e.max_hp and sr > 6.0:
			var w := sr * 2.0
			var tl := c + Vector2(-sr, -sr - 8)
			draw_rect(Rect2(tl, Vector2(w, 4)), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(tl, Vector2(w * clampf(e.hp / e.max_hp, 0, 1), 4)), Color(1, 0.3, 0.3))
		_label(c + Vector2(0, sr * 0.45), String(e.d["lbl"]), sr, Color(1, 1, 1, 0.85))
	for g in grabs:
		var e: Thing = g["e"]
		if e.dead:
			continue
		var src: Vector2 = item_world(g["from"])[0]
		draw_line(w2s(src), w2s(e.pos), Color(1.0, 0.85, 0.2), 3.0)


func _draw_boss(e: Thing) -> void:
	# a rival ooze: same body as yours, crimson-black, its own feeding arms
	var c := w2s(e.pos)
	var sr := e.r * zoom
	var tents := []
	var i := 0
	for f in e.feelers:
		i += 1
		if f["target"] == null and (f["tip"] as Vector2).distance_to(e.pos) < e.r * 1.05:
			continue
		tents.append({"tip": f["tip"], "w": 0.16, "latched": f["latched"], "seed": float(i) + 7.0})
	for tt in tents:
		_draw_tentacle(e.pos, e.r, tt["tip"], tt["w"], tt["latched"], tt["seed"], RIVAL_OOZE, Color(0.85, 0.25, 0.3, 0.9))
	for part in e.parts:
		var a: float = part["a"] + e.rot
		var ps: float = part["s"] * sr
		_shape(part["sh"], c + Vector2.from_angle(a) * (sr + ps * 0.25), ps, a, part["c"], Color(0, 0, 0, 0.6), 1.5)
	var body := _membrane(e.pos, e.r, e.vel, e.rot, tents, 1.0)
	draw_colored_polygon(body, RIVAL_OOZE)
	draw_circle(c, sr * 0.45, Color(0.9, 0.15, 0.25, 0.18))
	draw_circle(c, sr * 0.22, Color(1.0, 0.35, 0.4, 0.3))
	var shine := _membrane(e.pos, e.r, e.vel, e.rot, tents, 0.86)
	var arc := PackedVector2Array()
	for k in shine.size():
		var th := TAU * k / shine.size()
		if th > PI * 1.05 and th < PI * 1.55:
			arc.append(shine[k])
	if arc.size() > 1:
		draw_polyline(arc, Color(1.0, 0.45, 0.5, 0.5), maxf(1.5, sr * 0.06))
	body.append(body[0])
	draw_polyline(body, Color(1, 1, 1, 0.9) if e.flash > 0.0 else Color(0.05, 0, 0.01, 0.9), maxf(1.5, sr * 0.035))
	_label(c, "RIVAL", sr * 0.6, Color(1, 0.6, 0.7))


func _tentacles() -> Array:
	# every pseudopod currently reaching out: feeders plus the lurch arm
	var out := []
	var i := 0
	for f in feelers:
		i += 1
		if f["target"] == null and (f["tip"] as Vector2).distance_to(ppos) < R * 1.05:
			continue
		out.append({"tip": f["tip"], "w": 0.16, "latched": f["latched"], "seed": float(i)})
	if lurch_state > 0:
		out.append({"tip": lurch_tip, "w": 0.34, "latched": lurch_state == 2, "seed": 0.0})
	return out


func _draw_tentacle(origin: Vector2, rad: float, tip: Vector2, w0: float, latched: bool, seed: float, skin: Color, cell: Color) -> void:
	var to := tip - origin
	var L := to.length()
	if L < rad * 0.9:
		return
	var dir := to / L
	var nrm := dir.orthogonal()
	var base := origin + dir * rad * 0.75
	var span := tip - base
	var bend := sin(t * 5.0 + seed * 1.7) * span.length() * 0.18
	var ctrl := base + span * 0.5 + nrm * bend
	var n := 12
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var pts := []
	for k in n + 1:
		var u := float(k) / n
		var p := base.lerp(ctrl, u).lerp(ctrl.lerp(tip, u), u)
		pts.append(p)
	for k in n + 1:
		var u := float(k) / n
		var p: Vector2 = pts[k]
		var tang: Vector2 = ((pts[mini(k + 1, n)] as Vector2) - (pts[maxi(k - 1, 0)] as Vector2)).normalized()
		var w := rad * w0 * lerpf(1.0, 0.28, u) * (1.0 + 0.12 * sin(u * 9.0 - t * 8.0))
		left.append(w2s(p + tang.orthogonal() * w))
		right.append(w2s(p - tang.orthogonal() * w))
	right.reverse()
	left.append_array(right)
	draw_colored_polygon(left, skin)
	draw_circle(w2s(tip), maxf(2.0, rad * w0 * 0.55 * zoom), skin)
	# cells stream out to forage, then back along a latched arm carrying food
	for k in 3:
		var u := fposmod(t * 1.4 + k / 3.0 + seed * 0.37, 1.0)
		if latched:
			u = 1.0 - u
		var idx := clampi(int(u * n), 0, n)
		var cp: Vector2 = pts[idx]
		draw_circle(w2s(cp), maxf(1.5, rad * w0 * 0.35 * zoom), cell)


func _membrane(origin: Vector2, rad: float, vel: Vector2, ang: float, tents: Array, shrink: float) -> PackedVector2Array:
	var c := w2s(origin)
	var sr := rad * zoom
	var sp := vel.length()
	var st := clampf(sp / maxf(max_speed() * 5.0, 0.0001), 0.0, 0.32)
	var va := vel.angle()
	var pts := PackedVector2Array()
	var n := 64
	for k in n:
		var th := TAU * k / n
		var ph := th - ang
		var wob := 1.0 + 0.045 * sin(3.0 * ph + t * 1.7) + 0.03 * sin(5.0 * ph - t * 2.6) + 0.018 * sin(8.0 * ph + t * 4.1)
		var phi := th - va
		var ell := 1.0 / sqrt(pow(cos(phi) / (1.0 + st), 2.0) + pow(sin(phi) / (1.0 - 0.4 * st), 2.0))
		var bulge := 0.0
		for tt in tents:
			var ta: float = ((tt["tip"] as Vector2) - origin).angle()
			var dd := angle_difference(th, ta)
			bulge += (0.5 * float(tt["w"])) * exp(-pow(dd / 0.32, 2.0))
		pts.append(c + Vector2.from_angle(th) * sr * (wob * ell + bulge) * shrink)
	return pts


func _draw_player() -> void:
	var c := w2s(ppos)
	var sr := R * zoom
	if has("fire.halo") or has("fire.inferno"):
		var er := R * (3.2 if has("fire.inferno") else 1.9) * zoom
		draw_circle(c, er, Color(1.0, 0.45, 0.1, 0.07))
		draw_arc(c, er * (0.97 + 0.03 * sin(t * 9.0)), 0, TAU, 48, Color(1.0, 0.5, 0.15, 0.45), 2.0)
	for s in sparks:
		var a: float = s["t"] / 2.5
		draw_circle(w2s(s["pos"]), maxf(1.5, s["r"] * zoom * 0.25), Color(0.5, 0.9, 1.0, a * 0.8))
	if syn_active.has("blender"):
		var n: int = 2 + syn_active["blender"]["links"].size()
		for i in n:
			var ha := halberd_ang + TAU * i / n
			var hp := w2s(ppos + Vector2.from_angle(ha) * R * 2.1)
			var dirv := Vector2.from_angle(ha + PI * 0.5)
			draw_line(hp - dirv * sr * 0.45, hp + dirv * sr * 0.45, Color(0.85, 0.95, 1.0, 0.9), maxf(2.0, sr * 0.08))
	if has("blade.orbit"):
		for i in 3:
			var bp := w2s(ppos + Vector2.from_angle(blade_ang + TAU * i / 3.0) * R * 2.0)
			_shape(4, bp, sr * 0.3, blade_ang * 2.0 + i, Color(0.85, 0.85, 1.0), Color(0, 0, 0, 0.6), 1.0)
	for cr in critters:
		var cp := w2s(cr["pos"])
		draw_circle(cp, maxf(3.0, sr * 0.16), OOZE)
		draw_circle(cp, maxf(1.5, sr * 0.07), Color(0.55, 0.95, 0.45))
	var tents := _tentacles()
	for tt in tents:
		_draw_tentacle(ppos, R, tt["tip"], tt["w"], tt["latched"], tt["seed"], OOZE, Color(0.32, 0.22, 0.42, 0.9))
	# hull pieces sit half-sunk in the ooze: draw them, then the membrane over their inner half
	for it in items:
		if not it.surface:
			continue
		var a := hull_ang + it.ang
		var p := w2s(ppos + Vector2.from_angle(a) * (R + it.r * 0.25))
		var isr := it.r * zoom
		var col: Color = it.d["col"]
		if it.creature:
			var wig := sin(t * 14.0 + it.wob) * 0.6
			for sgn: float in [-1.0, 1.0]:
				var la := a + sgn * (0.5 + wig * sgn)
				draw_line(p, p + Vector2.from_angle(la) * isr * 1.5, col.darkened(0.4), maxf(1.0, isr * 0.2))
		var bc := _branch_col(it.d)
		_shape(int(it.d.get("sh", 0)) if not it.creature else 0, p, isr, a, col, bc if bc.a > 0.0 else Color(0, 0, 0, 0.6), maxf(1.0, isr * (0.14 if bc.a > 0.0 else 0.08)))
	var body := _membrane(ppos, R, pvel, hull_ang, tents, 1.0)
	draw_colored_polygon(body, OOZE)
	# what's inside: buried junk as faint silhouettes and the crushed core's glow
	var bi := 0
	for it in items:
		if it.surface:
			continue
		bi += 1
		if bi > 30:
			break
		var a := hull_ang + it.ang
		var rr := sr * (0.2 + 0.6 * fposmod(it.wob, 1.0))
		var col: Color = it.d["col"]
		draw_circle(c + Vector2.from_angle(a) * rr, maxf(1.0, it.r * zoom * 0.6), Color(col.darkened(0.6), 0.16))
	var core_frac := clampf(core_area / maxf(R * R / GROWTH, 0.0001), 0.0, 1.0)
	draw_circle(c, sr * 0.42 * (0.6 + core_frac), Color(0.45, 0.18, 0.65, 0.14 + 0.2 * core_frac))
	draw_circle(c, sr * 0.2 * (0.6 + core_frac), Color(0.75, 0.4, 1.0, 0.18 + 0.35 * core_frac))
	# oily sheen: a thin iridescent highlight on the upper-left of the membrane
	var shine := _membrane(ppos, R, pvel, hull_ang, tents, 0.86)
	var arc := PackedVector2Array()
	var arc2 := PackedVector2Array()
	for k in shine.size():
		var th := TAU * k / shine.size()
		if th > PI * 1.05 and th < PI * 1.55:
			arc.append(shine[k])
		if th > PI * 1.6 and th < PI * 1.8:
			arc2.append(shine[k])
	if arc.size() > 1:
		draw_polyline(arc, Color(0.62, 0.55, 0.85, 0.55), maxf(1.5, sr * 0.06))
	if arc2.size() > 1:
		draw_polyline(arc2, Color(0.4, 0.8, 0.8, 0.35), maxf(1.0, sr * 0.04))
	draw_circle(c + Vector2.from_angle(PI * 1.3) * sr * 0.55, maxf(1.5, sr * 0.07), Color(1, 1, 1, 0.45))
	body.append(body[0])
	var hurt_flash := iframes > 0.0 and int(iframes * 16) % 2 == 0
	draw_polyline(body, Color(1.0, 0.25, 0.3, 0.9) if hurt_flash else Color(0, 0, 0, 0.85), maxf(1.5, sr * (0.07 if hurt_flash else 0.03)))
	for it in items:
		if it.surface:
			var p := w2s(ppos + Vector2.from_angle(hull_ang + it.ang) * (R + it.r * 0.25))
			var col: Color = it.d["col"]
			_label(p + Vector2.from_angle(hull_ang + it.ang) * it.r * zoom * 0.3, String(it.d["lbl"]), it.r * zoom, Color(0, 0, 0, 0.75) if col.get_luminance() > 0.45 else Color(1, 1, 1, 0.85))
	for id in syn_active:
		var sa: Dictionary = syn_active[id]
		var cp := w2s(item_world(sa["cat"])[0])
		for o in sa["links"]:
			draw_line(cp, w2s(item_world(o)[0]), Color(0.5, 1.0, 1.0, 0.6), 2.0)
	# branch focus markers: where each ability fires from
	for b in Defs.TREE:
		if rank(b["tag"]) <= 0 or b["tag"] in ["metal", "wheel", "organic"]:
			continue
		var fa := _focus(b["tag"])
		var tip := c + Vector2.from_angle(fa) * (sr * 1.0 + 16.0)
		var bse := c + Vector2.from_angle(fa) * (sr * 1.0 + 4.0)
		var side := Vector2.from_angle(fa).orthogonal() * 6.0
		draw_colored_polygon(PackedVector2Array([tip, bse + side, bse - side]), b["col"])
	if imbalance > 0.04:
		var ha := hull_ang + com.angle()
		draw_circle(c + Vector2.from_angle(ha) * sr * 0.6, maxf(3.0, sr * imbalance * 0.5), Color(1.0, 0.8, 0.3, 0.6))
	if burst_t > 0.0:
		draw_arc(c, sr * 1.6, hull_ang, hull_ang + PI * 1.5, 32, Color(0.25, 0.15, 0.35, 0.7), 3.0)


func _draw_fx() -> void:
	for b in bullets:
		if not _on_screen(b.pos, b.r):
			continue
		var c := w2s(b.pos)
		var sr := maxf(b.r * zoom, 2.0 if b.hostile else 1.5)
		if b.hostile:
			draw_circle(c, sr + 1.5, Color(0.3, 0, 0))
			draw_circle(c, sr, b.col)
		else:
			draw_line(c, c - b.vel.normalized() * maxf(sr * 3.0, 5.0), b.col, maxf(1.5, sr))
	for f in fx_beams:
		var a: float = f["t"] / 0.1
		draw_line(w2s(f["a"]), w2s(f["b"]), Color(f["col"], 0.75 * a), maxf(1.5, f["w"] * zoom * 2.0))
	for f in fx_cones:
		var p := w2s(f["pos"])
		var L: float = f["len"] * zoom
		var pts := PackedVector2Array([p, p + Vector2.from_angle(f["a"] - f["half"]) * L, p + Vector2.from_angle(f["a"]) * L * 1.05, p + Vector2.from_angle(f["a"] + f["half"]) * L])
		draw_colored_polygon(pts, Color(f["col"], 0.22))
	for f in fx_bolts:
		var pts := PackedVector2Array()
		for q in f["pts"]:
			pts.append(w2s(q))
		draw_polyline(pts, f["col"], 2.0)
	for f in fx_rings:
		var k: float = 1.0 - f["t"] / f["tm"]
		draw_arc(w2s(f["pos"]), f["r"] * zoom * (0.3 + 0.7 * k), 0, TAU, 40, Color(f["col"], (1.0 - k) * f["col"].a), 3.0)
	for dd in dust:
		draw_circle(w2s(dd["pos"]), 1.5, Color(0.8, 0.7, 1.0, 0.8))
	for f in fx_texts:
		var a: float = clampf(f["t"] / 0.4, 0.0, 1.0)
		var s: String = f["s"]
		var fs: int = f["size"]
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := w2s(f["pos"]) - Vector2(w * 0.5, 0)
		draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, a))
		draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(f["col"], a))


func _hud_text(p: Vector2, s: String, fs: int, col: Color) -> void:
	draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8))
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _draw_hud() -> void:
	var remain := maxf(0.0, run_len - t)
	_hud_text(Vector2(16, 30), "%02d:%02d" % [int(t) / 60, int(t) % 60], 26, Color(1, 1, 1))
	_hud_text(Vector2(100, 30), "/ %02d:%02d" % [int(run_len) / 60, int(run_len) % 60] if remain > 0 else "RIVAL ARRIVED", 16, Color(0.7, 0.7, 0.8))
	_hud_text(Vector2(16, 62), fmt_len(R * 2.0), 30, Color(0.9, 0.8, 1.0))
	var zl := "ZONE %d · %s" % [zone + 1, zone_def.get("name", "")]
	if wall_r > 0.0:
		zl += ("  ·  WALLS EDIBLE — BREAK OUT" if zone_open else "  ·  exit at %s" % fmt_len(wall_r / ABSORB * 2.0))
	_hud_text(Vector2(16, 84), zl, 14, Color(0.6, 1.0, 0.7) if zone_open else Color(0.7, 0.6, 1.0))
	var sc := surface_count()
	_hud_text(Vector2(16, 106), "hull %d live · %d buried · core %d" % [sc, items.size() - sc, core_count], 14, Color(0.8, 0.8, 0.85))
	for i in int(max_integrity):
		var part := clampf(integrity - i, 0.0, 1.0)
		var c := Vector2(24 + i * 22, 124)
		draw_circle(c, 8, Color(0.2, 0.2, 0.25))
		if part > 0.0:
			draw_circle(c, 8 * maxf(part, 0.3), Color(1.0, 0.4, 0.6) if part >= 1.0 else Color(0.6, 0.3, 0.4))
	_hud_text(Vector2(30 + max_integrity * 22, 130), "core integrity" + ("  — NO ARMOR!" if sc == 0 else ""), 12, Color(1, 0.6, 0.7) if sc == 0 else Color(0.7, 0.7, 0.8))
	if collapse_idx < COLLAPSES.size():
		var prev: float = COLLAPSES[collapse_idx - 1] if collapse_idx > 0 else R0
		var nxt: float = COLLAPSES[collapse_idx]
		var f := clampf(log(R / prev) / log(nxt / prev), 0.0, 1.0)
		draw_rect(Rect2(16, 142, 200, 8), Color(0.2, 0.2, 0.25))
		draw_rect(Rect2(16, 142, 200 * f, 8), Color(0.8, 0.5, 1.0))
		_hud_text(Vector2(222, 151), "collapse @ " + fmt_len(nxt * 2.0), 12, Color(0.8, 0.7, 1.0))
	_hud_text(Vector2(16, 172), "lopsided %d%%" % int(imbalance / 0.6 * 100.0), 12, Color(1.0, 0.85, 0.4) if imbalance > 0.06 else Color(0.6, 0.6, 0.65))
	var bc := "CHURN ready" if burst_cd <= 0.0 else "churn %.0fs" % burst_cd
	_hud_text(Vector2(120, 172), bc, 12, Color(0.85, 0.7, 1.0) if burst_cd <= 0.0 else Color(0.5, 0.5, 0.55))
	_draw_tree_panel()
	_draw_apex_markers()
	if boss != null and not boss.dead:
		var bw := 500.0
		var bx := (screen.x - bw) * 0.5
		var ratio := boss.r / R
		_hud_text(Vector2(bx, screen.y - 58), "RIVAL SINGULARITY  %s  (%.2fx your size — eat it below 0.80x)" % [fmt_len(boss.r * 2.0), ratio], 14, Color(1, 0.5, 0.6))
		draw_rect(Rect2(bx, screen.y - 48, bw, 10), Color(0.2, 0.1, 0.12))
		draw_rect(Rect2(bx, screen.y - 48, bw * clampf(ratio / 2.0, 0, 1), 10), Color(1, 0.3, 0.45))
		draw_line(Vector2(bx + bw * 0.4, screen.y - 52), Vector2(bx + bw * 0.4, screen.y - 34), Color(0.5, 1, 0.6), 2.0)
	var by := screen.y * 0.22
	for b in banners:
		var a := clampf(b["t"] / 0.5, 0.0, 1.0) * clampf((3.5 - b["t"]) / 0.15, 0.0, 1.0)
		var title: String = b["title"]
		var w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_string_outline(font, Vector2((screen.x - w) * 0.5, by), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 6, Color(0, 0, 0, a))
		draw_string(font, Vector2((screen.x - w) * 0.5, by), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 0.9, 1.0, a))
		var sub: String = b["sub"]
		var w2 := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string_outline(font, Vector2((screen.x - w2) * 0.5, by + 24), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, a))
		draw_string(font, Vector2((screen.x - w2) * 0.5, by + 24), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.85, 0.9, a))
		by += 74
	if not bot_mode:
		_hud_text(Vector2(16, screen.y - 14), "WASD crawl · SPACE / click lurch · SHIFT churn · Q/E nudge spin · F12 screenshot", 12, Color(0.6, 0.6, 0.65))
	else:
		_hud_text(Vector2(16, screen.y - 14), "AUTOPILOT", 12, Color(0.6, 0.9, 0.6))


func _draw_tree_panel() -> void:
	var x := screen.x - 250.0
	var y := 26.0
	_hud_text(Vector2(x, y), "ESSENCE TREE", 13, Color(0.85, 0.75, 1.0))
	y += 8
	for b in Defs.TREE:
		var tg: String = b["tag"]
		var rk := rank(tg)
		var col: Color = b["col"]
		var dim := col if rk > 0 else col.darkened(0.55)
		y += 18
		_hud_text(Vector2(x, y), String(b["name"]), 13, dim)
		for i in MAX_RANK:
			var pc := Vector2(x + 96 + i * 13, y - 5)
			draw_circle(pc, 4.5, col if i < rk else Color(0.22, 0.22, 0.28))
		if rk < MAX_RANK:
			var f := clampf(float(essence[tg]) / ess_need(tg), 0.0, 1.0)
			draw_rect(Rect2(x + 162, y - 8, 70, 5), Color(0.2, 0.2, 0.25))
			draw_rect(Rect2(x + 162, y - 8, 70 * f, 5), dim)
		var picked := []
		for n in nodes:
			if String(n).begins_with(tg + ".") and not String(n).ends_with(".base"):
				var id := String(n).get_slice(".", 1)
				for pair in b["ranks"]:
					for o in pair:
						if o[0] == id:
							picked.append(o[1])
		if rk > 0:
			y += 13
			var s := String(b["base"][0])
			if not picked.is_empty():
				s += " · " + " · ".join(picked)
			_hud_text(Vector2(x + 6, y), s, 10, Color(0.75, 0.75, 0.8))
	if not syn_active.is_empty():
		y += 24
		_hud_text(Vector2(x, y), "HULL SYNERGIES", 13, Color(0.5, 1.0, 1.0))
		for id in syn_active:
			y += 16
			_hud_text(Vector2(x, y), String(syn_active[id]["def"]["name"]), 13, Color(1, 1, 1))


func _draw_apex_markers() -> void:
	for e in apexes:
		if e.dead:
			continue
		var s := w2s(e.pos)
		var margin := 34.0
		var inside := s.x > 0 and s.y > 0 and s.x < screen.x and s.y < screen.y
		if inside:
			continue
		var ctr := screen * 0.5
		var dir := (s - ctr).normalized()
		var k := minf((ctr.x - margin) / maxf(absf(dir.x), 0.001), (ctr.y - margin) / maxf(absf(dir.y), 0.001))
		var p := ctr + dir * k
		var edible := e.r < ABSORB_LIVE * R
		var col := Color(0.55, 1.0, 0.65) if edible else Color(1.0, 0.3, 0.2, 0.6 + 0.4 * sin(t * (10.0 if e.state == 1 else 3.0)))
		var side := dir.orthogonal() * 9.0
		draw_colored_polygon(PackedVector2Array([p + dir * 14.0, p - dir * 4.0 + side, p - dir * 4.0 - side]), col)
		var lbl := "%s %s" % [String(e.d["lbl"]), fmt_len(e.pos.distance_to(ppos))]
		if e.state == 1:
			lbl = "HUNTING · " + lbl
		var w := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var lp := p - dir * 22.0 - Vector2(w * 0.5, -4)
		lp.x = clampf(lp.x, 4, screen.x - w - 4)
		_hud_text(lp, lbl, 12, col)


func _draw_choice() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0, 0, 0, 0.55))
	var p: Dictionary = pending[0]
	var title: String = p["title"]
	var w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	_hud_text(Vector2((screen.x - w) * 0.5, screen.y * 0.3), title, 30, Color(1, 0.95, 1))
	var sub: String = p.get("sub", "")
	var w2 := font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	_hud_text(Vector2((screen.x - w2) * 0.5, screen.y * 0.3 + 26), sub, 15, Color(0.8, 0.8, 0.85))
	var opts: Array = p["options"]
	var cw := 300.0
	var ch := 120.0
	var gap := 24.0
	var total := opts.size() * cw + (opts.size() - 1) * gap
	var x0 := (screen.x - total) * 0.5
	card_rects.clear()
	for i in opts.size():
		var o: Dictionary = opts[i]
		var r := Rect2(x0 + i * (cw + gap), screen.y * 0.42, cw, ch)
		card_rects.append(r)
		var col: Color = o["col"]
		draw_rect(r, Color(0.1, 0.1, 0.14, 0.95))
		draw_rect(r, col, false, 3.0)
		_hud_text(r.position + Vector2(14, 30), "[%d]  %s" % [i + 1, o["name"]], 17, col)
		draw_multiline_string_outline(font, r.position + Vector2(14, 62), String(o["desc"]), HORIZONTAL_ALIGNMENT_LEFT, cw - 28, 13, -1, 4, Color(0, 0, 0, 0.8))
		draw_multiline_string(font, r.position + Vector2(14, 62), String(o["desc"]), HORIZONTAL_ALIGNMENT_LEFT, cw - 28, 13, -1, Color(0.9, 0.9, 0.95))
