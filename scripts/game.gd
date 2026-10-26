extends Node2D
## CRITICAL MASS — mechanics prototype.
## Everything is simulated in world meters and drawn manually in screen space
## so a single scene can span 10 cm -> several km without float/camera issues.

const ABSORB := 0.5         # props / wrecks absorbable when r < ABSORB * R
const ABSORB_LIVE := 0.42   # live enemies absorbable when r < ABSORB_LIVE * R
const LOOSE_ABSORB := 0.75  # shed pieces can be re-grabbed up to this ratio
const BURY := 0.05          # surface items get buried once r < BURY * R
const DUST := 0.03          # world things below DUST * R dissolve into dust
const VIEW_K := 7.0        # half screen height, in player radii
const R0 := 0.05            # 10 cm diameter start
const GROWTH := 0.16
const COLLAPSES := [0.15, 0.4, 1.0, 2.5, 7.0, 25.0, 70.0, 200.0, 600.0, 1500.0]
const TIER_R := [1.0, 25.0]
const TIER_NAMES := ["MICRO-SCALE", "MESO-SCALE", "MACRO-APOCALYPSE"]
const MAX_BULLETS := 800
# Designed scale arc (seconds of a 20-min run -> radius). Absorption efficiency
# bends toward it so skilled play runs a bit ahead and sloppy play catches up.
const SCHEDULE := [[0.0, 0.05], [300.0, 1.0], [720.0, 25.0], [1200.0, 1000.0], [1500.0, 4000.0]]
const LOOSE_TIME := 5.0

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
	var dead := false
	var gone := false
	var grabbed := false
	var state := 0
	var st := 0.0
	var elite := false
	var shed_acc := 0.0
	var area_v := 0.0       # growth value carried by a shed hull piece
	var parts := []         # boss hull decoration

class HullItem:
	var d: Dictionary
	var r := 0.1
	var area := 0.01
	var mass := 0.01
	var ang := 0.0
	var surface := true
	var cd := 0.0
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
	var hostile := false
	var homing: Thing = null
	var power := 1.0
	var turn := 0.0

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
var iframes := 0.0
var burst_t := 0.0
var burst_cd := 0.0
var core_tags := {}
var auras := {}
var syn_active := {}    # id -> {"cat": HullItem, "links": Array}
var com := Vector2.ZERO # hull-local center-of-mass offset
var imbalance := 0.0
var slam_cd := 0.0
var collapse_idx := 0
var tier := 0
var stats := {"synergies": 0, "absorbed": 0, "kills": 0, "shed": 0, "recovered": 0, "lost": 0, "slams": 0, "collapses": 0, "hits": 0, "core_hits": 0}
var halberd_ang := 0.0
var tesla_cd := 0.0
var spark_cd := 0.0
var spark_tick := 0.0
var aura_tick := 0.0
var regen_t := 0.0
var game_over := false
var victory := false
var end_t := 0.0
var input_move := Vector2.ZERO
var manual_spin := 0.0
var want_burst := false
var pull_r := 0.0

# --- world ---
var props: Array[Thing] = []
var enemies: Array[Thing] = []
var bullets: Array[Bullet] = []
var boss: Thing = null
var boss_spawned := false
var strike_cd := 8.0
var strikes := []
var spawn_acc := 0.0
var horde_t := 40.0
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

var prop_sorted: Array = []
var enemy_sorted: Array = []
var prop_by_name := {}


func _ready() -> void:
	font = ThemeDB.fallback_font
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
	rng.seed = seed_v
	if bot_mode:
		bot = Bot.new()
	if shot_dir != "":
		DirAccess.make_dir_recursive_absolute(shot_dir)
		next_shot = t + 1.0
	next_log = t
	_build_polys()
	prop_sorted = Defs.PROPS.duplicate()
	for d in Defs.PROPS:
		prop_by_name[d["name"]] = d
	enemy_sorted = Defs.ENEMIES.duplicate()
	if start_r > R0:
		_seed_hull(start_r)
	recompute_size()
	view_r = R * VIEW_K
	cam = ppos
	_update_zoom()
	for i in 60:
		spawn_prop_cluster(true)
	for i in 6:
		spawn_enemy()
	# a debug-seeded hull fires synergy/collapse banners while it's built; drop them
	banners.clear()
	stats["synergies"] = 0
	if tier == 0:
		banner("MICRO-SCALE", "eat things smaller than you · avoid things bigger")
	else:
		banner(TIER_NAMES[tier], "")


func _seed_hull(target_r: float) -> void:
	# Debug: grow to target radius with a plausible hull for testing later tiers.
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
		recompute_size()
		while collapse_idx < COLLAPSES.size() and R >= COLLAPSES[collapse_idx]:
			do_collapse(true)
	tier = _tier_for(R)


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
	if not (game_over or victory):
		t += dt
	_read_input()
	if bot != null:
		var b := bot.think(self, dt)
		input_move = b["move"]
		want_burst = b["burst"]
		manual_spin = b["spin"]

	_build_grid()
	if not (game_over or victory):
		_update_player(dt)
		_update_hull_weapons(dt)
		_update_synergies(dt)
		_update_auras(dt)
	_update_enemies(dt)
	_update_bullets(dt)
	_update_props(dt)
	if not (game_over or victory):
		_player_collisions()
		_spawning(dt)
		_update_strikes(dt)
		_check_collapse()
		_check_boss()
	_cleanup()
	_update_camera(dt)
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
	want_burst = Input.is_key_pressed(KEY_SPACE)


func _unhandled_input(ev: InputEvent) -> void:
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
# Player physics: rolling, spin, imbalance, slams
# =============================================================================

func max_speed() -> float:
	return 3.4 * R * (1.0 + 0.08 * aura_lvl("Momentum")) * (1.0 - 0.45 * imbalance)


