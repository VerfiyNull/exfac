extends Control
## Base between runs — locker, kit, skills, deploy. Icon-first; Esc returns to title.

const Items := preload("res://scripts/systems/items.gd")
const Skills := preload("res://scripts/systems/skills.gd")
const MetaSim := preload("res://scripts/systems/meta.gd")
const UiStyle := preload("res://scripts/systems/ui_style.gd")

@onready var title_label: Label = %TitleLabel
@onready var stats_label: Label = %StatsLabel
@onready var status_label: Label = %StatusLabel
@onready var history_label: Label = %HistoryLabel
@onready var return_label: Label = %ReturnLabel
@onready var controls_hint: Label = %ControlsHint
@onready var deploy_hint: Label = %DeployHint
@onready var stash_list: ItemList = %StashList
@onready var selected_label: Label = %SelectedLabel
@onready var equip_button: Button = %EquipButton
@onready var sell_button: Button = %SellButton
@onready var salvage_button: Button = %SalvageButton
@onready var quick_kit_button: Button = %QuickKitButton
@onready var filter_all_button: Button = %FilterAllButton
@onready var filter_gear_button: Button = %FilterGearButton
@onready var filter_loot_button: Button = %FilterLootButton
@onready var weapon_label: Label = %WeaponLabel
@onready var armor_label: Label = %ArmorLabel
@onready var bag_label: Label = %BagLabel
@onready var risk_label: Label = %RiskLabel
@onready var pack_label: Label = %PackLabel
@onready var start_button: Button = %StartRaidButton
@onready var unequip_weapon_button: Button = %UnequipWeaponButton
@onready var unequip_armor_button: Button = %UnequipArmorButton
@onready var unequip_bag_button: Button = %UnequipBagButton
@onready var buy_med_button: Button = %BuyMedButton
@onready var buy_ammo_button: Button = %BuyAmmoButton
@onready var buy_flare_button: Button = %BuyFlareButton
@onready var pack_scrap_button: Button = %PackScrapButton
@onready var locker_panel: PanelContainer = %LockerPanel
@onready var kit_panel: PanelContainer = %KitPanel
@onready var skills_panel: PanelContainer = %SkillsPanel
@onready var deploy_panel: PanelContainer = %DeployPanel
@onready var skills_points: Label = %SkillsPoints
@onready var train_button: Button = %TrainButton
@onready var skills_list: VBoxContainer = %SkillsList

var _skill_rows: Dictionary = {}
var _salvage_armed := false
var _selected_skill_id: String = ""
## Locker list filter: all | gear | loot
var _locker_filter: String = "all"
## Maps visible ItemList row → stash index.
var _visible_stash_indices: Array[int] = []


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	unequip_weapon_button.pressed.connect(_on_unequip.bind("weapon_id"))
	unequip_armor_button.pressed.connect(_on_unequip.bind("armor_id"))
	unequip_bag_button.pressed.connect(_on_unequip.bind("bag_id"))
	equip_button.pressed.connect(_on_equip_pressed)
	quick_kit_button.pressed.connect(_on_quick_kit)
	sell_button.pressed.connect(_on_sell_pressed)
	salvage_button.pressed.connect(_on_salvage_pressed)
	train_button.pressed.connect(_on_train_pressed)
	buy_med_button.pressed.connect(_on_buy.bind("medkit"))
	buy_ammo_button.pressed.connect(_on_buy.bind("ammo_box"))
	buy_flare_button.pressed.connect(_on_buy.bind("mark_flare"))
	pack_scrap_button.pressed.connect(_on_pack_scrap)
	filter_all_button.pressed.connect(_set_filter.bind("all"))
	filter_gear_button.pressed.connect(_set_filter.bind("gear"))
	filter_loot_button.pressed.connect(_set_filter.bind("loot"))
	stash_list.item_selected.connect(_on_stash_selected)
	stash_list.item_activated.connect(_on_stash_activated)
	_build_skill_rows()
	_apply_styles()
	_refresh()
	stash_list.grab_focus()


