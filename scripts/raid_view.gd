extends Node2D
## Kenney raid renderer — tiled grass, Y-sorted world, detailed doors/crates/props.

const RaidSim := preload("res://scripts/systems/raid.gd")
const RaidAssets := preload("res://scripts/systems/raid_assets.gd")
const Items := preload("res://scripts/systems/items.gd")

const ACTOR_PX := 28.0
const Z_FLOOR := 0
const Z_BASE := 10

var _ground: Node2D
var _floors: Node2D
var _world: Node2D

var _player: Sprite2D
var _roamers: Dictionary = {}
var _crates: Dictionary = {}
var _bullets: Array = []
var _extract_nodes: Dictionary = {}
var _door_nodes: Dictionary = {}
var _door_open: Dictionary = {}
var _window_nodes: Dictionary = {}
var _window_broken: Dictionary = {}

var _world_ref: Dictionary = {}
var _built := false
var _overlay_dirty := true
var _los_tick: int = 0
var _last_dusk_bucket := -1.0
var _static_sprites: Array = []


func _ready() -> void:
	_ensure_layers()


func build(world: Dictionary) -> void:
	_ensure_layers()
	_world_ref = world
	_clear_node(_ground)
	_clear_node(_floors)
	_clear_node(_world)
	_roamers.clear()
	_crates.clear()
	_bullets.clear()
	_door_nodes.clear()
	_door_open.clear()
	_window_nodes.clear()
	_window_broken.clear()
	_extract_nodes.clear()
	_static_sprites.clear()
	_player = null
	_los_tick = 0
	_last_dusk_bucket = -1.0

	_build_ground(world)
	_build_floors(world)
	_build_obstacles(world)
	_build_extracts(world)

	_player = _make_actor_sprite("player_gun")
	_world.add_child(_player)
	_built = true
	_overlay_dirty = true
	queue_redraw()


func sync(world: Dictionary, view: Rect2) -> void:
	if not _built:
		return
	_world_ref = world
	_los_tick += 1
	_sync_player(world)
	_sync_roamers(world, view)
	_sync_crates(world, view)
	_sync_bullets(world, view)
	_sync_doors_windows(world)
	_cull_static(view)
	var dusk := float(world.get("dusk_01", 0.0))
	var dusk_bucket := floorf(dusk * 10.0)
	var need_overlay: bool = _overlay_dirty \
			or dusk_bucket != _last_dusk_bucket \
			or float(player_loot_channel(world)) > 0.0 \
			or not world.get("floats", []).is_empty() \
			or float(world.get("noise_ttl", 0.0)) > 0.05 \
			or not world.get("blood_trail", []).is_empty() \
			or bool(world.get("extract_alarm", false))
	if need_overlay:
		_last_dusk_bucket = dusk_bucket
		queue_redraw()
		_overlay_dirty = false


func player_loot_channel(world: Dictionary) -> float:
	return float(world["player"].get("loot_channel", 0.0))


func _ensure_layers() -> void:
	if _ground != null:
		return
	_ground = Node2D.new()
	_ground.name = "Ground"
	_ground.z_index = Z_FLOOR
	add_child(_ground)
	_floors = Node2D.new()
	_floors.name = "Floors"
	_floors.z_index = Z_FLOOR + 2
	add_child(_floors)
	_world = Node2D.new()
	_world.name = "World"
	_world.y_sort_enabled = true
	_world.z_index = Z_BASE
	add_child(_world)


