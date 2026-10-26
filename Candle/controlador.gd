extends Node2D


# ==================================================
# 1. REFERENCIAS A LOS NODOS
# ==================================================

@onready var player: CharacterBody2D = get_parent()
@onready var sprite: AnimatedSprite2D = player.get_node("AnimatedSprite2D")
@onready var hitbox: Area2D = player.get_node("Hitbox")
@onready var SpinningHitbox: Area2D = player.get_node("SpinningHitbox")
@onready var hurtbox: Area2D = player.get_node("Hurtbox")
@onready var barra_vida: ProgressBar = player.get_node("CanvasLayer/ProgressBar")


# ==================================================
# 2. CONFIGURACIÓN DEL JUGADOR
# ==================================================

@export var velocidad: float = 300.0
@export var danio: int = 1
@export var distancia_ataque: float = 35.0
@export var vida_maxima: int = 100

var haciendo_dash: bool = false
var tiempo_dash: float = 0.0
var velocidad_dash: float = 800.0
var duracion_dash: float = 0.2

var vida_actual: int
var invulnerable: bool = false


# ==================================================
# 3. ESTADOS DEL JUGADOR
# ==================================================

enum States {
	IDLE,
	WALK,
	ATTACK,
	STAB,
	LARGESTAB,
	SPINNINGATTACK
}

var current_state: States = States.IDLE

var ultima_direccion: Vector2 = Vector2.DOWN
var direccion_ataque: Vector2 = Vector2.DOWN


# ==================================================
# 4. VARIABLES DE COMBATE
# ==================================================

var ataque_actual: int = 0
var ataque_en_curso: bool = false
var combo_pendiente: bool = false

# Variables del combo Attack1 -> Stab1.
var estocada_desbloqueada: bool = false
var estocada_pendiente: bool = false

# Evita golpear varias veces al mismo enemigo en un ataque.
var enemigos_golpeados: Array[Node2D] = []
var enemigos_golpeados_spin: Array[Node2D] = []
@export var duracion_spin: float = 2.0
@export var tiempo_hitbox_activa: float = 0.25
@export var tiempo_hitbox_inactiva: float = 0.15

var tiempo_spin: float = 0.0
var tiempo_ciclo_spin: float = 0.0
var spin_activo: bool = false
var hitbox_spin_activa: bool = false
# ==================================================
# 5. INICIALIZACIÓN
# ==================================================

func _ready() -> void:
	player.add_to_group("jugador")

	vida_actual = vida_maxima
	actualizar_barra_vida()

	hitbox.set_deferred("monitoring", false)

	if not hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		hitbox.body_entered.connect(_on_hitbox_body_entered)

	if not hurtbox.body_entered.is_connected(_on_hurtbox_body_entered):
		hurtbox.body_entered.connect(_on_hurtbox_body_entered)

	if not sprite.animation_finished.is_connected(_al_terminar_animacion):
		sprite.animation_finished.connect(_al_terminar_animacion)

	actualizar_animacion(Vector2.ZERO)
	SpinningHitbox.set_deferred("monitoring", false)
	if not SpinningHitbox.body_entered.is_connected(
		_on_spinning_hitbox_body_entered
	):
		SpinningHitbox.body_entered.connect(
		_on_spinning_hitbox_body_entered
	)
# ==================================================
# 6. CONTROL PRINCIPAL
# ==================================================

func _physics_process(delta: float) -> void:

	var direccion: Vector2 = Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
		"ui_down"
	)

	# Si está haciendo dash, controlar únicamente el dash.
	if haciendo_dash:
		procesar_dash(delta)
		return

	# Recordar la última dirección.
	if direccion != Vector2.ZERO:
		ultima_direccion = direccion

	# Movimiento.
	player.velocity = direccion * velocidad
	player.move_and_slide()

	# Procesar según el estado.
	match current_state:

		States.IDLE:
			procesar_movimiento(direccion)

		States.WALK:
			procesar_movimiento(direccion)

		States.ATTACK:
			procesar_ataque()

		States.STAB:
			procesar_ataque()

		States.LARGESTAB:
			procesar_ataque()
		States.SPINNINGATTACK:
			procesar_spin(delta)


