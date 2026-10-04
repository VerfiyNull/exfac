class_name Items
extends RefCounted
## Item catalog + locker/inventory helpers. Loot rolls live here so raid never invents item ids.

const LOOT_TABLE: Array[String] = [
	"scrap", "scrap", "scrap",
	"ammo_box", "ammo_box",
	"medkit", "intel", "gold_watch", "mark_flare",
	"field_pistol", "cloth_armor", "sling_bag",
]

static var _defs: Dictionary = {}


static func _ensure_defs() -> void:
	if not _defs.is_empty():
		return
	# spread/recoil in radians — SMG sprays, rifle kicks but starts tight, pistol sits between.
	# coil_carbine: slow heavy punches. mesh_carrier: mid armor rung. mark_flare: loud lure consumable.
	_defs = {
		"rusty_smg": {"id": "rusty_smg", "name": "Rusty SMG", "slot": "weapon", "value": 40, "damage": 14.0, "fire_rate": 6.0, "mag_size": 28, "reload": 1.55, "start_reserve": 84, "spread": 0.075, "recoil": 0.038, "max_bloom": 0.32, "recoil_decay": 0.55, "kick": 3.2, "color": Color("8fa3b8")},
		"patrol_rifle": {"id": "patrol_rifle", "name": "Patrol Rifle", "slot": "weapon", "value": 120, "damage": 22.0, "fire_rate": 4.5, "mag_size": 20, "reload": 2.05, "start_reserve": 60, "spread": 0.022, "recoil": 0.055, "max_bloom": 0.20, "recoil_decay": 0.42, "kick": 5.5, "color": Color("6ec1ff")},
		"coil_carbine": {"id": "coil_carbine", "name": "Coil Carbine", "slot": "weapon", "value": 95, "damage": 28.0, "fire_rate": 2.4, "mag_size": 10, "reload": 2.35, "start_reserve": 40, "spread": 0.018, "recoil": 0.072, "max_bloom": 0.24, "recoil_decay": 0.38, "kick": 7.2, "color": Color("7a9ec4")},
		"field_pistol": {"id": "field_pistol", "name": "Field Pistol", "slot": "weapon", "value": 25, "damage": 11.0, "fire_rate": 3.2, "mag_size": 12, "reload": 1.25, "start_reserve": 36, "spread": 0.045, "recoil": 0.028, "max_bloom": 0.16, "recoil_decay": 0.70, "kick": 2.4, "color": Color("b7c0cc")},
		"cloth_armor": {"id": "cloth_armor", "name": "Cloth Armor", "slot": "armor", "value": 35, "mitigation": 0.15, "durability": 55.0, "color": Color("9bb07a")},
		"mesh_carrier": {"id": "mesh_carrier", "name": "Mesh Carrier", "slot": "armor", "value": 70, "mitigation": 0.24, "durability": 95.0, "color": Color("7a9a72")},
		"plate_vest": {"id": "plate_vest", "name": "Plate Vest", "slot": "armor", "value": 110, "mitigation": 0.35, "durability": 140.0, "color": Color("5f8f6a")},
		"sling_bag": {"id": "sling_bag", "name": "Sling Bag", "slot": "bag", "value": 30, "capacity": 4, "color": Color("c4a574")},
		"field_pack": {"id": "field_pack", "name": "Field Pack", "slot": "bag", "value": 90, "capacity": 8, "color": Color("d0894c")},
		"scrap": {"id": "scrap", "name": "Scrap Parts", "slot": "loot", "value": 12, "color": Color("a8a79c")},
		"medkit": {"id": "medkit", "name": "Field Medkit", "slot": "loot", "value": 28, "heal": 45.0, "color": Color("e07070")},
		"intel": {"id": "intel", "name": "Signal Chip", "slot": "loot", "value": 55, "color": Color("7fd0ff")},
		"mark_flare": {"id": "mark_flare", "name": "Mark Flare", "slot": "loot", "value": 22, "color": Color("ff8a4a")},
		"gold_watch": {"id": "gold_watch", "name": "Heirloom Watch", "slot": "loot", "value": 80, "color": Color("e6c35a")},
		"ammo_box": {"id": "ammo_box", "name": "Ammo Box", "slot": "loot", "value": 18, "ammo": 30, "color": Color("d2b48c")},
	}


