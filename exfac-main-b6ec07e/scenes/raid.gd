extends Node2D
## Raid presentation + input; combat/loot/extract rules live in RaidSim.

# Explicit preloads — don't rely on global class_name cache after systems/ moves.
const RaidSim := preload("res://scripts/systems/raid.gd")
const Items := preload("res://scripts/systems/items.gd")
const Skills := preload("res://scripts/systems/skills.gd")
const UiStyle := preload("res://scripts/systems/ui_style.gd")

var world: Dictionary = {}
var paused := false
var result_hold := 0.0
var fire_rate := 2.5

@onready var cam: Camera2D = %Camera
@onready var vitals_panel: PanelContainer = %VitalsPanel
@onready var hp_label: Label = %HpLabel
@onready var hp_bar: ProgressBar = %HpBar
@onready var stamina_label: Label = %StaminaLabel
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var bag_label: Label = %BagLabel
@onready var bag_list: Label = %BagList
@onready var msg_label: Label = %MsgLabel
@onready var hint_label: Label = %HintLabel
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_label: Label = %ResultLabel
@onready var minimap_panel: PanelContainer = %MinimapPanel
@onready var minimap: Control = %Minimap
@onready var extract_bar_panel: PanelContainer = %ExtractBarPanel
@onready var extract_bar: ProgressBar = %ExtractBar
@onready var extract_bar_label: Label = %ExtractBarLabel
@onready var med_label: Label = %MedLabel
@onready var ammo_label: Label = %AmmoLabel
@onready var ammo_sub: Label = %AmmoSub
@onready var crosshair: Control = %Crosshair
@onready var compass: Control = %Compass
@onready var compass_label: Label = %CompassLabel


func _ready() -> void:
	var packed := int(GameSession.meta.get("packed_medkits", 0))
	GameSession.meta["packed_medkits"] = 0
	var packed_scrap := int(GameSession.meta.get("packed_scrap", 0))
	GameSession.meta["packed_scrap"] = 0
	var skills: Dictionary = Skills.ensure(GameSession.meta)
	world = RaidSim.create_raid_world(GameSession.meta["loadout"], packed, skills)
	if packed_scrap > 0:
		Items.add_to_stash(world["inventory"], Items.stack_of("scrap", packed_scrap))
		RaidSim.refresh_inventory_cap(world)
	fire_rate = Items.loadout_fire_rate(GameSession.meta["loadout"])
	result_panel.visible = false
	cam.make_current()
	_apply_hud_styles()
	minimap.draw.connect(_draw_minimap)
	crosshair.draw.connect(_draw_crosshair)
	compass.draw.connect(_draw_compass)
	extract_bar_panel.visible = false
	hint_label.visible = false
	msg_label.visible = false
	ammo_sub.visible = false
	_snap_camera(true)
	queue_redraw()
	crosshair.queue_redraw()
	compass.queue_redraw()
	_maybe_teach_field_tips()


func _maybe_teach_field_tips() -> void:
	## One sparse tip per session — stance first, intel when a chip is already packed.
	if Items.count_in_stacks(world["inventory"], "intel") > 0 and GameSession.consume_teach("intel_pulse"):
		world["message"] = "T  burn Signal Chip — brief hostile sweep"
		world["message_ttl"] = 4.0
	elif GameSession.consume_teach("stance"):
		world["message"] = "Ctrl crouch · RMB brace · G decoy · V flare"
		world["message_ttl"] = 3.8


func _apply_hud_styles() -> void:
	UiStyle.apply_wash(vitals_panel)
	UiStyle.apply_wash(minimap_panel, Color(0.04, 0.06, 0.08, 0.65))
	UiStyle.apply_wash(result_panel, Color(0.04, 0.06, 0.08, 0.88))
	UiStyle.apply_wash(extract_bar_panel, Color(0.04, 0.06, 0.08, 0.55))
	UiStyle.style_progress(hp_bar, Color(0.24, 0.81, 0.56, 1))
	UiStyle.style_progress(stamina_bar, Color(0.4, 0.78, 0.95, 1))
	UiStyle.style_progress(extract_bar, Color(0.24, 0.81, 0.56, 1))


