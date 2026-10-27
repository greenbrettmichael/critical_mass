class_name Net
extends RefCounted
## Online play. One player hosts: their game runs the whole simulation. Everyone
## else sends inputs and draws the snapshots the host streams back, filtered to
## what their own ooze can see (the visibility floor doubles as interest
## management: things beneath your notice are never sent).

const PORT := 7777
const SNAP_EVERY := 3        # physics frames between snapshots (20 Hz at 60 fps)
const VIEW_PAD := 1.35       # send things this far past the screen's half-diagonal

# --- host: def registry, so snapshots carry small ints instead of dictionaries
var def_ids := {}            # def Dictionary -> id
var defs := []               # id -> slim def
var new_defs := []           # [id, slim def] not yet broadcast
var next_nid := 1

# --- client
var cdefs := {}              # id -> def
var things := {}             # nid -> Thing (props and enemies), kept for smoothing
var snap_t := 0.0            # time since the last snapshot arrived
var snap_dt := 0.05
var got_snap := false
var await_serial := -1       # fork already answered locally, waiting for the host to catch up
var terrain_keys: Array = Defs.TERRAIN.keys()


# =============================================================================
# Host side
# =============================================================================

func did(d: Dictionary) -> int:
	var k: int = def_ids.get(d, -1)
	if k < 0:
		k = defs.size()
		def_ids[d] = k
		var slim := {}
		for key in ["name", "lbl", "col", "sh", "tags", "fly", "beh"]:
			if d.has(key):
				slim[key] = d[key]
		defs.append(slim)
		new_defs.append([k, slim])
	return k


func _tdid(th) -> int:
	if th.did < 0:
		th.did = did(th.d)
	return th.did


func _nid(th) -> int:
	if th.nid == 0:
		th.nid = next_nid
		next_nid += 1
	return th.nid


