extends RefCounted
## Kenney Topdown Shooter pack → raid style keys (CC0).

const TILE := "res://assets/PNG/Tiles/tile_%s.png"
const CHAR := "res://assets/PNG/%s/%s.png"
const TILE_PX := 64.0

const TILE_IDS := {
	"grass": 1,
	"dirt": 5,
	"dirt_road": 15,
	"mud": 14,
	"gravel": 6,
	"road": 86,
	"junction": 86,
	"asphalt": 86,
	"pad": 86,
	"interior": 100,
	"yard": 5,
	"leaf": 2,
	"scrub": 2,
	"pond": 10,
	"tree": 182,
	"bush": 235,
	"container": 130,
	"crate": 130,
	"ammo_crate": 131,
	"med_cache": 96,
	"weapon_case": 170,
	"intel_safe": 180,
	"extract": 12,
	"prop": 130,
	"rubble": 86,
	"door": 442,
	"door_open": 441,
	"window_glass": 10,
}

const SOLID_COLORS := {
	"wall": Color("3a3a3e"),
	"shed": Color("6b4a2e"),
	"building": Color("38383c"),
	"warehouse": Color("45484c"),
	"courtyard": Color("3f4246"),
	"bunker": Color("2a2e2a"),
	"column": Color("5a5c60"),
	"sandbag": Color("8a7348"),
	"fence": Color("5c4030"),
	"rubble": Color("5a5752"),
	"prop": Color("4a4540"),
}

const WALL_OUTLINE := Color(0.08, 0.08, 0.1, 0.95)

const FLOOR_UNDERLAY := {
	"dirt": Color("8a6238"),
	"dirt_road": Color("8a6238"),
	"mud": Color("6e4a28"),
	"gravel": Color("7a6a50"),
	"road": Color("3a3a3a"),
	"junction": Color("3a3a3a"),
	"asphalt": Color("3a3a3a"),
	"pad": Color("4a4a4e"),
	"interior": Color("8b6840"),
	"yard": Color("8a6238"),
	"leaf": Color("3d7a45"),
	"scrub": Color("3d7a45"),
	"pond": Color("4a7a80"),
	"extract": Color("4a4a4e"),
}

const CRATE_MODULATE := {
	"crate": Color(1.05, 0.95, 0.85, 1),
	"ammo_crate": Color(0.85, 0.95, 1.15, 1),
	"med_cache": Color(0.7, 1.2, 0.8, 1),
	"weapon_case": Color(1.1, 0.85, 0.65, 1),
	"intel_safe": Color(0.95, 0.9, 1.1, 1),
	"container": Color(0.9, 0.9, 0.95, 1),
}

const CRATE_SIZE := {
	"crate": 26.0,
	"ammo_crate": 28.0,
	"med_cache": 24.0,
	"weapon_case": 30.0,
	"intel_safe": 28.0,
	"container": 32.0,
}

const CHAR_PATHS := {
	"player_stand": ["Survivor 1", "survivor1_stand"],
	"player_gun": ["Survivor 1", "survivor1_gun"],
	"player_machine": ["Survivor 1", "survivor1_machine"],
	"player_hold": ["Survivor 1", "survivor1_hold"],
	"player_reload": ["Survivor 1", "survivor1_reload"],
	"roamer_stand": ["Soldier 1", "soldier1_stand"],
	"roamer_gun": ["Soldier 1", "soldier1_gun"],
	"roamer_machine": ["Soldier 1", "soldier1_machine"],
	"roamer_hold": ["Soldier 1", "soldier1_hold"],
	"elite_stand": ["Hitman 1", "hitman1_stand"],
	"elite_gun": ["Hitman 1", "hitman1_gun"],
	"elite_machine": ["Hitman 1", "hitman1_machine"],
	"elite_hold": ["Hitman 1", "hitman1_hold"],
}

static var _cache: Dictionary = {}
static var _fit_cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()
	_fit_cache.clear()


