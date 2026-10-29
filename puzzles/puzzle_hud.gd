class_name PuzzleHUD
extends CanvasLayer
## Small on-screen banner that shows puzzle feedback (plates, doors, keys).

var _tween: Tween

@onready var label: Label = $Label


func _ready() -> void:
	add_to_group("hud")
	if label != null:
		label.modulate.a = 0.0


func show_message(text: String) -> void:
	if label == null:
		return
	label.text = text
	label.modulate.a = 1.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(2.4)
	_tween.tween_property(label, "modulate:a", 0.0, 0.7)
