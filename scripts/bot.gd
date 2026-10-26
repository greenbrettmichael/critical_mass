class_name Bot
extends RefCounted
## Autopilot used for simulated playtests: greedily eats the best-value edible
## thing nearby while steering away from threats, walls and hostile fire.

var target = null
var retarget := 0.0
var wander := Vector2.RIGHT
var stuck_t := 0.0
var last_pos := Vector2.ZERO
var escape_t := 0.0
var t := 0.0
var rng := RandomNumberGenerator.new()
var focus := ""   # optional branch tag the autopilot tries to build around


func pick(_g, options: Array) -> int:
	if focus != "":
		for i in options.size():
			if options[i]["tag"] == focus:
				return i
	return rng.randi() % options.size()


func _diet_weight(d: Dictionary) -> float:
	if focus == "":
		return 1.0
	return 4.0 if d.get("tags", []).has(focus) else 0.5


func think(g, dt: float) -> Dictionary:
	t += dt
	retarget -= dt
	var R: float = g.R
	var pos: Vector2 = g.ppos
	var out := {"move": Vector2.ZERO, "burst": false, "spin": 0.0, "lurch": false}
	if g.game_over or g.victory:
		return out

	if target != null and (target.gone or target.dead):
		target = null
	if retarget <= 0.0 or target == null:
		retarget = 0.35
		target = _pick_target(g)

	var seek := Vector2.ZERO
	if target != null:
		seek = (target.pos - pos).normalized()
	else:
		if fmod(t, 3.0) < dt:
			wander = Vector2.from_angle(rng.randf() * TAU)
		seek = wander

	var avoid := Vector2.ZERO
	var threats := 0
	for e in g.enemies:
		if e.dead:
			continue
		var to: Vector2 = pos - e.pos
		var d: float = to.length()
		if e == g.boss:
			continue
		if e.r < g.ABSORB_LIVE * R:
			continue
		var gap: float = (d - e.r - R) / R
		if gap < 5.0:
			threats += 1
			var w: float = (e.r / R) * 1.6 / pow(maxf(gap, 0.2) + 0.5, 2.0)
			avoid += to / maxf(d, 0.0001) * w
	for b in g.bullets:
		if not b.hostile:
			continue
		var to: Vector2 = pos - b.pos
		var d: float = to.length()
		if d < R * 4.0 and b.vel.dot(to) > 0.0:
			var side: Vector2 = b.vel.normalized().orthogonal()
			if side.dot(to) < 0.0:
				side = -side
			avoid += side * 1.2 / maxf(d / R, 0.5)
	for p in g.props:
		if p.gone or p.loose >= 0.0 or p.wreck or p.r < g.ABSORB * R:
			continue
		var to: Vector2 = pos - p.pos
		var d: float = to.length()
		var gap: float = (d - p.r * 0.85 - R) / R
		if gap < 1.5:
			avoid += to / maxf(d, 0.0001) * 0.6 / maxf(gap + 0.3, 0.15)
	# floor hazards: steer around anything that strips pieces, mildly around slow ground
	for h in g.terrain:
		var td: Dictionary = Defs.TERRAIN[h["type"]]
		var k: float = g.terrain_strength(h["r"])
		if k <= 0.0:
			continue
		var to: Vector2 = pos - h["pos"]
		var d: float = to.length()
		var gap: float = (d - float(h["r"]) - R) / R
		if gap > 2.0:
			continue
		var harm: float = 1.6 if (td.has("drain") or td.has("corrode")) else (0.5 if float(td.get("slow", 1.0)) < 0.6 else 0.15)
		avoid += to / maxf(d, 0.0001) * harm * k / maxf(gap + 0.6, 0.25)
	for s in g.strikes:
		var to: Vector2 = pos - s["pos"]
		if to.length() < s["r"] + R * 1.5:
			avoid += to.normalized() * 4.0

	# apex predators: stay well outside their sight unless we've outgrown them
	for e in g.apexes:
		if e.dead or e.r < g.ABSORB_LIVE * R:
			continue
		var to: Vector2 = pos - e.pos
		var d: float = to.length()
		var sight: float = e.r * 3.5 + R * 6.0
		if d < sight * 1.3:
			threats += 2
			avoid += to / maxf(d, 0.0001) * 5.0 * (sight * 1.3 - d) / sight

	# the rival ooze: hunt it when it's smaller, give it room when even, flee when bigger
	var boss = g.boss
	if boss != null and not boss.dead:
		var to: Vector2 = boss.pos - pos
		var d: float = to.length()
		var rel: float = boss.r / R
		if rel < 0.8 and d < R * 12.0 + boss.r:
			seek = to.normalized() * 2.0
		elif rel > 1.2:
			var w: float = clampf((R * 9.0 + boss.r - d) / (R * 4.0), 0.0, 2.0)
			avoid += -to.normalized() * 3.0 * w
			threats += 2 if w > 0.0 else 0
		elif d < R * 3.0 + boss.r:
			avoid += -to.normalized() * 0.8
	# the goal: once the planet core is edible, go eat it
	var core = g.core
	if core != null and not core.gone and core.r < g.ABSORB * R:
		seek = (core.pos - pos).normalized() * 2.5

	var mv := seek + avoid
	if escape_t > 0.0:
		escape_t -= dt
		mv = wander
	else:
		stuck_t += dt
		if stuck_t > 1.0:
			if pos.distance_to(last_pos) < R * 0.6:
				escape_t = 0.9
				# back out along the open side: away from the nearby walls' centroid
				var push := Vector2.ZERO
				for p in g.props:
					if p.gone or p.r < g.ABSORB * R or p.wreck or p.loose >= 0.0:
						continue
					var to: Vector2 = pos - p.pos
					if to.length() < p.r + R * 3.0:
						push += to.normalized()
				wander = push.normalized() if push.length() > 0.1 else Vector2.from_angle(rng.randf() * TAU)
				wander = wander.rotated(rng.randf_range(-0.6, 0.6))
				target = null
			stuck_t = 0.0
			last_pos = pos
	out["move"] = mv.normalized()
	if threats >= 4:
		out["burst"] = true
	# lurch at the current target once it's within reach, or lurch to flee a hunting apex
	if g.lurch_state == 0 and g.lurch_cd <= 0.0:
		if target != null and not target.gone and pos.distance_to(target.pos) - target.r - R < g.lurch_range() and avoid.length() < 1.5:
			out["lurch"] = true
		for e in g.apexes:
			if not e.dead and e.state == 1 and pos.distance_to(e.pos) - e.r < R * 8.0:
				out["lurch"] = true
	return out


func _pick_target(g):
	var R: float = g.R
	var pos: Vector2 = g.ppos
	var best = null
	var bs := 0.0
	for p in g.props:
		if p.gone:
			continue
		var edible: bool = p.r < g.ABSORB * R or (p.loose >= 0.0 and p.r < g.LOOSE_ABSORB * R)
		if not edible:
			continue
		var d := pos.distance_to(p.pos) / R
		if d > 14.0:
			continue
		var v: float = pow(p.r / R, 2.0) * (3.0 if p.loose >= 0.0 else 1.0) * _diet_weight(p.d)
		for tg in p.d.get("tags", []):
			if tg in ["transformer", "cart", "knight", "mower", "crane", "sushi", "police"]:
				v *= 2.0
				break
		var s := v / pow(d + 2.0, 1.6)
		if s > bs:
			bs = s
			best = p
	for e in g.enemies:
		if e.dead or e.r >= g.ABSORB_LIVE * R:
			continue
		var d := pos.distance_to(e.pos) / R
		if d > 10.0:
			continue
		var s := pow(e.r / R, 2.0) * _diet_weight(e.d) / pow(d + 2.0, 1.6)
		if s > bs:
			bs = s
			best = e
	return best
