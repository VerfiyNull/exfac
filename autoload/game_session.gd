extends Node
## Persistent solo session: meta economy + scene transitions + local save.

# Explicit preloads — headless / fresh clone has no global class_name cache yet.
const Items := preload("res://scripts/systems/items.gd")
const Skills := preload("res://scripts/systems/skills.gd")
const MetaSim := preload("res://scripts/systems/meta.gd")
const SaveGame := preload("res://scripts/systems/save.gd")

## Bump when shipping a build players should be able to spot on the title screen.
const APP_VERSION := "0.3.5"
const RAID_HISTORY_MAX := 8

var meta: Dictionary = {}
var status: String = "Kit up from the locker, then deploy."
var stipend_note: String = ""
var selected_stash_index: int = 0
var last_raid_result: Dictionary = {}
var raid_history: Array = []
var loaded_from_save := false
## Teach-once field tips this session (stance / intel pulse).
var field_taught: Dictionary = {}


func consume_teach(key: String) -> bool:
	## True the first time this tip fires; silent after.
	if bool(field_taught.get(key, false)):
		return false
	field_taught[key] = true
	return true


func _ready() -> void:
	_boot_meta(false)


func _boot_meta(force_new: bool) -> void:
	loaded_from_save = false
	last_raid_result = {}
	raid_history = []
	var save_was_bad := false
	if not force_new and SaveGame.has_save():
		var bundle := SaveGame.load_bundle()
		if not bundle.is_empty():
			meta = bundle.get("meta", {})
			last_raid_result = bundle.get("last_raid", {})
			raid_history = bundle.get("raid_history", [])
			Skills.ensure(meta)
			loaded_from_save = true
			status = "Welcome back."
			stipend_note = ""
			selected_stash_index = 0
			return
		# Corrupt / unsupported file — quarantine so Continue doesn't keep lying.
		SaveGame.quarantine_save()
		save_was_bad = true
	meta = MetaSim.create_meta_state()
	Skills.ensure(meta)
	var stipend := MetaSim.begin_hub_visit(meta)
	if stipend > 0:
		stipend_note = "+%d credits" % stipend
	else:
		stipend_note = ""
	status = "Save unreadable — started a fresh run." if save_was_bad else "Kit up from the locker, then deploy."
	selected_stash_index = 0


func persist() -> bool:
	Skills.ensure(meta)
	return SaveGame.save_meta(meta, last_raid_result, raid_history)


func start_new_run() -> void:
	SaveGame.delete_save()
	_boot_meta(true)
	persist()
	go_hideout()


func continue_run() -> void:
	if not loaded_from_save:
		_boot_meta(false)
	go_hideout()


func go_title() -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/title.tscn")


func go_hideout() -> void:
	get_tree().change_scene_to_file.call_deferred("res://scenes/hideout.tscn")


func go_raid() -> void:
	Skills.ensure(meta)
	# Kit is intentional — do not auto-restock empty weapon/armor/bag from locker on deploy
	# (that was re-arming fists-only runs). Death recovery still restocks in apply_raid_result.
	var weapon: Variant = meta["loadout"].get("weapon_id")
	var bag: Variant = meta["loadout"].get("bag_id")
	if weapon == null or String(weapon).is_empty():
		status = "Deploying unarmed — fists only."
	elif bag == null or String(bag).is_empty():
		status = "Deploying with pockets only — equip a bag for more slots."
	else:
		status = "Field live."
	# Pack up to 2 medkits from locker into the field bag (consumed from locker).
	var packed := 0
	while packed < 2 and Items.remove_from_stash(meta["stash"], "medkit", 1):
		packed += 1
	meta["packed_medkits"] = packed
	if packed > 0:
		status = "%s Packed %d medkit(s)." % [status, packed]
	# Scrap for decoys — only if BASE armed Pack scrap.
	var want_scrap := int(meta.get("pack_scrap_qty", 0))
	var packed_scrap := 0
	while packed_scrap < want_scrap and Items.remove_from_stash(meta["stash"], "scrap", 1):
		packed_scrap += 1
	meta["packed_scrap"] = packed_scrap
	meta["pack_scrap_qty"] = 0
	if packed_scrap > 0:
		status = "%s Packed %d scrap." % [status, packed_scrap]
	persist()
	get_tree().change_scene_to_file.call_deferred("res://scenes/raid.tscn")


