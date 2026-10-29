class_name RuneInscription
extends Node2D
## Carved slab that shows the required rune order as glyphs, so the puzzle is
## solvable from the clue rather than by guessing. The SealPuzzle feeds it the
## authoritative order at startup.

const RuneGeometry := preload("res://puzzles/rune_geometry.gd")

@export var espaciado: float = 52.0
@export var color_glyph: Color = Color(0.95, 0.82, 0.42, 1.0)


func _ready() -> void:
	add_to_group("rune_inscription")


## Draws the glyphs for `orden` (an array of glyph shape ids).
func mostrar_orden(orden: Array) -> void:
	for c in get_children():
		if c is Polygon2D and c.name.begins_with("GlyphClue"):
			c.queue_free()
	var total := orden.size()
	for i in total:
		var g := Polygon2D.new()
		g.name = "GlyphClue%d" % i
		g.polygon = RuneGeometry.points(int(orden[i]))
		g.color = color_glyph
		g.position = Vector2(
			(float(i) - (float(total) - 1.0) * 0.5) * espaciado, -6.0
		)
		add_child(g)