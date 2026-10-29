class_name FireBomb
extends Node2D
## Fire Bomb effect. Spawned by the player when a Fire Bomb is used; it arcs to
## the target position, then explodes dealing area damage to nearby enemies.
## Damage and radius are configured through the item's use_params.

@export var damage: int = 3
@export var radius: float = 150.0
@export var fuse: float = 0.45
@export var explosion_texture: Texture2D

## World position the bomb flies to before detonating. Set by the player.
var target_position: Vector2 = Vector2.ZERO

@onready var bomb: Sprite2D = $Bomb
@onready var explosion: Sprite2D = $Explosion


func _ready() -> void:
	if explosion != null and explosion_texture != null:
		explosion.texture = explosion_texture
		explosion.visible = false

	var start: Vector2 = global_position
	var dur: float = maxf(fuse, 0.05)

	var tw: Tween = create_tween()
	tw.tween_method(_set_arc.bind(start), 0.0, 1.0, dur)
	tw.tween_callback(_explode)

	if bomb != null:
		var stw: Tween = create_tween()
		stw.tween_property(bomb, "rotation", TAU * 2.0, dur)


func _set_arc(t: float, start: Vector2) -> void:
	var pos: Vector2 = start.lerp(target_position, t)
	pos.y -= sin(t * PI) * 40.0  # small arc
	global_position = pos


func _explode() -> void:
	if bomb != null:
		bomb.visible = false

	_apply_damage()

	if explosion == null:
		queue_free()
		return

	explosion.visible = true
	var target_scale: float = (radius * 2.0) / 128.0
	explosion.scale = Vector2(target_scale, target_scale) * 0.4

	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(explosion, "scale", Vector2(target_scale, target_scale), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(explosion, "modulate:a", 0.0, 0.3).set_delay(0.15)

	var timer: SceneTreeTimer = get_tree().create_timer(0.5)
	timer.timeout.connect(queue_free)


func _apply_damage() -> void:
	for e in get_tree().get_nodes_in_group("enemigos"):
		if not is_instance_valid(e) or not e.has_method("recibir_danio"):
			continue
		if global_position.distance_to(e.global_position) <= radius:
			e.recibir_danio(damage)