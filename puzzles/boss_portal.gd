class_name BossPortal
extends Area2D
## The gate portal. It stays hidden and inert until the SealPuzzle unlocks it;
## once active, touching it travels to the boss arena through Godot's scene
## changer. The destination path is validated before use.

@export var escena_destino: String = "res://scenes/boss_arena.tscn"

var activo: bool = false

@onready var visual: Node2D = get_node_or_null("Visual")


func _ready() -> void:
	add_to_group("boss_portal")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_aplicar_estado(false)


func activar() -> void:
	if activo:
		return
	activo = true
	_aplicar_estado(true)
	if visual != null:
		var tw := create_tween().set_loops()
		tw.tween_property(visual, "scale", Vector2(1.16, 1.16), 0.7).set_trans(Tween.TRANS_SINE)
		tw.tween_property(visual, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)


func _aplicar_estado(encendido: bool) -> void:
	set_deferred("monitoring", encendido)
	if visual != null:
		visual.visible = encendido


func _on_body_entered(body: Node2D) -> void:
	if not activo or not body.is_in_group("jugador"):
		return
	if not ResourceLoader.exists(escena_destino):
		push_error("BossPortal: destination scene not found: %s" % escena_destino)
		return
	get_tree().change_scene_to_file(escena_destino)