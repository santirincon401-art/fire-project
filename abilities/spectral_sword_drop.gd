extends Area2D
## Touch this drop to unlock Spectral Swords for the rest of the session.

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var placeholder: Node2D = $Placeholder

var _taken: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		if sprite.sprite_frames.get_frame_count("idle") > 0:
			sprite.play("idle")
			if placeholder:
				placeholder.visible = false
	var bob := create_tween().set_loops()
	bob.tween_property(self, "position:y", position.y - 10.0, 0.7).set_trans(Tween.TRANS_SINE)
	bob.tween_property(self, "position:y", position.y, 0.7).set_trans(Tween.TRANS_SINE)


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("jugador"):
		return
	_taken = true
	set_deferred("monitoring", false)

	var abilities := get_node_or_null("/root/PlayerAbilities")
	if abilities:
		abilities.spectral_swords_unlocked = true
	get_tree().call_group("hud", "show_message", "Spectral Swords Unlocked!")

	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector2(1.7, 1.7), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, 0.32)
	var timer := get_tree().create_timer(0.35)
	timer.timeout.connect(queue_free)