func _build_ground(world: Dictionary) -> void:
	var mw := float(world["width"])
	var mh := float(world["height"])
	var margin := RaidSim.MAP_MARGIN
	var grass := RaidAssets.get_tex("grass")
	# Textured forest skirt past the playable rect — camera can see past the cutoff.
	var skirt := Polygon2D.new()
	if grass != null:
		skirt.color = Color(0.42, 0.52, 0.38, 1)
		skirt.texture = grass
		skirt.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		skirt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var sw := mw + margin * 2.0
		var sh := mh + margin * 2.0
		skirt.uv = PackedVector2Array([
			Vector2.ZERO, Vector2(sw, 0), Vector2(sw, sh), Vector2(0, sh)
		])
	else:
		skirt.color = Color(0.12, 0.22, 0.14, 1)
	skirt.polygon = _rect_poly(Rect2(-margin, -margin, mw + margin * 2.0, mh + margin * 2.0))
	_ground.add_child(skirt)
	var poly := Polygon2D.new()
	if grass != null:
		poly.color = Color.WHITE
		poly.texture = grass
		poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		poly.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		poly.uv = PackedVector2Array([
			Vector2.ZERO, Vector2(mw, 0), Vector2(mw, mh), Vector2(0, mh)
		])
	else:
		poly.color = Color("2a8f55")
	poly.polygon = _rect_poly(Rect2(0, 0, mw, mh))
	_ground.add_child(poly)
	# Soft leaf fringe on the playable edge so grass doesn't meet void as a hard line.
	var fringe := Color(0.16, 0.28, 0.18, 0.5)
	var thick := 88.0
	for band in [
		Rect2(-12.0, -12.0, mw + 24.0, thick),
		Rect2(-12.0, mh - thick + 12.0, mw + 24.0, thick),
		Rect2(-12.0, 0.0, thick, mh),
		Rect2(mw - thick + 12.0, 0.0, thick, mh),
	]:
		var strip := Polygon2D.new()
		strip.color = fringe
		strip.polygon = _rect_poly(band)
		_ground.add_child(strip)


func _build_floors(world: Dictionary) -> void:
	# Opaque underlay kills grass show-through; texture sits on top.
	for d in world.get("decals", []):
		var style := String(d.get("style", "dirt"))
		var key := style if RaidAssets.TILE_IDS.has(style) else "dirt"
		var r := Rect2(float(d["x"]), float(d["y"]), float(d["w"]), float(d["h"]))
		if r.size.x < 1.0 or r.size.y < 1.0:
			continue
		var under := Polygon2D.new()
		under.color = RaidAssets.floor_underlay(key)
		under.polygon = _rect_poly(r)
		_floors.add_child(under)
		var tex := RaidAssets.get_tex(key)
		if tex == null:
			continue
		var poly := Polygon2D.new()
		poly.color = Color.WHITE
		poly.texture = tex
		poly.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		poly.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		poly.polygon = _rect_poly(r)
		poly.uv = PackedVector2Array([
			Vector2.ZERO,
			Vector2(r.size.x, 0.0),
			r.size,
			Vector2(0.0, r.size.y),
		])
		_floors.add_child(poly)


func _build_obstacles(world: Dictionary) -> void:
	var obstacles: Array = world.get("obstacles", [])
	for i in obstacles.size():
		var o: Dictionary = obstacles[i]
		var kind := String(o.get("kind", "solid"))
		var style := String(o.get("style", "rubble"))
		var r := Rect2(float(o["x"]), float(o["y"]), float(o["w"]), float(o["h"]))
		if RaidAssets.is_prop_style(style):
			_add_prop_sprite(style, r)
			continue
		if kind == "door":
			var open := bool(o.get("open", false))
			var door := _make_door_node(r, open)
			_world.add_child(door)
			_door_nodes[i] = door
			_door_open[i] = open
			continue
		if kind == "window":
			var broken := bool(o.get("broken", false))
			var win := _make_window_node(r, broken)
			_world.add_child(win)
			_window_nodes[i] = win
			_window_broken[i] = broken
			continue
		if style == "container" or style in ["crate", "ammo_crate", "med_cache", "weapon_case", "intel_safe"]:
			_add_prop_sprite(style if RaidAssets.TILE_IDS.has(style) else "container", r)
			continue
		var fill_style := style if RaidAssets.is_solid_style(style) else "wall"
		_add_wall(r, RaidAssets.solid_color(fill_style))


func _add_wall(r: Rect2, fill: Color) -> void:
	if r.size.x < 0.5 or r.size.y < 0.5:
		return
	var anchor := Vector2(r.get_center().x, r.end.y)
	# Dark outline for building silhouette.
	var outline := Polygon2D.new()
	outline.color = RaidAssets.WALL_OUTLINE
	outline.position = anchor
	var grown := r.grow(1.4)
	outline.polygon = _rect_poly_local(grown, anchor)
	_world.add_child(outline)
	var body := Polygon2D.new()
	body.color = fill
	body.position = anchor
	body.polygon = _rect_poly_local(r, anchor)
	_world.add_child(body)