static func get_item(def_id: String) -> Dictionary:
	## Soft miss — log + stub so corrupt bags don't hard-crash mid-field.
	_ensure_defs()
	if not _defs.has(def_id):
		push_error("Items: unknown id '%s'" % def_id)
		return {"id": def_id, "name": "Unknown", "slot": "loot", "value": 0, "color": Color(0.45, 0.45, 0.5)}
	return _defs[def_id]


static func has_item(def_id: String) -> bool:
	_ensure_defs()
	return _defs.has(def_id)


static func stack_of(def_id: String, qty: int = 1) -> Dictionary:
	get_item(def_id)
	return {"def_id": def_id, "qty": qty}


static func add_to_stash(stash: Array, incoming: Dictionary) -> void:
	for s in stash:
		if s["def_id"] == incoming["def_id"]:
			s["qty"] += incoming["qty"]
			return
	stash.append({"def_id": incoming["def_id"], "qty": incoming["qty"]})


static func remove_from_stash(stash: Array, def_id: String, qty: int = 1) -> bool:
	for i in stash.size():
		var stack: Dictionary = stash[i]
		if stack["def_id"] != def_id:
			continue
		if stack["qty"] < qty:
			return false
		stack["qty"] -= qty
		if stack["qty"] <= 0:
			stash.remove_at(i)
		return true
	return false


static func inventory_used(stacks: Array) -> int:
	var n := 0
	for s in stacks:
		n += int(s["qty"])
	return n


static func try_add_inventory(inv: Array, cap: int, incoming: Dictionary) -> bool:
	if inventory_used(inv) + int(incoming["qty"]) > cap:
		return false
	add_to_stash(inv, incoming)
	return true


## Take what fits; returns qty left behind (0 = all taken). Avoids wiping overflow loot.
static func try_add_inventory_partial(inv: Array, cap: int, incoming: Dictionary) -> int:
	var qty := int(incoming.get("qty", 0))
	if qty <= 0:
		return 0
	var space := maxi(0, cap - inventory_used(inv))
	if space <= 0:
		return qty
	var take := mini(qty, space)
	add_to_stash(inv, {"def_id": String(incoming["def_id"]), "qty": take})
	return qty - take


static func loadout_capacity(loadout: Dictionary) -> int:
	var bag_id: Variant = loadout.get("bag_id")
	if bag_id == null or String(bag_id).is_empty():
		return 2
	var bag := get_item(String(bag_id))
	return 2 + int(bag.get("capacity", 0))


## Raid bag slots: equipped bag, or the best bag sitting in the raid inventory.
static func effective_raid_capacity(loadout: Dictionary, inventory: Array) -> int:
	var cap := loadout_capacity(loadout)
	for s in inventory:
		var def := get_item(String(s["def_id"]))
		if String(def["slot"]) != "bag":
			continue
		cap = maxi(cap, 2 + int(def.get("capacity", 0)))
	return cap


static func format_inventory_lines(inventory: Array) -> String:
	if inventory.is_empty():
		return "(empty)"
	var lines: PackedStringArray = []
	for s in inventory:
		var def := get_item(String(s["def_id"]))
		lines.append("%s ×%d" % [String(def["name"]), int(s["qty"])])
	return "\n".join(lines)


static func loadout_has_weapon(loadout: Dictionary) -> bool:
	var weapon_id: Variant = loadout.get("weapon_id")
	return weapon_id != null and not String(weapon_id).is_empty()


