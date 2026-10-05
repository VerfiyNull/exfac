class_name RaidSim
extends RefCounted
## Pure field simulation — visuals read this state; no Godot nodes owned here.
##
## Layout (search the section banners below):
##   Tunables → World bootstrap → Perception/LOS → Main tick → Combat → Vitals →
##   Noise → Inventory/medkit → Interact/loot → Gadgets → Melee → Raid resolve →
##   Map gen → Spatial index → Floor/collision → Projectiles/extracts/bleed
## Roamer brains live in raid_roamers.gd (host bridge back into helpers here).

# Explicit preloads — headless / fresh clone has no global class_name cache yet.
const Items := preload("res://scripts/systems/items.gd")
const Skills := preload("res://scripts/systems/skills.gd")
const MetaSim := preload("res://scripts/systems/meta.gd")
const RaidRoamers := preload("res://scripts/systems/raid_roamers.gd")

# =============================================================================
# TUNABLES — edit here; avoid scattering magic numbers in hot paths.
# Mirrored copies in raid_roamers.gd must stay identical (see comment there).
# =============================================================================

# --- Map / perception --------------------------------------------------------
const MAP_W := 9600.0
const MAP_H := 6400.0
## Visual forest skirt past the playable rect — hides the hard map cutoff.
const MAP_MARGIN := 360.0
## Spatial bins for draw / floor / LOS — keeps the big map from scanning everything.
const SPATIAL_CHUNK := 512.0
const VISION_RANGE := 520.0
## PZ-style sight: ~90° cone (±45°) while idle; alerted AI tracks freely.
const VIEW_CONE_HALF := PI * 0.25
const VIEW_CONE_DOT := 0.7071  # cos(45°)
const SPAWN_EXTRACT_MIN_DIST := 1100.0
const ACTOR_RADIUS := 11.0
const ROAMER_RADIUS := 10.0

# --- Extract pressure --------------------------------------------------------
## How far roamers hear an active extract flare and rush the exit.
const EXTRACT_ALARM_RADIUS := 1600.0
## Damage while holding extract bleeds progress (seconds lost per HP).
const EXTRACT_DAMAGE_PROGRESS_BLEED := 0.045
## Crouched extract hold — keep the flare tight so the pad doesn't scream the whole map.
const CROUCH_EXTRACT_ALARM_MULT := 0.62
## Extract reinforcements — flare summons a late wave from the perimeter.
const REINFORCE_DELAY_HOT := 0.55
const REINFORCE_DELAY_CONTESTED := 1.15
const REINFORCE_COUNT_HOT := 4
const REINFORCE_COUNT_CONTESTED := 2
const REINFORCE_SPAWN_RING := 380.0
## Extract abandon — peeling off a lit pad still rings; don't cheese hold/leave.
const HEAR_EXTRACT_ABANDON_RANGE := 520.0
const NOISE_TTL_EXTRACT_ABANDON := 1.1
const EXTRACT_ABANDON_MIN_PROGRESS := 0.12
const EXTRACT_ABANDON_STAMINA := 18.0
const EXTRACT_ABANDON_STUMBLE := 0.35
const WOUNDED_EXTRACT_ABANDON_HEAR_MULT := 1.18
const HEAVY_BAG_EXTRACT_ABANDON_HEAR_MULT := 1.14

# --- Movement / stamina ------------------------------------------------------
## Sprint — big map traversal without making walk feel sluggish.
const SPRINT_MULT := 1.7
const STAMINA_MAX := 100.0
## Sprint sips the bar; recovery is deliberately slow so pacing still matters.
const STAMINA_DRAIN := 14.0
const STAMINA_REGEN := 8.0
## Brief lockout after emptying the bar so sprint can't stutter-tap.
const SPRINT_EXHAUST := 0.75
## Movement response — accel toward desired speed; stop/reverse snappier than a skate.
const MOVE_ACCEL_RESP := 16.0
const MOVE_STOP_RESP := 22.0
const MOVE_REVERSE_RESP := 14.0
const MOVE_SPRINT_RESP := 12.0
const MOVE_BRACE_RESP := 20.0
## Facing gait (PZ combat-strafe feel) — full pace looking ahead, slow when not.
const MOVE_STRAFE_MULT := 0.72
const MOVE_BACK_MULT := 0.52
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
const WOUNDED_STUMBLE_HEAR_MULT := 1.22
const HEAVY_BAG_STUMBLE_HEAR_MULT := 1.18

# --- Stance (crouch / brace) -------------------------------------------------
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
## Brace settle — hold the plant and the cone tightens further.
const BRACE_SETTLE_TIME := 0.85
const BRACE_SETTLE_SPREAD := 0.7
const BRACE_RELOAD_MULT := 0.78
const BRACE_CROUCH_RELOAD_MULT := 0.68
const BRACE_HEAL_MULT := 0.82
const CROUCH_HEAL_MULT := 0.88
const BRACE_CROUCH_HEAL_MULT := 0.72

# --- Suppression / threat ----------------------------------------------------
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

# --- Dusk --------------------------------------------------------------------
## Field dusk — light falls; vision thins so you push for the lift.
const RAID_DUSK_START := 120.0
const RAID_DUSK_FULL := 240.0
const DUSK_VISION_MIN := 0.55
const DUSK_HEAR_MAX := 1.22
## Dusk heat — late raids make quieter exits shout farther.
const DUSK_QUIET_ALARM_MULT := 1.9
const DUSK_CONTESTED_ALARM_MULT := 1.22
const DUSK_QUIET_PAD_ADD := 0.09

# --- Wound / adrenaline / bag weight -----------------------------------------
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
const WOUNDED_STAMINA_DRAIN_MULT := 1.35
const WOUNDED_STAMINA_REGEN_MULT := 0.72
const WOUNDED_SPRINT_HEAR_MULT := 1.16
const WOUNDED_SHOT_HEAR_MULT := 1.18
const WOUNDED_SETTLE_MULT := 0.72
const WOUNDED_HEAL_MULT := 0.78
const WOUNDED_RELOAD_MULT := 0.78
const ADRENALINE_SETTLE_MULT := 0.92
## Heavy bag — a stuffed pack drags you; risk of greed.
const HEAVY_BAG_RATIO := 0.75
const HEAVY_BAG_SPEED := 0.88
const FULL_BAG_SPEED := 0.76
const HEAVY_BAG_STAMINA_DRAIN_MULT := 1.22
const HEAVY_BAG_STAMINA_REGEN_MULT := 0.82
const HEAVY_BAG_SPRINT_HEAR_MULT := 1.2
const HEAVY_BAG_SHOT_HEAR_MULT := 1.14
const HEAVY_BAG_SETTLE_MULT := 0.62
const HEAVY_BAG_RELOAD_MULT := 0.82
const HEAVY_BAG_HEAL_MULT := 0.85

# --- Hearing (shots / sprint / walk) -----------------------------------------
## Roamers hear shots / sprint even without line of sight.
const HEAR_SHOT_RANGE := 560.0
const HEAR_SPRINT_RANGE := 240.0
const NOISE_TTL_SHOT := 1.1
const NOISE_TTL_SPRINT := 0.25
## Footsteps — walk is audible; crouch stays quiet; sprint already has its own noise.
const HEAR_WALK_RANGE := 110.0
const NOISE_TTL_WALK := 0.35
const HEAVY_BAG_WALK_HEAR_MULT := 1.35
const FULL_BAG_WALK_HEAR_MULT := 1.55
const WOUNDED_WALK_HEAR_MULT := 1.28

# --- Loot / medkit channels --------------------------------------------------
## Field medkit channel time — interrupted if you take damage.
const MEDKIT_CHANNEL := 1.35
## Ransack — pry a crate / strip a body (not instant; loud; leave range or take a hit to cancel).
const LOOT_CHANNEL_CRATE := 1.75
const LOOT_CHANNEL_CORPSE := 1.15
const LOOT_CHANNEL_DROP_BAG := 1.4
const LOOT_CHANNEL_AMMO := 1.35
const LOOT_CHANNEL_MED := 1.5
const LOOT_CHANNEL_WEAPON := 2.35
const LOOT_CHANNEL_INTEL := 2.1
## Loose ground piles — quick grab so the field feels littered, not only boxed.
const LOOT_CHANNEL_GROUND := 0.85
const HEAR_RANSACK_RANGE := 400.0
const CROUCH_LOOT_RATE := 1.28
const CROUCH_RANSACK_HEAR_MULT := 0.62
const HEAVY_BAG_RANSACK_HEAR_MULT := 1.22
const HEAVY_BAG_LOOT_RATE := 0.82
const WOUNDED_LOOT_RATE := 0.82
## Sprint dump — aborting a channel into a run makes a clatter.
const HEAR_RELOAD_DUMP_RANGE := 140.0
const NOISE_TTL_RELOAD_DUMP := 0.4
const HEAR_MEDKIT_DUMP_RANGE := 120.0
const NOISE_TTL_MEDKIT_DUMP := 0.4
const HEAR_LOOT_DUMP_RANGE := 160.0
const NOISE_TTL_LOOT_DUMP := 0.45

# --- Distraction / intel / flare ---------------------------------------------
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
const WOUNDED_DISTRACT_HEAR_MULT := 1.2
const HEAVY_BAG_DISTRACT_HEAR_MULT := 1.15
## Intel pulse — burn a Signal Chip for a short awareness sweep.
const INTEL_PULSE_TTL := 4.0
const INTEL_PULSE_COOLDOWN := 1.0
## Mark flare — loud lure farther than scrap toss; wakes dormants on the bang.
const HEAR_FLARE_RANGE := 720.0
const NOISE_TTL_FLARE := 3.4
const FLARE_TOSS_RANGE := 380.0
const FLARE_COOLDOWN := 1.8

# --- Doors -------------------------------------------------------------------
## Doors — closed slabs block LOS/path; E pries them open (and shut).
const DOOR_INTERACT_RANGE := 28.0
const HEAR_DOOR_PRY_RANGE := 180.0
const NOISE_TTL_DOOR_PRY := 0.55
## Crouched pry — soft latch work so you can slip rooms without a stadium clang.
const HEAR_DOOR_CROUCH_RANGE := 85.0
const NOISE_TTL_DOOR_CROUCH := 0.4
const WOUNDED_DOOR_PRY_HEAR_MULT := 1.25
const HEAVY_BAG_DOOR_PRY_HEAR_MULT := 1.18

# --- Dry-fire ----------------------------------------------------------------
## Dry-fire click — empty mag still makes a small tell.
const HEAR_DRYFIRE_RANGE := 95.0
const NOISE_TTL_DRYFIRE := 0.45
const CROUCH_DRYFIRE_HEAR_MULT := 0.55
const BRACE_DRYFIRE_HEAR_MULT := 0.7
const BRACE_CROUCH_DRYFIRE_HEAR_MULT := 0.42
const WOUNDED_DRYFIRE_HEAR_MULT := 1.3
const HEAVY_BAG_DRYFIRE_HEAR_MULT := 1.18

# --- Melee / unarmed ---------------------------------------------------------
## Empty-mag shove — last-ditch contact weapon when the chamber's dry.
const MELEE_RANGE := 44.0
const MELEE_DAMAGE := 22.0
## Contact hit — no knockback; briefly hobble their move speed instead.
const MELEE_SLOW_TTL := 0.5
const MELEE_SLOW_MULT := 0.4
const MELEE_COOLDOWN := 0.9
const HEAR_MELEE_RANGE := 200.0
const NOISE_TTL_MELEE := 0.55
## Unarmed punch — no gun visible; LMB is fists with shorter reach and quieter tell.
const PUNCH_RANGE := 48.0
const PUNCH_DAMAGE := 16.0
const PUNCH_COOLDOWN := 0.52
const PUNCH_STAMINA_COST := 14.0
const MELEE_STAMINA_COST := 18.0
const PUNCH_MISS_STAMINA_COST := 8.0
const HEAR_PUNCH_RANGE := 110.0
const NOISE_TTL_PUNCH := 0.35
const PUNCH_SWING_TTL := 0.18
const WOUNDED_MELEE_HEAR_MULT := 1.2
const HEAVY_BAG_MELEE_HEAR_MULT := 1.15
## Silent rear drop — crouched empty-mag shove / punch into a dormant's back stays quiet.
const MELEE_SILENT_DAMAGE := 58.0
const PUNCH_SILENT_DAMAGE := 48.0
const HEAR_MELEE_SILENT_RANGE := 55.0
const NOISE_TTL_MELEE_SILENT := 0.35
const MELEE_BEHIND_DOT := -0.35

# --- Blood trail -------------------------------------------------------------
## Blood trail — wounded runners drip scent roamers can track.
const BLOOD_DRIP_INTERVAL := 0.45
const BLOOD_TRAIL_TTL := 4.5

# --- Floor traction ----------------------------------------------------------
## Small, readable biases (never transform the game).
## Keys: speed / hear / vision multipliers while standing on that decal style.
const FLOOR_MODS := {
	"road": {"speed": 1.07, "hear": 1.1, "vision": 1.03},
	"junction": {"speed": 1.05, "hear": 1.08, "vision": 1.02},
	"dirt_road": {"speed": 1.02, "hear": 1.0, "vision": 1.0},
	"pad": {"speed": 1.03, "hear": 1.04, "vision": 1.02},
	"interior": {"speed": 1.04, "hear": 0.95, "vision": 1.01},
	"asphalt": {"speed": 1.04, "hear": 1.06, "vision": 1.02},
	"gravel": {"speed": 0.94, "hear": 1.16, "vision": 1.0},
	"grass": {"speed": 0.96, "hear": 0.88, "vision": 0.96},
	"leaf": {"speed": 0.95, "hear": 0.86, "vision": 0.95},
	"scrub": {"speed": 0.93, "hear": 0.9, "vision": 0.94},
	"mud": {"speed": 0.9, "hear": 0.92, "vision": 0.97},
	"pond": {"speed": 0.72, "hear": 1.14, "vision": 0.94},
	"yard": {"speed": 0.97, "hear": 0.9, "vision": 0.97},
	"dirt": {"speed": 0.98, "hear": 0.96, "vision": 0.99},
}