func _build_skill_rows() -> void:
	for child in skills_list.get_children():
		child.queue_free()
	_skill_rows.clear()
	for skill_id in Skills.IDS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var name_l := Label.new()
		name_l.custom_minimum_size = Vector2(72, 0)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.add_theme_font_size_override("font_size", 12)
		name_l.add_theme_color_override("font_color", Color(0.88, 0.92, 0.96, 1))
		name_l.text = Skills.label(skill_id)
		name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_l.mouse_filter = Control.MOUSE_FILTER_STOP
		name_l.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed:
				_selected_skill_id = skill_id
				_refresh_skills()
		)
		var rank_l := Label.new()
		rank_l.custom_minimum_size = Vector2(56, 0)
		rank_l.add_theme_font_size_override("font_size", 12)
		rank_l.add_theme_color_override("font_color", Color(0.55, 0.62, 0.7, 1))
		rank_l.mouse_filter = Control.MOUSE_FILTER_STOP
		rank_l.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed:
				_selected_skill_id = skill_id
				_refresh_skills()
		)
		var down := Button.new()
		down.custom_minimum_size = Vector2(28, 26)
		down.text = "−"
		down.pressed.connect(_on_lower_skill.bind(skill_id))
		UiStyle.style_button(down, false)
		var up := Button.new()
		up.custom_minimum_size = Vector2(28, 26)
		up.text = "+"
		up.pressed.connect(_on_raise_skill.bind(skill_id))
		UiStyle.style_button(up, false)
		row.add_child(name_l)
		row.add_child(rank_l)
		row.add_child(down)
		row.add_child(up)
		skills_list.add_child(row)
		_skill_rows[skill_id] = {"rank": rank_l, "up": up, "down": down}


func _apply_styles() -> void:
	UiStyle.apply_wash(locker_panel, Color(0.05, 0.07, 0.095, 0.78))
	UiStyle.apply_wash(kit_panel, Color(0.05, 0.07, 0.095, 0.7))
	UiStyle.apply_wash(skills_panel, Color(0.05, 0.075, 0.095, 0.7))
	UiStyle.apply_wash(deploy_panel, Color(0.06, 0.1, 0.09, 0.82))
	UiStyle.style_button(start_button, true)
	UiStyle.style_button(equip_button, false)
	UiStyle.style_button(quick_kit_button, false)
	UiStyle.style_button(sell_button, false)
	UiStyle.style_button(salvage_button, false)
	UiStyle.style_button(train_button, false)
	UiStyle.style_button(unequip_weapon_button, false)
	UiStyle.style_button(unequip_armor_button, false)
	UiStyle.style_button(unequip_bag_button, false)
	UiStyle.style_button(buy_med_button, false)
	UiStyle.style_button(buy_ammo_button, false)
	UiStyle.style_button(buy_flare_button, false)
	UiStyle.style_button(pack_scrap_button, false)
	UiStyle.style_button(filter_all_button, false)
	UiStyle.style_button(filter_gear_button, false)
	UiStyle.style_button(filter_loot_button, false)

	var list_bg := StyleBoxFlat.new()
	list_bg.bg_color = Color(0.03, 0.042, 0.06, 0.98)
	list_bg.set_border_width_all(0)
	list_bg.set_corner_radius_all(4)
	list_bg.content_margin_left = 8
	list_bg.content_margin_right = 8
	list_bg.content_margin_top = 6
	list_bg.content_margin_bottom = 6
	stash_list.add_theme_stylebox_override("panel", list_bg)
	stash_list.add_theme_stylebox_override("focus", list_bg)
	var sel := StyleBoxFlat.new()
	sel.bg_color = Color(0.11, 0.2, 0.18, 1)
	sel.set_corner_radius_all(3)
	stash_list.add_theme_stylebox_override("selected", sel)
	stash_list.add_theme_stylebox_override("selected_focus", sel)
	stash_list.add_theme_color_override("font_color", Color(0.82, 0.88, 0.92, 1))
	stash_list.add_theme_color_override("font_hovered_color", Color(0.94, 0.97, 0.99, 1))
	stash_list.add_theme_color_override("font_selected_color", Color(0.92, 0.98, 0.94, 1))


