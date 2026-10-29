extends RefCounted
## Shared geometry for the rune puzzle glyph shapes.
## 0 = triangle, 1 = square, 2 = circle. Used by both the rune devices and the
## inscription so the clue and the runes always agree.

static func points(shape: int) -> PackedVector2Array:
	match shape:
		0:
			return PackedVector2Array([Vector2(0, -11), Vector2(10, 8), Vector2(-10, 8)])
		1:
			return PackedVector2Array([
				Vector2(-9, -9), Vector2(9, -9), Vector2(9, 9), Vector2(-9, 9)
			])
		_:
			var pts := PackedVector2Array()
			for i in 14:
				var a := TAU * float(i) / 14.0
				pts.append(Vector2(cos(a), sin(a)) * 10.0)
			return pts


static func nombre(shape: int) -> String:
	match shape:
		0:
			return "Triangle"
		1:
			return "Square"
		_:
			return "Circle"