func _update_player(dt: float) -> void:
	iframes -= dt
	burst_t -= dt
	burst_cd -= dt
	slam_cd -= dt
	var accel := 10.0 * R * (1.0 - 0.6 * imbalance)
	var target := input_move.limit_length(1.0) * max_speed()
	pvel = pvel.move_toward(target, accel * dt)
	ppos += pvel * dt

	# Spin model: steering curls the hull, the heavy side swings to trail like a
	# pendulum, and plain rolling adds a slow drift so every turret gets a turn.
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
	omega = clampf(omega, -15.0, 15.0)
	hull_ang = wrapf(hull_ang + omega * dt, -PI, PI)

	# Slam: lopsided hull whipping its heavy side across the leading edge.
	if imbalance > 0.06 and slam_cd <= 0.0 and sp > 1.2 * R:
		heavy_ang = hull_ang + com.angle()
		if absf(angle_difference(pvel.angle(), heavy_ang)) < 0.35:
			_slam(heavy_ang)

	regen_t += dt * (1.0 + 0.5 * aura_lvl("Biomass"))
	if regen_t > 25.0:
		regen_t = 0.0
		if integrity < 3.0:
			integrity = minf(3.0, integrity + 1.0)


func _slam(ang: float) -> void:
	slam_cd = 0.8
	stats["slams"] += 1
	var c := ppos + Vector2.from_angle(ang) * R * 1.1
	var rad := R * (1.6 + 5.0 * imbalance)
	var dmg := 14.0 * imbalance * R * R
	for e: Thing in query(c, rad):
		hurt(e, dmg)
		e.vel += (e.pos - c).normalized() * R * 6.0
	ring(c, rad, Color(1.0, 0.85, 0.4, 0.9), 0.4)
	shake = maxf(shake, 0.25 + imbalance)
	if imbalance > 0.12:
		text(c, "SLAM!", Color(1, 0.85, 0.4), 18)
	var sh := aura_lvl("Shrapnel Bloom")
	if sh > 0:
		for i in 6 + sh * 3:
			var a := ang + rng.randf_range(-1.2, 1.2)
			_spawn_bullet(c, Vector2.from_angle(a) * R * 9.0, 0.5, 2.0 * R * R * sh, R * 0.06, Color(0.9, 0.9, 1.0), 2)


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
	for it in items:
		if it.surface:
			m += Vector2.from_angle(it.ang) * R * it.mass
			mt += it.mass
		else:
			mt += it.mass * 0.3
	com = m / mt
	imbalance = clampf(com.length() / R, 0.0, 0.6)
	_recompute_synergies()
	pull_r = R * (2.4 + 0.5 * aura_lvl("Biomass"))


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
	it.cd = rng.randf() * 0.4
	it.wob = rng.randf() * TAU
	place_item(it)
	items.append(it)
	if th.loose >= 0.0:
		stats["recovered"] += 1
		if th.r > 0.12 * R:
			text(th.pos, "RECOVERED", Color(0.5, 1.0, 0.6), 14)
	else:
		stats["absorbed"] += 1
		if th.r > 0.16 * R:
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
			if e != boss:
				e.vel += (e.pos - ppos).normalized() * R * 14.0
		ring(ppos, R * 5.0, Color(1, 0.2, 0.2), 0.5)
		shake = maxf(shake, 0.8)
		text(ppos + Vector2(0, -R * 1.6), "CORE BREACH", Color(1, 0.3, 0.3), 20)
		if integrity <= 0.0:
			game_over = true
			print("DEFEAT at T=%.1f" % t)
			banner("SINGULARITY COLLAPSED", "R to restart")
	for it: HullItem in taken:
		items.erase(it)
		var a := hull_ang + it.ang
		var th := Thing.new()
		th.d = it.d
		th.r = it.r
		th.pos = ppos + Vector2.from_angle(a) * (R + it.r * 0.4)
		th.vel = Vector2.from_angle(a + rng.randf_range(-0.5, 0.5)) * R * rng.randf_range(7.0, 11.0)
		th.loose = LOOSE_TIME
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
	var nt := _tier_for(R)
	if nt > tier:
		tier = nt
		banner(TIER_NAMES[tier], ["", "the fences and sedans are snacks now", "eat the city"][tier])
		shake = 1.0


func _tier_for(r: float) -> int:
	if r >= TIER_R[1]:
		return 2
	if r >= TIER_R[0]:
		return 1
	return 0


func do_collapse(silent: bool) -> void:
	collapse_idx += 1
	stats["collapses"] += 1
	var crushed := 0
	var tagc := {}
	var before := auras.duplicate()
	var keep: Array[HullItem] = []
	for it in items:
		if not it.surface or it.r < 0.16 * R:
			crushed += 1
			core_area += it.area
			for tg in it.d.get("tags", []):
				core_tags[tg] = int(core_tags.get(tg, 0)) + 1
				tagc[tg] = int(tagc.get(tg, 0)) + 1
		else:
			keep.append(it)
	items = keep
	core_count += crushed
	for a in Defs.AURAS:
		# each level needs double the pieces of the last: per, 2*per, 4*per...
		var cnt := float(core_tags.get(a["tag"], 0)) / float(a["per"])
		var lv := mini(5, floori(log(cnt) / log(2.0)) + 1) if cnt >= 1.0 else 0
		if lv > 0:
			auras[a["name"]] = lv
	recompute_size()
	if silent:
		return
	var gained := []
	for nm in auras:
		if int(auras[nm]) > int(before.get(nm, 0)):
			gained.append("%s %s" % [nm, _roman(int(auras[nm]))])
	var top := []
	var keys := tagc.keys()
	keys.sort_custom(func(a, b): return tagc[a] > tagc[b])
	for k in keys.slice(0, 3):
		top.append("%d %s" % [tagc[k], k])
	var sub := "%d pieces crushed (%s)" % [crushed, ", ".join(top)]
	if not gained.is_empty():
		sub += "  →  " + ", ".join(gained)
	banner("GRAVITATIONAL COLLAPSE", sub)
	ring(ppos, R * 6.0, Color(0.9, 0.5, 1.0), 0.7)
	shake = maxf(shake, 0.6)
	for e: Thing in query(ppos, R * 6.0):
		hurt(e, 6.0 * R * R)
		e.vel += (e.pos - ppos).normalized() * R * 8.0


func _roman(n: int) -> String:
	return ["", "I", "II", "III", "IV", "V"][clampi(n, 0, 5)]


func aura_lvl(nm: String) -> int:
	return int(auras.get(nm, 0))


