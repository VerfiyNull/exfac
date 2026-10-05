class_name RaidSim
extends RefCounted
## Pure field simulation — visuals read this state; no Godot nodes owned here.

# Explicit preloads — headless / fresh clone has no global class_name cache yet.
const Items := preload("res://scripts/systems/items.gd")
const Skills := preload("res://scripts/systems/skills.gd")
const MetaSim := preload("res://scripts/systems/meta.gd")

const MAP_W := 4800.0
const MAP_H := 3200.0
const VISION_RANGE := 420.0
## How far roamers hear an active extract flare and rush the exit.
const EXTRACT_ALARM_RADIUS := 1200.0
## Damage while holding extract bleeds progress (seconds lost per HP).
const EXTRACT_DAMAGE_PROGRESS_BLEED := 0.045
## Field medkit channel time — interrupted if you take damage.
const MEDKIT_CHANNEL := 1.35
## Sprint — big map traversal without making walk feel sluggish.
const SPRINT_MULT := 1.7
const STAMINA_MAX := 100.0
const STAMINA_DRAIN := 26.0
const STAMINA_REGEN := 16.0
## Brief lockout after emptying the bar so sprint can't stutter-tap.
const SPRINT_EXHAUST := 0.75
## Movement response — accel toward desired speed; stop/reverse snappier than a skate.
const MOVE_ACCEL_RESP := 16.0
const MOVE_STOP_RESP := 22.0
const MOVE_REVERSE_RESP := 14.0
const MOVE_SPRINT_RESP := 12.0
const MOVE_BRACE_RESP := 20.0
## Aim turn — mouse lead feels planted, not rubbery; still tracks fast in a fight.
const AIM_TURN_RESP := 20.0
const AIM_TURN_BRACE_RESP := 14.0
const AIM_TURN_SPRINT_RESP := 12.0
## Stamina collapse — emptying the bar plants a short stumble and a tell.
const STUMBLE_TTL := 0.55
const STUMBLE_SPEED := 0.32
const HEAR_STUMBLE_RANGE := 210.0
const NOISE_TTL_STUMBLE := 0.5
## Soft land — drop into crouch during the plant to cut the tell and recover faster.
const HEAR_STUMBLE_CROUCH_RANGE := 95.0
const STUMBLE_CROUCH_DECAY := 2.2
## Wounded stumble — limp collapse hits harder on the ears when upright.
const WOUNDED_STUMBLE_HEAR_MULT := 1.22
## Heavy stumble — a stuffed pack rattles harder when you plant upright.
const HEAVY_BAG_STUMBLE_HEAR_MULT := 1.18
## Crouch — slow, tight cone, quieter muzzle; can't sprint while down.
const CROUCH_MULT := 0.58
const CROUCH_SPREAD_MULT := 0.62
const CROUCH_SHOT_HEAR_MULT := 0.72
## Aim-brace (RMB) — planted shots; stacks with crouch; sprint cancels.
const BRACE_MULT := 0.68
const BRACE_SPREAD_MULT := 0.48
const BRACE_CROUCH_SPEED := 0.42
## Planted muzzle — bracing cups the report; stacks with crouch hush.
const BRACE_SHOT_HEAR_MULT := 0.82
const BRACE_CROUCH_SHOT_HEAR_MULT := 0.58
## Wounded muzzle — shaking upright shots telegraph farther.
const WOUNDED_SHOT_HEAR_MULT := 1.18
## Heavy muzzle — a stuffed pack rattles upright shots farther.
const HEAVY_BAG_SHOT_HEAR_MULT := 1.14
## Brace settle — hold the plant and the cone tightens further.
const BRACE_SETTLE_TIME := 0.85
const BRACE_SETTLE_SPREAD := 0.7
## Suppression — enemy rounds near you kick the aim cone open.
const SUPPRESS_NEAR := 52.0
const SUPPRESS_BLOOM := 0.038
const SUPPRESS_HIT_BLOOM := 0.055
## Return fire — your near-misses pin roamers the same way.
const ROAMER_SUPPRESS_NEAR := 48.0
const ROAMER_SUPPRESS_GAP := 0.42
const ROAMER_SUPPRESS_HIT_GAP := 0.55
const ROAMER_SUPPRESS_TTL := 0.7
const ROAMER_SUPPRESS_SPREAD := 0.14
## Threat bearing — incoming fire paints a short compass tick.
const THREAT_BEARING_TTL := 2.8
## Field dusk — light falls; vision thins so you push for the lift.
const RAID_DUSK_START := 120.0
const RAID_DUSK_FULL := 240.0
const DUSK_VISION_MIN := 0.55
const DUSK_HEAR_MAX := 1.22
## Dusk heat — late raids make quieter exits shout farther.
const DUSK_QUIET_ALARM_MULT := 1.9
const DUSK_CONTESTED_ALARM_MULT := 1.22
const DUSK_QUIET_PAD_ADD := 0.09
## Crouched extract hold — keep the flare tight so the pad doesn't scream the whole map.
const CROUCH_EXTRACT_ALARM_MULT := 0.62
## Wounded limp — critical HP slows you (pressure to medkit / extract).
const WOUNDED_HP_RATIO := 0.35
const WOUNDED_SPEED_MULT := 0.72
## Tunnel vision — limp HP thins sight; adrenaline briefly punches it back open.
const WOUNDED_VISION_MULT := 0.78
const ADRENALINE_VISION_MULT := 0.92
## Shaking hands — limp HP opens the cone; adrenaline steadies a bit.
const WOUNDED_SPREAD_MULT := 1.28
const ADRENALINE_SPREAD_MULT := 0.9
## Bleed-out — stay under the limp line and HP keeps draining until you patch up.
const BLEED_DPS := 3.2
const BLEED_CUE_INTERVAL := 2.4
const CROUCH_BLEED_MULT := 0.62
## Labored breath — standing wounded telegraphs; crouch keeps the rasp down.
const HEAR_WOUND_BREATH_RANGE := 95.0
const NOISE_TTL_WOUND_BREATH := 0.45
## Adrenaline — first limp spike: a short stamina dump so you can still run.
const ADRENALINE_STAMINA := 38.0
const ADRENALINE_SPEED := 1.12
const ADRENALINE_TTL := 3.6
## Limp lungs — sprinting while critical burns the bar faster.
const WOUNDED_STAMINA_DRAIN_MULT := 1.35
## Limp recovery — critical HP also slows stamina regen.
const WOUNDED_STAMINA_REGEN_MULT := 0.72
## Heavy lungs — a stuffed pack also burns sprint gas.
const HEAVY_BAG_STAMINA_DRAIN_MULT := 1.22
## Heavy recovery — a stuffed pack also slows stamina regen.
const HEAVY_BAG_STAMINA_REGEN_MULT := 0.82
## Heavy sprint — a stuffed pack also telegraphs a run farther.
const HEAVY_BAG_SPRINT_HEAR_MULT := 1.2
## Wounded sprint — limp footfalls telegraph a run farther.
const WOUNDED_SPRINT_HEAR_MULT := 1.16
## Heavy bag — a stuffed pack drags you; risk of greed.
const HEAVY_BAG_RATIO := 0.75
const HEAVY_BAG_SPEED := 0.88
const FULL_BAG_SPEED := 0.76
## Heavy plant — a stuffed pack also slows brace settle.
const HEAVY_BAG_SETTLE_MULT := 0.62
## Shaking plant — limp HP also slows brace settle (adrenaline steadies).
const WOUNDED_SETTLE_MULT := 0.72
const ADRENALINE_SETTLE_MULT := 0.92
## Heavy hands — stuffing the pack also slows mag changes.
const HEAVY_BAG_RELOAD_MULT := 0.82
## Heavy patch — fumbling a kit around a stuffed pack takes longer.
const HEAVY_BAG_HEAL_MULT := 0.85
## Shaking hands — limp HP also slows the medkit channel.
const WOUNDED_HEAL_MULT := 0.78
const WOUNDED_RELOAD_MULT := 0.78
## Roamers hear shots / sprint even without line of sight.
const HEAR_SHOT_RANGE := 560.0
const HEAR_SPRINT_RANGE := 240.0
const NOISE_TTL_SHOT := 1.1
const NOISE_TTL_SPRINT := 0.25
## Ransack — pry a crate / strip a body (not instant; loud; leave range or take a hit to cancel).
const LOOT_CHANNEL_CRATE := 1.75
const LOOT_CHANNEL_CORPSE := 1.15
const LOOT_CHANNEL_DROP_BAG := 1.4
const LOOT_CHANNEL_AMMO := 1.35
const LOOT_CHANNEL_MED := 1.5
const LOOT_CHANNEL_WEAPON := 2.35
const LOOT_CHANNEL_INTEL := 2.1
const HEAR_RANSACK_RANGE := 400.0
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
## Scrap toss — throw junk ahead to pull roamers off you.
const HEAR_DISTRACT_RANGE := 540.0
const NOISE_TTL_DISTRACT := 2.2
const DISTRACT_TOSS_RANGE := 300.0
const DISTRACT_COOLDOWN := 1.15
## Planted toss — brace cups the clang; stacks with crouch for a soft linger.
const BRACE_DISTRACT_HEAR_MULT := 0.82
const BRACE_CROUCH_DISTRACT_HEAR_MULT := 0.55
const CROUCH_DISTRACT_HEAR_MULT := 0.72
const CROUCH_DISTRACT_TTL_MULT := 1.35
const BRACE_DISTRACT_TTL_MULT := 1.15
const BRACE_CROUCH_DISTRACT_TTL_MULT := 1.5
## Wounded toss — shaking upright scrap clangs farther.
const WOUNDED_DISTRACT_HEAR_MULT := 1.2
## Heavy toss — a stuffed pack rattles upright scrap farther.
const HEAVY_BAG_DISTRACT_HEAR_MULT := 1.15
## Extract reinforcements — flare summons a late wave from the perimeter.
const REINFORCE_DELAY_HOT := 0.55
const REINFORCE_DELAY_CONTESTED := 1.15
const REINFORCE_COUNT_HOT := 4
const REINFORCE_COUNT_CONTESTED := 2
const REINFORCE_SPAWN_RING := 380.0
## Alert call — a roamer who spots you shouts; allies investigate the call.
const ALERT_CALL_RANGE := 420.0
const ALERT_CALL_COOLDOWN := 2.8
## Enforcer distress — a hurt elite yells farther and wakes the compound.
const ENFORCER_DISTRESS_HP := 0.5
const ENFORCER_DISTRESS_RANGE := 780.0
## Blood trail — wounded runners drip scent roamers can track.
const BLOOD_DRIP_INTERVAL := 0.45
const BLOOD_TRAIL_TTL := 4.5
const BLOOD_SCENT_RANGE := 160.0
## Doors — closed slabs block LOS/path; E pries them open (and shut).
const DOOR_INTERACT_RANGE := 28.0
const HEAR_DOOR_PRY_RANGE := 180.0
const NOISE_TTL_DOOR_PRY := 0.55
## Crouched pry — soft latch work so you can slip rooms without a stadium clang.
const HEAR_DOOR_CROUCH_RANGE := 85.0
const NOISE_TTL_DOOR_CROUCH := 0.4
## Wounded pry — shaking hands clang the latch harder when upright.
const WOUNDED_DOOR_PRY_HEAR_MULT := 1.25
## Heavy pry — a stuffed pack rattles the latch when you stand-pry.
const HEAVY_BAG_DOOR_PRY_HEAR_MULT := 1.18
## Footsteps — walk is audible; crouch stays quiet; sprint already has its own noise.
const HEAR_WALK_RANGE := 110.0
const NOISE_TTL_WALK := 0.35
## Heavy pack footfalls — a stuffed bag clanks louder when you walk it.
const HEAVY_BAG_WALK_HEAR_MULT := 1.35
const FULL_BAG_WALK_HEAR_MULT := 1.55
## Wounded walk — limp footfalls telegraph when you're upright.
const WOUNDED_WALK_HEAR_MULT := 1.28
## Planted reload — bracing (optionally crouched) speeds the mag change.
const BRACE_RELOAD_MULT := 0.78
const BRACE_CROUCH_RELOAD_MULT := 0.68
## Crouched ransack — faster pry, quieter clatter.
const CROUCH_LOOT_RATE := 1.28
const CROUCH_RANSACK_HEAR_MULT := 0.62
## Heavy ransack — a stuffed pack rattles louder while you pry.
const HEAVY_BAG_RANSACK_HEAR_MULT := 1.22
## Heavy pry — greed also slows how fast you crack the lid.
const HEAVY_BAG_LOOT_RATE := 0.82
## Shaking hands — limp HP slows crate pry the same way.
const WOUNDED_LOOT_RATE := 0.82
## Planted medkit — brace/crouch lets you patch faster while vulnerable.
const BRACE_HEAL_MULT := 0.82
const CROUCH_HEAL_MULT := 0.88
const BRACE_CROUCH_HEAL_MULT := 0.72
## Dry-fire click — empty mag still makes a small tell.
const HEAR_DRYFIRE_RANGE := 95.0
const NOISE_TTL_DRYFIRE := 0.45
## Crouched dry-fire — cup the click so it doesn't paint the hallway.
const CROUCH_DRYFIRE_HEAR_MULT := 0.55
## Braced dry-fire — planted click is softer than a hip snap.
const BRACE_DRYFIRE_HEAR_MULT := 0.7
const BRACE_CROUCH_DRYFIRE_HEAR_MULT := 0.42
## Wounded dry-fire — shaking hands slap the receiver louder when upright.
const WOUNDED_DRYFIRE_HEAR_MULT := 1.3
## Heavy dry-fire — a stuffed pack rattles the empty slap when upright.
const HEAVY_BAG_DRYFIRE_HEAR_MULT := 1.18
## Sprint dump — canceling a reload into a run drops the mag with a clatter.
const HEAR_RELOAD_DUMP_RANGE := 140.0
const NOISE_TTL_RELOAD_DUMP := 0.4
## Sprint dump medkit — same abort into a run; soft pack drop.
const HEAR_MEDKIT_DUMP_RANGE := 120.0
const NOISE_TTL_MEDKIT_DUMP := 0.4
## Sprint dump ransack — kick off a crate mid-pry; louder clatter.
const HEAR_LOOT_DUMP_RANGE := 160.0
const NOISE_TTL_LOOT_DUMP := 0.45
## Empty-mag shove — last-ditch contact weapon when the chamber's dry.
const MELEE_RANGE := 34.0
const MELEE_DAMAGE := 22.0
## Contact hit — no knockback; briefly hobble their move speed instead.
const MELEE_SLOW_TTL := 0.5
const MELEE_SLOW_MULT := 0.4
const MELEE_COOLDOWN := 0.9
const HEAR_MELEE_RANGE := 200.0
const NOISE_TTL_MELEE := 0.55
## Unarmed punch — no gun visible; LMB is fists with shorter reach and quieter tell.
const PUNCH_RANGE := 38.0
const PUNCH_DAMAGE := 16.0
const PUNCH_COOLDOWN := 0.52
const PUNCH_STAMINA_COST := 14.0
const MELEE_STAMINA_COST := 18.0
const PUNCH_MISS_STAMINA_COST := 8.0
const HEAR_PUNCH_RANGE := 110.0
const NOISE_TTL_PUNCH := 0.35
const PUNCH_SWING_TTL := 0.18
## Wounded shove — limp upright buttstock rings farther.
const WOUNDED_MELEE_HEAR_MULT := 1.2
## Heavy shove — a stuffed pack rattles an upright buttstock farther.
const HEAVY_BAG_MELEE_HEAR_MULT := 1.15
## Silent rear drop — crouched empty-mag shove / punch into a dormant's back stays quiet.
const MELEE_SILENT_DAMAGE := 58.0
const PUNCH_SILENT_DAMAGE := 48.0
const HEAR_MELEE_SILENT_RANGE := 55.0
const NOISE_TTL_MELEE_SILENT := 0.35
const MELEE_BEHIND_DOT := -0.35
## Door bash — sprinting into a closed slab kicks it open loudly.
const HEAR_DOOR_BASH_RANGE := 320.0
const NOISE_TTL_DOOR_BASH := 0.7
const DOOR_BASH_STAMINA := 28.0
## Wounded bash — limp kick rings farther across the compound.
const WOUNDED_DOOR_BASH_HEAR_MULT := 1.18
## Heavy bash — a stuffed pack rattles harder when you kick a slab.
const HEAVY_BAG_DOOR_BASH_HEAR_MULT := 1.15
## Wounded bash cost — limp kicks also burn more composure.
const WOUNDED_DOOR_BASH_STAMINA_MULT := 1.25
## Heavy bash cost — a stuffed pack also burns more composure on the kick.
const HEAVY_BAG_DOOR_BASH_STAMINA_MULT := 1.18
## Extract abandon — peeling off a lit pad still rings; don't cheese hold/leave.
const HEAR_EXTRACT_ABANDON_RANGE := 520.0
const NOISE_TTL_EXTRACT_ABANDON := 1.1
const EXTRACT_ABANDON_MIN_PROGRESS := 0.12
const EXTRACT_ABANDON_STAMINA := 18.0
const EXTRACT_ABANDON_STUMBLE := 0.35
## Wounded abandon — limp peel rings the break flare farther.
const WOUNDED_EXTRACT_ABANDON_HEAR_MULT := 1.18
## Heavy abandon — a stuffed pack rattles the break flare farther.
const HEAVY_BAG_EXTRACT_ABANDON_HEAR_MULT := 1.14
## Intel pulse — burn a Signal Chip for a short awareness sweep.
const INTEL_PULSE_TTL := 4.0
const INTEL_PULSE_COOLDOWN := 1.0
## Mark flare — loud lure farther than scrap toss; wakes dormants on the bang.
const HEAR_FLARE_RANGE := 720.0
const NOISE_TTL_FLARE := 3.4
const FLARE_TOSS_RANGE := 380.0
const FLARE_COOLDOWN := 1.8