# ==================================================
# 7. MOVIMIENTO NORMAL
# ==================================================

func procesar_movimiento(direccion: Vector2) -> void:

	if Input.is_action_just_pressed("Attack"):
		iniciar_ataque(1)
		return

	if Input.is_action_just_pressed("LargeStab"):
		iniciar_LargeStab(1)
		return
	if Input.is_action_just_pressed("Spin"):
		iniciar_spin()
		return
	if direccion == Vector2.ZERO:
		cambiar_estado(States.IDLE)
	else:
		cambiar_estado(States.WALK)

	actualizar_animacion(direccion)

# ==================================================
# 8. ENTRADAS DURANTE LOS ATAQUES
# ==================================================

func procesar_ataque() -> void:

	# Combo normal: Attack1 -> Attack2.
	if Input.is_action_just_pressed("Attack"):
		if current_state == States.ATTACK and ataque_actual == 1:
			combo_pendiente = true

	# Combo especial: Attack1 -> Stab1.
	if estocada_desbloqueada:
		if Input.is_action_just_pressed("Stab"):
			estocada_pendiente = true


# ==================================================
# 9. DASH
# ==================================================

func procesar_dash(delta: float) -> void:

	tiempo_dash += delta

	player.velocity = direccion_ataque * velocidad_dash
	player.move_and_slide()

	if tiempo_dash >= duracion_dash:
		haciendo_dash = false
		tiempo_dash = 0.0
		player.velocity = Vector2.ZERO
	activar_invulnerabilidad()
	current_state = States.WALK

# ==================================================
# 10. CAMBIO DE ESTADO
# ==================================================

func cambiar_estado(nuevo_estado: States) -> void:

	if current_state == nuevo_estado:
		return

	current_state = nuevo_estado


# ==================================================
# 11. SISTEMA DE VIDA
# ==================================================

func recibir_danio(cantidad: int) -> void:

	if vida_actual <= 0:
		return

	vida_actual = clampi(
		vida_actual - cantidad,
		0,
		vida_maxima
	)

	actualizar_barra_vida()

	print("Vida de Candle: ", vida_actual, "/", vida_maxima)

	if vida_actual == 0:
		print("¡Candle ha muerto!")


func curar(cantidad: int) -> void:

	if vida_actual <= 0:
		return

	vida_actual = mini(
		vida_actual + cantidad,
		vida_maxima
	)

	actualizar_barra_vida()


func actualizar_barra_vida() -> void:

	barra_vida.max_value = vida_maxima
	barra_vida.value = vida_actual


# ==================================================
# 12. ATAQUE NORMAL
# ==================================================

func iniciar_ataque(numero: int) -> void:

	var animacion: String = obtener_vista() + "Attack" + str(numero)

	# Comprobar que existe la animación.
	if not sprite.sprite_frames.has_animation(animacion):
		push_warning("No existe la animación: " + animacion)
		return

	if numero != 1 and numero != 2:
		return

	ataque_actual = numero
	ataque_en_curso = true
	combo_pendiente = false

	# Attack1 desbloquea temporalmente Stab1.
	if numero == 1:
		estocada_desbloqueada = true
		estocada_pendiente = false

	# Attack2 cierra la posibilidad de encadenar Stab1.
	if numero == 2:
		estocada_desbloqueada = false
		estocada_pendiente = false

	cambiar_estado(States.ATTACK)

	# Preparar dirección e hitbox.
	direccion_ataque = ultima_direccion.normalized()

	hitbox.position = direccion_ataque * distancia_ataque
	enemigos_golpeados.clear()

	sprite.flip_h = ultima_direccion.x < 0.0

	hitbox.set_deferred("monitoring", true)
	sprite.play(animacion)


# ==================================================
# 13. ESTOCADA STAB1
# ==================================================

