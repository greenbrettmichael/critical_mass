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


func think(g, dt: float) -> Dictionary:
	t += dt
	retarget -= dt
	var R: float = g.R
	var pos: Vector2 = g.ppos
	var out := {"move": Vector2.ZERO, "burst": false, "spin": 0.0}
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
			wander = Vector2.from_angle(randf() * TAU)
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
	for s in g.strikes:
		var to: Vector2 = pos - s["pos"]
		if to.length() < s["r"] + R * 1.5:
			avoid += to.normalized() * 4.0

	var boss = g.boss
	if boss != null and not boss.dead:
		var to: Vector2 = boss.pos - pos
		var d: float = to.length()
		if boss.r < R * 0.8:
			seek = to.normalized() * 2.0
		else:
			# kite: orbit at a distance and let turrets/chunks do the work
			var orbit: Vector2 = to.normalized().orthogonal()
			var desired: float = R * 6.0 + boss.r
			var radial: Vector2 = -to.normalized() * clampf((desired - d) / (R * 2.0), -1.0, 1.5)
			seek = seek * 0.6 + orbit * 0.7 + radial * 1.2
		if d < R * 10.0 + boss.r:
			out["burst"] = true

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
				wander = push.normalized() if push.length() > 0.1 else Vector2.from_angle(randf() * TAU)
				wander = wander.rotated(randf_range(-0.6, 0.6))
				target = null
			stuck_t = 0.0
			last_pos = pos
	out["move"] = mv.normalized()
	if threats >= 4:
		out["burst"] = true
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
		var v: float = pow(p.r / R, 2.0) * (3.0 if p.loose >= 0.0 else 1.0)
		if p.d.get("w", {}).get("t", "none") != "none":
			v *= 1.5
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
		var s := pow(e.r / R, 2.0) / pow(d + 2.0, 1.6)
		if s > bs:
			bs = s
			best = e
	return best