static func create_raid_world(loadout: Dictionary, packed_medkits: int = 0, skills: Dictionary = {}) -> Dictionary:
	var skill_state: Dictionary = skills if not skills.is_empty() else Skills.create_state()
	var world := {
		"width": MAP_W,
		"height": MAP_H,
		"player": {},
		"roamers": [],
		"crates": [],
		"extracts": [],
		"bullets": [],
		"obstacles": [],
		"inventory": [],
		"inventory_cap": Items.loadout_capacity(loadout) + Skills.bag_bonus(skill_state),
		"loadout": loadout.duplicate(true),
		"skills": skill_state.duplicate(true),
		"skill_deeds": 0,
		"sprint_meters": 0.0,
		"time_alive": 0.0,
		"message": "",
		"message_ttl": 0.0,
		"floats": [],
		"shake": 0.0,
		"interact_hint": null,
		"next_id": 1,
		"over": false,
		"outcome": null,
		"extract_alarm": false,
		"extract_contest_count": 0,
		"active_extract_id": -1,
		"extract_progress_01": 0.0,
		"extract_damage_bleed": 0.0,
		"extract_reinforce_ttl": 0.0,
		"extract_reinforce_pending": 0,
		"extract_reinforce_done": false,
		"noise_pos": Vector2.ZERO,
		"noise_radius": 0.0,
		"noise_ttl": 0.0,
		"nearest_extract_id": -1,
		"nearest_extract_dir": Vector2.RIGHT,
		"nearest_extract_dist": 0.0,
		"drop_bag_id": -1,
		"dropped_loot": [],
		"blood_trail": [],
		"blood_drip_cd": 0.0,
		"intel_pulse_ttl": 0.0,
		"intel_pulse_cd": 0.0,
		"threat_dir": Vector2.RIGHT,
		"threat_ttl": 0.0,
		"dusk_01": 0.0,
		"dusk_warned": false,
	}

	world["obstacles"] = _build_obstacles()

	world["player"] = _make_actor(world, "player", Vector2(240, MAP_H - 240), {
		"hp": 100.0,
		"max_hp": 100.0,
		"speed": 175.0,
		"damage": Items.loadout_damage(loadout),
		"mitigation": Items.loadout_mitigation(loadout),
		"vision_range": VISION_RANGE,
	})
	world["player"]["heal_channel"] = 0.0
	world["player"]["heal_amount"] = 0.0
	world["player"]["loot_channel"] = 0.0
	world["player"]["loot_channel_max"] = 0.0
	world["player"]["loot_target_id"] = -1
	world["player"]["distract_cooldown"] = 0.0
	world["player"]["flare_cooldown"] = 0.0
	var armed := Items.loadout_has_weapon(loadout)
	world["player"]["armed"] = armed
	world["player"]["punch_swing"] = 0.0
	var mag := Items.weapon_mag_size(loadout)
	world["player"]["mag"] = mag
	world["player"]["mag_size"] = mag
	world["player"]["reserve"] = Items.weapon_start_reserve(loadout)
	world["player"]["reload_channel"] = 0.0
	world["player"]["reload_time"] = Items.weapon_reload_time(loadout)
	var stam_max := Skills.stamina_max(skill_state)
	world["player"]["stamina"] = stam_max
	world["player"]["stamina_max"] = stam_max
	world["player"]["stamina_regen_mult"] = Skills.stamina_regen_mult(skill_state)
	world["player"]["sprinting"] = false
	world["player"]["sprint_exhaust"] = 0.0
	world["player"]["stumble_ttl"] = 0.0
	world["player"]["crouching"] = false
	world["player"]["bracing"] = false
	world["player"]["brace_hold"] = 0.0
	world["player"]["vel"] = Vector2.ZERO
	world["player"]["fire_rate"] = Items.loadout_fire_rate(loadout)
	world["player"]["recoil_bloom"] = 0.0
	world["player"]["suppress_ttl"] = 0.0
	world["player"]["wounded"] = false
	world["player"]["bleeding"] = false
	world["player"]["bleed_cue_cd"] = 0.0
	world["player"]["adrenaline_ttl"] = 0.0
	world["player"]["adrenaline_fired"] = false
	world["player"]["heavy_bag"] = false
	world["player"]["recoil_mult"] = Skills.recoil_mult(skill_state)
	world["player"]["loot_mult"] = Skills.loot_channel_mult(skill_state)
	world["player"]["medkit_mult"] = Skills.medkit_channel_mult(skill_state)
	var armor_max := Items.loadout_armor_durability(loadout)
	world["player"]["armor_max"] = armor_max
	world["player"]["armor_hp"] = armor_max
	world["player"]["base_mitigation"] = Items.loadout_mitigation(loadout)
	_refresh_armor_mitigation(world["player"])

	_refresh_bag_cap(world)
	# Pack only what fits; excess is refunded to the locker by the raid scene.
	var want_pack := maxi(0, packed_medkits)
	var pack := mini(want_pack, int(world["inventory_cap"]))
	world["pack_refund_medkits"] = want_pack - pack
	if pack > 0:
		Items.add_to_stash(world["inventory"], Items.stack_of("medkit", pack))
		_refresh_bag_cap(world)

	# Spread roamers across the big map.
	for _i in 22:
		var sp := _rand_clear_pos(world["obstacles"], 20.0, 80.0)
		world["roamers"].append(_make_actor(world, "roamer", sp, {
			"hp": randf_range(45.0, 70.0),
			"max_hp": 70.0,
			"speed": randf_range(95.0, 135.0),
			"damage": randf_range(8.0, 14.0),
			"aggro_range": randf_range(200.0, 320.0),
			"mitigation": 0.05,
		}))
		world["roamers"].back()["alert_ttl"] = 0.0
		world["roamers"].back()["last_heard"] = sp
		world["roamers"].back()["last_seen"] = sp
		world["roamers"].back()["ai_state"] = "patrol"
		world["roamers"].back()["patrol_anchor"] = sp
		world["roamers"].back()["patrol_phase"] = randf() * TAU
		world["roamers"].back()["search_ttl"] = 0.0
		world["roamers"].back()["elite"] = false
		world["roamers"].back()["hear_mult"] = 1.0
		world["roamers"].back()["role"] = "roamer"
		world["roamers"].back()["call_cooldown"] = 0.0
		world["roamers"].back()["suppress_ttl"] = 0.0
		world["roamers"].back()["forage_ttl"] = 0.0
		world["roamers"].back()["forage_target_id"] = -1
		# Some start dormant — deaf to soft walks until a louder cue wakes them.
		var dormant := randf() < 0.28
		world["roamers"].back()["dormant"] = dormant
		if dormant:
			world["roamers"].back()["ai_state"] = "dormant"
			world["roamers"].back()["aggro_range"] = float(world["roamers"].back()["aggro_range"]) * 0.45

	# Mixed container types — common crates + scarce specialty caches.
	var spawn_plan: Array = []
	for _i in 12:
		spawn_plan.append("crate")
	for _i in 5:
		spawn_plan.append("ammo_crate")
	for _i in 4:
		spawn_plan.append("med_cache")
	for _i in 4:
		spawn_plan.append("weapon_case")
	for _i in 3:
		spawn_plan.append("intel_safe")
	spawn_plan.shuffle()
	for kind in spawn_plan:
		var sp := _rand_clear_pos(world["obstacles"], 18.0, 40.0)
		world["crates"].append({
			"id": _alloc_id(world),
			"pos": sp,
			"radius": 16.0,
			"opened": false,
			"kind": String(kind),
			"contents": Items.roll_container_loot(String(kind)),
		})

	world["extracts"] = [
		# Hot NE — short hold, huge flare, roamers pile in hard.
		{"id": _alloc_id(world), "pos": Vector2(MAP_W - 160, 140), "radius": 56.0, "hold_seconds": 2.1, "progress": 0.0, "active": true, "pressure": "hot", "alarm_radius": 1650.0, "contest_pad": 0.18, "bleed_mult": 1.35},
		# Quiet NW — long sit, small flare — safer if you can stay still.
		{"id": _alloc_id(world), "pos": Vector2(140, 140), "radius": 50.0, "hold_seconds": 4.2, "progress": 0.0, "active": true, "pressure": "quiet", "alarm_radius": 620.0, "contest_pad": 0.06, "bleed_mult": 0.7},
		# Contested south — balanced mid pressure (classic flare).
		{"id": _alloc_id(world), "pos": Vector2(MAP_W * 0.5, MAP_H - 140), "radius": 54.0, "hold_seconds": 2.9, "progress": 0.0, "active": true, "pressure": "contested", "alarm_radius": EXTRACT_ALARM_RADIUS, "contest_pad": 0.12, "bleed_mult": 1.0},
	]
	# One Warden per extract — tougher elites that hold the exits.
	for z in world["extracts"]:
		var zp: Vector2 = z["pos"]
		var offset := Vector2(randf_range(-70, 70), randf_range(-70, 70))
		var sp := zp + offset
		sp.x = clampf(sp.x, 60.0, MAP_W - 60.0)
		sp.y = clampf(sp.y, 60.0, MAP_H - 60.0)
		world["roamers"].append(_make_actor(world, "roamer", sp, {
			"hp": randf_range(110.0, 140.0),
			"max_hp": 140.0,
			"speed": randf_range(105.0, 125.0),
			"damage": randf_range(16.0, 22.0),
			"aggro_range": randf_range(340.0, 420.0),
			"mitigation": 0.22,
			"radius": 17.0,
			"vision_range": VISION_RANGE * 1.15,
		}))
		var enforcer: Dictionary = world["roamers"].back()
		enforcer["alert_ttl"] = 0.0
		enforcer["last_heard"] = sp
		enforcer["last_seen"] = sp
		enforcer["ai_state"] = "patrol"
		enforcer["patrol_anchor"] = zp
		enforcer["patrol_phase"] = randf() * TAU
		enforcer["search_ttl"] = 0.0
		enforcer["elite"] = true
		enforcer["hear_mult"] = 1.35
		enforcer["role"] = "enforcer"
		enforcer["fire_gap_mult"] = 0.72
		enforcer["call_cooldown"] = 0.0
		enforcer["suppress_ttl"] = 0.0
		enforcer["forage_ttl"] = 0.0
		enforcer["forage_target_id"] = -1
		enforcer["distress_fired"] = false
		enforcer["telegraph_shown"] = false
		enforcer["telegraph_ttl"] = 0.0
		enforcer["dormant"] = false
	_update_extract_compass(world)
	return world


static func has_line_of_sight(from: Vector2, to: Vector2, obstacles: Array) -> bool:
	var delta := to - from
	var dist := delta.length()
	if dist < 1.0:
		return true
	var steps := int(ceil(dist / 12.0))
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var p := from.lerp(to, t)
		for o in obstacles:
			if not _obstacle_blocks(o):
				continue
			if p.x >= float(o["x"]) and p.x <= float(o["x"]) + float(o["w"]) \
					and p.y >= float(o["y"]) and p.y <= float(o["y"]) + float(o["h"]):
				return false
	return true


static func can_see_actor(viewer: Dictionary, target_pos: Vector2, obstacles: Array) -> bool:
	var from: Vector2 = viewer["pos"]
	var range_v := float(viewer.get("vision_range", VISION_RANGE))
	if from.distance_to(target_pos) > range_v:
		return false
	return has_line_of_sight(from, target_pos, obstacles)


