class_name SaveGame
extends RefCounted
## Solo persistence — locker, loadout, skills, run counters. Sanitize unknown ids on load.

const SAVE_PATH := "user://exfac_save.json"
const SAVE_TMP_PATH := "user://exfac_save.json.tmp"
const SAVE_VERSION := 2

## Last load failure reason (empty on success). Title/session use this for corrupt-save UX.
static var last_load_error: String = ""


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func delete_save() -> bool:
	if not has_save():
		return true
	var err := DirAccess.remove_absolute(SAVE_PATH)
	if err != OK and has_save():
		push_error("SaveGame: delete failed for %s (%s)" % [SAVE_PATH, error_string(err)])
		return false
	return true


## Move a bad save aside so Continue doesn't keep offering a broken file.
static func quarantine_save() -> void:
	if not has_save():
		return
	var bad := "user://exfac_save.bad.json"
	DirAccess.remove_absolute(bad)
	var err := DirAccess.rename_absolute(SAVE_PATH, bad)
	if err != OK:
		push_error("SaveGame: quarantine rename failed (%s)" % error_string(err))
		delete_save()


static func save_meta(meta: Dictionary, last_raid: Dictionary = {}, raid_history: Array = []) -> bool:
	Skills.ensure(meta)
	var hist_out: Array = []
	for entry in raid_history:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		hist_out.append(_sanitize_raid_result(entry))
	var payload := {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"meta": _sanitize_meta(meta),
		"last_raid": _sanitize_raid_result(last_raid),
		"raid_history": hist_out,
	}
	var json := JSON.stringify(payload)
	# Atomic replace — crash mid-write must not truncate the real save.
	var f := FileAccess.open(SAVE_TMP_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveGame: failed to open %s (%s)" % [SAVE_TMP_PATH, FileAccess.get_open_error()])
		return false
	f.store_string(json)
	f.close()
	var err := DirAccess.rename_absolute(SAVE_TMP_PATH, SAVE_PATH)
	if err != OK:
		# Some platforms can't rename over an existing file — remove then rename.
		DirAccess.remove_absolute(SAVE_PATH)
		err = DirAccess.rename_absolute(SAVE_TMP_PATH, SAVE_PATH)
	if err != OK:
		push_error("SaveGame: atomic replace failed (%s)" % error_string(err))
		return false
	return true


static func load_bundle() -> Dictionary:
	## Returns { "meta": Dictionary, "last_raid": Dictionary, "raid_history": Array } or empty on failure.
	last_load_error = ""
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		last_load_error = "unreadable"
		push_error("SaveGame: failed to read %s (%s)" % [SAVE_PATH, FileAccess.get_open_error()])
		return {}
	var raw := f.get_as_text()
	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		last_load_error = "corrupt"
		push_error("SaveGame: corrupt save (not an object).")
		return {}
	var root: Dictionary = parsed
	var ver := int(root.get("version", 0))
	if ver < 1 or ver > SAVE_VERSION:
		last_load_error = "unsupported"
		push_error("SaveGame: unsupported version %s" % str(root.get("version")))
		return {}
	var meta_raw: Variant = root.get("meta", {})
	if typeof(meta_raw) != TYPE_DICTIONARY:
		last_load_error = "corrupt"
		return {}
	var raid_raw: Variant = root.get("last_raid", {})
	var last_raid: Dictionary = {}
	if typeof(raid_raw) == TYPE_DICTIONARY:
		last_raid = _hydrate_raid_result(raid_raw)
	var history: Array = []
	var hist_raw: Variant = root.get("raid_history", [])
	if typeof(hist_raw) == TYPE_ARRAY:
		for entry in hist_raw:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var hydrated := _hydrate_raid_result(entry)
			if not hydrated.is_empty():
				history.append(hydrated)
	return {
		"meta": _hydrate_meta(meta_raw),
		"last_raid": last_raid,
		"raid_history": history,
	}


static func load_meta() -> Dictionary:
	var bundle := load_bundle()
	if bundle.is_empty():
		return {}
	return bundle.get("meta", {})


static func summarize(meta: Dictionary) -> String:
	if meta.is_empty():
		return ""
	Skills.ensure(meta)
	return "%d raids  ·  %d cr  ·  %d skill pts" % [
		int(meta.get("raids_completed", 0)),
		int(meta.get("credits", 0)),
		int(meta["skills"].get("points", 0)),
	]


static func _sanitize_meta(meta: Dictionary) -> Dictionary:
	# JSON-safe copy — no Godot Objects, only primitives / arrays / dicts.
	var stash_out: Array = []
	for s in meta.get("stash", []):
		if typeof(s) != TYPE_DICTIONARY:
			continue
		stash_out.append({
			"def_id": String(s.get("def_id", "")),
			"qty": int(s.get("qty", 0)),
		})
	var loadout: Dictionary = meta.get("loadout", {})
	var skills: Dictionary = meta.get("skills", Skills.create_state())
	var ranks_out := {}
	var ranks: Dictionary = skills.get("ranks", {})
	for id in Skills.IDS:
		ranks_out[id] = int(ranks.get(id, 0))
	return {
		"stash": stash_out,
		"loadout": {
			"weapon_id": _slot_or_null(loadout.get("weapon_id")),
			"armor_id": _slot_or_null(loadout.get("armor_id")),
			"bag_id": _slot_or_null(loadout.get("bag_id")),
		},
		"skills": {
			"points": int(skills.get("points", 0)),
			"ranks": ranks_out,
		},
		"influence": int(meta.get("influence", 0)),
		"credits": int(meta.get("credits", 0)),
		"hub_visit_id": int(meta.get("hub_visit_id", 0)),
		"raids_completed": int(meta.get("raids_completed", 0)),
		"raids_survived": int(meta.get("raids_survived", 0)),
		"pack_scrap_qty": clampi(int(meta.get("pack_scrap_qty", 0)), 0, 2),
		# In-flight deploy packs — must survive quit between Base → Field.
		"packed_medkits": clampi(int(meta.get("packed_medkits", 0)), 0, 2),
		"packed_scrap": clampi(int(meta.get("packed_scrap", 0)), 0, 2),
	}


static func _hydrate_meta(raw: Dictionary) -> Dictionary:
	var base := MetaSim.create_meta_state()
	var stash_in: Array = raw.get("stash", [])
	var stash: Array = []
	for s in stash_in:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var def_id := _migrate_item_id(String(s.get("def_id", "")))
		if def_id.is_empty():
			continue
		# Skip unknown ids so old saves don't crash the catalog assert.
		if not _item_exists(def_id):
			continue
		var qty := int(s.get("qty", 0))
		if qty <= 0:
			continue
		# Merge duplicate rows so count_in_stacks / pack logic stay honest.
		Items.add_to_stash(stash, {"def_id": def_id, "qty": qty})
	base["stash"] = stash

	var loadout_raw: Dictionary = raw.get("loadout", {})
	base["loadout"] = {
		"weapon_id": _valid_slot(loadout_raw.get("weapon_id"), "weapon"),
		"armor_id": _valid_slot(loadout_raw.get("armor_id"), "armor"),
		"bag_id": _valid_slot(loadout_raw.get("bag_id"), "bag"),
	}

	var skills := Skills.create_state()
	var skills_raw: Dictionary = raw.get("skills", {})
	skills["points"] = maxi(0, int(skills_raw.get("points", 0)))
	var ranks_raw: Dictionary = skills_raw.get("ranks", {})
	for id in Skills.IDS:
		skills["ranks"][id] = clampi(int(ranks_raw.get(id, 0)), 0, Skills.MAX_RANK)
	base["skills"] = skills

	base["influence"] = maxi(0, int(raw.get("influence", base["influence"])))
	base["credits"] = maxi(0, int(raw.get("credits", base["credits"])))
	base["hub_visit_id"] = maxi(0, int(raw.get("hub_visit_id", 0)))
	base["raids_completed"] = maxi(0, int(raw.get("raids_completed", 0)))
	base["raids_survived"] = maxi(0, int(raw.get("raids_survived", 0)))
	base["pack_scrap_qty"] = clampi(int(raw.get("pack_scrap_qty", 0)), 0, 2)
	base["packed_medkits"] = clampi(int(raw.get("packed_medkits", 0)), 0, 2)
	base["packed_scrap"] = clampi(int(raw.get("packed_scrap", 0)), 0, 2)
	return base


static func _slot_or_null(v: Variant) -> Variant:
	if v == null:
		return null
	var s := String(v)
	if s.is_empty() or s == "<null>":
		return null
	return s


static func _valid_slot(v: Variant, expected_slot: String) -> Variant:
	var id: Variant = _slot_or_null(v)
	if id == null:
		return null
	id = _migrate_item_id(String(id))
	if not _item_exists(String(id)):
		return null
	var def := Items.get_item(String(id))
	if String(def.get("slot", "")) != expected_slot:
		return null
	return String(id)



static func _migrate_item_id(def_id: String) -> String:
	## Old catalog ids → current EXFac-native ids.
	match def_id:
		"raid_rifle":
			return "patrol_rifle"
		"raid_pack":
			return "field_pack"
		_:
			return def_id


static func _item_exists(def_id: String) -> bool:
	return Items.has_item(def_id)


static func _sanitize_stacks(stacks: Array) -> Array:
	var out: Array = []
	for s in stacks:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var def_id := _migrate_item_id(String(s.get("def_id", "")))
		var qty := int(s.get("qty", 0))
		if def_id.is_empty() or qty <= 0 or not _item_exists(def_id):
			continue
		out.append({"def_id": def_id, "qty": qty})
	return out


static func _sanitize_raid_result(result: Dictionary) -> Dictionary:
	if result.is_empty():
		return {}
	return {
		"outcome": String(result.get("outcome", "")),
		"loot": _sanitize_stacks(result.get("loot", [])),
		"dropped": _sanitize_stacks(result.get("dropped", [])),
		"influence_gained": int(result.get("influence_gained", 0)),
		"skill_bonus": int(result.get("skill_bonus", 0)),
		"message": String(result.get("message", "")),
	}


static func _hydrate_raid_result(raw: Dictionary) -> Dictionary:
	var outcome := String(raw.get("outcome", ""))
	if outcome.is_empty():
		return {}
	var loot: Array = []
	for s in _sanitize_stacks(raw.get("loot", [])):
		if _item_exists(String(s["def_id"])):
			loot.append(s)
	var dropped: Array = []
	for s in _sanitize_stacks(raw.get("dropped", [])):
		if _item_exists(String(s["def_id"])):
			dropped.append(s)
	return {
		"outcome": outcome,
		"loot": loot,
		"dropped": dropped,
		"influence_gained": int(raw.get("influence_gained", 0)),
		"skill_bonus": int(raw.get("skill_bonus", 0)),
		"message": String(raw.get("message", "")),
	}
