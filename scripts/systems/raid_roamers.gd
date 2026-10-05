class_name RaidRoamers
extends RefCounted
## Roamer / enforcer field AI â€” RaidSim owns world helpers; this owns contact brains.

# Runtime load â€” avoids circular preload with raid.gd.
static var _host: GDScript


static func _R() -> GDScript:
	if _host == null:
		_host = load("res://scripts/systems/raid.gd") as GDScript
	return _host


## Keep in sync with RaidSim â€” duplicated so AI consts stay typed without host lookups.
const EXTRACT_ALARM_RADIUS := 1400.0
const HEAR_SPRINT_RANGE := 240.0
const MELEE_SLOW_MULT := 0.4
const ROAMER_SUPPRESS_SPREAD := 0.14


static func _host_extract_alarm(world: Dictionary, zone: Dictionary) -> float:
	return float(_R().call("_effective_extract_alarm", world, zone))


static func _host_has_los(from: Vector2, to: Vector2, obstacles: Array) -> bool:
	return bool(_R().call("has_line_of_sight", from, to, obstacles))


static func _host_collide(actor: Dictionary, obstacles: Array) -> void:
	_R().call("_collide_actor_obstacles", actor, obstacles)


static func _host_clamp(actor: Dictionary, w: float, h: float) -> void:
	_R().call("_clamp_to_map", actor, w, h)


static func _host_spawn_bullet(world: Dictionary, from: Dictionary, aim: Vector2, from_player: bool, speed: float) -> void:
	_R().call("_spawn_bullet", world, from, aim, from_player, speed)


static func _host_push_float(world: Dictionary, pos: Vector2, text: String, color: Color, life: float = 1.1) -> void:
	_R().call("_push_float", world, pos, text, color, life)


static func _host_set_message(world: Dictionary, msg: String, ttl: float = 2.5) -> void:
	_R().call("_set_message", world, msg, ttl)


static func _host_emit_noise(world: Dictionary, pos: Vector2, radius: float, ttl: float) -> void:
	_R().call("_emit_noise", world, pos, radius, ttl)

## Roamer AI — explicit states so hearing / LOS / extract rush don't fight each other.
const ROAMER_SEARCH_TTL := 3.2
const ROAMER_COMBAT_HOLD_RANGE := 95.0
const ROAMER_COMBAT_BACK_RANGE := 62.0
## Wounded retreat — battered roamers break contact; enforcers hold the line.
const ROAMER_RETREAT_HP := 0.32
const ROAMER_RETREAT_RANGE := 170.0
const ROAMER_RETREAT_SPEED := 1.28
const ROAMER_RETREAT_FIRE_GAP := 1.35
## Flank peel — a second contact circles wide instead of stacking mid-range.
const ROAMER_FLANK_RANGE := 145.0
const ROAMER_FLANK_SPEED := 1.15
## Corpse strip — idle roamers steal unlooted bodies before you do.
const ROAMER_SCAVENGE_RANGE := 28.0
const ROAMER_SCAVENGE_SPOT := 160.0
const ROAMER_FORAGE_TIME := 2.35
## Alert call — a roamer who spots you shouts; allies investigate the call.
const ALERT_CALL_RANGE := 420.0
const ALERT_CALL_COOLDOWN := 2.8
## Enforcer distress — a hurt elite yells farther and wakes the compound.
const ENFORCER_DISTRESS_HP := 0.5
const ENFORCER_DISTRESS_RANGE := 780.0
## Blood scent pull range (trail itself still owned by RaidSim).
const BLOOD_SCENT_RANGE := 160.0