func _process(dt: float) -> void:
	crosshair.queue_redraw()
	compass.queue_redraw()

	if paused:
		if Input.is_action_just_pressed("pause_game"):
			paused = false
			hint_label.text = ""
			hint_label.visible = false
		return

	if Input.is_action_just_pressed("pause_game") and not bool(world["over"]):
		paused = true
		hint_label.text = "PAUSED"
		hint_label.visible = true
		return

	if bool(world["over"]):
		result_hold += dt
		RaidSim.step_raid(world, dt, Vector2.ZERO, Vector2.ZERO, false, false, 1.0)
		_show_result()
		if result_hold > 2.2 or Input.is_action_just_pressed("start_raid") or Input.is_action_just_pressed("ui_accept"):
			_return_to_hideout()
		_snap_camera(false)
		queue_redraw()
		minimap.queue_redraw()
		_refresh_hud()
		return

	var move := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	var aim := get_global_mouse_position()
	var shoot := Input.is_action_pressed("shoot")
	var interact := Input.is_action_just_pressed("interact")
	var use_medkit := Input.is_action_just_pressed("use_medkit")
	var reload := Input.is_action_just_pressed("reload")
	var sprint := Input.is_action_pressed("sprint")
	var crouch := Input.is_action_pressed("crouch")
	var brace := Input.is_action_pressed("aim_brace")
	var equip := Input.is_action_just_pressed("equip_gear")
	var distract := Input.is_action_just_pressed("distract")
	var intel_pulse := Input.is_action_just_pressed("intel_pulse")
	var mark_flare := Input.is_action_just_pressed("mark_flare")
	RaidSim.step_raid(world, dt, move, aim, shoot, interact, fire_rate, use_medkit, reload, sprint, equip, distract, crouch, brace, intel_pulse, mark_flare)
	fire_rate = float(world["player"].get("fire_rate", fire_rate))
	_maybe_teach_intel_after_loot()
	if bool(world["over"]):
		result_hold = 0.0
	_snap_camera(false)
	_refresh_hud()
	queue_redraw()
	minimap.queue_redraw()


func _maybe_teach_intel_after_loot() -> void:
	if Items.count_in_stacks(world["inventory"], "intel") <= 0:
		return
	if not GameSession.consume_teach("intel_pulse"):
		return
	if float(world.get("message_ttl", 0.0)) > 1.5:
		return
	world["message"] = "T  burn Signal Chip — brief hostile sweep"
	world["message_ttl"] = 3.5


func _snap_camera(instant: bool) -> void:
	var player: Dictionary = world["player"]
	var target: Vector2 = player["pos"]
	if instant:
		cam.global_position = target
	else:
		cam.global_position = cam.global_position.lerp(target, 0.18)


func _show_result() -> void:
	result_panel.visible = true
	var outcome := String(world["outcome"]) if world["outcome"] != null else "aborted"
	if outcome == "extracted":
		var deeds := int(world.get("skill_deeds", 0))
		var bonus := Skills.bonus_points_from_deeds(deeds)
		result_label.text = "OUT\nLoot banked · +%d skill%s\nEnter — BASE" % [
			1 + bonus, " (+deeds)" if bonus > 0 else "",
		]
		result_label.add_theme_color_override("font_color", Color("3ecf8e"))
		UiStyle.apply_ok_panel(result_panel)
	elif outcome == "died":
		var lost := Items.inventory_used(world.get("dropped_loot", []))
		if lost > 0:
			result_label.text = "DOWN\nDrop bag lost · %d items\nEnter — BASE" % lost
		else:
			result_label.text = "DOWN\nEnter — BASE"
		result_label.add_theme_color_override("font_color", Color("e85454"))
		UiStyle.apply_danger_panel(result_panel)
	else:
		result_label.text = "FIELD OVER\nEnter — BASE"
		UiStyle.apply_wash(result_panel)


func _return_to_hideout() -> void:
	var result := RaidSim.finalize_raid_result(world)
	GameSession.apply_raid_result(result)