static func step_raid(world: Dictionary, dt: float, move: Vector2, aim_world: Vector2, shoot: bool, interact: bool, fire_rate: float, use_medkit: bool = false, reload: bool = false, sprint: bool = false, equip: bool = false, distract: bool = false, crouch: bool = false, brace: bool = false, intel_pulse: bool = false, mark_flare: bool = false, shoot_click: bool = false) -> void:
	if bool(world["over"]):
		_update_floats(world, dt)
		world["shake"] = maxf(0.0, float(world["shake"]) - dt * 28.0)
		return

	world["time_alive"] = float(world["time_alive"]) + dt
	if float(world["message_ttl"]) > 0.0:
		world["message_ttl"] = float(world["message_ttl"]) - dt
	world["shake"] = maxf(0.0, float(world["shake"]) - dt * 28.0)
	world["intel_pulse_ttl"] = maxf(0.0, float(world.get("intel_pulse_ttl", 0.0)) - dt)
	world["intel_pulse_cd"] = maxf(0.0, float(world.get("intel_pulse_cd", 0.0)) - dt)
	world["threat_ttl"] = maxf(0.0, float(world.get("threat_ttl", 0.0)) - dt)
	_tick_raid_dusk(world)

	var player: Dictionary = world["player"]
	player["hit_flash"] = maxf(0.0, float(player["hit_flash"]) - dt)
	player["distract_cooldown"] = maxf(0.0, float(player.get("distract_cooldown", 0.0)) - dt)
	player["flare_cooldown"] = maxf(0.0, float(player.get("flare_cooldown", 0.0)) - dt)
	if not bool(player["alive"]):
		return

	# Bleed ticks in every channel — patch above the limp line or bleed out.
	_tick_bleed(world, dt)
	if not bool(player["alive"]):
		_update_floats(world, dt)
		return
	player["adrenaline_ttl"] = maxf(0.0, float(player.get("adrenaline_ttl", 0.0)) - dt)

	var busy := float(player.get("heal_channel", 0.0)) > 0.0 \
		or float(player.get("reload_channel", 0.0)) > 0.0 \
		or float(player.get("loot_channel", 0.0)) > 0.0

	# Stance early so door pry this frame matches the held crouch.
	player["crouching"] = crouch and not sprint

	# Ransack / door — pry crates or toggle a slab.
	if interact and not busy:
		_try_interact(world)
		busy = float(player.get("loot_channel", 0.0)) > 0.0

	if float(player.get("loot_channel", 0.0)) > 0.0:
		# Sprint dump — kick off the crate into a run (contents stay sealed).
		var loot_dump := move.normalized() if move.length_squared() > 1e-6 else Vector2.ZERO
		if sprint and loot_dump.length_squared() > 1e-6:
			player["loot_channel"] = 0.0
			player["loot_channel_max"] = 0.0
			player["loot_target_id"] = -1
			player["bracing"] = false
			player["brace_hold"] = 0.0
			_emit_noise(world, player["pos"], HEAR_LOOT_DUMP_RANGE, NOISE_TTL_LOOT_DUMP)
			_push_float(world, player["pos"] + Vector2(0, -18), "DUMP", Color("e6b35a"), 0.65)
			_set_message(world, "Ransack dumped — moving.", 1.0)
			# Fall through into free movement / sprint this frame.
		else:
			_tick_loot_channel(world, dt, move, aim_world, crouch and not sprint)
			return

	# Medkit channel — slow crawl, no shooting, broken by damage.
	var channeling := float(player.get("heal_channel", 0.0)) > 0.0
	if use_medkit and not channeling and float(player.get("reload_channel", 0.0)) <= 0.0:
		_begin_medkit(world)
		channeling = float(player.get("heal_channel", 0.0)) > 0.0

	if channeling:
		# Sprint dump — abort the patch into a run (kit stays in bag).
		var heal_dump := move.normalized() if move.length_squared() > 1e-6 else Vector2.ZERO
		if sprint and heal_dump.length_squared() > 1e-6:
			player["heal_channel"] = 0.0
			player["heal_amount"] = 0.0
			player["bracing"] = false
			player["brace_hold"] = 0.0
			_emit_noise(world, player["pos"], HEAR_MEDKIT_DUMP_RANGE, NOISE_TTL_MEDKIT_DUMP)
			_push_float(world, player["pos"] + Vector2(0, -18), "DUMP", Color("3ecf8e"), 0.65)
			_set_message(world, "Medkit stowed — moving.", 1.0)
			# Fall through into free movement / sprint this frame.
		else:
			var want_crouch_h := crouch and not sprint
			var want_brace_h := brace and not sprint
			player["crouching"] = want_crouch_h
			player["bracing"] = want_brace_h
			var heal_rate := 1.0
			if want_brace_h and want_crouch_h:
				heal_rate = 1.0 / BRACE_CROUCH_HEAL_MULT
			elif want_brace_h:
				heal_rate = 1.0 / BRACE_HEAL_MULT
			elif want_crouch_h:
				heal_rate = 1.0 / CROUCH_HEAL_MULT
			# Shaking hands — critical wounds make kits stick.
			var hp_ratio_h := float(player["hp"]) / maxf(1.0, float(player["max_hp"]))
			if hp_ratio_h <= WOUNDED_HP_RATIO:
				heal_rate *= WOUNDED_HEAL_MULT
			# Greedy packs — digging a kit out of a stuffed bag takes longer.
			var used_h := float(Items.inventory_used(world["inventory"]))
			var cap_h := maxf(1.0, float(world["inventory_cap"]))
			if used_h / cap_h >= HEAVY_BAG_RATIO:
				heal_rate *= HEAVY_BAG_HEAL_MULT
			player["heal_channel"] = float(player["heal_channel"]) - dt * heal_rate
			_tick_stamina(player, dt, false, false)
			_tick_recoil(player, world["loadout"], dt)
			var move_dir_ch := move.normalized() if move.length_squared() > 1e-6 else Vector2.ZERO
			var heal_move := 0.35
			if want_brace_h and want_crouch_h:
				heal_move = 0.2
			elif want_brace_h:
				heal_move = 0.26
			elif want_crouch_h:
				heal_move = 0.28
			var desired_ch: Vector2 = move_dir_ch * float(player["speed"]) * heal_move
			player["vel"] = _smooth_vec(player.get("vel", Vector2.ZERO), desired_ch, MOVE_BRACE_RESP, dt)
			player["pos"] = player["pos"] + player["vel"] * dt
			_collide_actor_obstacles(player, world["obstacles"])
			_clamp_to_map(player, float(world["width"]), float(world["height"]))
			var aim_ch: Vector2 = aim_world - (player["pos"] as Vector2)
			var want_ch: Vector2 = aim_ch.normalized() if aim_ch.length_squared() > 1e-6 else (player.get("aim", Vector2.RIGHT) as Vector2)
			player["aim"] = _smooth_aim(player.get("aim", Vector2.RIGHT), want_ch, AIM_TURN_RESP, dt)
			player["facing"] = (player["aim"] as Vector2).angle()
			if float(player["heal_channel"]) <= 0.0:
				_finish_medkit(world)
			_tick_blood_trail(world, dt)
			_tick_noise(world, dt)
			_update_extract_compass(world)
			_update_extracts(world, dt)
			_update_roamers(world, dt)
			_update_bullets(world, dt)
			_update_floats(world, dt)
			_refresh_interact_hint(world)
			_refresh_bag_cap(world)
			return

	# Reload channel — manual only (R). Empty-mag fire never auto-reloads.
	var reloading := float(player.get("reload_channel", 0.0)) > 0.0
	if reload and not reloading:
		_begin_reload(world)
		reloading = float(player.get("reload_channel", 0.0)) > 0.0

	if reloading:
		# Sprint dump — abort the mag change into a run (clatter, then free move).
		var dump_move := move.normalized() if move.length_squared() > 1e-6 else Vector2.ZERO
		if sprint and dump_move.length_squared() > 1e-6:
			player["reload_channel"] = 0.0
			player["bracing"] = false
			player["brace_hold"] = 0.0
			_emit_noise(world, player["pos"], HEAR_RELOAD_DUMP_RANGE, NOISE_TTL_RELOAD_DUMP)
			_push_float(world, player["pos"] + Vector2(0, -18), "DUMP", Color("e6b35a"), 0.65)
			_set_message(world, "Mag dumped — moving.", 1.0)
			# Fall through into free movement / sprint this frame.
		else:
			# Planted reload — brace (and crouch) burn the channel faster.
			var want_crouch_r := crouch and not sprint
			var want_brace_r := brace and not sprint
			player["crouching"] = want_crouch_r
			player["bracing"] = want_brace_r
			var reload_rate := 1.0
			if want_brace_r and want_crouch_r:
				reload_rate = 1.0 / BRACE_CROUCH_RELOAD_MULT
			elif want_brace_r:
				reload_rate = 1.0 / BRACE_RELOAD_MULT
			# Shaking hands — critical wounds make mags stick.
			var hp_ratio_r := float(player["hp"]) / maxf(1.0, float(player["max_hp"]))
			if hp_ratio_r <= WOUNDED_HP_RATIO:
				reload_rate *= WOUNDED_RELOAD_MULT
			# Greedy packs — fumbling around a stuffed bag slows the mag change.
			var used_r := float(Items.inventory_used(world["inventory"]))
			var cap_r := maxf(1.0, float(world["inventory_cap"]))
			if used_r / cap_r >= HEAVY_BAG_RATIO:
				reload_rate *= HEAVY_BAG_RELOAD_MULT
			player["reload_channel"] = float(player["reload_channel"]) - dt * reload_rate
			_tick_stamina(player, dt, false, false)
			_tick_recoil(player, world["loadout"], dt)
			var move_dir_r := move.normalized() if move.length_squared() > 1e-6 else Vector2.ZERO
			var reload_move := 0.55
			if want_brace_r and want_crouch_r:
				reload_move = 0.32
			elif want_brace_r:
				reload_move = 0.4
			elif want_crouch_r:
				reload_move = 0.42
			var desired_r: Vector2 = move_dir_r * float(player["speed"]) * reload_move
			player["vel"] = _smooth_vec(player.get("vel", Vector2.ZERO), desired_r, MOVE_BRACE_RESP, dt)
			player["pos"] = player["pos"] + player["vel"] * dt
			_collide_actor_obstacles(player, world["obstacles"])
			_clamp_to_map(player, float(world["width"]), float(world["height"]))
			var aim_r: Vector2 = aim_world - (player["pos"] as Vector2)
			var want_r: Vector2 = aim_r.normalized() if aim_r.length_squared() > 1e-6 else (player.get("aim", Vector2.RIGHT) as Vector2)
			player["aim"] = _smooth_aim(player.get("aim", Vector2.RIGHT), want_r, AIM_TURN_RESP, dt)
			player["facing"] = (player["aim"] as Vector2).angle()
			if float(player["reload_channel"]) <= 0.0:
				_finish_reload(world)
			_tick_blood_trail(world, dt)
			_tick_noise(world, dt)
			_update_extract_compass(world)
			_update_extracts(world, dt)
			_update_roamers(world, dt)
			_update_bullets(world, dt)
			_update_floats(world, dt)
			_refresh_interact_hint(world)
			_refresh_bag_cap(world)
			return

	player["fire_cooldown"] = maxf(0.0, float(player["fire_cooldown"]) - dt)
	player["suppress_ttl"] = maxf(0.0, float(player.get("suppress_ttl", 0.0)) - dt)
	player["punch_swing"] = maxf(0.0, float(player.get("punch_swing", 0.0)) - dt)
	player["armed"] = Items.loadout_has_weapon(world["loadout"])
	var move_dir := move.normalized() if move.length_squared() > 1e-6 else Vector2.ZERO
	var can_sprint := move_dir.length_squared() > 1e-6
	# Sprint beats crouch/brace — holding both stands you up into a run.
	# Stance before recoil so aim_spread / shot cone match this frame.
	var want_crouch := crouch and not sprint
	var want_brace := brace and not sprint
	player["crouching"] = want_crouch
	player["bracing"] = want_brace
	# Bag weight before settle — greed slows the plant as well as your feet.
	var used_pre := float(Items.inventory_used(world["inventory"]))
	var cap_pre := maxf(1.0, float(world["inventory_cap"]))
	var bag_ratio_pre := used_pre / cap_pre
	var heavy_pre := bag_ratio_pre >= HEAVY_BAG_RATIO
	player["heavy_bag"] = heavy_pre
	if want_brace:
		var settle_rate := 1.0
		if heavy_pre:
			settle_rate *= HEAVY_BAG_SETTLE_MULT
		# Limp hands — critical HP slows the plant; adrenaline steadies a bit.
		var hp_ratio_b := float(player.get("hp", 1.0)) / maxf(1.0, float(player.get("max_hp", 1.0)))
		if hp_ratio_b <= WOUNDED_HP_RATIO:
			if float(player.get("adrenaline_ttl", 0.0)) > 0.0:
				settle_rate *= ADRENALINE_SETTLE_MULT
			else:
				settle_rate *= WOUNDED_SETTLE_MULT
		player["brace_hold"] = float(player.get("brace_hold", 0.0)) + dt * settle_rate
	else:
		player["brace_hold"] = 0.0
	_tick_stamina(player, dt, sprint and can_sprint and not want_crouch, can_sprint)
	_tick_recoil(player, world["loadout"], dt)
	var speed_mult := 1.0
	if bool(player["sprinting"]):
		speed_mult = SPRINT_MULT
	elif want_crouch and want_brace:
		speed_mult = BRACE_CROUCH_SPEED
	elif want_crouch:
		speed_mult = CROUCH_MULT
	elif want_brace:
		speed_mult = BRACE_MULT
	# Critical wounds limp even while sprinting / bracing — medkit or die trying.
	if bool(player.get("wounded", false)):
		speed_mult *= WOUNDED_SPEED_MULT
	if float(player.get("adrenaline_ttl", 0.0)) > 0.0:
		speed_mult *= ADRENALINE_SPEED
	if float(player.get("stumble_ttl", 0.0)) > 0.0:
		speed_mult *= STUMBLE_SPEED
	# Greedy packs cost pace — leave loot or limp to extract.
	var bag_ratio := bag_ratio_pre
	var heavy := heavy_pre
	if bag_ratio >= 1.0:
		speed_mult *= FULL_BAG_SPEED
	elif heavy:
		speed_mult *= HEAVY_BAG_SPEED
	var desired_vel: Vector2 = move_dir * float(player["speed"]) * speed_mult
	var move_resp := MOVE_ACCEL_RESP
	var cur_vel: Vector2 = player.get("vel", Vector2.ZERO)
	if desired_vel.length_squared() < 1e-4:
		move_resp = MOVE_STOP_RESP
	elif bool(player["sprinting"]):
		move_resp = MOVE_SPRINT_RESP
	elif want_brace:
		move_resp = MOVE_BRACE_RESP
	elif cur_vel.length_squared() > 1e-4 and desired_vel.dot(cur_vel) < 0.0:
		move_resp = MOVE_REVERSE_RESP
	player["vel"] = _smooth_vec(cur_vel, desired_vel, move_resp, dt)
	player["pos"] = player["pos"] + player["vel"] * dt
	if bool(player["sprinting"]) and move_dir.length_squared() > 1e-6:
		_try_sprint_door_bash(world, player, move_dir)
	_collide_actor_obstacles(player, world["obstacles"])
	_clamp_to_map(player, float(world["width"]), float(world["height"]))
	if bool(player["sprinting"]):
		world["sprint_meters"] = float(world.get("sprint_meters", 0.0)) + float(player["speed"]) * speed_mult * dt
		while float(world["sprint_meters"]) >= 110.0:
			world["sprint_meters"] = float(world["sprint_meters"]) - 110.0
			world["skill_deeds"] = int(world.get("skill_deeds", 0)) + 1

	_tick_blood_trail(world, dt)

	var want_aim: Vector2 = aim_world - (player["pos"] as Vector2)
	if want_aim.length_squared() > 1e-6:
		want_aim = want_aim.normalized()
	else:
		var prev_aim: Vector2 = player.get("aim", Vector2.RIGHT)
		want_aim = prev_aim if prev_aim.length_squared() > 1e-6 else Vector2.RIGHT
	var aim_resp := AIM_TURN_RESP
	if bool(player["sprinting"]):
		aim_resp = AIM_TURN_SPRINT_RESP
	elif want_brace:
		aim_resp = AIM_TURN_BRACE_RESP
	player["aim"] = _smooth_aim(player.get("aim", Vector2.RIGHT), want_aim, aim_resp, dt)
	player["facing"] = (player["aim"] as Vector2).angle()

	var effective_fire_rate := float(player.get("fire_rate", fire_rate))
	# Source of truth is loadout — never trust a stale armed flag for the gun path.
	var armed := Items.loadout_has_weapon(world["loadout"])
	player["armed"] = armed
	if not armed:
		# Fists-only — keep chamber empty so no accidental gun branch can fire.
		player["mag"] = 0
		player["mag_size"] = 0
	if float(player["fire_cooldown"]) <= 0.0 and (player["aim"] as Vector2).length_squared() > 1e-6:
		if not armed:
			# Unarmed: click-edge only — holding LMB must not auto-swing.
			if shoot_click:
				if not _try_melee(world, true):
					_swing_punch_miss(world)
		elif int(player.get("mag", 0)) <= 0:
			# Armed but dry — click-edge only (no hold spam on buttstock / dry-fire).
			if shoot_click:
				if _try_melee(world, false):
					pass
				else:
					if int(player.get("reserve", 0)) <= 0:
						_set_message(world, "Out of ammo — ransack Ammo Boxes.", 1.2)
					else:
						_set_message(world, "Empty mag — press R to reload.", 1.0)
					player["fire_cooldown"] = 0.2
					# Click still travels — dry-fire isn't free intel; crouch/brace cup it.
					var dry_r := HEAR_DRYFIRE_RANGE
					var dry_ttl := NOISE_TTL_DRYFIRE
					if not bool(player.get("sprinting", false)):
						var braced := bool(player.get("bracing", false))
						var crouched := bool(player.get("crouching", false))
						if braced and crouched:
							dry_r *= BRACE_CROUCH_DRYFIRE_HEAR_MULT
							dry_ttl *= 0.75
						elif braced:
							dry_r *= BRACE_DRYFIRE_HEAR_MULT
							dry_ttl *= 0.85
						elif crouched:
							dry_r *= CROUCH_DRYFIRE_HEAR_MULT
							dry_ttl *= 0.85
						else:
							# Upright limp slap — shaking hands telegraph the empty click.
							var hp_ratio_d := float(player.get("hp", 1.0)) / maxf(1.0, float(player.get("max_hp", 1.0)))
							if hp_ratio_d <= WOUNDED_HP_RATIO:
								dry_r *= WOUNDED_DRYFIRE_HEAR_MULT
								dry_ttl *= 1.1
							# Greedy pack — stuffing the bag also rattles the empty slap.
							if bool(player.get("heavy_bag", false)):
								dry_r *= HEAVY_BAG_DRYFIRE_HEAR_MULT
								dry_ttl *= 1.05
					_emit_noise(world, player["pos"], dry_r, dry_ttl)
		elif shoot:
			var shot_dir := _player_shot_dir(player, world["loadout"])
			_spawn_bullet(world, player, shot_dir, true, 560.0)
			player["mag"] = int(player["mag"]) - 1
			player["fire_cooldown"] = 1.0 / maxf(0.5, effective_fire_rate)
			_apply_recoil_kick(player, world)
			if int(player["mag"]) <= 0:
				_push_float(world, player["pos"] + Vector2(0, -20), "EMPTY", Color("e85454"), 0.7)
			# Sprint-firing is louder — crouch/brace shots stay quieter.
			var hear_r := HEAR_SHOT_RANGE
			var hear_ttl := NOISE_TTL_SHOT
			if bool(player["sprinting"]):
				hear_r *= 1.35
				hear_ttl *= 1.25
				player["recoil_bloom"] = minf(
					float(Items.loadout_recoil_stats(world["loadout"])["max_bloom"]),
					float(player.get("recoil_bloom", 0.0)) + 0.02
				)
			else:
				var braced := bool(player.get("bracing", false))
				var crouched := bool(player.get("crouching", false))
				if braced and crouched:
					hear_r *= BRACE_CROUCH_SHOT_HEAR_MULT
					hear_ttl *= 0.75
				elif braced:
					hear_r *= BRACE_SHOT_HEAR_MULT
					hear_ttl *= 0.9
				elif crouched:
					hear_r *= CROUCH_SHOT_HEAR_MULT
					hear_ttl *= 0.85
				else:
					var hp_ratio_s := float(player.get("hp", 1.0)) / maxf(1.0, float(player.get("max_hp", 1.0)))
					if hp_ratio_s <= WOUNDED_HP_RATIO:
						hear_r *= WOUNDED_SHOT_HEAR_MULT
						hear_ttl *= 1.08
					# Greedy pack — stuffing the bag also rattles upright shots.
					if bool(player.get("heavy_bag", false)):
						hear_r *= HEAVY_BAG_SHOT_HEAR_MULT
						hear_ttl *= 1.05
			_emit_noise(world, player["pos"], hear_r, hear_ttl)

	if bool(player["sprinting"]):
		var sprint_r := HEAR_SPRINT_RANGE
		# Greedy pack — stuffing the bag also telegraphs a sprint farther.
		if bool(player.get("heavy_bag", false)):
			sprint_r *= HEAVY_BAG_SPRINT_HEAR_MULT
		# Limp run — critical HP also telegraphs a sprint farther.
		if bool(player.get("wounded", false)):
			sprint_r *= WOUNDED_SPRINT_HEAR_MULT
		_emit_noise(world, player["pos"], sprint_r, NOISE_TTL_SPRINT)
	elif float(player.get("stumble_ttl", 0.0)) > 0.0:
		if want_crouch:
			# Soft land — plant into a crouch to cut the tell and shake it off faster.
			player["stumble_ttl"] = maxf(0.0, float(player["stumble_ttl"]) - dt * (STUMBLE_CROUCH_DECAY - 1.0))
			_emit_noise(world, player["pos"], HEAR_STUMBLE_CROUCH_RANGE, NOISE_TTL_STUMBLE * 0.7)
			if bool(player.get("stumble_crack", false)):
				player["stumble_crack"] = false
				_push_float(world, player["pos"] + Vector2(0, -18), "soft", Color("9de8ff"), 0.5)
		else:
			var stumble_r := HEAR_STUMBLE_RANGE
			var hp_ratio_st := float(player.get("hp", 1.0)) / maxf(1.0, float(player.get("max_hp", 1.0)))
			if hp_ratio_st <= WOUNDED_HP_RATIO:
				stumble_r *= WOUNDED_STUMBLE_HEAR_MULT
			var used_st := float(Items.inventory_used(world["inventory"]))
			var cap_st := maxf(1.0, float(world["inventory_cap"]))
			if used_st / cap_st >= HEAVY_BAG_RATIO or bool(player.get("heavy_bag", false)):
				stumble_r *= HEAVY_BAG_STUMBLE_HEAR_MULT
			_emit_noise(world, player["pos"], stumble_r, NOISE_TTL_STUMBLE)
			if bool(player.get("stumble_crack", false)):
				player["stumble_crack"] = false
				_push_float(world, player["pos"] + Vector2(0, -18), "!", Color("e6b35a"), 0.55)
	elif want_crouch:
		pass  # Crouch footfalls stay below the hearing floor.
	elif move_dir.length_squared() > 1e-6:
		var walk_r := HEAR_WALK_RANGE
		var walk_ttl := NOISE_TTL_WALK
		# Greedy packs telegraph — leave loot or accept the louder trail.
		var used_w := float(Items.inventory_used(world["inventory"]))
		var cap_w := maxf(1.0, float(world["inventory_cap"]))
		var bag_r := used_w / cap_w
		if bag_r >= 1.0:
			walk_r *= FULL_BAG_WALK_HEAR_MULT
			walk_ttl *= 1.15
		elif bag_r >= HEAVY_BAG_RATIO or bool(player.get("heavy_bag", false)):
			walk_r *= HEAVY_BAG_WALK_HEAR_MULT
			walk_ttl *= 1.08
		# Limp shuffle — upright wounded footfalls carry farther.
		var hp_ratio_w := float(player.get("hp", 1.0)) / maxf(1.0, float(player.get("max_hp", 1.0)))
		if hp_ratio_w <= WOUNDED_HP_RATIO:
			walk_r *= WOUNDED_WALK_HEAR_MULT
			walk_ttl *= 1.08
		_emit_noise(world, player["pos"], walk_r, walk_ttl)

	if equip:
		_try_equip_from_bag(world)
	if distract:
		_try_distract_toss(world, crouch and not sprint, brace and not sprint)
	if mark_flare:
		_try_mark_flare(world)
	if intel_pulse:
		_try_intel_pulse(world)

	_tick_noise(world, dt)
	_update_extract_compass(world)
	# Extracts first so the flare is live before roamer AI reacts this frame.
	_update_extracts(world, dt)
	_update_roamers(world, dt)
	_update_bullets(world, dt)
	_update_floats(world, dt)
	_refresh_interact_hint(world)
	_refresh_bag_cap(world)


static func _begin_reload(world: Dictionary) -> void:
	var player: Dictionary = world["player"]
	if not Items.loadout_has_weapon(world["loadout"]):
		_set_message(world, "Unarmed — nothing to reload.", 1.0)
		return
	if float(player.get("heal_channel", 0.0)) > 0.0 or float(player.get("loot_channel", 0.0)) > 0.0:
		return
	var mag := int(player.get("mag", 0))
	var mag_size := int(player.get("mag_size", 0))
	var reserve := int(player.get("reserve", 0))
	if mag >= mag_size:
		# Full mag — R packs one Ammo Box from the bag into reserve instead.
		if _try_pack_ammo_box(world):
			return
		_set_message(world, "Mag already full.")
		return
	if reserve <= 0:
		if _try_pack_ammo_box(world):
			reserve = int(player.get("reserve", 0))
		if reserve <= 0:
			_set_message(world, "No reserve ammo — loot Ammo Boxes or pack from bag (R).")
			return
	player["reload_channel"] = float(player.get("reload_time", 1.5))
	_set_message(world, "Reloading…", float(player["reload_channel"]) + 0.1)
	_push_float(world, player["pos"], "RELOAD", Color("d2b48c"), 0.9)


static func _try_pack_ammo_box(world: Dictionary) -> bool:
	if Items.count_in_stacks(world["inventory"], "ammo_box") <= 0:
		return false
	if not Items.consume_from_stacks(world["inventory"], "ammo_box", 1):
		return false
	var rounds := int(Items.get_item("ammo_box").get("ammo", 30))
	world["player"]["reserve"] = int(world["player"].get("reserve", 0)) + rounds
	_refresh_bag_cap(world)
	_set_message(world, "Packed Ammo Box into reserve (+%d)." % rounds)
	_push_float(world, world["player"]["pos"], "+%d RES" % rounds, Color("d2b48c"), 0.9)
	return true


static func _finish_reload(world: Dictionary) -> void:
	var player: Dictionary = world["player"]
	player["reload_channel"] = 0.0
	var mag := int(player.get("mag", 0))
	var mag_size := int(player.get("mag_size", 0))
	var reserve := int(player.get("reserve", 0))
	var need := mag_size - mag
	var take := mini(need, reserve)
	player["mag"] = mag + take
	player["reserve"] = reserve - take
	_set_message(world, "Reloaded (%d in mag)." % int(player["mag"]))
	_push_float(world, player["pos"], "%d/%d" % [int(player["mag"]), int(player["reserve"])], Color("e6b35a"), 0.9)


static func _interrupt_reload(world: Dictionary) -> void:
	var player: Dictionary = world["player"]
	if float(player.get("reload_channel", 0.0)) <= 0.0:
		return
	player["reload_channel"] = 0.0
	_set_message(world, "Reload interrupted.")
	_push_float(world, player["pos"], "RELOAD STOPPED", Color("e85454"), 0.9)


static func _tick_stamina(player: Dictionary, dt: float, want_sprint: bool, moving: bool) -> void:
	var stamina_max := float(player.get("stamina_max", STAMINA_MAX))
	var stamina := float(player.get("stamina", stamina_max))
	var exhaust := float(player.get("sprint_exhaust", 0.0))
	player["stumble_ttl"] = maxf(0.0, float(player.get("stumble_ttl", 0.0)) - dt)
	if exhaust > 0.0:
		exhaust = maxf(0.0, exhaust - dt)
		player["sprint_exhaust"] = exhaust
		want_sprint = false

	var sprinting := false
	if want_sprint and moving and stamina > 0.0:
		sprinting = true
		var drain := STAMINA_DRAIN
		# Limp lungs — critical HP burns sprint gas faster.
		if bool(player.get("wounded", false)):
			drain *= WOUNDED_STAMINA_DRAIN_MULT
		# Greedy pack — stuffing the bag also burns sprint gas.
		if bool(player.get("heavy_bag", false)):
			drain *= HEAVY_BAG_STAMINA_DRAIN_MULT
		stamina = maxf(0.0, stamina - drain * dt)
		if stamina <= 0.0:
			sprinting = false
			player["sprint_exhaust"] = SPRINT_EXHAUST
			# Collapse into a short plant — loud enough that nearby roamers notice.
			player["stumble_ttl"] = STUMBLE_TTL
			player["stumble_crack"] = true
	else:
		# Regen while walking or standing; slightly slower while moving.
		var regen := STAMINA_REGEN * float(player.get("stamina_regen_mult", 1.0)) * (0.7 if moving else 1.0)
		# Planted rest — bracing still lets the lungs catch up.
		if bool(player.get("bracing", false)) and not moving:
			regen *= 1.35
		# Limp recovery — critical HP also slows the refill.
		if bool(player.get("wounded", false)):
			regen *= WOUNDED_STAMINA_REGEN_MULT
		# Greedy pack — stuffing the bag also slows the refill.
		if bool(player.get("heavy_bag", false)):
			regen *= HEAVY_BAG_STAMINA_REGEN_MULT
		stamina = minf(stamina_max, stamina + regen * dt)

	player["stamina"] = stamina
	player["sprinting"] = sprinting