# =============================================================================
# Weapons
# =============================================================================

func item_world(it: HullItem) -> Array:
	var a := hull_ang + it.ang
	return [ppos + Vector2.from_angle(a) * (R + it.r * 0.2), a]


func _update_hull_weapons(dt: float) -> void:
	var rate := 2.0 if burst_t > 0.0 else 1.0
	for it in items:
		if not it.surface:
			continue
		var w: Dictionary = it.d["w"]
		if w["t"] == "none":
			continue
		it.cd -= dt * rate
		if it.cd > 0.0:
			continue
		it.cd = float(w["cd"]) * rng.randf_range(0.9, 1.1)
		_fire(it, w)


func _fire(it: HullItem, w: Dictionary) -> void:
	var iw := item_world(it)
	var p: Vector2 = iw[0]
	var a: float = iw[1]
	var rng_abs := maxf(float(w.get("rng", 10.0)) * it.r, 2.5 * R)
	var dmg := float(w.get("dmg", 1.0)) * it.r * it.r
	var col: Color = w.get("col", Color.WHITE)
	if nearest_enemy_d > rng_abs + R * 2.0:
		it.cd = 0.15
		return
	match w["t"]:
		"proj":
			var n := int(w.get("n", 1))
			var spread := float(w.get("spread", 0.0))
			var spd := float(w["spd"]) * it.r
			spd = maxf(spd, 6.0 * R)
			for i in n:
				var off := (i - (n - 1) * 0.5) * spread * 0.8 + rng.randf_range(-spread, spread) * 0.5
				var v := Vector2.from_angle(a + off) * spd + pvel * 0.4
				_spawn_bullet(p, v, rng_abs / spd, dmg, float(w.get("br", 0.2)) * it.r, col, 1)
		"missile":
			var tgt := _nearest_enemy(p, rng_abs)
			if tgt == null:
				it.cd = 0.2
				return
			for i in int(w.get("n", 1)):
				var spd2 := maxf(float(w["spd"]) * it.r, 6.0 * R)
				var b := _spawn_bullet(p, Vector2.from_angle(a + rng.randf_range(-0.6, 0.6)) * spd2, rng_abs * 1.5 / spd2, dmg, float(w.get("br", 0.2)) * it.r, col, 1)
				if b:
					b.homing = tgt
					b.turn = 5.0
		"beam":
			var offs := [0.0]
			if w.get("twin", false):
				offs = [-0.14, 0.14]
			for o in offs:
				_beam(p, a + o, rng_abs, float(w.get("w", 0.3)) * it.r, dmg, col)
		"sweep":
			var mult := 2.0 if syn_active.has("lightshow") else 1.0
			var amp := 0.7 * mult
			var s := sin(t * 5.0 + it.wob) * amp
			_beam(p, a + s, rng_abs, float(w.get("w", 0.3)) * it.r * mult, dmg * mult, col)
			_beam(p, a - s, rng_abs, float(w.get("w", 0.3)) * it.r * mult, dmg * mult, w.get("col2", col))
		"zap":
			var tgt := _nearest_enemy(p, rng_abs)
			if tgt == null:
				it.cd = 0.2
				return
			hurt(tgt, dmg)
			_bolt(p, tgt.pos, col)
		"aura":
			var rad := maxf(float(w["rng"]) * it.r, R * 0.6)
			for e: Thing in query(p, rad):
				hurt(e, dmg)
			fx_rings.append({"pos": p, "r": rad, "col": Color(col, 0.35), "t": 0.15, "tm": 0.15, "follow": it})
		"cone":
			var half := float(w["half"])
			var push := float(w.get("push", 0.0))
			for e: Thing in query(p, rng_abs):
				var to := e.pos - p
				if absf(angle_difference(a, to.angle())) < half + e.r / maxf(to.length(), 0.001):
					hurt(e, dmg)
					if push > 0.0 and e != boss:
						e.vel += to.normalized() * push * it.r
			fx_cones.append({"pos": p, "a": a, "half": half, "len": rng_abs, "col": col, "t": 0.12})
		"grapple":
			var best: Thing = null
			var bs := 0.0
			for e: Thing in query(p, rng_abs * (1.6 if syn_active.has("buffet") else 1.0)):
				if e == boss or e.grabbed:
					continue
				var sc := e.r * (3.0 if e.elite else 1.0)
				if sc > bs:
					bs = sc
					best = e
			if best == null:
				it.cd = 0.3
				return
			if syn_active.has("buffet"):
				it.cd *= 0.4
			best.grabbed = true
			grabs.append({"e": best, "from": it})
			text(best.pos, "GRAPPLED", Color(1.0, 0.85, 0.2), 14)


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
# Synergies & auras
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
			banner("SYNERGY: " + String(sd["name"]).to_upper(), sd["desc"])
			stats["synergies"] += 1


func _update_synergies(dt: float) -> void:
	var sp := pvel.length()
	if syn_active.has("blender"):
		var n: int = 2 + syn_active["blender"]["links"].size()
		halberd_ang += (1.5 + 1.4 * sp / R) * dt
		for i in n:
			var hp := ppos + Vector2.from_angle(halberd_ang + TAU * i / n) * R * 2.1
			for e: Thing in query(hp, R * 0.4):
				hurt(e, 7.0 * R * R * dt)
	if syn_active.has("tesla"):
		tesla_cd -= dt
		if tesla_cd <= 0.0:
			tesla_cd = 0.35
			var cat: HullItem = syn_active["tesla"]["cat"]
			var src: Vector2 = item_world(cat)[0]
			var near: Array = query(ppos, R * 4.0)
			near.sort_custom(func(a, b): return a.pos.distance_squared_to(ppos) < b.pos.distance_squared_to(ppos))
			var from := src
			for e: Thing in near.slice(0, 5):
				_bolt(from, e.pos, Color(0.6, 0.9, 1.0))
				hurt(e, 3.5 * R * R)
				from = e.pos
	# grapple pulls (crane weapon, boosted by Kaiju Buffet)
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
			var crush := 30.0 * R * R * (2.0 if syn_active.has("buffet") else 1.0)
			hurt(e, crush)
			ring(e.pos, e.r * 1.5, Color(1.0, 0.85, 0.2), 0.3)
			text(e.pos, "CRUNCH", Color(1.0, 0.85, 0.2), 16)
			if not e.dead:
				e.vel = -to.normalized() * R * 6.0
		else:
			keep.append(g)
	grabs = keep