static func update(world: Dictionary, dt: float) -> void:
	var player: Dictionary = world["player"]
	var alarm := bool(world.get("extract_alarm", false))
	var extract_pos := Vector2.ZERO
	if alarm:
		for z in world["extracts"]:
			if int(z["id"]) == int(world.get("active_extract_id", -1)):
				extract_pos = z["pos"]
				break

	var noise_ttl := float(world.get("noise_ttl", 0.0))
	var noise_radius := float(world.get("noise_radius", 0.0))
	var noise_pos: Vector2 = world.get("noise_pos", Vector2.ZERO)

	var contest_count := 0
	var active_alarm_radius: float = EXTRACT_ALARM_RADIUS
	if alarm:
		for z in world["extracts"]:
			if int(z["id"]) == int(world.get("active_extract_id", -1)):
				active_alarm_radius = _host_extract_alarm(world, z)
				break
	for roamer in world["roamers"]:
		roamer["hit_flash"] = maxf(0.0, float(roamer["hit_flash"]) - dt)
		roamer["alert_ttl"] = maxf(0.0, float(roamer.get("alert_ttl", 0.0)) - dt)
		roamer["search_ttl"] = maxf(0.0, float(roamer.get("search_ttl", 0.0)) - dt)
		roamer["call_cooldown"] = maxf(0.0, float(roamer.get("call_cooldown", 0.0)) - dt)
		roamer["suppress_ttl"] = maxf(0.0, float(roamer.get("suppress_ttl", 0.0)) - dt)
		roamer["telegraph_ttl"] = maxf(0.0, float(roamer.get("telegraph_ttl", 0.0)) - dt)
		if not bool(roamer["alive"]):
			continue
		# Re-assert root before AI — any leftover slide from last frame is undone.
		if _melee_rooted(roamer) and roamer.has("melee_root_pos"):
			roamer["pos"] = roamer["melee_root_pos"]
		roamer["fire_cooldown"] = maxf(0.0, float(roamer["fire_cooldown"]) - dt)
		var to_player: Vector2 = player["pos"] - roamer["pos"]
		var d := to_player.length()
		var sees_player: bool = bool(player["alive"]) and d < float(roamer["aggro_range"]) \
				and _host_has_los(roamer["pos"], player["pos"], world["obstacles"])

		# Hearing: gunshots / sprint pull roamers even through walls.
		var hears := false
		if bool(player["alive"]) and noise_ttl > 0.0 and noise_radius > 0.0:
			var hear_reach := noise_radius * float(roamer.get("hear_mult", 1.0)) * float(world.get("dusk_hear_mult", 1.0))
			var nd: float = roamer["pos"].distance_to(noise_pos)
			if nd <= hear_reach:
				hears = true
				var alert_boost := 3.2 if bool(roamer.get("elite", false)) else 2.4
				roamer["alert_ttl"] = maxf(float(roamer["alert_ttl"]), alert_boost)
				roamer["last_heard"] = noise_pos

		# Blood scent — wounded trails pull patrols even when you're quiet.
		# Sets last_heard only (not acoustic hears) so investigate never chases stale noise_pos.
		var scent_pull := false
		if not hears and not sees_player and bool(player["alive"]):
			var scent: Variant = nearest_blood(world, roamer["pos"], BLOOD_SCENT_RANGE)
			if scent != null:
				scent_pull = true
				roamer["alert_ttl"] = maxf(float(roamer.get("alert_ttl", 0.0)), 1.8)
				roamer["last_heard"] = scent

		# Spot call — first contact shouts so nearby allies push your last known.
		if sees_player and float(roamer.get("call_cooldown", 0.0)) <= 0.0:
			alert_call(world, roamer, player["pos"])
			roamer["call_cooldown"] = ALERT_CALL_COOLDOWN

		# Hurt enforcer — one distress blast that wakes dormants across a wide ring.
		if bool(roamer.get("elite", false)) and not bool(roamer.get("distress_fired", false)):
			var hp_ratio := float(roamer["hp"]) / maxf(1.0, float(roamer.get("max_hp", roamer["hp"])))
			if hp_ratio <= ENFORCER_DISTRESS_HP:
				distress_call(world, roamer, player["pos"] if bool(player["alive"]) else roamer["pos"])
				roamer["distress_fired"] = true

		var near_extract_rush := false
		if alarm and bool(player["alive"]):
			var to_ex: Vector2 = extract_pos - (roamer["pos"] as Vector2)
			near_extract_rush = to_ex.length() <= active_alarm_radius

		# Wake dormant roamers on gunshots / sprint / extract flare — not soft walks.
		if bool(roamer.get("dormant", false)):
			var wake: bool = (hears and noise_radius >= HEAR_SPRINT_RANGE * 0.9) or sees_player or near_extract_rush
			if wake:
				roamer["dormant"] = false
				roamer["aggro_range"] = maxf(float(roamer["aggro_range"]), randf_range(200.0, 320.0))
			else:
				roamer["ai_state"] = "dormant"
				_host_collide(roamer, world["obstacles"])
				_host_clamp(roamer, float(world["width"]), float(world["height"]))
				if _melee_rooted(roamer) and roamer.has("melee_root_pos"):
					roamer["pos"] = roamer["melee_root_pos"]
				_tick_melee_slow(roamer, dt)
				continue

		# Extract rush overrides local AI — radius depends on the exit's pressure profile.
		var rushing := false
		if near_extract_rush:
			rushing = true
			contest_count += 1
			roamer["ai_state"] = "rush"
			var to_extract: Vector2 = extract_pos - (roamer["pos"] as Vector2)
			roamer["aim"] = to_player.normalized() if d > 1e-6 else to_extract.normalized()
			# Punch-slow roots feet — rush must not backpedal/teleport away on contact.
			if not _melee_rooted(roamer):
				if d > 85.0:
					roamer["pos"] = roamer["pos"] + (roamer["aim"] as Vector2) * _speed(roamer) * 1.35 * dt
				elif d < 55.0:
					roamer["pos"] = roamer["pos"] - (roamer["aim"] as Vector2) * _speed(roamer) * 0.35 * dt
			# Rush fire needs LOS — close range alone must not shoot through walls.
			if float(roamer["fire_cooldown"]) <= 0.0 and sees_player:
				var rdir := (roamer["aim"] as Vector2).rotated(randf_range(-shot_spread(roamer), shot_spread(roamer)))
				_host_spawn_bullet(world, roamer, rdir, false, 460.0)
				roamer["fire_cooldown"] = randf_range(0.28, 0.55)

		if not rushing:
			_pick_state(world, roamer, sees_player, hears or scent_pull, bool(player["alive"]))
			# Idle contacts strip unlooted bodies — don't leave free kits on the ground.
			if String(roamer.get("ai_state", "")) in ["patrol", "search", "forage"]:
				_try_start_forage(world, roamer)
			match String(roamer.get("ai_state", "patrol")):
				"combat":
					_do_combat(world, roamer, player, to_player, d, dt)
				"flank":
					_do_flank(world, roamer, player, to_player, d, dt)
				"retreat":
					_do_retreat(world, roamer, player, to_player, d, dt)
				"forage":
					_do_forage(world, roamer, dt)
				"investigate":
					# Always chase last_heard (noise + scent write it); never fall back to stale noise_pos.
					_do_investigate(world, roamer, roamer.get("last_heard", player["pos"]), dt)
				"search":
					_do_search(world, roamer, dt)
				"dormant":
					pass
				_:
					_do_patrol(world, roamer, dt)

		_host_collide(roamer, world["obstacles"])
		_host_clamp(roamer, float(world["width"]), float(world["height"]))
		# Hard pin while punch-rooted — AI/collision must not slide them away.
		if _melee_rooted(roamer) and roamer.has("melee_root_pos"):
			roamer["pos"] = roamer["melee_root_pos"]
		# Expire slow after the pin so the last rooted frame isn't a surprise backpedal.
		_tick_melee_slow(roamer, dt)
	world["extract_contest_count"] = contest_count