func _make_door_node(r: Rect2, open: bool) -> Node2D:
	var root := Node2D.new()
	root.position = Vector2(r.get_center().x, r.end.y)
	_rebuild_door(root, r, open)
	return root


func _rebuild_door(root: Node2D, r: Rect2, open: bool) -> void:
	for c in root.get_children():
		c.queue_free()
	# Jamb (doorway hole in the wall line).
	var jamb := Polygon2D.new()
	jamb.color = Color(0.12, 0.1, 0.09, 1)
	jamb.polygon = _rect_poly_local(r.grow(1.0), root.position)
	root.add_child(jamb)
	var horizontal := r.size.x > r.size.y
	var short := mini(r.size.x, r.size.y)
	var longv := maxf(r.size.x, r.size.y)
	var leaf_w := short * 0.92
	var leaf_h := longv * 0.96
	var local_center := Vector2.ZERO
	var rot := 0.0
	if open:
		leaf_w = short * 0.38
		if horizontal:
			local_center = Vector2(longv * 0.34, -short * 0.5)
			rot = 0.55
		else:
			local_center = Vector2(short * 0.55, -longv * 0.45)
			rot = 0.5
	else:
		local_center = Vector2(0.0, -short * 0.5) if horizontal else Vector2(0.0, -longv * 0.5)
		rot = PI * 0.5 if horizontal else 0.0
	var leaf := Node2D.new()
	leaf.position = local_center
	leaf.rotation = rot
	root.add_child(leaf)
	var hw := leaf_w * 0.5
	var hh := leaf_h * 0.5
	var frame := Polygon2D.new()
	frame.color = Color("3d2818")
	frame.polygon = PackedVector2Array([
		Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(hw, hh), Vector2(-hw, hh)
	])
	leaf.add_child(frame)
	var plank_w := leaf_w * 0.28
	var gap := leaf_w * 0.05
	var colors := [Color("6b4428"), Color("7a5230"), Color("5c3a20")]
	for i in 3:
		var px := -hw + gap + plank_w * 0.5 + float(i) * (plank_w + gap)
		var plank := Polygon2D.new()
		plank.color = colors[i]
		plank.polygon = PackedVector2Array([
			Vector2(px - plank_w * 0.5, -hh + 2.0),
			Vector2(px + plank_w * 0.5, -hh + 2.0),
			Vector2(px + plank_w * 0.5, hh - 2.0),
			Vector2(px - plank_w * 0.5, hh - 2.0),
		])
		leaf.add_child(plank)
	var handle := Polygon2D.new()
	handle.color = Color("c4a35a")
	var hx := hw * 0.62
	handle.polygon = PackedVector2Array([
		Vector2(hx - 1.2, -3.0), Vector2(hx + 1.2, -3.0),
		Vector2(hx + 1.2, 3.0), Vector2(hx - 1.2, 3.0),
	])
	leaf.add_child(handle)
	if open:
		leaf.modulate = Color(1, 1, 1, 0.92)

func _make_window_node(r: Rect2, broken: bool) -> Node2D:
	var root := Node2D.new()
	root.position = Vector2(r.get_center().x, r.end.y)
	_rebuild_window(root, r, broken)
	return root