func _update_auras(dt: float) -> void:
	aura_tick -= dt
	var tick := aura_tick <= 0.0
	if tick:
		aura_tick = 0.2
	var ember := aura_lvl("Ember Halo")
	if ember > 0 and tick:
		for e: Thing in query(ppos, R * (1.7 + 0.2 * ember)):
			hurt(e, 1.2 * ember * R * R * 0.2)
	var lt := aura_lvl("Lightning Trail")
	if lt > 0:
		spark_cd -= dt
		if spark_cd <= 0.0 and pvel.length() > R * 0.5:
			spark_cd = 0.12
			sparks.append({"pos": ppos - pvel.normalized() * R * 0.9, "t": 2.5, "r": R * 0.7})
		if tick:
			for s in sparks:
				for e: Thing in query(s["pos"], s["r"]):
					hurt(e, 1.5 * lt * R * R * 0.2)


# =============================================================================
# Enemies
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


func hurt(e: Thing, dmg: float) -> void:
	if e.dead:
		return
	if e == boss:
		_boss_hurt(dmg)
		return
	e.hp -= dmg
	e.flash = 0.08
	if e.hp <= 0.0:
		kill(e)


func kill(e: Thing) -> void:
	e.dead = true
	stats["kills"] += 1
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


func _update_enemies(dt: float) -> void:
	for e in enemies:
		if e.dead:
			continue
		e.age += dt
		e.flash -= dt
		e.contact_cd -= dt
		e.cd -= dt
		if e == boss:
			_boss_ai(e, dt)
			continue
		if e.grabbed:
			continue
		var to := ppos - e.pos
		var d := to.length()
		var dir := to / maxf(d, 0.000001)
		var spd := float(e.d["spd"]) * e.r * (1.15 if e.elite else 1.0)
		spd = minf(spd, max_speed() * 0.95)
		var small := e.r < ABSORB_LIVE * R
		var desired := Vector2.ZERO
		var beh: String = e.d["beh"]
		match beh:
			"swarm", "chase":
				if small and e.d.get("flee", false) and d < R * 7.0:
					desired = -dir * spd
				else:
					desired = dir * spd
			"ranged":
				var atk: Dictionary = e.d["atk"]
				var pref := float(atk["rng"]) * R * 0.75
				if small and d < R * 5.0:
					desired = -dir * spd
				elif d > pref * 1.1:
					desired = dir * spd
				elif d < pref * 0.7:
					desired = -dir * spd * 0.8
				else:
					desired = dir.orthogonal() * spd * (0.6 if (e.get_instance_id() % 2) == 0 else -0.6)
				if e.cd <= 0.0 and d < float(atk["rng"]) * R * 1.3 and e.age > 1.0:
					e.cd = float(atk["cd"]) * rng.randf_range(0.8, 1.2)
					_enemy_shoot(e, atk, dir)
			"ram":
				match e.state:
					0:
						desired = dir * spd
						if d < R * 6.0 + e.r and e.cd <= 0.0:
							e.state = 1
							e.st = 0.7
					1:
						desired = Vector2.ZERO
						e.st -= dt
						e.flash = 0.05 if int(e.st * 12) % 2 == 0 else 0.0
						if e.st <= 0.0:
							e.state = 2
							e.st = 0.8
							e.vel = dir * maxf(spd * 4.0, max_speed() * 1.3)
					2:
						e.st -= dt
						desired = e.vel
						if e.st <= 0.0:
							e.state = 0
							e.cd = 2.5
		if beh == "ram" and e.state == 2:
			pass
		else:
			e.vel = e.vel.lerp(desired, 1.0 - exp(-4.0 * dt))
		e.pos += e.vel * dt
		e.rot = lerp_angle(e.rot, e.vel.angle(), 1.0 - exp(-6.0 * dt))
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
				e.pos += dv / dd * (md - dd) * 0.25


func _enemy_shoot(e: Thing, atk: Dictionary, dir: Vector2) -> void:
	var spd := float(atk["spd"]) * R
	var b := Bullet.new()
	b.pos = e.pos + dir * e.r
	b.vel = dir.rotated(rng.randf_range(-0.08, 0.08)) * spd
	b.life = float(atk["rng"]) * R * 1.8 / spd
	b.r = maxf(R * 0.07, e.r * 0.18)
	b.col = Color(1.0, 0.35, 0.25)
	b.hostile = true
	b.power = float(atk.get("pow", 1.0)) * clampf(e.r / R, 0.15, 3.0) * (1.5 if e.elite else 1.0)
	if atk.get("homing", false):
		b.turn = 1.5
	bullets.append(b)


func _update_bullets(dt: float) -> void:
	for b in bullets:
		b.life -= dt
		if b.turn > 0.0:
			var tgt := ppos
			if not b.hostile:
				if b.homing == null or b.homing.dead:
					b.homing = null
				else:
					tgt = b.homing.pos
			if b.hostile or b.homing != null:
				var sp := b.vel.length()
				var want := (tgt - b.pos).angle()
				b.vel = Vector2.from_angle(lerp_angle(b.vel.angle(), want, minf(1.0, b.turn * dt))) * sp
		b.pos += b.vel * dt
		if b.hostile:
			if not (game_over or victory) and b.pos.distance_to(ppos) < R + b.r:
				player_hit(b.power, b.pos)
				b.life = -1.0
		else:
			for e: Thing in query(b.pos, b.r):
				hurt(e, b.dmg)
				b.pierce -= 1
				if b.pierce <= 0:
					b.life = -1.0
					break
	bullets = bullets.filter(func(b): return b.life > 0.0)