static func loadout_damage(loadout: Dictionary) -> float:
	if not loadout_has_weapon(loadout):
		return 0.0
	return float(get_item(String(loadout["weapon_id"])).get("damage", 8.0))


static func loadout_fire_rate(loadout: Dictionary) -> float:
	## Unarmed punch cadence — LMB is fists, not a phantom gun.
	if not loadout_has_weapon(loadout):
		return 1.85
	return float(get_item(String(loadout["weapon_id"])).get("fire_rate", 2.5))


static func weapon_mag_size(loadout: Dictionary) -> int:
	if not loadout_has_weapon(loadout):
		return 0
	return int(get_item(String(loadout["weapon_id"])).get("mag_size", 8))


static func weapon_reload_time(loadout: Dictionary) -> float:
	if not loadout_has_weapon(loadout):
		return 0.0
	return float(get_item(String(loadout["weapon_id"])).get("reload", 1.4))


static func weapon_start_reserve(loadout: Dictionary) -> int:
	if not loadout_has_weapon(loadout):
		return 0
	return int(get_item(String(loadout["weapon_id"])).get("start_reserve", 24))


## Base cone, bloom-per-shot, cap, recovery/sec, and muzzle shake for the equipped gun.
static func loadout_recoil_stats(loadout: Dictionary) -> Dictionary:
	if not loadout_has_weapon(loadout):
		return {"spread": 0.0, "recoil": 0.0, "max_bloom": 0.0, "recoil_decay": 1.0, "kick": 0.0}
	var def := get_item(String(loadout["weapon_id"]))
	return {
		"spread": float(def.get("spread", 0.05)),
		"recoil": float(def.get("recoil", 0.03)),
		"max_bloom": float(def.get("max_bloom", 0.2)),
		"recoil_decay": float(def.get("recoil_decay", 0.5)),
		"kick": float(def.get("kick", 2.5)),
	}


static func loadout_mitigation(loadout: Dictionary) -> float:
	var armor_id: Variant = loadout.get("armor_id")
	if armor_id == null or String(armor_id).is_empty():
		return 0.0
	return float(get_item(String(armor_id)).get("mitigation", 0.0))


static func loadout_armor_durability(loadout: Dictionary) -> float:
	var armor_id: Variant = loadout.get("armor_id")
	if armor_id == null or String(armor_id).is_empty():
		return 0.0
	return float(get_item(String(armor_id)).get("durability", 0.0))


## Weighted pick — entries are {"id": String, "w": float}.
static func _pick_weighted(entries: Array) -> String:
	var total := 0.0
	for e in entries:
		total += float(e["w"])
	var roll := randf() * total
	var acc := 0.0
	for e in entries:
		acc += float(e["w"])
		if roll <= acc:
			return String(e["id"])
	return String(entries.back()["id"])


static func roll_crate_loot() -> Array:
	return roll_container_loot("crate")