static func _stance_spread_mult(player: Dictionary) -> float:
	var mult := 1.0
	if bool(player.get("sprinting", false)):
		mult *= 1.4
	if bool(player.get("crouching", false)):
		mult *= CROUCH_SPREAD_MULT
	if bool(player.get("bracing", false)):
		mult *= BRACE_SPREAD_MULT
		if float(player.get("brace_hold", 0.0)) >= BRACE_SETTLE_TIME:
			mult *= BRACE_SETTLE_SPREAD
	# Limp hands — critical HP opens the cone unless the surge is still up.
	var hp_ratio := float(player.get("hp", 1.0)) / maxf(1.0, float(player.get("max_hp", 1.0)))
	if hp_ratio <= WOUNDED_HP_RATIO:
		if float(player.get("adrenaline_ttl", 0.0)) > 0.0:
			mult *= ADRENALINE_SPREAD_MULT
		else:
			mult *= WOUNDED_SPREAD_MULT
	return mult


static func _apply_suppression(world: Dictionary, player: Dictionary, amount: float, ttl: float = 0.55) -> void:
	# Cap with the equipped weapon's bloom ceiling (not a global magic 0.35).
	var stats_cap := float(Items.loadout_recoil_stats(world.get("loadout", {})).get("max_bloom", 0.35))
	if stats_cap <= 0.0:
		stats_cap = 0.35
	player["recoil_bloom"] = minf(stats_cap, float(player.get("recoil_bloom", 0.0)) + amount)
	player["suppress_ttl"] = maxf(float(player.get("suppress_ttl", 0.0)), ttl)


static func _tick_recoil(player: Dictionary, loadout: Dictionary, dt: float) -> void:
	var stats := Items.loadout_recoil_stats(loadout)
	var bloom := float(player.get("recoil_bloom", 0.0))
	bloom = maxf(0.0, bloom - float(stats["recoil_decay"]) * dt)
	player["recoil_bloom"] = bloom
	# Current cone (radians) — HUD reads this for the soft aim wedge.
	var stance_mult := _stance_spread_mult(player)
	var skill_mult := float(player.get("recoil_mult", 1.0))
	player["aim_spread"] = (float(stats["spread"]) + bloom) * stance_mult * skill_mult


static func _player_shot_dir(player: Dictionary, loadout: Dictionary) -> Vector2:
	var aim: Vector2 = player["aim"]
	if aim.length_squared() < 1e-6:
		return Vector2.RIGHT
	var stats := Items.loadout_recoil_stats(loadout)
	var bloom := float(player.get("recoil_bloom", 0.0))
	var skill_mult := float(player.get("recoil_mult", 1.0))
	var stance_mult := _stance_spread_mult(player)
	var cone := (float(stats["spread"]) + bloom) * stance_mult * skill_mult
	var offset := randf_range(-cone, cone)
	return aim.normalized().rotated(offset)


static func _apply_recoil_kick(player: Dictionary, world: Dictionary) -> void:
	var stats := Items.loadout_recoil_stats(world["loadout"])
	var bloom := float(player.get("recoil_bloom", 0.0))
	var skill_mult := float(player.get("recoil_mult", 1.0))
	player["recoil_bloom"] = minf(float(stats["max_bloom"]), bloom + float(stats["recoil"]) * skill_mult)
	world["shake"] = maxf(float(world.get("shake", 0.0)), float(stats["kick"]))
	# Refresh cone immediately so the next frame's wedge matches the kick.
	var stance_mult := _stance_spread_mult(player)
	player["aim_spread"] = (float(stats["spread"]) + float(player["recoil_bloom"])) * stance_mult * skill_mult


static func _emit_noise(world: Dictionary, pos: Vector2, radius: float, ttl: float) -> void:
	# Keep the louder / longer noise if both sprint and shots fire the same frame.
	if radius >= float(world.get("noise_radius", 0.0)) or ttl >= float(world.get("noise_ttl", 0.0)):
		world["noise_pos"] = pos
		world["noise_radius"] = maxf(float(world.get("noise_radius", 0.0)), radius)
		world["noise_ttl"] = maxf(float(world.get("noise_ttl", 0.0)), ttl)


static func _tick_noise(world: Dictionary, dt: float) -> void:
	var ttl := float(world.get("noise_ttl", 0.0))
	if ttl <= 0.0:
		world["noise_radius"] = 0.0
		return
	world["noise_ttl"] = ttl - dt
	if float(world["noise_ttl"]) <= 0.0:
		world["noise_radius"] = 0.0
		world["noise_ttl"] = 0.0


static func _update_extract_compass(world: Dictionary) -> void:
	var player: Dictionary = world["player"]
	var best_id := -1
	var best_dist := INF
	var best_dir := Vector2.RIGHT
	var best_pressure := ""
	for z in world["extracts"]:
		if not bool(z.get("active", true)):
			continue
		var d: float = player["pos"].distance_to(z["pos"])
		if d < best_dist:
			best_dist = d
			best_id = int(z["id"])
			best_pressure = String(z.get("pressure", "contested"))
			var delta: Vector2 = z["pos"] - player["pos"]
			best_dir = delta.normalized() if delta.length_squared() > 1e-6 else Vector2.RIGHT
	world["nearest_extract_id"] = best_id
	world["nearest_extract_dist"] = 0.0 if best_id < 0 else best_dist
	world["nearest_extract_dir"] = best_dir
	world["nearest_extract_pressure"] = best_pressure


static func _try_equip_from_bag(world: Dictionary) -> void:
	var player: Dictionary = world["player"]
	if float(player.get("heal_channel", 0.0)) > 0.0 or float(player.get("reload_channel", 0.0)) > 0.0 \
			or float(player.get("loot_channel", 0.0)) > 0.0:
		_set_message(world, "Can't swap gear while channeling.")
		return
	var loadout: Dictionary = world["loadout"]
	var inv: Array = world["inventory"]
	var equipped_any := false
	var notes: Array[String] = []

	for slot_pair in [["weapon", "weapon_id"], ["armor", "armor_id"], ["bag", "bag_id"]]:
		var slot: String = slot_pair[0]
		var key: String = slot_pair[1]
		var best_id: Variant = null
		var best_score := -1.0
		for s in inv:
			var def := Items.get_item(String(s["def_id"]))
			if String(def["slot"]) != slot:
				continue
			var score := float(def.get("value", 0))
			if score > best_score:
				best_score = score
				best_id = String(s["def_id"])
		if best_id == null:
			continue
		var cur: Variant = loadout.get(key)
		var cur_score := -1.0
		if cur != null and not String(cur).is_empty():
			cur_score = float(Items.get_item(String(cur)).get("value", 0))
		if best_score <= cur_score:
			continue
		# Swap: bag item → loadout; old loadout → bag.
		if not Items.consume_from_stacks(inv, String(best_id), 1):
			continue
		if cur != null and not String(cur).is_empty():
			Items.add_to_stash(inv, Items.stack_of(String(cur), 1))
		loadout[key] = String(best_id)
		equipped_any = true
		notes.append(Items.item_name(best_id))
		if slot == "weapon":
			player["armed"] = true
			player["damage"] = Items.loadout_damage(loadout)
			player["fire_rate"] = Items.loadout_fire_rate(loadout)
			var mag_size := Items.weapon_mag_size(loadout)
			player["mag_size"] = mag_size
			player["reload_time"] = Items.weapon_reload_time(loadout)
			player["recoil_bloom"] = 0.0
			# Chamber what reserve allows; leftover mag ammo folds into reserve.
			var old_mag := int(player.get("mag", 0))
			player["reserve"] = int(player.get("reserve", 0)) + old_mag
			var fill := mini(mag_size, int(player["reserve"]))
			player["mag"] = fill
			player["reserve"] = int(player["reserve"]) - fill
			player["reload_channel"] = 0.0
		elif slot == "armor":
			player["base_mitigation"] = Items.loadout_mitigation(loadout)
			var armor_max := Items.loadout_armor_durability(loadout)
			player["armor_max"] = armor_max
			player["armor_hp"] = armor_max
			_refresh_armor_mitigation(player)
		elif slot == "bag":
			_refresh_bag_cap(world)

	if equipped_any:
		_refresh_bag_cap(world)
		_set_message(world, "Equipped: %s" % ", ".join(notes))
		_push_float(world, player["pos"], "GEAR UP", Color("6ec1ff"), 1.0)
	else:
		_set_message(world, "No better weapon / armor / bag in bag — loot upgrades first.")


static func _begin_medkit(world: Dictionary) -> void:
	var player: Dictionary = world["player"]
	if float(player.get("loot_channel", 0.0)) > 0.0 or float(player.get("reload_channel", 0.0)) > 0.0:
		_set_message(world, "Finish what you're doing first.")
		return
	if float(player["hp"]) >= float(player["max_hp"]) - 0.5:
		_set_message(world, "Already healthy — save the medkit.")
		return
	if Items.count_in_stacks(world["inventory"], "medkit") <= 0:
		_set_message(world, "No Field Medkit in bag — ransack one or pack from hideout.")
		return
	var heal := float(Items.get_item("medkit").get("heal", 45.0))
	var med_dur := MEDKIT_CHANNEL * float(player.get("medkit_mult", 1.0))
	player["heal_channel"] = med_dur
	player["heal_amount"] = heal
	_set_message(world, "Using Field Medkit… stay alive for %.1fs" % med_dur, med_dur + 0.2)
	_push_float(world, player["pos"], "HEALING", Color("e07070"), 1.0)


static func _finish_medkit(world: Dictionary) -> void:
	var player: Dictionary = world["player"]
	player["heal_channel"] = 0.0
	if not Items.consume_from_stacks(world["inventory"], "medkit", 1):
		player["heal_amount"] = 0.0
		_set_message(world, "Medkit fumbled — none left.")
		return
	var heal := float(player.get("heal_amount", 45.0))
	player["heal_amount"] = 0.0
	var before := float(player["hp"])
	player["hp"] = mini(float(player["max_hp"]), before + heal)
	var gained := int(ceil(float(player["hp"]) - before))
	world["skill_deeds"] = int(world.get("skill_deeds", 0)) + 1
	_set_message(world, "Medkit applied (+%d HP)." % gained)
	_push_float(world, player["pos"], "+%d HP" % gained, Color("3ecf8e"), 1.2)


static func _interrupt_medkit(world: Dictionary, reason: String) -> void:
	var player: Dictionary = world["player"]
	if float(player.get("heal_channel", 0.0)) <= 0.0:
		return
	player["heal_channel"] = 0.0
	player["heal_amount"] = 0.0
	_set_message(world, reason)
	_push_float(world, player["pos"], "HEAL INTERRUPTED", Color("e85454"), 1.0)


static func _find_loot_target(world: Dictionary) -> Variant:
	var player: Dictionary = world["player"]
	var nearest: Variant = null
	var best := INF
	for c in world["crates"]:
		if bool(c["opened"]):
			continue
		var d: float = player["pos"].distance_to(c["pos"])
		var bias := 0.0
		var kind := String(c.get("kind", "crate"))
		if kind == "drop_bag":
			bias = -8.0
		elif kind == "corpse":
			bias = -4.0
		if d <= float(c["radius"]) + float(player["radius"]) + 10.0 and d + bias < best:
			best = d + bias
			nearest = c
	return nearest


static func _loot_target_by_id(world: Dictionary, target_id: int) -> Variant:
	for c in world["crates"]:
		if int(c["id"]) == target_id:
			return c
	return null


static func _loot_channel_for_kind(kind: String) -> float:
	match kind:
		"corpse":
			return LOOT_CHANNEL_CORPSE
		"drop_bag":
			return LOOT_CHANNEL_DROP_BAG
		"ammo_crate":
			return LOOT_CHANNEL_AMMO
		"med_cache":
			return LOOT_CHANNEL_MED
		"weapon_case":
			return LOOT_CHANNEL_WEAPON
		"intel_safe":
			return LOOT_CHANNEL_INTEL
		_:
			return LOOT_CHANNEL_CRATE


static func _try_interact(world: Dictionary) -> void:
	var loot = _find_loot_target(world)
	var door = _find_door_target(world)
	# Loot wins when both in reach — don't steal E from a body/crate.
	if loot != null:
		_begin_loot(world)
		return
	if door != null:
		_toggle_door(world, door)
		return
	_set_message(world, "Nothing in reach — get next to a crate, body, or door.")


static func _find_door_target(world: Dictionary) -> Variant:
	var player: Dictionary = world["player"]
	var nearest: Variant = null
	var best := INF
	for o in world["obstacles"]:
		if String(o.get("kind", "")) != "door":
			continue
		var center := Vector2(float(o["x"]) + float(o["w"]) * 0.5, float(o["y"]) + float(o["h"]) * 0.5)
		var d: float = player["pos"].distance_to(center)
		var reach := DOOR_INTERACT_RANGE + float(player["radius"]) + maxf(float(o["w"]), float(o["h"])) * 0.35
		if d <= reach and d < best:
			best = d
			nearest = o
	return nearest


static func _try_sprint_door_bash(world: Dictionary, player: Dictionary, move_dir: Vector2) -> void:
	# Probe a short step ahead — if a closed door sits there, kick it open.
	var ahead := move_dir.normalized() * (float(player["radius"]) + 14.0)
	var probes: Array = [player["pos"] + ahead, player["pos"] + ahead * 0.5, player["pos"]]
	for o in world["obstacles"]:
		if String(o.get("kind", "")) != "door" or bool(o.get("open", false)):
			continue
		var hit := false
		for probe in probes:
			var p: Vector2 = probe
			if p.x >= float(o["x"]) and p.x <= float(o["x"]) + float(o["w"]) \
					and p.y >= float(o["y"]) and p.y <= float(o["y"]) + float(o["h"]):
				hit = true
				break
		if not hit:
			continue
		o["open"] = true
		var center := Vector2(float(o["x"]) + float(o["w"]) * 0.5, float(o["y"]) + float(o["h"]) * 0.5)
		var bash_cost := DOOR_BASH_STAMINA
		# Limp kick — critical HP also burns more composure on the plant.
		if bool(player.get("wounded", false)):
			bash_cost *= WOUNDED_DOOR_BASH_STAMINA_MULT
		# Greedy pack — stuffing the bag also burns more composure on the kick.
		if bool(player.get("heavy_bag", false)):
			bash_cost *= HEAVY_BAG_DOOR_BASH_STAMINA_MULT
		player["stamina"] = maxf(0.0, float(player.get("stamina", 0.0)) - bash_cost)
		var bash_r := HEAR_DOOR_BASH_RANGE
		# Limp kick — critical HP telegraphs a bash farther.
		if bool(player.get("wounded", false)):
			bash_r *= WOUNDED_DOOR_BASH_HEAR_MULT
		# Greedy pack — stuffing the bag also telegraphs a bash farther.
		if bool(player.get("heavy_bag", false)):
			bash_r *= HEAVY_BAG_DOOR_BASH_HEAR_MULT
		_emit_noise(world, center, bash_r, NOISE_TTL_DOOR_BASH)
		_push_float(world, center, "BASH", Color("e6b35a"), 0.9)
		_set_message(world, "Door bashed open — loud.", 1.4)
		world["skill_deeds"] = int(world.get("skill_deeds", 0)) + 1
		return


static func _toggle_door(world: Dictionary, door: Dictionary) -> void:
	door["open"] = not bool(door.get("open", false))
	var center := Vector2(float(door["x"]) + float(door["w"]) * 0.5, float(door["y"]) + float(door["h"]) * 0.5)
	var player: Dictionary = world["player"]
	var quiet := bool(player.get("crouching", false)) and not bool(player.get("sprinting", false))
	var hp_ratio := float(player.get("hp", 1.0)) / maxf(1.0, float(player.get("max_hp", 1.0)))
	var wounded_clang := (not quiet) and hp_ratio <= WOUNDED_HP_RATIO
	var used_d := float(Items.inventory_used(world["inventory"]))
	var cap_d := maxf(1.0, float(world["inventory_cap"]))
	var heavy_clang := (not quiet) and (used_d / cap_d >= HEAVY_BAG_RATIO or bool(player.get("heavy_bag", false)))
	if bool(door["open"]):
		if quiet:
			_set_message(world, "Door eased open.", 1.2)
			_push_float(world, center, "SOFT", Color("9de8ff"), 0.65)
			_emit_noise(world, center, HEAR_DOOR_CROUCH_RANGE, NOISE_TTL_DOOR_CROUCH)
		else:
			var pry_r := HEAR_DOOR_PRY_RANGE
			if wounded_clang:
				pry_r *= WOUNDED_DOOR_PRY_HEAR_MULT
			if heavy_clang:
				pry_r *= HEAVY_BAG_DOOR_PRY_HEAR_MULT
			_set_message(world, "Door open.")
			_push_float(world, center, "OPEN", Color("9de8ff"), 0.7)
			_emit_noise(world, center, pry_r, NOISE_TTL_DOOR_PRY)
	else:
		if quiet:
			_set_message(world, "Door eased shut.", 1.2)
			_push_float(world, center, "SOFT", Color("8fa3b8"), 0.65)
			_emit_noise(world, center, HEAR_DOOR_CROUCH_RANGE * 0.85, NOISE_TTL_DOOR_CROUCH)
		else:
			var shut_r := HEAR_DOOR_PRY_RANGE * 0.7
			if wounded_clang:
				shut_r *= WOUNDED_DOOR_PRY_HEAR_MULT
			if heavy_clang:
				shut_r *= HEAVY_BAG_DOOR_PRY_HEAR_MULT
			_set_message(world, "Door shut.")
			_push_float(world, center, "SHUT", Color("8fa3b8"), 0.7)
			_emit_noise(world, center, shut_r, NOISE_TTL_DOOR_PRY * 0.85)


static func _begin_loot(world: Dictionary) -> void:
	var player: Dictionary = world["player"]
	var nearest = _find_loot_target(world)
	if nearest == null:
		_set_message(world, "Nothing in reach — get next to a crate or body.")
		return
	var kind := String(nearest.get("kind", "crate"))
	var dur := _loot_channel_for_kind(kind) * float(player.get("loot_mult", 1.0))
	player["loot_channel"] = dur
	player["loot_channel_max"] = dur
	player["loot_target_id"] = int(nearest["id"])
	var label := "%s…" % Items.container_display_name(kind)
	match kind:
		"corpse":
			label = "Stripping body…"
		"drop_bag":
			label = "Grabbing drop bag…"
		"weapon_case":
			label = "Cracking weapon case…"
		"intel_safe":
			label = "Picking intel safe…"
		"med_cache":
			label = "Opening med cache…"
		"ammo_crate":
			label = "Breaking ammo crate…"
		_:
			label = "Prying crate…"
	_set_message(world, "%s stay close — this is loud." % label, dur + 0.3)
	_push_float(world, nearest["pos"], "RANSACK", Color("e6b35a"), 0.9)
	_emit_noise(world, player["pos"], HEAR_RANSACK_RANGE, 0.5)