func player_hit(power: float, src: Vector2) -> void:
	if iframes > 0.0 or game_over or victory:
		return
	var n := power * (1.0 - 0.08 * aura_lvl("Iron Core"))
	var k := floori(n)
	if rng.randf() < n - k:
		k += 1
	if k <= 0:
		return
	iframes = 0.4
	stats["hits"] += 1
	shake = maxf(shake, 0.2 + 0.1 * k)
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
	# the rival eats props too, and fights you for your shed pieces
	for p in props:
		if p.gone:
			continue
		var pd := p.pos.distance_to(e.pos)
		if p.r < e.r * 0.5 and pd < e.r + p.r * 0.5:
			e.hp += p.r * p.r * GROWTH
			p.gone = true
		elif p.loose >= 0.0 and pd < e.r * 3.5 and p.age > 0.6:
			p.pos += (e.pos - p.pos).normalized() * R * 2.0 * dt


func _boss_hurt(dmg: float) -> void:
	var e := boss
	var loss := dmg * 0.0015
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
			if p.loose < 0.0:
				p.gone = true
				stats["lost"] += 1
				var rad := p.r * 6.0
				ring(p.pos, rad, Color(1.0, 0.5, 0.2), 0.35)
				for e: Thing in query(p.pos, rad):
					hurt(e, 6.0 * p.r * p.r)


func _player_collisions() -> void:
	for p in props:
		if p.gone:
			continue
		var to := ppos - p.pos
		var d := to.length()
		if d > R * 6.0 + p.r:
			continue
		var edible := p.r < ABSORB * R or (p.loose >= 0.0 and p.r < LOOSE_ABSORB * R)
		if edible:
			if d < R + p.r * 0.5 and not (p.loose >= 0.0 and p.age < 0.35):
				absorb(p)
			elif d < pull_r + p.r and p.loose < 0.0:
				var f := 1.0 - d / (pull_r + p.r)
				p.pos += to / maxf(d, 0.000001) * R * (1.0 + 6.0 * f) * get_physics_process_delta_time()
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
			player_hit(1.4 * e.r / R * (1.5 if e.elite else 1.0), e.pos)
			hurt(e, 1.5 * R * R * (0.5 + pvel.length() / max_speed()))
			pvel += n * R * 4.0
			e.vel -= n * R * 3.0
		var overlap := R + e.r - d
		ppos += n * overlap * 0.4
		e.pos -= n * overlap * 0.6


func _eat_boss() -> void:
	victory = true
	var th := Thing.new()
	th.d = boss.d
	th.r = boss.r
	th.pos = boss.pos
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


func _spawn_theme(center: Vector2) -> bool:
	# A ready-made synergy kit (e.g. carts around a transformer) sized for now.
	var fits := []
	for th in Defs.THEMES:
		var cat: Dictionary = prop_by_name[th["items"][0]]
		var cr := float(cat["r"])
		if cr > 0.18 * R and cr < 0.48 * R:
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
		th.pos = center + Vector2.from_angle(TAU * k / float(theme["items"].size()) + rng.randf_range(-0.2, 0.2)) * (th.r * 2.5 + R)
		th.rot = rng.randf() * TAU
		props.append(th)
		k += 1
	return true


func spawn_prop_cluster(initial: bool) -> void:
	var hd := _view_half_diag()
	var dist: float
	var ang := rng.randf() * TAU
	if initial:
		dist = rng.randf_range(R * 4.0, hd * 1.6)
	else:
		if pvel.length() > R and rng.randf() < 0.6:
			ang = pvel.angle() + rng.randf_range(-1.0, 1.0)
		dist = rng.randf_range(hd * 1.05, hd * 1.7)
	var center := ppos + Vector2.from_angle(ang) * dist
	if rng.randf() < 0.2 and _spawn_theme(center):
		return
	var big := rng.randf() < 0.25
	var ratio: float
	if big:
		ratio = exp(rng.randf_range(log(0.7), log(3.0)))
	else:
		ratio = exp(lerpf(log(0.08), log(0.48), pow(rng.randf(), 1.3)))
	var base_s := R * ratio
	var n := 1 if big else rng.randi_range(4, 10)
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
		if th.pos.distance_to(ppos) < R * 2.0 + s:
			continue
		if s >= ABSORB * R and _overlaps_solid(th.pos, s):
			continue
		props.append(th)


func _overlaps_solid(at: Vector2, s: float) -> bool:
	for o in props:
		if not o.gone and o.r >= ABSORB * R * 0.8 and o.pos.distance_to(at) < (o.r + s) + R * 2.5:
			return true
	return false


func spawn_enemy(force_ratio: float = -1.0, at: Vector2 = Vector2.INF, kind: Dictionary = {}) -> Thing:
	var p := clampf(t / run_len, 0.0, 1.0)
	var ratio := force_ratio
	var elite := false
	if ratio < 0.0:
		var roll := rng.randf()
		if roll < 0.06 + 0.1 * p and _elite_count() < 2 + int(3 * p):
			ratio = rng.randf_range(1.4, 2.6)
			elite = true
		elif roll < 0.42 + 0.2 * p:
			ratio = exp(rng.randf_range(log(0.55), log(1.3)))
		else:
			ratio = exp(rng.randf_range(log(0.12), log(0.42)))
	var s := R * ratio
	var d: Dictionary = kind if not kind.is_empty() else _pick_def(enemy_sorted, s)
	var e := Thing.new()
	e.d = d
	e.enemy = true
	e.r = s
	e.elite = elite
	e.hp = float(d["hp"]) * s * s * 0.3 * (4.0 if elite else 1.0)
	e.max_hp = e.hp
	if at == Vector2.INF:
		var ang := rng.randf() * TAU
		if pvel.length() > R and rng.randf() < 0.4:
			ang = pvel.angle() + rng.randf_range(-0.8, 0.8)
		at = ppos + Vector2.from_angle(ang) * (_view_half_diag() * 1.05 + s)
	e.pos = at
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
	# props: keep a healthy buffet around the player
	var near := 0
	for p in props:
		if not p.gone and p.loose < 0.0:
			var d := p.pos.distance_to(ppos)
			if d > hd * 2.4:
				p.gone = true
			elif p.r < DUST * R:
				p.gone = true
				_dust(p)
			else:
				near += 1
	var want_props := 220
	var guard := 0
	while near < want_props and guard < 6:
		guard += 1
		spawn_prop_cluster(false)
		near += 5

	# enemies
	var p := clampf(t / run_len, 0.0, 1.0)
	var target_n := int(22 + 110 * p)
	if boss != null:
		target_n = int(target_n * 0.35)
	var alive := 0
	for e in enemies:
		if e.dead or e == boss:
			continue
		var d := e.pos.distance_to(ppos)
		if d > hd * 3.0:
			e.dead = true
			e.gone = true
		elif e.r < DUST * R:
			e.dead = true
			_dust(e)
		else:
			alive += 1
	spawn_acc += dt * (3.5 + 12.0 * p)
	while spawn_acc >= 1.0 and alive < target_n:
		spawn_acc -= 1.0
		spawn_enemy()
		alive += 1
	spawn_acc = minf(spawn_acc, 3.0)

	# hordes: a ring of one creature type closing in
	horde_t -= dt
	if horde_t <= 0.0 and boss == null:
		horde_t = rng.randf_range(35.0, 50.0)
		var ratio := rng.randf_range(0.2, 0.6)
		var kind := _pick_def(enemy_sorted, R * ratio)
		var n := 14 + int(16 * p)
		for i in n:
			var a := TAU * i / n
			spawn_enemy(ratio * rng.randf_range(0.85, 1.15), ppos + Vector2.from_angle(a) * hd * 1.1, kind)
		banner("HORDE", "%d %ss incoming" % [n, String(kind["name"]).to_lower()])