static func _speed(roamer: Dictionary) -> float:
	var spd := float(roamer.get("speed", 0.0))
	if float(roamer.get("melee_slow_ttl", 0.0)) > 0.0:
		spd *= MELEE_SLOW_MULT
	return spd


static func _tick_melee_slow(roamer: Dictionary, dt: float) -> void:
	var ttl := float(roamer.get("melee_slow_ttl", 0.0))
	if ttl <= 0.0:
		roamer["melee_slow_ttl"] = 0.0
		return
	roamer["melee_slow_ttl"] = maxf(0.0, ttl - dt)


static func _pick_state(world: Dictionary, roamer: Dictionary, sees_player: bool, hears: bool, player_alive: bool) -> void:
	if not player_alive:
		roamer["ai_state"] = "patrol"
		return
	if sees_player:
		var hp_ratio := float(roamer["hp"]) / maxf(1.0, float(roamer.get("max_hp", roamer["hp"])))
		# Enforcers hold; battered roamers break contact and try to open range.
		if hp_ratio <= ROAMER_RETREAT_HP and not bool(roamer.get("elite", false)):
			roamer["ai_state"] = "retreat"
		else:
			var prev_spot := String(roamer.get("ai_state", "patrol"))
			roamer["ai_state"] = "combat"
			# First lock — elite telegraph so the fight doesn't feel like a cheap scrap.
			if bool(roamer.get("elite", false)) and not bool(roamer.get("telegraph_shown", false)) \
					and prev_spot != "combat" and prev_spot != "flank" and prev_spot != "rush":
				roamer["telegraph_shown"] = true
				roamer["telegraph_ttl"] = 1.1
				_host_push_float(world, roamer["pos"] + Vector2(0, -24), "ENFORCER", Color("c9a0ff"), 1.2)
				_host_set_message(world, "Enforcer locked on — heavy fire.", 2.0)
				world["shake"] = maxf(float(world.get("shake", 0.0)), 5.0)
		roamer["alert_ttl"] = maxf(float(roamer.get("alert_ttl", 0.0)), 1.5)
		roamer["search_ttl"] = ROAMER_SEARCH_TTL
		return
	var prev := String(roamer.get("ai_state", "patrol"))
	if prev == "combat" or prev == "retreat" or prev == "flank":
		# Lost LOS — sweep last known area before giving up.
		roamer["ai_state"] = "search"
		roamer["search_ttl"] = maxf(float(roamer.get("search_ttl", 0.0)), ROAMER_SEARCH_TTL)
		return
	if hears or float(roamer.get("alert_ttl", 0.0)) > 0.0:
		roamer["ai_state"] = "investigate"
		return
	if prev == "search" and float(roamer.get("search_ttl", 0.0)) > 0.0:
		return
	# Search burned out with no fresh contact — some settle back to dormant.
	if prev == "search" and float(roamer.get("search_ttl", 0.0)) <= 0.0 \
			and not bool(roamer.get("elite", false)) \
			and not bool(roamer.get("dormant", false)) \
			and String(roamer.get("role", "roamer")) == "roamer":
		if int(roamer["id"]) % 3 == 0:
			roamer["dormant"] = true
			roamer["ai_state"] = "dormant"
			roamer["aggro_range"] = maxf(90.0, float(roamer.get("aggro_range", 200.0)) * 0.45)
			return
	roamer["ai_state"] = "patrol"