static func _tick_loot_channel(world: Dictionary, dt: float, move: Vector2, aim_world: Vector2, crouch: bool = false) -> void:
	var player: Dictionary = world["player"]
	var target = _loot_target_by_id(world, int(player.get("loot_target_id", -1)))
	if target == null or bool(target.get("opened", false)):
		_interrupt_loot(world, "Target gone — ransack cancelled.")
		_post_channel_world(world, dt)
		return
	var reach := float(target["radius"]) + float(player["radius"]) + 22.0
	if player["pos"].distance_to(target["pos"]) > reach:
		_interrupt_loot(world, "Moved off the loot — ransack cancelled.")
		_post_channel_world(world, dt)
		return

	player["crouching"] = crouch
	var loot_rate := CROUCH_LOOT_RATE if crouch else 1.0
	# Shaking hands — critical wounds make lids stick.
	var hp_ratio_l := float(player["hp"]) / maxf(1.0, float(player["max_hp"]))
	if hp_ratio_l <= WOUNDED_HP_RATIO:
		loot_rate *= WOUNDED_LOOT_RATE
	# Greedy packs — digging past a stuffed bag slows the pry.
	var used_loot := float(Items.inventory_used(world["inventory"]))
	var cap_loot := maxf(1.0, float(world["inventory_cap"]))
	if used_loot / cap_loot >= HEAVY_BAG_RATIO:
		loot_rate *= HEAVY_BAG_LOOT_RATE
	player["loot_channel"] = float(player["loot_channel"]) - dt * loot_rate
	_tick_stamina(player, dt, false, false)
	_tick_recoil(player, world["loadout"], dt)
	var move_dir := move.normalized() if move.length_squared() > 1e-6 else Vector2.ZERO
	# Slow shuffle while hands are busy; crouch is even tighter.
	var shuffle := 0.22 if crouch else 0.28
	player["vel"] = move_dir * float(player["speed"]) * shuffle
	player["pos"] = player["pos"] + player["vel"] * dt
	_collide_actor_obstacles(player, world["obstacles"])
	_clamp_to_map(player, float(world["width"]), float(world["height"]))
	var aim: Vector2 = aim_world - (player["pos"] as Vector2)
	player["aim"] = aim.normalized() if aim.length_squared() > 1e-6 else Vector2.RIGHT
	# Continuous clatter — quieter when crouched over the lid; greed rattles louder.
	var hear := HEAR_RANSACK_RANGE * (CROUCH_RANSACK_HEAR_MULT if crouch else 1.0)
	var used_l := float(Items.inventory_used(world["inventory"]))
	var cap_l := maxf(1.0, float(world["inventory_cap"]))
	if used_l / cap_l >= HEAVY_BAG_RATIO:
		hear *= HEAVY_BAG_RANSACK_HEAR_MULT
	_emit_noise(world, player["pos"], hear, 0.35)

	if float(player["loot_channel"]) <= 0.0:
		_finish_loot(world, target)
	_post_channel_world(world, dt)


static func _post_channel_world(world: Dictionary, dt: float) -> void:
	# Scent while channeling — wounded trails must still drip during loot/heal/reload.
	_tick_blood_trail(world, dt)
	_tick_noise(world, dt)
	_update_extract_compass(world)
	_update_extracts(world, dt)
	_update_roamers(world, dt)
	_update_bullets(world, dt)
	_update_floats(world, dt)
	_refresh_interact_hint(world)
	_refresh_bag_cap(world)


static func _interrupt_loot(world: Dictionary, reason: String) -> void:
	var player: Dictionary = world["player"]
	if float(player.get("loot_channel", 0.0)) <= 0.0 and int(player.get("loot_target_id", -1)) < 0:
		return
	player["loot_channel"] = 0.0
	player["loot_channel_max"] = 0.0
	player["loot_target_id"] = -1
	_set_message(world, reason)
	_push_float(world, player["pos"], "RANSACK STOPPED", Color("e85454"), 0.9)


static func _finish_loot(world: Dictionary, nearest: Dictionary) -> void:
	var player: Dictionary = world["player"]
	player["loot_channel"] = 0.0
	player["loot_channel_max"] = 0.0
	player["loot_target_id"] = -1
	_refresh_bag_cap(world)
	var taken_names: Array[String] = []
	var taken := 0
	var blocked := 0
	var ammo_gained := 0
	var kind := String(nearest.get("kind", "crate"))
	var remaining: Array = []
	for stack in nearest["contents"]:
		_refresh_bag_cap(world)
		if String(stack["def_id"]) == "ammo_box":
			var rounds := int(Items.get_item("ammo_box").get("ammo", 30)) * int(stack["qty"])
			world["player"]["reserve"] = int(world["player"].get("reserve", 0)) + rounds
			ammo_gained += rounds
			taken += int(stack["qty"])
			taken_names.append("Ammo +%d" % rounds)
			continue
		var qty := int(stack["qty"])
		var left := Items.try_add_inventory_partial(
			world["inventory"], int(world["inventory_cap"]), {"def_id": stack["def_id"], "qty": qty}
		)
		var got := qty - left
		if got > 0:
			taken += got
			taken_names.append(Items.item_name(stack["def_id"]))
		if left > 0:
			blocked += left
			remaining.append({"def_id": String(stack["def_id"]), "qty": left})
	# Keep unclaimed stacks in the container — bag-full must not delete loot.
	nearest["contents"] = remaining
	nearest["opened"] = remaining.is_empty()
	_refresh_bag_cap(world)
	var verb := Items.container_display_name(kind)
	if kind == "corpse":
		verb = "Stripped body"
	elif kind == "drop_bag":
		verb = "Grabbed drop bag"
	elif kind == "weapon_case":
		verb = "Cracked weapon case"
	elif kind == "intel_safe":
		verb = "Opened intel safe"
	elif kind == "med_cache":
		verb = "Looted med cache"
	elif kind == "ammo_crate":
		verb = "Broke ammo crate"
	else:
		verb = "Cracked crate"
	if ammo_gained > 0 and taken == int(ceil(float(ammo_gained) / 30.0)) and blocked == 0 and taken_names.size() == 1:
		_set_message(world, "Scooped ammo into reserve (+%d)." % ammo_gained)
		_push_float(world, nearest["pos"], "+%d AMMO" % ammo_gained, Color("d2b48c"))
	elif taken == 0 and blocked > 0:
		_set_message(world, "Bag full — extract with what you have, or find a bigger bag.")
		_push_float(world, nearest["pos"], "BAG FULL", Color("e85454"))
	elif blocked > 0:
		var label := ", ".join(taken_names.slice(0, mini(2, taken_names.size())))
		_set_message(world, "%s %s (+%d; bag full, left %d)." % [verb, label, taken, blocked])
		_push_float(world, nearest["pos"], "+%s" % label, Color("3ecf8e"))
	else:
		var label2 := ", ".join(taken_names.slice(0, mini(3, taken_names.size())))
		_set_message(world, "%s: %s" % [verb, label2])
		_push_float(world, nearest["pos"], "+%s" % label2, Color("e6b35a"))
	if taken > 0 and Items.has_better_gear_in_inventory(world["loadout"], world["inventory"]):
		_set_message(world, "%s — press F to equip upgrades." % String(world["message"]), 3.0)
	if taken > 0:
		world["skill_deeds"] = int(world.get("skill_deeds", 0)) + 1


static func _try_distract_toss(world: Dictionary, crouch: bool = false, brace: bool = false) -> void:
	var player: Dictionary = world["player"]
	if float(player.get("distract_cooldown", 0.0)) > 0.0:
		_set_message(world, "Wait to toss again.", 0.8)
		return
	if Items.count_in_stacks(world["inventory"], "scrap") <= 0:
		_set_message(world, "Need Scrap Parts in bag to toss a decoy.")
		return
	if not Items.consume_from_stacks(world["inventory"], "scrap", 1):
		_set_message(world, "Need Scrap Parts in bag to toss a decoy.")
		return
	var aim: Vector2 = player.get("aim", Vector2.RIGHT)
	if aim.length_squared() < 1e-6:
		aim = Vector2.RIGHT
	var toss_range := DISTRACT_TOSS_RANGE
	if crouch and brace:
		toss_range *= 0.78
	elif crouch:
		toss_range *= 0.85
	elif brace:
		toss_range *= 0.92
	var land: Vector2 = player["pos"] + aim.normalized() * toss_range
	land.x = clampf(land.x, 20.0, float(world["width"]) - 20.0)
	land.y = clampf(land.y, 20.0, float(world["height"]) - 20.0)
	player["distract_cooldown"] = DISTRACT_COOLDOWN
	# Planted / crouched toss: softer clang that hangs longer — sneaky pull.
	var hear := HEAR_DISTRACT_RANGE
	var ttl := NOISE_TTL_DISTRACT
	if crouch and brace:
		hear *= BRACE_CROUCH_DISTRACT_HEAR_MULT
		ttl *= BRACE_CROUCH_DISTRACT_TTL_MULT
	elif crouch:
		hear *= CROUCH_DISTRACT_HEAR_MULT
		ttl *= CROUCH_DISTRACT_TTL_MULT
	elif brace:
		hear *= BRACE_DISTRACT_HEAR_MULT
		ttl *= BRACE_DISTRACT_TTL_MULT
	else:
		# Upright limp toss — shaking hands telegraph the clang farther.
		var hp_ratio_t := float(player.get("hp", 1.0)) / maxf(1.0, float(player.get("max_hp", 1.0)))
		if hp_ratio_t <= WOUNDED_HP_RATIO:
			hear *= WOUNDED_DISTRACT_HEAR_MULT
			ttl *= 1.08
		# Greedy pack — stuffing the bag also rattles an upright toss.
		var used_t := float(Items.inventory_used(world["inventory"]))
		var cap_t := maxf(1.0, float(world["inventory_cap"]))
		if used_t / cap_t >= HEAVY_BAG_RATIO or bool(player.get("heavy_bag", false)):
			hear *= HEAVY_BAG_DISTRACT_HEAR_MULT
			ttl *= 1.05
	_emit_noise(world, land, hear, ttl)
	var soft := crouch or brace
	_push_float(world, land, "clink" if soft else "CLANG", Color("d2b48c"), 1.4)
	if crouch and brace:
		_set_message(world, "Planted soft decoy — should linger.", 2.0)
	elif crouch:
		_set_message(world, "Soft decoy tossed — should linger.", 2.0)
	elif brace:
		_set_message(world, "Planted decoy tossed — quieter clang.", 2.0)
	else:
		_set_message(world, "Scrap tossed — roamers should check the clang.", 2.0)
	_refresh_bag_cap(world)


static func _smooth_vec(current: Vector2, desired: Vector2, responsivity: float, dt: float) -> Vector2:
	## Exponential approach — framerate-stable accel/decel without overshoot.
	var t := 1.0 - exp(-maxf(0.0, responsivity) * dt)
	return current.lerp(desired, clampf(t, 0.0, 1.0))


static func _smooth_aim(current: Vector2, desired: Vector2, responsivity: float, dt: float) -> Vector2:
	var cur := current
	if cur.length_squared() < 1e-6:
		cur = Vector2.RIGHT
	else:
		cur = cur.normalized()
	var want := desired
	if want.length_squared() < 1e-6:
		return cur
	want = want.normalized()
	var a0 := cur.angle()
	var da := wrapf(want.angle() - a0, -PI, PI)
	var t := 1.0 - exp(-maxf(0.0, responsivity) * dt)
	return Vector2.from_angle(a0 + da * clampf(t, 0.0, 1.0))


static func _try_empty_mag_shove(world: Dictionary) -> bool:
	## Back-compat alias — empty mag still shoves.
	return _try_melee(world, false)


static func _spend_melee_stamina(player: Dictionary, cost: float) -> bool:
	var stam := float(player.get("stamina", 0.0))
	if stam < cost:
		return false
	player["stamina"] = stam - cost
	return true


static func _swing_punch_miss(world: Dictionary) -> void:
	var player: Dictionary = world["player"]
	if not _spend_melee_stamina(player, PUNCH_MISS_STAMINA_COST):
		_set_message(world, "Too gassed to swing.", 0.9)
		player["fire_cooldown"] = 0.25
		return
	player["fire_cooldown"] = PUNCH_COOLDOWN * 0.75
	player["punch_swing"] = PUNCH_SWING_TTL
	_emit_noise(world, player["pos"], HEAR_PUNCH_RANGE * 0.55, NOISE_TTL_PUNCH * 0.7)
	_push_float(world, player["pos"] + Vector2(0, -16), "—", Color(0.75, 0.8, 0.85, 0.7), 0.35)


static func _try_melee(world: Dictionary, unarmed: bool = false) -> bool:
	var player: Dictionary = world["player"]
	var reach := PUNCH_RANGE if unarmed else MELEE_RANGE
	var best: Variant = null
	var best_d := reach
	var aim: Vector2 = player.get("aim", Vector2.RIGHT)
	if aim.length_squared() < 1e-6:
		aim = Vector2.RIGHT
	else:
		aim = aim.normalized()
	for roamer in world["roamers"]:
		if not bool(roamer["alive"]):
			continue
		var to_r: Vector2 = roamer["pos"] - player["pos"]
		var d := to_r.length()
		if d > best_d or d < 1e-6:
			continue
		# Must be roughly in front — no rear bashes.
		if to_r.normalized().dot(aim) < 0.25:
			continue
		best_d = d
		best = roamer
	if best == null:
		return false
	var stam_cost := PUNCH_STAMINA_COST if unarmed else MELEE_STAMINA_COST
	if not _spend_melee_stamina(player, stam_cost):
		_set_message(world, "Too gassed to swing.", 0.9)
		player["fire_cooldown"] = 0.25
		return true  # consumed the click; don't fall through to miss/dry-fire
	var target: Dictionary = best
	# Behind a sleeper while crouched — drop them soft instead of a stadium shove.
	var was_dormant := bool(target.get("dormant", false))
	var from_t: Vector2 = (player["pos"] as Vector2) - (target["pos"] as Vector2)
	var t_aim: Vector2 = target.get("aim", Vector2.RIGHT)
	var behind := from_t.length_squared() > 1e-6 and t_aim.length_squared() > 1e-6 \
		and from_t.normalized().dot(t_aim.normalized()) <= MELEE_BEHIND_DOT
	var silent := was_dormant and behind \
		and bool(player.get("crouching", false)) and not bool(player.get("sprinting", false)) \
		and not bool(target.get("elite", false))
	# Hobble once — pin feet in place; never stack / refresh while already slowed.
	if float(target.get("melee_slow_ttl", 0.0)) <= 0.0:
		target["melee_slow_ttl"] = MELEE_SLOW_TTL
		target["melee_root_pos"] = Vector2(target["pos"])
	var base_dmg := PUNCH_SILENT_DAMAGE if (unarmed and silent) else (PUNCH_DAMAGE if unarmed else (MELEE_SILENT_DAMAGE if silent else MELEE_DAMAGE))
	var dmg := base_dmg * (0.7 if bool(target.get("elite", false)) else 1.0)
	target["hp"] = float(target["hp"]) - dmg
	target["hit_flash"] = 0.18
	target["fire_cooldown"] = maxf(float(target.get("fire_cooldown", 0.0)), 0.55)
	target["alert_ttl"] = maxf(float(target.get("alert_ttl", 0.0)), 0.4 if silent else 2.2)
	target["last_seen"] = player["pos"]
	target["last_heard"] = player["pos"]
	# Contact wakes / pulls attention — don't stay dormant after a hit.
	target["dormant"] = false
	if String(target.get("ai_state", "")) != "rush":
		var hp_ratio := float(target["hp"]) / maxf(1.0, float(target.get("max_hp", target["hp"])))
		if hp_ratio <= ROAMER_RETREAT_HP and not bool(target.get("elite", false)):
			target["ai_state"] = "retreat"
		else:
			target["ai_state"] = "combat"
	player["fire_cooldown"] = PUNCH_COOLDOWN if unarmed else MELEE_COOLDOWN
	player["punch_swing"] = PUNCH_SWING_TTL
	if not unarmed:
		player["recoil_bloom"] = minf(
			float(Items.loadout_recoil_stats(world["loadout"])["max_bloom"]),
			float(player.get("recoil_bloom", 0.0)) + (0.012 if silent else 0.03)
		)
	# No camera shake on melee — shake made contact read as a warp.
	if silent:
		_emit_noise(world, player["pos"], HEAR_MELEE_SILENT_RANGE, NOISE_TTL_MELEE_SILENT)
		_push_float(world, target["pos"] + Vector2(0, -14), "DROP", Color("9de8ff"), 0.65)
	else:
		var melee_r := HEAR_PUNCH_RANGE if unarmed else HEAR_MELEE_RANGE
		var melee_ttl := NOISE_TTL_PUNCH if unarmed else NOISE_TTL_MELEE
		# Limp contact — critical HP telegraphs an upright hit farther.
		var hp_ratio_m := float(player.get("hp", 1.0)) / maxf(1.0, float(player.get("max_hp", 1.0)))
		if hp_ratio_m <= WOUNDED_HP_RATIO and not bool(player.get("crouching", false)):
			melee_r *= WOUNDED_MELEE_HEAR_MULT
		# Greedy pack — stuffing the bag also rattles an upright hit.
		if not bool(player.get("crouching", false)) \
				and (bool(player.get("heavy_bag", false)) \
				or float(Items.inventory_used(world["inventory"])) / maxf(1.0, float(world["inventory_cap"])) >= HEAVY_BAG_RATIO):
			melee_r *= HEAVY_BAG_MELEE_HEAR_MULT
		_emit_noise(world, player["pos"], melee_r, melee_ttl)
		_push_float(world, target["pos"] + Vector2(0, -14), "PUNCH" if unarmed else "SHOVE", Color("e6b35a"), 0.7)
	_push_float(world, target["pos"], "-%d" % int(ceil(dmg)), Color("ffd0d0"), 0.5)
	if float(target["hp"]) <= 0.0:
		target["alive"] = false
		var elite := bool(target.get("elite", false))
		world["crates"].append({
			"id": _alloc_id(world),
			"pos": target["pos"],
			"radius": 15.0 if elite else 14.0,
			"opened": false,
			"kind": "corpse",
			"elite": elite,
			"contents": Items.roll_enforcer_loot() if elite else Items.roll_roamer_loot(),
		})
		world["skill_deeds"] = int(world.get("skill_deeds", 0)) + (3 if elite else (3 if silent else 2))
		_set_message(world, "Dropped quiet — strip the body (E)." if silent else ("Punched down — strip the body (E)." if unarmed else "Shoved down — strip the body (E)."))
		_push_float(world, target["pos"], "ENFORCER DOWN" if elite else "ROAMER DOWN", Color("c9a0ff") if elite else Color("e6b35a"), 1.2)
	else:
		if silent:
			_set_message(world, "Soft drop — still breathing.", 1.1)
		elif unarmed:
			_set_message(world, "Punch landed.", 1.0)
		else:
			_set_message(world, "Buttstock shove — reload when you can.", 1.1)
	return true