static func tile_path(id: int) -> String:
	if id < 10:
		return TILE % ("%02d" % id)
	return TILE % str(id)


static func get_tex(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var out: Texture2D = null
	if key == "rock":
		out = _make_rock_tex()
	elif key == "log":
		out = _make_log_tex()
	elif TILE_IDS.has(key):
		out = _load(tile_path(int(TILE_IDS[key])))
	elif CHAR_PATHS.has(key):
		var pair: Array = CHAR_PATHS[key]
		out = _load(CHAR % [pair[0], pair[1]])
	_cache[key] = out
	return out


## Opaque pixel span for prop scaling — cached so builds don't re-scan every tree.
static func tex_fit_px(key: String) -> float:
	if _fit_cache.has(key):
		return float(_fit_cache[key])
	var tex := get_tex(key)
	var fit := 64.0
	if tex != null:
		fit = float(maxi(tex.get_width(), tex.get_height()))
		var img: Image = tex.get_image()
		if img != null:
			var used: Rect2i = img.get_used_rect()
			if used.size.x > 4 and used.size.y > 4:
				fit = float(maxi(used.size.x, used.size.y))
	_fit_cache[key] = fit
	return fit


static func tex_for_decal(style: String) -> Texture2D:
	var t := get_tex(style)
	return t if t != null else get_tex("dirt")


static func tex_for_crate(kind: String) -> Texture2D:
	var t := get_tex(kind)
	return t if t != null else get_tex("crate")


static func crate_modulate(kind: String) -> Color:
	if CRATE_MODULATE.has(kind):
		return CRATE_MODULATE[kind]
	return Color.WHITE


static func crate_px(kind: String) -> float:
	if CRATE_SIZE.has(kind):
		return float(CRATE_SIZE[kind])
	return 26.0


static func floor_underlay(style: String) -> Color:
	if FLOOR_UNDERLAY.has(style):
		return FLOOR_UNDERLAY[style]
	return Color("5a7a48")


static func is_prop_style(style: String) -> bool:
	return style in ["tree", "bush", "rock", "log"]


static func is_solid_style(style: String) -> bool:
	return SOLID_COLORS.has(style)


static func solid_color(style: String) -> Color:
	if SOLID_COLORS.has(style):
		return SOLID_COLORS[style]
	return SOLID_COLORS["wall"]


static func _make_rock_tex() -> Texture2D:
	# Procedural pebble — Kenney pack has no clean rock sprites.
	var img := Image.create(48, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_ellipse(img, Vector2(24, 22), Vector2(20, 14), Color("4a4a4e"))
	_fill_ellipse(img, Vector2(18, 18), Vector2(10, 8), Color("5c5c62"))
	_fill_ellipse(img, Vector2(28, 16), Vector2(7, 5), Color("6a6a70"))
	return ImageTexture.create_from_image(img)


static func _make_log_tex() -> Texture2D:
	var img := Image.create(64, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_fill_ellipse(img, Vector2(32, 12), Vector2(30, 9), Color("5a3a22"))
	_fill_ellipse(img, Vector2(32, 11), Vector2(28, 6), Color("7a5230"))
	_fill_ellipse(img, Vector2(10, 12), Vector2(4, 7), Color("3d2818"))
	_fill_ellipse(img, Vector2(54, 12), Vector2(4, 7), Color("3d2818"))
	return ImageTexture.create_from_image(img)


static func _fill_ellipse(img: Image, center: Vector2, radii: Vector2, color: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var rx2 := radii.x * radii.x
	var ry2 := radii.y * radii.y
	if rx2 < 1.0 or ry2 < 1.0:
		return
	for y in range(h):
		for x in range(w):
			var dx := (float(x) + 0.5 - center.x) / radii.x
			var dy := (float(y) + 0.5 - center.y) / radii.y
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, color)


static func _load(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var res = load(path)
	return res as Texture2D