func encode(g, o) -> PackedByteArray:
	# everything ooze `o` needs to draw its screen and HUD this frame
	var hd: float = g._hd_of(o) * VIEW_PAD
	var R: float = o.R
	var seen_min: float = g.SEE_MIN * R
	var c: Vector2 = o.ppos

	var pi := PackedInt32Array()
	var pf := PackedFloat32Array()
	for p in g.props:
		if p.gone:
			continue
		var is_core: bool = p == g.core
		if not is_core and (p.r < seen_min or p.pos.distance_to(c) > hd + p.r):
			continue
		var fl := (1 if p.wreck else 0) | (2 if p.wall else 0) | (4 if p.fixed else 0) | (8 if is_core else 0) | (16 if p.was_enemy else 0)
		pi.append_array([_nid(p), _tdid(p), fl])
		pf.append_array([p.pos.x, p.pos.y, p.r, p.rot, p.loose, p.age, p.vel.x, p.vel.y])

	var ei := PackedInt32Array()
	var ef := PackedFloat32Array()
	var feel := []
	for e in g.enemies:
		if e.dead or e.oz != null:
			continue
		var always: bool = e.apex or e.rival
		if not always and (e.r < seen_min or e.pos.distance_to(c) > hd + e.r):
			continue
		var fl := (1 if e.apex else 0) | (2 if e.rival else 0) | (4 if e.elite else 0)
		ei.append_array([_nid(e), _tdid(e), fl, e.state, e.slot])
		ef.append_array([e.pos.x, e.pos.y, e.r, e.rot, e.vel.x, e.vel.y, e.flash, e.stun, e.burn,
			clampf(e.hp / maxf(e.max_hp, 1e-9), 0.0, 1.0), e.age])
		if e.rival and e.pos.distance_to(c) < hd + e.r * 4.0:
			feel.append([e.nid, _feelers(e.feelers)])

	var bf := PackedFloat32Array()
	for b in g.bullets:
		if b.pos.distance_to(c) > hd or b.r < seen_min * 0.2 and not b.hostile:
			continue
		bf.append_array([b.pos.x, b.pos.y, b.vel.x, b.vel.y, b.r, b.col.r, b.col.g, b.col.b, 1.0 if b.hostile else 0.0])

	var tf := PackedFloat32Array()
	for h in g.terrain:
		var hr: float = h["r"]
		if (h["pos"] as Vector2).distance_to(c) > hd + hr * 1.2:
			continue
		var dir: Vector2 = h["dir"]
		tf.append_array([terrain_keys.find(h["type"]), h["pos"].x, h["pos"].y, hr, dir.x, dir.y, h["seed"]])

	var oz := []
	for x in g.oozes:
		var near: bool = x == o or x.ppos.distance_to(c) < hd + x.R * 4.0
		oz.append(_ooze(x, x == o, near))

	var fx := []
	for f in g.fx_rings:
		if (f["pos"] as Vector2).distance_to(c) < hd + f["r"]:
			fx.append(["r", f["pos"], f["r"], f["col"], f["t"], f["tm"]])
	for f in g.fx_texts:
		if (f["pos"] as Vector2).distance_to(c) < hd:
			fx.append(["t", f["pos"], f["s"], f["col"], f["t"], f["size"]])
	for f in g.fx_bolts:
		if (f["pts"][0] as Vector2).distance_to(c) < hd * 1.5:
			fx.append(["b", f["pts"], f["col"], f["t"]])
	for f in g.fx_beams:
		if (f["a"] as Vector2).distance_to(c) < hd * 1.5:
			fx.append(["m", f["a"], f["b"], f["w"], f["col"], f["t"]])
	for f in g.fx_cones:
		if (f["pos"] as Vector2).distance_to(c) < hd * 1.5:
			fx.append(["c", f["pos"], f["a"], f["half"], f["len"], f["col"], f["t"]])
	var strikes := []
	var patches := []
	for x in g.oozes:
		for s in x.strikes:
			if (s["pos"] as Vector2).distance_to(c) < hd + s["r"]:
				strikes.append([s["pos"], s["r"], s["t"], s["tm"]])
		for pt in x.patches:
			if (pt["pos"] as Vector2).distance_to(c) < hd + pt["r"]:
				patches.append([pt["pos"], pt["r"], pt["t"]])

	var mine := {
		"integ": o.integrity, "maxi": o.max_integrity, "ess": o.essence, "pend": o.pending,
		"serial": o.pick_serial, "zone": o.zone, "zopen": o.zone_open, "wall": o.wall_r, "arena": o.arena_r,
		"ton": o.terrain_on, "bcd": o.burst_cd, "col": o.collapse_idx, "cc": o.core_count,
		"ni": o.items.size(), "ban": o.banners, "shake": o.shake, "hv": o.hurt_vignette,
		"resp": o.respawn_t, "killer": o.killer, "win": o.victory, "over": o.game_over,
		"lcd": o.lurch_cd, "stats": o.stats,
	}
	var slots := []
	for sl in g.rival_slots:
		slots.append([sl["slot"], sl["t"]])
	var snap := [g.t, g.match_over, g.rival_count, slots, mine, oz, pi, pf, ei, ef, feel, bf, tf, fx, strikes, patches]
	var raw := var_to_bytes(snap)
	var out := PackedByteArray()
	out.resize(4)
	out.encode_u32(0, raw.size())
	out.append_array(raw.compress(FileAccess.COMPRESSION_ZSTD))
	return out