func iniciar_stab(numero: int) -> void:

	var animacion: String = obtener_vista() + "Stab" + str(numero)

	# Comprobar que existe la animación.
	if not sprite.sprite_frames.has_animation(animacion):
		push_warning("No existe la animación: " + animacion)
		estocada_desbloqueada = false
		estocada_pendiente = false
		return

	ataque_actual = 0
	ataque_en_curso = true
	combo_pendiente = false

	# Por ahora solo tenemos Stab1.
	estocada_desbloqueada = false
	estocada_pendiente = false

	cambiar_estado(States.STAB)

	# Preparar dirección e hitbox.
	direccion_ataque = ultima_direccion.normalized()

	hitbox.position = direccion_ataque * distancia_ataque
	enemigos_golpeados.clear()

	sprite.flip_h = ultima_direccion.x < 0.0

	hitbox.set_deferred("monitoring", true)
	sprite.play(animacion)


# ==================================================
# 14. LARGE STAB
# ==================================================

func iniciar_LargeStab(numero: int) -> void:

	var animacion: String = obtener_vista() + "LargeStab" + str(numero)

	# Comprobar que existe la animación.
	if not sprite.sprite_frames.has_animation(animacion):
		push_warning("No existe la animación: " + animacion)
		return

	ataque_actual = 0
	ataque_en_curso = true
	combo_pendiente = false

	estocada_desbloqueada = false
	estocada_pendiente = false

	cambiar_estado(States.LARGESTAB)

	# Preparar dirección e hitbox.
	direccion_ataque = ultima_direccion.normalized()

	hitbox.position = direccion_ataque * distancia_ataque
	enemigos_golpeados.clear()

	sprite.flip_h = ultima_direccion.x < 0.0

	hitbox.set_deferred("monitoring", true)
	sprite.play(animacion)


# ==================================================
# 15. DETECTAR ENEMIGOS GOLPEADOS
# ==================================================

func _on_hitbox_body_entered(body: Node2D) -> void:

	if not body.is_in_group("enemigos"):
		return

	if body in enemigos_golpeados:
		return

	if body.has_method("recibir_danio"):
		enemigos_golpeados.append(body)
		body.recibir_danio(danio)


# ==================================================
# 16. DIRECCIÓN Y VISTAS
# ==================================================

func obtener_vista() -> String:

	if ultima_direccion.x != 0.0 and ultima_direccion.y != 0.0:

		if ultima_direccion.y < 0.0:
			return "Three-quarter2View"
		else:
			return "Three-quarterView"

	if ultima_direccion.y < 0.0:
		return "BackView"

	if ultima_direccion.y > 0.0:
		return "FrontView"

	return "SideView"


# ==================================================
# 17. ANIMACIONES DE MOVIMIENTO
# ==================================================

func actualizar_animacion(direccion: Vector2) -> void:

	var accion: String

	if direccion == Vector2.ZERO:
		accion = "Idle"
	else:
		accion = "Walk"

	var animacion: String = obtener_vista() + accion

	sprite.flip_h = ultima_direccion.x < 0.0

	if sprite.sprite_frames.has_animation(animacion):
		if sprite.animation != animacion:
			sprite.play(animacion)


# ==================================================
# 18. FINALIZACIÓN DE ANIMACIONES Y COMBOS
# ==================================================

func _al_terminar_animacion() -> void:

	# Ignorar si no hay un ataque activo.
	if not ataque_en_curso:
		return

	# LargeStab1 -> LargeStab2 y dash.
	if sprite.animation.ends_with("LargeStab1"):

		var siguiente_animacion: String = obtener_vista() + "LargeStab2"

		if sprite.sprite_frames.has_animation(siguiente_animacion):

			sprite.play(siguiente_animacion)

			haciendo_dash = true
			tiempo_dash = 0.0

			# Activar invulnerabilidad una sola vez.
			activar_invulnerabilidad()

			return

	# Desactivar hitbox al terminar el golpe.
	hitbox.set_deferred("monitoring", false)

	# Attack1 -> Stab1.
	if sprite.animation.ends_with("Attack1") and estocada_pendiente:

		estocada_pendiente = false
		estocada_desbloqueada = false
		ataque_en_curso = false

		call_deferred("iniciar_stab", 1)
		return

	# Attack1 -> Attack2.
	if ataque_actual == 1 and combo_pendiente:

		combo_pendiente = false
		ataque_en_curso = false
		ataque_actual = 0

		estocada_desbloqueada = false
		estocada_pendiente = false

		call_deferred("iniciar_ataque", 2)
		return

	# Terminar el ataque actual.
	ataque_en_curso = false
	ataque_actual = 0
	combo_pendiente = false
	estocada_pendiente = false
	estocada_desbloqueada = false

	# Regresar a movimiento o reposo.
	if player.velocity == Vector2.ZERO:

		cambiar_estado(States.IDLE)
		actualizar_animacion(Vector2.ZERO)

	else:

		cambiar_estado(States.WALK)
		actualizar_animacion(player.velocity.normalized())