static func _should_flank(world: Dictionary, roamer: Dictionary) -> bool:
	if bool(roamer.get("elite", false)):
		return false
	var my_id := int(roamer["id"])
	for other in world["roamers"]:
		if other == roamer or not bool(other["alive"]):
			continue
		if bool(other.get("elite", false)):
			continue
		var st := String(other.get("ai_state", "patrol"))
		if st != "combat" and st != "flank" and st != "rush":
			continue
		# Lower id pins mid-range; higher id peels wide.
		if int(other["id"]) < my_id:
			return true
	return false


static func _melee_rooted(roamer: Dictionary) -> bool:
	## Contact stun-slow — no backpedal/separation while hobbled (that read as a teleport shove).
	return float(roamer.get("melee_slow_ttl", 0.0)) > 0.0


static func _do_combat(world: Dictionary, roamer: Dictionary, player: Dictionary, to_player: Vector2, d: float, dt: float) -> void:
	if _should_flank(world, roamer) and not _melee_rooted(roamer):
		roamer["ai_state"] = "flank"
		_do_flank(world, roamer, player, to_player, d, dt)
		return
	roamer["ai_state"] = "combat"
	roamer["last_seen"] = player["pos"]
	roamer["aim"] = to_player.normalized() if d > 1e-6 else Vector2.RIGHT
	# While punch-slowed: feet planted — aim/fire only, no range pocket shuffle.
	if _melee_rooted(roamer):
		pass
	elif d > ROAMER_COMBAT_HOLD_RANGE:
		roamer["pos"] = roamer["pos"] + roamer["aim"] * _speed(roamer) * dt
	elif d < ROAMER_COMBAT_BACK_RANGE:
		roamer["pos"] = roamer["pos"] - roamer["aim"] * _speed(roamer) * 0.55 * dt
	else:
		var side := (roamer["aim"] as Vector2).orthogonal().normalized()
		if int(roamer["id"]) % 2 == 0:
			side = -side
		roamer["pos"] = roamer["pos"] + side * _speed(roamer) * 0.45 * dt
	if float(roamer["fire_cooldown"]) <= 0.0:
		var sdir := (roamer["aim"] as Vector2).rotated(randf_range(-shot_spread(roamer), shot_spread(roamer)))
		var shot_speed := 480.0 if bool(roamer.get("elite", false)) else 420.0
		_host_spawn_bullet(world, roamer, sdir, false, shot_speed)
		var gap := randf_range(0.5, 0.95) * float(roamer.get("fire_gap_mult", 1.0))
		roamer["fire_cooldown"] = gap


