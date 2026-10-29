class_name PressurePlate
extends Area2D
## A stone plate the player steps on to activate. Once pressed it stays latched,
## so a set of plates can be activated one at a time.

signal activated

@export var plate_id: int = 1
@export var glow_color: Color = Color(0.5, 1.7, 1.6, 1.0)
## Whether the plate can be stepped on right now. The SealPuzzle disables the
## plates until the rune sequence is correct.
@export var habilitada: bool = true

var is_active: bool = false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("pressure_plates")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	set_deferred("monitoring", habilitada)


func _on_body_entered(body: Node2D) -> void:
	if not habilitada:
		return
	if not is_active and body.is_in_group("jugador"):
		activate()


func activate() -> void:
	if is_active:
		return
	is_active = true
	activated.emit()
	get_tree().call_group("hud", "show_message", "Ancient seal %d activated" % plate_id)
	if sprite != null:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(sprite, "modulate", glow_color, 0.2)
		tw.tween_property(sprite, "scale", Vector2(0.85, 0.85), 0.12)


## Enables/disables the plate (used to gate stage 2 behind the rune sequence).
func habilitar(valor: bool) -> void:
	habilitada = valor
	set_deferred("monitoring", valor)


## Clears a latched plate so the puzzle can be re-solved.
func reset() -> void:
	is_active = false
	if sprite != null:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.2)
		tw.tween_property(sprite, "scale", Vector2.ONE, 0.12)