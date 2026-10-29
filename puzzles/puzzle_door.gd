class_name PuzzleDoor
extends Node2D
## A blocking door that opens either when all pressure plates are activated
## or when the matching key is collected. Gives visual + HUD feedback.

@export var door_w: float = 192.0
@export var door_h: float = 128.0
@export var required_plates: int = 0
@export var needs_key: bool = false
@export var door_name: String = "door"

var opened: bool = false
var _plates_activated: int = 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var body: StaticBody2D = $StaticBody2D
@onready var shape: CollisionShape2D = $StaticBody2D/CollisionShape2D


func _ready() -> void:
	if sprite != null:
		sprite.scale = Vector2(door_w / 64.0, door_h / 128.0)
	if shape != null:
		var rs := RectangleShape2D.new()
		rs.size = Vector2(door_w, door_h)
		shape.shape = rs
	call_deferred("_wire")


func _wire() -> void:
	if required_plates > 0:
		for p in get_tree().get_nodes_in_group("pressure_plates"):
			if p.has_signal("activated") and not p.activated.is_connected(_on_plate_activated):
				p.activated.connect(_on_plate_activated)
	if needs_key:
		for k in get_tree().get_nodes_in_group("keys"):
			if k.has_signal("collected") and not k.collected.is_connected(open):
				k.collected.connect(open)


func _on_plate_activated() -> void:
	_plates_activated += 1
	if _plates_activated >= required_plates:
		open()


func open() -> void:
	if opened:
		return
	opened = true
	if shape != null:
		shape.set_deferred("disabled", true)
	if body != null:
		body.set_deferred("collision_layer", 0)
		body.set_deferred("collision_mask", 0)
	get_tree().call_group("hud", "show_message", "%s grinds open!" % door_name)
	if sprite != null:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(sprite, "modulate:a", 0.08, 0.7)
		tw.tween_property(sprite, "scale:y", sprite.scale.y * 0.2, 0.7)
	if body != null:
		var timer := get_tree().create_timer(1.2)
		timer.timeout.connect(_free_body)


func _free_body() -> void:
	if is_instance_valid(body):
		body.queue_free()