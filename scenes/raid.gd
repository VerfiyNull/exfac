extends Node2D
## Raid presentation + input; combat/loot/extract rules live in RaidSim.

# Explicit preloads — don't rely on global class_name cache after systems/ moves.
const RaidSim := preload("res://scripts/systems/raid.gd")
const Items := preload("res://scripts/systems/items.gd")
const Skills := preload("res://scripts/systems/skills.gd")
const UiStyle := preload("res://scripts/systems/ui_style.gd")
const RaidViewScript := preload("res://scripts/raid_view.gd")

var world: Dictionary = {}
var paused := false
var result_hold := 0.0
var fire_rate := 2.5
var raid_view: Node2D
var _last_dusk_bucket := -1.0
var _hp_bar_col := Color(0, 0, 0, 0)
var _stam_bar_col := Color(0, 0, 0, 0)

@onready var cam: Camera2D = %Camera
@onready var vitals_panel: PanelContainer = %VitalsPanel
@onready var hp_label: Label = %HpLabel
@onready var hp_bar: ProgressBar = %HpBar
@onready var stamina_label: Label = %StaminaLabel
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var bag_label: Label = %BagLabel
@onready var bag_list: Label = %BagList
@onready var hint_label: Label = %HintLabel
@onready var result_panel: PanelContainer = %ResultPanel
@onready var result_label: Label = %ResultLabel
@onready var extract_bar_panel: PanelContainer = %ExtractBarPanel
@onready var extract_bar: ProgressBar = %ExtractBar
@onready var extract_bar_label: Label = %ExtractBarLabel
@onready var med_label: Label = %MedLabel
@onready var ammo_label: Label = %AmmoLabel
@onready var ammo_sub: Label = %AmmoSub


func _ready() -> void:
	var packed := int(GameSession.meta.get("packed_medkits", 0))
	GameSession.meta["packed_medkits"] = 0
	var packed_scrap := int(GameSession.meta.get("packed_scrap", 0))
	GameSession.meta["packed_scrap"] = 0
	var skills: Dictionary = Skills.ensure(GameSession.meta)
	world = RaidSim.create_raid_world(GameSession.meta["loadout"], packed, skills)
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
	extract_bar_panel.visible = false
	hint_label.visible = false
	ammo_sub.visible = false
	bag_list.visible = false
	raid_view = RaidViewScript.new()
	raid_view.name = "RaidView"
	add_child(raid_view)
	move_child(raid_view, 0)
	raid_view.call("build", world)
	_snap_camera(true)
	_sync_view()
	_refresh_hud()


func _apply_hud_styles() -> void:
	UiStyle.apply_wash(vitals_panel, Color(0.045, 0.06, 0.08, 0.72))
	UiStyle.apply_wash(result_panel, Color(0.04, 0.06, 0.08, 0.9))
	UiStyle.apply_wash(extract_bar_panel, Color(0.04, 0.09, 0.08, 0.62))
	UiStyle.style_progress(hp_bar, Color(0.24, 0.81, 0.56, 1))
	UiStyle.style_progress(stamina_bar, Color(0.4, 0.78, 0.95, 1))
	UiStyle.style_progress(extract_bar, Color(0.24, 0.81, 0.56, 1))


func _process(dt: float) -> void:
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
		_sync_view()
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
	# Require a live Shift key — action alone can sticky after opposite-shift / focus quirks.
	var sprint := Input.is_action_pressed("sprint") and Input.is_key_pressed(KEY_SHIFT)
	var crouch := Input.is_action_pressed("crouch")
	var brace := Input.is_action_pressed("aim_brace")
	var equip := Input.is_action_just_pressed("equip_gear")
	var distract := Input.is_action_just_pressed("distract")
	var intel_pulse := Input.is_action_just_pressed("intel_pulse")
	var mark_flare := Input.is_action_just_pressed("mark_flare")
	RaidSim.step_raid(world, dt, move, aim, shoot, interact, fire_rate, use_medkit, reload, sprint, equip, distract, crouch, brace, intel_pulse, mark_flare, shoot_click)
	fire_rate = float(world["player"].get("fire_rate", fire_rate))
	if bool(world["over"]):
		result_hold = 0.0
	_snap_camera(false)
	_refresh_hud()
	_sync_view()


func _sync_view() -> void:
	if raid_view == null:
		return
	# Light camera kick on hits / flares only (shoot kick already removed in sim).
	var shake := float(world.get("shake", 0.0)) * 0.28
	if shake > 0.05:
		raid_view.position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	else:
		raid_view.position = Vector2.ZERO
	raid_view.call("sync", world, _view_rect().grow(180.0))


