class_name Skills
extends RefCounted
## Player-driven ranks. Field reads modifiers; base spends/refunds points. Prefs: skills stay; no auto-reload.

const MAX_RANK := 3
const EGRESS_POINTS := 1
const EXTRACT_POINTS := EGRESS_POINTS  ## legacy alias

## Stable ids — order is base display order.
const IDS: Array[String] = [
	"endurance",
	"fieldcraft",
	"marksman",
	"packmule",
	"medic",
]


static func create_state() -> Dictionary:
	var ranks := {}
	for id in IDS:
		ranks[id] = 0
	return {"points": 0, "ranks": ranks}


static func ensure(meta: Dictionary) -> Dictionary:
	if not meta.has("skills") or typeof(meta["skills"]) != TYPE_DICTIONARY:
		meta["skills"] = create_state()
	var skills: Dictionary = meta["skills"]
	if not skills.has("ranks") or typeof(skills["ranks"]) != TYPE_DICTIONARY:
		skills["ranks"] = create_state()["ranks"]
	for id in IDS:
		if not skills["ranks"].has(id):
			skills["ranks"][id] = 0
	skills["points"] = int(skills.get("points", 0))
	return skills


static func rank(skills: Dictionary, skill_id: String) -> int:
	var ranks: Dictionary = skills.get("ranks", {})
	return clampi(int(ranks.get(skill_id, 0)), 0, MAX_RANK)


static func label(skill_id: String) -> String:
	match skill_id:
		"endurance":
			return "Endurance"
		"fieldcraft":
			return "Fieldcraft"
		"marksman":
			return "Marksman"
		"packmule":
			return "Packmule"
		"medic":
			return "Medic"
		_:
			return skill_id.capitalize()


static func blurb(skill_id: String) -> String:
	match skill_id:
		"endurance":
			return "More stamina, faster recovery"
		"fieldcraft":
			return "Faster ransack channels"
		"marksman":
			return "Tighter shot cone under fire"
		"packmule":
			return "Extra field bag slots"
		"medic":
			return "Faster field medkits"
		_:
			return ""


static func award_extract(skills: Dictionary, bonus: int = 0) -> int:
	var gained := EGRESS_POINTS + maxi(0, bonus)
	skills["points"] = int(skills.get("points", 0)) + gained
	return gained


## Deeds → bonus extract points (train-by-doing). Caps so hideout spend stays the main sink.
static func bonus_points_from_deeds(deeds: int) -> int:
	if deeds <= 0:
		return 0
	return mini(2, int(deeds / 5))


static func try_raise(skills: Dictionary, skill_id: String) -> String:
	if not IDS.has(skill_id):
		return "Unknown skill."
	var ranks: Dictionary = skills["ranks"]
	var cur := rank(skills, skill_id)
	if cur >= MAX_RANK:
		return "%s is maxed." % label(skill_id)
	if int(skills.get("points", 0)) <= 0:
		return "No skill points — extract to earn them."
	skills["points"] = int(skills["points"]) - 1
	ranks[skill_id] = cur + 1
	return "%s → %d." % [label(skill_id), cur + 1]


static func try_lower(skills: Dictionary, skill_id: String) -> String:
	## Refund one rank for one skill point — respec without a separate currency.
	if not IDS.has(skill_id):
		return "Unknown skill."
	var ranks: Dictionary = skills["ranks"]
	var cur := rank(skills, skill_id)
	if cur <= 0:
		return "%s is already clear." % label(skill_id)
	ranks[skill_id] = cur - 1
	skills["points"] = int(skills.get("points", 0)) + 1
	return "%s → %d  (+1 pt)." % [label(skill_id), cur - 1]


## —— raid modifiers (rank 0 = baseline) ——

static func stamina_max(skills: Dictionary) -> float:
	return 100.0 + float(rank(skills, "endurance")) * 18.0


static func stamina_regen_mult(skills: Dictionary) -> float:
	return 1.0 + float(rank(skills, "endurance")) * 0.12


static func loot_channel_mult(skills: Dictionary) -> float:
	# Lower = faster pry/strip.
	return maxf(0.55, 1.0 - float(rank(skills, "fieldcraft")) * 0.12)


static func recoil_mult(skills: Dictionary) -> float:
	return maxf(0.55, 1.0 - float(rank(skills, "marksman")) * 0.12)


static func bag_bonus(skills: Dictionary) -> int:
	return rank(skills, "packmule")


static func medkit_channel_mult(skills: Dictionary) -> float:
	return maxf(0.5, 1.0 - float(rank(skills, "medic")) * 0.14)