static func _do_flank(world: Dictionary, roamer: Dictionary, player: Dictionary, to_player: Vector2, d: float, dt: float) -> void:
	roamer["last_seen"] = player["pos"]
	roamer["aim"] = to_player.normalized() if d > 1e-6 else Vector2.RIGHT
	if not _melee_rooted(roamer):
		var side := (roamer["aim"] as Vector2).orthogonal().normalized()
		if int(roamer["id"]) % 2 == 0:
			side = -side
		var anchor: Vector2 = player["pos"] + side * ROAMER_FLANK_RANGE
		var to_anchor: Vector2 = anchor - (roamer["pos"] as Vector2)
		if to_anchor.length() > 12.0:
			roamer["pos"] = roamer["pos"] + to_anchor.normalized() * _speed(roamer) * ROAMER_FLANK_SPEED * dt
	if float(roamer["fire_cooldown"]) <= 0.0 and d < ROAMER_FLANK_RANGE * 1.35:
		var sdir := (roamer["aim"] as Vector2).rotated(randf_range(-shot_spread(roamer), shot_spread(roamer)))
		_host_spawn_bullet(world, roamer, sdir, false, 430.0)
		roamer["fire_cooldown"] = randf_range(0.55, 0.95) * float(roamer.get("fire_gap_mult", 1.0))


static func _do_retreat(world: Dictionary, roamer: Dictionary, player: Dictionary, to_player: Vector2, d: float, dt: float) -> void:
	roamer["last_seen"] = player["pos"]
	roamer["aim"] = to_player.normalized() if d > 1e-6 else Vector2.RIGHT
	# Break contact — open range hard, then sidestep while keeping eyes on you.
	# Punch-slow roots feet so a hit never looks like a teleport shove away.
	if not _melee_rooted(roamer):
		var away := -(roamer["aim"] as Vector2)
		if d < ROAMER_RETREAT_RANGE:
			roamer["pos"] = roamer["pos"] + away * _speed(roamer) * ROAMER_RETREAT_SPEED * dt
		else:
			var side := (roamer["aim"] as Vector2).orthogonal().normalized()
			if int(roamer["id"]) % 2 == 0:
				side = -side
			roamer["pos"] = roamer["pos"] + (away * 0.35 + side * 0.65) * _speed(roamer) * dt
	if float(roamer["fire_cooldown"]) <= 0.0 and d < ROAMER_RETREAT_RANGE * 1.15:
		var sdir := (roamer["aim"] as Vector2).rotated(randf_range(-shot_spread(roamer) - 0.08, shot_spread(roamer) + 0.08))
		_host_spawn_bullet(world, roamer, sdir, false, 400.0)
		roamer["fire_cooldown"] = randf_range(0.85, 1.25) * ROAMER_RETREAT_FIRE_GAP


static func _find_forage_target(world: Dictionary, roamer: Dictionary) -> Variant:
	var best: Variant = null
	var best_d := ROAMER_SCAVENGE_SPOT
	for c in world["crates"]:
		if bool(c.get("opened", false)):
			continue
		var kind := String(c.get("kind", ""))
		if kind != "corpse" and kind != "drop_bag":
			continue
		var d: float = roamer["pos"].distance_to(c["pos"])
		if d <= best_d:
			best_d = d
			best = c
	return best