func _refresh_hud() -> void:
	var player: Dictionary = world["player"]
	var hp := float(player["hp"])
	var max_hp := float(player["max_hp"])
	var hp_ratio := clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	hp_label.text = "%d / %d" % [int(ceil(hp)), int(max_hp)]
	var armor_max := float(player.get("armor_max", 0.0))
	if armor_max > 0.0:
		var armor_pct := int(round(100.0 * float(player.get("armor_hp", 0.0)) / armor_max))
		hp_label.text = "%d / %d · %d%%" % [int(ceil(hp)), int(max_hp), armor_pct]
		if armor_pct <= 0:
			hp_label.add_theme_color_override("font_color", Color("e85454"))
		elif armor_pct <= 35:
			hp_label.add_theme_color_override("font_color", Color("e6b35a"))
		else:
			hp_label.add_theme_color_override("font_color", Color(0.93, 0.95, 0.97, 1))
	else:
		hp_label.add_theme_color_override("font_color", Color(0.93, 0.95, 0.97, 1))
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	UiStyle.style_progress(hp_bar, UiStyle.hp_color(hp_ratio))

	var stamina := float(player.get("stamina", 100.0))
	var stamina_max := float(player.get("stamina_max", 100.0))
	stamina_bar.max_value = stamina_max
	stamina_bar.value = stamina
	var sprinting := bool(player.get("sprinting", false))
	var exhausted := float(player.get("sprint_exhaust", 0.0)) > 0.0
	if exhausted:
		stamina_label.text = "—"
		stamina_label.add_theme_color_override("font_color", Color("e85454"))
		UiStyle.style_progress(stamina_bar, Color(0.91, 0.33, 0.33, 1))
	elif sprinting:
		stamina_label.text = "%d" % int(ceil(stamina))
		stamina_label.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0, 1))
		UiStyle.style_progress(stamina_bar, Color(0.55, 0.9, 1.0, 1))
	else:
		stamina_label.text = "%d" % int(ceil(stamina))
		stamina_label.add_theme_color_override("font_color", Color(0.55, 0.78, 0.92, 1))
		UiStyle.style_progress(stamina_bar, Color(0.4, 0.78, 0.95, 1))

	var used := Items.inventory_used(world["inventory"])
	var cap := int(world["inventory_cap"])
	bag_label.text = "BAG  %d / %d" % [used, cap]
	var bag_text := Items.format_inventory_lines(world["inventory"])
	bag_list.text = "" if bag_text == "(empty)" else bag_text

	var meds := Items.count_in_stacks(world["inventory"], "medkit")
	var channel := float(world["player"].get("heal_channel", 0.0))
	if channel > 0.0:
		med_label.text = "HEAL  %.1fs" % channel
		med_label.add_theme_color_override("font_color", Color("e07070"))
	else:
		med_label.text = "MED  ×%d" % meds
		med_label.add_theme_color_override("font_color", Color("e07070") if meds > 0 else Color(0.4, 0.45, 0.5))

	var mag := int(player.get("mag", 0))
	var reserve := int(player.get("reserve", 0))
	var rch := float(player.get("reload_channel", 0.0))
	var armed := Items.loadout_has_weapon(world.get("loadout", {}))
	if not armed:
		ammo_label.text = "FISTS"
		ammo_sub.visible = float(player.get("punch_swing", 0.0)) > 0.0
		ammo_sub.text = "·" if ammo_sub.visible else ""
		ammo_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92, 1))
	elif rch > 0.0:
		ammo_label.text = "…"
		ammo_sub.visible = true
		ammo_sub.text = "%.1fs" % rch
		ammo_label.add_theme_color_override("font_color", Color("d2b48c"))
	else:
		ammo_label.text = "%d  |  %d" % [mag, reserve]
		# Manual reload discipline — empty mag keeps a quiet R cue (no auto-reload).
		if mag <= 0 and reserve > 0:
			ammo_sub.visible = true
			ammo_sub.text = "R"
			ammo_label.add_theme_color_override("font_color", Color("e85454"))
		elif mag <= 0 and reserve <= 0:
			ammo_sub.visible = true
			ammo_sub.text = "—"
			ammo_label.add_theme_color_override("font_color", Color("e85454"))
		else:
			ammo_sub.visible = false
			ammo_sub.text = ""
			ammo_label.add_theme_color_override("font_color", Color("e6b35a"))

	var msg := ""
	if float(world["message_ttl"]) > 0.0:
		msg = String(world["message"])
	msg_label.text = msg
	msg_label.visible = not msg.is_empty()

	var hint: Variant = world["interact_hint"]
	var hint_text := String(hint) if hint != null else ("" if not paused else "PAUSED")
	hint_label.text = hint_text
	hint_label.visible = not hint_text.is_empty()

	var extracting := bool(world.get("extract_alarm", false)) and not bool(world["over"])
	extract_bar_panel.visible = extracting
	if extracting:
		var pct := float(world.get("extract_progress_01", 0.0))
		extract_bar.value = pct * 100.0
		var contest := int(world.get("extract_contest_count", 0))
		if contest > 0:
			extract_bar_label.text = "CONTESTED  %d%%" % int(floor(pct * 100.0))
			extract_bar_label.add_theme_color_override("font_color", Color("e85454"))
			UiStyle.apply_danger_panel(extract_bar_panel)
			UiStyle.style_progress(extract_bar, Color(0.91, 0.33, 0.33, 1))
		else:
			extract_bar_label.text = "OUT  %d%%" % int(floor(pct * 100.0))
			extract_bar_label.add_theme_color_override("font_color", Color("3ecf8e"))
			UiStyle.apply_wash(extract_bar_panel, Color(0.04, 0.1, 0.08, 0.55))
			UiStyle.style_progress(extract_bar, Color(0.24, 0.81, 0.56, 1))

	var dist_m := float(world.get("nearest_extract_dist", 0.0)) / 40.0
	var dir: Vector2 = world.get("nearest_extract_dir", Vector2.RIGHT)
	var deeds := int(world.get("skill_deeds", 0))
	var deed_bonus := Skills.bonus_points_from_deeds(deeds)
	if deeds > 0:
		compass_label.text = "%s  %.0fm  ·  deeds %d→+%d" % [_compass_arrow(dir), dist_m, deeds, deed_bonus]
	else:
		compass_label.text = "%s  %.0fm" % [_compass_arrow(dir), dist_m]

	# Soft dusk wash cue on the vitals wash when light is failing.
	var dusk := float(world.get("dusk_01", 0.0))
	if dusk > 0.15:
		UiStyle.apply_wash(vitals_panel, Color(0.07, 0.06, 0.05, 0.78).lerp(Color(0.04, 0.06, 0.08, 0.65), 1.0 - dusk))
	else:
		UiStyle.apply_wash(vitals_panel)