func _snap_camera(instant: bool) -> void:
	var player: Dictionary = world["player"]
	var target: Vector2 = player["pos"]
	# Keep the view inside the forest skirt so the map never hard-cuts to void.
	var half := get_viewport_rect().size * 0.5
	var z := cam.zoom if cam != null else Vector2.ONE
	half = Vector2(half.x / maxf(0.01, z.x), half.y / maxf(0.01, z.y))
	var margin := RaidSim.MAP_MARGIN
	var mw := float(world.get("width", RaidSim.MAP_W))
	var mh := float(world.get("height", RaidSim.MAP_H))
	target.x = clampf(target.x, half.x - margin, mw + margin - half.x)
	target.y = clampf(target.y, half.y - margin, mh + margin - half.y)
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
		result_label.text = "OUT\nLoot banked - +%d skill%s\nEnter - BASE" % [
			1 + bonus, " (+deeds)" if bonus > 0 else "",
		]
		result_label.add_theme_color_override("font_color", Color("3ecf8e"))
		UiStyle.apply_ok_panel(result_panel)
	elif outcome == "died":
		var lost := Items.inventory_used(world.get("dropped_loot", []))
		if lost > 0:
			result_label.text = "DOWN\nDrop bag lost - %d items\nEnter - BASE" % lost
		else:
			result_label.text = "DOWN\nEnter - BASE"
		result_label.add_theme_color_override("font_color", Color("e85454"))
		UiStyle.apply_danger_panel(result_panel)
	else:
		result_label.text = "FIELD OVER\nEnter - BASE"
		UiStyle.apply_wash(result_panel)


func _return_to_hideout() -> void:
	var result := RaidSim.finalize_raid_result(world)
	GameSession.apply_raid_result(result)


func _bag_summary(inventory: Array) -> String:
	## Top two stacks only — full bag dump stays out of the vitals chrome.
	if inventory.is_empty():
		return ""
	var parts: Array[String] = []
	var n := mini(2, inventory.size())
	for i in n:
		var stack: Dictionary = inventory[i]
		var name := Items.item_name(stack.get("def_id", ""))
		var qty := int(stack.get("qty", 1))
		parts.append("%s×%d" % [name, qty] if qty > 1 else name)
	var more := inventory.size() - n
	if more > 0:
		parts.append("+%d" % more)
	return " · ".join(parts)


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
	var hp_col := UiStyle.hp_color(hp_ratio)
	if hp_col != _hp_bar_col:
		_hp_bar_col = hp_col
		UiStyle.style_progress(hp_bar, hp_col)

	var stamina := float(player.get("stamina", 100.0))
	var stamina_max := float(player.get("stamina_max", 100.0))
	stamina_bar.max_value = stamina_max
	stamina_bar.value = stamina
	var sprinting := bool(player.get("sprinting", false))
	var exhausted := float(player.get("sprint_exhaust", 0.0)) > 0.0
	var stam_col: Color
	if exhausted:
		stamina_label.text = "—"
		stamina_label.add_theme_color_override("font_color", Color("e85454"))
		stam_col = Color(0.91, 0.33, 0.33, 1)
	elif sprinting:
		stamina_label.text = "%d" % int(ceil(stamina))
		stamina_label.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0, 1))
		stam_col = Color(0.55, 0.9, 1.0, 1)
	else:
		stamina_label.text = "%d" % int(ceil(stamina))
		stamina_label.add_theme_color_override("font_color", Color(0.55, 0.78, 0.92, 1))
		stam_col = Color(0.4, 0.78, 0.95, 1)
	if stam_col != _stam_bar_col:
		_stam_bar_col = stam_col
		UiStyle.style_progress(stamina_bar, stam_col)

	var used := Items.inventory_used(world["inventory"])
	var cap := int(world["inventory_cap"])
	bag_label.text = "BAG %d/%d" % [used, cap]
	var summary := _bag_summary(world["inventory"])
	bag_list.text = summary
	bag_list.visible = not summary.is_empty()

	var meds := Items.count_in_stacks(world["inventory"], "medkit")
	var channel := float(world["player"].get("heal_channel", 0.0))
	if channel > 0.0:
		med_label.text = "HEAL %.1fs" % channel
		med_label.add_theme_color_override("font_color", Color("e07070"))
	else:
		med_label.text = "MED ×%d" % meds
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
		ammo_label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92, 1))
	elif rch > 0.0:
		ammo_label.text = "…"
		ammo_sub.visible = true
		ammo_sub.text = "%.1fs" % rch
		ammo_label.add_theme_color_override("font_color", Color("d2b48c"))
	else:
		ammo_label.text = "%d | %d" % [mag, reserve]
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
			UiStyle.apply_wash(extract_bar_panel, Color(0.04, 0.1, 0.08, 0.62))
			UiStyle.style_progress(extract_bar, Color(0.24, 0.81, 0.56, 1))

	# Soft dusk wash — only when the cue bucket changes (avoid layout thrash).
	var dusk := float(world.get("dusk_01", 0.0))
	var dusk_bucket := floorf(dusk * 8.0)
	if dusk_bucket != _last_dusk_bucket:
		_last_dusk_bucket = dusk_bucket
		if dusk > 0.15:
			UiStyle.apply_wash(vitals_panel, Color(0.07, 0.06, 0.05, 0.78).lerp(Color(0.045, 0.06, 0.08, 0.72), 1.0 - dusk))
		else:
			UiStyle.apply_wash(vitals_panel, Color(0.045, 0.06, 0.08, 0.72))


func _draw() -> void:
	# World paint lives on RaidView (Kenney sprites). Scene keeps HUD only.
	pass


func _view_rect() -> Rect2:
	var half := get_viewport_rect().size * 0.5
	var z := cam.zoom if cam != null else Vector2.ONE
	half = Vector2(half.x / maxf(0.01, z.x), half.y / maxf(0.01, z.y))
	var center := cam.global_position if cam != null else Vector2.ZERO
	return Rect2(center - half, half * 2.0)
