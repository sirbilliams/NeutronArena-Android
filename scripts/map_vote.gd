class_name MapVote
extends RefCounted
## Pre-match vote: pure tally (the server keeps one MapVote per vote, World wires the RPCs).
## Two ballots, mode and map. Each voter casts at most one choice per ballot; ties are broken at random.
var mode_options: Array = []     # StringName ids
var map_options: Array = []      # layout names
var mode_votes := {}             # voter id -> option index
var map_votes := {}

func _init(modes := [], maps := []) -> void:
	mode_options = modes
	map_options = maps

func cast(voter: int, mode_i: int, map_i: int) -> void:
	if mode_i >= 0 and mode_i < mode_options.size():
		mode_votes[voter] = mode_i
	if map_i >= 0 and map_i < map_options.size():
		map_votes[voter] = map_i

func forget(voter: int) -> void:
	mode_votes.erase(voter)
	map_votes.erase(voter)

static func counts(votes: Dictionary, n: int) -> Array:
	var c := []
	c.resize(n)
	c.fill(0)
	for v in votes.values():
		if v >= 0 and v < n:
			c[v] += 1
	return c

## Index of the winning option; no votes or a tie = random among the leaders.
static func tally(votes: Dictionary, n: int, rng: RandomNumberGenerator = null) -> int:
	if n <= 0:
		return -1
	var c := counts(votes, n)
	var top: int = c.max()
	var leaders := []
	for i in n:
		if c[i] == top:
			leaders.append(i)
	if leaders.size() == 1:
		return leaders[0]
	return leaders[(rng.randi() if rng else randi()) % leaders.size()]

func mode_counts() -> Array:
	return counts(mode_votes, mode_options.size())

func map_counts() -> Array:
	return counts(map_votes, map_options.size())

## {mode: StringName, map: String}
func result(rng: RandomNumberGenerator = null) -> Dictionary:
	var mi := tally(mode_votes, mode_options.size(), rng)
	var pi := tally(map_votes, map_options.size(), rng)
	return {"mode": mode_options[mi] if mi >= 0 else &"tdm", "map": map_options[pi] if pi >= 0 else ""}