func _process(_dt: float) -> void:
	if Input.is_action_just_pressed("pause_game"):
		GameSession.persist()
		GameSession.go_title()
		return
	if Input.is_action_just_pressed("move_down"):
		_move_stash(1)
	elif Input.is_action_just_pressed("move_up"):
		_move_stash(-1)
	elif Input.is_action_just_pressed("interact"):
		_on_equip_pressed()
	elif Input.is_action_just_pressed("equip_gear"):
		_on_quick_kit()
	elif Input.is_action_just_pressed("start_raid"):
		GameSession.go_raid()
		_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_X:
				_on_sell_pressed()
				accept_event()
			KEY_1:
				_set_filter("all")
				accept_event()
			KEY_2:
				_set_filter("gear")
				accept_event()
			KEY_3:
				_set_filter("loot")
				accept_event()
			KEY_TAB:
				# Cycle focus: locker → deploy → skills.
				if stash_list.has_focus():
					start_button.grab_focus()
				elif start_button.has_focus():
					if train_button.visible:
						train_button.grab_focus()
					else:
						stash_list.grab_focus()
				else:
					stash_list.grab_focus()
				accept_event()


func _set_filter(kind: String) -> void:
	_locker_filter = kind
	_salvage_armed = false
	_refresh()


func _move_stash(delta: int) -> void:
	if _visible_stash_indices.is_empty():
		return
	var cur_vis := 0
	var stash_idx := GameSession.selected_stash_index
	for i in _visible_stash_indices.size():
		if int(_visible_stash_indices[i]) == stash_idx:
			cur_vis = i
			break
	cur_vis = (cur_vis + delta + _visible_stash_indices.size()) % _visible_stash_indices.size()
	GameSession.selected_stash_index = int(_visible_stash_indices[cur_vis])
	_refresh()


func _selected_def() -> Dictionary:
	var stash: Array = GameSession.meta["stash"]
	if stash.is_empty():
		return {}
	var idx := clampi(GameSession.selected_stash_index, 0, stash.size() - 1)
	return Items.get_item(String(stash[idx]["def_id"]))


func _equip_selected(slot: String, expected_item_slot: String) -> void:
	var stash: Array = GameSession.meta["stash"]
	if stash.is_empty():
		GameSession.status = "Locker empty."
		_refresh()
		return
	var idx := clampi(GameSession.selected_stash_index, 0, stash.size() - 1)
	var def := Items.get_item(String(stash[idx]["def_id"]))
	if String(def["slot"]) != expected_item_slot:
		GameSession.status = "That isn't a %s." % expected_item_slot
	else:
		GameSession.status = MetaSim.equip_from_stash(GameSession.meta, slot, String(stash[idx]["def_id"]))
		GameSession.selected_stash_index = clampi(GameSession.selected_stash_index, 0, maxi(0, GameSession.meta["stash"].size() - 1))
		GameSession.persist()
	_refresh()


func _equip_selected_auto() -> void:
	var def := _selected_def()
	if def.is_empty():
		GameSession.status = "Locker empty."
		_refresh()
		return
	var slot_kind := String(def["slot"])
	if slot_kind == "weapon":
		_equip_selected("weapon_id", "weapon")
	elif slot_kind == "armor":
		_equip_selected("armor_id", "armor")
	elif slot_kind == "bag":
		_equip_selected("bag_id", "bag")
	else:
		GameSession.status = "%s packs into the field bag." % String(def["name"])
		_refresh()


func _on_equip_pressed() -> void:
	_equip_selected_auto()


func _on_quick_kit() -> void:
	GameSession.quick_kit()
	_refresh()


