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
	# One-shot build marker — if you never see this, Godot is opening an old folder.
	if not bool(world.get("_punch_build_noted", false)):
		world["_punch_build_noted"] = true
		world["message"] = "Punch build: click · stamina · no shove"
		world["message_ttl"] = 3.5
	var need_persist := false
	# Refund medkits that did not fit the bag (create_raid_world may truncate).
	var med_refund := int(world.get("pack_refund_medkits", 0))
	world["pack_refund_medkits"] = 0
	if med_refund > 0:
		Items.add_to_stash(GameSession.meta["stash"], Items.stack_of("medkit", med_refund))
		need_persist = true
	# Scrap pack — capacity-safe; leftovers return to locker.
	if packed_scrap > 0:
		var scrap_left := Items.try_add_inventory_partial(
			world["inventory"], int(world["inventory_cap"]), Items.stack_of("scrap", packed_scrap)
		)
		RaidSim.refresh_inventory_cap(world)
		if scrap_left > 0:
			Items.add_to_stash(GameSession.meta["stash"], Items.stack_of("scrap", scrap_left))
			need_persist = true
	if need_persist:
		GameSession.persist()
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
	elif GameSession.consume_teach("ground_loot"):
		world["message"] = "Colored piles on the ground — E scoop · crates for bigger finds"
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
	var shoot_click := Input.is_action_just_pressed("shoot")
	var shoot_held := Input.is_action_pressed("shoot")
	var armed_now := Items.loadout_has_weapon(world.get("loadout", {}))
	var mag_now := int(world["player"].get("mag", 0))
	# Guns can hold-fire; fists / empty-mag melee are click-edge only (scene + sim).
	var melee_mode := (not armed_now) or mag_now <= 0
	var shoot := shoot_click if melee_mode else shoot_held
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
	RaidSim.step_raid(world, dt, move, aim, shoot, interact, fire_rate, use_medkit, reload, sprint, equip, distract, crouch, brace, intel_pulse, mark_flare, shoot_click)
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
		# Unarmed: weapon status only — never mag/reserve / AMMO chrome.
		ammo_label.text = "FISTS"
		ammo_sub.visible = false
		ammo_sub.text = ""
		ammo_sub.custom_minimum_size = Vector2.ZERO
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

	# Base earth — slightly warmer so color washes have something to sit on.
	draw_rect(Rect2(0, 0, world["width"], world["height"]), Color("1a222c"))
	# Soft ground grid so the big map reads as space, not void.
	var grid := 200.0
	var gx0 := 0.0
	while gx0 < float(world["width"]):
		draw_line(Vector2(gx0, 0), Vector2(gx0, world["height"]), Color(1, 1, 1, 0.028), 1.0)
		gx0 += grid
	var gy0 := 0.0
	while gy0 < float(world["height"]):
		draw_line(Vector2(0, gy0), Vector2(world["width"], gy0), Color(1, 1, 1, 0.028), 1.0)
		gy0 += grid

	# Paint-only ground patches (roads, yards, pads) — no collision.
	for d in world.get("decals", []):
		_draw_decal(d)

	for o in world["obstacles"]:
		_draw_obstacle(o)

	var player: Dictionary = world["player"]
	var obstacles: Array = world["obstacles"]

	# Blood scent trail — only when you can see the drip.
	for drop in world.get("blood_trail", []):
		var bp: Vector2 = drop["pos"]
		if bool(player["alive"]) and not RaidSim.can_see_actor(player, bp, obstacles):
			continue
		var life := clampf(float(drop.get("ttl", 0.0)) / maxf(0.1, RaidSim.BLOOD_TRAIL_TTL), 0.15, 1.0)
		draw_circle(bp, 3.5 + life * 2.0, Color(0.55, 0.08, 0.1, 0.35 * life))
		draw_circle(bp + Vector2(2, -1), 2.0, Color(0.7, 0.12, 0.14, 0.45 * life))

	# Vision ring — match fog (dusk/wound shrink vision_range).
	if bool(player["alive"]):
		var vision_r := float(player.get("vision_range", RaidSim.VISION_RANGE))
		draw_arc(player["pos"], vision_r, 0.0, TAU, 72, Color(0.4, 0.7, 1.0, 0.14), 1.6)
		# Soft outer fog rim so the cut feels like night, not a hard clip.
		draw_arc(player["pos"], vision_r + 18.0, 0.0, TAU, 72, Color(0.05, 0.07, 0.1, 0.18), 14.0)

	for z in world["extracts"]:
		_draw_extract_pad(z, player)

	for c in world["crates"]:
		var cp: Vector2 = c["pos"]
		# Crates / corpses only render when in vision + LOS (same fog as combat reads).
		if not RaidSim.can_see_actor(player, cp, obstacles):
			continue
		if bool(c["opened"]):
			# Spent caches leave a pale husk so the field remembers scavenges.
			if String(c.get("kind", "")) == "ground_loot":
				draw_circle(cp, 4.0, Color(0.3, 0.32, 0.34, 0.45))
			else:
				draw_rect(Rect2(cp.x - 8, cp.y - 6, 16, 12), Color(0.25, 0.28, 0.32, 0.55))
				draw_rect(Rect2(cp.x - 8, cp.y - 6, 16, 12), Color(0.15, 0.17, 0.2, 0.7), false, 1.0)
			continue
		_draw_loot_container(c, cp)
		# Soft reach pulse when you're close enough to E.
		var reach := float(c.get("radius", 16.0)) + float(player.get("radius", 14.0)) + 18.0
		if bool(player["alive"]) and player["pos"].distance_to(cp) <= reach:
			draw_arc(cp, 16.0, 0.0, TAU, 28, Color(1, 1, 1, 0.18), 1.2)
		# Ransack progress on the active target.
		if int(player.get("loot_target_id", -1)) == int(c["id"]) and float(player.get("loot_channel", 0.0)) > 0.0:
			var max_c := maxf(0.2, float(player.get("loot_channel_max", 1.0)))
			var pct := 1.0 - clampf(float(player["loot_channel"]) / max_c, 0.0, 1.0)
			draw_arc(cp, 20.0, -PI * 0.5, -PI * 0.5 + TAU * pct, 36, Color("e6b35a"), 3.5)

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
			# Punch arc only while swinging — no idle tip-dot (read as a HUD speck under FISTS).
			var swing := float(player.get("punch_swing", 0.0))
			if swing > 0.0:
				var a := paim.angle()
				var span := 0.9
				draw_arc(ppos, pr + 8.0, a - span, a + span, 16, Color(0.9, 0.95, 1.0, 0.7), 2.5)
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
			var vision_cut := float(player.get("vision_range", RaidSim.VISION_RANGE))
			if player["pos"].distance_to(f["pos"]) > vision_cut:
				continue
		var alpha := clampf(float(f["life"]) / float(f["max_life"]), 0.0, 1.0)
		var col: Color = f["color"]
		col.a = alpha
		draw_string(ThemeDB.fallback_font, f["pos"], String(f["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col)

	# Field dusk wash — late raids cool and darken without hiding the HUD.
	var dusk_draw := float(world.get("dusk_01", 0.0))
	if dusk_draw > 0.02:
		var wash := Color(0.08, 0.06, 0.12, 0.12 + dusk_draw * 0.28)
		draw_rect(Rect2(0, 0, world["width"], world["height"]), wash)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_extract_pad(z: Dictionary, player: Dictionary) -> void:
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
	# Landing chevrons — pad reads as a lift, not a plain disc.
	for i in 4:
		var a := float(i) * TAU * 0.25 + float(world.get("time_alive", 0.0)) * (0.4 if is_active else 0.0)
		var outer := zp + Vector2(cos(a), sin(a)) * (zr - 10.0)
		var inner := zp + Vector2(cos(a), sin(a)) * (zr - 22.0)
		draw_line(outer, inner, Color(ring.r, ring.g, ring.b, 0.55), 2.0)
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
	# Soft proximity wash when you're on the apron.
	if bool(player.get("alive", false)) and player["pos"].distance_to(zp) <= zr + 40.0:
		draw_arc(zp, zr + 8.0, 0.0, TAU, 40, Color(ring.r, ring.g, ring.b, 0.2), 2.0)


func _draw_decal(d: Dictionary) -> void:
	var r := Rect2(float(d["x"]), float(d["y"]), float(d["w"]), float(d["h"]))
	var fill := Color(0.22, 0.28, 0.24, 0.35)
	match String(d.get("style", "dirt")):
		"asphalt":
			fill = Color(0.18, 0.2, 0.24, 0.55)
		"road":
			fill = Color(0.16, 0.18, 0.22, 0.72)
		"yard":
			fill = Color(0.22, 0.34, 0.24, 0.42)
		"gravel":
			fill = Color(0.32, 0.3, 0.26, 0.4)
		"pad":
			fill = Color(0.28, 0.3, 0.34, 0.5)
		_:
			fill = Color(0.3, 0.26, 0.2, 0.38)
	draw_rect(r, fill)
	if String(d.get("style", "")) == "road":
		# Center dashed stripe.
		var mid_y := r.position.y + r.size.y * 0.5
		if r.size.x > r.size.y:
			var x := r.position.x + 20.0
			while x < r.end.x - 20.0:
				draw_line(Vector2(x, mid_y), Vector2(mini(x + 28.0, r.end.x - 12.0), mid_y), Color(0.85, 0.75, 0.35, 0.35), 2.0)
				x += 52.0
		else:
			var mid_x := r.position.x + r.size.x * 0.5
			var y := r.position.y + 20.0
			while y < r.end.y - 20.0:
				draw_line(Vector2(mid_x, y), Vector2(mid_x, mini(y + 28.0, r.end.y - 12.0)), Color(0.85, 0.75, 0.35, 0.35), 2.0)
				y += 52.0


func _draw_obstacle(o: Dictionary) -> void:
	var r := Rect2(float(o["x"]), float(o["y"]), float(o["w"]), float(o["h"]))
	var kind := String(o.get("kind", "solid"))
	var style := String(o.get("style", "rubble"))
	if kind == "door":
		var open := bool(o.get("open", false))
		var fill := Color(0.55, 0.38, 0.22, 0.92) if not open else Color(0.35, 0.42, 0.38, 0.35)
		var edge := Color(0.85, 0.62, 0.32, 1) if not open else Color(0.4, 0.55, 0.45, 0.7)
		draw_rect(r, fill)
		draw_rect(r, edge, false, 2.0)
		# Latch tick.
		var mid := r.get_center()
		draw_circle(mid, 3.0, edge)
		return
	var fill := Color(0.28, 0.34, 0.42, 1)
	var edge := Color(0.14, 0.18, 0.24, 1)
	var accent := Color(0.4, 0.48, 0.55, 0.35)
	match style:
		"building":
			fill = Color(0.32, 0.38, 0.48, 1)
			edge = Color(0.18, 0.22, 0.3, 1)
			accent = Color(0.55, 0.62, 0.72, 0.25)
		"wall":
			fill = Color(0.26, 0.3, 0.38, 1)
			edge = Color(0.12, 0.15, 0.2, 1)
			accent = Color(0.45, 0.5, 0.58, 0.2)
		"prop":
			fill = Color(0.42, 0.36, 0.28, 1)
			edge = Color(0.22, 0.18, 0.12, 1)
			accent = Color(0.7, 0.55, 0.32, 0.35)
		"rubble":
			fill = Color(0.3, 0.32, 0.3, 1)
			edge = Color(0.16, 0.17, 0.16, 1)
			accent = Color(0.5, 0.42, 0.3, 0.22)
	draw_rect(r, fill)
	draw_rect(r, edge, false, 1.5)
	# Inner bevel / stripe so solids aren't flat slabs.
	if r.size.x > 40.0 and r.size.y > 40.0:
		draw_rect(Rect2(r.position + Vector2(4, 4), r.size - Vector2(8, 8)), accent, false, 1.0)
	elif r.size.y >= r.size.x:
		draw_line(r.position + Vector2(r.size.x * 0.35, 3), r.position + Vector2(r.size.x * 0.35, r.size.y - 3), accent, 2.0)
	else:
		draw_line(r.position + Vector2(3, r.size.y * 0.4), r.position + Vector2(r.size.x - 3, r.size.y * 0.4), accent, 2.0)
	# Building windows — tiny lit slits so compounds feel inhabited.
	if style == "building" and r.size.x >= 80.0 and r.size.y <= 40.0:
		var wx := r.position.x + 14.0
		while wx < r.end.x - 14.0:
			draw_rect(Rect2(wx, r.position.y + 6.0, 8.0, 10.0), Color(0.75, 0.85, 0.95, 0.22))
			wx += 22.0
	elif style == "building" and r.size.y >= 80.0 and r.size.x <= 40.0:
		var wy := r.position.y + 14.0
		while wy < r.end.y - 14.0:
			draw_rect(Rect2(r.position.x + 6.0, wy, 10.0, 8.0), Color(0.75, 0.85, 0.95, 0.22))
			wy += 22.0


func _draw_loot_container(c: Dictionary, cp: Vector2) -> void:
	var kind := String(c.get("kind", "crate"))
	if kind == "corpse":
		draw_circle(cp, 12.0, Color(0.45, 0.16, 0.18, 0.9))
		draw_circle(cp + Vector2(-4, -2), 5.0, Color(0.55, 0.22, 0.22, 0.85))
		draw_arc(cp, 12.0, 0.0, TAU, 22, Color("e85454"), 1.8)
		draw_string(ThemeDB.fallback_font, cp + Vector2(-10, 4), "×", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffb0b0"))
		return
	if kind == "drop_bag":
		draw_circle(cp, 14.0, Color(0.78, 0.55, 0.22, 0.9))
		draw_circle(cp + Vector2(0, -3), 8.0, Color(0.9, 0.7, 0.35, 0.55))
		draw_arc(cp, 14.0, 0.0, TAU, 26, Color("e6b35a"), 2.2)
		draw_string(ThemeDB.fallback_font, cp + Vector2(-14, 4), "BAG", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("fff0c8"))
		return
	if kind == "ground_loot":
		# Colored item pile — reads as loot on the dirt, not another box.
		var def_id := "scrap"
		var contents: Array = c.get("contents", [])
		if not contents.is_empty():
			def_id = String(contents[0].get("def_id", "scrap"))
		var col: Color = Items.get_item(def_id).get("color", Color("a8a79c"))
		draw_circle(cp, 13.0, Color(col.r, col.g, col.b, 0.22))
		draw_circle(cp + Vector2(-3, 2), 5.5, col.darkened(0.1))
		draw_circle(cp + Vector2(4, -1), 4.5, col.lightened(0.08))
		draw_circle(cp + Vector2(0, -4), 3.8, col)
		draw_arc(cp, 10.0, 0.0, TAU, 20, Color(col.r, col.g, col.b, 0.75), 1.4)
		return

	var fill := Color(0.78, 0.58, 0.28, 0.98)
	var edge := Color(0.45, 0.32, 0.14, 1)
	var lid := Color(0.9, 0.72, 0.38, 0.95)
	var tag := ""
	match kind:
		"ammo_crate":
			fill = Color(0.82, 0.68, 0.38, 0.98)
			edge = Color(0.5, 0.38, 0.16, 1)
			lid = Color(0.92, 0.78, 0.45, 1)
			tag = "A"
		"med_cache":
			fill = Color(0.82, 0.36, 0.36, 0.98)
			edge = Color(0.5, 0.16, 0.16, 1)
			lid = Color(0.95, 0.55, 0.55, 1)
			tag = "+"
		"weapon_case":
			fill = Color(0.38, 0.55, 0.78, 0.98)
			edge = Color(0.2, 0.34, 0.52, 1)
			lid = Color(0.55, 0.72, 0.92, 1)
			tag = "W"
		"intel_safe":
			fill = Color(0.32, 0.68, 0.78, 0.98)
			edge = Color(0.16, 0.42, 0.52, 1)
			lid = Color(0.55, 0.85, 0.95, 1)
			tag = "S"
		_:
			tag = ""
	# Body + raised lid + strap so crates read as objects, not UI tiles.
	draw_rect(Rect2(cp.x - 12, cp.y - 8, 24, 18), fill)
	draw_rect(Rect2(cp.x - 13, cp.y - 12, 26, 8), lid)
	draw_rect(Rect2(cp.x - 12, cp.y - 8, 24, 18), edge, false, 1.6)
	draw_rect(Rect2(cp.x - 13, cp.y - 12, 26, 8), edge.lightened(0.15), false, 1.2)
	draw_line(Vector2(cp.x - 10, cp.y + 1), Vector2(cp.x + 10, cp.y + 1), edge.darkened(0.1), 2.0)
	if tag != "":
		draw_string(ThemeDB.fallback_font, cp + Vector2(-5, 5), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.9))
	else:
		# Common crate rivets.
		draw_circle(cp + Vector2(-7, -4), 1.6, edge.lightened(0.25))
		draw_circle(cp + Vector2(7, -4), 1.6, edge.lightened(0.25))
		draw_circle(cp + Vector2(-7, 6), 1.6, edge.lightened(0.25))
		draw_circle(cp + Vector2(7, 6), 1.6, edge.lightened(0.25))


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
	# Road / pad washes first so the compound skeleton reads.
	for d in world.get("decals", []):
		var style := String(d.get("style", ""))
		if style != "road" and style != "pad":
			continue
		var dr := Rect2(float(d["x"]) * sx, float(d["y"]) * sy, maxf(1.0, float(d["w"]) * sx), maxf(1.0, float(d["h"]) * sy))
		minimap.draw_rect(dr, Color(0.22, 0.24, 0.28, 0.45) if style == "road" else Color(0.2, 0.26, 0.3, 0.35))
	# Faint obstacle blobs for orientation.
	for o in world["obstacles"]:
		var r := Rect2(float(o["x"]) * sx, float(o["y"]) * sy, maxf(1.0, float(o["w"]) * sx), maxf(1.0, float(o["h"]) * sy))
		var ocol := Color(0.25, 0.3, 0.36, 0.55)
		if String(o.get("kind", "")) == "door":
			ocol = Color(0.7, 0.5, 0.25, 0.7)
		elif String(o.get("style", "")) == "building":
			ocol = Color(0.32, 0.4, 0.5, 0.65)
		minimap.draw_rect(r, ocol)
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
		# Keep minimap readable — only mark critical / loose finds.
		if kind != "corpse" and kind != "drop_bag" and kind != "ground_loot" and kind != "weapon_case" and kind != "intel_safe":
			continue
		var cp: Vector2 = c["pos"]
		var blip := Color("e6b35a")
		match kind:
			"corpse":
				blip = Color("e85454")
			"drop_bag":
				blip = Color("e6b35a")
			"ground_loot":
				blip = Color(0.75, 0.7, 0.45, 0.85)
			"weapon_case":
				blip = Color(0.45, 0.7, 0.95, 0.9)
			"intel_safe":
				blip = Color(0.45, 0.85, 0.95, 0.9)
		if bool(c.get("elite", false)):
			blip = Color("c9a0ff")
		minimap.draw_circle(Vector2(cp.x * sx, cp.y * sy), 2.2 if kind == "drop_bag" else 1.8, blip)
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