func _rebuild_window(root: Node2D, r: Rect2, broken: bool) -> void:
	for c in root.get_children():
		c.queue_free()
	var local_r := Rect2(r.position - root.position, r.size)
	# Frame
	var frame := Polygon2D.new()
	frame.color = Color("2a2a2e")
	frame.polygon = _rect_poly(local_r)
	root.add_child(frame)
	var inset := local_r.grow(-1.6)
	if inset.size.x < 1.0 or inset.size.y < 1.0:
		return
	var glass := Polygon2D.new()
	if broken:
		glass.color = Color(0.45, 0.48, 0.5, 0.35)
	else:
		glass.color = Color(0.55, 0.82, 0.92, 0.72)
	glass.polygon = _rect_poly(inset)
	root.add_child(glass)
	if not broken:
		# Specular streak
		var shine := Polygon2D.new()
		shine.color = Color(1, 1, 1, 0.22)
		var sx := inset.position.x + inset.size.x * 0.15
		shine.polygon = PackedVector2Array([
			Vector2(sx, inset.position.y + 1.0),
			Vector2(sx + maxf(2.0, inset.size.x * 0.12), inset.position.y + 1.0),
			Vector2(sx + maxf(2.0, inset.size.x * 0.08), inset.end.y - 1.0),
			Vector2(sx - 1.0, inset.end.y - 1.0),
		])
		root.add_child(shine)
	else:
		# Crack lines
		var crack := Line2D.new()
		crack.width = 1.2
		crack.default_color = Color(0.2, 0.22, 0.24, 0.85)
		crack.points = PackedVector2Array([
			inset.position + Vector2(inset.size.x * 0.2, inset.size.y * 0.15),
			inset.position + Vector2(inset.size.x * 0.55, inset.size.y * 0.55),
			inset.position + Vector2(inset.size.x * 0.8, inset.size.y * 0.35),
		])
		root.add_child(crack)


func _add_prop_sprite(style: String, r: Rect2) -> void:
	var tex := RaidAssets.get_tex(style)
	if tex == null:
		_add_wall(r, Color("5a5752"))
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = true
	s.position = Vector2(r.get_center().x, r.end.y - 2.0)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var fit := RaidAssets.tex_fit_px(style)
	var size := maxf(r.size.x, r.size.y)
	if style == "tree":
		size *= 1.05
	elif style == "bush":
		size *= 0.95
	elif style == "log":
		s.scale = Vector2(r.size.x / float(tex.get_width()), r.size.y / float(tex.get_height()))
		s.modulate = Color(1.05, 0.95, 0.85, 1)
		_world.add_child(s)
		_static_sprites.append({"node": s, "rect": r.grow(20.0)})
		return
	s.scale = Vector2.ONE * (size / maxf(1.0, fit))
	s.modulate = RaidAssets.crate_modulate(style) if not RaidAssets.is_prop_style(style) else Color.WHITE
	_world.add_child(s)
	_static_sprites.append({"node": s, "rect": r.grow(24.0)})


func _cull_static(view: Rect2) -> void:
	## Hide off-screen props/walls sprites — big maps keep thousands of Sprite2Ds.
	var pad := view.grow(220.0)
	for entry in _static_sprites:
		var spr: CanvasItem = entry["node"]
		if spr == null or not is_instance_valid(spr):
			continue
		var r: Rect2 = entry["rect"]
		spr.visible = pad.intersects(r)


func _build_extracts(world: Dictionary) -> void:
	for z in world.get("extracts", []):
		var zp: Vector2 = z["pos"]
		var zr := float(z["radius"])
		var ring := Polygon2D.new()
		ring.color = Color(0.35, 0.85, 0.55, 0.18)
		ring.polygon = _circle_poly(zp, zr * 1.05, 28)
		_floors.add_child(ring)
		var tex := RaidAssets.get_tex("extract")
		if tex == null:
			continue
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = true
		s.position = zp
		s.scale = Vector2.ONE * ((zr * 1.35) / float(tex.get_width()))
		s.modulate = Color(0.7, 1.05, 0.8, 0.85)
		_floors.add_child(s)
		_extract_nodes[int(z["id"])] = s


func _sync_player(world: Dictionary) -> void:
	var player: Dictionary = world["player"]
	if _player == null:
		return
	_player.position = player["pos"]
	var aim: Vector2 = player.get("aim", Vector2.RIGHT)
	if aim.length_squared() > 1e-6:
		_player.rotation = aim.angle()
	_set_tex(_player, _player_pose_key(world, player))
	var crouch := bool(player.get("crouching", false))
	_fit_actor(_player, float(player.get("radius", 11.0)), 0.82 if crouch else 1.0)
	if not bool(player["alive"]):
		_player.modulate = Color(0.45, 0.45, 0.45, 0.85)
	elif float(player.get("hit_flash", 0.0)) > 0.0:
		_player.modulate = Color(1.35, 1.35, 1.35, 1)
	elif bool(player.get("sprinting", false)):
		_player.modulate = Color(0.85, 1.05, 1.15, 1)
	elif bool(player.get("bracing", false)):
		_player.modulate = Color(0.92, 0.98, 1.08, 1)
	elif crouch:
		_player.modulate = Color(0.9, 0.94, 0.9, 1)
	else:
		_player.modulate = Color.WHITE