static func _try_intel_pulse(world: Dictionary) -> void:
	if float(world.get("intel_pulse_cd", 0.0)) > 0.0:
		_set_message(world, "Intel still cooling.", 0.8)
		return
	if float(world.get("intel_pulse_ttl", 0.0)) > 0.0:
		_set_message(world, "Sweep already live.", 0.8)
		return
	if Items.count_in_stacks(world["inventory"], "intel") <= 0:
		_set_message(world, "Need a Signal Chip in bag to sweep.")
		return
	if not Items.consume_from_stacks(world["inventory"], "intel", 1):
		_set_message(world, "Need a Signal Chip in bag to sweep.")
		return
	world["intel_pulse_ttl"] = INTEL_PULSE_TTL
	world["intel_pulse_cd"] = INTEL_PULSE_COOLDOWN
	_refresh_bag_cap(world)
	_set_message(world, "Intel sweep — hostiles marked briefly.", INTEL_PULSE_TTL)
	_push_float(world, world["player"]["pos"], "SWEEP", Color("7fd0ff"), 1.0)
	world["skill_deeds"] = int(world.get("skill_deeds", 0)) + 1


static func _try_mark_flare(world: Dictionary) -> void:
	## Loud lure — farther bang than scrap toss; burns a Mark Flare from the bag.
	var player: Dictionary = world["player"]
	if float(player.get("flare_cooldown", 0.0)) > 0.0:
		return
	if float(player.get("heal_channel", 0.0)) > 0.0 or float(player.get("reload_channel", 0.0)) > 0.0 \
			or float(player.get("loot_channel", 0.0)) > 0.0:
		_set_message(world, "Can't throw while channeling.")
		return
	if Items.count_in_stacks(world["inventory"], "mark_flare") <= 0:
		_set_message(world, "Need a Mark Flare in bag.")
		return
	if not Items.consume_from_stacks(world["inventory"], "mark_flare", 1):
		_set_message(world, "Need a Mark Flare in bag.")
		return
	_refresh_bag_cap(world)
	player["flare_cooldown"] = FLARE_COOLDOWN
	var aim: Vector2 = player.get("aim", Vector2.RIGHT)
	if aim.length_squared() < 1e-6:
		aim = Vector2.RIGHT
	else:
		aim = aim.normalized()
	var impact: Vector2 = player["pos"] + aim * FLARE_TOSS_RANGE
	impact.x = clampf(impact.x, 20.0, float(world["width"]) - 20.0)
	impact.y = clampf(impact.y, 20.0, float(world["height"]) - 20.0)
	_emit_noise(world, impact, HEAR_FLARE_RANGE, NOISE_TTL_FLARE)
	# Wake dormants in a wide ring — flare is meant to pull the compound.
	for roamer in world["roamers"]:
		if not bool(roamer["alive"]):
			continue
		var d: float = impact.distance_to(roamer["pos"])
		if d > HEAR_FLARE_RANGE:
			continue
		roamer["dormant"] = false
		roamer["alert_ttl"] = maxf(float(roamer.get("alert_ttl", 0.0)), 2.8)
		roamer["last_heard"] = impact
		roamer["last_seen"] = impact
		var st := String(roamer.get("ai_state", "patrol"))
		if st == "combat" or st == "rush" or st == "flank" or st == "retreat":
			continue
		roamer["ai_state"] = "investigate"
		roamer["search_ttl"] = maxf(float(roamer.get("search_ttl", 0.0)), 2.4)
	_set_message(world, "Flare lit — contacts pull toward the bang.", 2.2)
	_push_float(world, impact, "FLARE", Color("ff8a4a"), 1.3)
	world["skill_deeds"] = int(world.get("skill_deeds", 0)) + 1
	world["shake"] = maxf(float(world.get("shake", 0.0)), 4.0)


static func finalize_raid_result(world: Dictionary) -> Dictionary:
	var outcome: Variant = world["outcome"]
	if outcome == "extracted":
		var loot_value := Items.loot_influence_value(world["inventory"])
		var influence_gained := MetaSim.EXTRACT_INFLUENCE_BASE + int(floor(loot_value * 0.25))
		var loot_copy: Array = []
		for s in world["inventory"]:
			loot_copy.append({"def_id": s["def_id"], "qty": s["qty"]})
		return {
			"outcome": "extracted",
			"loot": loot_copy,
			"influence_gained": influence_gained,
			"skill_bonus": Skills.bonus_points_from_deeds(int(world.get("skill_deeds", 0))),
			"message": "Extracted with %d items (+%d influence)." % [Items.inventory_used(world["inventory"]), influence_gained],
		}
	if outcome == "died":
		var dropped: Array = []
		for s in world.get("dropped_loot", []):
			dropped.append({"def_id": s["def_id"], "qty": s["qty"]})
		var lost_n := Items.inventory_used(dropped)
		return {
			"outcome": "died",
			"loot": [],
			"dropped": dropped,
			"influence_gained": 0,
			"skill_bonus": 0,
			"message": "KIA — drop bag lost (%d items). Locker untouched." % lost_n,
		}
	return {
		"outcome": "aborted",
		"loot": [],
		"dropped": [],
		"influence_gained": 0,
		"skill_bonus": 0,
		"message": "Field aborted.",
	}


## Equipped gear + bag contents become a ransackable drop on the body (solo: documents the loss).
static func _build_player_drop_contents(world: Dictionary) -> Array:
	var contents: Array = []
	var loadout: Dictionary = world.get("loadout", {})
	for key in ["weapon_id", "armor_id", "bag_id"]:
		var id: Variant = loadout.get(key)
		if id == null or String(id).is_empty():
			continue
		Items.add_to_stash(contents, Items.stack_of(String(id), 1))
	for s in world.get("inventory", []):
		Items.add_to_stash(contents, {"def_id": String(s["def_id"]), "qty": int(s["qty"])})
	return contents


static func _spawn_player_drop_bag(world: Dictionary) -> void:
	if int(world.get("drop_bag_id", -1)) >= 0:
		return
	var player: Dictionary = world["player"]
	var contents := _build_player_drop_contents(world)
	var bag_id := _alloc_id(world)
	world["crates"].append({
		"id": bag_id,
		"pos": Vector2(player["pos"]),
		"radius": 16.0,
		"opened": false,
		"kind": "drop_bag",
		"contents": contents,
	})
	world["drop_bag_id"] = bag_id
	var dropped_copy: Array = []
	for s in contents:
		dropped_copy.append({"def_id": String(s["def_id"]), "qty": int(s["qty"])})
	world["dropped_loot"] = dropped_copy


static func refresh_inventory_cap(world: Dictionary) -> void:
	## Public: bag capacity after inventory changes (scenes must not call private helpers).
	_refresh_bag_cap(world)


static func _refresh_bag_cap(world: Dictionary) -> void:
	var loadout: Dictionary = world.get("loadout", {})
	var skills: Dictionary = world.get("skills", {})
	world["inventory_cap"] = Items.effective_raid_capacity(loadout, world["inventory"]) + Skills.bag_bonus(skills)


static func _refresh_armor_mitigation(player: Dictionary) -> void:
	var base := float(player.get("base_mitigation", 0.0))
	var armor_max := float(player.get("armor_max", 0.0))
	if armor_max <= 0.0 or base <= 0.0:
		player["mitigation"] = 0.0
		return
	var ratio := clampf(float(player.get("armor_hp", 0.0)) / armor_max, 0.0, 1.0)
	player["mitigation"] = base * ratio


static func _wear_armor(world: Dictionary, absorbed: float, base_mit: float) -> void:
	if absorbed <= 0.05 or base_mit <= 0.0:
		return
	var player: Dictionary = world["player"]
	var armor_max := float(player.get("armor_max", 0.0))
	if armor_max <= 0.0:
		return
	var before := float(player.get("armor_hp", 0.0))
	if before <= 0.0:
		return
	var after := maxf(0.0, before - absorbed)
	player["armor_hp"] = after
	_refresh_armor_mitigation(player)
	if before > 0.0 and after <= 0.0:
		_set_message(world, "Armor broken — no more mitigation.", 2.5)
		_push_float(world, player["pos"], "ARMOR BROKEN", Color("e85454"), 1.3)
	elif before > armor_max * 0.35 and after <= armor_max * 0.35:
		_set_message(world, "Armor cracking — mitigation falling.", 1.8)
		_push_float(world, player["pos"], "ARMOR CRACKED", Color("e6b35a"), 1.0)


static func _build_obstacles() -> Array:
	var obstacles: Array = []
	# Outer rubble rings + interior blocks for a larger compound feel.
	var seeds: Array = [
		Vector2(600, 400), Vector2(1400, 700), Vector2(2200, 500), Vector2(3200, 900),
		Vector2(4000, 600), Vector2(900, 1500), Vector2(1800, 1600), Vector2(2800, 1400),
		Vector2(3700, 1700), Vector2(700, 2400), Vector2(1600, 2500), Vector2(2500, 2300),
		Vector2(3400, 2500), Vector2(4200, 2200), Vector2(1200, 1100), Vector2(3000, 400),
		Vector2(450, 900), Vector2(2100, 2100), Vector2(3900, 1200), Vector2(500, 2800),
	]
	for s in seeds:
		var w := randf_range(60.0, 220.0)
		var h := randf_range(40.0, 180.0)
		if randf() < 0.45:
			w = randf_range(36.0, 70.0)
			h = randf_range(120.0, 280.0)
		obstacles.append({
			"x": clampf(s.x + randf_range(-80, 80), 40.0, MAP_W - w - 40.0),
			"y": clampf(s.y + randf_range(-80, 80), 40.0, MAP_H - h - 40.0),
			"w": w,
			"h": h,
		})
	# A few long walls / corridors.
	obstacles.append_array([
		{"x": 1100.0, "y": 200.0, "w": 40.0, "h": 700.0},
		{"x": 2500.0, "y": 900.0, "w": 800.0, "h": 40.0},
		{"x": 3300.0, "y": 1400.0, "w": 40.0, "h": 900.0},
		{"x": 800.0, "y": 2000.0, "w": 900.0, "h": 40.0},
	])
	# Breached corridor doors — closed by default, E toggles.
	obstacles.append_array([
		{"x": 1100.0, "y": 900.0, "w": 40.0, "h": 70.0, "kind": "door", "open": false, "id": -101},
		{"x": 2460.0, "y": 900.0, "w": 70.0, "h": 40.0, "kind": "door", "open": false, "id": -102},
		{"x": 3300.0, "y": 2300.0, "w": 40.0, "h": 70.0, "kind": "door", "open": false, "id": -103},
		{"x": 1200.0, "y": 2000.0, "w": 70.0, "h": 40.0, "kind": "door", "open": false, "id": -104},
		{"x": 2800.0, "y": 1400.0, "w": 40.0, "h": 70.0, "kind": "door", "open": false, "id": -105},
	])
	return obstacles


static func _obstacle_blocks(o: Dictionary) -> bool:
	# Open doors are passable slabs — still drawn, no collision/LOS.
	if String(o.get("kind", "")) == "door" and bool(o.get("open", false)):
		return false
	return true


static func _rand_clear_pos(obstacles: Array, radius: float, margin: float) -> Vector2:
	for _try in 40:
		var p := Vector2(
			randf_range(margin, MAP_W - margin),
			randf_range(margin, MAP_H - margin)
		)
		if _place_away_from(obstacles, p.x, p.y, radius):
			return p
	return Vector2(MAP_W * 0.5, MAP_H * 0.5)


static func _alloc_id(world: Dictionary) -> int:
	var id := int(world["next_id"])
	world["next_id"] = id + 1
	return id


static func _make_actor(world: Dictionary, kind: String, pos: Vector2, extras: Dictionary) -> Dictionary:
	return {
		"id": _alloc_id(world),
		"kind": kind,
		"pos": pos,
		"vel": Vector2.ZERO,
		"melee_slow_ttl": 0.0,
		"melee_root_pos": pos,
		"hp": float(extras.get("hp", 100.0)),
		"max_hp": float(extras.get("max_hp", 100.0)),
		"radius": float(extras.get("radius", 14.0)),
		"facing": 0.0,
		"alive": true,
		"fire_cooldown": 0.0,
		"aim": Vector2.RIGHT,
		"aggro_range": float(extras.get("aggro_range", 220.0)),
		"speed": float(extras.get("speed", 140.0)),
		"damage": float(extras.get("damage", 10.0)),
		"mitigation": float(extras.get("mitigation", 0.0)),
		"hit_flash": 0.0,
		"vision_range": float(extras.get("vision_range", VISION_RANGE)),
	}


static func _place_away_from(obstacles: Array, x: float, y: float, r: float) -> bool:
	for o in obstacles:
		if not _obstacle_blocks(o):
			continue
		var cx := clampf(x, float(o["x"]), float(o["x"]) + float(o["w"]))
		var cy := clampf(y, float(o["y"]), float(o["y"]) + float(o["h"]))
		if (cx - x) * (cx - x) + (cy - y) * (cy - y) <= r * r:
			return false
	return true


static func _resolve_circle_rect(pos: Vector2, radius: float, o: Dictionary) -> Vector2:
	var nearest := Vector2(
		clampf(pos.x, float(o["x"]), float(o["x"]) + float(o["w"])),
		clampf(pos.y, float(o["y"]), float(o["y"]) + float(o["h"]))
	)
	var delta := pos - nearest
	var d2 := delta.length_squared()
	if d2 >= radius * radius or d2 < 1e-8:
		if pos.x > float(o["x"]) and pos.x < float(o["x"]) + float(o["w"]) \
				and pos.y > float(o["y"]) and pos.y < float(o["y"]) + float(o["h"]):
			var left := pos.x - float(o["x"])
			var right := float(o["x"]) + float(o["w"]) - pos.x
			var top := pos.y - float(o["y"])
			var bottom := float(o["y"]) + float(o["h"]) - pos.y
			var m := mini(mini(left, right), mini(top, bottom))
			if m == left:
				return Vector2(float(o["x"]) - radius, pos.y)
			if m == right:
				return Vector2(float(o["x"]) + float(o["w"]) + radius, pos.y)
			if m == top:
				return Vector2(pos.x, float(o["y"]) - radius)
			return Vector2(pos.x, float(o["y"]) + float(o["h"]) + radius)
		return pos
	var d := sqrt(d2)
	return nearest + delta * (radius / d)


static func _collide_actor_obstacles(actor: Dictionary, obstacles: Array) -> void:
	for o in obstacles:
		if not _obstacle_blocks(o):
			continue
		actor["pos"] = _resolve_circle_rect(actor["pos"], float(actor["radius"]), o)


static func _clamp_to_map(actor: Dictionary, w: float, h: float) -> void:
	var r := float(actor["radius"])
	var p: Vector2 = actor["pos"]
	actor["pos"] = Vector2(clampf(p.x, r, w - r), clampf(p.y, r, h - r))


static func _spawn_bullet(world: Dictionary, from: Dictionary, aim: Vector2, from_player: bool, speed: float) -> void:
	# Hard gate — unarmed players never spawn projectiles (even if a caller slips).
	if from_player and not Items.loadout_has_weapon(world.get("loadout", {})):
		return
	var dir := aim.normalized()
	if dir.length_squared() < 1e-6:
		return
	world["bullets"].append({
		"id": _alloc_id(world),
		"pos": from["pos"] + dir * (float(from["radius"]) + 4.0),
		"vel": dir * speed,
		"damage": float(from["damage"]),
		"life": 1.6,
		"from_player": from_player,
		"radius": 3.5,
		"origin": from["pos"],
	})


static func _mark_threat_bearing(world: Dictionary, from_pos: Vector2) -> void:
	var player: Dictionary = world["player"]
	if not bool(player.get("alive", false)):
		return
	var delta: Vector2 = from_pos - (player["pos"] as Vector2)
	if delta.length_squared() < 1e-4:
		var vel_guess: Vector2 = world.get("threat_dir", Vector2.RIGHT)
		if vel_guess.length_squared() > 1e-6:
			return
		delta = Vector2.RIGHT
	world["threat_dir"] = delta.normalized()
	world["threat_ttl"] = THREAT_BEARING_TTL


static func _tick_raid_dusk(world: Dictionary) -> void:
	var t := float(world.get("time_alive", 0.0))
	var dusk := 0.0
	if t > RAID_DUSK_START:
		dusk = clampf((t - RAID_DUSK_START) / maxf(1.0, RAID_DUSK_FULL - RAID_DUSK_START), 0.0, 1.0)
	world["dusk_01"] = dusk
	var player: Dictionary = world.get("player", {})
	if player.is_empty():
		return
	var vision := VISION_RANGE * lerpf(1.0, DUSK_VISION_MIN, dusk)
	# Limp tunnel — critical HP narrows awareness; adrenaline briefly punches it open.
	var hp_ratio := float(player.get("hp", 1.0)) / maxf(1.0, float(player.get("max_hp", 1.0)))
	if hp_ratio <= WOUNDED_HP_RATIO:
		if float(player.get("adrenaline_ttl", 0.0)) > 0.0:
			vision *= ADRENALINE_VISION_MULT
		else:
			vision *= WOUNDED_VISION_MULT
	player["vision_range"] = vision
	# Roamers hear a bit farther as the compound quiets — pressure without new HUD chrome.
	var hear_boost := lerpf(1.0, DUSK_HEAR_MAX, dusk)
	world["dusk_hear_mult"] = hear_boost
	if dusk > 0.02 and not bool(world.get("dusk_warned", false)):
		world["dusk_warned"] = true
		_set_message(world, "Light failing — vision thinning. Push for a lift.", 3.2)


static func _effective_extract_alarm(world: Dictionary, zone: Dictionary) -> float:
	var base := float(zone.get("alarm_radius", EXTRACT_ALARM_RADIUS))
	var dusk := float(world.get("dusk_01", 0.0))
	var radius := base
	if dusk > 0.0:
		var pressure := String(zone.get("pressure", "contested"))
		var mult := 1.0
		if pressure == "quiet":
			mult = lerpf(1.0, DUSK_QUIET_ALARM_MULT, dusk)
		elif pressure == "contested":
			mult = lerpf(1.0, DUSK_CONTESTED_ALARM_MULT, dusk)
		# Hot already screams — dusk doesn't need to stack more.
		radius = base * mult
	var player: Dictionary = world.get("player", {})
	# Low profile on the pad — crouched holds keep the flare from painting the whole map.
	if bool(player.get("crouching", false)) and not bool(player.get("sprinting", false)):
		radius *= CROUCH_EXTRACT_ALARM_MULT
	return radius


static func _effective_extract_contest_pad(world: Dictionary, zone: Dictionary) -> float:
	var pad := float(zone.get("contest_pad", 0.12))
	var dusk := float(world.get("dusk_01", 0.0))
	if dusk <= 0.0:
		return pad
	if String(zone.get("pressure", "")) == "quiet":
		pad += DUSK_QUIET_PAD_ADD * dusk
	return pad


static func _set_message(world: Dictionary, msg: String, ttl: float = 2.5) -> void:
	world["message"] = msg
	world["message_ttl"] = ttl


static func _push_float(world: Dictionary, pos: Vector2, text: String, color: Color, life: float = 1.1) -> void:
	world["floats"].append({
		"id": _alloc_id(world),
		"pos": Vector2(pos.x, pos.y - 18.0),
		"text": text,
		"color": color,
		"life": life,
		"max_life": life,
		"vy": -36.0,
	})


static func _update_floats(world: Dictionary, dt: float) -> void:
	var next: Array = []
	for f in world["floats"]:
		f["life"] = float(f["life"]) - dt
		if float(f["life"]) <= 0.0:
			continue
		f["pos"] = Vector2(f["pos"].x, f["pos"].y + float(f["vy"]) * dt)
		next.append(f)
	world["floats"] = next


