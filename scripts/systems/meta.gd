class_name MetaSim
extends RefCounted
## Between-run economy: locker, loadout risk, requisition, skill training. Scenes call this — never mutate meta from raw dicts in UI.

# Explicit preloads — headless / fresh clone has no global class_name cache yet.
const Items := preload("res://scripts/systems/items.gd")
const Skills := preload("res://scripts/systems/skills.gd")

const EGRESS_INFLUENCE_BASE := 35
const EXTRACT_INFLUENCE_BASE := EGRESS_INFLUENCE_BASE  ## legacy alias
const BASE_VISIT_CREDITS := 10
const HIDEOUT_VISIT_CREDITS := BASE_VISIT_CREDITS  ## legacy alias
## Spend influence at BASE to buy a skill point when field exits are scarce.
const SKILL_POINT_INFLUENCE_COST := 60


static func create_meta_state() -> Dictionary:
	var loadout := {
		"weapon_id": "rusty_smg",
		"armor_id": "cloth_armor",
		"bag_id": "sling_bag",
	}
	var stash := Items.default_starter_stash()
	# Equipped kit is at risk — keep it out of the stash.
	var filtered: Array = []
	for s in stash:
		var id: String = String(s["def_id"])
		if id == loadout["weapon_id"] or id == loadout["armor_id"] or id == loadout["bag_id"]:
			continue
		filtered.append(s)
	return {
		"stash": filtered,
		"loadout": loadout,
		"skills": Skills.create_state(),
		"influence": 80,
		"credits": 100,
		"hub_visit_id": 0,
		"raids_completed": 0,
		"raids_survived": 0,
		"pack_scrap_qty": 0,
		"packed_medkits": 0,
		"packed_scrap": 0,
	}


static func begin_hub_visit(meta: Dictionary) -> int:
	meta["hub_visit_id"] = int(meta["hub_visit_id"]) + 1
	# Small BASE upkeep stipend — claims stay off for now.
	if int(meta["hub_visit_id"]) <= 1:
		return 0
	meta["credits"] = int(meta["credits"]) + BASE_VISIT_CREDITS
	return BASE_VISIT_CREDITS


static func equip_from_stash(meta: Dictionary, slot: String, def_id: String) -> String:
	var loadout: Dictionary = meta["loadout"]
	var current: Variant = loadout.get(slot)
	var name := Items.item_name(def_id)
	var expected := _loadout_slot_kind(slot)
	if expected.is_empty():
		return "Unknown kit slot."
	var def := Items.get_item(def_id)
	if String(def.get("slot", "")) != expected:
		return "%s can't go in that slot." % name
	if current != null and String(current) == def_id:
		return "Already equipped %s." % name
	if not Items.remove_from_stash(meta["stash"], def_id, 1):
		return "No %s in locker." % name
	if current != null and not String(current).is_empty():
		Items.add_to_stash(meta["stash"], Items.stack_of(String(current), 1))
	loadout[slot] = def_id
	return "Equipped %s." % name


static func _loadout_slot_kind(slot: String) -> String:
	match slot:
		"weapon_id":
			return "weapon"
		"armor_id":
			return "armor"
		"bag_id":
			return "bag"
		_:
			return ""


static func unequip_to_stash(meta: Dictionary, slot: String) -> String:
	var loadout: Dictionary = meta["loadout"]
	var current: Variant = loadout.get(slot)
	if current == null or String(current).is_empty():
		return "Nothing equipped."
	Items.add_to_stash(meta["stash"], Items.stack_of(String(current), 1))
	loadout[slot] = null
	return "Unequipped %s." % Items.item_name(current)


static func lose_loadout_on_death(meta: Dictionary) -> void:
	var loadout: Dictionary = meta["loadout"]
	loadout["weapon_id"] = null
	loadout["armor_id"] = null
	loadout["bag_id"] = null


static func ensure_bare_minimum_kit(meta: Dictionary) -> void:
	## Guns are optional — broke runners can stay on fists; no free sidearm forever.
	pass


static func restock_loadout_from_stash(meta: Dictionary) -> String:
	var notes: Array[String] = []
	var loadout: Dictionary = meta["loadout"]

	var try_slot := func(slot: String, ids: Array) -> void:
		var cur: Variant = loadout.get(slot)
		if cur != null and not String(cur).is_empty():
			return
		for id in ids:
			if Items.remove_from_stash(meta["stash"], String(id), 1):
				loadout[slot] = String(id)
				notes.append(Items.item_name(id))
				return

	try_slot.call("weapon_id", ["coil_carbine", "patrol_rifle", "rusty_smg", "field_pistol"])
	try_slot.call("armor_id", ["plate_vest", "mesh_carrier", "cloth_armor"])
	try_slot.call("bag_id", ["field_pack", "sling_bag"])
	if notes.is_empty():
		var wid: Variant = loadout.get("weapon_id")
		if wid != null and not String(wid).is_empty():
			return "Still carrying %s." % Items.item_name(wid)
		return "No kit left — deploying unarmed is fine."
	return "Re-equipped from locker: %s." % ", ".join(notes)


static func describe_loadout(loadout: Dictionary) -> String:
	return "%s / %s / %s" % [
		Items.weapon_slot_name(loadout.get("weapon_id")),
		Items.item_name(loadout.get("armor_id")),
		Items.item_name(loadout.get("bag_id")),
	]


