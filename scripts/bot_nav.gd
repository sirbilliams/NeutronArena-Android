class_name BotNav
extends RefCounted
## Bot navigation: a waypoint chain along the street centre line (ArenaLevel.LAYOUTS[..].route) in world metres.
## Chosen over a baked NavigationMesh: zero load-time cost on phones; local obstacle steering is done by BotBrain whiskers.
var pts := PackedVector2Array()
var cum := PackedFloat32Array()
var total := 0.0

func _init(layout_name: String) -> void:
	var route: Array = ArenaLevel.LAYOUTS[layout_name].route
	for r in route:
		pts.append(Vector2(r.x, r.y) * Config.WORLD_SCALE)
	cum.append(0.0)
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
		cum.append(total)

## Closest point on the chain: {s: arclength, d: distance to the chain}
func project(p: Vector2) -> Dictionary:
	var best_d := INF
	var best_s := 0.0
	for i in pts.size() - 1:
		var a := pts[i]
		var ab := pts[i + 1] - a
		var l2 := ab.length_squared()
		var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0) if l2 > 0.0 else 0.0
		var d := p.distance_to(a + ab * t)
		if d < best_d:
			best_d = d
			best_s = cum[i] + sqrt(l2) * t
	return {"s": best_s, "d": best_d}

func _seg(s: float) -> int:
	for i in pts.size() - 1:
		if s <= cum[i + 1]:
			return i
	return pts.size() - 2

func point_at(s: float) -> Vector2:
	s = clampf(s, 0.0, total)
	var i := _seg(s)
	return pts[i].lerp(pts[i + 1], (s - cum[i]) / maxf(cum[i + 1] - cum[i], 0.001))

## Unit direction of travel (towards the museum end) at arclength s
func tangent_at(s: float) -> Vector2:
	var i := _seg(clampf(s, 0.0, total))
	return (pts[i + 1] - pts[i]).normalized()
