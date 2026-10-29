class_name ResetPedestal
extends Area2D
## Touch to reset the rune sequence, so a wrong attempt is recoverable without
## restarting the level. Enforces a short cooldown so it cannot spam resets.

@export var cooldown: float = 1.5

var _cd: float = 0.0

@onready var glyph: Polygon2D = get_node_or_null("Glyph")
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")


func _ready() -> void:
	add_to_group("reset_pedestals")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _cd > 0.0:
		_cd = maxf(_cd - delta, 0.0)


func _on_body_entered(body: Node2D) -> void:
	if _cd > 0.0:
		return
	if not body.is_in_group("jugador"):
		return
	_cd = cooldown
	get_tree().call_group("seal_puzzle", "resetear")
	get_tree().call_group("hud", "show_message", "The runes go dark... the binding is cleared.")
	if glyph != null:
		var base: Vector2 = glyph.scale
		var tw := create_tween()
		tw.tween_property(glyph, "scale", base * 1.4, 0.1)
		tw.tween_property(glyph, "scale", base, 0.2)