func _feelers(arr: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for f in arr:
		var tip: Vector2 = f["tip"]
		out.append_array([tip.x, tip.y, 1.0 if f["latched"] else 0.0, 1.0 if f["target"] != null else 0.0])
	return out


func _ooze(x, own: bool, near: bool) -> Array:
	# public body state for everyone; hull detail only when it's on screen
	var base := [x.id, x.name, x.ppos, x.pvel, x.R, x.hull_ang, x.down, x.iframes, x.respawn_t, x.guard]
	if not near:
		return base
	var ii := PackedInt32Array()
	var fi := PackedFloat32Array()
	var buried := 0
	var index := {}
	for it in x.items:
		if not it.surface:
			buried += 1
			if buried > (30 if own else 10):
				continue
		index[it] = ii.size() / 2
		ii.append_array([_tdid(it), (1 if it.surface else 0) | (2 if it.creature else 0)])
		fi.append_array([it.r, it.ang, it.wob])
	var syn := []
	for id in x.syn_active:
		var sa: Dictionary = x.syn_active[id]
		var links := []
		for l in sa["links"]:
			links.append(index.get(l, -1))
		syn.append([id, index.get(sa["cat"], -1), links])
	var crit := PackedVector2Array()
	for cr in x.critters:
		crit.append(cr["pos"])
	var sparks := []
	for s in x.sparks:
		sparks.append([s["pos"], s["r"], s["t"]])
	base.append_array([ii, fi, syn, x.nodes.keys(), x.ranks, x.focus_local, _feelers(x.feelers),
		x.lurch_state, x.lurch_tip, x.burst_t, x.imbalance, x.com, x.core_area,
		x.halberd_ang, x.blade_ang, crit, sparks])
	return base


# =============================================================================
# Client side
# =============================================================================

func apply(g, bytes: PackedByteArray) -> void:
	var size := bytes.decode_u32(0)
	var raw := bytes.slice(4).decompress(size, FileAccess.COMPRESSION_ZSTD)
	var snap = bytes_to_var(raw)
	if typeof(snap) != TYPE_ARRAY:
		return
	snap_dt = clampf(snap_t if got_snap else 0.05, 0.016, 0.25)
	snap_t = 0.0
	got_snap = true
	g.t = snap[0]
	g.match_over = snap[1]
	g.rival_count = snap[2]
	g.rival_slots.clear()
	for sl in snap[3]:
		g.rival_slots.append({"slot": sl[0], "t": sl[1]})
	_apply_mine(g, snap[4])
	for row in snap[5]:
		_apply_ooze(g, row)
	_apply_props(g, snap[6], snap[7])
	_apply_enemies(g, snap[8], snap[9], snap[10])
	g.bullets.clear()
	var bf: PackedFloat32Array = snap[11]
	for i in range(0, bf.size(), 9):
		var b = g.make_bullet()
		b.pos = Vector2(bf[i], bf[i + 1])
		b.vel = Vector2(bf[i + 2], bf[i + 3])
		b.r = bf[i + 4]
		b.col = Color(bf[i + 5], bf[i + 6], bf[i + 7])
		b.hostile = bf[i + 8] > 0.5
		b.life = 1.0
		g.bullets.append(b)
	g.terrain.clear()
	var tf: PackedFloat32Array = snap[12]
	for i in range(0, tf.size(), 7):
		g.terrain.append({"type": terrain_keys[int(tf[i])], "pos": Vector2(tf[i + 1], tf[i + 2]), "r": tf[i + 3],
			"dir": Vector2(tf[i + 4], tf[i + 5]), "seed": tf[i + 6], "dyn": false})
	g.fx_rings.clear()
	g.fx_texts.clear()
	g.fx_bolts.clear()
	g.fx_beams.clear()
	g.fx_cones.clear()
	for f in snap[13]:
		match f[0]:
			"r": g.fx_rings.append({"pos": f[1], "r": f[2], "col": f[3], "t": f[4], "tm": f[5]})
			"t": g.fx_texts.append({"pos": f[1], "s": f[2], "col": f[3], "t": f[4], "size": f[5]})
			"b": g.fx_bolts.append({"pts": f[1], "col": f[2], "t": f[3]})
			"m": g.fx_beams.append({"a": f[1], "b": f[2], "w": f[3], "col": f[4], "t": f[5]})
			"c": g.fx_cones.append({"pos": f[1], "a": f[2], "half": f[3], "len": f[4], "col": f[5], "t": f[6]})
	for x in g.oozes:
		x.strikes.clear()
		x.patches.clear()
	for s in snap[14]:
		g.view.strikes.append({"pos": s[0], "r": s[1], "t": s[2], "tm": s[3]})
	for pt in snap[15]:
		g.view.patches.append({"pos": pt[0], "r": pt[1], "t": pt[2]})


func _apply_mine(g, m: Dictionary) -> void:
	var o = g.view
	o.integrity = m["integ"]
	o.max_integrity = m["maxi"]
	o.essence = m["ess"]
	o.pick_serial = m["serial"]
	o.pending = m["pend"]
	if await_serial >= 0:
		if o.pick_serial >= await_serial:
			await_serial = -1
		elif not o.pending.is_empty():
			o.pending = o.pending.slice(1)
	if o.zone != int(m["zone"]) or o.zone_def.is_empty():
		o.zone = m["zone"]
		o.zone_def = Defs.ZONES[o.zone]
	o.zone_open = m["zopen"]
	o.wall_r = m["wall"]
	o.arena_r = m["arena"]
	o.terrain_on = m["ton"]
	o.burst_cd = m["bcd"]
	o.collapse_idx = m["col"]
	o.core_count = m["cc"]
	o.net_items = m["ni"]
	o.banners = m["ban"]
	o.shake = maxf(o.shake, m["shake"])
	o.hurt_vignette = maxf(o.hurt_vignette, m["hv"])
	o.respawn_t = m["resp"]
	o.killer = m["killer"]
	o.victory = m["win"]
	o.game_over = m["over"]
	o.lurch_cd = m["lcd"]
	o.stats = m["stats"]


func _apply_ooze(g, row: Array) -> void:
	var id: int = row[0]
	if id >= g.oozes.size():
		return
	var x = g.oozes[id]
	x.name = row[1]
	_steer(x, row[2], row[3])
	x.R = row[4]
	x.hull_ang = row[5]
	x.down = row[6]
	x.iframes = row[7]
	x.respawn_t = row[8]
	x.guard = row[9]
	if x.avatar != null:
		x.avatar.r = x.R
		x.avatar.dead = x.down
		x.avatar.tag_name = x.name
		x.avatar.d["lbl"] = x.name
	if row.size() <= 10:
		x.items.clear()
		x.feelers.clear()
		return
	var ii: PackedInt32Array = row[10]
	var fi: PackedFloat32Array = row[11]
	x.items.clear()
	for k in range(ii.size() / 2):
		var it = g.make_item()
		it.d = def_of(ii[k * 2])
		it.surface = (ii[k * 2 + 1] & 1) != 0
		it.creature = (ii[k * 2 + 1] & 2) != 0
		it.r = fi[k * 3]
		it.ang = fi[k * 3 + 1]
		it.wob = fi[k * 3 + 2]
		x.items.append(it)
	x.syn_active.clear()
	for s in row[12]:
		var cat: int = s[1]
		if cat < 0 or cat >= x.items.size():
			continue
		var links := []
		for l in s[2]:
			if l >= 0 and l < x.items.size():
				links.append(x.items[l])
		var sdef := {}
		for sd in Defs.SYNERGIES:
			if sd["id"] == s[0]:
				sdef = sd
		x.syn_active[s[0]] = {"cat": x.items[cat], "links": links, "def": sdef}
	x.nodes.clear()
	for n in row[13]:
		x.nodes[n] = true
	x.ranks = row[14]
	x.focus_local = row[15]
	var ff: PackedFloat32Array = row[16]
	x.feelers.clear()
	for i in range(0, ff.size(), 4):
		x.feelers.append({"tip": Vector2(ff[i], ff[i + 1]), "latched": ff[i + 2] > 0.5, "target": true if ff[i + 3] > 0.5 else null})
	x.lurch_state = row[17]
	x.lurch_tip = row[18]
	x.burst_t = row[19]
	x.imbalance = row[20]
	x.com = row[21]
	x.core_area = row[22]
	x.halberd_ang = row[23]
	x.blade_ang = row[24]
	x.critters.clear()
	for p in row[25]:
		x.critters.append({"pos": p})
	x.sparks.clear()
	for s in row[26]:
		x.sparks.append({"pos": s[0], "r": s[1], "t": s[2]})


func _steer(x, pos: Vector2, vel: Vector2) -> void:
	# snap if it's far off (respawn, first sight), otherwise glide toward it
	if x.net_to == Vector2.INF or x.ppos.distance_to(pos) > maxf(x.R, 1e-4) * 6.0:
		x.ppos = pos
	x.net_to = pos
	x.pvel = vel


func _apply_props(g, pi: PackedInt32Array, pf: PackedFloat32Array) -> void:
	var keep: Array = []
	g.core = null
	for k in range(pi.size() / 3):
		var nid := pi[k * 3]
		var th = things.get(nid)
		if th == null:
			th = g.make_thing()
			th.nid = nid
			things[nid] = th
			th.pos = Vector2(pf[k * 8], pf[k * 8 + 1])
		th.d = def_of(pi[k * 3 + 1])
		var fl := pi[k * 3 + 2]
		th.wreck = (fl & 1) != 0
		th.wall = (fl & 2) != 0
		th.fixed = (fl & 4) != 0
		th.was_enemy = (fl & 16) != 0
		th.net_to = Vector2(pf[k * 8], pf[k * 8 + 1])
		th.r = pf[k * 8 + 2]
		th.rot = pf[k * 8 + 3]
		th.loose = pf[k * 8 + 4]
		th.age = pf[k * 8 + 5]
		th.vel = Vector2(pf[k * 8 + 6], pf[k * 8 + 7])
		th.gone = false
		th.seen = true
		if (fl & 8) != 0:
			g.core = th
		keep.append(th)
	g.props.assign(keep)


func _apply_enemies(g, ei: PackedInt32Array, ef: PackedFloat32Array, feel: Array) -> void:
	var keep: Array = []
	g.apexes.clear()
	g.rivals.clear()
	for k in range(ei.size() / 5):
		var nid := ei[k * 5]
		var e = things.get(nid)
		var o := k * 11
		if e == null:
			e = g.make_thing()
			e.nid = nid
			things[nid] = e
			e.pos = Vector2(ef[o], ef[o + 1])
		e.d = def_of(ei[k * 5 + 1])
		e.enemy = true
		var fl := ei[k * 5 + 2]
		e.apex = (fl & 1) != 0
		e.elite = (fl & 4) != 0
		e.state = ei[k * 5 + 3]
		if (fl & 2) != 0 and not e.rival:
			e.rival = true
			g.dress_rival(e, ei[k * 5 + 4])
		e.net_to = Vector2(ef[o], ef[o + 1])
		e.r = ef[o + 2]
		e.rot = ef[o + 3]
		e.vel = Vector2(ef[o + 4], ef[o + 5])
		e.flash = ef[o + 6]
		e.stun = ef[o + 7]
		e.burn = ef[o + 8]
		e.max_hp = 1.0
		e.hp = ef[o + 9]
		e.age = ef[o + 10]
		e.dead = false
		e.seen = true
		keep.append(e)
		if e.apex:
			g.apexes.append(e)
		if e.rival:
			g.rivals.append(e)
	for row in feel:
		var e = things.get(row[0])
		if e == null:
			continue
		var ff: PackedFloat32Array = row[1]
		e.feelers.clear()
		for i in range(0, ff.size(), 4):
			e.feelers.append({"tip": Vector2(ff[i], ff[i + 1]), "latched": ff[i + 2] > 0.5, "target": true if ff[i + 3] > 0.5 else null})
	# other players are drawn as oozes but still count as big live things for the HUD and autopilot
	for x in g.oozes:
		if x.avatar != null and x != g.view:
			keep.append(x.avatar)
	g.enemies.assign(keep)
	# forget things that dropped out of the snapshot
	for nid in things.keys():
		var th = things[nid]
		if not th.seen:
			things.erase(nid)
		th.seen = false


func def_of(id: int) -> Dictionary:
	return cdefs.get(id, {"name": "?", "lbl": "", "col": Color(0.5, 0.5, 0.5), "sh": 0, "tags": []})


func smooth(g, dt: float) -> void:
	# glide everything between 20 Hz snapshots
	snap_t += dt
	var k := 1.0 - exp(-14.0 * dt)
	for th in g.props:
		if th.net_to != Vector2.INF:
			th.net_to += th.vel * dt
			th.pos = th.pos.lerp(th.net_to, k)
	for e in g.enemies:
		if e.oz != null or e.net_to == Vector2.INF:
			continue
		e.net_to += e.vel * dt
		e.pos = e.pos.lerp(e.net_to, k)
	for b in g.bullets:
		b.pos += b.vel * dt
	for x in g.oozes:
		if x.net_to == Vector2.INF:
			continue
		x.net_to += x.pvel * dt
		x.ppos = x.ppos.lerp(x.net_to, k)
		if x.avatar != null:
			x.avatar.pos = x.ppos
			x.avatar.vel = x.pvel
