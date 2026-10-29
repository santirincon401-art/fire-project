
extends Node2D

@export_category("Movement")
@export var fallback_speed: float = 420.0
@export var fallback_max_distance: float = 320.0
@export var fallback_damage: int = 2
@export var hit_distance: float = 20.0

var _orbiting: bool = true
var _target: Node2D = null
var _speed: float = 420.0
var _max_distance: float = 320.0
var _damage: int = 2
var _start_position: Vector2
var _direction: Vector2 = Vector2.RIGHT
var _already_hit: bool = false
var _hitting: bool = false


func _ready() -> void:
	_start_position = global_position


# Allows the ability controller to enable or disable orbit mode.
func set_orbit_mode(enabled: bool) -> void:
	_orbiting = enabled


# Called every frame while the sword orbits the player.
func orbit_at(world_position: Vector2, facing_angle: float) -> void:
	if not _orbiting or _hitting:
		return

	global_position = world_position
	rotation = facing_angle


# Sends this sword toward a target.
func launch_at(
	new_target: Node2D,
	new_speed: float,
	distance_limit: float,
	hit_damage: int
) -> void:
	_orbiting = false
	_target = new_target

	_speed = new_speed if new_speed > 0.0 else fallback_speed
	_max_distance = distance_limit if distance_limit > 0.0 else fallback_max_distance
	_damage = hit_damage

	_start_position = global_position
	_already_hit = false
	_hitting = false

	if is_instance_valid(_target):
		_direction = global_position.direction_to(_target.global_position)

	if _direction == Vector2.ZERO:
		_direction = Vector2.RIGHT

	_play_animation("fly")


func _physics_process(delta: float) -> void:
	if _orbiting or _hitting:
		return

	# Remove the sword when it reaches its maximum travel distance.
	if global_position.distance_to(_start_position) >= _max_distance:
		queue_free()
		return

	# Home toward the target while it remains valid.
	if is_instance_valid(_target):
		var desired_direction := global_position.direction_to(
			_target.global_position
		)

		if desired_direction != Vector2.ZERO:
			_direction = desired_direction

	global_position += _direction * _speed * delta
	rotation = _direction.angle()

	# Check distance to target.
	if is_instance_valid(_target) and not _already_hit:
		var distance := global_position.distance_to(_target.global_position)

		if distance <= hit_distance:
			_hit_target()


func _hit_target() -> void:
	if _already_hit:
		return

	_already_hit = true
	_hitting = true

	if is_instance_valid(_target):
		if _target.has_method("recibir_danio"):
			_target.call("recibir_danio", _damage)

	# Play the impact animation if one exists.
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

	if sprite != null and sprite.sprite_frames != null:
		if sprite.sprite_frames.has_animation("hit"):
			sprite.play("hit")
			await sprite.animation_finished

	queue_free()


func _play_animation(animation_name: StringName) -> void:
	var sprite := get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

	if sprite == null or sprite.sprite_frames == null:
		return

	if sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)
