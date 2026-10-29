class_name RuneDevice
extends Area2D
## A rune pedestal. The player walks onto it to activate it; it reports its
## rune_id to the SealPuzzle. Each pedestal draws a distinct glyph (from
## rune_geometry) so the inscription's order can be matched by the player.

signal rune_activated(rune_id: int)

const RuneGeometry := preload("res://puzzles/rune_geometry.gd")

@export var rune_id: int = 1
## 0 = triangle, 1 = square, 2 = circle.
@export var glyph_shape: int = 0
@export var color_inactivo: Color = Color(0.32, 0.34, 0.4, 1.0)
@export var color_activo: Color = Color(0.45, 1.6, 1.5, 1.0)

var activada: bool = false

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var glyph: Polygon2D = get_node_or_null("Glyph")


func _ready() -> void:
	add_to_group("rune_devices")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if glyph != null:
		glyph.polygon = RuneGeometry.points(glyph_shape)
	_pintar(false)


func _on_body_entered(body: Node2D) -> void:
	if activada:
		return
	if body.is_in_group("jugador"):
		activate()


func activate() -> void:
	if activada:
		return
	activada = true
	_pintar(true)
	if glyph != null:
		var base: Vector2 = glyph.scale
		var tw := create_tween()
		tw.tween_property(glyph, "scale", base * 1.3, 0.1)
		tw.tween_property(glyph, "scale", base, 0.2)
	rune_activated.emit(rune_id)


func reset() -> void:
	activada = false
	_pintar(false)


func _pintar(encendida: bool) -> void:
	if glyph != null:
		glyph.color = color_activo if encendida else color_inactivo
	if sprite != null:
		sprite.modulate = Color(1, 1, 1, 1) if encendida else Color(0.62, 0.62, 0.68, 1)