## Container-typed loot — med/ammo lean useful; weapon/intel lean rare high-value.
static func roll_container_loot(kind: String) -> Array:
	var out: Array = []
	match kind:
		"med_cache":
			out.append(stack_of("medkit", randi_range(1, 2)))
			if randf() < 0.45:
				out.append(stack_of(_pick_weighted([
					{"id": "scrap", "w": 3.0}, {"id": "medkit", "w": 2.0}, {"id": "ammo_box", "w": 1.0},
				]), 1))
		"ammo_crate":
			out.append(stack_of("ammo_box", randi_range(1, 2)))
			if randf() < 0.55:
				out.append(stack_of(_pick_weighted([
					{"id": "ammo_box", "w": 4.0}, {"id": "scrap", "w": 2.0}, {"id": "field_pistol", "w": 0.6},
				]), 1))
		"weapon_case":
			out.append(stack_of(_pick_weighted([
				{"id": "field_pistol", "w": 3.0},
				{"id": "rusty_smg", "w": 2.2},
				{"id": "coil_carbine", "w": 1.4},
				{"id": "patrol_rifle", "w": 1.0},
				{"id": "cloth_armor", "w": 1.2},
				{"id": "mesh_carrier", "w": 1.0},
				{"id": "plate_vest", "w": 0.8},
				{"id": "field_pack", "w": 0.7},
			]), 1))
			if randf() < 0.55:
				out.append(stack_of(_pick_weighted([
					{"id": "ammo_box", "w": 3.0}, {"id": "scrap", "w": 2.0}, {"id": "medkit", "w": 1.0}, {"id": "mark_flare", "w": 1.2},
				]), 1))
		"intel_safe":
			out.append(stack_of(_pick_weighted([
				{"id": "intel", "w": 4.0}, {"id": "gold_watch", "w": 2.5}, {"id": "scrap", "w": 1.0}, {"id": "mark_flare", "w": 1.0},
			]), 1))
			if randf() < 0.4:
				out.append(stack_of(_pick_weighted([
					{"id": "gold_watch", "w": 2.0}, {"id": "intel", "w": 2.0}, {"id": "medkit", "w": 1.0},
				]), 1))
		_:
			# Common field crate — scrap-heavy with rare jackpot chance.
			var count := int(randi_range(1, 3))
			for _i in count:
				out.append(stack_of(_pick_weighted([
					{"id": "scrap", "w": 5.0},
					{"id": "ammo_box", "w": 2.5},
					{"id": "medkit", "w": 1.2},
					{"id": "mark_flare", "w": 0.8},
					{"id": "intel", "w": 0.5},
					{"id": "gold_watch", "w": 0.35},
					{"id": "field_pistol", "w": 0.4},
					{"id": "cloth_armor", "w": 0.3},
					{"id": "sling_bag", "w": 0.25},
				]), 1))
			if randf() < 0.08:
				out.append(stack_of("patrol_rifle", 1))
			if randf() < 0.06:
				out.append(stack_of("coil_carbine", 1))
			if randf() < 0.07:
				out.append(stack_of("plate_vest", 1))
			if randf() < 0.06:
				out.append(stack_of("mesh_carrier", 1))
			if randf() < 0.07:
				out.append(stack_of("field_pack", 1))
	return out


## What a dead roamer drops — lean ammo/meds, occasional gear.
static func roll_roamer_loot() -> Array:
	var out: Array = []
	var roll := randf()
	if roll < 0.45:
		out.append(stack_of("ammo_box", 1))
	elif roll < 0.7:
		out.append(stack_of("medkit", 1))
	elif roll < 0.85:
		out.append(stack_of("scrap", 1))
	elif roll < 0.93:
		out.append(stack_of("field_pistol", 1))
	else:
		out.append(stack_of("cloth_armor", 1))
	if randf() < 0.18:
		out.append(stack_of("ammo_box", 1))
	return out


## Elite enforcer drops — richer than roamers; gear shows up more often.
static func roll_enforcer_loot() -> Array:
	var out: Array = []
	out.append(stack_of(_pick_weighted([
		{"id": "ammo_box", "w": 2.5},
		{"id": "medkit", "w": 2.0},
		{"id": "plate_vest", "w": 1.4},
		{"id": "mesh_carrier", "w": 1.5},
		{"id": "patrol_rifle", "w": 1.0},
		{"id": "coil_carbine", "w": 1.3},
		{"id": "rusty_smg", "w": 1.2},
		{"id": "field_pack", "w": 1.0},
		{"id": "gold_watch", "w": 0.9},
		{"id": "intel", "w": 0.8},
		{"id": "mark_flare", "w": 1.1},
	]), 1))
	if randf() < 0.7:
		out.append(stack_of(_pick_weighted([
			{"id": "ammo_box", "w": 3.0},
			{"id": "medkit", "w": 2.0},
			{"id": "scrap", "w": 1.5},
			{"id": "mark_flare", "w": 1.2},
			{"id": "cloth_armor", "w": 0.8},
		]), 1))
	if randf() < 0.35:
		out.append(stack_of(_pick_weighted([
			{"id": "intel", "w": 2.0},
			{"id": "gold_watch", "w": 1.5},
			{"id": "field_pistol", "w": 1.0},
			{"id": "coil_carbine", "w": 0.7},
		]), 1))
	return out