static func _refresh_interact_hint(world: Dictionary) -> void:
	var player: Dictionary = world["player"]
	if not bool(player["alive"]) or bool(world["over"]):
		world["interact_hint"] = null
		return
	if float(player.get("loot_channel", 0.0)) > 0.0:
		var max_c := maxf(0.2, float(player.get("loot_channel_max", 1.0)))
		var left := float(player["loot_channel"])
		var pct := int(floor((1.0 - left / max_c) * 100.0))
		world["interact_hint"] = "RANSACK  %d%%" % pct
		return
	for z in world["extracts"]:
		if not bool(z["active"]):
			continue
		if player["pos"].distance_to(z["pos"]) <= float(z["radius"]):
			var pct := mini(1.0, float(world.get("extract_progress_01", float(z["progress"]) / float(z["hold_seconds"]))))
			var contest := int(world.get("extract_contest_count", 0))
			if contest > 0:
				world["interact_hint"] = "CONTESTED  %d%%" % int(floor(pct * 100.0))
			else:
				world["interact_hint"] = "OUT  %d%%" % int(floor(pct * 100.0))
			return
	var nearest: Variant = null
	var best := INF
	var nearest_kind := "crate"
	for c in world["crates"]:
		if bool(c["opened"]):
			continue
		var d: float = player["pos"].distance_to(c["pos"])
		if d <= float(c["radius"]) + float(player["radius"]) + 18.0 and d < best:
			best = d
			nearest = c
			nearest_kind = String(c.get("kind", "crate"))
	if nearest != null:
		match nearest_kind:
			"corpse":
				world["interact_hint"] = "E  strip"
			"drop_bag":
				world["interact_hint"] = "E  grab"
			"weapon_case":
				world["interact_hint"] = "E  crack"
			"intel_safe":
				world["interact_hint"] = "E  pick"
			"med_cache", "ammo_crate":
				world["interact_hint"] = "E  open"
			_:
				world["interact_hint"] = "E  pry"
		return
	var door = _find_door_target(world)
	if door != null:
		world["interact_hint"] = "E  open" if not bool(door.get("open", false)) else "E  shut"
		return
	world["interact_hint"] = null
	if Items.has_better_gear_in_inventory(world["loadout"], world["inventory"]):
		world["interact_hint"] = "F  equip"
		return
	if float(player.get("heal_channel", 0.0)) > 0.0:
		world["interact_hint"] = "HEAL  %.1fs" % float(player["heal_channel"])
		return
	if float(player.get("reload_channel", 0.0)) > 0.0:
		world["interact_hint"] = "RELOAD  %.1fs" % float(player["reload_channel"])
		return
	if not bool(player.get("armed", true)):
		world["interact_hint"] = "LMB  punch"
		return
	if int(player.get("mag", 0)) <= 0 and int(player.get("reserve", 0)) > 0:
		world["interact_hint"] = "R  reload"
		return
	if int(player.get("mag", 0)) <= 0 and int(player.get("reserve", 0)) <= 0:
		if Items.count_in_stacks(world["inventory"], "ammo_box") > 0:
			world["interact_hint"] = "R  pack ammo"
		else:
			world["interact_hint"] = "NO AMMO"
		return
	if int(player.get("mag", 0)) >= int(player.get("mag_size", 0)) \
			and Items.count_in_stacks(world["inventory"], "ammo_box") > 0:
		world["interact_hint"] = "R  pack ammo"
		return


static func _update_roamers(world: Dictionary, dt: float) -> void:
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
	var active_alarm_radius := EXTRACT_ALARM_RADIUS
	if alarm:
		for z in world["extracts"]:
			if int(z["id"]) == int(world.get("active_extract_id", -1)):
				active_alarm_radius = _effective_extract_alarm(world, z)
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
		if _roamer_melee_rooted(roamer) and roamer.has("melee_root_pos"):
			roamer["pos"] = roamer["melee_root_pos"]
		roamer["fire_cooldown"] = maxf(0.0, float(roamer["fire_cooldown"]) - dt)
		var to_player: Vector2 = player["pos"] - roamer["pos"]
		var d := to_player.length()
		var sees_player := bool(player["alive"]) and d < float(roamer["aggro_range"]) \
				and has_line_of_sight(roamer["pos"], player["pos"], world["obstacles"])

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
			var scent: Variant = _nearest_blood(world, roamer["pos"], BLOOD_SCENT_RANGE)
			if scent != null:
				scent_pull = true
				roamer["alert_ttl"] = maxf(float(roamer.get("alert_ttl", 0.0)), 1.8)
				roamer["last_heard"] = scent

		# Spot call — first contact shouts so nearby allies push your last known.
		if sees_player and float(roamer.get("call_cooldown", 0.0)) <= 0.0:
			_roamer_alert_call(world, roamer, player["pos"])
			roamer["call_cooldown"] = ALERT_CALL_COOLDOWN

		# Hurt enforcer — one distress blast that wakes dormants across a wide ring.
		if bool(roamer.get("elite", false)) and not bool(roamer.get("distress_fired", false)):
			var hp_ratio := float(roamer["hp"]) / maxf(1.0, float(roamer.get("max_hp", roamer["hp"])))
			if hp_ratio <= ENFORCER_DISTRESS_HP:
				_enforcer_distress_call(world, roamer, player["pos"] if bool(player["alive"]) else roamer["pos"])
				roamer["distress_fired"] = true

		var near_extract_rush := false
		if alarm and bool(player["alive"]):
			var to_ex: Vector2 = extract_pos - (roamer["pos"] as Vector2)
			near_extract_rush = to_ex.length() <= active_alarm_radius

		# Wake dormant roamers on gunshots / sprint / extract flare — not soft walks.
		if bool(roamer.get("dormant", false)):
			var wake := (hears and noise_radius >= HEAR_SPRINT_RANGE * 0.9) or sees_player or near_extract_rush
			if wake:
				roamer["dormant"] = false
				roamer["aggro_range"] = maxf(float(roamer["aggro_range"]), randf_range(200.0, 320.0))
			else:
				roamer["ai_state"] = "dormant"
				_collide_actor_obstacles(roamer, world["obstacles"])
				_clamp_to_map(roamer, float(world["width"]), float(world["height"]))
				if _roamer_melee_rooted(roamer) and roamer.has("melee_root_pos"):
					roamer["pos"] = roamer["melee_root_pos"]
				_tick_roamer_melee_slow(roamer, dt)
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
			if not _roamer_melee_rooted(roamer):
				if d > 85.0:
					roamer["pos"] = roamer["pos"] + (roamer["aim"] as Vector2) * _roamer_speed(roamer) * 1.35 * dt
				elif d < 55.0:
					roamer["pos"] = roamer["pos"] - (roamer["aim"] as Vector2) * _roamer_speed(roamer) * 0.35 * dt
			# Rush fire needs LOS — close range alone must not shoot through walls.
			if float(roamer["fire_cooldown"]) <= 0.0 and sees_player:
				var rdir := (roamer["aim"] as Vector2).rotated(randf_range(-_roamer_shot_spread(roamer), _roamer_shot_spread(roamer)))
				_spawn_bullet(world, roamer, rdir, false, 460.0)
				roamer["fire_cooldown"] = randf_range(0.28, 0.55)

		if not rushing:
			_roamer_pick_state(world, roamer, sees_player, hears or scent_pull, bool(player["alive"]))
			# Idle contacts strip unlooted bodies — don't leave free kits on the ground.
			if String(roamer.get("ai_state", "")) in ["patrol", "search", "forage"]:
				_roamer_try_start_forage(world, roamer)
			match String(roamer.get("ai_state", "patrol")):
				"combat":
					_roamer_do_combat(world, roamer, player, to_player, d, dt)
				"flank":
					_roamer_do_flank(world, roamer, player, to_player, d, dt)
				"retreat":
					_roamer_do_retreat(world, roamer, player, to_player, d, dt)
				"forage":
					_roamer_do_forage(world, roamer, dt)
				"investigate":
					# Always chase last_heard (noise + scent write it); never fall back to stale noise_pos.
					_roamer_do_investigate(world, roamer, roamer.get("last_heard", player["pos"]), dt)
				"search":
					_roamer_do_search(world, roamer, dt)
				"dormant":
					pass
				_:
					_roamer_do_patrol(world, roamer, dt)

		_collide_actor_obstacles(roamer, world["obstacles"])
		_clamp_to_map(roamer, float(world["width"]), float(world["height"]))
		# Hard pin while punch-rooted — AI/collision must not slide them away.
		if _roamer_melee_rooted(roamer) and roamer.has("melee_root_pos"):
			roamer["pos"] = roamer["melee_root_pos"]
		# Expire slow after the pin so the last rooted frame isn't a surprise backpedal.
		_tick_roamer_melee_slow(roamer, dt)
	world["extract_contest_count"] = contest_count


static func _roamer_speed(roamer: Dictionary) -> float:
	var spd := float(roamer.get("speed", 0.0))
	if float(roamer.get("melee_slow_ttl", 0.0)) > 0.0:
		spd *= MELEE_SLOW_MULT
	return spd


static func _tick_roamer_melee_slow(roamer: Dictionary, dt: float) -> void:
	var ttl := float(roamer.get("melee_slow_ttl", 0.0))
	if ttl <= 0.0:
		roamer["melee_slow_ttl"] = 0.0
		return
	roamer["melee_slow_ttl"] = maxf(0.0, ttl - dt)


static func _roamer_pick_state(world: Dictionary, roamer: Dictionary, sees_player: bool, hears: bool, player_alive: bool) -> void:
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
				_push_float(world, roamer["pos"] + Vector2(0, -24), "ENFORCER", Color("c9a0ff"), 1.2)
				_set_message(world, "Enforcer locked on — heavy fire.", 2.0)
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


static func _roamer_should_flank(world: Dictionary, roamer: Dictionary) -> bool:
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


static func _roamer_melee_rooted(roamer: Dictionary) -> bool:
	## Contact stun-slow — no backpedal/separation while hobbled (that read as a teleport shove).
	return float(roamer.get("melee_slow_ttl", 0.0)) > 0.0


static func _roamer_do_combat(world: Dictionary, roamer: Dictionary, player: Dictionary, to_player: Vector2, d: float, dt: float) -> void:
	if _roamer_should_flank(world, roamer) and not _roamer_melee_rooted(roamer):
		roamer["ai_state"] = "flank"
		_roamer_do_flank(world, roamer, player, to_player, d, dt)
		return
	roamer["ai_state"] = "combat"
	roamer["last_seen"] = player["pos"]
	roamer["aim"] = to_player.normalized() if d > 1e-6 else Vector2.RIGHT
	# While punch-slowed: feet planted — aim/fire only, no range pocket shuffle.
	if _roamer_melee_rooted(roamer):
		pass
	elif d > ROAMER_COMBAT_HOLD_RANGE:
		roamer["pos"] = roamer["pos"] + roamer["aim"] * _roamer_speed(roamer) * dt
	elif d < ROAMER_COMBAT_BACK_RANGE:
		roamer["pos"] = roamer["pos"] - roamer["aim"] * _roamer_speed(roamer) * 0.55 * dt
	else:
		var side := (roamer["aim"] as Vector2).orthogonal().normalized()
		if int(roamer["id"]) % 2 == 0:
			side = -side
		roamer["pos"] = roamer["pos"] + side * _roamer_speed(roamer) * 0.45 * dt
	if float(roamer["fire_cooldown"]) <= 0.0:
		var sdir := (roamer["aim"] as Vector2).rotated(randf_range(-_roamer_shot_spread(roamer), _roamer_shot_spread(roamer)))
		var shot_speed := 480.0 if bool(roamer.get("elite", false)) else 420.0
		_spawn_bullet(world, roamer, sdir, false, shot_speed)
		var gap := randf_range(0.5, 0.95) * float(roamer.get("fire_gap_mult", 1.0))
		roamer["fire_cooldown"] = gap


static func _roamer_do_flank(world: Dictionary, roamer: Dictionary, player: Dictionary, to_player: Vector2, d: float, dt: float) -> void:
	roamer["last_seen"] = player["pos"]
	roamer["aim"] = to_player.normalized() if d > 1e-6 else Vector2.RIGHT
	if not _roamer_melee_rooted(roamer):
		var side := (roamer["aim"] as Vector2).orthogonal().normalized()
		if int(roamer["id"]) % 2 == 0:
			side = -side
		var anchor: Vector2 = player["pos"] + side * ROAMER_FLANK_RANGE
		var to_anchor: Vector2 = anchor - (roamer["pos"] as Vector2)
		if to_anchor.length() > 12.0:
			roamer["pos"] = roamer["pos"] + to_anchor.normalized() * _roamer_speed(roamer) * ROAMER_FLANK_SPEED * dt
	if float(roamer["fire_cooldown"]) <= 0.0 and d < ROAMER_FLANK_RANGE * 1.35:
		var sdir := (roamer["aim"] as Vector2).rotated(randf_range(-_roamer_shot_spread(roamer), _roamer_shot_spread(roamer)))
		_spawn_bullet(world, roamer, sdir, false, 430.0)
		roamer["fire_cooldown"] = randf_range(0.55, 0.95) * float(roamer.get("fire_gap_mult", 1.0))


static func _roamer_do_retreat(world: Dictionary, roamer: Dictionary, player: Dictionary, to_player: Vector2, d: float, dt: float) -> void:
	roamer["last_seen"] = player["pos"]
	roamer["aim"] = to_player.normalized() if d > 1e-6 else Vector2.RIGHT
	# Break contact — open range hard, then sidestep while keeping eyes on you.
	# Punch-slow roots feet so a hit never looks like a teleport shove away.
	if not _roamer_melee_rooted(roamer):
		var away := -(roamer["aim"] as Vector2)
		if d < ROAMER_RETREAT_RANGE:
			roamer["pos"] = roamer["pos"] + away * _roamer_speed(roamer) * ROAMER_RETREAT_SPEED * dt
		else:
			var side := (roamer["aim"] as Vector2).orthogonal().normalized()
			if int(roamer["id"]) % 2 == 0:
				side = -side
			roamer["pos"] = roamer["pos"] + (away * 0.35 + side * 0.65) * _roamer_speed(roamer) * dt
	if float(roamer["fire_cooldown"]) <= 0.0 and d < ROAMER_RETREAT_RANGE * 1.15:
		var sdir := (roamer["aim"] as Vector2).rotated(randf_range(-_roamer_shot_spread(roamer) - 0.08, _roamer_shot_spread(roamer) + 0.08))
		_spawn_bullet(world, roamer, sdir, false, 400.0)
		roamer["fire_cooldown"] = randf_range(0.85, 1.25) * ROAMER_RETREAT_FIRE_GAP


static func _roamer_find_forage_target(world: Dictionary, roamer: Dictionary) -> Variant:
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


static func _roamer_try_start_forage(world: Dictionary, roamer: Dictionary) -> void:
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
	var target: Variant = _roamer_find_forage_target(world, roamer)
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


static func _roamer_do_forage(world: Dictionary, roamer: Dictionary, dt: float) -> void:
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
		roamer["pos"] = roamer["pos"] + roamer["aim"] * _roamer_speed(roamer) * 0.85 * dt
		return
	roamer["forage_ttl"] = float(roamer.get("forage_ttl", 0.0)) + dt
	if float(roamer["forage_ttl"]) < ROAMER_FORAGE_TIME:
		return
	target["opened"] = true
	target["contents"] = []
	roamer["forage_ttl"] = 0.0
	roamer["forage_target_id"] = -1
	roamer["ai_state"] = "patrol"
	_push_float(world, target["pos"] + Vector2(0, -12), "STRIPPED", Color("c4785c"), 1.0)
	_set_message(world, "Roamer stripped a body — loot's gone.", 2.0)


static func _roamer_do_investigate(world: Dictionary, roamer: Dictionary, target: Vector2, dt: float) -> void:
	var to_noise: Vector2 = target - roamer["pos"]
	var nd := to_noise.length()
	if nd > 28.0:
		roamer["aim"] = to_noise.normalized()
		roamer["pos"] = roamer["pos"] + roamer["aim"] * _roamer_speed(roamer) * 1.05 * dt
	else:
		# Arrive: pause and scan — keeps search from instantly flipping to idle.
		roamer["alert_ttl"] = maxf(float(roamer.get("alert_ttl", 0.0)), 0.6)
		roamer["ai_state"] = "search"
		roamer["search_ttl"] = maxf(float(roamer.get("search_ttl", 0.0)), 1.4)
		roamer["last_seen"] = target


static func _roamer_do_search(world: Dictionary, roamer: Dictionary, dt: float) -> void:
	var focus: Vector2 = roamer.get("last_seen", roamer.get("last_heard", roamer["pos"]))
	var phase := float(world["time_alive"]) * 1.7 + float(roamer["id"]) * 0.9
	var orbit := Vector2(cos(phase), sin(phase)) * 42.0
	var target := focus + orbit
	var to_t: Vector2 = target - roamer["pos"]
	if to_t.length() > 8.0:
		roamer["aim"] = to_t.normalized()
		roamer["pos"] = roamer["pos"] + roamer["aim"] * _roamer_speed(roamer) * 0.7 * dt


static func _roamer_do_patrol(_world: Dictionary, roamer: Dictionary, dt: float) -> void:
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
		roamer["pos"] = roamer["pos"] + roamer["aim"] * _roamer_speed(roamer) * (0.55 if bool(roamer.get("elite", false)) else 0.45) * dt


static func _bullet_hits_obstacle(p: Vector2, obstacles: Array) -> bool:
	for o in obstacles:
		if not _obstacle_blocks(o):
			continue
		if p.x >= float(o["x"]) and p.x <= float(o["x"]) + float(o["w"]) \
				and p.y >= float(o["y"]) and p.y <= float(o["y"]) + float(o["h"]):
			return true
	return false


static func _kill_roamer_from_bullet(world: Dictionary, roamer: Dictionary) -> void:
	roamer["alive"] = false
	var elite := bool(roamer.get("elite", false))
	world["crates"].append({
		"id": _alloc_id(world),
		"pos": roamer["pos"],
		"radius": 15.0 if elite else 14.0,
		"opened": false,
		"kind": "corpse",
		"elite": elite,
		"contents": Items.roll_enforcer_loot() if elite else Items.roll_roamer_loot(),
	})
	if elite:
		_set_message(world, "Enforcer down — rich body (E).")
		_push_float(world, roamer["pos"], "ENFORCER DOWN", Color("c9a0ff"), 1.4)
		world["skill_deeds"] = int(world.get("skill_deeds", 0)) + 4
	else:
		_set_message(world, "Roamer down — loot the body (E).")
		_push_float(world, roamer["pos"], "ROAMER DOWN", Color("e6b35a"), 1.2)
		world["skill_deeds"] = int(world.get("skill_deeds", 0)) + 2