func _on_sell_pressed() -> void:
	_salvage_armed = false
	# One Sell action dumps the whole selected stack — no separate stack button.
	var stash: Array = GameSession.meta["stash"]
	if stash.is_empty():
		return
	var idx := clampi(GameSession.selected_stash_index, 0, stash.size() - 1)
	GameSession.sell_selected_stash(int(stash[idx]["qty"]))
	_refresh()


func _on_salvage_pressed() -> void:
	if not _salvage_armed:
		_salvage_armed = true
		salvage_button.text = "Confirm?"
		GameSession.status = "Salvage all loot? Press again to confirm."
		_refresh()
		return
	_salvage_armed = false
	GameSession.sell_all_loot()
	_refresh()


func _on_train_pressed() -> void:
	GameSession.buy_skill_point()
	_refresh()


func _on_buy(def_id: String) -> void:
	GameSession.buy_supply(def_id, 1)
	_refresh()


func _on_pack_scrap() -> void:
	## Cycle 0 → 1 → 2 → 0 scrap packed for the next deploy (decoy ammo).
	var cur := int(GameSession.meta.get("pack_scrap_qty", 0))
	var have := Items.count_in_stacks(GameSession.meta["stash"], "scrap")
	var nxt := (cur + 1) % 3
	if nxt > have:
		nxt = 0 if have <= 0 else mini(have, 2)
	GameSession.meta["pack_scrap_qty"] = nxt
	if nxt <= 0:
		GameSession.status = "No scrap packed for decoys."
	else:
		GameSession.status = "Will pack %d scrap for decoys on deploy." % nxt
	GameSession.persist()
	_refresh()


func _on_stash_activated(_index: int) -> void:
	_equip_selected_auto()


func _on_unequip(slot: String) -> void:
	GameSession.unequip_slot(slot)
	_refresh()


func _on_stash_selected(index: int) -> void:
	if index < 0 or index >= _visible_stash_indices.size():
		return
	GameSession.selected_stash_index = int(_visible_stash_indices[index])
	_refresh_selected()


func _on_start_pressed() -> void:
	GameSession.go_raid()
	_refresh()


func _on_raise_skill(skill_id: String) -> void:
	_selected_skill_id = skill_id
	GameSession.raise_skill(skill_id)
	_refresh()


func _on_lower_skill(skill_id: String) -> void:
	_selected_skill_id = skill_id
	GameSession.lower_skill(skill_id)
	_refresh()


func _slot_line(def_id: Variant, empty_text: String = "—") -> String:
	if def_id == null or String(def_id).is_empty():
		return empty_text
	return Items.item_name(def_id)


func _passes_filter(slot_kind: String) -> bool:
	match _locker_filter:
		"gear":
			return slot_kind == "weapon" or slot_kind == "armor" or slot_kind == "bag"
		"loot":
			return slot_kind == "loot"
		_:
			return true


func _refresh_selected() -> void:
	var stash: Array = GameSession.meta["stash"]
	if stash.is_empty() or _visible_stash_indices.is_empty():
		selected_label.text = "Empty"
		equip_button.disabled = true
		sell_button.disabled = true
		salvage_button.disabled = true
		return
	var idx := clampi(GameSession.selected_stash_index, 0, stash.size() - 1)
	var stack: Dictionary = stash[idx]
	var def := Items.get_item(String(stack["def_id"]))
	var slot := String(def["slot"])
	var price := MetaSim.sell_price(String(stack["def_id"]))
	var qty := int(stack["qty"])
	selected_label.text = "%s  ×%d  ·  %d cr" % [String(def["name"]), qty, price * qty]
	sell_button.disabled = false
	sell_button.text = "Sell"
	var has_loot := false
	for s in stash:
		if String(Items.get_item(String(s["def_id"])).get("slot", "")) == "loot":
			has_loot = true
			break
	salvage_button.disabled = not has_loot
	equip_button.disabled = not (slot == "weapon" or slot == "armor" or slot == "bag")
	equip_button.text = "Equip" if not equip_button.disabled else "—"