# =============================================================================
# WORLD BOOTSTRAP
# =============================================================================
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
		"decals": [],
		"districts": [],
		"landmarks": [],
	}

	var field := _build_field()
	world["obstacles"] = field["obstacles"]
	world["decals"] = field["decals"]
	world["districts"] = field.get("districts", [])
	world["landmarks"] = field.get("landmarks", [])
	# Spatial bins — LOS / floor / draw cull share one index built at world create.
	world["draw_chunks"] = _build_spatial_index(field["decals"], field["obstacles"])
	var loot_spots: Array = field.get("loot_spots", [])
	var roamer_anchors: Array = field.get("roamer_anchors", [])
	var field_extracts: Array = field.get("extract_sites", [])

	# Random clear drop-in — never near an extract pad.
	var spawn := _ingress_spawn(
		world["obstacles"],
		field.get("spawn_candidates", []),
		field.get("extract_sites", [])
	)
	world["player"] = _make_actor(world, "player", spawn, {
		"hp": 100.0,
		"max_hp": 100.0,
		"speed": 118.0,
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

	# Roamers prefer district anchors so voids stay quieter than compounds.
	for _i in 36:
		var sp: Vector2
		if not roamer_anchors.is_empty() and randf() < 0.78:
			var anchor: Vector2 = roamer_anchors[_i % roamer_anchors.size()]
			sp = _rand_near(world["obstacles"], anchor, 220.0, 20.0)
		else:
			sp = _rand_clear_pos(world["obstacles"], 20.0, 90.0)
		world["roamers"].append(_make_actor(world, "roamer", sp, {
			"hp": randf_range(45.0, 70.0),
			"max_hp": 70.0,
			"speed": randf_range(72.0, 96.0),
			"damage": randf_range(8.0, 14.0),
			"aggro_range": randf_range(200.0, 320.0),
			"mitigation": 0.05,
			"radius": ROAMER_RADIUS,
		}))
		world["roamers"].back()["alert_ttl"] = 0.0
		world["roamers"].back()["last_heard"] = sp
		world["roamers"].back()["last_seen"] = sp
		world["roamers"].back()["ai_state"] = "patrol"
		world["roamers"].back()["patrol_anchor"] = sp
		world["roamers"].back()["patrol_waypoint"] = Vector2.ZERO
		world["roamers"].back()["patrol_phase"] = randf() * TAU
		world["roamers"].back()["search_ttl"] = 0.0
		world["roamers"].back()["elite"] = false
		world["roamers"].back()["hear_mult"] = 1.0
		world["roamers"].back()["role"] = "roamer"
		world["roamers"].back()["call_cooldown"] = 0.0
		world["roamers"].back()["suppress_ttl"] = 0.0
		world["roamers"].back()["forage_ttl"] = 0.0
		world["roamers"].back()["forage_target_id"] = -1
		# Few start dormant — most should be walking a beat.
		var dormant := randf() < 0.12
		world["roamers"].back()["dormant"] = dormant
		if dormant:
			world["roamers"].back()["ai_state"] = "dormant"
			world["roamers"].back()["aggro_range"] = float(world["roamers"].back()["aggro_range"]) * 0.45

	# Containers prefer landmark loot spots; leftovers fill random clear ground.
	var spawn_plan: Array = []
	for _i in 28:
		spawn_plan.append("crate")
	for _i in 11:
		spawn_plan.append("ammo_crate")
	for _i in 10:
		spawn_plan.append("med_cache")
	for _i in 8:
		spawn_plan.append("weapon_case")
	for _i in 7:
		spawn_plan.append("intel_safe")
	for _i in 36:
		spawn_plan.append("ground_loot")
	spawn_plan.shuffle()
	# Prefer specialty spots for specialty kinds, ground spots for ground piles.
	var specialty_spots: Array = []
	var ground_spots: Array = []
	var other_spots: Array = []
	for spot in loot_spots:
		match String(spot.get("prefer", "")):
			"specialty":
				specialty_spots.append(spot)
			"ground":
				ground_spots.append(spot)
			_:
				other_spots.append(spot)
	var si := 0
	var gi := 0
	var oi := 0
	for kind in spawn_plan:
		var prefer := String(kind)
		var sp: Vector2
		var spot: Dictionary = {}
		var is_specialty := prefer in ["weapon_case", "intel_safe", "med_cache", "ammo_crate"]
		if is_specialty and si < specialty_spots.size():
			spot = specialty_spots[si]
			si += 1
		elif prefer == "ground_loot" and gi < ground_spots.size():
			spot = ground_spots[gi]
			gi += 1
		elif oi < other_spots.size():
			spot = other_spots[oi]
			oi += 1
		elif gi < ground_spots.size():
			spot = ground_spots[gi]
			gi += 1
		elif si < specialty_spots.size():
			spot = specialty_spots[si]
			si += 1
		if not spot.is_empty():
			sp = _rand_near(world["obstacles"], spot["pos"], float(spot.get("radius", 90.0)), 14.0)
		else:
			sp = _rand_clear_pos(world["obstacles"], 16.0, 50.0)
		var is_ground := prefer == "ground_loot"
		world["crates"].append({
			"id": _alloc_id(world),
			"pos": sp,
			"radius": 16.0 if is_ground else 24.0,
			"opened": false,
			"kind": prefer,
			"contents": Items.roll_container_loot(prefer),
			"tint": randi(),
		})

	# Extract sites come from the generated layout (positions jittered each run).
	var extract_defs: Array = field_extracts
	if extract_defs.is_empty():
		extract_defs = [
			{"pressure": "hot", "pos": Vector2(MAP_W - 180, 160), "alarm_radius": 1900.0, "hold_seconds": 2.1, "contest_pad": 0.18, "bleed_mult": 1.35, "radius": 58.0},
			{"pressure": "quiet", "pos": Vector2(160, 160), "alarm_radius": 700.0, "hold_seconds": 4.2, "contest_pad": 0.06, "bleed_mult": 0.7, "radius": 52.0},
			{"pressure": "contested", "pos": Vector2(MAP_W * 0.5, MAP_H - 160), "alarm_radius": EXTRACT_ALARM_RADIUS, "hold_seconds": 2.9, "contest_pad": 0.12, "bleed_mult": 1.0, "radius": 56.0},
			{"pressure": "contested", "pos": Vector2(MAP_W - 200, MAP_H * 0.55), "alarm_radius": 1100.0, "hold_seconds": 3.3, "contest_pad": 0.1, "bleed_mult": 0.95, "radius": 54.0},
		]
	world["extracts"] = []
	for ed in extract_defs:
		world["extracts"].append({
			"id": _alloc_id(world),
			"pos": ed["pos"],
			"radius": float(ed.get("radius", 54.0)),
			"hold_seconds": float(ed.get("hold_seconds", 3.0)),
			"progress": 0.0,
			"active": true,
			"pressure": String(ed.get("pressure", "contested")),
			"alarm_radius": float(ed.get("alarm_radius", EXTRACT_ALARM_RADIUS)),
			"contest_pad": float(ed.get("contest_pad", 0.12)),
			"bleed_mult": float(ed.get("bleed_mult", 1.0)),
		})
	for z in world["extracts"]:
		world["landmarks"].append({
			"id": int(z["id"]),
			"name": String(z.get("pressure", "OUT")).to_upper(),
			"pos": z["pos"],
			"kind": "extract",
		})
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
			"speed": randf_range(78.0, 92.0),
			"damage": randf_range(16.0, 22.0),
			"aggro_range": randf_range(340.0, 420.0),
			"mitigation": 0.22,
			"radius": ROAMER_RADIUS + 2.0,
			"vision_range": VISION_RANGE * 1.15,
		}))
		var enforcer: Dictionary = world["roamers"].back()
		enforcer["alert_ttl"] = 0.0
		enforcer["last_heard"] = sp
		enforcer["last_seen"] = sp
		enforcer["ai_state"] = "patrol"
		enforcer["patrol_anchor"] = zp
		enforcer["patrol_waypoint"] = Vector2.ZERO
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



# =============================================================================
# PERCEPTION / LOS / SPATIAL QUERY
# =============================================================================
static func has_line_of_sight(
	from: Vector2, to: Vector2, obstacles: Array, index: Dictionary = {}
) -> bool:
	return _trace_clear(from, to, obstacles, false, index)


## Loot / interact reach — walls, closed doors, and window frames all block.
static func has_clear_reach(
	from: Vector2, to: Vector2, obstacles: Array, index: Dictionary = {}
) -> bool:
	return _trace_clear(from, to, obstacles, true, index)


static func _trace_clear(
	from: Vector2, to: Vector2, obstacles: Array, for_reach: bool, index: Dictionary = {}
) -> bool:
	var delta := to - from
	var dist := delta.length()
	if dist < 1.0:
		return true
	var probe: Array = obstacles
	if _spatial_index_matches(index, obstacles.size(), -1):
		probe = _gather_obstacles_along(from, to, obstacles, index)
	var steps := int(ceil(dist / 12.0))
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var p := from.lerp(to, t)
		for o in probe:
			if for_reach:
				if not _obstacle_blocks_reach(o):
					continue
			elif not _obstacle_blocks_los(o):
				continue
			if _point_hits_obstacle(p, o):
				return false
	return true


## True when the index was built for this obstacle/decal array (skip if tests swap lists).
static func _spatial_index_matches(index: Dictionary, obstacle_count: int, decal_count: int) -> bool:
	if index.is_empty():
		return false
	var cells: Variant = index.get("cells", null)
	if cells == null or not (cells is Dictionary) or (cells as Dictionary).is_empty():
		return false
	if obstacle_count >= 0 and int(index.get("obstacle_count", -1)) != obstacle_count:
		return false
	if decal_count >= 0 and int(index.get("decal_count", -1)) != decal_count:
		return false
	return true


## Obstacles that touch chunks along a segment — keeps LOS off the full solid list.
static func _gather_obstacles_along(
	from: Vector2, to: Vector2, obstacles: Array, index: Dictionary
) -> Array:
	var cells: Dictionary = index.get("cells", {})
	var cs := float(index.get("size", SPATIAL_CHUNK))
	if cs < 1.0 or cells.is_empty():
		return obstacles
	# Conservative AABB of the segment (+1 cell) so thin walls can't fall between samples.
	var x0 := int(floor(minf(from.x, to.x) / cs)) - 1
	var y0 := int(floor(minf(from.y, to.y) / cs)) - 1
	var x1 := int(floor(maxf(from.x, to.x) / cs)) + 1
	var y1 := int(floor(maxf(from.y, to.y) / cs)) + 1
	var seen: Dictionary = {}
	var out: Array = []
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			var cell: Variant = cells.get("%d:%d" % [cx, cy], null)
			if cell == null:
				continue
			for oi in cell["o"]:
				if seen.has(oi):
					continue
				seen[oi] = true
				if oi < 0 or oi >= obstacles.size():
					continue
				out.append(obstacles[oi])
	return out


static func can_see_actor(
	viewer: Dictionary, target_pos: Vector2, obstacles: Array, index: Dictionary = {}
) -> bool:
	var from: Vector2 = viewer["pos"]
	var range_v := float(viewer.get("vision_range", VISION_RANGE))
	if from.distance_squared_to(target_pos) > range_v * range_v:
		return false
	# Optional facing cone — roamers use this; player fog stays omnidirectional.
	if bool(viewer.get("use_view_cone", false)):
		var aim: Vector2 = viewer.get("aim", Vector2.ZERO)
		if aim.length_squared() > 1e-6:
			var to_t := target_pos - from
			if to_t.length_squared() > 1e-6 and aim.normalized().dot(to_t.normalized()) < VIEW_CONE_DOT:
				return false
	return has_line_of_sight(from, target_pos, obstacles, index)


## PZ-style facing gait — forward full, strafe mid, backpedal slowest.
static func _facing_move_mult(move_dir: Vector2, look_dir: Vector2) -> float:
	if move_dir.length_squared() < 1e-6:
		return 1.0
	var look := look_dir
	if look.length_squared() < 1e-6:
		return 1.0
	look = look.normalized()
	var align := move_dir.normalized().dot(look)
	# Forward cone (~±45°) stays near full pace.
	if align >= VIEW_CONE_DOT:
		return lerpf(0.92, 1.0, (align - VIEW_CONE_DOT) / (1.0 - VIEW_CONE_DOT))
	if align >= 0.0:
		return lerpf(MOVE_STRAFE_MULT, 0.92, align / VIEW_CONE_DOT)
	return lerpf(MOVE_BACK_MULT, MOVE_STRAFE_MULT, align + 1.0)



