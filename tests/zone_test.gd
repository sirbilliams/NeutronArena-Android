extends Node
## Forward-spawn rule test (no glb needed): godot --headless --path . res://tests/zone_test.tscn
var fails := 0
func check(c: bool, m: String) -> void:
	print("  [", "ok" if c else "FAIL", "] ", m)
	if not c: fails += 1

func _ready() -> void:
	var lv := ArenaLevel.new()
	lv._build_zones()
	var J := Config.TEAM_JIMMY
	var N := Config.TEAM_NEGATRON
	check(lv.zones[J].size() == 3 and lv.zones[N].size() == 3, "2 forward zones + base per team")
	var base_n := lv.raw_to_world(lv.zones[N][2].raw)
	var d0 := lv.raw_to_world(lv.zones[J][0].raw).distance_to(base_n)
	var d1 := lv.raw_to_world(lv.zones[J][1].raw).distance_to(base_n)
	var d2 := lv.raw_to_world(lv.zones[J][2].raw).distance_to(base_n)
	check(d0 < d1 and d1 < d2, "Jimmy zones ordered forward -> base (%.0f < %.0f < %.0f m from Negatron base)" % [d0, d1, d2])
	check(lv.choose_zone(J, []) == 0 and lv.choose_zone(N, []) == 0, "no enemies: most forward zone")
	var zj0 := lv.raw_to_world(lv.zones[J][0].raw)
	var zj1 := lv.raw_to_world(lv.zones[J][1].raw)
	check(lv.choose_zone(J, [zj0 + Vector3(10, 0, 0)]) == 1, "enemy 10 m from forward zone: falls back to zone 1")
	check(lv.choose_zone(J, [zj0 + Vector3(40, 0, 0)]) == 0, "enemy 40 m away: forward zone still used")
	check(lv.choose_zone(J, [zj0 + Vector3(20, 0, 0), zj1 + Vector3(0, 0, 5)]) == 2, "both forward zones contested: base")
	check(lv.choose_zone(N, [zj0 + Vector3(10, 0, 0)]) == 0, "Jimmy-zone enemy does not affect Negatron zones")
	var lc := ArenaLevel.new()
	lc.layout_name = "compact"
	lc._build_zones()
	check(lc.zones[J].size() == 1 and lc.choose_zone(J, [Vector3.ZERO]) == 0, "compact layout: base only")
	print("ZONE TEST ", "PASS" if fails == 0 else "FAIL")
	get_tree().quit(0 if fails == 0 else 1)