func _refresh_skills() -> void:
	var skills := Skills.ensure(GameSession.meta)
	var pts := int(skills.get("points", 0))
	if _selected_skill_id.is_empty() and not Skills.IDS.is_empty():
		_selected_skill_id = String(Skills.IDS[0])
	var blurb := Skills.blurb(_selected_skill_id)
	skills_points.text = "%d pt%s — %s" % [pts, "" if pts == 1 else "s", blurb]
	var cost := MetaSim.SKILL_POINT_INFLUENCE_COST
	var can_train := int(GameSession.meta["influence"]) >= cost
	train_button.visible = can_train
	train_button.text = "Train %d" % cost
	train_button.disabled = not can_train
	for skill_id in Skills.IDS:
		var row: Dictionary = _skill_rows[skill_id]
		var r := Skills.rank(skills, skill_id)
		var marks := ""
		for i in Skills.MAX_RANK:
			marks += "●" if i < r else "○"
		var selected := skill_id == _selected_skill_id
		(row["rank"] as Label).text = marks
		(row["rank"] as Label).add_theme_color_override(
			"font_color",
			Color(0.85, 0.92, 0.78, 1) if selected else Color(0.55, 0.62, 0.7, 1)
		)
		var up: Button = row["up"]
		var down: Button = row["down"]
		up.disabled = pts <= 0 or r >= Skills.MAX_RANK
		up.text = "·" if r >= Skills.MAX_RANK else "+"
		down.disabled = r <= 0


func _refresh_filter_buttons() -> void:
	filter_all_button.text = "[All]" if _locker_filter == "all" else "All"
	filter_gear_button.text = "[Gear]" if _locker_filter == "gear" else "Gear"
	filter_loot_button.text = "[Loot]" if _locker_filter == "loot" else "Loot"