# =============================================================================
# MAIN TICK
# =============================================================================
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
			var aim_ch: Vector2 = aim_world - (player["pos"] as Vector2)
			var want_ch: Vector2 = aim_ch.normalized() if aim_ch.length_squared() > 1e-6 else (player.get("aim", Vector2.RIGHT) as Vector2)
			var heal_move := 0.35
			if want_brace_h and want_crouch_h:
				heal_move = 0.2
			elif want_brace_h:
				heal_move = 0.26
			elif want_crouch_h:
				heal_move = 0.28
			heal_move *= _facing_move_mult(move_dir_ch, want_ch)
			var desired_ch: Vector2 = move_dir_ch * float(player["speed"]) * heal_move
			player["vel"] = _smooth_vec(player.get("vel", Vector2.ZERO), desired_ch, MOVE_BRACE_RESP, dt)
			_move_actor(player, player["vel"] * dt, world["obstacles"])
			_clamp_to_map(player, float(world["width"]), float(world["height"]))
			player["aim"] = _smooth_aim(player.get("aim", Vector2.RIGHT), want_ch, AIM_TURN_RESP, dt)
			player["facing"] = (player["aim"] as Vector2).angle()
			if float(player["heal_channel"]) <= 0.0:
				_finish_medkit(world)
			_tick_blood_trail(world, dt)
			_tick_noise(world, dt)
			_update_extract_compass(world)
			_update_extracts(world, dt)
			RaidRoamers.update(world, dt)
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
			var aim_r: Vector2 = aim_world - (player["pos"] as Vector2)
			var want_r: Vector2 = aim_r.normalized() if aim_r.length_squared() > 1e-6 else (player.get("aim", Vector2.RIGHT) as Vector2)
			var reload_move := 0.55
			if want_brace_r and want_crouch_r:
				reload_move = 0.32
			elif want_brace_r:
				reload_move = 0.4
			elif want_crouch_r:
				reload_move = 0.42
			reload_move *= _facing_move_mult(move_dir_r, want_r)
			var desired_r: Vector2 = move_dir_r * float(player["speed"]) * reload_move
			player["vel"] = _smooth_vec(player.get("vel", Vector2.ZERO), desired_r, MOVE_BRACE_RESP, dt)
			_move_actor(player, player["vel"] * dt, world["obstacles"])
			_clamp_to_map(player, float(world["width"]), float(world["height"]))
			player["aim"] = _smooth_aim(player.get("aim", Vector2.RIGHT), want_r, AIM_TURN_RESP, dt)
			player["facing"] = (player["aim"] as Vector2).angle()
			if float(player["reload_channel"]) <= 0.0:
				_finish_reload(world)
			_tick_blood_trail(world, dt)
			_tick_noise(world, dt)
			_update_extract_compass(world)
			_update_extracts(world, dt)
			RaidRoamers.update(world, dt)
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
	# Look where the mouse points this frame — gait keys off facing, not last aim.
	var look_dir: Vector2 = aim_world - (player["pos"] as Vector2)
	if look_dir.length_squared() > 1e-6:
		look_dir = look_dir.normalized()
	else:
		var prev_look: Vector2 = player.get("aim", Vector2.RIGHT)
		look_dir = prev_look.normalized() if prev_look.length_squared() > 1e-6 else Vector2.RIGHT
	var facing_mult := _facing_move_mult(move_dir, look_dir)
	player["facing_move"] = facing_mult
	# Sprint only when moving into your look cone — shuffle-strafe can't outrun facing.
	var can_sprint := move_dir.length_squared() > 1e-6 and facing_mult >= 0.9
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
	var was_sprinting := bool(player.get("sprinting", false))
	# Sprint input must be live — Shift can sticky-release in Godot; sim clears if caller lied.
	var want_sprint_live := sprint and can_sprint and not want_crouch
	_tick_stamina(player, dt, want_sprint_live, move_dir.length_squared() > 1e-6)
	_tick_recoil(player, world["loadout"], dt)
	var speed_mult := 1.0
	if bool(player["sprinting"]) and can_sprint:
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
	# Surface underfoot — asphalt runs, mud/pond drag, brush softens pace.
	# Cache floor samples; full decal scan every frame was thrashing the big map.
	var floor_style := String(player.get("floor", "dirt"))
	var floor_cache: Vector2 = player.get("floor_cache_pos", Vector2(-99999, -99999))
	if player["pos"].distance_squared_to(floor_cache) > 144.0:
		floor_style = _floor_at(world, player["pos"])
		player["floor_cache_pos"] = player["pos"]
	player["floor"] = floor_style
	var floor_mods := _floor_mods(floor_style)
	speed_mult *= float(floor_mods["speed"])
	# Facing gait last — looking away always costs pace (PZ strafe/backpedal).
	speed_mult *= facing_mult
	var desired_vel: Vector2 = move_dir * float(player["speed"]) * speed_mult
	var move_resp := MOVE_ACCEL_RESP
	var cur_vel: Vector2 = player.get("vel", Vector2.ZERO)
	if desired_vel.length_squared() < 1e-4:
		move_resp = MOVE_STOP_RESP
	elif was_sprinting and not bool(player["sprinting"]):
		# Release shift — dump run speed immediately so it doesn't coast.
		move_resp = MOVE_STOP_RESP * 1.35
	elif bool(player["sprinting"]) and can_sprint:
		move_resp = MOVE_SPRINT_RESP
	elif want_brace:
		move_resp = MOVE_BRACE_RESP
	elif cur_vel.length_squared() > 1e-4 and desired_vel.dot(cur_vel) < 0.0:
		move_resp = MOVE_REVERSE_RESP
	player["vel"] = _smooth_vec(cur_vel, desired_vel, move_resp, dt)
	_move_actor(player, player["vel"] * dt, world["obstacles"])
	_clamp_to_map(player, float(world["width"]), float(world["height"]))
	if bool(player["sprinting"]) and can_sprint:
		world["sprint_meters"] = float(world.get("sprint_meters", 0.0)) + float(player["speed"]) * speed_mult * dt
		while float(world["sprint_meters"]) >= 110.0:
			world["sprint_meters"] = float(world["sprint_meters"]) - 110.0
			world["skill_deeds"] = int(world.get("skill_deeds", 0)) + 1

	_tick_blood_trail(world, dt)

	var want_aim: Vector2 = look_dir
	var aim_resp := AIM_TURN_RESP
	if bool(player["sprinting"]) and can_sprint:
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
		sprint_r *= float(_floor_mods(String(player.get("floor", "dirt")))["hear"])
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
		walk_r *= float(_floor_mods(String(player.get("floor", "dirt")))["hear"])
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
	RaidRoamers.update(world, dt)
	_update_bullets(world, dt)
	_update_floats(world, dt)
	_refresh_interact_hint(world)
	_refresh_bag_cap(world)



# =============================================================================
# COMBAT — RELOAD / RECOIL / SUPPRESSION
# =============================================================================
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



# =============================================================================
# PLAYER VITALS — STAMINA / STANCE
# =============================================================================
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
	# No camera shake on fire — kick bloom already sells recoil without a screen wobble.
	# Refresh cone immediately so the next frame's wedge matches the kick.
	var stance_mult := _stance_spread_mult(player)
	player["aim_spread"] = (float(stats["spread"]) + float(player["recoil_bloom"])) * stance_mult * skill_mult



# =============================================================================
# NOISE / COMPASS
# =============================================================================
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



# =============================================================================
# INVENTORY / MEDKIT CHANNELS
# =============================================================================
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
		if d > float(c["radius"]) + float(player["radius"]) + 10.0:
			continue
		# No ghost-loot through walls, shut doors, or window frames.
		if not has_clear_reach(player["pos"], c["pos"], world["obstacles"], world.get("draw_chunks", {})):
			continue
		if d + bias < best:
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
		"ground_loot":
			return LOOT_CHANNEL_GROUND
		_:
			return LOOT_CHANNEL_CRATE



# =============================================================================
# INTERACT — DOORS / LOOT CHANNELS
# =============================================================================
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


static func _toggle_door(world: Dictionary, door: Dictionary) -> void:
	var center := Vector2(float(door["x"]) + float(door["w"]) * 0.5, float(door["y"]) + float(door["h"]) * 0.5)
	var player: Dictionary = world["player"]
	var opening := not bool(door.get("open", false))
	# Can't shut while anyone is standing in the doorway.
	if not opening and _doorway_occupied(world, door):
		_set_message(world, "Step clear of the door.", 1.1)
		_push_float(world, center, "BLOCKED", Color("e6b35a"), 0.55)
		return
	door["open"] = opening
	var quiet := bool(player.get("crouching", false)) and not bool(player.get("sprinting", false))
	var hp_ratio := float(player.get("hp", 1.0)) / maxf(1.0, float(player.get("max_hp", 1.0)))
	var wounded_clang := (not quiet) and hp_ratio <= WOUNDED_HP_RATIO
	var used_d := float(Items.inventory_used(world["inventory"]))
	var cap_d := maxf(1.0, float(world["inventory_cap"]))
	var heavy_clang := (not quiet) and (used_d / cap_d >= HEAVY_BAG_RATIO or bool(player.get("heavy_bag", false)))
	if opening:
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


static func _actor_overlaps_door(actor: Dictionary, door: Dictionary) -> bool:
	var r := Rect2(float(door["x"]), float(door["y"]), float(door["w"]), float(door["h"]))
	var rad := float(actor.get("radius", ACTOR_RADIUS))
	var p: Vector2 = actor["pos"]
	var nearest := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	return p.distance_squared_to(nearest) <= rad * rad


static func _doorway_occupied(world: Dictionary, door: Dictionary) -> bool:
	if _actor_overlaps_door(world["player"], door):
		return true
	for roamer in world.get("roamers", []):
		if not bool(roamer.get("alive", true)):
			continue
		if _actor_overlaps_door(roamer, door):
			return true
	return false


## Roamer pry — open a closed door in their path (not a sprint auto-bash).
static func open_door_for_roamer(world: Dictionary, door: Dictionary) -> void:
	if bool(door.get("open", false)):
		return
	door["open"] = true
	var center := Vector2(float(door["x"]) + float(door["w"]) * 0.5, float(door["y"]) + float(door["h"]) * 0.5)
	_push_float(world, center, "OPEN", Color("c45c5c"), 0.55)
	_emit_noise(world, center, HEAR_DOOR_PRY_RANGE * 0.85, NOISE_TTL_DOOR_PRY)


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
		"ground_loot":
			label = "Scooping loot…"
		_:
			label = "Prying crate…"
	if kind == "ground_loot":
		_set_message(world, "%s stay close." % label, dur + 0.2)
		_push_float(world, nearest["pos"], "SCOOP", Color("d2b48c"), 0.7)
		_emit_noise(world, player["pos"], HEAR_RANSACK_RANGE * 0.45, 0.35)
	else:
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
	if not has_clear_reach(player["pos"], target["pos"], world["obstacles"], world.get("draw_chunks", {})):
		_interrupt_loot(world, "Blocked — ransack cancelled.")
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
	var look_l: Vector2 = aim_world - (player["pos"] as Vector2)
	look_l = look_l.normalized() if look_l.length_squared() > 1e-6 else Vector2.RIGHT
	# Slow shuffle while hands are busy; crouch is even tighter; facing still matters.
	var shuffle := (0.22 if crouch else 0.28) * _facing_move_mult(move_dir, look_l)
	player["vel"] = move_dir * float(player["speed"]) * shuffle
	_move_actor(player, player["vel"] * dt, world["obstacles"])
	_clamp_to_map(player, float(world["width"]), float(world["height"]))
	player["aim"] = look_l
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
	RaidRoamers.update(world, dt)
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
	elif kind == "ground_loot":
		verb = "Scooped loot"
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



# =============================================================================
# GADGETS — DISTRACT TOSS
# =============================================================================
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



# =============================================================================
# MELEE / UNARMED
# =============================================================================
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
		if hp_ratio <= RaidRoamers.ROAMER_RETREAT_HP and not bool(target.get("elite", false)):
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


# =============================================================================
# GADGETS — INTEL / MARK FLARE
# =============================================================================
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
	world["shake"] = maxf(float(world.get("shake", 0.0)), 1.8)



# =============================================================================
# RAID RESOLVE / LOADOUT AFTERMATH
# =============================================================================
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


## Random clear drop-in — must stay far from every extract site.

# =============================================================================
# MAP GENERATION — DISTRICTS / ROADS / PREFABS
# =============================================================================
static func _ingress_spawn(obstacles: Array, candidates: Array = [], extract_sites: Array = []) -> Vector2:
	var picks: Array = []
	for p in candidates:
		var v: Vector2 = p
		if _spawn_far_from_extracts(v, extract_sites) and _place_away_from(obstacles, v.x, v.y, 22.0):
			picks.append(v)
	picks.shuffle()
	for v2 in picks:
		return v2
	# Search near valid candidates only (never seed from extract pads).
	for p2 in candidates:
		var base: Vector2 = p2
		if not _spawn_far_from_extracts(base, extract_sites):
			continue
		for _try in 12:
			var near := _rand_near(obstacles, base, 160.0, 22.0)
			if _spawn_far_from_extracts(near, extract_sites) and _place_away_from(obstacles, near.x, near.y, 22.0):
				return near
	# Last resort — scan map pockets away from extracts.
	for _scan in 80:
		var p3 := Vector2(randf_range(120.0, MAP_W - 120.0), randf_range(120.0, MAP_H - 120.0))
		if _spawn_far_from_extracts(p3, extract_sites) and _place_away_from(obstacles, p3.x, p3.y, 22.0):
			return p3
	return _roll_ingress_pos(extract_sites)


static func _spawn_far_from_extracts(pos: Vector2, extract_sites: Array) -> bool:
	for ex in extract_sites:
		var ep: Vector2 = ex["pos"] if ex is Dictionary else ex
		var pad := float(ex["radius"]) if ex is Dictionary and ex.has("radius") else 60.0
		if pos.distance_to(ep) < SPAWN_EXTRACT_MIN_DIST + pad:
			return false
	return true