func apply_raid_result(result: Dictionary) -> void:
	last_raid_result = result
	_push_raid_history(result)
	Skills.ensure(meta)
	meta["raids_completed"] = int(meta["raids_completed"]) + 1
	if String(result["outcome"]) == "extracted":
		meta["raids_survived"] = int(meta["raids_survived"]) + 1
		for stack in result["loot"]:
			Items.add_to_stash(meta["stash"], stack)
		meta["influence"] = int(meta["influence"]) + int(result["influence_gained"])
		var gained := Skills.award_extract(meta["skills"], int(result.get("skill_bonus", 0)))
		status = "%s  +%d skill pt" % [String(result["message"]), gained]
	elif String(result["outcome"]) == "died":
		MetaSim.lose_loadout_on_death(meta)
		var restock := MetaSim.restock_loadout_from_stash(meta)
		status = "%s %s" % [String(result["message"]), restock]
	else:
		status = String(result["message"])

	var stipend := MetaSim.begin_hub_visit(meta)
	stipend_note = "+%d credits" % stipend if stipend > 0 else ""
	var stash: Array = meta["stash"]
	if stash.is_empty():
		selected_stash_index = 0
	else:
		selected_stash_index = mini(selected_stash_index, stash.size() - 1)
	persist()
	go_hideout()


func _push_raid_history(result: Dictionary) -> void:
	if result.is_empty():
		return
	var copy := {
		"outcome": String(result.get("outcome", "")),
		"loot": result.get("loot", []),
		"dropped": result.get("dropped", []),
		"influence_gained": int(result.get("influence_gained", 0)),
		"skill_bonus": int(result.get("skill_bonus", 0)),
		"message": String(result.get("message", "")),
	}
	raid_history.push_front(copy)
	while raid_history.size() > RAID_HISTORY_MAX:
		raid_history.pop_back()


func raise_skill(skill_id: String) -> void:
	Skills.ensure(meta)
	status = Skills.try_raise(meta["skills"], skill_id)
	persist()


func lower_skill(skill_id: String) -> void:
	Skills.ensure(meta)
	status = Skills.try_lower(meta["skills"], skill_id)
	persist()


func quick_kit() -> void:
	status = MetaSim.quick_kit_from_stash(meta)
	persist()


func sell_selected_stash(qty: int = 1) -> void:
	var stash: Array = meta["stash"]
	if stash.is_empty():
		status = "Locker empty."
		return
	var idx := clampi(selected_stash_index, 0, stash.size() - 1)
	var def_id := String(stash[idx]["def_id"])
	status = MetaSim.sell_from_stash(meta, def_id, qty)
	selected_stash_index = clampi(selected_stash_index, 0, maxi(0, meta["stash"].size() - 1))
	persist()


func sell_all_loot() -> void:
	status = MetaSim.sell_all_loot(meta)
	selected_stash_index = clampi(selected_stash_index, 0, maxi(0, meta["stash"].size() - 1))
	persist()


func buy_skill_point() -> void:
	status = MetaSim.buy_skill_point(meta)
	persist()


func buy_supply(def_id: String, qty: int = 1) -> void:
	status = MetaSim.buy_to_stash(meta, def_id, qty)
	persist()


func unequip_slot(slot: String) -> void:
	status = MetaSim.unequip_to_stash(meta, slot)
	persist()


func format_raid_return(result: Dictionary) -> String:
	if result.is_empty():
		return ""
	var outcome := String(result.get("outcome", ""))
	match outcome:
		"extracted":
			var n := 0
			for s in result.get("loot", []):
				n += int(s.get("qty", 0))
			var bonus := int(result.get("skill_bonus", 0))
			var bonus_bit := "  ·  +%d skill bonus" % bonus if bonus > 0 else ""
			return "LAST  out  ·  %d items  ·  +%d inf%s" % [
				n, int(result.get("influence_gained", 0)), bonus_bit,
			]
		"died":
			var lost := 0
			for s in result.get("dropped", []):
				lost += int(s.get("qty", 0))
			return "LAST  down  ·  drop bag %d items" % lost
		_:
			return "LAST  %s" % outcome


func format_raid_history(history: Array = raid_history) -> String:
	if history.is_empty():
		return ""
	var marks: PackedStringArray = []
	for entry in history:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		match String(entry.get("outcome", "")):
			"extracted":
				marks.append("O")
			"died":
				marks.append("D")
			_:
				marks.append("·")
	if marks.is_empty():
		return ""
	return "FIELD  %s" % "  ".join(marks)