# ==================================================
# 19. RECIBIR ATAQUES DE LOS ENEMIGOS
# ==================================================

func _on_hurtbox_body_entered(body: Node2D) -> void:

	if not body.is_in_group("enemigos"):
		return

	# Comprobar que el enemigo tenga una variable danio.
	if not ("danio" in body):
		return

	if invulnerable:
		return

	recibir_danio(body.danio)
	activar_invulnerabilidad()

	# Efecto visual al recibir daño.
	var tween = create_tween()

	sprite.modulate = Color.CRIMSON

	tween.tween_property(
		sprite,
		"modulate",
		Color.WHITE,
		0.5
	)


# ==================================================
# 20. INVULNERABILIDAD
# ==================================================


func activar_invulnerabilidad() -> void:
	if invulnerable:
		return

	invulnerable = true
	print("Invulnerabilidad activada")

	await get_tree().create_timer(0.5).timeout

	invulnerable = false
	print("Invulnerabilidad desactivada")


func _on_spinning_hitbox_body_entered(body: Node2D) -> void:

	# Solo hacer daño durante el giro.
	if current_state != States.SPINNINGATTACK:
		return

	# Comprobar que sea un enemigo.
	if not body.is_in_group("enemigos"):
		return

	# Evitar golpear al mismo enemigo dos veces.
	if body in enemigos_golpeados_spin:
		return

	# Aplicar daño.
	if body.has_method("recibir_danio"):
		enemigos_golpeados_spin.append(body)
		body.recibir_danio(danio)
func iniciar_spin() -> void:

	if not sprite.sprite_frames.has_animation("SpinningAttack"):
		push_warning("No existe la animación: SpinningAttack")
		return

	ataque_en_curso = true
	ataque_actual = 0

	combo_pendiente = false
	estocada_desbloqueada = false
	estocada_pendiente = false

	tiempo_spin = 0.0
	tiempo_ciclo_spin = 0.0

	spin_activo = true
	hitbox_spin_activa = true

	enemigos_golpeados_spin.clear()

	cambiar_estado(States.SPINNINGATTACK)

	hitbox.set_deferred("monitoring", false)
	SpinningHitbox.set_deferred("monitoring", true)

	sprite.play("SpinningAttack")
func procesar_spin(delta: float) -> void:

	tiempo_spin += delta
	tiempo_ciclo_spin += delta

	# Terminar el ataque cuando se agote la duración.
	if tiempo_spin >= duracion_spin:
		terminar_spin()
		return

	# Alternar entre hitbox activa e inactiva.
	if hitbox_spin_activa:
		if tiempo_ciclo_spin >= tiempo_hitbox_activa:
			hitbox_spin_activa = false
			tiempo_ciclo_spin = 0.0

			SpinningHitbox.set_deferred("monitoring", false)

	else:
		if tiempo_ciclo_spin >= tiempo_hitbox_inactiva:
			hitbox_spin_activa = true
			tiempo_ciclo_spin = 0.0

			enemigos_golpeados_spin.clear()
			SpinningHitbox.set_deferred("monitoring", true)
func terminar_spin() -> void:

	spin_activo = false
	hitbox_spin_activa = false
	ataque_en_curso = false
	ataque_actual = 0

	SpinningHitbox.set_deferred("monitoring", false)

	if player.velocity == Vector2.ZERO:
		cambiar_estado(States.IDLE)
		actualizar_animacion(Vector2.ZERO)
	else:
		cambiar_estado(States.WALK)
		actualizar_animacion(player.velocity.normalized())