func _player_pose_key(world: Dictionary, player: Dictionary) -> String:
	if float(player.get("reload_channel", 0.0)) > 0.0:
		return "player_reload"
	var loadout: Dictionary = world.get("loadout", {})
	if not Items.loadout_has_weapon(loadout):
		# Fists / dry — hold reads as empty hands better than a ghost rifle.
		return "player_hold"
	if float(player.get("punch_swing", 0.0)) > 0.0:
		return "player_hold"
	var wid := String(loadout.get("weapon_id", ""))
	if "rifle" in wid or "carbine" in wid:
		return "player_machine"
	# Idle plant — stand pose when still so the field feels less twitchy.
	if not bool(player.get("sprinting", false)) and not bool(player.get("bracing", false)):
		var vel: Vector2 = player.get("vel", Vector2.ZERO)
		if vel.length() < 12.0:
			return "player_stand"
	return "player_gun"


func _sync_roamers(world: Dictionary, view: Rect2) -> void:
	var player: Dictionary = world["player"]
	var obstacles: Array = world["obstacles"]
	var index: Dictionary = world.get("draw_chunks", {})
	var pulse := float(world.get("intel_pulse_ttl", 0.0)) > 0.0
	var do_los := (_los_tick % 2) == 0 or pulse
	var seen: Dictionary = {}
	for roamer in world.get("roamers", []):
		if not bool(roamer.get("alive", true)):
			continue
		var id := int(roamer["id"])
		seen[id] = true
		var pos: Vector2 = roamer["pos"]
		var spr: Sprite2D = _roamers.get(id, null)
		if spr == null:
			spr = _make_actor_sprite("elite_gun" if bool(roamer.get("elite", false)) else "roamer_gun")
			_world.add_child(spr)
			_roamers[id] = spr
		if not view.has_point(pos) and not pulse:
			spr.visible = false
			continue
		var visible: bool
		if do_los or not spr.visible:
			visible = pulse or RaidSim.can_see_actor(player, pos, obstacles, index)
		else:
			visible = spr.visible
		spr.visible = visible
		if not visible:
			continue
		spr.position = pos
		var aim: Vector2 = roamer.get("aim", Vector2.RIGHT)
		if aim.length_squared() > 1e-6:
			spr.rotation = aim.angle()
		var elite := bool(roamer.get("elite", false))
		_set_tex(spr, _roamer_pose_key(roamer, elite))
		_fit_actor(spr, float(roamer.get("radius", 10.0)))
		if float(roamer.get("hit_flash", 0.0)) > 0.0:
			spr.modulate = Color(1.45, 0.75, 0.75, 1)
		elif pulse and not RaidSim.can_see_actor(player, pos, obstacles, index):
			spr.modulate = Color(0.55, 0.9, 1.0, 0.75)
		elif bool(roamer.get("dormant", false)):
			spr.modulate = Color(0.78, 0.8, 0.82, 1)
		elif elite:
			spr.modulate = Color(1.05, 0.92, 1.18, 1)
		else:
			spr.modulate = Color.WHITE
	var drop: Array = []
	for id in _roamers.keys():
		if not seen.has(id):
			drop.append(id)
	for id2 in drop:
		var s2: Sprite2D = _roamers[id2]
		if is_instance_valid(s2):
			s2.queue_free()
		_roamers.erase(id2)


func _roamer_pose_key(roamer: Dictionary, elite: bool) -> String:
	var prefix := "elite_" if elite else "roamer_"
	var st := String(roamer.get("ai_state", "patrol"))
	# Combat keeps the rifle up; idle beats drop to stand so compounds read quieter.
	if st in ["combat", "flank", "rush", "retreat"]:
		return prefix + "gun"
	if st == "investigate" or st == "search":
		return prefix + "hold"
	if bool(roamer.get("dormant", false)) or st == "dormant" or st == "forage" or st == "patrol":
		return prefix + "stand"
	return prefix + "gun"