static func container_display_name(kind: String) -> String:
	match kind:
		"med_cache":
			return "Med cache"
		"ammo_crate":
			return "Ammo crate"
		"weapon_case":
			return "Weapon case"
		"intel_safe":
			return "Intel safe"
		"drop_bag":
			return "Drop bag"
		"corpse":
			return "Body"
		_:
			return "Crate"


static func _slot_score(loadout: Dictionary, slot_key: String) -> float:
	var cur: Variant = loadout.get(slot_key)
	if cur == null or String(cur).is_empty():
		return -1.0
	return float(get_item(String(cur)).get("value", 0))


## True if bag holds a strictly better weapon, armor, or bag than the live loadout.
static func has_better_gear_in_inventory(loadout: Dictionary, inventory: Array) -> bool:
	var best := {"weapon": -1.0, "armor": -1.0, "bag": -1.0}
	for s in inventory:
		var def := get_item(String(s["def_id"]))
		var slot := String(def["slot"])
		if not best.has(slot):
			continue
		best[slot] = maxf(float(best[slot]), float(def.get("value", 0)))
	return float(best["weapon"]) > _slot_score(loadout, "weapon_id") \
		or float(best["armor"]) > _slot_score(loadout, "armor_id") \
		or float(best["bag"]) > _slot_score(loadout, "bag_id")


static func loot_influence_value(stacks: Array) -> int:
	var sum := 0
	for s in stacks:
		sum += int(get_item(String(s["def_id"]))["value"]) * int(s["qty"])
	return sum


static func sort_stash(stash: Array) -> void:
	# Weapons → armor → bags → loot, then name — easier equip scan.
	var order := {"weapon": 0, "armor": 1, "bag": 2, "loot": 3}
	stash.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da := get_item(String(a["def_id"]))
		var db := get_item(String(b["def_id"]))
		var sa := int(order.get(String(da["slot"]), 9))
		var sb := int(order.get(String(db["slot"]), 9))
		if sa != sb:
			return sa < sb
		return String(da["name"]) < String(db["name"])
	)


static func default_starter_stash() -> Array:
	return [
		stack_of("rusty_smg", 1),
		stack_of("cloth_armor", 1),
		stack_of("sling_bag", 1),
		stack_of("patrol_rifle", 1),
		stack_of("plate_vest", 1),
		stack_of("field_pack", 1),
		stack_of("medkit", 2),
		stack_of("scrap", 5),
	]


static func item_name(def_id: Variant) -> String:
	if def_id == null or String(def_id).is_empty():
		return "None"
	return String(get_item(String(def_id))["name"])


static func weapon_slot_name(def_id: Variant) -> String:
	## Kit row — empty weapon reads as fists, not a missing gun error.
	if def_id == null or String(def_id).is_empty():
		return "Fists"
	return item_name(def_id)


static func count_in_stacks(stacks: Array, def_id: String) -> int:
	var n := 0
	for s in stacks:
		if String(s["def_id"]) == def_id:
			n += int(s["qty"])
	return n


## First stash index for def_id, or -1. Used to keep locker selection stable across sort.
static func index_of_def(stacks: Array, def_id: String) -> int:
	if def_id.is_empty():
		return -1
	for i in stacks.size():
		if String(stacks[i]["def_id"]) == def_id:
			return i
	return -1


static func consume_from_stacks(stacks: Array, def_id: String, qty: int = 1) -> bool:
	return remove_from_stash(stacks, def_id, qty)