## District compound — jittered cells, bent road graph, non-overlapping prefabs.
static func _build_field() -> Dictionary:
	var obstacles: Array = []
	var decals: Array = []
	var districts: Array = []
	var landmarks: Array = []
	var loot_spots: Array = []
	var roamer_anchors: Array = []
	var road_rects: Array = []
	var building_rects: Array = []
	var spawn_candidates: Array = []
	var door_id := -200
	var landmark_seq := 1
	var road_w := randf_range(88.0, 112.0)

	# Turf base is drawn solid in the scene — skip map-wide organic tiles (they thrash near compounds).

	# --- Random extract sites (edge-biased) + random ingress corner ---
	var extract_sites: Array = _roll_extract_sites()
	var ingress := _roll_ingress_pos(extract_sites)
	spawn_candidates.append(ingress)
	for _s in 6:
		spawn_candidates.append(ingress + Vector2(randf_range(-90, 90), randf_range(-90, 90)))

	# --- Jittered district cells with shuffled themes ---
	var cell_defs := _roll_district_cells(ingress)
	for d in cell_defs:
		var theme := String(d["theme"])
		# Compact wash around district center — keep small so roads stay readable.
		var cx := float(d["x"]) + float(d["w"]) * 0.5
		var cy := float(d["y"]) + float(d["h"]) * 0.5
		var ww := minf(float(d["w"]) * 0.38, 380.0)
		var hh := minf(float(d["h"]) * 0.38, 300.0)
		var wash := "yard"
		match theme:
			"ingress":
				wash = "pad"
			"yard":
				wash = "yard"
			"warehouse":
				wash = "asphalt"
			"ruins":
				wash = "dirt"
			"extract":
				wash = "gravel"
		# District aprons stay cheap rects — organic blobs are for field nature only.
		decals.append({
			"x": cx - ww * 0.5, "y": cy - hh * 0.5, "w": ww, "h": hh,
			"style": wash, "theme": theme,
		})
		districts.append(d.duplicate(true))
		if theme != "ingress":
			roamer_anchors.append(Vector2(cx, cy))
			landmarks.append({"id": landmark_seq, "name": String(d["name"]), "pos": Vector2(cx, cy), "kind": "district"})
			landmark_seq += 1

	# --- Road graph: bent segments between hubs (not full-map strips) ---
	var hubs: Array = [ingress]
	for ex in extract_sites:
		hubs.append(ex["pos"])
	for d2 in cell_defs:
		if String(d2["theme"]) == "ingress":
			continue
		hubs.append(Vector2(float(d2["x"]) + float(d2["w"]) * 0.5, float(d2["y"]) + float(d2["h"]) * 0.5))
	# Asphalt to extracts; dirt tracks between districts (reference mix).
	for i in extract_sites.size():
		_append_road_path(decals, road_rects, ingress, extract_sites[i]["pos"], road_w, "road")
	var district_hubs: Array = hubs.slice(1 + extract_sites.size())
	district_hubs.shuffle()
	for i in mini(district_hubs.size() - 1, 10):
		var track := "dirt_road" if randf() < 0.55 else "road"
		_append_road_path(decals, road_rects, district_hubs[i], district_hubs[i + 1], road_w * 0.85, track)
	# Extra cross-links so the larger grid doesn't leave dead ends.
	if district_hubs.size() >= 4:
		_append_road_path(decals, road_rects, district_hubs[0], district_hubs[district_hubs.size() - 1], road_w * 0.8, "dirt_road")
		_append_road_path(
			decals, road_rects,
			district_hubs[1],
			district_hubs[mini(district_hubs.size() - 1, 5)],
			road_w * 0.75,
			"road" if randf() < 0.45 else "dirt_road"
		)

	# Ingress / extract pads — compact apron (no giant yellow wash under compounds).
	decals.append({"x": ingress.x - 70.0, "y": ingress.y - 70.0, "w": 140.0, "h": 140.0, "style": "pad", "theme": "ingress"})
	for ex in extract_sites:
		var ep: Vector2 = ex["pos"]
		decals.append({"x": ep.x - 64.0, "y": ep.y - 64.0, "w": 128.0, "h": 128.0, "style": "pad", "theme": "extract"})
		decals.append({"x": ep.x - 48.0, "y": ep.y - 48.0, "w": 96.0, "h": 96.0, "style": "asphalt", "theme": "extract"})
		roamer_anchors.append(ep)
		loot_spots.append({"pos": ep, "radius": 140.0, "prefer": "ground"})
		# Never add extract pads to spawn_candidates — that was dropping players on lifts.

	# Cheap road shoulders (rects, not organic blobs) + sparse verge props.
	for i in mini(road_rects.size(), 14):
		var rr: Rect2 = road_rects[i]
		if mini(rr.size.x, rr.size.y) > road_w * 1.2:
			continue  # junction pad
		var horiz := rr.size.x >= rr.size.y
		var side_n := Vector2(0, 1) if horiz else Vector2(1, 0)
		var shoulder_w := 28.0
		if horiz:
			decals.append({
				"x": rr.position.x, "y": rr.position.y - shoulder_w,
				"w": rr.size.x, "h": shoulder_w, "style": "gravel", "theme": "nature",
			})
			decals.append({
				"x": rr.position.x, "y": rr.end.y,
				"w": rr.size.x, "h": shoulder_w, "style": "gravel", "theme": "nature",
			})
		else:
			decals.append({
				"x": rr.position.x - shoulder_w, "y": rr.position.y,
				"w": shoulder_w, "h": rr.size.y, "style": "gravel", "theme": "nature",
			})
			decals.append({
				"x": rr.end.x, "y": rr.position.y,
				"w": shoulder_w, "h": rr.size.y, "style": "gravel", "theme": "nature",
			})
		var side := side_n if randf() < 0.5 else -side_n
		var along := rr.get_center() + side * (road_w * 0.7 + 56.0)
		var verge := Rect2(along.x - 36, along.y - 28, 72, 56)
		if _rect_hits_reserved(verge, road_rects, [], extract_sites, ingress):
			continue
		if _rect_hits_solids(verge, obstacles, 10.0):
			continue
		if randf() < 0.55:
			_try_place_prop(obstacles, along + Vector2(randf_range(-16, 16), randf_range(-12, 12)), "tree" if randf() < 0.6 else "bush", randf_range(52.0, 78.0))
		elif randf() < 0.4:
			_try_place_prop(obstacles, along, "rock", randf_range(26.0, 42.0))
		if randf() < 0.35:
			loot_spots.append({"pos": along, "radius": 90.0, "prefer": "ground"})

	# --- Buildings: reject road / extract / other-building overlap ---
	var shed_names := ["Tool Shed", "Guard Hut", "Side Shed", "Pump House"]
	var wh_names := ["Warehouse A", "Warehouse B", "Cold Store", "Loading Bay"]
	var yard_names := ["Courtyard", "Motor Pool", "Open Yard", "Scrap Court"]
	var bunker_names := ["Bunker", "Hard Room", "Vault Cell", "Armory"]
	var name_i := 0

	for d in cell_defs:
		var theme := String(d["theme"])
		if theme == "ingress":
			continue
		var dx := float(d["x"])
		var dy := float(d["y"])
		var dw := float(d["w"])
		var dh := float(d["h"])
		var count := 3
		var styles: Array = ["shed", "shed", "shed"]
		match theme:
			"yard":
				count = 3 + randi() % 3
				styles = ["courtyard", "shed", "shed", "shed", "courtyard"]
			"warehouse":
				count = 3 + randi() % 3
				styles = ["warehouse", "warehouse", "shed", "shed", "warehouse"]
			"ruins":
				count = 4 + randi() % 3
				styles = ["shed", "courtyard", "bunker", "shed", "shed", "courtyard"]
			"extract":
				count = 2 + randi() % 2
				styles = ["bunker", "shed", "shed"]
		styles.shuffle()
		for bi in count:
			var prefab := String(styles[bi % styles.size()])
			var bw := 200.0
			var bh := 170.0
			match prefab:
				"shed":
					bw = randf_range(220.0, 320.0)
					bh = randf_range(190.0, 270.0)
				"warehouse":
					bw = randf_range(440.0, 620.0)
					bh = randf_range(260.0, 360.0)
				"courtyard":
					bw = randf_range(360.0, 500.0)
					bh = randf_range(300.0, 420.0)
				"bunker":
					bw = randf_range(240.0, 340.0)
					bh = randf_range(210.0, 300.0)
			var placed := false
			for _try in 28:
				var ox := dx + randf_range(24.0, maxf(24.0, dw - bw - 24.0))
				var oy := dy + randf_range(24.0, maxf(24.0, dh - bh - 24.0))
				# Bias toward roads so compounds plug into the street grid.
				if (not road_rects.is_empty()) and _try < 18:
					var rr: Rect2 = road_rects[randi() % road_rects.size()]
					if rr.size.x >= rr.size.y:
						ox = clampf(rr.get_center().x + randf_range(-bw * 0.35, bw * 0.35) - bw * 0.5, dx + 20.0, dx + dw - bw - 20.0)
						oy = clampf(rr.end.y + randf_range(6.0, 36.0), dy + 20.0, dy + dh - bh - 20.0)
						if randf() < 0.5:
							oy = clampf(rr.position.y - bh - randf_range(6.0, 36.0), dy + 20.0, dy + dh - bh - 20.0)
					else:
						oy = clampf(rr.get_center().y + randf_range(-bh * 0.35, bh * 0.35) - bh * 0.5, dy + 20.0, dy + dh - bh - 20.0)
						ox = clampf(rr.end.x + randf_range(6.0, 36.0), dx + 20.0, dx + dw - bw - 20.0)
						if randf() < 0.5:
							ox = clampf(rr.position.x - bw - randf_range(6.0, 36.0), dx + 20.0, dx + dw - bw - 20.0)
				var foot := Rect2(ox - 10.0, oy - 10.0, bw + 20.0, bh + 20.0)
				if _rect_hits_reserved(foot, road_rects, building_rects, extract_sites, ingress):
					continue
				building_rects.append(Rect2(ox, oy, bw, bh))
				# Apron + interior floor (thin-wall inset).
				decals.append({
					"x": ox - 14.0, "y": oy - 14.0, "w": bw + 28.0, "h": bh + 28.0,
					"style": "pad", "theme": theme,
				})
				if prefab != "courtyard":
					decals.append({
						"x": ox + 12.0, "y": oy + 12.0, "w": bw - 24.0, "h": bh - 24.0,
						"style": "interior", "theme": theme,
					})
				else:
					decals.append({
						"x": ox + 12.0, "y": oy + 12.0, "w": bw - 24.0, "h": bh - 24.0,
						"style": "yard", "theme": theme,
					})
				var bname := "Structure"
				match prefab:
					"shed":
						bname = shed_names[name_i % shed_names.size()]
					"warehouse":
						bname = wh_names[name_i % wh_names.size()]
					"courtyard":
						bname = yard_names[name_i % yard_names.size()]
					"bunker":
						bname = bunker_names[name_i % bunker_names.size()]
				name_i += 1
				var center_b := Vector2(ox + bw * 0.5, oy + bh * 0.5)
				landmarks.append({"id": landmark_seq, "name": bname, "pos": center_b, "kind": prefab})
				landmark_seq += 1
				door_id = _append_prefab(obstacles, Vector2(ox, oy), bw, bh, prefab, door_id)
				var door_out := Vector2(ox + bw + 4.0, oy + bh * 0.5)
				_append_door_apron(decals, door_out)
				_append_structure_road_link(decals, road_rects, door_out, Rect2(ox, oy, bw, bh))
				_append_building_sidewalk(decals, road_rects, Rect2(ox, oy, bw, bh))
				var prefer := "crate"
				if prefab == "bunker" or prefab == "warehouse":
					prefer = "specialty"
				elif prefab == "courtyard":
					prefer = "ground"
				loot_spots.append({"pos": center_b, "radius": 70.0, "prefer": prefer})
				loot_spots.append({"pos": center_b + Vector2(randf_range(-30, 30), randf_range(-24, 24)), "radius": 70.0, "prefer": prefer})
				# Cover beside the stoop — never stacked in the doorway lane.
				var cover_at := Vector2(ox + bw + 48.0, oy + bh * 0.5 + 58.0)
				if randf() < 0.5:
					cover_at.y = oy + bh * 0.5 - 58.0
				if not _rect_hits_reserved(Rect2(cover_at.x - 24, cover_at.y - 24, 48, 48), road_rects, building_rects, extract_sites, ingress) \
						and not _rect_hits_solids(Rect2(cover_at.x - 24, cover_at.y - 24, 48, 48), obstacles, 8.0):
					_append_cover_cluster(obstacles, cover_at, 1 + randi() % 2)
				roamer_anchors.append(center_b)
				placed = true
				break
			if not placed:
				continue

	# Guarantee each prefab style exists (smoke + visual variety) even on unlucky rolls.
	var have := {}
	for o in obstacles:
		have[String(o.get("style", ""))] = true
	for need in ["shed", "warehouse", "courtyard", "bunker"]:
		if have.has(need):
			continue
		var nw := 200.0
		var nh := 170.0
		match need:
			"warehouse":
				nw = 380.0
				nh = 220.0
			"courtyard":
				nw = 300.0
				nh = 260.0
			"bunker":
				nw = 200.0
				nh = 180.0
		for _g in 30:
			var gx := randf_range(200.0, MAP_W - nw - 200.0)
			var gy := randf_range(200.0, MAP_H - nh - 200.0)
			var gf := Rect2(gx - 16.0, gy - 16.0, nw + 32.0, nh + 32.0)
			if _rect_hits_reserved(gf, road_rects, building_rects, extract_sites, ingress):
				continue
			building_rects.append(Rect2(gx, gy, nw, nh))
			door_id = _append_prefab(obstacles, Vector2(gx, gy), nw, nh, need, door_id)
			landmarks.append({"id": landmark_seq, "name": need.capitalize(), "pos": Vector2(gx + nw * 0.5, gy + nh * 0.5), "kind": need})
			landmark_seq += 1
			loot_spots.append({"pos": Vector2(gx + nw * 0.5, gy + nh * 0.5), "radius": 70.0, "prefer": "specialty" if need in ["bunker", "warehouse"] else "crate"})
			break

	# Sparse rubble off roads / buildings / other solids.
	for _i in 12:
		var w := randf_range(36.0, 90.0)
		var h := randf_range(32.0, 80.0)
		var ox := randf_range(80.0, MAP_W - w - 80.0)
		var oy := randf_range(80.0, MAP_H - h - 80.0)
		var foot2 := Rect2(ox, oy, w, h)
		if _rect_hits_reserved(foot2.grow(24.0), road_rects, building_rects, extract_sites, ingress):
			continue
		if _rect_hits_solids(foot2, obstacles, 12.0):
			continue
		obstacles.append({
			"x": ox, "y": oy, "w": w, "h": h,
			"style": "rubble" if randf() < 0.55 else "prop",
			"kind": "solid",
		})

	# Nature + field clutter — grass washes, trees, rocks, ponds (keeps compounds from reading empty).
	_scatter_nature(decals, obstacles, road_rects, building_rects, extract_sites, ingress)

	# Keep door lanes and pads clear after all clutter rolls.
	_carve_door_clearance(obstacles)
	_carve_clear_disk(obstacles, ingress, 160.0)
	for ex3 in extract_sites:
		_carve_clear_disk(obstacles, ex3["pos"], 120.0)

	# Final filter — only hand create_raid_world candidates that are extract-safe.
	var safe_spawns: Array = []
	for sc in spawn_candidates:
		var sv: Vector2 = sc
		if _spawn_far_from_extracts(sv, extract_sites):
			safe_spawns.append(sv)
	if safe_spawns.is_empty():
		safe_spawns.append(ingress)

	return {
		"obstacles": obstacles,
		"decals": decals,
		"districts": districts,
		"landmarks": landmarks,
		"loot_spots": loot_spots,
		"roamer_anchors": roamer_anchors,
		"spawn_candidates": safe_spawns,
		"extract_sites": extract_sites,
	}


