class_name CollectibleKey
extends Area2D
## A floating key the player collects by walking into it.

signal collected

var taken: bool = false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("keys")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if sprite != null:
		var tw := create_tween().set_loops()
		tw.tween_property(sprite, "position:y", -10.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(sprite, "position:y", 0.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_body_entered(body: Node2D) -> void:
	if not taken and body.is_in_group("jugador"):
		collected.emit()
		take()


func take() -> void:
	taken = true
	set_deferred("monitoring", false)
	get_tree().call_group("hud", "show_message", "Ancient Key collected!")
	if sprite != null:
		var tw := create_tween().set_parallel(true)
		tw.tween_property(sprite, "scale", Vector2(1.6, 1.6), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(sprite, "modulate:a", 0.0, 0.35)
	var timer := get_tree().create_timer(0.4)
	timer.timeout.connect(queue_free)