func _dust(th: Thing) -> void:
	core_area += th.r * th.r * 0.4 * growth_eff()
	integrity = minf(3.0, integrity + 0.01)
	if dust.size() < 300 and th.pos.distance_to(ppos) < view_r * 1.5:
		dust.append({"pos": th.pos, "t": 0.0})


func _update_strikes(dt: float) -> void:
	if tier >= 2:
		strike_cd -= dt
		if strike_cd <= 0.0:
			var p := clampf(t / run_len, 0.0, 1.0)
			strike_cd = rng.randf_range(4.0, 8.0) * (1.0 - 0.4 * p)
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
	print("T=%5.1f D=%s R=%.4f surf=%d bur=%d core=%d integ=%.2f imb=%.2f en=%d props=%d bul=%d fps=%d auras=%s syn=%s %s%s" % [
		t, fmt_len(R * 2.0), R, surface_count(), items.size() - surface_count(), core_count, integrity, imbalance,
		alive, props.size(), bullets.size(), Engine.get_frames_per_second(), str(auras), str(syn_active.keys()), str(stats),
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


func _draw() -> void:
	_draw_grid()
	_draw_props()
	_draw_strikes()
	_draw_enemies()
	_draw_player()
	_draw_fx()
	_draw_hud()


func _draw_grid() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen), Color(0.07, 0.08, 0.1))
	var span := view_r * 2.0
	var s := pow(10.0, floorf(log(span / 4.0) / log(10.0)))
	for level in 2:
		var step := s * (10.0 if level == 1 else 1.0)
		var n_lines := span / step
		var alpha := clampf(1.0 - n_lines / 45.0, 0.0, 1.0) * (0.10 if level == 0 else 0.16)
		if alpha <= 0.005:
			continue
		var col := Color(0.6, 0.7, 1.0, alpha)
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
	# scale bar
	var bar_m := s
	var px := bar_m * zoom
	var o := Vector2(screen.x - 30 - px, screen.y - 28)
	draw_line(o, o + Vector2(px, 0), Color(1, 1, 1, 0.6), 2.0)
	draw_line(o + Vector2(0, -5), o + Vector2(0, 5), Color(1, 1, 1, 0.6), 2.0)
	draw_line(o + Vector2(px, -5), o + Vector2(px, 5), Color(1, 1, 1, 0.6), 2.0)
	var lbl := fmt_len(bar_m)
	draw_string(font, o + Vector2(px * 0.5 - 20, -8), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.7))


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
		var grow := clampf(p.age / 0.3, 0.0, 1.0)
		sr *= grow
		var outline := Color(0.55, 1.0, 0.65, 0.9) if edible else Color(0.0, 0.0, 0.0, 0.7)
		var ow := maxf(1.0, sr * 0.08) if edible else maxf(1.5, sr * 0.12)
		if not edible:
			fill = fill.darkened(0.25)
		if p.loose >= 0.0:
			var blink := p.loose < 2.0 and int(p.loose * 8.0) % 2 == 0
			if blink:
				fill = Color(1, 0.4, 0.3)
			draw_arc(c, sr + 4.0, -PI * 0.5, -PI * 0.5 + TAU * (p.loose / LOOSE_TIME), 24, Color(1, 0.8, 0.3), 2.0)
		_shape(sh, c, sr, p.rot, fill, outline, ow)
		if p.wreck:
			draw_line(c + Vector2(-sr, -sr) * 0.5, c + Vector2(sr, sr) * 0.5, Color(0, 0, 0, 0.6), maxf(1.0, sr * 0.12))
			draw_line(c + Vector2(-sr, sr) * 0.5, c + Vector2(sr, -sr) * 0.5, Color(0, 0, 0, 0.6), maxf(1.0, sr * 0.12))
		_label(c, String(p.d["lbl"]), sr, Color(0, 0, 0, 0.75) if fill.get_luminance() > 0.45 else Color(1, 1, 1, 0.8))


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
		var sr := e.r * zoom
		var fill: Color = e.d["col"]
		if e.flash > 0.0:
			fill = fill.lerp(Color(1, 1, 1), 0.5)
		var edible := e.r < ABSORB_LIVE * R
		var outline := Color(0.55, 1.0, 0.65) if edible else Color(1.0, 0.25, 0.2)
		if e.elite:
			outline = Color(1.0, 0.8, 0.2)
			draw_arc(c, sr * 1.18, 0, TAU, 24, Color(1.0, 0.8, 0.2, 0.35), maxf(1.0, sr * 0.05))
		if e.d.get("fly", false):
			draw_circle(c + Vector2(sr * 0.3, sr * 0.5), sr * 0.9, Color(0, 0, 0, 0.25))
		# legs
		if sr > 3.0 and not e.d.get("fly", false):
			var wig := sin(e.age * 18.0) * 0.4
			for sgn: float in [-1.0, 1.0]:
				var la := e.rot + sgn * (PI * 0.5 + wig * sgn)
				draw_line(c, c + Vector2.from_angle(la) * sr * 1.25, fill.darkened(0.4), maxf(1.0, sr * 0.18))
		draw_circle(c, sr, fill)
		draw_arc(c, sr, 0, TAU, 20, outline, clampf(sr * 0.08, 1.5, 4.0))
		if sr > 4.0:
			var look := (ppos - e.pos).normalized()
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
	var c := w2s(e.pos)
	var sr := e.r * zoom
	draw_circle(c, sr * 1.6, Color(0.9, 0.2, 0.4, 0.08))
	for part in e.parts:
		var a: float = part["a"] + e.rot
		var ps: float = part["s"] * sr
		_shape(part["sh"], c + Vector2.from_angle(a) * (sr + ps * 0.2), ps, a, part["c"], Color(0, 0, 0, 0.6), 1.5)
	draw_circle(c, sr, Color(1, 1, 1) if e.flash > 0.0 else Color(0.35, 0.05, 0.15))
	draw_arc(c, sr, 0, TAU, 48, Color(1.0, 0.3, 0.5), 3.0)
	_label(c, "RIVAL", sr * 0.6, Color(1, 0.6, 0.7))