## Bin decals/obstacles into spatial cells for view cull + LOS/floor probes.

# =============================================================================
# SPATIAL INDEX
# =============================================================================
static func _build_spatial_index(decals: Array, obstacles: Array) -> Dictionary:
	var cells := {}
	for i in decals.size():
		var d: Dictionary = decals[i]
		_spatial_put(cells, float(d["x"]), float(d["y"]), float(d["w"]), float(d["h"]), i, true)
	for i in obstacles.size():
		var o: Dictionary = obstacles[i]
		# Fringe forest is paint-only — keep it out of LOS/collision bins.
		if String(o.get("kind", "")) == "deco" or bool(o.get("fringe", false)):
			continue
		_spatial_put(cells, float(o["x"]), float(o["y"]), float(o["w"]), float(o["h"]), i, false)
	return {
		"size": SPATIAL_CHUNK,
		"cells": cells,
		"obstacle_count": obstacles.size(),
		"decal_count": decals.size(),
	}


static func _spatial_put(
	cells: Dictionary, x: float, y: float, w: float, h: float, idx: int, is_decal: bool
) -> void:
	var cs := SPATIAL_CHUNK
	var x0 := int(floor(x / cs))
	var y0 := int(floor(y / cs))
	var x1 := int(floor((x + maxf(1.0, w)) / cs))
	var y1 := int(floor((y + maxf(1.0, h)) / cs))
	for cx in range(x0, x1 + 1):
		for cy in range(y0, y1 + 1):
			var key := "%d:%d" % [cx, cy]
			if not cells.has(key):
				cells[key] = {"d": [], "o": []}
			if is_decal:
				cells[key]["d"].append(idx)
			else:
				cells[key]["o"].append(idx)


static func _roll_extract_sites() -> Array:
	## Four edge lifts with pressure roles; positions jitter so layouts diverge.
	var sites: Array = [
		{
			"pressure": "hot",
			"pos": Vector2(MAP_W - randf_range(140, 320), randf_range(120, 280)),
			"alarm_radius": 1900.0, "hold_seconds": 2.1, "contest_pad": 0.18, "bleed_mult": 1.35, "radius": 58.0,
		},
		{
			"pressure": "quiet",
			"pos": Vector2(randf_range(120, 300), randf_range(120, 280)),
			"alarm_radius": 700.0, "hold_seconds": 4.2, "contest_pad": 0.06, "bleed_mult": 0.7, "radius": 52.0,
		},
		{
			"pressure": "contested",
			"pos": Vector2(MAP_W * randf_range(0.38, 0.62), MAP_H - randf_range(120, 280)),
			"alarm_radius": EXTRACT_ALARM_RADIUS, "hold_seconds": 2.9, "contest_pad": 0.12, "bleed_mult": 1.0, "radius": 56.0,
		},
		{
			"pressure": "contested",
			"pos": Vector2(MAP_W - randf_range(140, 300), MAP_H * randf_range(0.42, 0.68)),
			"alarm_radius": 1100.0, "hold_seconds": 3.3, "contest_pad": 0.1, "bleed_mult": 0.95, "radius": 54.0,
		},
	]
	return sites


static func _roll_ingress_pos(extract_sites: Array) -> Vector2:
	## Drop-in away from extracts — random edge pocket each run.
	var best := Vector2(280, MAP_H - 280)
	var best_d := -1.0
	for _i in 48:
		var edge := randi() % 4
		var c: Vector2
		match edge:
			0: # south
				c = Vector2(randf_range(180, MAP_W - 180), MAP_H - randf_range(180, 520))
			1: # north
				c = Vector2(randf_range(180, MAP_W - 180), randf_range(180, 520))
			2: # west
				c = Vector2(randf_range(180, 520), randf_range(180, MAP_H - 180))
			_: # east
				c = Vector2(MAP_W - randf_range(180, 520), randf_range(180, MAP_H - 180))
		if not _spawn_far_from_extracts(c, extract_sites):
			# Track farthest fallback so we never silently pick an extract apron.
			var mind := INF
			for ex in extract_sites:
				mind = minf(mind, c.distance_to(ex["pos"]))
			if mind > best_d:
				best_d = mind
				best = c
			continue
		return c
	return best


