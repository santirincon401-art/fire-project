extends CharacterBody2D
## Stationary turret that fires bullets in a rotating spiral. Compatible with
## the existing player hitboxes via group "enemigos" and recibir_danio().

@export_category("Estadísticas Base")
@export var danio: int = 12
@export var vida_maxima: int = 8
@export var danio_bala: int = 10

@export_category("Disparo en espiral")
## Seconds between bullets while a burst is active (lower = faster shooting).
@export var shoot_interval: float = 0.08
## Travel speed of each independent bullet, in pixels per second.
@export var bullet_speed: float = 180.0
## How many bullets are fired before the burst pause.
@export var burst_size: int = 16
## Seconds to wait after a burst before the next one starts.
@export var burst_pause: float = 0.7
## How many degrees the spiral rotates after each shot.
@export var spiral_step_degrees: float = 18.0
## Extra simultaneous arms. 1 = single spiral, 2 = two opposite streams, etc.
@export var spiral_arms: int = 1
## If greater than 0, only shoot when the player is this close.
@export var aggro_range: float = 650.0

@export var bullet_scene: PackedScene

@onready var visual: Node2D = $Visual
@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")

@export_category("Animaciones (opcionales)")
@export var anim_idle: StringName = &"idle"
@export var anim_cast: StringName = &"cast"
@export var anim_hurt: StringName = &"hurt"
@export var anim_death: StringName = &"death"

var vida: int
var jugador: Node2D
var _angle: float = 0.0
var _shot_timer: float = 0.0
var _shots_in_burst: int = 0
var _pausing: bool = false
var _pause_timer: float = 0.0
var _disparando: float = 0.0
var _muerto: bool = false


func _ready() -> void:
	add_to_group("enemigos")
	vida = vida_maxima
	jugador = get_tree().get_first_node_in_group("jugador") as Node2D
	_shot_timer = shoot_interval
	if bullet_scene == null:
		bullet_scene = preload("res://enemys/spiral_shooter/spiral_bullet.tscn")
	# If a SpriteFrames with real frames is supplied, use it and hide the shapes.
	if _has_anim(anim_idle):
		if visual:
			visual.visible = false
		_play(anim_idle)


func _physics_process(delta: float) -> void:
	if _muerto:
		return
	velocity = Vector2.ZERO
	move_and_slide()

	if not is_instance_valid(jugador):
		jugador = get_tree().get_first_node_in_group("jugador") as Node2D

	if visual:
		visual.rotation = _angle

	_process_firing(delta)
	_update_sprite(delta)


## Keeps the sprite (if any) in an idle/cast pose; a no-op without frames.
func _update_sprite(delta: float) -> void:
	if _disparando > 0.0:
		_disparando -= delta
		_play(anim_cast)
	else:
		_play(anim_idle)


func _process_firing(delta: float) -> void:
	if not _player_in_range():
		return

	if _pausing:
		_pause_timer += delta
		if _pause_timer >= burst_pause:
			_pausing = false
			_pause_timer = 0.0
			_shots_in_burst = 0
		return
	
	_shot_timer += delta
	if _shot_timer < shoot_interval:
		return
	_shot_timer = 0.0
	Sonidos.play("disparo_mago")
	_fire_spiral_step()
	_shots_in_burst += 1
	_angle += deg_to_rad(spiral_step_degrees)

	if _shots_in_burst >= burst_size:
		_pausing = true
		_pause_timer = 0.0


func _player_in_range() -> bool:
	if aggro_range <= 0.0:
		return true
	if not is_instance_valid(jugador):
		return false
	return global_position.distance_to(jugador.global_position) <= aggro_range


func _fire_spiral_step() -> void:
	_disparando = 0.22
	var arms: int = maxi(spiral_arms, 1)
	var arm_gap: float = TAU / float(arms)
	for i in arms:
		_spawn_bullet(_angle + arm_gap * float(i))


func _spawn_bullet(angle: float) -> void:
	if bullet_scene == null:
		return

	var bullet: Node = bullet_scene.instantiate()
	var host: Node = get_parent()
	if host == null:
		host = get_tree().current_scene
	if host == null:
		bullet.queue_free()
		return

	host.add_child(bullet)
	if bullet is Node2D:
		(bullet as Node2D).global_position = global_position
	if bullet.has_method("setup"):
		bullet.setup(Vector2.from_angle(angle), bullet_speed, danio_bala)


func recibir_danio(cantidad: int) -> void:
	if _muerto:
		return
	vida = clampi(vida - cantidad, 0, vida_maxima)

	if visual:
		var tween := create_tween()
		visual.modulate = Color.CRIMSON
		tween.tween_property(visual, "modulate", Color.WHITE, 0.25)

	if vida <= 0:
		_morir()
	elif _has_anim(anim_hurt):
		_play(anim_hurt)


func _morir() -> void:
	if _muerto:
		return
	_muerto = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	if _has_anim(anim_death):
		_play(anim_death)
		var timer := get_tree().create_timer(0.7)
		timer.timeout.connect(queue_free)
	else:
		queue_free()


func _play(anim: StringName) -> void:
	if sprite == null or not _has_anim(anim):
		return
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)


func _has_anim(anim: StringName) -> bool:
	if sprite == null or sprite.sprite_frames == null:
		return false
	if not sprite.sprite_frames.has_animation(anim):
		return false
	return sprite.sprite_frames.get_frame_count(anim) > 0
