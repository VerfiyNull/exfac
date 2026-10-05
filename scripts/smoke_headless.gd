extends SceneTree
## Headless smoke: hideout economy + raid extract/death without rendering.

const _Items := preload("res://scripts/systems/items.gd")
const _MetaSim := preload("res://scripts/systems/meta.gd")
const _RaidSim := preload("res://scripts/systems/raid.gd")
const _Skills := preload("res://scripts/systems/skills.gd")
const _SaveGame := preload("res://scripts/systems/save.gd")


func _script_has_method(script: GDScript, method_name: String) -> bool:
	for m in script.get_script_method_list():
		if String(m.get("name", "")) == method_name:
			return true
	return false


func _initialize() -> void:
	var failed := 0
	# Guard hideout + elite loot call sites — catch Items/MetaSim/Skills API drift early.
	failed += _check("hideout MetaSim/Skills APIs", func() -> bool:
		return _script_has_method(_Skills, "try_lower") \
			and _script_has_method(_MetaSim, "quick_kit_from_stash") \
			and _script_has_method(_MetaSim, "sell_from_stash") \
			and _script_has_method(_MetaSim, "sell_all_loot") \
			and _script_has_method(_MetaSim, "buy_skill_point") \
			and _script_has_method(_MetaSim, "buy_to_stash")
	)
	failed += _check("Items enforcer loot API", func() -> bool:
		if not _script_has_method(_Items, "roll_enforcer_loot"):
			return false
		if not _script_has_method(_Items, "roll_roamer_loot"):
			return false
		var loot: Array = _Items.roll_enforcer_loot()
		return not loot.is_empty() and loot[0].has("def_id")
	)
	failed += _check("title/base scenes load", func() -> bool:
		var title_ps: PackedScene = load("res://scenes/title.tscn")
		var base_ps: PackedScene = load("res://scenes/hideout.tscn")
		return title_ps != null and base_ps != null
	)
	failed += _check("raid scene script parses with RaidSim preload", func() -> bool:
		# Guard against class_name drift — scenes/raid.gd must preload systems/raid.gd
		# and load cleanly (Neil: Identifier RaidSim not declared).
		var src := FileAccess.get_file_as_string("res://scenes/raid.gd")
		if src.find('preload("res://scripts/systems/raid.gd")') < 0:
			return false
		if src.find("RaidSim.THREAT_BEARING_TTL") < 0:
			return false
		var scr: Variant = load("res://scenes/raid.gd")
		if scr == null:
			return false
		var raid_ps: PackedScene = load("res://scenes/raid.tscn")
		return raid_ps != null
	)
	failed += _check("RaidSim public bag refresh", func() -> bool:
		return _script_has_method(_RaidSim, "refresh_inventory_cap")
	)
	failed += _check("create meta", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		return meta.has("stash") and meta.has("loadout") and int(meta["influence"]) > 0
	)
	failed += _check("bag capacity", func() -> bool:
		var loadout := {"weapon_id": "rusty_smg", "armor_id": null, "bag_id": "sling_bag"}
		return _Items.loadout_capacity(loadout) == 6
	)
	failed += _check("raid bag expands from inventory bag", func() -> bool:
		var loadout := {"weapon_id": "rusty_smg", "armor_id": null, "bag_id": "sling_bag"}
		var inv: Array = [_Items.stack_of("field_pack", 1)]
		return _Items.effective_raid_capacity(loadout, inv) == 10
	)
	failed += _check("death loses loadout + restock", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		_MetaSim.lose_loadout_on_death(meta)
		var note := _MetaSim.restock_loadout_from_stash(meta)
		var wid: Variant = meta["loadout"].get("weapon_id")
		return wid != null and not String(wid).is_empty() and not note.is_empty()
	)
	failed += _check("bare kit if broke", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		meta["stash"] = []
		_MetaSim.lose_loadout_on_death(meta)
		_MetaSim.restock_loadout_from_stash(meta)
		# Guns optional — empty locker stays fists, no free pistol forever.
		var wid: Variant = meta["loadout"].get("weapon_id")
		return wid == null or String(wid).is_empty()
	)
	failed += _check("unarmed raid world punches", func() -> bool:
		var loadout := {"weapon_id": null, "armor_id": null, "bag_id": "sling_bag"}
		var world := _RaidSim.create_raid_world(loadout)
		if bool(world["player"].get("armed", true)):
			return false
		if int(world["player"].get("mag", 9)) != 0:
			return false
		if _Items.loadout_has_weapon(world["loadout"]):
			return false
		# Place a roamer in punch range ahead and swing.
		var player: Dictionary = world["player"]
		world["roamers"] = [{
			"id": 99,
			"alive": true,
			"pos": player["pos"] + Vector2(28, 0),
			"radius": 12.0,
			"hp": 40.0,
			"max_hp": 40.0,
			"mitigation": 0.0,
			"aim": Vector2.LEFT,
			"speed": 90.0,
			"damage": 8.0,
			"fire_cooldown": 0.0,
			"hit_flash": 0.0,
			"alert_ttl": 0.0,
			"search_ttl": 0.0,
			"call_cooldown": 0.0,
			"suppress_ttl": 0.0,
			"telegraph_ttl": 0.0,
			"aggro_range": 220.0,
			"hear_mult": 1.0,
			"dormant": false,
			"ai_state": "patrol",
			"elite": false,
			"role": "roamer",
			"home": player["pos"] + Vector2(28, 0),
			"patrol_phase": 0.0,
		}]
		_RaidSim.step_raid(world, 0.05, Vector2.ZERO, player["pos"] + Vector2(40, 0), false, false, 2.0, false, false, false, false, false, false, false, false, false, true)
		# Punch hits — and never spawns a bullet / gun fire path.
		if not world["bullets"].is_empty():
			return false
		return float(world["roamers"][0]["hp"]) < 40.0 or not bool(world["roamers"][0]["alive"])
	)
	failed += _check("punch slows without shoving", func() -> bool:
		var loadout := {"weapon_id": null, "armor_id": null, "bag_id": "sling_bag"}
		var world := _RaidSim.create_raid_world(loadout)
		var player: Dictionary = world["player"]
		var start: Vector2 = player["pos"] + Vector2(28, 0)
		world["obstacles"] = []
		world["roamers"] = [{
			"id": 99,
			"alive": true,
			"pos": start,
			"radius": 12.0,
			"hp": 80.0,
			"max_hp": 80.0,
			"mitigation": 0.0,
			"aim": Vector2.LEFT,
			"speed": 100.0,
			"damage": 8.0,
			"fire_cooldown": 99.0,
			"hit_flash": 0.0,
			"alert_ttl": 0.0,
			"search_ttl": 0.0,
			"call_cooldown": 0.0,
			"suppress_ttl": 0.0,
			"telegraph_ttl": 0.0,
			"aggro_range": 220.0,
			"hear_mult": 1.0,
			"dormant": false,
			"ai_state": "patrol",
			"elite": false,
			"role": "roamer",
			"home": start,
			"patrol_phase": 0.0,
			"melee_slow_ttl": 0.0,
		}]
		_RaidSim.step_raid(world, 0.05, Vector2.ZERO, player["pos"] + Vector2(40, 0), false, false, 2.0, false, false, false, false, false, false, false, false, false, true)
		var roamer: Dictionary = world["roamers"][0]
		var after_hit: Vector2 = roamer["pos"]
		var slow_ttl := float(roamer.get("melee_slow_ttl", 0.0))
		# Stay planted for the slow window — combat backpedal used to look like a teleport.
		for _i in 9:
			world["bullets"] = []
			_RaidSim.step_raid(world, 0.05, Vector2.ZERO, player["pos"] + Vector2(40, 0), false, false, 2.0)
		var drift: float = (roamer["pos"] as Vector2).distance_to(after_hit)
		var still_slow := float(roamer.get("melee_slow_ttl", 0.0)) > 0.0
		return float(roamer["hp"]) < 80.0 \
			and after_hit.distance_to(start) < 1.0 \
			and drift < 1.0 \
			and still_slow \
			and slow_ttl > 0.35 and slow_ttl <= _RaidSim.MELEE_SLOW_TTL
	)
	failed += _check("hold shoot does not auto-punch", func() -> bool:
		var loadout := {"weapon_id": null, "armor_id": null, "bag_id": "sling_bag"}
		var world := _RaidSim.create_raid_world(loadout)
		var player: Dictionary = world["player"]
		world["obstacles"] = []
		world["roamers"] = [{
			"id": 99, "alive": true, "pos": player["pos"] + Vector2(28, 0), "radius": 12.0,
			"hp": 80.0, "max_hp": 80.0, "mitigation": 0.0, "aim": Vector2.LEFT, "speed": 100.0,
			"damage": 8.0, "fire_cooldown": 0.0, "hit_flash": 0.0, "alert_ttl": 0.0, "search_ttl": 0.0,
			"call_cooldown": 0.0, "suppress_ttl": 0.0, "telegraph_ttl": 0.0, "aggro_range": 220.0,
			"hear_mult": 1.0, "dormant": false, "ai_state": "patrol", "elite": false, "role": "roamer",
			"home": player["pos"] + Vector2(28, 0), "patrol_phase": 0.0, "melee_slow_ttl": 0.0,
		}]
		var hp0 := float(world["roamers"][0]["hp"])
		# Held shoot without click edge — must not swing.
		_RaidSim.step_raid(world, 0.05, Vector2.ZERO, player["pos"] + Vector2(40, 0), true, false, 2.0, false, false, false, false, false, false, false, false, false, false)
		_RaidSim.step_raid(world, 0.05, Vector2.ZERO, player["pos"] + Vector2(40, 0), true, false, 2.0, false, false, false, false, false, false, false, false, false, false)
		return is_equal_approx(float(world["roamers"][0]["hp"]), hp0) \
			and float(world["player"].get("punch_swing", 0.0)) <= 0.0
	)
	failed += _check("punch spends stamina", func() -> bool:
		var loadout := {"weapon_id": null, "armor_id": null, "bag_id": "sling_bag"}
		var world := _RaidSim.create_raid_world(loadout)
		var player: Dictionary = world["player"]
		var before := float(player["stamina"])
		world["obstacles"] = []
		world["roamers"] = [{
			"id": 99, "alive": true, "pos": player["pos"] + Vector2(28, 0), "radius": 12.0,
			"hp": 80.0, "max_hp": 80.0, "mitigation": 0.0, "aim": Vector2.LEFT, "speed": 100.0,
			"damage": 8.0, "fire_cooldown": 0.0, "hit_flash": 0.0, "alert_ttl": 0.0, "search_ttl": 0.0,
			"call_cooldown": 0.0, "suppress_ttl": 0.0, "telegraph_ttl": 0.0, "aggro_range": 220.0,
			"hear_mult": 1.0, "dormant": false, "ai_state": "patrol", "elite": false, "role": "roamer",
			"home": player["pos"] + Vector2(28, 0), "patrol_phase": 0.0, "melee_slow_ttl": 0.0,
		}]
		_RaidSim.step_raid(world, 0.05, Vector2.ZERO, player["pos"] + Vector2(40, 0), false, false, 2.0, false, false, false, false, false, false, false, false, false, true)
		return float(player["stamina"]) <= before - _RaidSim.PUNCH_STAMINA_COST + 0.01 \
			and float(world["roamers"][0]["hp"]) < 80.0
	)
	failed += _check("punch slow does not stack", func() -> bool:
		var loadout := {"weapon_id": null, "armor_id": null, "bag_id": "sling_bag"}
		var world := _RaidSim.create_raid_world(loadout)
		var player: Dictionary = world["player"]
		var start: Vector2 = player["pos"] + Vector2(28, 0)
		world["obstacles"] = []
		world["roamers"] = [{
			"id": 99,
			"alive": true,
			"pos": start,
			"radius": 12.0,
			"hp": 200.0,
			"max_hp": 200.0,
			"mitigation": 0.0,
			"aim": Vector2.LEFT,
			"speed": 100.0,
			"damage": 8.0,
			"fire_cooldown": 99.0,
			"hit_flash": 0.0,
			"alert_ttl": 0.0,
			"search_ttl": 0.0,
			"call_cooldown": 0.0,
			"suppress_ttl": 0.0,
			"telegraph_ttl": 0.0,
			"aggro_range": 220.0,
			"hear_mult": 1.0,
			"dormant": false,
			"ai_state": "patrol",
			"elite": false,
			"role": "roamer",
			"home": start,
			"patrol_phase": 0.0,
			"melee_slow_ttl": 0.0,
		}]
		_RaidSim.step_raid(world, 0.05, Vector2.ZERO, player["pos"] + Vector2(40, 0), false, false, 2.0, false, false, false, false, false, false, false, false, false, true)
		var ttl_after_first := float(world["roamers"][0].get("melee_slow_ttl", 0.0))
		# Second punch while still slowed must not refresh / extend the timer.
		world["player"]["fire_cooldown"] = 0.0
		_RaidSim.step_raid(world, 0.05, Vector2.ZERO, player["pos"] + Vector2(40, 0), false, false, 2.0, false, false, false, false, false, false, false, false, false, true)
		var ttl_after_second := float(world["roamers"][0].get("melee_slow_ttl", 0.0))
		return ttl_after_first > 0.35 \
			and ttl_after_second < ttl_after_first \
			and ttl_after_second <= _RaidSim.MELEE_SLOW_TTL
	)
	failed += _check("unarmed LMB never spawns projectile", func() -> bool:
		var loadout := {"weapon_id": null, "armor_id": null, "bag_id": null}
		var world := _RaidSim.create_raid_world(loadout)
		# Empty field — fire into air; fists miss must not invent a round.
		world["roamers"] = []
		world["bullets"] = []
		var aim: Vector2 = world["player"]["pos"] + Vector2(80, 0)
		_RaidSim.step_raid(world, 0.05, Vector2.ZERO, aim, true, false, 2.0)
		_RaidSim.step_raid(world, 0.05, Vector2.ZERO, aim, true, false, 2.0)
		# Hard gate on spawn — even a direct call must no-op for unarmed players.
		_RaidSim._spawn_bullet(world, world["player"], Vector2.RIGHT, true, 560.0)
		return world["bullets"].is_empty() \
			and not _Items.loadout_has_weapon(world["loadout"]) \
			and not bool(world["player"].get("armed", true)) \
			and int(world["player"].get("mag", 1)) == 0
	)
	failed += _check("unarmed draw flag is fists-only", func() -> bool:
		# Scene render gates muzzle/gun tick on loadout_has_weapon — keep that contract smoke-checked.
		var fists := {"weapon_id": null, "armor_id": "cloth_armor", "bag_id": "sling_bag"}
		var gun := {"weapon_id": "rusty_smg", "armor_id": null, "bag_id": null}
		return (not _Items.loadout_has_weapon(fists)) and _Items.loadout_has_weapon(gun)
	)
	failed += _check("deploy path does not restock weapon", func() -> bool:
		# go_raid must not call restock_loadout_from_stash (that re-armed fists). Source guard.
		var src := FileAccess.get_file_as_string("res://autoload/game_session.gd")
		var go := src.find("func go_raid()")
		var apply := src.find("func apply_raid_result(")
		if go < 0 or apply < 0 or apply <= go:
			return false
		var body := src.substr(go, apply - go)
		return body.find("restock_loadout_from_stash") < 0
	)
	failed += _check("movement eases toward desired speed", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"])
		world["player"]["vel"] = Vector2.ZERO
		_RaidSim.step_raid(world, 0.05, Vector2(1, 0), world["player"]["pos"] + Vector2(40, 0), false, false, 4.0)
		var v1: Vector2 = world["player"]["vel"]
		_RaidSim.step_raid(world, 0.05, Vector2(1, 0), world["player"]["pos"] + Vector2(40, 0), false, false, 4.0)
		var v2: Vector2 = world["player"]["vel"]
		# Accel: second sample should be at least as fast after easing in.
		return v1.x > 1.0 and v2.x >= v1.x - 0.01
	)
	failed += _check("raid world is large", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"])
		return float(world["width"]) >= 7000.0 and float(world["height"]) >= 4500.0 \
			and world["roamers"].size() >= 20 \
			and (world.get("decals", []) as Array).size() >= 8 \
			and (world["obstacles"] as Array).size() >= 40
	)
	failed += _check("vision blocked by wall", func() -> bool:
		var obstacles: Array = [{"x": 100.0, "y": 0.0, "w": 40.0, "h": 200.0}]
		var viewer := {"pos": Vector2(50, 100), "vision_range": 500.0}
		return not _RaidSim.can_see_actor(viewer, Vector2(200, 100), obstacles)
	)
	failed += _check("extract flare contests roamers", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"])
		# Put player in first extract and a roamer nearby.
		var z: Dictionary = world["extracts"][0]
		world["player"]["pos"] = z["pos"]
		var roamer: Dictionary = world["roamers"][0]
		roamer["pos"] = z["pos"] + Vector2(400, 0)
		var before: Vector2 = roamer["pos"]
		_RaidSim.step_raid(world, 0.2, Vector2.ZERO, z["pos"], false, false, 4.0)
		return bool(world["extract_alarm"]) and float(world["extract_progress_01"]) > 0.0 \
			and int(world["extract_contest_count"]) >= 1 and roamer["pos"].distance_to(world["player"]["pos"]) < before.distance_to(world["player"]["pos"])
	)
	failed += _check("field egress banks loot", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"])
		world["inventory"] = [_Items.stack_of("scrap", 2)]
		world["over"] = true
		world["outcome"] = "extracted"
		var result: Dictionary = _RaidSim.finalize_raid_result(world)
		return String(result["outcome"]) == "extracted" and int(result["influence_gained"]) >= _MetaSim.EXTRACT_INFLUENCE_BASE
	)
	failed += _check("medkit heals after channel", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"], 2)
		world["roamers"] = []
		world["bullets"] = []
		world["player"]["hp"] = 40.0
		assert(_Items.count_in_stacks(world["inventory"], "medkit") == 2)
		_RaidSim.step_raid(world, 0.0, Vector2.ZERO, world["player"]["pos"], false, false, 4.0, true)
		assert(float(world["player"]["heal_channel"]) > 0.0)
		# Finish channel without taking damage.
		var steps := 20
		for _i in steps:
			world["roamers"] = []
			world["bullets"] = []
			_RaidSim.step_raid(world, 0.1, Vector2.ZERO, world["player"]["pos"], false, false, 4.0, false)
		return float(world["player"]["hp"]) > 40.0 and _Items.count_in_stacks(world["inventory"], "medkit") == 1 \
			and float(world["player"]["heal_channel"]) <= 0.0
	)
	failed += _check("medkit interrupted by damage", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"], 1)
		world["roamers"] = []
		world["player"]["hp"] = 50.0
		_RaidSim.step_raid(world, 0.0, Vector2.ZERO, world["player"]["pos"], false, false, 4.0, true)
		# Fake a roamer bullet hit mid-channel.
		world["bullets"].append({
			"id": 9999,
			"pos": world["player"]["pos"],
			"vel": Vector2.ZERO,
			"damage": 12.0,
			"life": 1.0,
			"from_player": false,
			"radius": 8.0,
		})
		_RaidSim.step_raid(world, 0.05, Vector2.ZERO, world["player"]["pos"], false, false, 4.0, false)
		return float(world["player"]["heal_channel"]) <= 0.0 and _Items.count_in_stacks(world["inventory"], "medkit") == 1 \
			and float(world["player"]["hp"]) < 50.0
	)
	failed += _check("reload fills mag from reserve", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		world["roamers"] = []
		world["bullets"] = []
		world["player"]["mag"] = 0
		world["player"]["reserve"] = 40
		_RaidSim.step_raid(world, 0.0, Vector2.ZERO, world["player"]["pos"], false, false, 4.0, false, true)
		if float(world["player"]["reload_channel"]) <= 0.0:
			return false
		for _i in 30:
			world["roamers"] = []
			world["bullets"] = []
			_RaidSim.step_raid(world, 0.1, Vector2.ZERO, world["player"]["pos"], false, false, 4.0, false, false)
		return int(world["player"]["mag"]) == int(world["player"]["mag_size"]) \
			and int(world["player"]["reserve"]) == 40 - int(world["player"]["mag_size"]) \
			and float(world["player"]["reload_channel"]) <= 0.0
	)
	failed += _check("shooting spends mag", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		var before := int(world["player"]["mag"])
		_RaidSim.step_raid(world, 0.05, Vector2.ZERO, world["player"]["pos"] + Vector2(40, 0), true, false, 10.0, false, false)
		return int(world["player"]["mag"]) == before - 1 and world["bullets"].size() >= 1
	)
	failed += _check("sprint drains stamina and moves faster", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world_walk := _RaidSim.create_raid_world(meta["loadout"], 0)
		var world_run := _RaidSim.create_raid_world(meta["loadout"], 0)
		world_walk["roamers"] = []
		world_run["roamers"] = []
		var start := Vector2(400, 1600)
		world_walk["player"]["pos"] = start
		world_run["player"]["pos"] = start
		_RaidSim.step_raid(world_walk, 0.2, Vector2(1, 0), start + Vector2(100, 0), false, false, 4.0, false, false, false)
		_RaidSim.step_raid(world_run, 0.2, Vector2(1, 0), start + Vector2(100, 0), false, false, 4.0, false, false, true)
		var walk_dx: float = float(world_walk["player"]["pos"].x) - start.x
		var run_dx: float = float(world_run["player"]["pos"].x) - start.x
		return bool(world_run["player"]["sprinting"]) \
			and float(world_run["player"]["stamina"]) < float(world_run["player"]["stamina_max"]) \
			and run_dx > walk_dx * 1.2
	)
	failed += _check("sprint exhausts then locks out", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		world["roamers"] = []
		world["player"]["stamina"] = 5.0
		var start: Vector2 = world["player"]["pos"]
		_RaidSim.step_raid(world, 0.3, Vector2(1, 0), start + Vector2(80, 0), false, false, 4.0, false, false, true)
		return float(world["player"]["stamina"]) <= 0.0 \
			and float(world["player"]["sprint_exhaust"]) > 0.0 \
			and not bool(world["player"]["sprinting"])
	)
	failed += _check("extract compass points at nearest exit", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		return int(world["nearest_extract_id"]) >= 0 and float(world["nearest_extract_dist"]) > 0.0 \
			and (world["nearest_extract_dir"] as Vector2).length() > 0.5
	)
	failed += _check("equip better gear from bag", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		world["roamers"] = []
		world["loadout"]["weapon_id"] = "field_pistol"
		world["player"]["damage"] = _Items.loadout_damage(world["loadout"])
		world["player"]["fire_rate"] = _Items.loadout_fire_rate(world["loadout"])
		world["player"]["mag_size"] = _Items.weapon_mag_size(world["loadout"])
		world["player"]["mag"] = int(world["player"]["mag_size"])
		world["inventory"] = [_Items.stack_of("patrol_rifle", 1)]
		_RaidSim.step_raid(world, 0.0, Vector2.ZERO, world["player"]["pos"], false, false, 4.0, false, false, false, true)
		return String(world["loadout"]["weapon_id"]) == "patrol_rifle" \
			and _Items.count_in_stacks(world["inventory"], "field_pistol") == 1 \
			and float(world["player"]["damage"]) > 15.0
	)
	failed += _check("roamers hear gunshots through walls", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		world["obstacles"] = [{"x": 300.0, "y": 0.0, "w": 40.0, "h": 3200.0}]
		world["player"]["pos"] = Vector2(200, 1600)
		world["player"]["mag"] = 10
		world["player"]["reserve"] = 40
		var roamer: Dictionary = world["roamers"][0]
		roamer["pos"] = Vector2(500, 1600)
		roamer["alive"] = true
		var before: Vector2 = roamer["pos"]
		# Shoot — noise should pull roamer toward player even with wall LOS blocked.
		_RaidSim.step_raid(world, 0.05, Vector2.ZERO, Vector2(250, 1600), true, false, 10.0, false, false, false, false)
		assert(float(world["noise_ttl"]) > 0.0)
		_RaidSim.step_raid(world, 0.25, Vector2.ZERO, Vector2(250, 1600), false, false, 10.0, false, false, false, false)
		return roamer["pos"].distance_to(world["player"]["pos"]) < before.distance_to(world["player"]["pos"]) \
			and float(roamer["alert_ttl"]) > 0.0
	)
	failed += _check("killing roamer spawns corpse loot", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		world["roamers"] = [world["roamers"][0]]
		var roamer: Dictionary = world["roamers"][0]
		roamer["pos"] = world["player"]["pos"] + Vector2(30, 0)
		roamer["hp"] = 1.0
		roamer["alive"] = true
		var before_crates := int(world["crates"].size())
		world["bullets"].append({
			"id": 9001,
			"pos": roamer["pos"],
			"vel": Vector2.ZERO,
			"damage": 50.0,
			"life": 1.0,
			"from_player": true,
			"radius": 8.0,
		})
		_RaidSim.step_raid(world, 0.05, Vector2.ZERO, roamer["pos"], false, false, 4.0)
		var found := false
		for c in world["crates"]:
			if String(c.get("kind", "")) == "corpse" and not bool(c["opened"]):
				found = true
				break
		return not bool(roamer["alive"]) and found and world["crates"].size() >= before_crates
	)
	failed += _check("ransack is not instant", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		world["roamers"] = []
		world["bullets"] = []
		var crate: Dictionary = world["crates"][0]
		crate["opened"] = false
		crate["kind"] = "crate"
		crate["contents"] = [_Items.stack_of("scrap", 1)]
		crate["pos"] = world["player"]["pos"] + Vector2(12, 0)
		_RaidSim.step_raid(world, 0.0, Vector2.ZERO, world["player"]["pos"], false, true, 4.0)
		if float(world["player"]["loot_channel"]) <= 0.0:
			return false
		# Mid-channel: still closed, inventory empty of that scrap from crate.
		_RaidSim.step_raid(world, 0.3, Vector2.ZERO, world["player"]["pos"], false, false, 4.0)
		if bool(crate["opened"]) or float(world["player"]["loot_channel"]) <= 0.0:
			return false
		# Finish channel.
		for _i in 30:
			world["roamers"] = []
			world["bullets"] = []
			_RaidSim.step_raid(world, 0.1, Vector2.ZERO, world["player"]["pos"], false, false, 4.0)
		return bool(crate["opened"]) and float(world["player"]["loot_channel"]) <= 0.0 \
			and _Items.count_in_stacks(world["inventory"], "scrap") >= 1
	)
	failed += _check("ransack cancels if you walk away", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		world["roamers"] = []
		var crate: Dictionary = world["crates"][0]
		crate["opened"] = false
		crate["contents"] = [_Items.stack_of("medkit", 1)]
		crate["pos"] = world["player"]["pos"] + Vector2(10, 0)
		_RaidSim.step_raid(world, 0.0, Vector2.ZERO, world["player"]["pos"], false, true, 4.0)
		world["player"]["pos"] = crate["pos"] + Vector2(200, 0)
		_RaidSim.step_raid(world, 0.05, Vector2.ZERO, world["player"]["pos"], false, false, 4.0)
		return float(world["player"]["loot_channel"]) <= 0.0 and not bool(crate["opened"])
	)
	failed += _check("scrap decoy pulls roamers away", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		world["obstacles"] = []
		world["player"]["pos"] = Vector2(400, 1600)
		world["inventory"] = [_Items.stack_of("scrap", 2)]
		world["player"]["aim"] = Vector2.RIGHT
		var roamer: Dictionary = world["roamers"][0]
		roamer["pos"] = Vector2(450, 1600)
		roamer["alive"] = true
		var before: Vector2 = roamer["pos"]
		_RaidSim.step_raid(world, 0.0, Vector2.ZERO, world["player"]["pos"] + Vector2(300, 0), false, false, 4.0, false, false, false, false, true)
		assert(float(world["noise_ttl"]) > 0.0)
		var noise: Vector2 = world["noise_pos"]
		for _i in 8:
			_RaidSim.step_raid(world, 0.15, Vector2.ZERO, world["player"]["pos"], false, false, 4.0)
		return roamer["pos"].distance_to(noise) < before.distance_to(noise) \
			and _Items.count_in_stacks(world["inventory"], "scrap") == 1
	)
	failed += _check("recoil bloom climbs while dumping mag", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		meta["loadout"]["weapon_id"] = "rusty_smg"
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		world["roamers"] = []
		world["obstacles"] = []
		world["player"]["mag"] = 20
		world["player"]["reserve"] = 40
		world["player"]["fire_rate"] = 18.0
		world["player"]["fire_cooldown"] = 0.0
		var aim: Vector2 = world["player"]["pos"] + Vector2(200, 0)
		var before := float(world["player"].get("recoil_bloom", 0.0))
		for _i in 10:
			_RaidSim.step_raid(world, 0.06, Vector2.ZERO, aim, true, false, 18.0)
		var bloom := float(world["player"]["recoil_bloom"])
		var spread := float(world["player"]["aim_spread"])
		return bloom > before + 0.08 and spread > 0.12 and float(world["shake"]) > 0.0
	)
	failed += _check("rifle starts tighter than SMG", func() -> bool:
		var smg_stats: Dictionary = _Items.loadout_recoil_stats({"weapon_id": "rusty_smg"})
		var rifle_stats: Dictionary = _Items.loadout_recoil_stats({"weapon_id": "patrol_rifle"})
		return float(rifle_stats["spread"]) < float(smg_stats["spread"]) \
			and float(rifle_stats["kick"]) > float(smg_stats["kick"])
	)
	failed += _check("recoil recovers when you stop firing", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		world["roamers"] = []
		world["player"]["recoil_bloom"] = 0.25
		for _i in 20:
			_RaidSim.step_raid(world, 0.1, Vector2.ZERO, world["player"]["pos"] + Vector2(40, 0), false, false, 4.0)
		return float(world["player"]["recoil_bloom"]) < 0.05
	)
	failed += _check("death spawns drop bag with gear + loot", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		world["roamers"] = []
		world["inventory"] = [_Items.stack_of("scrap", 2), _Items.stack_of("medkit", 1)]
		world["player"]["hp"] = 5.0
		world["bullets"].append({
			"id": 9100,
			"pos": world["player"]["pos"],
			"vel": Vector2.ZERO,
			"damage": 80.0,
			"life": 1.0,
			"from_player": false,
			"radius": 8.0,
		})
		_RaidSim.step_raid(world, 0.05, Vector2.ZERO, world["player"]["pos"], false, false, 4.0)
		var found := false
		var has_weapon := false
		var has_scrap := false
		for c in world["crates"]:
			if String(c.get("kind", "")) != "drop_bag":
				continue
			found = true
			for s in c["contents"]:
				if String(s["def_id"]) == String(world["loadout"]["weapon_id"]):
					has_weapon = true
				if String(s["def_id"]) == "scrap":
					has_scrap = true
		var result: Dictionary = _RaidSim.finalize_raid_result(world)
		return not bool(world["player"]["alive"]) and found and has_weapon and has_scrap \
			and int(world["drop_bag_id"]) >= 0 and result.has("dropped") \
			and _Items.inventory_used(result["dropped"]) >= 3
	)
	failed += _check("raid spawns mixed container types", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		var kinds := {}
		for c in world["crates"]:
			var k := String(c.get("kind", "crate"))
			kinds[k] = int(kinds.get(k, 0)) + 1
		return int(kinds.get("crate", 0)) >= 12 \
			and int(kinds.get("ammo_crate", 0)) >= 5 \
			and int(kinds.get("med_cache", 0)) >= 4 \
			and int(kinds.get("weapon_case", 0)) >= 4 \
			and int(kinds.get("intel_safe", 0)) >= 3 \
			and int(kinds.get("ground_loot", 0)) >= 16
	)
	failed += _check("ground loot is a fast channel", func() -> bool:
		return _RaidSim._loot_channel_for_kind("ground_loot") < _RaidSim._loot_channel_for_kind("crate") \
			and not _Items.roll_container_loot("ground_loot").is_empty()
	)
	failed += _check("weapon case loot leans gear", func() -> bool:
		seed(42)
		var saw_gear := false
		for _i in 20:
			var loot: Array = _Items.roll_container_loot("weapon_case")
			for s in loot:
				var slot := String(_Items.get_item(String(s["def_id"]))["slot"])
				if slot == "weapon" or slot == "armor" or slot == "bag":
					saw_gear = true
					break
			if saw_gear:
				break
		var med: Array = _Items.roll_container_loot("med_cache")
		var has_med := false
		for s2 in med:
			if String(s2["def_id"]) == "medkit":
				has_med = true
		return saw_gear and has_med
	)
	failed += _check("weapon case takes longer to crack", func() -> bool:
		return _RaidSim._loot_channel_for_kind("weapon_case") > _RaidSim._loot_channel_for_kind("crate") \
			and _RaidSim._loot_channel_for_kind("ammo_crate") < _RaidSim._loot_channel_for_kind("crate")
	)
	failed += _check("roamer enters combat on LOS", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		world["obstacles"] = []
		world["player"]["pos"] = Vector2(400, 1600)
		var roamer: Dictionary = world["roamers"][0]
		roamer["pos"] = Vector2(480, 1600)
		roamer["alive"] = true
		roamer["aggro_range"] = 400.0
		roamer["ai_state"] = "patrol"
		_RaidSim.step_raid(world, 0.1, Vector2.ZERO, world["player"]["pos"], false, false, 4.0)
		return String(roamer["ai_state"]) == "combat"
	)
	failed += _check("roamer investigates noise then searches", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		world["obstacles"] = [{"x": 300.0, "y": 0.0, "w": 40.0, "h": 3200.0}]
		world["player"]["pos"] = Vector2(200, 1600)
		world["player"]["mag"] = 10
		var roamer: Dictionary = world["roamers"][0]
		roamer["pos"] = Vector2(520, 1600)
		roamer["alive"] = true
		roamer["ai_state"] = "patrol"
		# Shot noise through wall → investigate.
		_RaidSim.step_raid(world, 0.05, Vector2.ZERO, Vector2(250, 1600), true, false, 10.0)
		_RaidSim.step_raid(world, 0.1, Vector2.ZERO, Vector2(250, 1600), false, false, 10.0)
		var mid := String(roamer["ai_state"])
		# Clear noise; force combat then lose LOS → search sweep.
		world["noise_ttl"] = 0.0
		world["noise_radius"] = 0.0
		roamer["alert_ttl"] = 0.0
		roamer["ai_state"] = "combat"
		roamer["search_ttl"] = 2.0
		roamer["last_seen"] = roamer["pos"]
		_RaidSim.step_raid(world, 0.1, Vector2.ZERO, Vector2(250, 1600), false, false, 10.0)
		return (mid == "investigate" or mid == "search") and String(roamer["ai_state"]) == "search"
	)
	failed += _check("extracts have hot quiet contested pressure", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		var pressures := {}
		for z in world["extracts"]:
			pressures[String(z.get("pressure", ""))] = z
		if not pressures.has("hot") or not pressures.has("quiet") or not pressures.has("contested"):
			return false
		return float(pressures["hot"]["alarm_radius"]) > float(pressures["quiet"]["alarm_radius"]) \
			and float(pressures["quiet"]["hold_seconds"]) > float(pressures["hot"]["hold_seconds"])
	)
	failed += _check("quiet extract ignores far roamers", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		world["obstacles"] = []
		var quiet: Variant = null
		for z in world["extracts"]:
			if String(z.get("pressure", "")) == "quiet":
				quiet = z
				break
		if quiet == null:
			return false
		world["player"]["pos"] = quiet["pos"]
		var roamer: Dictionary = world["roamers"][0]
		roamer["pos"] = quiet["pos"] + Vector2(900, 0)
		roamer["alive"] = true
		roamer["ai_state"] = "patrol"
		var before: Vector2 = roamer["pos"]
		_RaidSim.step_raid(world, 0.25, Vector2.ZERO, quiet["pos"], false, false, 4.0)
		# Outside quiet alarm (~620) — should not rush.
		return bool(world["extract_alarm"]) and String(roamer["ai_state"]) != "rush" \
			and roamer["pos"].distance_to(before) < 40.0
	)
	failed += _check("hot extract pulls roamers from farther", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		world["obstacles"] = []
		var hot: Variant = null
		for z in world["extracts"]:
			if String(z.get("pressure", "")) == "hot":
				hot = z
				break
		if hot == null:
			return false
		world["player"]["pos"] = hot["pos"]
		var roamer: Dictionary = world["roamers"][0]
		roamer["pos"] = hot["pos"] + Vector2(1200, 0)
		roamer["alive"] = true
		var before: Vector2 = roamer["pos"]
		_RaidSim.step_raid(world, 0.25, Vector2.ZERO, hot["pos"], false, false, 4.0)
		return bool(world["extract_alarm"]) and String(roamer["ai_state"]) == "rush" \
			and roamer["pos"].distance_to(world["player"]["pos"]) < before.distance_to(world["player"]["pos"])
	)
	failed += _check("armor reduces damage then wears down", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		meta["loadout"]["armor_id"] = "plate_vest"
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		world["roamers"] = []
		var start_hp := float(world["player"]["hp"])
		var start_mit := float(world["player"]["mitigation"])
		var start_armor := float(world["player"]["armor_hp"])
		assert(start_mit > 0.2 and start_armor > 100.0)
		world["bullets"].append({
			"id": 9200,
			"pos": world["player"]["pos"],
			"vel": Vector2.ZERO,
			"damage": 40.0,
			"life": 1.0,
			"from_player": false,
			"radius": 8.0,
		})
		_RaidSim.step_raid(world, 0.05, Vector2.ZERO, world["player"]["pos"], false, false, 4.0)
		var after_hp := float(world["player"]["hp"])
		var after_armor := float(world["player"]["armor_hp"])
		var after_mit := float(world["player"]["mitigation"])
		# Plate should block some of the 40 — and lose durability.
		return after_hp > start_hp - 40.0 + 5.0 \
			and after_armor < start_armor \
			and after_mit < start_mit
	)
	failed += _check("armor can break to zero mitigation", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		meta["loadout"]["armor_id"] = "cloth_armor"
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		world["roamers"] = []
		world["player"]["armor_hp"] = 3.0
		world["player"]["base_mitigation"] = 0.5
		world["player"]["mitigation"] = 0.5
		world["bullets"].append({
			"id": 9201,
			"pos": world["player"]["pos"],
			"vel": Vector2.ZERO,
			"damage": 40.0,
			"life": 1.0,
			"from_player": false,
			"radius": 8.0,
		})
		_RaidSim.step_raid(world, 0.05, Vector2.ZERO, world["player"]["pos"], false, false, 4.0)
		return float(world["player"]["armor_hp"]) <= 0.0 and float(world["player"]["mitigation"]) <= 0.001
	)
	failed += _check("sprint-firing is louder than standing shots", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var stand := _RaidSim.create_raid_world(meta["loadout"], 0)
		var run := _RaidSim.create_raid_world(meta["loadout"], 0)
		stand["roamers"] = []
		run["roamers"] = []
		stand["player"]["mag"] = 10
		run["player"]["mag"] = 10
		run["player"]["stamina"] = 100.0
		var aim_s: Vector2 = stand["player"]["pos"] + Vector2(80, 0)
		var aim_r: Vector2 = run["player"]["pos"] + Vector2(80, 0)
		_RaidSim.step_raid(stand, 0.05, Vector2.ZERO, aim_s, true, false, 10.0, false, false, false)
		_RaidSim.step_raid(run, 0.05, Vector2(1, 0), aim_r, true, false, 10.0, false, false, true)
		return bool(run["player"]["sprinting"]) \
			and float(run["noise_radius"]) > float(stand["noise_radius"]) + 50.0
	)
	failed += _check("raid step moves player", func() -> bool:
		var meta: Dictionary = _MetaSim.create_meta_state()
		var world: Dictionary = _RaidSim.create_raid_world(meta["loadout"])
		var before: Vector2 = world["player"]["pos"]
		_RaidSim.step_raid(world, 0.1, Vector2(1, 0), before + Vector2(50, 0), false, false, 4.0)
		var after: Vector2 = world["player"]["pos"]
		return after.x > before.x
	)
	failed += _check("empty mag does not auto-reload", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		world["roamers"] = []
		world["bullets"] = []
		world["player"]["mag"] = 0
		world["player"]["reserve"] = 40
		# Fire with empty mag — must NOT start a reload channel.
		_RaidSim.step_raid(world, 0.05, Vector2.ZERO, world["player"]["pos"] + Vector2(40, 0), true, false, 10.0, false, false)
		return float(world["player"]["reload_channel"]) <= 0.0 and int(world["player"]["mag"]) == 0
	)
	failed += _check("skills raise and apply to raid", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var skills: Dictionary = _Skills.ensure(meta)
		skills["points"] = 3
		var note := _Skills.try_raise(skills, "packmule")
		var note2 := _Skills.try_raise(skills, "endurance")
		var world := _RaidSim.create_raid_world(meta["loadout"], 0, skills)
		var base_cap := _Items.loadout_capacity(meta["loadout"])
		return note.begins_with("Packmule") and note2.begins_with("Endurance") \
			and _Skills.rank(skills, "packmule") == 1 \
			and int(world["inventory_cap"]) == base_cap + 1 \
			and float(world["player"]["stamina_max"]) > 100.0 \
			and int(skills["points"]) == 1
	)
	failed += _check("egress awards a skill point", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		_Skills.ensure(meta)
		var before := int(meta["skills"]["points"])
		var gained := _Skills.award_extract(meta["skills"])
		return gained == 1 and int(meta["skills"]["points"]) == before + 1
	)
	failed += _check("raid deeds bonus skill points on extract", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		_Skills.ensure(meta)
		var world := _RaidSim.create_raid_world(meta["loadout"], 0, meta["skills"])
		world["skill_deeds"] = 12
		world["over"] = true
		world["outcome"] = "extracted"
		world["inventory"] = [_Items.stack_of("scrap", 1)]
		var result: Dictionary = _RaidSim.finalize_raid_result(world)
		var bonus := int(result.get("skill_bonus", 0))
		var before := int(meta["skills"]["points"])
		var gained := _Skills.award_extract(meta["skills"], bonus)
		return bonus == 2 and gained == 3 and int(meta["skills"]["points"]) == before + 3
	)
	failed += _check("save and load preserves meta", func() -> bool:
		_SaveGame.delete_save()
		var meta := _MetaSim.create_meta_state()
		_Skills.ensure(meta)
		meta["credits"] = 777
		meta["raids_completed"] = 4
		meta["skills"]["points"] = 2
		meta["skills"]["ranks"]["packmule"] = 2
		meta["stash"] = [_Items.stack_of("gold_watch", 3)]
		meta["loadout"]["weapon_id"] = "patrol_rifle"
		meta["loadout"]["armor_id"] = null
		var last := {
			"outcome": "extracted",
			"loot": [_Items.stack_of("scrap", 2)],
			"dropped": [],
			"influence_gained": 40,
			"skill_bonus": 1,
			"message": "ok",
		}
		if not _SaveGame.save_meta(meta, last):
			return false
		if not _SaveGame.has_save():
			return false
		var bundle := _SaveGame.load_bundle()
		_SaveGame.delete_save()
		var loaded: Dictionary = bundle.get("meta", {})
		var raid: Dictionary = bundle.get("last_raid", {})
		return not loaded.is_empty() \
			and int(loaded["credits"]) == 777 \
			and int(loaded["raids_completed"]) == 4 \
			and int(loaded["skills"]["points"]) == 2 \
			and int(loaded["skills"]["ranks"]["packmule"]) == 2 \
			and String(loaded["loadout"]["weapon_id"]) == "patrol_rifle" \
			and loaded["loadout"]["armor_id"] == null \
			and _Items.count_in_stacks(loaded["stash"], "gold_watch") == 3 \
			and String(raid.get("outcome", "")) == "extracted" \
			and int(raid.get("influence_gained", 0)) == 40 \
			and int(raid.get("skill_bonus", 0)) == 1
	)
	failed += _check("locker sorts by slot then name", func() -> bool:
		var stash: Array = [
			_Items.stack_of("scrap", 1),
			_Items.stack_of("patrol_rifle", 1),
			_Items.stack_of("cloth_armor", 1),
			_Items.stack_of("sling_bag", 1),
		]
		_Items.sort_stash(stash)
		return String(stash[0]["def_id"]) == "patrol_rifle" \
			and String(stash[1]["def_id"]) == "cloth_armor" \
			and String(stash[2]["def_id"]) == "sling_bag" \
			and String(stash[3]["def_id"]) == "scrap"
	)
	failed += _check("stores sell and buy", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		meta["stash"] = [_Items.stack_of("scrap", 2), _Items.stack_of("intel", 1)]
		meta["credits"] = 50
		var sell_note := _MetaSim.sell_from_stash(meta, "intel", 1)
		var after_sell := int(meta["credits"])
		var buy_note := _MetaSim.buy_to_stash(meta, "medkit", 1)
		var gear_block := _MetaSim.buy_to_stash(meta, "patrol_rifle", 1)
		return sell_note.begins_with("Sold") \
			and after_sell == 50 + _MetaSim.sell_price("intel") \
			and buy_note.begins_with("Bought") \
			and _Items.count_in_stacks(meta["stash"], "medkit") >= 1 \
			and gear_block.find("consumables") >= 0 \
			and int(meta["credits"]) == after_sell - _MetaSim.buy_price("medkit")
	)
	failed += _check("unequip returns gear to locker", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var before := _Items.count_in_stacks(meta["stash"], "cloth_armor")
		var note := _MetaSim.unequip_to_stash(meta, "armor_id")
		return note.begins_with("Unequipped") \
			and meta["loadout"]["armor_id"] == null \
			and _Items.count_in_stacks(meta["stash"], "cloth_armor") == before + 1
	)
	failed += _check("sell all loot keeps gear", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		meta["stash"] = [
			_Items.stack_of("scrap", 3),
			_Items.stack_of("intel", 1),
			_Items.stack_of("patrol_rifle", 1),
		]
		meta["credits"] = 10
		var expected := 10 + _MetaSim.sell_price("scrap") * 3 + _MetaSim.sell_price("intel")
		var note := _MetaSim.sell_all_loot(meta)
		return note.begins_with("Sold loot") \
			and int(meta["credits"]) == expected \
			and _Items.count_in_stacks(meta["stash"], "patrol_rifle") == 1 \
			and _Items.count_in_stacks(meta["stash"], "scrap") == 0
	)
	failed += _check("train spends influence for skill point", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		_Skills.ensure(meta)
		meta["influence"] = _MetaSim.SKILL_POINT_INFLUENCE_COST
		var before := int(meta["skills"]["points"])
		var note := _MetaSim.buy_skill_point(meta)
		var blocked := _MetaSim.buy_skill_point(meta)
		return note.begins_with("Trained") \
			and int(meta["skills"]["points"]) == before + 1 \
			and int(meta["influence"]) == 0 \
			and blocked.find("Need") >= 0
	)
	failed += _check("quick kit equips better locker gear", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		# Starter has rusty_smg on body; put a better rifle in stash.
		meta["stash"] = [_Items.stack_of("patrol_rifle", 1), _Items.stack_of("plate_vest", 1), _Items.stack_of("field_pack", 1)]
		meta["loadout"] = {"weapon_id": "rusty_smg", "armor_id": "cloth_armor", "bag_id": "sling_bag"}
		var note := _MetaSim.quick_kit_from_stash(meta)
		var again := _MetaSim.quick_kit_from_stash(meta)
		return note.begins_with("Quick kit") \
			and String(meta["loadout"]["weapon_id"]) == "patrol_rifle" \
			and String(meta["loadout"]["armor_id"]) == "plate_vest" \
			and String(meta["loadout"]["bag_id"]) == "field_pack" \
			and again.begins_with("Already") \
			and _MetaSim.loadout_at_risk_value(meta["loadout"]) > 100
	)
	failed += _check("raid history persists in save", func() -> bool:
		_SaveGame.delete_save()
		var meta := _MetaSim.create_meta_state()
		var hist: Array = [
			{"outcome": "extracted", "loot": [], "dropped": [], "influence_gained": 35, "skill_bonus": 0, "message": "ok"},
			{"outcome": "died", "loot": [], "dropped": [_Items.stack_of("scrap", 1)], "influence_gained": 0, "skill_bonus": 0, "message": "dead"},
			{"outcome": "extracted", "loot": [_Items.stack_of("intel", 1)], "dropped": [], "influence_gained": 40, "skill_bonus": 1, "message": "ok2"},
		]
		if not _SaveGame.save_meta(meta, hist[0], hist):
			return false
		var bundle := _SaveGame.load_bundle()
		_SaveGame.delete_save()
		var loaded_hist: Array = bundle.get("raid_history", [])
		return loaded_hist.size() == 3 \
			and String(loaded_hist[0].get("outcome", "")) == "extracted" \
			and String(loaded_hist[1].get("outcome", "")) == "died" \
			and String(loaded_hist[2].get("outcome", "")) == "extracted"
	)
	failed += _check("skill rank refund returns a point", func() -> bool:
		var skills := _Skills.create_state()
		skills["points"] = 2
		_Skills.try_raise(skills, "medic")
		_Skills.try_raise(skills, "medic")
		var note := _Skills.try_lower(skills, "medic")
		var blocked := _Skills.try_lower(skills, "endurance")
		return note.begins_with("Medic") \
			and _Skills.rank(skills, "medic") == 1 \
			and int(skills["points"]) == 1 \
			and blocked.find("clear") >= 0
	)
	failed += _check("sell stack dumps full qty", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		meta["stash"] = [_Items.stack_of("scrap", 5)]
		meta["credits"] = 0
		var note := _MetaSim.sell_from_stash(meta, "scrap", 5)
		return note.begins_with("Sold") \
			and int(meta["credits"]) == _MetaSim.sell_price("scrap") * 5 \
			and meta["stash"].is_empty()
	)
	failed += _check("soft get_item unknown id", func() -> bool:
		var stub: Dictionary = _Items.get_item("no_such_item_zzz")
		return String(stub.get("name", "")) == "Unknown" and String(stub.get("slot", "")) == "loot"
	)
	failed += _check("catalog has coil mesh flare", func() -> bool:
		return _Items.has_item("coil_carbine") and _Items.has_item("mesh_carrier") and _Items.has_item("mark_flare") \
			and String(_Items.get_item("coil_carbine")["slot"]) == "weapon" \
			and String(_Items.get_item("mesh_carrier")["slot"]) == "armor" \
			and String(_Items.get_item("mark_flare")["slot"]) == "loot"
	)
	failed += _check("intel pulse burns chip", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"])
		world["inventory"] = [_Items.stack_of("intel", 1)]
		_RaidSim.refresh_inventory_cap(world)
		world["intel_pulse_ttl"] = 0.0
		world["intel_pulse_cd"] = 0.0
		_RaidSim.step_raid(world, 0.0, Vector2.ZERO, world["player"]["pos"], false, false, 4.0, false, false, false, false, false, false, false, true)
		return float(world.get("intel_pulse_ttl", 0.0)) >= 3.5 \
			and _Items.count_in_stacks(world["inventory"], "intel") == 0
	)
	failed += _check("mark flare pulls contacts", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"])
		world["inventory"] = [_Items.stack_of("mark_flare", 1)]
		_RaidSim.refresh_inventory_cap(world)
		world["player"]["flare_cooldown"] = 0.0
		_RaidSim.step_raid(world, 0.0, Vector2.ZERO, world["player"]["pos"] + Vector2(100, 0), false, false, 4.0, false, false, false, false, false, false, false, false, true)
		return float(world.get("noise_radius", 0.0)) >= 500.0 \
			and _Items.count_in_stacks(world["inventory"], "mark_flare") == 0
	)
	failed += _check("gear_score prefers armor mit", func() -> bool:
		return _MetaSim.gear_score("mesh_carrier") > _MetaSim.gear_score("cloth_armor") \
			and _MetaSim.gear_score("coil_carbine") > _MetaSim.gear_score("field_pistol")
	)
	failed += _check("bag-full loot stays in container", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		world["roamers"] = []
		world["inventory"] = [_Items.stack_of("scrap", int(world["inventory_cap"]))]
		_RaidSim.refresh_inventory_cap(world)
		var crate: Dictionary = world["crates"][0]
		crate["opened"] = false
		crate["kind"] = "crate"
		crate["contents"] = [_Items.stack_of("gold_watch", 1), _Items.stack_of("intel", 1)]
		crate["pos"] = world["player"]["pos"] + Vector2(12, 0)
		_RaidSim.step_raid(world, 0.0, Vector2.ZERO, world["player"]["pos"], false, true, 4.0)
		for _i in 40:
			world["roamers"] = []
			world["bullets"] = []
			_RaidSim.step_raid(world, 0.1, Vector2.ZERO, world["player"]["pos"], false, false, 4.0)
		return not bool(crate["opened"]) \
			and (crate["contents"] as Array).size() >= 2 \
			and _Items.count_in_stacks(world["inventory"], "gold_watch") == 0
	)
	failed += _check("partial loot keeps remainder", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		world["roamers"] = []
		# One free slot — 3-scrap stack should take 1 and leave 2.
		world["inventory"] = [_Items.stack_of("medkit", int(world["inventory_cap"]) - 1)]
		_RaidSim.refresh_inventory_cap(world)
		var crate: Dictionary = world["crates"][0]
		crate["opened"] = false
		crate["contents"] = [_Items.stack_of("scrap", 3)]
		crate["pos"] = world["player"]["pos"] + Vector2(12, 0)
		_RaidSim.step_raid(world, 0.0, Vector2.ZERO, world["player"]["pos"], false, true, 4.0)
		for _i in 40:
			world["roamers"] = []
			world["bullets"] = []
			_RaidSim.step_raid(world, 0.1, Vector2.ZERO, world["player"]["pos"], false, false, 4.0)
		return _Items.count_in_stacks(world["inventory"], "scrap") == 1 \
			and not bool(crate["opened"]) \
			and _Items.count_in_stacks(crate["contents"], "scrap") == 2
	)
	failed += _check("packed medkits survive save round-trip", func() -> bool:
		_SaveGame.delete_save()
		var meta := _MetaSim.create_meta_state()
		meta["packed_medkits"] = 2
		meta["packed_scrap"] = 1
		if not _SaveGame.save_meta(meta):
			return false
		var bundle := _SaveGame.load_bundle()
		_SaveGame.delete_save()
		var loaded: Dictionary = bundle.get("meta", {})
		return int(loaded.get("packed_medkits", 0)) == 2 \
			and int(loaded.get("packed_scrap", 0)) == 1
	)
	failed += _check("count_in_stacks sums duplicate rows", func() -> bool:
		var stacks: Array = [
			_Items.stack_of("scrap", 2),
			_Items.stack_of("medkit", 1),
			{"def_id": "scrap", "qty": 3},
		]
		return _Items.count_in_stacks(stacks, "scrap") == 5
	)
	failed += _check("hydrate merges duplicate stash rows", func() -> bool:
		_SaveGame.delete_save()
		var meta := _MetaSim.create_meta_state()
		meta["stash"] = [
			_Items.stack_of("scrap", 2),
			{"def_id": "scrap", "qty": 4},
		]
		if not _SaveGame.save_meta(meta):
			return false
		var loaded := _SaveGame.load_meta()
		_SaveGame.delete_save()
		var scrap_rows := 0
		for s in loaded.get("stash", []):
			if String(s["def_id"]) == "scrap":
				scrap_rows += 1
		return scrap_rows == 1 and _Items.count_in_stacks(loaded["stash"], "scrap") == 6
	)
	failed += _check("equip rejects wrong slot", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		meta["stash"] = [_Items.stack_of("medkit", 1)]
		var note := _MetaSim.equip_from_stash(meta, "weapon_id", "medkit")
		return note.find("can't go") >= 0 \
			and String(meta["loadout"].get("weapon_id", "")) != "medkit" \
			and _Items.count_in_stacks(meta["stash"], "medkit") == 1
	)
	failed += _check("selection remaps after sort by def_id", func() -> bool:
		var stash: Array = [
			_Items.stack_of("scrap", 1),
			_Items.stack_of("patrol_rifle", 1),
			_Items.stack_of("cloth_armor", 1),
		]
		var selected_def := "scrap"
		_Items.sort_stash(stash)
		var idx := _Items.index_of_def(stash, selected_def)
		return idx >= 0 and String(stash[idx]["def_id"]) == "scrap"
	)
	failed += _check("medkit pack excess sets refund", func() -> bool:
		# Pockets-only cap is 2; asking for 5 must pack 2 and refund 3.
		var world := _RaidSim.create_raid_world(
			{"weapon_id": null, "armor_id": null, "bag_id": null}, 5
		)
		return int(world.get("pack_refund_medkits", -1)) == 3 \
			and _Items.count_in_stacks(world["inventory"], "medkit") == 2 \
			and int(world["inventory_cap"]) == 2
	)
	failed += _check("item migrate raid_rifle on load", func() -> bool:
		_SaveGame.delete_save()
		var payload := {
			"version": 2,
			"saved_at": 1,
			"meta": {
				"stash": [{"def_id": "raid_rifle", "qty": 1}, {"def_id": "raid_pack", "qty": 1}],
				"loadout": {"weapon_id": "raid_rifle", "armor_id": null, "bag_id": "raid_pack"},
				"skills": {"points": 0, "ranks": {}},
				"influence": 0,
				"credits": 0,
				"hub_visit_id": 0,
				"raids_completed": 0,
				"raids_survived": 0,
				"pack_scrap_qty": 0,
			},
			"last_raid": {},
			"raid_history": [],
		}
		var f := FileAccess.open(_SaveGame.SAVE_PATH, FileAccess.WRITE)
		if f == null:
			return false
		f.store_string(JSON.stringify(payload))
		f.close()
		var loaded := _SaveGame.load_meta()
		_SaveGame.delete_save()
		return String(loaded["loadout"].get("weapon_id", "")) == "patrol_rifle" \
			and String(loaded["loadout"].get("bag_id", "")) == "field_pack" \
			and _Items.count_in_stacks(loaded["stash"], "patrol_rifle") == 1 \
			and _Items.count_in_stacks(loaded["stash"], "field_pack") == 1
	)
	failed += _check("corrupt save reports empty bundle", func() -> bool:
		_SaveGame.delete_save()
		var f := FileAccess.open(_SaveGame.SAVE_PATH, FileAccess.WRITE)
		f.store_string("not-json{{{")
		f.close()
		var bundle := _SaveGame.load_bundle()
		var err := _SaveGame.last_load_error
		_SaveGame.delete_save()
		return bundle.is_empty() and not err.is_empty()
	)
	failed += _check("try_add_inventory_partial respects cap", func() -> bool:
		var inv: Array = [_Items.stack_of("scrap", 1)]
		var left := _Items.try_add_inventory_partial(inv, 3, _Items.stack_of("medkit", 5))
		return left == 3 and _Items.count_in_stacks(inv, "medkit") == 2 \
			and _Items.inventory_used(inv) == 3
	)
	failed += _check("aborted result has full schema", func() -> bool:
		var meta := _MetaSim.create_meta_state()
		var world := _RaidSim.create_raid_world(meta["loadout"], 0)
		world["over"] = true
		world["outcome"] = "aborted"
		var result := _RaidSim.finalize_raid_result(world)
		return String(result.get("outcome", "")) == "aborted" \
			and result.has("dropped") and result.has("skill_bonus") and result.has("loot")
	)

	if failed == 0:
		print("SMOKE_OK exfac")
		quit(0)
	else:
		print("SMOKE_FAIL count=%d" % failed)
		quit(1)


func _check(name: String, fn: Callable) -> int:
	var ok: bool = fn.call()
	print(("PASS" if ok else "FAIL"), " ", name)
	return 0 if ok else 1
