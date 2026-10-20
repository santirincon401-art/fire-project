
extends Node2D

# REFERENCIAS
@onready var player: CharacterBody2D = get_parent()
@onready var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
@onready var Hitbox: Area2D = player.get_node("Hitbox")
@onready var Hurtbox: Area2D = player.get_node("Hurtbox")
@onready var barra_vida: ProgressBar = player.get_node("CanvasLayer/ProgressBar")

# CONFIGURACIÓN
@export var velocidad: float = 300.0
@export var danio: int = 1
@export var distancia_ataque: float = 35.0
@export var vida_maxima: int = 100

var vida_actual: int

# ESTADOS
enum States { IDLE, WALK, ATTACK }

var current_state: States = States.IDLE
var ultima_direccion: Vector2 = Vector2.DOWN
var direccion_ataque: Vector2 = Vector2.DOWN

var ataque_actual: int = 0
var ataque_en_curso: bool = false
var combo_pendiente: bool = false
var enemigos_golpeados: Array[Node2D] = []


func _ready() -> void:
	player.add_to_group("jugador")

	vida_actual = vida_maxima
	actualizar_barra_vida()

	Hitbox.set_deferred("monitoring", false)

	if not Hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		Hitbox.body_entered.connect(_on_hitbox_body_entered)

	sprite.animation_finished.connect(_al_terminar_animacion)
	actualizar_animacion(Vector2.ZERO)


func _physics_process(_delta: float) -> void:
	var direccion = Input.get_vector(
		"ui_left", "ui_right", "ui_up", "ui_down"
	)

	if direccion != Vector2.ZERO:
		ultima_direccion = direccion

	player.velocity = direccion * velocidad
	player.move_and_slide()

	if Input.is_action_just_pressed("Attack"):
		if not ataque_en_curso:
			iniciar_ataque(1)
		elif ataque_actual == 1:
			combo_pendiente = true

	if ataque_en_curso:
		return

	current_state = States.IDLE if direccion == Vector2.ZERO else States.WALK
	actualizar_animacion(direccion)


# VIDA DEL JUGADOR

func recibir_danio(cantidad: int) -> void:
	if vida_actual <= 0:
		return

	vida_actual = clampi(vida_actual - cantidad, 0, vida_maxima)
	actualizar_barra_vida()

	print("Vida del jugador: ", vida_actual, "/", vida_maxima)

	if vida_actual == 0:
		print("¡Candle ha muerto!")


func curar(cantidad: int) -> void:
	vida_actual = mini(vida_actual + cantidad, vida_maxima)
	actualizar_barra_vida()


func actualizar_barra_vida() -> void:
	barra_vida.max_value = vida_maxima
	barra_vida.value = vida_actual


# ATAQUES

func iniciar_ataque(numero: int) -> void:
	var animacion = obtener_vista() + "Attack" + str(numero)

	if not sprite.sprite_frames.has_animation(animacion):
		push_warning("No existe la animación: " + animacion)
		return

	ataque_actual = numero
	ataque_en_curso = true
	current_state = States.ATTACK

	direccion_ataque = ultima_direccion.normalized()
	Hitbox.position = direccion_ataque * distancia_ataque
	enemigos_golpeados.clear()
	Hitbox.set_deferred("monitoring", true)

	sprite.flip_h = ultima_direccion.x < 0.0
	sprite.play(animacion)


func _on_hitbox_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemigos"):
		return

	if body in enemigos_golpeados:
		return

	if body.has_method("recibir_danio"):
		enemigos_golpeados.append(body)
		body.recibir_danio(danio)


# VISTAS

func obtener_vista() -> String:
	if ultima_direccion.x != 0.0 and ultima_direccion.y != 0.0:
		return "Three-quarter2View" if ultima_direccion.y < 0.0 else "Three-quarterView"

	if ultima_direccion.y < 0.0:
		return "BackView"

	if ultima_direccion.y > 0.0:
		return "FrontView"

	return "SideView"


# ANIMACIONES

func actualizar_animacion(direccion: Vector2) -> void:
	var accion = "Idle" if direccion == Vector2.ZERO else "Walk"
	var animacion = obtener_vista() + accion

	sprite.flip_h = ultima_direccion.x < 0.0

	if sprite.sprite_frames.has_animation(animacion):
		if sprite.animation != animacion:
			sprite.play(animacion)


# FINALIZACIÓN DEL ATAQUE Y COMBO

func _al_terminar_animacion() -> void:
	if not ataque_en_curso:
		return

	Hitbox.set_deferred("monitoring", false)

	if ataque_actual == 1 and combo_pendiente:
		combo_pendiente = false
		iniciar_ataque(2)
		return

	ataque_en_curso = false
	ataque_actual = 0
	combo_pendiente = false

	var direccion = player.velocity.normalized()
	current_state = States.IDLE if direccion == Vector2.ZERO else States.WALK
	actualizar_animacion(direccion)


func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemigos"):
		recibir_danio(body.danio)
		var tween = create_tween()
		sprite.modulate = Color.CRIMSON
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.5)