func _draw() -> void:
	var shake := float(world.get("shake", 0.0))
	var ox := randf_range(-shake, shake) if shake > 0.0 else 0.0
	var oy := randf_range(-shake, shake) if shake > 0.0 else 0.0
	draw_set_transform(Vector2(ox, oy), 0.0, Vector2.ONE)

	draw_rect(Rect2(0, 0, world["width"], world["height"]), Color("141a22"))
	# Soft ground grid so the big map reads as space, not void.
	var grid := 200.0
	var gx0 := 0.0
	while gx0 < float(world["width"]):
		draw_line(Vector2(gx0, 0), Vector2(gx0, world["height"]), Color(1, 1, 1, 0.03), 1.0)
		gx0 += grid
	var gy0 := 0.0
	while gy0 < float(world["height"]):
		draw_line(Vector2(0, gy0), Vector2(world["width"], gy0), Color(1, 1, 1, 0.03), 1.0)
		gy0 += grid

	for o in world["obstacles"]:
		draw_rect(Rect2(float(o["x"]), float(o["y"]), float(o["w"]), float(o["h"])), Color("2e3848"))
		draw_rect(Rect2(float(o["x"]), float(o["y"]), float(o["w"]), float(o["h"])), Color("1a222c"), false, 1.0)

	var player: Dictionary = world["player"]
	var obstacles: Array = world["obstacles"]

	# Vision ring (player awareness).
	if bool(player["alive"]):
		draw_arc(player["pos"], RaidSim.VISION_RANGE, 0.0, TAU, 64, Color(0.4, 0.7, 1.0, 0.12), 1.5)

	for z in world["extracts"]:
		var zp: Vector2 = z["pos"]
		var zr := float(z["radius"])
		var is_active := bool(world.get("extract_alarm", false)) and int(world.get("active_extract_id", -1)) == int(z["id"])
		var contest := int(world.get("extract_contest_count", 0))
		var pressure := String(z.get("pressure", "contested"))
		var fill := Color(0.24, 0.81, 0.56, 0.18)
		var ring := Color("3ecf8e")
		match pressure:
			"hot":
				fill = Color(0.78, 0.28, 0.28, 0.16)
				ring = Color(0.85, 0.4, 0.4, 0.85)
			"quiet":
				fill = Color(0.35, 0.65, 0.82, 0.14)
				ring = Color(0.5, 0.78, 0.92, 0.8)
			_:
				fill = Color(0.24, 0.81, 0.56, 0.18)
				ring = Color("3ecf8e")
		if is_active and contest > 0:
			fill = Color(0.91, 0.33, 0.33, 0.22)
			ring = Color("e85454")
		elif is_active:
			fill = Color(0.9, 0.7, 0.35, 0.2)
			ring = Color("e6b35a")
		draw_circle(zp, zr, fill)
		draw_arc(zp, zr, 0.0, TAU, 48, ring, 2.5 if is_active else 2.0)
		var pct := 0.0
		if is_active:
			pct = float(world.get("extract_progress_01", 0.0))
		else:
			pct = clampf(float(z["progress"]) / float(z["hold_seconds"]), 0.0, 1.0)
		if pct > 0.0:
			draw_arc(zp, zr - 6.0, -PI * 0.5, -PI * 0.5 + TAU * pct, 48, Color("9dffc8") if contest == 0 else Color("ffb0b0"), 5.0)
		var label := pressure.to_upper()
		if is_active and contest > 0:
			label = "CONTESTED"
		elif is_active:
			label = "FLARED"
		draw_string(ThemeDB.fallback_font, zp + Vector2(-34, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ring)

	for c in world["crates"]:
		if bool(c["opened"]):
			continue
		var cp: Vector2 = c["pos"]
		# Crates / corpses only render when in vision + LOS (same fog as combat reads).
		if not RaidSim.can_see_actor(player, cp, obstacles):
			continue
		if String(c.get("kind", "crate")) == "corpse":
			draw_circle(cp, 11.0, Color(0.55, 0.22, 0.22, 0.85))
			draw_arc(cp, 11.0, 0.0, TAU, 20, Color("e85454"), 1.5)
			draw_string(ThemeDB.fallback_font, cp + Vector2(-10, 4), "×", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffb0b0"))
		elif String(c.get("kind", "crate")) == "drop_bag":
			# Player death pouch — amber pack, critical border only.
			draw_circle(cp, 13.0, Color(0.78, 0.55, 0.22, 0.88))
			draw_arc(cp, 13.0, 0.0, TAU, 24, Color("e6b35a"), 2.0)
			draw_string(ThemeDB.fallback_font, cp + Vector2(-14, 4), "BAG", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("fff0c8"))
		else:
			var fill := Color("e6b35a")
			var edge := Color("8a6a30")
			match String(c.get("kind", "crate")):
				"ammo_crate":
					fill = Color(0.82, 0.7, 0.45, 0.95)
					edge = Color(0.55, 0.42, 0.22, 1)
				"med_cache":
					fill = Color(0.78, 0.38, 0.38, 0.92)
					edge = Color(0.55, 0.2, 0.2, 1)
				"weapon_case":
					fill = Color(0.45, 0.62, 0.82, 0.95)
					edge = Color(0.28, 0.42, 0.6, 1)
				"intel_safe":
					fill = Color(0.42, 0.72, 0.82, 0.95)
					edge = Color(0.22, 0.48, 0.58, 1)
			draw_rect(Rect2(cp.x - 10, cp.y - 10, 20, 20), fill)
			# Specialty caches get a critical-state border; common crates stay wash-only.
			if String(c.get("kind", "crate")) != "crate":
				draw_rect(Rect2(cp.x - 10, cp.y - 10, 20, 20), edge, false, 1.5)
			else:
				draw_rect(Rect2(cp.x - 10, cp.y - 10, 20, 20), Color(0.54, 0.42, 0.19, 0.35), false, 1.0)
		# Ransack progress on the active target.
		if int(player.get("loot_target_id", -1)) == int(c["id"]) and float(player.get("loot_channel", 0.0)) > 0.0:
			var max_c := maxf(0.2, float(player.get("loot_channel_max", 1.0)))
			var pct := 1.0 - clampf(float(player["loot_channel"]) / max_c, 0.0, 1.0)
			draw_arc(cp, 18.0, -PI * 0.5, -PI * 0.5 + TAU * pct, 36, Color("e6b35a"), 3.5)

	for roamer in world["roamers"]:
		if not bool(roamer["alive"]):
			continue
		var elite := bool(roamer.get("elite", false))
		var pulse_live := float(world.get("intel_pulse_ttl", 0.0)) > 0.0
		var visible := RaidSim.can_see_actor(player, roamer["pos"], obstacles)
		# Fog of war: no silhouette if out of vision or blocked — unless intel sweep.
		if not visible and not pulse_live:
			continue
		var col := Color("e85454") if float(roamer["hit_flash"]) > 0.0 else Color("c45c5c")
		if float(roamer["hit_flash"]) <= 0.0:
			if elite:
				col = Color("c9a0ff")
			else:
				match String(roamer.get("ai_state", "patrol")):
					"combat", "rush":
						col = Color("d45a5a")
					"investigate", "search":
						col = Color("c4785c")
					_:
						col = Color("c45c5c")
		if pulse_live and not visible:
			col = Color(0.5, 0.85, 1.0, 0.75)
		var rpos: Vector2 = roamer["pos"]
		var rr := float(roamer["radius"])
		draw_circle(rpos, rr, col)
		# Cheap body read — darker torso disc + eyes; enforcers get a plate rim.
		draw_circle(rpos, rr * 0.62, col.darkened(0.22))
		if elite:
			draw_arc(rpos, rr + 2.0, 0.0, TAU, 28, Color(0.78, 0.55, 1.0, 0.55), 1.5)
		# Enforcer first-lock telegraph — expanding ring so you can read the elite.
		var t_ttl := float(roamer.get("telegraph_ttl", 0.0))
		if elite and t_ttl > 0.0:
			var ring_a := clampf(t_ttl / 1.1, 0.2, 0.9)
			draw_arc(rpos, rr + 10.0 + (1.1 - t_ttl) * 28.0, 0.0, TAU, 40, Color(0.78, 0.55, 1.0, ring_a), 2.5)
		var raim: Vector2 = roamer["aim"]
		if visible and raim.length_squared() > 1e-6:
			raim = raim.normalized()
			_draw_actor_eyes(rpos, rr, raim, Color(0.15, 0.08, 0.08, 0.95), Color(0.95, 0.55, 0.5, 1) if elite else Color(1, 0.85, 0.85, 1))
			# Short facing cue — not a gun laser (muzzle is own length for roamers).
			draw_line(rpos, rpos + raim * (rr + 6.0), Color("ffaaaa") if not elite else Color("e0c0ff"), 2.0)

	if bool(player["alive"]):
		var pcol := Color("ffffff") if float(player["hit_flash"]) > 0.0 else Color("6ec1ff")
		if bool(player.get("sprinting", false)):
			pcol = Color("9de8ff") if float(player["hit_flash"]) <= 0.0 else pcol
			# Motion streak so sprint reads at a glance on the big map.
			var v: Vector2 = player.get("vel", Vector2.ZERO)
			if v.length_squared() > 1.0:
				draw_line(player["pos"] - v.normalized() * 16.0, player["pos"], Color(0.55, 0.85, 1.0, 0.45), 4.0)
		var ppos: Vector2 = player["pos"]
		var pr := float(player["radius"])
		draw_circle(ppos, pr, pcol)
		# Vest / pack silhouette from loadout — sparse kit read without gun clutter.
		var loadout: Dictionary = world.get("loadout", {})
		var armed := Items.loadout_has_weapon(loadout)
		var has_armor := loadout.get("armor_id") != null and not String(loadout.get("armor_id")).is_empty()
		var has_bag := loadout.get("bag_id") != null and not String(loadout.get("bag_id")).is_empty()
		if has_armor:
			draw_circle(ppos, pr * 0.72, Color(0.35, 0.55, 0.48, 0.55))
		else:
			draw_circle(ppos, pr * 0.55, pcol.darkened(0.18))
		if has_bag:
			var bag_off: Vector2 = -(player["aim"] as Vector2) if (player["aim"] as Vector2).length_squared() > 1e-6 else Vector2.LEFT
			bag_off = bag_off.normalized()
			draw_circle(ppos + bag_off * (pr * 0.55), pr * 0.38, Color(0.72, 0.52, 0.28, 0.85))
		var paim: Vector2 = player["aim"]
		if paim.length_squared() < 1e-6:
			paim = Vector2.RIGHT
		else:
			paim = paim.normalized()
		_draw_actor_eyes(ppos, pr, paim, Color(0.08, 0.12, 0.18, 0.95), Color(0.95, 0.98, 1.0, 1))
		if armed:
			# Muzzle tick only when a firearm is equipped — never for fists.
			draw_line(ppos, ppos + paim * 22.0, Color("d0e8ff"), 2.5)
		else:
			# Punch arc / fist cue — no muzzle length that reads as a gun.
			var swing := float(player.get("punch_swing", 0.0))
			if swing > 0.0:
				var a := paim.angle()
				var span := 0.9
				draw_arc(ppos, pr + 8.0, a - span, a + span, 16, Color(0.9, 0.95, 1.0, 0.7), 2.5)
			else:
				draw_circle(ppos + paim * (pr + 3.0), 2.8, Color(0.75, 0.82, 0.9, 0.55))
		var channel := float(player.get("heal_channel", 0.0))
		if channel > 0.0:
			var pct := 1.0 - clampf(channel / RaidSim.MEDKIT_CHANNEL, 0.0, 1.0)
			draw_arc(ppos, pr + 10.0, -PI * 0.5, -PI * 0.5 + TAU * pct, 32, Color("e07070"), 3.0)
		var rch_draw := float(player.get("reload_channel", 0.0))
		if rch_draw > 0.0 and armed:
			var rpct := 1.0 - clampf(rch_draw / maxf(0.2, float(player.get("reload_time", 1.5))), 0.0, 1.0)
			draw_arc(ppos, pr + 14.0, -PI * 0.5, -PI * 0.5 + TAU * rpct, 32, Color("d2b48c"), 3.0)
	else:
		draw_circle(player["pos"], float(player["radius"]), Color("555555"))

	for b in world["bullets"]:
		# Hide roamer rounds you can't see (same vision rules).
		if not bool(b["from_player"]) and not RaidSim.can_see_actor(player, b["pos"], obstacles):
			continue
		var bcol := Color("ffe08a") if bool(b["from_player"]) else Color("ff8080")
		draw_circle(b["pos"], float(b["radius"]), bcol)

	for f in world["floats"]:
		if not RaidSim.can_see_actor(player, f["pos"], obstacles) and bool(player["alive"]):
			# Still show floats on self / nearby; skip far fogged ones.
			if player["pos"].distance_to(f["pos"]) > RaidSim.VISION_RANGE:
				continue
		var alpha := clampf(float(f["life"]) / float(f["max_life"]), 0.0, 1.0)
		var col: Color = f["color"]
		col.a = alpha
		draw_string(ThemeDB.fallback_font, f["pos"], String(f["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_actor_eyes(pos: Vector2, radius: float, facing: Vector2, pupil: Color, sclera: Color) -> void:
	## Tiny facing eyes — readable at top-down scale without becoming a face sprite.
	var f := facing.normalized() if facing.length_squared() > 1e-6 else Vector2.RIGHT
	var side := f.orthogonal()
	var eye_r := maxf(1.6, radius * 0.18)
	var forward := radius * 0.38
	var spread := radius * 0.28
	var left := pos + f * forward + side * spread
	var right := pos + f * forward - side * spread
	draw_circle(left, eye_r, sclera)
	draw_circle(right, eye_r, sclera)
	draw_circle(left + f * (eye_r * 0.25), eye_r * 0.45, pupil)
	draw_circle(right + f * (eye_r * 0.25), eye_r * 0.45, pupil)


func _draw_minimap() -> void:
	var w := minimap.size.x
	var h := minimap.size.y
	minimap.draw_rect(Rect2(Vector2.ZERO, minimap.size), Color(0.04, 0.06, 0.08, 0.9))
	var sx := w / float(world["width"])
	var sy := h / float(world["height"])
	# Faint obstacle blobs for orientation.
	for o in world["obstacles"]:
		var r := Rect2(float(o["x"]) * sx, float(o["y"]) * sy, maxf(1.0, float(o["w"]) * sx), maxf(1.0, float(o["h"]) * sy))
		minimap.draw_rect(r, Color(0.25, 0.3, 0.36, 0.55))
	for z in world["extracts"]:
		var zp: Vector2 = z["pos"]
		var is_active := bool(world.get("extract_alarm", false)) and int(world.get("active_extract_id", -1)) == int(z["id"])
		var contest := int(world.get("extract_contest_count", 0))
		var ecol := Color("3ecf8e")
		if is_active and contest > 0:
			ecol = Color("e85454")
		elif is_active:
			ecol = Color("e6b35a")
		minimap.draw_circle(Vector2(zp.x * sx, zp.y * sy), 3.5 if is_active else 3.0, ecol)
	# Corpse / drop-bag blips (opened crates ignored).
	for c in world["crates"]:
		if bool(c["opened"]):
			continue
		var kind := String(c.get("kind", "crate"))
		if kind != "corpse" and kind != "drop_bag":
			continue
		var cp: Vector2 = c["pos"]
		var blip := Color("e85454") if kind == "corpse" else Color("e6b35a")
		if bool(c.get("elite", false)):
			blip = Color("c9a0ff")
		minimap.draw_circle(Vector2(cp.x * sx, cp.y * sy), 2.2 if kind == "drop_bag" else 2.0, blip)
	# Hostiles only when in vision — no god-mode radar (unless intel pulse).
	var player: Dictionary = world["player"]
	var obstacles: Array = world["obstacles"]
	var intel_live := float(world.get("intel_pulse_ttl", 0.0)) > 0.0
	for roamer in world["roamers"]:
		if not bool(roamer["alive"]):
			continue
		if not intel_live and not RaidSim.can_see_actor(player, roamer["pos"], obstacles):
			continue
		var rp: Vector2 = roamer["pos"]
		var rcol := Color("c9a0ff") if bool(roamer.get("elite", false)) else Color("c45c5c")
		if intel_live and not RaidSim.can_see_actor(player, roamer["pos"], obstacles):
			rcol = Color(0.5, 0.85, 1.0, 0.85)
		minimap.draw_circle(Vector2(rp.x * sx, rp.y * sy), 2.4 if bool(roamer.get("elite", false)) else 1.8, rcol)
	var pp: Vector2 = player["pos"]
	minimap.draw_circle(Vector2(pp.x * sx, pp.y * sy), 3.5, Color("6ec1ff"))
	# Extract direction tick from player.
	var dir: Vector2 = world.get("nearest_extract_dir", Vector2.RIGHT)
	var pmin := Vector2(pp.x * sx, pp.y * sy)
	minimap.draw_line(pmin, pmin + dir * 10.0, Color(0.24, 0.81, 0.56, 0.75), 1.5)


func _draw_crosshair() -> void:
	var c := crosshair.size * 0.5
	var col := Color(0.92, 0.95, 0.98, 0.85)
	var gap := 3.0
	var arm := 7.0
	crosshair.draw_line(c + Vector2(-arm, 0), c + Vector2(-gap, 0), col, 1.5)
	crosshair.draw_line(c + Vector2(gap, 0), c + Vector2(arm, 0), col, 1.5)
	crosshair.draw_line(c + Vector2(0, -arm), c + Vector2(0, -gap), col, 1.5)
	crosshair.draw_line(c + Vector2(0, gap), c + Vector2(0, arm), col, 1.5)
	crosshair.draw_circle(c, 1.2, Color(0.24, 0.81, 0.56, 0.9))


func _draw_compass() -> void:
	if world.is_empty():
		return
	var dir: Vector2 = world.get("nearest_extract_dir", Vector2.RIGHT)
	var c := compass.size * 0.5
	var tip := c + dir * 16.0
	var left := c + dir.rotated(2.5) * 8.0
	var right := c + dir.rotated(-2.5) * 8.0
	compass.draw_line(c - dir * 6.0, tip, Color(0.24, 0.81, 0.56, 0.95), 2.0)
	compass.draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(0.24, 0.81, 0.56, 0.95))
	compass.draw_arc(c, 18.0, 0.0, TAU, 32, Color(0.35, 0.5, 0.55, 0.35), 1.0)
	# Soft threat tick — fades with ttl; extract arrow stays primary.
	var threat_ttl := float(world.get("threat_ttl", 0.0))
	if threat_ttl > 0.0:
		var tdir: Vector2 = world.get("threat_dir", Vector2.RIGHT)
		if tdir.length_squared() > 1e-6:
			tdir = tdir.normalized()
			var alpha := clampf(threat_ttl / RaidSim.THREAT_BEARING_TTL, 0.25, 0.9)
			var tcol := Color(0.91, 0.35, 0.32, alpha)
			compass.draw_line(c + tdir * 6.0, c + tdir * 17.0, tcol, 2.0)
			compass.draw_circle(c + tdir * 17.0, 2.2, tcol)


func _compass_arrow(dir: Vector2) -> String:
	var a := atan2(dir.y, dir.x)
	# 8-way arrow from world +X right / +Y down.
	var oct := int(round(((a + PI) / TAU) * 8.0)) % 8
	var glyphs := ["←", "↖", "↑", "↗", "→", "↘", "↓", "↙"]
	return glyphs[oct]
