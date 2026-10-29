extends CharacterBody2D
## Mage enemy. A stationary caster that stays put, telegraphs its next shot, then
## fires a straight wizard bullet toward the player's current position.
##
## Behaviour:
##  - Attack range: only fires when the player is within `distancia_ataque`.
##  - Wind-up: `tiempo_aviso` seconds of visible telegraph before the shot, so the
##    attack is challenging but always fair (the player can step out of the line).
##  - Cooldown: `intervalo_disparo` seconds between shots, so it never fires
##    uncontrollably.
##  - Its bullets ignore it (see area_2d.gd), so it can never be damaged by, or
##    collide with, its own projectiles, and it never attacks once dead.
##
## Preserved animations: "idle", "attack1" (wind-up), "attack2" (release),
## "death". Every animation is guarded, so a missing one causes no error.

@export_category("Estadísticas Base")
@export var vida_maxima: int = 8
@export var danio_proyectil: int = 10
@export var distancia_ataque: float = 320.0
@export var intervalo_disparo: float = 1.6
## Telegraph / wind-up time before the bullet leaves the staff.
@export var tiempo_aviso: float = 0.45
## How far in front of the mage the bullet spawns. Must be large enough that the
## bullet never overlaps its caster on the frame it is created.
@export var distancia_aparicion: float = 30.0

@export var proyectil_escena: PackedScene

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")

enum Estado { IDLE, AVISO, RECUPERACION }

var vida: int = 0
var jugador: Node2D
var muerto: bool = false
var _estado: Estado = Estado.IDLE
var _temporizador: float = 0.0


func _ready() -> void:
	add_to_group("enemigos")
	vida = vida_maxima
	jugador = get_tree().get_first_node_in_group("jugador")
	_play(_idle_anim())


func _idle_anim() -> String:
	# The mage's SpriteFrames names its idle clip "Idle"; accept either casing so
	# the idle always plays (and never errors if the clip is renamed).
	if _has_anim("Idle"):
		return "Idle"
	return "idle"


func _physics_process(delta: float) -> void:
	if muerto:
		return

	if not is_instance_valid(jugador):
		jugador = get_tree().get_first_node_in_group("jugador")
		return

	var distancia: float = global_position.distance_to(jugador.global_position)

	match _estado:
		Estado.IDLE:
			_play(_idle_anim())
			if distancia <= distancia_ataque:
				_iniciar_aviso()
		Estado.AVISO:
			# Wind-up in progress: hold still until the telegraph finishes.
			_temporizador -= delta
			if _temporizador <= 0.0:
				disparar()
				_temporizador = intervalo_disparo
				_estado = Estado.RECUPERACION
		Estado.RECUPERACION:
			_temporizador -= delta
			if _temporizador <= 0.0:
				_estado = Estado.IDLE


func _iniciar_aviso() -> void:
	if muerto:
		return
	_estado = Estado.AVISO
	_temporizador = tiempo_aviso
	_play("attack1")
	_telegraph()


## Visible wind-up: a colour pulse and a small size pop so the player can read
## the incoming shot and react.
func _telegraph() -> void:
	if sprite == null:
		return
	var base_scale: Vector2 = sprite.scale
	var color_tween := create_tween()
	sprite.modulate = Color(1.7, 0.55, 0.55)
	color_tween.tween_property(sprite, "modulate", Color.WHITE, tiempo_aviso)

	var pulse := create_tween()
	pulse.tween_property(sprite, "scale", base_scale * 1.16, tiempo_aviso * 0.5)
	pulse.tween_property(sprite, "scale", base_scale, tiempo_aviso * 0.5)


func disparar() -> void:
	if muerto or proyectil_escena == null or not is_instance_valid(jugador):
		return

	_play("attack2")

	var direccion: Vector2 = global_position.direction_to(jugador.global_position)
	if direccion == Vector2.ZERO:
		direccion = Vector2.RIGHT

	var proyectil: Node = proyectil_escena.instantiate()
	var host: Node = get_tree().current_scene
	if host == null:
		host = get_parent()
	if host == null:
		proyectil.queue_free()
		return
	host.add_child(proyectil)

	if proyectil is Node2D:
		# Spawn clear of the mage so the bullet never overlaps its shooter.
		(proyectil as Node2D).global_position = global_position + direccion * distancia_aparicion

	if proyectil.has_method("configurar"):
		proyectil.call("configurar", direccion, self)


func recibir_danio(cantidad: int) -> void:
	if muerto:
		return

	vida -= cantidad

	if sprite:
		var tween := create_tween()
		sprite.modulate = Color.CRIMSON
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)

	if vida <= 0:
		morir()


func morir() -> void:
	if muerto:
		return
	muerto = true
	_estado = Estado.IDLE
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0

	# The death animation loops, so animation_finished never fires for it: use a
	# short timer instead of awaiting, otherwise the mage would never be freed.
	if _has_anim("death"):
		_play("death")
		var timer := get_tree().create_timer(0.9)
		timer.timeout.connect(_al_terminar_muerte)
	else:
		queue_free()


func _al_terminar_muerte() -> void:
	if is_instance_valid(self):
		queue_free()


func _play(anim: String) -> void:
	if sprite == null or not _has_anim(anim):
		return
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)


func _has_anim(anim: String) -> bool:
	if sprite == null or sprite.sprite_frames == null:
		return false
	if not sprite.sprite_frames.has_animation(anim):
		return false
	return sprite.sprite_frames.get_frame_count(anim) > 0
