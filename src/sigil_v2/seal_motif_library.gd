class_name SealMotifLibrary
extends RefCounted

const CIRCLE_SEGMENTS := 64
const TRIANGLE_SEGMENTS := 3
const ORBIT_RING_SEGMENTS := 48


static func paths(motif_id: StringName) -> Array:
	match motif_id:
		&"crescent":
			return [
				{
					"points": PackedVector2Array([
						Vector2(-80, -248), Vector2(-184, -202), Vector2(-246, -104),
						Vector2(-248, 22), Vector2(-190, 150), Vector2(-78, 224),
						Vector2(58, 220), Vector2(170, 152), Vector2(230, 52),
					]),
					"closed": false,
				},
				{
					"points": PackedVector2Array([
						Vector2(132, -182), Vector2(30, -210), Vector2(-72, -168),
						Vector2(-126, -76), Vector2(-118, 36), Vector2(-52, 126),
						Vector2(50, 158), Vector2(146, 116), Vector2(202, 34),
					]),
					"closed": false,
				},
			]
		&"fang":
			return [
				{
					"points": PackedVector2Array([
						Vector2(0, -260), Vector2(184, 188), Vector2(0, 108),
						Vector2(-184, 188), Vector2(0, -260),
					]),
					"closed": false,
				},
				{
					"points": PackedVector2Array([Vector2(0, -154), Vector2(0, 108)]),
					"closed": false,
				},
			]
		&"branch":
			return [
				{
					"points": PackedVector2Array([Vector2(0, 252), Vector2(0, -248)]),
					"closed": false,
				},
				{
					"points": PackedVector2Array([Vector2(0, 80), Vector2(-170, -54), Vector2(-216, -148)]),
					"closed": false,
				},
				{
					"points": PackedVector2Array([Vector2(0, -14), Vector2(156, -120), Vector2(202, -202)]),
					"closed": false,
				},
			]
	return []


static func segment_count(motif_id: StringName) -> int:
	var total := 0
	for path in paths(motif_id):
		var points: PackedVector2Array = path.get("points", PackedVector2Array())
		total += maxi(points.size() - 1, 0)
		if bool(path.get("closed", false)) and points.size() > 1:
			total += 1
	return total