func _sync_crates(world: Dictionary, view: Rect2) -> void:
	var player: Dictionary = world["player"]
	var obstacles: Array = world["obstacles"]
	var index: Dictionary = world.get("draw_chunks", {})
	var vision_sq := pow(float(player.get("vision_range", RaidSim.VISION_RANGE)), 2.0)
	var do_los := (_los_tick % 3) == 0
	var seen: Dictionary = {}
	for c in world.get("crates", []):
		if bool(c.get("looted", false)):
			continue
		var id := int(c["id"])
		seen[id] = true
		var pos: Vector2 = c["pos"]
		var kind := String(c.get("kind", "crate"))
		var spr: Sprite2D = _crates.get(id, null)
		if spr == null:
			spr = _make_crate_sprite(kind)
			_world.add_child(spr)
			_crates[id] = spr
		if not view.has_point(pos):
			spr.visible = false
			continue
		var ppos: Vector2 = player["pos"]
		var dist_sq: float = ppos.distance_squared_to(pos)
		var visible: bool
		if dist_sq > vision_sq:
			visible = false
		elif do_los or not spr.visible:
			visible = RaidSim.can_see_actor(player, pos, obstacles, index)
		else:
			visible = true
		spr.visible = visible
		if visible:
			spr.position = pos
	var drop: Array = []
	for id in _crates.keys():
		if not seen.has(id):
			drop.append(id)
	for id2 in drop:
		var s2: Sprite2D = _crates[id2]
		if is_instance_valid(s2):
			s2.queue_free()
		_crates.erase(id2)


func _make_crate_sprite(kind: String) -> Sprite2D:
	var spr := Sprite2D.new()
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex := RaidAssets.tex_for_crate(kind)
	if tex != null:
		spr.texture = tex
		var fit := float(maxi(tex.get_width(), tex.get_height()))
		var img: Image = tex.get_image()
		if img != null:
			var used: Rect2i = img.get_used_rect()
			if used.size.x > 4:
				fit = float(maxi(used.size.x, used.size.y))
		spr.scale = Vector2.ONE * (RaidAssets.crate_px(kind) / maxf(1.0, fit))
	spr.modulate = RaidAssets.crate_modulate(kind)
	return spr


func _sync_bullets(world: Dictionary, view: Rect2) -> void:
	var bullets: Array = world.get("bullets", [])
	while _bullets.size() < bullets.size():
		var s := Polygon2D.new()
		s.color = Color("f0d080")
		s.polygon = PackedVector2Array([
			Vector2(5, 0), Vector2(-3, -1.6), Vector2(-3, 1.6)
		])
		_world.add_child(s)
		_bullets.append(s)
	while _bullets.size() > bullets.size():
		var old: Node = _bullets.pop_back()
		if is_instance_valid(old):
			old.queue_free()
	for i in bullets.size():
		var b: Dictionary = bullets[i]
		var spr: Polygon2D = _bullets[i]
		var pos: Vector2 = b["pos"]
		spr.visible = view.has_point(pos)
		if spr.visible:
			spr.position = pos
			var vel: Vector2 = b.get("vel", Vector2.RIGHT)
			if vel.length_squared() > 1e-6:
				spr.rotation = vel.angle()
			spr.color = Color("ffe08a") if bool(b.get("from_player", false)) else Color("f0a060")


func _sync_doors_windows(world: Dictionary) -> void:
	var obstacles: Array = world.get("obstacles", [])
	for idx in _door_nodes.keys():
		var i := int(idx)
		if i < 0 or i >= obstacles.size():
			continue
		var o: Dictionary = obstacles[i]
		var open := bool(o.get("open", false))
		if bool(_door_open.get(i, false)) == open:
			continue
		_door_open[i] = open
		var node: Node2D = _door_nodes[idx]
		if node == null or not is_instance_valid(node):
			continue
		var r := Rect2(float(o["x"]), float(o["y"]), float(o["w"]), float(o["h"]))
		_rebuild_door(node, r, open)
	for idx2 in _window_nodes.keys():
		var j := int(idx2)
		if j < 0 or j >= obstacles.size():
			continue
		var o2: Dictionary = obstacles[j]
		var broken := bool(o2.get("broken", false))
		if bool(_window_broken.get(j, false)) == broken:
			continue
		_window_broken[j] = broken
		var node2: Node2D = _window_nodes[idx2]
		if node2 == null or not is_instance_valid(node2):
			continue
		var r2 := Rect2(float(o2["x"]), float(o2["y"]), float(o2["w"]), float(o2["h"]))
		_rebuild_window(node2, r2, broken)
	_pulse_extracts(world)


