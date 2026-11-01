class_name Characters
extends RefCounted
## Playable roster (character select). Pure data + validation, no scene dependencies (the server validates ids with it).
## Jimmy team: Jimmy, Carl, Sheen, Cindy, Libby.  Negatron team: Negatron + evil clones (red eyes) of Carl, Sheen, Cindy, Libby.
## "base" = the character whose art/animations the id uses; "evil" = recolour the eyes red at runtime (CharModel).
const ROSTER := {
	&"jimmy": {"name": "Jimmy", "team": 0, "base": &"jimmy", "evil": false, "blurb": "Boy genius. Big hair, bigger ideas, a bubble gun in every pocket."},
	&"carl": {"name": "Carl", "team": 0, "base": &"carl", "evil": false, "blurb": "Llama-loving best friend. Sturdy, loyal and hard to knock over."},
	&"sheen": {"name": "Sheen", "team": 0, "base": &"sheen", "evil": false, "blurb": "Ultra Lord's number one fan. Fearless, loud, never still."},
	&"cindy": {"name": "Cindy", "team": 0, "base": &"cindy", "evil": false, "blurb": "Top of the class and she knows it. Fights like she is grading you."},
	&"libby": {"name": "Libby", "team": 0, "base": &"libby", "evil": false, "blurb": "Quick on her feet, quicker with an opinion. Needs the Boy Genius disc."},
	&"negatron": {"name": "Negatron", "team": 1, "base": &"negatron", "evil": false, "blurb": "Yokian overlord of bad ideas. Cannot be reasoned with."},
	&"ecarl": {"name": "Evil Carl", "team": 1, "base": &"carl", "evil": true, "blurb": "Carl, recruited. The red eyes are not a good sign."},
	&"esheen": {"name": "Evil Sheen", "team": 1, "base": &"sheen", "evil": true, "blurb": "Sheen with a grudge. Same energy, worse intentions."},
	&"ecindy": {"name": "Evil Cindy", "team": 1, "base": &"cindy", "evil": true, "blurb": "Cindy with a plan. Smart, cold, glowing."},
	&"elibby": {"name": "Evil Libby", "team": 1, "base": &"libby", "evil": true, "blurb": "Libby turned. Fast, furious and very red in the eyes."},
}
const ORDER := [&"jimmy", &"carl", &"sheen", &"cindy", &"libby", &"negatron", &"ecarl", &"esheen", &"ecindy", &"elibby"]
## glb files each base character needs (relative to the asset dir); all must exist for the character to be playable
const FILES := {
	&"jimmy": ["jimmy.glb"],
	&"carl": ["carl.glb", "jimmy.glb"],
	&"sheen": ["sheen.glb", "jimmy.glb"],
	&"cindy": ["cindy.glb", "jimmy.glb"],
	&"libby": ["ase/n1/libystop.glb", "ase/n1/libywalk.glb", "ase/n1/libyrun.glb"],
	&"negatron": ["nummey_villain.glb", "nummey.glb"],
}
const LOCK_HINT := {
	&"libby": "Locked: import the Boy Genius disc (Re-import game files) to unlock.",
}

static func ids_for_team(team: int) -> Array:
	var out := []
	for id in ORDER:
		if ROSTER[id].team == team:
			out.append(id)
	return out

static func default_for_team(team: int) -> StringName:
	return &"jimmy" if team == Config.TEAM_JIMMY else &"negatron"

static func is_valid(id: StringName, team: int) -> bool:
	return ROSTER.has(id) and ROSTER[id].team == team

## Returns `id` when it is on `team`, else the team default (server side + Player).
static func sanitize(id, team: int) -> StringName:
	var s := StringName(str(id))
	return s if is_valid(s, team) else default_for_team(team)

static func base_of(id: StringName) -> StringName:
	return ROSTER[id].base if ROSTER.has(id) else &"jimmy"

static func is_evil(id: StringName) -> bool:
	return ROSTER.has(id) and ROSTER[id].evil

static func display_name(id: StringName) -> String:
	return ROSTER[id].name if ROSTER.has(id) else str(id)

## True when the imported art for this character exists on this device.
static var debug_locked: Array = []   # tests / shots: pretend these base characters are not imported

static func available(id: StringName) -> bool:
	if debug_locked.has(base_of(id)):
		return false
	for f in FILES.get(base_of(id), []):
		if not FileAccess.file_exists(Config.asset_path(f)):
			return false
	return true

static func lock_hint(id: StringName) -> String:
	return LOCK_HINT.get(base_of(id), "Locked: game files missing, use Re-import game files.")

## Random available-or-not id of a team (bots; the client falls back to the team default when art is missing).
static func random_for_team(team: int, rng: RandomNumberGenerator = null) -> StringName:
	var ids := ids_for_team(team)
	var i := rng.randi() % ids.size() if rng else randi() % ids.size()
	return ids[i]