static func gear_score(def_id: Variant) -> float:
	## Quick-kit weights — damage for guns; mit+dur for armor; capacity for bags.
	## Value is a tiny tie-break so equal DPS still prefers the richer piece.
	if def_id == null or String(def_id).is_empty():
		return -1.0
	var def := Items.get_item(String(def_id))
	var tie := float(def.get("value", 0)) * 0.001
	match String(def.get("slot", "")):
		"weapon":
			return float(def.get("damage", 0.0)) + tie
		"armor":
			# Armor preferred over equal-value weapons when slots are independent.
			return float(def.get("mitigation", 0.0)) * 100.0 + float(def.get("durability", 0.0)) * 0.01 + tie
		"bag":
			return float(def.get("capacity", 0)) + tie
		_:
			return float(def.get("value", 0))


static func loadout_at_risk_value(loadout: Dictionary) -> int:
	var total := 0
	for key in ["weapon_id", "armor_id", "bag_id"]:
		var id: Variant = loadout.get(key)
		if id == null or String(id).is_empty():
			continue
		total += sell_price(String(id))
	return total


static func _best_stash_id_for_slot(stash: Array, item_slot: String) -> String:
	var best_id := ""
	var best_score := -1.0
	for s in stash:
		var def_id := String(s["def_id"])
		var def := Items.get_item(def_id)
		if String(def.get("slot", "")) != item_slot:
			continue
		var score := gear_score(def_id)
		if score > best_score:
			best_score = score
			best_id = def_id
	return best_id


static func quick_kit_from_stash(meta: Dictionary) -> String:
	## Equip the best weapon/armor/bag in the locker when it beats what's on body.
	var changed: Array[String] = []
	var mapping := {
		"weapon_id": "weapon",
		"armor_id": "armor",
		"bag_id": "bag",
	}
	for loadout_slot in mapping.keys():
		var item_slot: String = mapping[loadout_slot]
		var best := _best_stash_id_for_slot(meta["stash"], item_slot)
		if best.is_empty():
			continue
		var cur: Variant = meta["loadout"].get(loadout_slot)
		if gear_score(best) <= gear_score(cur):
			continue
		var note := equip_from_stash(meta, String(loadout_slot), best)
		if note.begins_with("Equipped"):
			changed.append(Items.item_name(best))
	if changed.is_empty():
		return "Already wearing the best kit in locker."
	return "Quick kit: %s." % ", ".join(changed)


static func sell_price(def_id: String) -> int:
	return maxi(1, int(Items.get_item(def_id).get("value", 1)))


static func buy_price(def_id: String) -> int:
	# Markup so flipping loot isn't free — credits stay meaningful.
	return maxi(2, int(ceil(float(sell_price(def_id)) * 1.55)))


static func sell_from_stash(meta: Dictionary, def_id: String, qty: int = 1) -> String:
	qty = maxi(1, qty)
	if not Items.has_item(def_id):
		return "Unknown item."
	if not Items.remove_from_stash(meta["stash"], def_id, qty):
		return "Not enough %s in stash." % Items.item_name(def_id)
	var gained := sell_price(def_id) * qty
	meta["credits"] = int(meta["credits"]) + gained
	return "Sold %s ×%d  (+%d cr)." % [Items.item_name(def_id), qty, gained]


static func buy_to_stash(meta: Dictionary, def_id: String, qty: int = 1) -> String:
	qty = maxi(1, qty)
	if not Items.has_item(def_id):
		return "Unknown item."
	# Stores stock consumables only — gear comes from the field.
	var slot := String(Items.get_item(def_id).get("slot", ""))
	if slot != "loot":
		return "Stores only stock field consumables."
	var cost := buy_price(def_id) * qty
	if int(meta["credits"]) < cost:
		return "Need %d cr for %s." % [cost, Items.item_name(def_id)]
	meta["credits"] = int(meta["credits"]) - cost
	Items.add_to_stash(meta["stash"], Items.stack_of(def_id, qty))
	return "Bought %s ×%d  (−%d cr)." % [Items.item_name(def_id), qty, cost]


static func sell_all_loot(meta: Dictionary) -> String:
	## Liquidate loot-slot stacks only — gear stays for equipping.
	var stash: Array = meta["stash"]
	var gained := 0
	var sold_qty := 0
	var kept: Array = []
	for s in stash:
		var def_id := String(s["def_id"])
		var def := Items.get_item(def_id)
		if String(def.get("slot", "")) != "loot":
			kept.append(s)
			continue
		var qty := int(s["qty"])
		gained += sell_price(def_id) * qty
		sold_qty += qty
	if sold_qty <= 0:
		return "No salvage — kit stays."
	meta["stash"] = kept
	meta["credits"] = int(meta["credits"]) + gained
	return "Sold loot ×%d  (+%d cr)." % [sold_qty, gained]


static func buy_skill_point(meta: Dictionary) -> String:
	Skills.ensure(meta)
	var cost := SKILL_POINT_INFLUENCE_COST
	if int(meta["influence"]) < cost:
		return "Need %d influence for a skill point." % cost
	meta["influence"] = int(meta["influence"]) - cost
	meta["skills"]["points"] = int(meta["skills"]["points"]) + 1
	return "Trained +1 skill point (−%d inf)." % cost