func _draw_player() -> void:
	var c := w2s(ppos)
	var sr := R * zoom
	if pull_r > 0.0:
		draw_arc(c, pull_r * zoom, 0, TAU, 64, Color(0.6, 0.5, 1.0, 0.12), 1.0)
	var ember := aura_lvl("Ember Halo")
	if ember > 0:
		var er := R * (1.7 + 0.2 * ember) * zoom
		draw_circle(c, er, Color(1.0, 0.45, 0.1, 0.03 + 0.008 * ember))
		draw_arc(c, er * (0.97 + 0.03 * sin(t * 9.0)), 0, TAU, 48, Color(1.0, 0.5, 0.15, 0.35), 2.0)
	for s in sparks:
		var sc := w2s(s["pos"])
		var a: float = s["t"] / 2.5
		draw_circle(sc, maxf(1.5, s["r"] * zoom * 0.25), Color(0.5, 0.9, 1.0, a * 0.7))
	if syn_active.has("blender"):
		var n: int = 2 + syn_active["blender"]["links"].size()
		for i in n:
			var ha := halberd_ang + TAU * i / n
			var hp := w2s(ppos + Vector2.from_angle(ha) * R * 2.1)
			var dirv := Vector2.from_angle(ha + PI * 0.5)
			draw_line(hp - dirv * sr * 0.45, hp + dirv * sr * 0.45, Color(0.7, 0.9, 1.0, 0.85), maxf(2.0, sr * 0.08))
			_shape(2, hp + dirv * sr * 0.45, sr * 0.16, ha + PI * 0.5, Color(0.7, 0.9, 1.0, 0.85), Color.TRANSPARENT, 0.0)
	# core
	var core_frac := clampf(core_area / maxf(R * R / GROWTH, 0.0001), 0.0, 1.0)
	var core_col := Color(0.22, 0.12, 0.32).lerp(Color(0.85, 0.35, 1.0), core_frac)
	if iframes > 0.0 and int(iframes * 20) % 2 == 0:
		core_col = Color(1, 0.4, 0.4)
	draw_circle(c, sr, core_col)
	# buried junk speckle
	var bi := 0
	for it in items:
		if it.surface:
			continue
		bi += 1
		if bi > 70:
			break
		var a := hull_ang + it.ang
		var rr := sr * (0.25 + 0.6 * fposmod(it.wob, 1.0))
		var col: Color = it.d["col"]
		draw_circle(c + Vector2.from_angle(a) * rr, maxf(1.0, it.r * zoom * 0.7), col.darkened(0.5))
	draw_circle(c, sr * 0.35 * (0.6 + core_frac), Color(1.0, 0.7, 1.0, 0.25 + 0.5 * core_frac))
	for i in 3:
		var a := hull_ang + TAU * i / 3.0
		draw_line(c + Vector2.from_angle(a) * sr * 0.4, c + Vector2.from_angle(a) * sr * 0.95, Color(1, 1, 1, 0.12), 2.0)
	draw_arc(c, sr, 0, TAU, 48, Color(0.75, 0.6, 1.0), 2.0)
	# synergy links
	for id in syn_active:
		var sa: Dictionary = syn_active[id]
		var cp := w2s(item_world(sa["cat"])[0])
		for o in sa["links"]:
			draw_line(cp, w2s(item_world(o)[0]), Color(0.5, 1.0, 1.0, 0.5), 2.0)
	# surface items
	for it in items:
		if not it.surface:
			continue
		var a := hull_ang + it.ang
		var p := w2s(ppos + Vector2.from_angle(a) * (R + it.r * 0.2))
		var isr := it.r * zoom
		var col: Color = it.d["col"]
		if it.creature:
			var wig := sin(t * 14.0 + it.wob) * 0.6
			for sgn: float in [-1.0, 1.0]:
				var la := a + sgn * (0.5 + wig * sgn)
				draw_line(p, p + Vector2.from_angle(la) * isr * 1.5, col.darkened(0.4), maxf(1.0, isr * 0.2))
		var w: Dictionary = it.d["w"]
		if w["t"] != "none" and isr > 2.0:
			draw_line(p, p + Vector2.from_angle(a) * isr * 1.35, Color(0.15, 0.15, 0.15), maxf(1.5, isr * 0.28))
		_shape(int(it.d.get("sh", 0)) if not it.creature else 0, p, isr, a, col, Color(0, 0, 0, 0.6), maxf(1.0, isr * 0.08))
		_label(p, String(it.d["lbl"]), isr, Color(0, 0, 0, 0.75) if col.get_luminance() > 0.45 else Color(1, 1, 1, 0.85))
	# heavy-side marker
	if imbalance > 0.04:
		var ha := hull_ang + com.angle()
		var hp := c + Vector2.from_angle(ha) * sr * 0.7
		draw_circle(hp, maxf(3.0, sr * imbalance * 0.6), Color(1.0, 0.8, 0.3, 0.7))
	if burst_t > 0.0:
		draw_arc(c, sr * 1.6, hull_ang, hull_ang + PI * 1.5, 32, Color(0.85, 0.65, 1.0, 0.6), 3.0)