func _refresh() -> void:
	var meta := GameSession.meta
	Skills.ensure(meta)
	var loadout: Dictionary = meta["loadout"]
	title_label.text = "BASE"
	stats_label.text = "%d cr  ·  %d inf  ·  locker %d  ·  runs %d" % [
		int(meta["credits"]),
		int(meta["influence"]),
		Items.loot_influence_value(meta["stash"]),
		int(meta["raids_completed"]),
	]
	# One quiet strip — status + optional stipend + last return; history alone on the right.
	var bits: Array[String] = []
	if not GameSession.status.is_empty():
		bits.append(GameSession.status)
	if not GameSession.stipend_note.is_empty():
		bits.append(GameSession.stipend_note)
	var ret := GameSession.format_raid_return(GameSession.last_raid_result)
	if not ret.is_empty():
		bits.append(ret)
	status_label.text = "  ·  ".join(bits)
	var hist := GameSession.format_raid_history()
	history_label.text = hist
	history_label.visible = not hist.is_empty()
	return_label.visible = false
	return_label.text = ""
	controls_hint.text = "W/S · E equip · X sell · F kit · 1/2/3 filter · Tab · Enter deploy"

	weapon_label.text = Items.weapon_slot_name(loadout.get("weapon_id"))
	armor_label.text = _slot_line(loadout.get("armor_id"))
	bag_label.text = _slot_line(loadout.get("bag_id"), "Pockets")
	# Armor pip — durability still matters even when UI stays quiet.
	var armor_id: Variant = loadout.get("armor_id")
	if armor_id != null and not String(armor_id).is_empty():
		var adef := Items.get_item(String(armor_id))
		armor_label.text = "%s  ·  %d%% mit" % [
			Items.item_name(armor_id),
			int(round(float(adef.get("mitigation", 0.0)) * 100.0)),
		]
	risk_label.text = "At risk %d cr" % MetaSim.loadout_at_risk_value(loadout)
	unequip_weapon_button.disabled = loadout.get("weapon_id") == null or String(loadout.get("weapon_id")).is_empty()
	unequip_armor_button.disabled = loadout.get("armor_id") == null or String(loadout.get("armor_id")).is_empty()
	unequip_bag_button.disabled = loadout.get("bag_id") == null or String(loadout.get("bag_id")).is_empty()

	var bag_cap := Items.loadout_capacity(loadout) + Skills.bag_bonus(meta["skills"])
	var meds := mini(2, Items.count_in_stacks(meta["stash"], "medkit"))
	var scrap_pack := int(meta.get("pack_scrap_qty", 0))
	var has_weapon := Items.loadout_has_weapon(loadout)
	pack_label.text = "Bag %d  ·  Med ×%d  ·  Scrap %d" % [bag_cap, meds, scrap_pack]
	pack_label.add_theme_color_override("font_color", Color(0.55, 0.66, 0.74, 1))

	var credits := int(meta["credits"])
	buy_med_button.text = "Med %d" % MetaSim.buy_price("medkit")
	buy_ammo_button.text = "Ammo %d" % MetaSim.buy_price("ammo_box")
	buy_flare_button.text = "Flare %d" % MetaSim.buy_price("mark_flare")
	buy_med_button.disabled = credits < MetaSim.buy_price("medkit")
	buy_ammo_button.disabled = credits < MetaSim.buy_price("ammo_box")
	buy_flare_button.disabled = credits < MetaSim.buy_price("mark_flare")
	var scrap_have := Items.count_in_stacks(meta["stash"], "scrap")
	pack_scrap_button.disabled = scrap_have <= 0 and scrap_pack <= 0
	pack_scrap_button.text = "Scrap ×%d" % scrap_pack if scrap_pack > 0 else "Scrap"

	start_button.disabled = false
	start_button.text = "DEPLOY"
	if has_weapon:
		deploy_hint.text = "Ready — strip W anytime to go fists."
		deploy_hint.add_theme_color_override("font_color", Color(0.55, 0.7, 0.62, 1))
	else:
		deploy_hint.text = "Unarmed — LMB punches in the field."
		deploy_hint.add_theme_color_override("font_color", Color("e6b35a"))

	if not _salvage_armed:
		salvage_button.text = "Salvage"

	_refresh_filter_buttons()
	_refresh_skills()
	# Keep selection by item identity — sort reorder must not retarget Sell/Equip.
	var selected_def := ""
	var stash_pre: Array = meta["stash"]
	if not stash_pre.is_empty():
		var si := clampi(GameSession.selected_stash_index, 0, stash_pre.size() - 1)
		selected_def = String(stash_pre[si].get("def_id", ""))
	Items.sort_stash(meta["stash"])
	if not selected_def.is_empty():
		var remapped := Items.index_of_def(meta["stash"], selected_def)
		if remapped >= 0:
			GameSession.selected_stash_index = remapped
	stash_list.clear()
	_visible_stash_indices.clear()
	var stash: Array = meta["stash"]
	var selected_vis := -1
	for i in stash.size():
		var s: Dictionary = stash[i]
		var def := Items.get_item(String(s["def_id"]))
		var slot_kind := String(def["slot"])
		if not _passes_filter(slot_kind):
			continue
		var mark := "·"
		match slot_kind:
			"weapon":
				mark = "W"
			"armor":
				mark = "A"
			"bag":
				mark = "B"
		var row := stash_list.add_item("%s  %s ×%d" % [mark, String(def["name"]), int(s["qty"])])
		stash_list.set_item_custom_fg_color(row, def["color"])
		_visible_stash_indices.append(i)
		if i == GameSession.selected_stash_index:
			selected_vis = row
	if not _visible_stash_indices.is_empty():
		if selected_vis < 0:
			# Selection filtered out — snap to first visible.
			GameSession.selected_stash_index = int(_visible_stash_indices[0])
			selected_vis = 0
		stash_list.select(selected_vis)
	_refresh_selected()