static func _try_start_forage(world: Dictionary, roamer: Dictionary) -> void:
	if bool(roamer.get("elite", false)) or bool(roamer.get("dormant", false)):
		return
	if String(roamer.get("ai_state", "")) == "forage":
		var tid := int(roamer.get("forage_target_id", -1))
		var still: Variant = null
		for c in world["crates"]:
			if int(c["id"]) == tid and not bool(c.get("opened", false)):
				still = c
				break
		if still != null:
			return
		roamer["ai_state"] = "patrol"
		roamer["forage_ttl"] = 0.0
		roamer["forage_target_id"] = -1
	var target: Variant = _find_forage_target(world, roamer)
	if target == null:
		return
	# Don't pile onto a body another roamer is already stripping.
	var tid2 := int(target["id"])
	for other in world["roamers"]:
		if other == roamer or not bool(other["alive"]):
			continue
		if String(other.get("ai_state", "")) == "forage" and int(other.get("forage_target_id", -1)) == tid2:
			return
	roamer["ai_state"] = "forage"
	roamer["forage_target_id"] = tid2
	roamer["forage_ttl"] = float(roamer.get("forage_ttl", 0.0))
	if float(roamer["forage_ttl"]) <= 0.0:
		roamer["forage_ttl"] = 0.0


static func _do_forage(world: Dictionary, roamer: Dictionary, dt: float) -> void:
	var tid := int(roamer.get("forage_target_id", -1))
	var target: Variant = null
	for c in world["crates"]:
		if int(c["id"]) == tid:
			target = c
			break
	if target == null or bool(target.get("opened", false)):
		roamer["ai_state"] = "patrol"
		roamer["forage_ttl"] = 0.0
		roamer["forage_target_id"] = -1
		return
	var to_t: Vector2 = target["pos"] - roamer["pos"]
	var dist := to_t.length()
	if dist > ROAMER_SCAVENGE_RANGE:
		roamer["aim"] = to_t.normalized()
		roamer["pos"] = roamer["pos"] + roamer["aim"] * _speed(roamer) * 0.85 * dt
		return
	roamer["forage_ttl"] = float(roamer.get("forage_ttl", 0.0)) + dt
	if float(roamer["forage_ttl"]) < ROAMER_FORAGE_TIME:
		return
	target["opened"] = true
	target["contents"] = []
	roamer["forage_ttl"] = 0.0
	roamer["forage_target_id"] = -1
	roamer["ai_state"] = "patrol"
	_host_push_float(world, target["pos"] + Vector2(0, -12), "STRIPPED", Color("c4785c"), 1.0)
	_host_set_message(world, "Roamer stripped a body — loot's gone.", 2.0)


static func _do_investigate(world: Dictionary, roamer: Dictionary, target: Vector2, dt: float) -> void:
	var to_noise: Vector2 = target - roamer["pos"]
	var nd := to_noise.length()
	if nd > 28.0:
		roamer["aim"] = to_noise.normalized()
		roamer["pos"] = roamer["pos"] + roamer["aim"] * _speed(roamer) * 1.05 * dt
	else:
		# Arrive: pause and scan — keeps search from instantly flipping to idle.
		roamer["alert_ttl"] = maxf(float(roamer.get("alert_ttl", 0.0)), 0.6)
		roamer["ai_state"] = "search"
		roamer["search_ttl"] = maxf(float(roamer.get("search_ttl", 0.0)), 1.4)
		roamer["last_seen"] = target


static func _do_search(world: Dictionary, roamer: Dictionary, dt: float) -> void:
	var focus: Vector2 = roamer.get("last_seen", roamer.get("last_heard", roamer["pos"]))
	var phase := float(world["time_alive"]) * 1.7 + float(roamer["id"]) * 0.9
	var orbit := Vector2(cos(phase), sin(phase)) * 42.0
	var target := focus + orbit
	var to_t: Vector2 = target - roamer["pos"]
	if to_t.length() > 8.0:
		roamer["aim"] = to_t.normalized()
		roamer["pos"] = roamer["pos"] + roamer["aim"] * _speed(roamer) * 0.7 * dt