func _pulse_extracts(world: Dictionary) -> void:
	var t := float(world.get("time_alive", 0.0))
	var alarm := bool(world.get("extract_alarm", false))
	var active_id := int(world.get("active_extract_id", -1))
	for id in _extract_nodes.keys():
		var s: Sprite2D = _extract_nodes[id]
		if s == null or not is_instance_valid(s):
			continue
		var active := alarm and int(id) == active_id
		var pulse := 0.75 + 0.18 * sin(t * (5.5 if active else 1.8))
		s.modulate = Color(0.55, 1.05, 0.7, pulse) if active else Color(0.7, 1.05, 0.8, 0.7)


func _draw() -> void:
	if not _built or _world_ref.is_empty():
		return
	var world := _world_ref
	var player: Dictionary = world["player"]
	var view := _view_rect().grow(40.0)
	var mw := float(world.get("width", RaidSim.MAP_W))
	var mh := float(world.get("height", RaidSim.MAP_H))
	# Soft playable-edge wash — reads as forest falloff instead of a hard grass cut.
	var edge_col := Color(0.05, 0.1, 0.07, 0.22)
	var et := 56.0
	if view.intersects(Rect2(0, 0, mw, et)):
		draw_rect(Rect2(view.position.x, 0.0, view.size.x, et).intersection(Rect2(0, 0, mw, et)), edge_col)
	if view.intersects(Rect2(0, mh - et, mw, et)):
		draw_rect(Rect2(view.position.x, mh - et, view.size.x, et).intersection(Rect2(0, mh - et, mw, et)), edge_col)
	if view.intersects(Rect2(0, 0, et, mh)):
		draw_rect(Rect2(0.0, view.position.y, et, view.size.y).intersection(Rect2(0, 0, et, mh)), edge_col)
	if view.intersects(Rect2(mw - et, 0, et, mh)):
		draw_rect(Rect2(mw - et, view.position.y, et, view.size.y).intersection(Rect2(mw - et, 0, et, mh)), edge_col)
	var dusk := float(world.get("dusk_01", 0.0))
	if dusk > 0.02:
		# Cool wash + edge vignette so late raids feel thinner without hiding sprites.
		draw_rect(view, Color(0.06, 0.05, 0.14, 0.12 + dusk * 0.28))
		var edge := Color(0.02, 0.02, 0.06, 0.1 + dusk * 0.2)
		var thick := minf(view.size.x, view.size.y) * 0.08
		draw_rect(Rect2(view.position, Vector2(view.size.x, thick)), edge)
		draw_rect(Rect2(Vector2(view.position.x, view.end.y - thick), Vector2(view.size.x, thick)), edge)
		draw_rect(Rect2(view.position, Vector2(thick, view.size.y)), edge)
		draw_rect(Rect2(Vector2(view.end.x - thick, view.position.y), Vector2(thick, view.size.y)), edge)
	# Blood scent — fade with ttl so roamers' pull has a readable tell.
	for drop in world.get("blood_trail", []):
		var bp: Vector2 = drop["pos"]
		if not view.has_point(bp):
			continue
		var life := clampf(float(drop.get("ttl", 0.0)) / RaidSim.BLOOD_TRAIL_TTL, 0.0, 1.0)
		draw_circle(bp, 2.8 + life * 1.6, Color(0.55, 0.06, 0.1, 0.18 + life * 0.45))
	# Noise ping — brief ring when something shouts across the compound.
	var noise_ttl := float(world.get("noise_ttl", 0.0))
	if noise_ttl > 0.05:
		var np: Vector2 = world.get("noise_pos", Vector2.ZERO)
		var nr := float(world.get("noise_radius", 0.0))
		if nr > 8.0 and view.intersects(Rect2(np.x - nr, np.y - nr, nr * 2.0, nr * 2.0)):
			var na := clampf(noise_ttl / 1.2, 0.0, 1.0) * 0.28
			draw_arc(np, nr, 0.0, TAU, 48, Color(0.95, 0.85, 0.45, na), 1.4)
	for z in world.get("extracts", []):
		var zp: Vector2 = z["pos"]
		var zr := float(z["radius"])
		if not view.intersects(Rect2(zp.x - zr, zp.y - zr, zr * 2.0, zr * 2.0)):
			continue
		var active := bool(world.get("extract_alarm", false)) and int(world.get("active_extract_id", -1)) == int(z["id"])
		draw_arc(zp, zr, 0.0, TAU, 40, Color(0.3, 0.85, 0.55, 0.7 if active else 0.32), 2.2 if active else 1.5)
		if active:
			var t := float(world.get("time_alive", 0.0))
			draw_arc(zp, zr + 6.0 + sin(t * 6.0) * 3.0, 0.0, TAU, 36, Color(0.45, 1.0, 0.7, 0.22), 1.2)
	for c in world.get("crates", []):
		if int(player.get("loot_target_id", -1)) != int(c["id"]):
			continue
		if float(player.get("loot_channel", 0.0)) <= 0.0:
			continue
		var cp: Vector2 = c["pos"]
		var max_c := maxf(0.2, float(player.get("loot_channel_max", 1.0)))
		var pct := 1.0 - clampf(float(player["loot_channel"]) / max_c, 0.0, 1.0)
		var bar := Rect2(cp.x - 12.0, cp.y + 14.0, 24.0, 3.0)
		draw_rect(bar, Color(0.08, 0.09, 0.1, 0.75))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * pct, bar.size.y)), Color("e6b35a"))
	for f in world.get("floats", []):
		var fpos: Vector2 = f["pos"]
		if not view.has_point(fpos):
			continue
		var alpha := clampf(float(f["life"]) / float(f["max_life"]), 0.0, 1.0)
		var col: Color = f["color"]
		col.a = alpha
		draw_string(ThemeDB.fallback_font, fpos, String(f["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, col)


func _view_rect() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2()
	var half := vp.get_visible_rect().size * 0.5
	var cam := vp.get_camera_2d()
	var z := cam.zoom if cam != null else Vector2.ONE
	half = Vector2(half.x / maxf(0.01, z.x), half.y / maxf(0.01, z.y))
	var center := cam.global_position if cam != null else Vector2.ZERO
	return Rect2(center - half, half * 2.0)


func _make_actor_sprite(key: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = true
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_set_tex(s, key)
	_fit_actor(s, 11.0)
	return s


func _set_tex(s: Sprite2D, key: String) -> void:
	# Skip reload churn when the pose key didn't change.
	if String(s.get_meta("pose_key", "")) == key and s.texture != null:
		return
	var tex := RaidAssets.get_tex(key)
	if tex != null:
		s.texture = tex
		s.set_meta("pose_key", key)


func _fit_actor(s: Sprite2D, radius: float, stance_scale: float = 1.0) -> void:
	if s.texture == null:
		return
	var target := maxf(ACTOR_PX, radius * 2.5) * stance_scale
	s.scale = Vector2.ONE * (target / float(s.texture.get_height()))


func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		r.position,
		Vector2(r.end.x, r.position.y),
		r.end,
		Vector2(r.position.x, r.end.y),
	])


func _rect_poly_local(r: Rect2, anchor: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		r.position - anchor,
		Vector2(r.end.x, r.position.y) - anchor,
		r.end - anchor,
		Vector2(r.position.x, r.end.y) - anchor,
	])


func _circle_poly(center: Vector2, radius: float, pts: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts:
		var a := TAU * float(i) / float(pts)
		out.append(center + Vector2(cos(a), sin(a)) * radius)
	return out


func _clear_node(n: Node) -> void:
	if n == null:
		return
	for c in n.get_children():
		c.queue_free()