static func _update_bullets(world: Dictionary, dt: float) -> void:
	var next: Array = []
	var map_w := float(world["width"])
	var map_h := float(world["height"])
	# Substep like LOS (12px) so fast rounds don't tunnel walls at low FPS.
	const BULLET_STEP_PX := 12.0
	for b in world["bullets"]:
		b["life"] = float(b["life"]) - dt
		if float(b["life"]) <= 0.0:
			continue
		var travel: Vector2 = b["vel"] * dt
		var travel_len := travel.length()
		var steps := 1
		if travel_len > BULLET_STEP_PX:
			steps = int(ceil(travel_len / BULLET_STEP_PX))
		var step_delta := travel / float(steps)
		var consumed := false
		for _s in steps:
			b["pos"] = b["pos"] + step_delta
			var p: Vector2 = b["pos"]
			if p.x < 0.0 or p.y < 0.0 or p.x > map_w or p.y > map_h:
				consumed = true
				break
			if _bullet_hits_obstacle(p, world["obstacles"]):
				consumed = true
				break

			if bool(b["from_player"]):
				var hit := false
				var suppressed: Dictionary = b.get("roamer_suppress_ids", {})
				for roamer in world["roamers"]:
					if not bool(roamer["alive"]):
						continue
					var dist_r: float = p.distance_to(roamer["pos"])
					var rid := int(roamer["id"])
					# Near-miss whip — pin their trigger even if the round doesn't connect.
					if not bool(suppressed.get(rid, false)) and dist_r <= ROAMER_SUPPRESS_NEAR:
						_apply_roamer_suppression(roamer, ROAMER_SUPPRESS_GAP)
						suppressed[rid] = true
						b["roamer_suppress_ids"] = suppressed
					if dist_r <= float(roamer["radius"]) + float(b["radius"]):
						var dmg := float(b["damage"]) * (1.0 - float(roamer["mitigation"]))
						roamer["hp"] = float(roamer["hp"]) - dmg
						roamer["hit_flash"] = 0.12
						_apply_roamer_suppression(roamer, ROAMER_SUPPRESS_HIT_GAP, ROAMER_SUPPRESS_TTL * 1.15)
						_push_float(world, roamer["pos"], "-%d" % int(ceil(dmg)), Color("ffd0d0"), 0.55)
						if float(roamer["hp"]) <= 0.0:
							_kill_roamer_from_bullet(world, roamer)
						hit = true
						break
				if hit:
					consumed = true
					break
			elif bool(world["player"]["alive"]):
				var pl: Dictionary = world["player"]
				var dist_pl: float = p.distance_to(pl["pos"])
				# Near-miss whip — open the cone even if the round doesn't connect.
				if not bool(b.get("suppress_applied", false)) and dist_pl <= SUPPRESS_NEAR:
					_apply_suppression(world, pl, SUPPRESS_BLOOM)
					_mark_threat_bearing(world, b.get("origin", p))
					# Near-miss whip also knocks the plant — settle isn't free under fire.
					pl["brace_hold"] = 0.0
					b["suppress_applied"] = true
				if dist_pl <= float(pl["radius"]) + float(b["radius"]):
					var base_mit := float(pl.get("base_mitigation", pl.get("mitigation", 0.0)))
					var mit := float(pl.get("mitigation", 0.0))
					var incoming := float(b["damage"])
					var absorbed := incoming * mit
					var pdmg := incoming - absorbed
					pl["hp"] = float(pl["hp"]) - pdmg
					pl["hit_flash"] = 0.15
					world["shake"] = maxf(float(world["shake"]), 6.0)
					_apply_suppression(world, pl, SUPPRESS_HIT_BLOOM, 0.75)
					_mark_threat_bearing(world, b.get("origin", p))
					# Hits break a settled plant — reacquire before the cone tightens again.
					pl["brace_hold"] = 0.0
					_push_float(world, pl["pos"], "-%d" % int(ceil(pdmg)), Color("e85454"), 0.7)
					_wear_armor(world, absorbed, base_mit)
					_interrupt_medkit(world, "Medkit interrupted — took fire.")
					_interrupt_reload(world)
					_interrupt_loot(world, "Ransack interrupted — took fire.")
					# Holding extract under fire bleeds the timer — leave or finish under pressure.
					if bool(world.get("extract_alarm", false)):
						var bleed_mult := 1.0
						for z in world["extracts"]:
							if int(z["id"]) == int(world.get("active_extract_id", -1)):
								bleed_mult = float(z.get("bleed_mult", 1.0))
								break
						world["extract_damage_bleed"] = float(world.get("extract_damage_bleed", 0.0)) + pdmg * EXTRACT_DAMAGE_PROGRESS_BLEED * bleed_mult
					if float(pl["hp"]) <= 0.0:
						pl["alive"] = false
						pl["hp"] = 0.0
						world["over"] = true
						world["outcome"] = "died"
						world["shake"] = 14.0
						_spawn_player_drop_bag(world)
						var lost := Items.inventory_used(world.get("dropped_loot", []))
						_set_message(world, "KIA — drop bag left behind (%d items). Stash is safe." % lost, 6.0)
						_push_float(world, pl["pos"], "DROP BAG", Color("e6b35a"), 2.0)
						_push_float(world, pl["pos"] + Vector2(0, -14), "YOU DIED", Color("e85454"), 2.2)
					consumed = true
					break
		if not consumed:
			next.append(b)
	world["bullets"] = next


static func _update_extracts(world: Dictionary, dt: float) -> void:
	var player: Dictionary = world["player"]
	if not bool(player["alive"]) or bool(world["over"]):
		world["extract_alarm"] = false
		world["extract_progress_01"] = 0.0
		return
	var in_zone: Variant = null
	for z in world["extracts"]:
		if not bool(z["active"]):
			continue
		if player["pos"].distance_to(z["pos"]) <= float(z["radius"]):
			in_zone = z
			break
	for z in world["extracts"]:
		if z != in_zone:
			z["progress"] = maxf(0.0, float(z["progress"]) - dt * 0.85)
	if in_zone == null:
		# Lit pad then peel — the flare already sang; leaving mid-hold still rings.
		if bool(world.get("extract_alarm", false)) \
				and float(world.get("extract_progress_01", 0.0)) >= EXTRACT_ABANDON_MIN_PROGRESS:
			var abandon_r := HEAR_EXTRACT_ABANDON_RANGE
			# Limp peel — critical HP telegraphs the break flare farther.
			var hp_ratio_a := float(player.get("hp", 1.0)) / maxf(1.0, float(player.get("max_hp", 1.0)))
			if hp_ratio_a <= WOUNDED_HP_RATIO:
				abandon_r *= WOUNDED_EXTRACT_ABANDON_HEAR_MULT
			# Greedy pack — stuffing the bag also rattles the break flare.
			var used_a := float(Items.inventory_used(world["inventory"]))
			var cap_a := maxf(1.0, float(world["inventory_cap"]))
			if used_a / cap_a >= HEAVY_BAG_RATIO or bool(player.get("heavy_bag", false)):
				abandon_r *= HEAVY_BAG_EXTRACT_ABANDON_HEAR_MULT
			_emit_noise(world, player["pos"], abandon_r, NOISE_TTL_EXTRACT_ABANDON)
			# Peel costs composure — no free cheese leave after the flare lit.
			player["stamina"] = maxf(0.0, float(player.get("stamina", 0.0)) - EXTRACT_ABANDON_STAMINA)
			player["stumble_ttl"] = maxf(float(player.get("stumble_ttl", 0.0)), EXTRACT_ABANDON_STUMBLE)
			_push_float(world, player["pos"] + Vector2(0, -18), "BREAK", Color("e6b35a"), 0.9)
			_set_message(world, "Extract broken — flare still ringing.", 2.0)
		world["extract_alarm"] = false
		world["active_extract_id"] = -1
		world["extract_progress_01"] = 0.0
		world["extract_damage_bleed"] = 0.0
		world["extract_reinforce_ttl"] = 0.0
		world["extract_reinforce_pending"] = 0
		world["extract_reinforce_done"] = false
		return

	# First tick in zone: flare the extract — nearby roamers begin the contest.
	if not bool(world["extract_alarm"]) or int(world["active_extract_id"]) != int(in_zone["id"]):
		world["extract_alarm"] = true
		world["active_extract_id"] = int(in_zone["id"])
		world["extract_damage_bleed"] = 0.0
		world["extract_reinforce_done"] = false
		var pressure := String(in_zone.get("pressure", "contested"))
		var flare_msg := "EXIT FLARED — contacts rushing the lift. Hold or leave."
		var flare_col := Color("e6b35a")
		var reinforce_n := 0
		var reinforce_delay := 0.0
		match pressure:
			"hot":
				flare_msg = "HOT LIFT — wide flare, short hold. Expect a pile-on."
				flare_col = Color("e85454")
				reinforce_n = REINFORCE_COUNT_HOT
				reinforce_delay = REINFORCE_DELAY_HOT
			"quiet":
				flare_msg = "QUIET LIFT — long hold, small flare. Stay still."
				flare_col = Color("7fd0ff")
				reinforce_n = 0
				reinforce_delay = 0.0
			_:
				flare_msg = "EXIT FLARED — contacts rushing the lift. Hold or leave."
				reinforce_n = REINFORCE_COUNT_CONTESTED
				reinforce_delay = REINFORCE_DELAY_CONTESTED
		world["extract_reinforce_pending"] = reinforce_n
		world["extract_reinforce_ttl"] = reinforce_delay
		_set_message(world, flare_msg, 3.5)
		_push_float(world, player["pos"], String(in_zone.get("pressure", "extract")).to_upper(), flare_col, 1.4)

	# Late wave from the perimeter — hot exits hit hardest; quiet skips.
	if not bool(world.get("extract_reinforce_done", false)) and int(world.get("extract_reinforce_pending", 0)) > 0:
		world["extract_reinforce_ttl"] = float(world.get("extract_reinforce_ttl", 0.0)) - dt
		if float(world["extract_reinforce_ttl"]) <= 0.0:
			_spawn_extract_reinforcements(world, in_zone, int(world["extract_reinforce_pending"]))
			world["extract_reinforce_done"] = true
			world["extract_reinforce_pending"] = 0
			_set_message(world, "Reinforcements inbound — finish or break off.", 2.2)
			_push_float(world, in_zone["pos"], "INBOUND", Color("e85454"), 1.3)

	var bleed := float(world.get("extract_damage_bleed", 0.0))
	if bleed > 0.0:
		var applied := mini(bleed, dt * 2.5)
		in_zone["progress"] = maxf(0.0, float(in_zone["progress"]) - applied)
		world["extract_damage_bleed"] = bleed - applied

	in_zone["progress"] = float(in_zone["progress"]) + dt
	var hold := float(in_zone["hold_seconds"])
	# Contested roamers stretch the timer — pad scales with the exit's pressure profile.
	var contest := int(world.get("extract_contest_count", 0))
	if contest > 0:
		var pad := _effective_extract_contest_pad(world, in_zone)
		hold += mini(1.8, contest * pad)
	# Quiet sits reward composure — slight stamina drip while uncontested.
	if String(in_zone.get("pressure", "")) == "quiet" and contest == 0:
		player["stamina"] = minf(
			float(player.get("stamina_max", STAMINA_MAX)),
			float(player.get("stamina", 0.0)) + STAMINA_REGEN * 0.55 * dt
		)
	# Hot contested holds burn composure — stamina bleeds under the pile-on.
	elif String(in_zone.get("pressure", "")) == "hot" and contest > 0:
		player["stamina"] = maxf(0.0, float(player.get("stamina", 0.0)) - STAMINA_DRAIN * 0.85 * dt)
	world["extract_progress_01"] = clampf(float(in_zone["progress"]) / hold, 0.0, 1.0)

	if float(in_zone["progress"]) >= hold:
		world["over"] = true
		world["outcome"] = "extracted"
		world["extract_alarm"] = false
		# Clean quiet sits and hot fights both count as train-by-doing — different flavors.
		var pressure_done := String(in_zone.get("pressure", "contested"))
		if pressure_done == "quiet" and contest == 0:
			world["skill_deeds"] = int(world.get("skill_deeds", 0)) + 3
		elif pressure_done == "hot":
			world["skill_deeds"] = int(world.get("skill_deeds", 0)) + 2
		elif contest > 0:
			world["skill_deeds"] = int(world.get("skill_deeds", 0)) + 1
		# Late extracts under thinning light count as a hard sit.
		if float(world.get("dusk_01", 0.0)) >= 0.5:
			world["skill_deeds"] = int(world.get("skill_deeds", 0)) + 1
			_push_float(world, player["pos"] + Vector2(0, -16), "DUSK OUT", Color("9aa8d4"), 1.4)
		_set_message(world, "OUT — loot banks to locker.", 6.0)
		_push_float(world, player["pos"], "OUT", Color("3ecf8e"), 2.0)
	else:
		var left := hold - float(in_zone["progress"])
		var pressure2 := String(in_zone.get("pressure", "contested"))
		if contest > 0:
			_set_message(world, "%s extract — %.1fs · %d roamers closing" % [pressure2.to_upper(), left, contest], 0.2)
		else:
			_set_message(world, "%s extracting… %.1fs" % [pressure2.capitalize(), left], 0.25)


static func _spawn_extract_reinforcements(world: Dictionary, zone: Dictionary, count: int) -> void:
	var zp: Vector2 = zone["pos"]
	for i in count:
		var ang := TAU * float(i) / float(maxi(1, count)) + randf_range(-0.2, 0.2)
		var sp := zp + Vector2(cos(ang), sin(ang)) * REINFORCE_SPAWN_RING
		sp.x = clampf(sp.x, 60.0, MAP_W - 60.0)
		sp.y = clampf(sp.y, 60.0, MAP_H - 60.0)
		world["roamers"].append(_make_actor(world, "roamer", sp, {
			"hp": randf_range(50.0, 75.0),
			"max_hp": 75.0,
			"speed": randf_range(120.0, 155.0),
			"damage": randf_range(10.0, 16.0),
			"aggro_range": randf_range(280.0, 360.0),
			"mitigation": 0.08,
		}))
		var r: Dictionary = world["roamers"].back()
		r["alert_ttl"] = 4.0
		r["last_heard"] = zp
		r["last_seen"] = world["player"]["pos"]
		r["ai_state"] = "rush"
		r["patrol_anchor"] = zp
		r["patrol_phase"] = randf() * TAU
		r["search_ttl"] = 0.0
		r["elite"] = false
		r["hear_mult"] = 1.1
		r["role"] = "reinforcement"
		r["call_cooldown"] = 0.0
		r["suppress_ttl"] = 0.0
		r["forage_ttl"] = 0.0
		r["forage_target_id"] = -1
		r["dormant"] = false


static func _apply_roamer_suppression(roamer: Dictionary, gap: float, ttl: float = ROAMER_SUPPRESS_TTL) -> void:
	roamer["suppress_ttl"] = maxf(float(roamer.get("suppress_ttl", 0.0)), ttl)
	roamer["fire_cooldown"] = maxf(float(roamer.get("fire_cooldown", 0.0)), gap)
	# Wake anyone you pin — dormants don't tank near-misses forever.
	roamer["dormant"] = false
	roamer["alert_ttl"] = maxf(float(roamer.get("alert_ttl", 0.0)), 1.2)


static func _roamer_shot_spread(roamer: Dictionary) -> float:
	var spread := 0.07
	if float(roamer.get("suppress_ttl", 0.0)) > 0.0:
		spread += ROAMER_SUPPRESS_SPREAD
	if bool(roamer.get("elite", false)):
		spread *= 0.75
	return spread


static func _tick_bleed(world: Dictionary, dt: float) -> void:
	var player: Dictionary = world["player"]
	if not bool(player["alive"]):
		return
	var hp_ratio := float(player["hp"]) / maxf(1.0, float(player["max_hp"]))
	var wounded := hp_ratio <= WOUNDED_HP_RATIO
	var was_wounded := bool(player.get("wounded", false))
	player["wounded"] = wounded
	player["bleeding"] = wounded
	player["bleed_cue_cd"] = maxf(0.0, float(player.get("bleed_cue_cd", 0.0)) - dt)
	# First limp of the raid — dump stamina so you can still break contact.
	if wounded and not was_wounded and not bool(player.get("adrenaline_fired", false)):
		player["adrenaline_fired"] = true
		player["adrenaline_ttl"] = ADRENALINE_TTL
		var stam_max := float(player.get("stamina_max", STAMINA_MAX))
		player["stamina"] = minf(stam_max, float(player.get("stamina", 0.0)) + ADRENALINE_STAMINA)
		player["sprint_exhaust"] = 0.0
		player["suppress_ttl"] = 0.0
		_push_float(world, player["pos"] + Vector2(0, -22), "PUSH", Color("9de8ff"), 1.0)
		_set_message(world, "Adrenaline — move. Then patch.", 2.2)
	if not wounded:
		return
	var bleed_rate := BLEED_DPS
	# Stay low — slower leak while you find a medkit or extract.
	if bool(player.get("crouching", false)) and not bool(player.get("sprinting", false)):
		bleed_rate *= CROUCH_BLEED_MULT
	player["hp"] = float(player["hp"]) - bleed_rate * dt
	if float(player["bleed_cue_cd"]) <= 0.0:
		player["bleed_cue_cd"] = BLEED_CUE_INTERVAL
		_push_float(world, player["pos"] + Vector2(0, -16), "BLEEDING", Color("c45c5c"), 0.85)
		# Standing rasp carries — drop low or plant to keep the tell off nearby ears.
		# First-limp surge also cups the rasp while you're still flying.
		var quiet_breath := (bool(player.get("crouching", false)) or bool(player.get("bracing", false)) \
			or float(player.get("adrenaline_ttl", 0.0)) > 0.0) \
			and not bool(player.get("sprinting", false))
		if not quiet_breath:
			_emit_noise(world, player["pos"], HEAR_WOUND_BREATH_RANGE, NOISE_TTL_WOUND_BREATH)
	if float(player["hp"]) > 0.0:
		return
	player["alive"] = false
	player["hp"] = 0.0
	world["over"] = true
	world["outcome"] = "died"
	world["shake"] = 14.0
	_spawn_player_drop_bag(world)
	var lost := Items.inventory_used(world.get("dropped_loot", []))
	_set_message(world, "Bled out — drop bag left behind (%d items). Stash is safe." % lost, 6.0)
	_push_float(world, player["pos"], "DROP BAG", Color("e6b35a"), 2.0)
	_push_float(world, player["pos"] + Vector2(0, -14), "BLED OUT", Color("e85454"), 2.2)


static func _tick_blood_trail(world: Dictionary, dt: float) -> void:
	var trail: Array = world.get("blood_trail", [])
	var next: Array = []
	for drop in trail:
		drop["ttl"] = float(drop["ttl"]) - dt
		if float(drop["ttl"]) > 0.0:
			next.append(drop)
	world["blood_trail"] = next
	world["blood_drip_cd"] = maxf(0.0, float(world.get("blood_drip_cd", 0.0)) - dt)
	var player: Dictionary = world["player"]
	if not bool(player.get("wounded", false)) or not bool(player["alive"]):
		return
	if float(world["blood_drip_cd"]) > 0.0:
		return
	# Only drip while moving — standing still doesn't paint a highway.
	if (player.get("vel", Vector2.ZERO) as Vector2).length_squared() < 20.0:
		return
	world["blood_drip_cd"] = BLOOD_DRIP_INTERVAL
	world["blood_trail"].append({
		"pos": player["pos"],
		"ttl": BLOOD_TRAIL_TTL,
	})


static func _nearest_blood(world: Dictionary, from: Vector2, range_v: float) -> Variant:
	var best: Variant = null
	var best_d := range_v
	for drop in world.get("blood_trail", []):
		var d: float = from.distance_to(drop["pos"])
		if d <= best_d:
			best_d = d
			best = drop["pos"]
	return best


static func _roamer_alert_call(world: Dictionary, caller: Dictionary, target_pos: Vector2) -> void:
	# Soft shout float — no HUD spam; nearby allies get a investigate ping.
	_push_float(world, caller["pos"] + Vector2(0, -18), "!", Color("ffb0b0"), 0.55)
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


static func _enforcer_distress_call(world: Dictionary, enforcer: Dictionary, target_pos: Vector2) -> void:
	_push_float(world, enforcer["pos"] + Vector2(0, -22), "!!", Color("c9a0ff"), 1.0)
	_set_message(world, "Enforcer distress — compound stirring.", 2.4)
	_emit_noise(world, enforcer["pos"], ENFORCER_DISTRESS_RANGE * 0.55, 1.1)
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