static func _do_patrol(_world: Dictionary, roamer: Dictionary, dt: float) -> void:
	var anchor: Vector2 = roamer.get("patrol_anchor", roamer["pos"])
	var phase := float(roamer.get("patrol_phase", 0.0)) + dt * (0.55 if bool(roamer.get("elite", false)) else 0.7)
	roamer["patrol_phase"] = phase
	# Wardens orbit their extract tighter; roamers wander farther.
	var radius := 55.0 if bool(roamer.get("elite", false)) else 90.0
	var wander := Vector2(cos(phase), sin(phase * 0.7)) * radius
	var target := anchor + wander
	var to_t: Vector2 = target - roamer["pos"]
	if to_t.length() > 6.0:
		roamer["aim"] = to_t.normalized()
		roamer["pos"] = roamer["pos"] + roamer["aim"] * _speed(roamer) * (0.55 if bool(roamer.get("elite", false)) else 0.45) * dt

## Default ttl matches RaidSim.ROAMER_SUPPRESS_TTL (literal — defaults can't call _R()).
static func apply_suppression(roamer: Dictionary, gap: float, ttl: float = 0.7) -> void:
	roamer["suppress_ttl"] = maxf(float(roamer.get("suppress_ttl", 0.0)), ttl)
	roamer["fire_cooldown"] = maxf(float(roamer.get("fire_cooldown", 0.0)), gap)
	# Wake anyone you pin — dormants don't tank near-misses forever.
	roamer["dormant"] = false
	roamer["alert_ttl"] = maxf(float(roamer.get("alert_ttl", 0.0)), 1.2)


static func shot_spread(roamer: Dictionary) -> float:
	var spread := 0.07
	if float(roamer.get("suppress_ttl", 0.0)) > 0.0:
		spread += ROAMER_SUPPRESS_SPREAD
	if bool(roamer.get("elite", false)):
		spread *= 0.75
	return spread

static func nearest_blood(world: Dictionary, from: Vector2, range_v: float) -> Variant:
	var best: Variant = null
	var best_d := range_v
	for drop in world.get("blood_trail", []):
		var d: float = from.distance_to(drop["pos"])
		if d <= best_d:
			best_d = d
			best = drop["pos"]
	return best


static func alert_call(world: Dictionary, caller: Dictionary, target_pos: Vector2) -> void:
	# Soft shout float — no HUD spam; nearby allies get a investigate ping.
	_host_push_float(world, caller["pos"] + Vector2(0, -18), "!", Color("ffb0b0"), 0.55)
	var call_r := ALERT_CALL_RANGE * (1.2 if bool(caller.get("elite", false)) else 1.0)
	for other in world["roamers"]:
		if other == caller or not bool(other["alive"]):
			continue
		if String(other.get("ai_state", "patrol")) == "combat" \
				or String(other.get("ai_state", "patrol")) == "rush" \
				or String(other.get("ai_state", "patrol")) == "retreat" \
				or String(other.get("ai_state", "patrol")) == "flank":
			continue
		var d: float = caller["pos"].distance_to(other["pos"])
		if d > call_r:
			continue
		other["alert_ttl"] = maxf(float(other.get("alert_ttl", 0.0)), 2.6)
		other["last_heard"] = target_pos
		other["last_seen"] = target_pos
		other["ai_state"] = "investigate"
		other["search_ttl"] = maxf(float(other.get("search_ttl", 0.0)), 2.0)


static func distress_call(world: Dictionary, enforcer: Dictionary, target_pos: Vector2) -> void:
	_host_push_float(world, enforcer["pos"] + Vector2(0, -22), "!!", Color("c9a0ff"), 1.0)
	_host_set_message(world, "Enforcer distress — compound stirring.", 2.4)
	_host_emit_noise(world, enforcer["pos"], ENFORCER_DISTRESS_RANGE * 0.55, 1.1)
	for other in world["roamers"]:
		if other == enforcer or not bool(other["alive"]):
			continue
		var d: float = enforcer["pos"].distance_to(other["pos"])
		if d > ENFORCER_DISTRESS_RANGE:
			continue
		other["dormant"] = false
		other["alert_ttl"] = maxf(float(other.get("alert_ttl", 0.0)), 3.4)
		other["last_heard"] = target_pos
		other["last_seen"] = target_pos
		other["aggro_range"] = maxf(float(other.get("aggro_range", 200.0)), 280.0)
		var st := String(other.get("ai_state", "patrol"))
		if st == "combat" or st == "rush" or st == "flank" or st == "retreat":
			continue
		other["ai_state"] = "investigate"
		other["search_ttl"] = maxf(float(other.get("search_ttl", 0.0)), 2.8)