func _draw_fx() -> void:
	for b in bullets:
		if not _on_screen(b.pos, b.r):
			continue
		var c := w2s(b.pos)
		var sr := maxf(b.r * zoom, 2.0 if b.hostile else 1.5)
		if b.hostile:
			draw_circle(c, sr + 1.5, Color(0.3, 0, 0))
		draw_circle(c, sr, b.col)
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
		var pos: Vector2 = f["pos"]
		if f.has("follow"):
			continue
		var k: float = 1.0 - f["t"] / f["tm"]
		draw_arc(w2s(pos), f["r"] * zoom * (0.3 + 0.7 * k), 0, TAU, 40, Color(f["col"], (1.0 - k) * f["col"].a), 3.0)
	for f in fx_rings:
		if f.has("follow"):
			var it: HullItem = f["follow"]
			if it.surface and items.has(it):
				draw_circle(w2s(item_world(it)[0]), f["r"] * zoom, f["col"] * Color(1, 1, 1, 0.3))
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
	var tm := "%02d:%02d" % [int(t) / 60, int(t) % 60]
	_hud_text(Vector2(16, 30), tm, 26, Color(1, 1, 1))
	_hud_text(Vector2(100, 30), "/ %02d:%02d" % [int(run_len) / 60, int(run_len) % 60] if remain > 0 else "RIVAL ARRIVED", 16, Color(0.7, 0.7, 0.8))
	_hud_text(Vector2(16, 62), fmt_len(R * 2.0), 30, Color(0.9, 0.8, 1.0))
	_hud_text(Vector2(16, 84), TIER_NAMES[tier], 14, Color(0.7, 0.6, 1.0))
	var sc := surface_count()
	_hud_text(Vector2(16, 106), "hull %d live · %d buried · core %d" % [sc, items.size() - sc, core_count], 14, Color(0.8, 0.8, 0.85))
	# integrity
	for i in 3:
		var filled := integrity >= i + 1
		var part := clampf(integrity - i, 0.0, 1.0)
		var c := Vector2(24 + i * 22, 124)
		draw_circle(c, 8, Color(0.2, 0.2, 0.25))
		if filled or part > 0.0:
			draw_circle(c, 8 * maxf(part, 0.3), Color(1.0, 0.4, 0.6) if filled else Color(0.6, 0.3, 0.4))
	_hud_text(Vector2(92, 130), "core integrity" + ("  — NO ARMOR!" if items.is_empty() else ""), 12, Color(1, 0.6, 0.7) if items.is_empty() else Color(0.7, 0.7, 0.8))
	# collapse progress
	if collapse_idx < COLLAPSES.size():
		var prev: float = COLLAPSES[collapse_idx - 1] if collapse_idx > 0 else R0
		var nxt: float = COLLAPSES[collapse_idx]
		var f := clampf(log(R / prev) / log(nxt / prev), 0.0, 1.0)
		draw_rect(Rect2(16, 142, 200, 8), Color(0.2, 0.2, 0.25))
		draw_rect(Rect2(16, 142, 200 * f, 8), Color(0.8, 0.5, 1.0))
		_hud_text(Vector2(222, 151), "collapse @ " + fmt_len(nxt * 2.0), 12, Color(0.8, 0.7, 1.0))
	# imbalance / burst
	_hud_text(Vector2(16, 172), "lopsided %d%%" % int(imbalance / 0.6 * 100.0), 12, Color(1.0, 0.85, 0.4) if imbalance > 0.06 else Color(0.6, 0.6, 0.65))
	var bc := "SPIN BURST ready" if burst_cd <= 0.0 else "spin burst %.0fs" % burst_cd
	_hud_text(Vector2(120, 172), bc, 12, Color(0.85, 0.7, 1.0) if burst_cd <= 0.0 else Color(0.5, 0.5, 0.55))
	# right column: auras + synergies
	var y := 30.0
	var x := screen.x - 300
	if not auras.is_empty():
		_hud_text(Vector2(x, y), "CORE AURAS", 13, Color(0.8, 0.6, 1.0))
		y += 18
		for nm in auras:
			_hud_text(Vector2(x, y), "%s %s" % [nm, _roman(int(auras[nm]))], 13, Color(1, 1, 1))
			y += 16
		y += 6
	if not syn_active.is_empty():
		_hud_text(Vector2(x, y), "HULL SYNERGIES", 13, Color(0.5, 1.0, 1.0))
		y += 18
		for id in syn_active:
			_hud_text(Vector2(x, y), String(syn_active[id]["def"]["name"]), 13, Color(1, 1, 1))
			y += 16
	# boss bar
	if boss != null and not boss.dead:
		var bw := 500.0
		var bx := (screen.x - bw) * 0.5
		var ratio := boss.r / R
		_hud_text(Vector2(bx, screen.y - 58), "RIVAL SINGULARITY  %s  (%.2fx your size — eat it below 0.80x)" % [fmt_len(boss.r * 2.0), ratio], 14, Color(1, 0.5, 0.6))
		draw_rect(Rect2(bx, screen.y - 48, bw, 10), Color(0.2, 0.1, 0.12))
		draw_rect(Rect2(bx, screen.y - 48, bw * clampf(ratio / 2.0, 0, 1), 10), Color(1, 0.3, 0.45))
		draw_line(Vector2(bx + bw * 0.4, screen.y - 52), Vector2(bx + bw * 0.4, screen.y - 34), Color(0.5, 1, 0.6), 2.0)
	# banners
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
		_hud_text(Vector2(16, screen.y - 14), "WASD roll · Q/E nudge spin · SPACE spin-burst · F12 screenshot", 12, Color(0.6, 0.6, 0.65))
	else:
		_hud_text(Vector2(16, screen.y - 14), "AUTOPILOT", 12, Color(0.6, 0.9, 0.6))