static func _roll_district_cells(ingress: Vector2) -> Array:
	## Soft 4×4 grid with jitter — more compounds across the larger map.
	var cols: Array = [0.0]
	var rows: Array = [0.0]
	for i in 3:
		cols.append(MAP_W * ((float(i) + 1.0) * 0.25 + randf_range(-0.03, 0.03)))
		rows.append(MAP_H * ((float(i) + 1.0) * 0.25 + randf_range(-0.03, 0.03)))
	cols.append(MAP_W)
	rows.append(MAP_H)
	cols.sort()
	rows.sort()
	var themes: Array = [
		"yard", "warehouse", "ruins", "warehouse",
		"extract", "yard", "ruins", "warehouse",
		"yard", "ruins", "extract", "warehouse",
		"yard", "ruins", "warehouse",
	]
	themes.shuffle()
	var names := [
		"Yards", "Warehouse Row", "Ruins", "East Sheds",
		"North Approach", "South Approach", "Scrap Lot", "Hard Zone",
		"Motor Court", "Cold Stores", "West Quarters", "Central Lot",
		"Tank Farm", "Rail Spur", "Outer Pens",
	]
	var cells: Array = []
	var ti := 0
	for gy in 4:
		for gx in 4:
			var x0 := float(cols[gx])
			var y0 := float(rows[gy])
			var x1 := float(cols[gx + 1])
			var y1 := float(rows[gy + 1])
			var cell := Rect2(x0, y0, x1 - x0, y1 - y0)
			if cell.has_point(ingress):
				cells.append({"x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0, "theme": "ingress", "name": "Ingress"})
				continue
			var theme := String(themes[ti % themes.size()])
			var nm := String(names[ti % names.size()])
			ti += 1
			cells.append({"x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0, "theme": theme, "name": nm})
	return cells


## Corridor — asphalt uses hard elbows; dirt tracks wander with organic blobs.
static func _append_road_path(
	decals: Array, road_rects: Array, a: Vector2, b: Vector2, road_w: float, style: String = "road"
) -> void:
	if style == "dirt_road":
		_append_dirt_track(decals, road_rects, a, b, road_w)
		return
	var mid := Vector2(
		lerpf(a.x, b.x, randf_range(0.4, 0.6)) + randf_range(-70.0, 70.0),
		lerpf(a.y, b.y, randf_range(0.4, 0.6)) + randf_range(-55.0, 55.0)
	)
	mid.x = clampf(mid.x, 140.0, MAP_W - 140.0)
	mid.y = clampf(mid.y, 140.0, MAP_H - 140.0)
	var elbows: Array = []
	if randf() < 0.5:
		elbows = [Vector2(mid.x, a.y), Vector2(mid.x, b.y)]
		_append_road_segment(decals, road_rects, a, elbows[0], road_w, style)
		_append_road_segment(decals, road_rects, elbows[0], elbows[1], road_w, style)
		_append_road_segment(decals, road_rects, elbows[1], b, road_w, style)
	else:
		elbows = [Vector2(a.x, mid.y), Vector2(b.x, mid.y)]
		_append_road_segment(decals, road_rects, a, elbows[0], road_w, style)
		_append_road_segment(decals, road_rects, elbows[0], elbows[1], road_w, style)
		_append_road_segment(decals, road_rects, elbows[1], b, road_w, style)
	for el in elbows:
		_append_road_junction(decals, road_rects, el, road_w)
	_append_road_junction(decals, road_rects, a, road_w * 0.85)
	_append_road_junction(decals, road_rects, b, road_w * 0.85)


## Winding dirt track — polyline with jitter, painted as organic blobs.
static func _append_dirt_track(decals: Array, road_rects: Array, a: Vector2, b: Vector2, road_w: float) -> void:
	var pts: Array = [a]
	var steps := 3 + randi() % 3
	for i in steps:
		var t := float(i + 1) / float(steps + 1)
		var p := a.lerp(b, t)
		p += Vector2(randf_range(-140.0, 140.0), randf_range(-110.0, 110.0))
		p.x = clampf(p.x, 120.0, MAP_W - 120.0)
		p.y = clampf(p.y, 120.0, MAP_H - 120.0)
		pts.append(p)
	pts.append(b)
	for i in pts.size() - 1:
		var p0: Vector2 = pts[i]
		var p1: Vector2 = pts[i + 1]
		_append_road_segment(decals, road_rects, p0, p1, road_w * randf_range(0.75, 1.05), "dirt_road")


## Paint-only ground wash — cheap rects (organic disks were thrashing near compounds).
static func _append_organic_wash(
	decals: Array, center: Vector2, w: float, h: float, style: String, theme: String = "nature"
) -> void:
	decals.append({
		"x": center.x - w * 0.5, "y": center.y - h * 0.5,
		"w": w, "h": h,
		"style": style, "theme": theme,
		"organic": style == "pond", "seed": randi(),
	})


static func _append_road_junction(decals: Array, road_rects: Array, at: Vector2, road_w: float) -> void:
	var s := road_w * 1.05
	var r := Rect2(at.x - s * 0.5, at.y - s * 0.5, s, s)
	for existing in road_rects:
		var er: Rect2 = existing
		if er.intersects(r):
			var overlap := er.intersection(r)
			if overlap.get_area() > r.get_area() * 0.65:
				return
	road_rects.append(r)
	decals.append({"x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y, "style": "junction"})


static func _append_road_segment(
	decals: Array, road_rects: Array, a: Vector2, b: Vector2, road_w: float, style: String = "road"
) -> void:
	var min_x := minf(a.x, b.x)
	var max_x := maxf(a.x, b.x)
	var min_y := minf(a.y, b.y)
	var max_y := maxf(a.y, b.y)
	# Skip degenerate stubs — they read as asphalt freckles.
	if absf(max_x - min_x) < 28.0 and absf(max_y - min_y) < 28.0:
		return
	var r: Rect2
	if absf(max_x - min_x) >= absf(max_y - min_y):
		r = Rect2(min_x, (a.y + b.y) * 0.5 - road_w * 0.5, maxf(28.0, max_x - min_x), road_w)
	else:
		r = Rect2((a.x + b.x) * 0.5 - road_w * 0.5, min_y, road_w, maxf(28.0, max_y - min_y))
	# Absorb into an existing co-linear segment instead of stacking translucent slabs.
	for i in road_rects.size():
		var er: Rect2 = road_rects[i]
		if not er.intersects(r.grow(4.0)):
			continue
		var same_h := absf(er.size.y - r.size.y) < 8.0 and absf(er.get_center().y - r.get_center().y) < 10.0 \
			and er.size.x >= er.size.y and r.size.x >= r.size.y
		var same_v := absf(er.size.x - r.size.x) < 8.0 and absf(er.get_center().x - r.get_center().x) < 10.0 \
			and er.size.y >= er.size.x and r.size.y >= r.size.x
		if same_h or same_v:
			var merged := er.merge(r)
			road_rects[i] = merged
			# Update matching decal in place (same surface style only).
			for d in decals:
				if String(d.get("style", "")) != style:
					continue
				if absf(float(d["x"]) - er.position.x) < 0.5 and absf(float(d["y"]) - er.position.y) < 0.5:
					d["x"] = merged.position.x
					d["y"] = merged.position.y
					d["w"] = merged.size.x
					d["h"] = merged.size.y
					return
			return
		var overlap := er.intersection(r)
		if overlap.get_area() > r.get_area() * 0.7:
			return
	road_rects.append(r)
	var d := {"x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y, "style": style}
	decals.append(d)


static func _rect_hits_reserved(foot: Rect2, road_rects: Array, building_rects: Array, extract_sites: Array, ingress: Vector2) -> bool:
	if foot.grow(40.0).has_point(ingress):
		return true
	for ex in extract_sites:
		var ep: Vector2 = ex["pos"]
		if foot.grow(30.0).has_point(ep) or foot.intersects(Rect2(ep.x - 100.0, ep.y - 100.0, 200.0, 200.0)):
			return true
	# Tight road margin — compounds may sit flush and link with driveways.
	for rr in road_rects:
		if foot.intersects((rr as Rect2).grow(2.0)):
			return true
	for br in building_rects:
		# Tighter spacing — denser compounds on the larger map.
		if foot.intersects((br as Rect2).grow(16.0)):
			return true
	return false


## Sidewalk strip on the building face closest to a road — compounds meet the street.
static func _append_building_sidewalk(decals: Array, road_rects: Array, foot: Rect2) -> void:
	if road_rects.is_empty():
		return
	var center := foot.get_center()
	var best_pt := center
	var best_d := INF
	for rr in road_rects:
		var r: Rect2 = rr
		var p := Vector2(clampf(center.x, r.position.x, r.end.x), clampf(center.y, r.position.y, r.end.y))
		var d := center.distance_to(p)
		if d < best_d:
			best_d = d
			best_pt = p
	if best_d > 130.0:
		return
	var sw := 22.0
	var to_road := best_pt - center
	if absf(to_road.x) >= absf(to_road.y):
		if to_road.x >= 0.0:
			decals.append({
				"x": foot.end.x, "y": foot.position.y + 8.0, "w": sw, "h": foot.size.y - 16.0,
				"style": "pad", "theme": "yard",
			})
		else:
			decals.append({
				"x": foot.position.x - sw, "y": foot.position.y + 8.0, "w": sw, "h": foot.size.y - 16.0,
				"style": "pad", "theme": "yard",
			})
	else:
		if to_road.y >= 0.0:
			decals.append({
				"x": foot.position.x + 8.0, "y": foot.end.y, "w": foot.size.x - 16.0, "h": sw,
				"style": "pad", "theme": "yard",
			})
		else:
			decals.append({
				"x": foot.position.x + 8.0, "y": foot.position.y - sw, "w": foot.size.x - 16.0, "h": sw,
				"style": "pad", "theme": "yard",
			})


## Road spur from door stoop — merges into the nearest street and pads the join.
static func _append_structure_road_link(
	decals: Array, road_rects: Array, door_out: Vector2, foot: Rect2 = Rect2()
) -> void:
	if road_rects.is_empty():
		return
	var best_pt := door_out
	var best_d := INF
	for rr in road_rects:
		var r: Rect2 = rr
		var p := Vector2(
			clampf(door_out.x, r.position.x, r.end.x),
			clampf(door_out.y, r.position.y, r.end.y)
		)
		var d := door_out.distance_to(p)
		if d < best_d:
			best_d = d
			best_pt = p
	if best_d < 6.0 or best_d > 260.0:
		return
	_append_road_segment(decals, road_rects, door_out, best_pt, 52.0, "road")
	# Junction blot at the street meet so the spur doesn't dead-end into a hard edge.
	_append_road_junction(decals, road_rects, best_pt, 56.0)
	# Extend building apron toward the road when close enough to read as connected.
	if foot.size.x > 1.0 and best_d < 120.0:
		var mid := door_out.lerp(best_pt, 0.45)
		decals.append({
			"x": mid.x - 36.0, "y": mid.y - 28.0, "w": 72.0, "h": 56.0,
			"style": "pad", "theme": "yard",
		})


## Prefab dispatcher — shed / warehouse / courtyard / bunker.
static func _append_prefab(obstacles: Array, origin: Vector2, bw: float, bh: float, prefab: String, door_id: int) -> int:
	match prefab:
		"warehouse":
			return _append_warehouse(obstacles, origin, bw, bh, door_id)
		"courtyard":
			return _append_courtyard(obstacles, origin, bw, bh, door_id)
		"bunker":
			return _append_bunker(obstacles, origin, bw, bh, door_id)
		_:
			return _append_shed(obstacles, origin, bw, bh, door_id)


static func _wall_rect(obstacles: Array, x: float, y: float, w: float, h: float, style: String = "building") -> void:
	obstacles.append({"x": x, "y": y, "w": w, "h": h, "style": style, "kind": "solid", "prefab": style})


static func _door_rect(obstacles: Array, x: float, y: float, w: float, h: float, door_id: int) -> void:
	obstacles.append({
		"x": x, "y": y, "w": w, "h": h,
		"kind": "door", "open": false, "id": door_id, "style": "door",
	})


static func _window_rect(obstacles: Array, x: float, y: float, w: float, h: float) -> void:
	obstacles.append({
		"x": x, "y": y, "w": w, "h": h,
		"kind": "window", "style": "window", "broken": false,
	})


## Long wall run with glass cuts — walk-blocked, LOS-open.
static func _wall_run_with_windows(
	obstacles: Array, x: float, y: float, w: float, h: float, style: String, want_windows: bool = true
) -> void:
	var horiz := w >= h
	var length := w if horiz else h
	if (not want_windows) or length < 110.0:
		_wall_rect(obstacles, x, y, w, h, style)
		return
	var win_len := mini(34.0, length * 0.22)
	var count := 1 if length < 200.0 else 2
	var cuts: Array = []
	for i in count:
		var at := length * (float(i) + 1.0) / float(count + 1) - win_len * 0.5
		cuts.append(clampf(at, 12.0, length - win_len - 12.0))
	var cursor := 0.0
	for cut_v in cuts:
		var cut := float(cut_v)
		var solid_len := cut - cursor
		if solid_len > 8.0:
			if horiz:
				_wall_rect(obstacles, x + cursor, y, solid_len, h, style)
			else:
				_wall_rect(obstacles, x, y + cursor, w, solid_len, style)
		if horiz:
			_window_rect(obstacles, x + cut, y, win_len, h)
		else:
			_window_rect(obstacles, x, y + cut, w, win_len)
		cursor = cut + win_len
	var rem := length - cursor
	if rem > 6.0:
		if horiz:
			_wall_rect(obstacles, x + cursor, y, rem, h, style)
		else:
			_wall_rect(obstacles, x, y + cursor, w, rem, style)


## Small 1-door room with light interior clutter.
static func _append_shed(obstacles: Array, origin: Vector2, bw: float, bh: float, door_id: int) -> int:
	var t := 14.0
	var ox := origin.x
	var oy := origin.y
	_wall_run_with_windows(obstacles, ox, oy, bw, t, "shed")
	_wall_run_with_windows(obstacles, ox, oy + bh - t, bw, t, "shed")
	_wall_run_with_windows(obstacles, ox, oy + t, t, bh - t * 2.0, "shed")
	var door_h := 56.0
	var door_y := oy + (bh - door_h) * 0.5
	var east_x := ox + bw - t
	var top_h := maxf(18.0, door_y - (oy + t))
	var bot_y := door_y + door_h
	var bot_h := maxf(18.0, (oy + bh - t) - bot_y)
	_wall_run_with_windows(obstacles, east_x, oy + t, t, top_h, "shed", top_h >= 70.0)
	_wall_run_with_windows(obstacles, east_x, bot_y, t, bot_h, "shed", bot_h >= 70.0)
	_door_rect(obstacles, east_x, door_y, t, door_h, door_id)
	if randf() < 0.75:
		var iw := randf_range(30.0, 56.0)
		var ih := randf_range(30.0, 56.0)
		obstacles.append({
			"x": ox + t + 18.0, "y": oy + t + 18.0, "w": iw, "h": ih,
			"style": "prop", "kind": "solid",
		})
	return door_id - 1


## Long hall, two doors, interior columns.
static func _append_warehouse(obstacles: Array, origin: Vector2, bw: float, bh: float, door_id: int) -> int:
	var t := 16.0
	var ox := origin.x
	var oy := origin.y
	_wall_run_with_windows(obstacles, ox, oy, bw, t, "warehouse")
	_wall_run_with_windows(obstacles, ox, oy + bh - t, bw, t, "warehouse")
	# West wall with north door.
	var door_h := 56.0
	var west_door_y := oy + bh * 0.28
	_wall_run_with_windows(obstacles, ox, oy + t, t, maxf(16.0, west_door_y - (oy + t)), "warehouse")
	_door_rect(obstacles, ox, west_door_y, t, door_h, door_id)
	door_id -= 1
	var west_bot_y := west_door_y + door_h
	_wall_run_with_windows(obstacles, ox, west_bot_y, t, maxf(16.0, (oy + bh - t) - west_bot_y), "warehouse")
	# East wall with south door.
	var east_x := ox + bw - t
	var east_door_y := oy + bh * 0.58
	_wall_run_with_windows(obstacles, east_x, oy + t, t, maxf(16.0, east_door_y - (oy + t)), "warehouse")
	_door_rect(obstacles, east_x, east_door_y, t, door_h, door_id)
	door_id -= 1
	var east_bot_y := east_door_y + door_h
	_wall_run_with_windows(obstacles, east_x, east_bot_y, t, maxf(16.0, (oy + bh - t) - east_bot_y), "warehouse")
	# Interior support columns — break LOS down the hall.
	var cols := 2 + randi() % 2
	for ci in cols:
		var cx := ox + t + 40.0 + (bw - t * 2.0 - 80.0) * (float(ci) + 0.5) / float(cols)
		var cy := oy + bh * 0.5 - 18.0
		obstacles.append({
			"x": cx, "y": cy, "w": 36.0, "h": 36.0,
			"style": "column", "kind": "solid", "prefab": "warehouse",
		})
	# Side crates.
	obstacles.append({
		"x": ox + t + 24.0, "y": oy + t + 20.0, "w": 48.0, "h": 40.0,
		"style": "prop", "kind": "solid",
	})
	return door_id


## U-shape open toward the nearest road (south side open).
static func _append_courtyard(obstacles: Array, origin: Vector2, bw: float, bh: float, door_id: int) -> int:
	var t := 16.0
	var ox := origin.x
	var oy := origin.y
	_wall_run_with_windows(obstacles, ox, oy, bw, t, "courtyard")
	# West arm — optional door gap mid-wall.
	var door_h := 56.0
	var door_y := oy + bh * 0.45
	if randf() < 0.55:
		_wall_run_with_windows(obstacles, ox, oy + t, t, maxf(14.0, door_y - (oy + t)), "courtyard")
		_door_rect(obstacles, ox, door_y, t, door_h, door_id)
		door_id -= 1
		var west_bot := door_y + door_h
		_wall_run_with_windows(obstacles, ox, west_bot, t, maxf(14.0, (oy + bh - t) - west_bot), "courtyard")
	else:
		_wall_run_with_windows(obstacles, ox, oy + t, t, bh - t * 2.0, "courtyard")
	_wall_run_with_windows(obstacles, ox + bw - t, oy + t, t, bh - t * 2.0, "courtyard")
	# Partial south lips so the open mouth still reads as a courtyard.
	var lip := bw * 0.28
	_wall_rect(obstacles, ox, oy + bh - t, lip, t, "courtyard")
	_wall_rect(obstacles, ox + bw - lip, oy + bh - t, lip, t, "courtyard")
	# Interior yard props near edges.
	obstacles.append({
		"x": ox + t + 30.0, "y": oy + t + 24.0, "w": 50.0, "h": 36.0,
		"style": "prop", "kind": "solid",
	})
	obstacles.append({
		"x": ox + bw - t - 70.0, "y": oy + t + 30.0, "w": 44.0, "h": 50.0,
		"style": "prop", "kind": "solid",
	})
	return door_id


## Hardened room — slightly thicker walls, slit windows, single door.
static func _append_bunker(obstacles: Array, origin: Vector2, bw: float, bh: float, door_id: int) -> int:
	var t := 22.0
	var ox := origin.x
	var oy := origin.y
	_wall_run_with_windows(obstacles, ox, oy, bw, t, "bunker")
	_wall_run_with_windows(obstacles, ox, oy + bh - t, bw, t, "bunker")
	_wall_run_with_windows(obstacles, ox, oy + t, t, bh - t * 2.0, "bunker")
	var door_h := 52.0
	var door_y := oy + (bh - door_h) * 0.5
	var east_x := ox + bw - t
	var top_h := maxf(14.0, door_y - (oy + t))
	var bot_y := door_y + door_h
	var bot_h := maxf(14.0, (oy + bh - t) - bot_y)
	_wall_run_with_windows(obstacles, east_x, oy + t, t, top_h, "bunker", top_h >= 60.0)
	_wall_run_with_windows(obstacles, east_x, bot_y, t, bot_h, "bunker", bot_h >= 60.0)
	_door_rect(obstacles, east_x, door_y, t, door_h, door_id)
	# Dense interior — desks / racks.
	obstacles.append({
		"x": ox + t + 16.0, "y": oy + t + 16.0, "w": 52.0, "h": 40.0,
		"style": "prop", "kind": "solid",
	})
	obstacles.append({
		"x": ox + bw * 0.45, "y": oy + bh * 0.42, "w": 40.0, "h": 56.0,
		"style": "prop", "kind": "solid",
	})
	obstacles.append({
		"x": ox + t + 20.0, "y": oy + bh - t - 50.0, "w": 60.0, "h": 32.0,
		"style": "prop", "kind": "solid",
	})
	return door_id - 1


static func _append_cover_cluster(obstacles: Array, at: Vector2, count: int) -> void:
	for i in count:
		var w := randf_range(42.0, 74.0)
		var h := randf_range(36.0, 68.0)
		var ox := at.x + randf_range(-40.0, 40.0) - w * 0.5
		var oy := at.y + randf_range(-32.0, 32.0) - h * 0.5
		if ox < 40.0 or oy < 40.0 or ox + w > MAP_W - 40.0 or oy + h > MAP_H - 40.0:
			continue
		var style := "prop"
		if i == 0:
			style = "sandbag"
			if randf() < 0.55:
				w = randf_range(70.0, 120.0)
				h = 24.0
			else:
				w = 24.0
				h = randf_range(70.0, 120.0)
		elif i == 1 and randf() < 0.35:
			style = "fence"
			w = randf_range(80.0, 140.0)
			h = 12.0
		var foot := Rect2(ox, oy, w, h)
		if _rect_hits_solids(foot, obstacles, 10.0):
			continue
		obstacles.append({"x": ox, "y": oy, "w": w, "h": h, "style": style, "kind": "solid"})


## Stoop dust only — never dump rocks in the doorway lane.
static func _append_door_apron(decals: Array, at: Vector2) -> void:
	decals.append({
		"x": at.x - 10.0, "y": at.y - 28.0, "w": 54.0, "h": 56.0,
		"style": "gravel", "theme": "nature",
	})
	# Side litter only (above/below the lane), paint-only.
	decals.append({
		"x": at.x + 8.0, "y": at.y - 48.0, "w": 36.0, "h": 18.0,
		"style": "dirt", "theme": "nature",
	})
	decals.append({
		"x": at.x + 8.0, "y": at.y + 30.0, "w": 36.0, "h": 18.0,
		"style": "dirt", "theme": "nature",
	})


static func _rect_hits_solids(foot: Rect2, obstacles: Array, pad: float = 8.0) -> bool:
	var g := foot.grow(pad)
	for o in obstacles:
		var r := Rect2(float(o["x"]), float(o["y"]), float(o["w"]), float(o["h"]))
		if g.intersects(r):
			return true
	return false


static func _try_place_prop(obstacles: Array, at: Vector2, style: String, size: float, fringe: bool = false) -> bool:
	var w := size
	var h := size
	var coll_r := size * 0.42
	if style == "tree":
		# Draw uses canopy bounds; collision is trunk-only.
		coll_r = size * 0.16
	elif style == "bush":
		h = size * randf_range(0.7, 0.95)
		coll_r = size * 0.34
	elif style == "rock":
		w = size * randf_range(0.85, 1.05)
		h = w
		coll_r = w * 0.4
	elif style == "log":
		w = size * randf_range(1.6, 2.2)
		h = size * randf_range(0.35, 0.5)
		coll_r = -1.0
	var x := at.x - w * 0.5
	var y := at.y - h * 0.5
	if fringe:
		# Skirt props may sit outside the playable rect; keep them inside the visual margin.
		var lo := -MAP_MARGIN + 24.0
		var hi_x := MAP_W + MAP_MARGIN - 24.0
		var hi_y := MAP_H + MAP_MARGIN - 24.0
		if x < lo or y < lo or x + w > hi_x or y + h > hi_y:
			return false
	else:
		# Canopy may overhang the playable edge; keep trunks on the map.
		var pad := -size * 0.35 if style in ["tree", "bush"] else 40.0
		if x < pad or y < pad or x + w > MAP_W - pad or y + h > MAP_H - pad:
			return false
	var foot := Rect2(x, y, w, h)
	if _rect_hits_solids(foot, obstacles, 14.0):
		return false
	var o := {
		"x": x, "y": y, "w": w, "h": h,
		"style": style,
		"kind": "deco" if fringe else "solid",
		"organic": style in ["tree", "bush", "rock"], "seed": randi(),
	}
	if fringe:
		o["fringe"] = true
	elif coll_r > 0.0:
		o["coll_r"] = coll_r
	obstacles.append(o)
	return true


## Strip clutter that landed in door approaches after scatter.
static func _carve_door_clearance(obstacles: Array) -> void:
	var zones: Array = []
	for o in obstacles:
		if String(o.get("kind", "")) != "door":
			continue
		var x := float(o["x"])
		var y := float(o["y"])
		var w := float(o["w"])
		var h := float(o["h"])
		# Tall thin doors open east/west; short wide doors open north/south.
		if h >= w:
			zones.append(Rect2(x - 48.0, y - 6.0, w + 96.0, h + 12.0))
		else:
			zones.append(Rect2(x - 6.0, y - 48.0, w + 12.0, h + 96.0))
	if zones.is_empty():
		return
	var keep: Array = []
	for o2 in obstacles:
		var kind := String(o2.get("kind", ""))
		if kind == "door" or kind == "window":
			keep.append(o2)
			continue
		var style := String(o2.get("style", ""))
		var is_build := style in ["shed", "warehouse", "courtyard", "bunker", "building", "column"]
		if is_build:
			keep.append(o2)
			continue
		var r := Rect2(float(o2["x"]), float(o2["y"]), float(o2["w"]), float(o2["h"]))
		var blocked := false
		for z in zones:
			if (z as Rect2).intersects(r):
				blocked = true
				break
		if not blocked:
			keep.append(o2)
	obstacles.clear()
	for k in keep:
		obstacles.append(k)


## Grass / mud washes + trees, bushes, rocks, logs, ponds — densifies empty yards.
static func _scatter_nature(
	decals: Array,
	obstacles: Array,
	road_rects: Array,
	building_rects: Array,
	extract_sites: Array,
	ingress: Vector2
) -> void:
	# Sparse ground patches away from compounds (cheap paint — not a full-map carpet).
	for _i in 10:
		var w := randf_range(90.0, 180.0)
		var h := randf_range(70.0, 140.0)
		var ox := randf_range(60.0, MAP_W - w - 60.0)
		var oy := randf_range(60.0, MAP_H - h - 60.0)
		var foot := Rect2(ox, oy, w, h)
		if _rect_hits_reserved(foot.grow(48.0), road_rects, building_rects, extract_sites, ingress):
			continue
		var wash_styles: Array = ["grass", "mud", "leaf", "scrub"]
		var style: String = wash_styles[randi() % wash_styles.size()]
		_append_organic_wash(decals, foot.get_center(), w, h, style, "nature")

	# Tree groves — spaced trunks, one leaf wash per grove (not per tree).
	for _g in 6:
		var gx := randf_range(200.0, MAP_W - 200.0)
		var gy := randf_range(200.0, MAP_H - 200.0)
		if _rect_hits_reserved(Rect2(gx - 40, gy - 40, 80, 80), road_rects, building_rects, extract_sites, ingress):
			continue
		_append_organic_wash(decals, Vector2(gx, gy), 180.0, 140.0, "leaf", "nature")
		var placed_trees := 0
		for _t in 5:
			var ts := randf_range(54.0, 82.0)
			var tx := gx + randf_range(-80.0, 80.0)
			var ty := gy + randf_range(-60.0, 60.0)
			if _rect_hits_reserved(Rect2(tx - ts * 0.5, ty - ts * 0.5, ts, ts).grow(12.0), road_rects, building_rects, extract_sites, ingress):
				continue
			if _try_place_prop(obstacles, Vector2(tx, ty), "tree", ts):
				placed_trees += 1
			if placed_trees >= 3:
				break

	# Ponds — organic water bodies, keep clear of roads.
	for _p in 2 + randi() % 2:
		var pw := randf_range(120.0, 220.0)
		var ph := randf_range(90.0, 180.0)
		var px := randf_range(120.0, MAP_W - pw - 120.0)
		var py := randf_range(120.0, MAP_H - ph - 120.0)
		var pf := Rect2(px, py, pw, ph)
		if _rect_hits_reserved(pf.grow(40.0), road_rects, building_rects, extract_sites, ingress):
			continue
		_append_organic_wash(decals, pf.get_center(), pw, ph, "pond", "nature")
		for _r in 3:
			var ang := randf() * TAU
			var rp := pf.get_center() + Vector2(cos(ang) * pw * 0.48, sin(ang) * ph * 0.48)
			_try_place_prop(obstacles, rp, "bush", randf_range(18.0, 28.0))

	# Loose field flora — must clear existing solids (no rock-on-tree stacks).
	for _t in 28:
		var flora: Array = ["tree", "tree", "bush", "rock", "log"]
		var kind: String = flora[randi() % flora.size()]
		var size := randf_range(40.0, 70.0)
		match kind:
			"tree":
				size = randf_range(56.0, 86.0)
			"bush":
				size = randf_range(40.0, 64.0)
			"rock":
				size = randf_range(22.0, 34.0)
			"log":
				size = randf_range(70.0, 110.0)
		var at := Vector2(randf_range(100.0, MAP_W - 100.0), randf_range(100.0, MAP_H - 100.0))
		var probe := Rect2(at.x - size * 0.5, at.y - size * 0.5, size, size)
		if _rect_hits_reserved(probe.grow(18.0), road_rects, building_rects, extract_sites, ingress):
			continue
		_try_place_prop(obstacles, at, kind, size)

	# Shipping-container style long props for industrial districts.
	for _c in 6:
		var cw := randf_range(140.0, 220.0)
		var ch := randf_range(48.0, 70.0)
		if randf() < 0.4:
			var tmp := cw
			cw = ch
			ch = tmp
		var cx := randf_range(100.0, MAP_W - cw - 100.0)
		var cy := randf_range(100.0, MAP_H - ch - 100.0)
		var cf := Rect2(cx, cy, cw, ch)
		if _rect_hits_reserved(cf.grow(20.0), road_rects, building_rects, extract_sites, ingress):
			continue
		if _rect_hits_solids(cf, obstacles, 12.0):
			continue
		obstacles.append({"x": cx, "y": cy, "w": cw, "h": ch, "style": "container", "kind": "solid"})

	# Map-edge tree belt — soft compound border like the forest ref.
	_scatter_edge_trees(obstacles, road_rects, building_rects, extract_sites, ingress)


static func _scatter_edge_trees(
	obstacles: Array,
	road_rects: Array,
	building_rects: Array,
	extract_sites: Array,
	ingress: Vector2
) -> void:
	# Outer forest skirt — paint-only, past the playable cutoff so the map doesn't hard-stop.
	for _i in 72:
		var edge := randi() % 4
		var ts := randf_range(58.0, 92.0)
		var tx: float
		var ty: float
		match edge:
			0: # north skirt
				tx = randf_range(-MAP_MARGIN + 40.0, MAP_W + MAP_MARGIN - ts - 40.0)
				ty = randf_range(-MAP_MARGIN + 20.0, -20.0)
			1: # south skirt
				tx = randf_range(-MAP_MARGIN + 40.0, MAP_W + MAP_MARGIN - ts - 40.0)
				ty = randf_range(MAP_H + 8.0, MAP_H + MAP_MARGIN - ts - 20.0)
			2: # west skirt
				tx = randf_range(-MAP_MARGIN + 20.0, -20.0)
				ty = randf_range(-MAP_MARGIN + 40.0, MAP_H + MAP_MARGIN - ts - 40.0)
			_: # east skirt
				tx = randf_range(MAP_W + 8.0, MAP_W + MAP_MARGIN - ts - 20.0)
				ty = randf_range(-MAP_MARGIN + 40.0, MAP_H + MAP_MARGIN - ts - 40.0)
		_try_place_prop(obstacles, Vector2(tx + ts * 0.5, ty + ts * 0.5), "tree" if randf() < 0.75 else "bush", ts, true)

	# Inner verge — denser belt just inside the playable edge (canopies may overhang).
	var belt := 180.0
	for _i in 56:
		var edge2 := randi() % 4
		var ts2 := randf_range(52.0, 86.0)
		var tx2: float
		var ty2: float
		match edge2:
			0:
				tx2 = randf_range(20.0, MAP_W - ts2 - 20.0)
				ty2 = randf_range(-ts2 * 0.25, belt)
			1:
				tx2 = randf_range(20.0, MAP_W - ts2 - 20.0)
				ty2 = randf_range(MAP_H - belt - ts2 * 0.5, MAP_H - ts2 * 0.35)
			2:
				tx2 = randf_range(-ts2 * 0.25, belt)
				ty2 = randf_range(20.0, MAP_H - ts2 - 20.0)
			_:
				tx2 = randf_range(MAP_W - belt - ts2 * 0.5, MAP_W - ts2 * 0.35)
				ty2 = randf_range(20.0, MAP_H - ts2 - 20.0)
		var at := Vector2(tx2 + ts2 * 0.5, ty2 + ts2 * 0.5)
		if _rect_hits_reserved(Rect2(tx2, ty2, ts2, ts2).grow(8.0), road_rects, building_rects, extract_sites, ingress):
			continue
		_try_place_prop(obstacles, at, "tree", ts2)

	# Corner thickets — edge-only scatter leaves corners thin and cut-off looking.
	var corners: Array = [
		Vector2(-MAP_MARGIN * 0.45, -MAP_MARGIN * 0.45),
		Vector2(MAP_W + MAP_MARGIN * 0.45, -MAP_MARGIN * 0.45),
		Vector2(-MAP_MARGIN * 0.45, MAP_H + MAP_MARGIN * 0.45),
		Vector2(MAP_W + MAP_MARGIN * 0.45, MAP_H + MAP_MARGIN * 0.45),
	]
	for corner in corners:
		for _c in 10:
			var ts3 := randf_range(60.0, 96.0)
			var jitter := Vector2(randf_range(-110.0, 110.0), randf_range(-110.0, 110.0))
			_try_place_prop(obstacles, corner + jitter, "tree" if randf() < 0.7 else "bush", ts3, true)


static func _obstacle_blocks(o: Dictionary) -> bool:
	# Open doors are passable slabs — still drawn, no collision.
	if String(o.get("kind", "")) == "door" and bool(o.get("open", false)):
		return false
	# Fringe forest is visual-only (outside / overhanging the playable rect).
	if String(o.get("kind", "")) == "deco" or bool(o.get("fringe", false)):
		return false
	return true


## Remove solids that overlap a clear disk (ingress / extract pads).
static func _carve_clear_disk(obstacles: Array, center: Vector2, radius: float) -> void:
	var keep: Array = []
	for o in obstacles:
		if String(o.get("kind", "")) == "door":
			keep.append(o)
			continue
		if String(o.get("kind", "")) == "deco" or bool(o.get("fringe", false)):
			keep.append(o)
			continue
		var r := Rect2(float(o["x"]), float(o["y"]), float(o["w"]), float(o["h"]))
		if r.get_center().distance_to(center) < radius + maxf(float(o["w"]), float(o["h"])) * 0.35:
			continue
		keep.append(o)
	obstacles.clear()
	for o2 in keep:
		obstacles.append(o2)


## Clear point near an anchor — falls back to global clear if jammed.
static func _rand_near(obstacles: Array, anchor: Vector2, radius: float, body_r: float) -> Vector2:
	for _try in 28:
		var ang := randf() * TAU
		var dist := randf_range(12.0, radius)
		var p := anchor + Vector2(cos(ang), sin(ang)) * dist
		p.x = clampf(p.x, 40.0, MAP_W - 40.0)
		p.y = clampf(p.y, 40.0, MAP_H - 40.0)
		if _place_away_from(obstacles, p.x, p.y, body_r):
			return p
	return _rand_clear_pos(obstacles, body_r, 60.0)


static func _obstacle_blocks_los(o: Dictionary) -> bool:
	# Glass (intact or broken) never blocks sight — only walls / shut doors do.
	if String(o.get("kind", "")) == "window":
		return false
	return _obstacle_blocks(o)


static func _obstacle_blocks_reach(o: Dictionary) -> bool:
	# Window frames always block looting/reaching, even after the pane breaks.
	if String(o.get("kind", "")) == "window":
		return true
	return _obstacle_blocks(o)


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
		"radius": float(extras.get("radius", ACTOR_RADIUS)),
		"facing": 0.0,
		"alive": true,
		"fire_cooldown": 0.0,
		"aim": Vector2.RIGHT,
		"aggro_range": float(extras.get("aggro_range", 220.0)),
		"speed": float(extras.get("speed", 90.0)),
		"damage": float(extras.get("damage", 10.0)),
		"mitigation": float(extras.get("mitigation", 0.0)),
		"hit_flash": 0.0,
		"vision_range": float(extras.get("vision_range", VISION_RANGE)),
	}


## Topmost floor decal under a point (roads beat washes).

# =============================================================================
# FLOOR / COLLISION / ACTOR HELPERS
# =============================================================================
static func _floor_at(world: Dictionary, pos: Vector2) -> String:
	var best := "dirt"
	var best_rank := -1
	var decals: Array = world.get("decals", [])
	var index: Dictionary = world.get("draw_chunks", {})
	var probe: Array = []
	if _spatial_index_matches(index, -1, decals.size()):
		var cells: Dictionary = index.get("cells", {})
		var cs := float(index.get("size", SPATIAL_CHUNK))
		var key := "%d:%d" % [int(floor(pos.x / cs)), int(floor(pos.y / cs))]
		var cell: Variant = cells.get(key, null)
		if cell != null:
			for di in cell["d"]:
				if di >= 0 and di < decals.size():
					probe.append(decals[di])
	else:
		probe = decals
	for d in probe:
		var style := String(d.get("style", ""))
		var rank := _floor_rank(style)
		if rank < 0:
			continue
		var r := Rect2(float(d["x"]), float(d["y"]), float(d["w"]), float(d["h"]))
		if not r.has_point(pos):
			continue
		if rank >= best_rank:
			best_rank = rank
			best = style
	return best


static func _floor_rank(style: String) -> int:
	match style:
		"road", "junction":
			return 50
		"dirt_road":
			return 45
		"interior":
			return 42
		"pad", "asphalt":
			return 40
		"gravel":
			return 30
		"pond":
			return 25
		"grass", "leaf", "scrub", "mud", "yard", "dirt":
			return 10
		_:
			return -1


static func _floor_mods(style: String) -> Dictionary:
	if FLOOR_MODS.has(style):
		return FLOOR_MODS[style]
	return {"speed": 1.0, "hear": 1.0, "vision": 1.0}


static func _obstacle_center(o: Dictionary) -> Vector2:
	return Vector2(float(o["x"]) + float(o["w"]) * 0.5, float(o["y"]) + float(o["h"]) * 0.5)


static func _point_hits_obstacle(p: Vector2, o: Dictionary) -> bool:
	var coll_r := float(o.get("coll_r", -1.0))
	if coll_r > 0.0:
		return p.distance_squared_to(_obstacle_center(o)) <= coll_r * coll_r
	return p.x >= float(o["x"]) and p.x <= float(o["x"]) + float(o["w"]) \
		and p.y >= float(o["y"]) and p.y <= float(o["y"]) + float(o["h"])


static func _place_away_from(obstacles: Array, x: float, y: float, r: float) -> bool:
	var p := Vector2(x, y)
	for o in obstacles:
		if not _obstacle_blocks(o):
			continue
		var coll_r := float(o.get("coll_r", -1.0))
		if coll_r > 0.0:
			if p.distance_squared_to(_obstacle_center(o)) <= (coll_r + r) * (coll_r + r):
				return false
			continue
		var cx := clampf(x, float(o["x"]), float(o["x"]) + float(o["w"]))
		var cy := clampf(y, float(o["y"]), float(o["y"]) + float(o["h"]))
		if (cx - x) * (cx - x) + (cy - y) * (cy - y) <= r * r:
			return false
	return true


static func _resolve_circle_rect(pos: Vector2, radius: float, o: Dictionary) -> Vector2:
	var coll_r := float(o.get("coll_r", -1.0))
	if coll_r > 0.0:
		var c := _obstacle_center(o)
		var min_d := coll_r + radius
		var delta := pos - c
		var d := delta.length()
		if d < 1e-5:
			return c + Vector2(min_d, 0.0)
		if d >= min_d:
			return pos
		return c + delta * (min_d / d)
	var ox := float(o["x"])
	var oy := float(o["y"])
	var ow := float(o["w"])
	var oh := float(o["h"])
	var nearest := Vector2(clampf(pos.x, ox, ox + ow), clampf(pos.y, oy, oy + oh))
	var delta2 := pos - nearest
	var d2 := delta2.length_squared()
	var buried := pos.x >= ox and pos.x <= ox + ow and pos.y >= oy and pos.y <= oy + oh
	# Buried or glued to the surface — face-eject (avoids radius/d explosions).
	if buried or d2 < 1e-6:
		var left := pos.x - ox if buried else absf(pos.x - ox)
		var right := ox + ow - pos.x if buried else absf(pos.x - (ox + ow))
		var top := pos.y - oy if buried else absf(pos.y - oy)
		var bottom := oy + oh - pos.y if buried else absf(pos.y - (oy + oh))
		var m := mini(mini(left, right), mini(top, bottom))
		if m == left:
			return Vector2(ox - radius, pos.y)
		if m == right:
			return Vector2(ox + ow + radius, pos.y)
		if m == top:
			return Vector2(pos.x, oy - radius)
		return Vector2(pos.x, oy + oh + radius)
	if d2 >= radius * radius:
		return pos
	return nearest + delta2 * (radius / sqrt(d2))


static func _collide_actor_obstacles(actor: Dictionary, obstacles: Array) -> void:
	for o in obstacles:
		if not _obstacle_blocks(o):
			continue
		actor["pos"] = _resolve_circle_rect(actor["pos"], float(actor["radius"]), o)


## Substep move so thin walls / windows can't be tunneled on a long frame.
static func _move_actor(actor: Dictionary, delta: Vector2, obstacles: Array) -> void:
	var dist := delta.length()
	if dist < 1e-6:
		return
	var steps := maxi(1, int(ceil(dist / 6.0)))
	var step := delta / float(steps)
	for _i in steps:
		actor["pos"] = actor["pos"] + step
		_collide_actor_obstacles(actor, obstacles)


## Sweep from a prior position after free AI writes (roamers).
static func _move_collide_from(actor: Dictionary, prev: Vector2, obstacles: Array) -> void:
	var delta: Vector2 = actor["pos"] - prev
	actor["pos"] = prev
	_move_actor(actor, delta, obstacles)


static func _clamp_to_map(actor: Dictionary, w: float, h: float) -> void:
	var r := float(actor["radius"])
	var p: Vector2 = actor["pos"]
	actor["pos"] = Vector2(clampf(p.x, r, w - r), clampf(p.y, r, h - r))



# =============================================================================
# PROJECTILES / EXTRACTS / BLEED / BLOOD
# =============================================================================
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
		"radius": 2.15,
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
	# Brush / dusk / mud thin sight; open asphalt keeps it a hair wider.
	var floor_v := _floor_at(world, player["pos"])
	player["floor"] = floor_v
	vision *= float(_floor_mods(floor_v)["vision"])
	player["vision_range"] = vision
	# Roamers hear a bit farther as the compound quiets — pressure without new HUD chrome.
	var hear_boost := lerpf(1.0, DUSK_HEAR_MAX, dusk)
	world["dusk_hear_mult"] = hear_boost
	if dusk > 0.02 and not bool(world.get("dusk_warned", false)):
		world["dusk_warned"] = true
		# No top banner — dusk already shows via wash + thinner fog.


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
		if d > float(c["radius"]) + float(player["radius"]) + 18.0:
			continue
		if not has_clear_reach(player["pos"], c["pos"], world["obstacles"], world.get("draw_chunks", {})):
			continue
		if d < best:
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
			"ground_loot":
				world["interact_hint"] = "E  scoop"
			_:
				world["interact_hint"] = "E  pry"
		return
	var door = _find_door_target(world)
	if door != null:
		if not bool(door.get("open", false)):
			world["interact_hint"] = "E  open"
		elif _actor_overlaps_door(player, door):
			world["interact_hint"] = "step clear"
		else:
			world["interact_hint"] = "E  shut"
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


static func _bullet_hits_obstacle(p: Vector2, obstacles: Array) -> bool:
	for o in obstacles:
		if String(o.get("kind", "")) == "window":
			# Broken panes no longer stop rounds; intact glass is handled in the step loop.
			if bool(o.get("broken", false)):
				continue
			if _point_hits_obstacle(p, o):
				return true
			continue
		if not _obstacle_blocks(o):
			continue
		if _point_hits_obstacle(p, o):
			return true
	return false


## Shatter an intact window under a bullet sample. Returns true if glass broke this step.
static func _try_break_window_at(world: Dictionary, p: Vector2) -> bool:
	for o in world["obstacles"]:
		if String(o.get("kind", "")) != "window" or bool(o.get("broken", false)):
			continue
		if not _point_hits_obstacle(p, o):
			continue
		o["broken"] = true
		var center := _obstacle_center(o)
		_emit_noise(world, center, 140.0, 0.35)
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
			# Intact glass shatters and the round keeps going; walls/doors still eat it.
			if _try_break_window_at(world, p):
				pass
			elif _bullet_hits_obstacle(p, world["obstacles"]):
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
						RaidRoamers.apply_suppression(roamer, ROAMER_SUPPRESS_GAP)
						suppressed[rid] = true
						b["roamer_suppress_ids"] = suppressed
					if dist_r <= float(roamer["radius"]) + float(b["radius"]):
						var dmg := float(b["damage"]) * (1.0 - float(roamer["mitigation"]))
						roamer["hp"] = float(roamer["hp"]) - dmg
						roamer["hit_flash"] = 0.12
						RaidRoamers.apply_suppression(roamer, ROAMER_SUPPRESS_HIT_GAP, ROAMER_SUPPRESS_TTL * 1.15)
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
					world["shake"] = maxf(float(world["shake"]), 2.4)
					_apply_suppression(world, pl, SUPPRESS_HIT_BLOOM, 0.75)
					_mark_threat_bearing(world, b.get("origin", p))
					# Hits break a settled plant — reacquire before the cone tightens again.
					pl["brace_hold"] = 0.0
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
						world["shake"] = 5.5
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
			"speed": randf_range(88.0, 108.0),
			"damage": randf_range(10.0, 16.0),
			"aggro_range": randf_range(280.0, 360.0),
			"mitigation": 0.08,
			"radius": ROAMER_RADIUS,
		}))
		var r: Dictionary = world["roamers"].back()
		r["alert_ttl"] = 4.0
		r["last_heard"] = zp
		r["last_seen"] = world["player"]["pos"]
		r["ai_state"] = "rush"
		r["patrol_anchor"] = zp
		r["patrol_waypoint"] = Vector2.ZERO
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
	world["shake"] = 5.5
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
