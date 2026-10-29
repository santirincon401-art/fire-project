extends CharacterBody2D
## Special enemy that drops the Spectral Sword collectible on death.
## Uses the same health API as other enemies: recibir_danio() and group enemigos.

const ANIM_IDLE := "idle"
const ANIM_MOVE := "move"
const ANIM_ATTACK := "attack"
const ANIM_HURT := "hurt"
const ANIM_DEATH := "death"

@export_category("Estadísticas Base")
@export var danio: int = 12
@export var vida_maxima: int = 6
@export var velocidad: float = 70.0
@export var distancia_ataque: float = 42.0
@export var tiempo_entre_ataques: float = 1.0

@export var drop_scene: PackedScene

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var placeholder: Node2D = $Placeholder
@onready var area: Area2D = $Area2D

var vida: int
var jugador: CharacterBody2D
var jugador_en_area: bool = false
var tiempo_desde_ultimo_ataque: float = 0.0
var _dead: bool = false
var _dropped: bool = false
var _hurt_locked: bool = false


func _ready() -> void:
	add_to_group("enemigos")
	vida = vida_maxima
	jugador = get_tree().get_first_node_in_group("jugador") as CharacterBody2D
	if drop_scene == null:
		drop_scene = preload("res://abilities/spectral_sword_drop.tscn")
	if sprite:
		if not sprite.animation_finished.is_connected(_on_animation_finished):
			sprite.animation_finished.connect(_on_animation_finished)
	_play(ANIM_IDLE)
	if area:
		if not area.body_entered.is_connected(_on_area_2d_body_entered):
			area.body_entered.connect(_on_area_2d_body_entered)
		if not area.body_exited.is_connected(_on_area_2d_body_exited):
			area.body_exited.connect(_on_area_2d_body_exited)


func _physics_process(delta: float) -> void:
	if _dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if not is_instance_valid(jugador):
		jugador = get_tree().get_first_node_in_group("jugador") as CharacterBody2D

	if not is_instance_valid(jugador):
		velocity = Vector2.ZERO
		move_and_slide()
		_play(ANIM_IDLE)
		return

	var toward: Vector2 = global_position.direction_to(jugador.global_position)
	var dist: float = global_position.distance_to(jugador.global_position)

	if dist > distancia_ataque:
		velocity = toward * velocidad
		if not _hurt_locked:
			_play(ANIM_MOVE)
	else:
		velocity = Vector2.ZERO
		if not _hurt_locked:
			_play(ANIM_ATTACK)

	move_and_slide()
	if toward.x != 0.0 and placeholder:
		placeholder.scale.x = -1.0 if toward.x < 0.0 else 1.0
	if toward.x != 0.0 and sprite:
		sprite.flip_h = toward.x < 0.0

	if jugador_en_area:
		tiempo_desde_ultimo_ataque += delta
		if tiempo_desde_ultimo_ataque >= tiempo_entre_ataques:
			_aplicar_danio_al_jugador()
			tiempo_desde_ultimo_ataque = 0.0


func recibir_danio(cantidad: int) -> void:
	if _dead:
		return
	vida = clampi(vida - cantidad, 0, vida_maxima)
	if placeholder:
		var tween := create_tween()
		placeholder.modulate = Color.CRIMSON
		tween.tween_property(placeholder, "modulate", Color.WHITE, 0.25)
	if sprite:
		sprite.modulate = Color.CRIMSON
		var stw := create_tween()
		stw.tween_property(sprite, "modulate", Color.WHITE, 0.25)

	if vida <= 0:
		_begin_death()
		return

	_hurt_locked = true
	_play(ANIM_HURT)
	if not _has_frames(ANIM_HURT):
		_hurt_locked = false


func _begin_death() -> void:
	_dead = true
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	if area:
		area.monitoring = false
	_play(ANIM_DEATH)
	if not _has_frames(ANIM_DEATH):
		_finish_death()
		return
	var timer := get_tree().create_timer(1.6)
	timer.timeout.connect(_finish_death)


func _finish_death() -> void:
	if _dropped or not is_instance_valid(self):
		return
	_dropped = true
	_spawn_drop()
	queue_free()


func _spawn_drop() -> void:
	if drop_scene == null:
		return
	var drop: Node = drop_scene.instantiate()
	var host: Node = get_parent()
	if host == null:
		host = get_tree().current_scene
	if host == null:
		drop.queue_free()
		return
	host.add_child(drop)
	if drop is Node2D:
		(drop as Node2D).global_position = global_position


func _on_animation_finished() -> void:
	if sprite == null:
		return
	var finished: String = sprite.animation
	if finished == ANIM_DEATH:
		_finish_death()
		return
	if finished == ANIM_HURT:
		_hurt_locked = false
		return
	# Looping idle/move/attack must not block hurt or death.


func _on_area_2d_body_entered(body: Node2D) -> void:
	if _dead:
		return
	if body.is_in_group("jugador"):
		jugador_en_area = true
		_aplicar_danio_al_jugador()
		tiempo_desde_ultimo_ataque = 0.0


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("jugador"):
		jugador_en_area = false
		tiempo_desde_ultimo_ataque = 0.0


func _aplicar_danio_al_jugador() -> void:
	if _dead or not is_instance_valid(jugador):
		return
	var ctrl: Node = jugador
	if not ctrl.has_method("recibir_danio"):
		ctrl = jugador.get_node_or_null("controlador")
	if ctrl == null or not ctrl.has_method("recibir_danio"):
		return
	if "invulnerable" in ctrl and bool(ctrl.invulnerable):
		return
	ctrl.recibir_danio(danio)
	if ctrl.has_method("activar_invulnerabilidad"):
		ctrl.activar_invulnerabilidad()


func _play(anim: String) -> void:
	if _dead and anim != ANIM_DEATH:
		return
	if sprite and _has_frames(anim):
		sprite.visible = true
		if placeholder:
			placeholder.visible = false
		if sprite.animation != anim or not sprite.is_playing():
			sprite.play(anim)
		return
	if sprite:
		sprite.visible = false
	if placeholder:
		placeholder.visible = true


func _has_frames(anim: String) -> bool:
	if sprite == null or sprite.sprite_frames == null:
		return false
	if not sprite.sprite_frames.has_animation(anim):
		return false
	return sprite.sprite_frames.get_frame_count(anim) > 0
