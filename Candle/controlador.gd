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
@onready var label_combo: Label = player.get_node_or_null("CanvasLayer/LabelCombo")


# ==================================================
# 2. CONFIGURACIÓN DEL JUGADOR
# ==================================================

@export var velocidad: float = 300.0
@export var danio: int = 1
@export var distancia_ataque: float = 35.0
@export var vida_maxima: int = 100

# Variables de Dash
var haciendo_dash: bool = false
var tiempo_dash: float = 0.0
var velocidad_dash: float = 800.0
var duracion_dash: float = 0.2

# Variables de Rodar (Sostenido con inercia y derrape)
var haciendo_rodar: bool = false
var velocidad_rodar: float = 650.0
var inercia_rodar: Vector2 = Vector2.ZERO
@export var friccion_rodar: float = 7.0

var vida_actual: int
var invulnerable: bool = false


# ==================================================
# 3. SISTEMA DE COMBOS Y FRENESÍ (DOPAMINA)
# ==================================================

var contador_combo: int = 0
var puntos_totales: int = 0
var tiempo_reset_combo: float = 0.0
@export var max_tiempo_sin_golpear: float = 2.5
var modo_frenesi: bool = false


# ==================================================
# 4. ESTADOS DEL JUGADOR
# ==================================================

enum States {
	IDLE,
	WALK,
	ATTACK,
	STAB,
	LARGESTAB,
	SPINNINGATTACK,
	ROLL
}

var current_state: States = States.IDLE
var ultima_direccion: Vector2 = Vector2.DOWN
var direccion_ataque: Vector2 = Vector2.DOWN


# ==================================================
# 5. VARIABLES DE COMBATE
# ==================================================

var ataque_actual: int = 0
var ataque_en_curso: bool = false
var combo_pendiente: bool = false

var estocada_desbloqueada: bool = false
var estocada_pendiente: bool = false

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
# 6. INICIALIZACIÓN
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
	if not SpinningHitbox.body_entered.is_connected(_on_spinning_hitbox_body_entered):
		SpinningHitbox.body_entered.connect(_on_spinning_hitbox_body_entered)


# ==================================================
# 7. CONTROL PRINCIPAL
# ==================================================

func _physics_process(delta: float) -> void:

	# Decaimiento del combo por tiempo sin golpear
	if contador_combo > 0:
		tiempo_reset_combo += delta
		if tiempo_reset_combo >= max_tiempo_sin_golpear:
			romper_combo()

	var direccion: Vector2 = Input.get_vector(
		"ui_left",
		"ui_right",
		"ui_up",
		"ui_down"
	)

	# Control de Rodar SOSTENIDO (Hold to Roll)
	if Input.is_action_pressed("Roll"):
		if not haciendo_rodar:
			iniciar_rodar(direccion)

	if haciendo_dash:
		procesar_dash(delta)
		return

	if haciendo_rodar:
		procesar_rodar(delta)
		return

	if direccion != Vector2.ZERO:
		ultima_direccion = direccion

	# Multiplicador de velocidad si estamos en modo frenesí (combo > 5)
	var multiplicador_velocidad = 1.25 if modo_frenesi else 1.0
	player.velocity = direccion * velocidad * multiplicador_velocidad
	player.move_and_slide()

	match current_state:
		States.IDLE, States.WALK:
			procesar_movimiento(direccion)
		States.ATTACK, States.STAB:
			procesar_ataque()
		States.SPINNINGATTACK:
			procesar_spin(delta)
		States.LARGESTAB:
			procesar_dash(delta)


# ==================================================
# 8. MOVIMIENTO Y ENTRADAS (APUNTANDO AL MOUSE)
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


func procesar_ataque() -> void:
	if Input.is_action_just_pressed("Attack"):
		if current_state == States.ATTACK and ataque_actual == 1:
			combo_pendiente = true

	if estocada_desbloqueada and Input.is_action_just_pressed("Stab"):
		estocada_pendiente = true


# ==================================================
# 9. MECÁNICA DE RODAR SOSTENIDO (DERRAPE CONTINUO)
# ==================================================

func iniciar_rodar(direccion_input: Vector2) -> void:
	var animacion: String = "Roll"
	
	if not sprite.sprite_frames.has_animation(animacion):
		animacion = obtener_vista() + "Walk"

	cambiar_estado(States.ROLL)
	haciendo_rodar = true
	
	var dir_rodar = direccion_input if direccion_input != Vector2.ZERO else ultima_direccion
	var boost_frenesi = 1.3 if modo_frenesi else 1.0
	inercia_rodar = dir_rodar.normalized() * velocidad_rodar * boost_frenesi
	
	activar_invulnerabilidad()
	sprite.play(animacion)


func procesar_rodar(delta: float) -> void:
	player.velocity = inercia_rodar
	player.move_and_slide()
	
	# Fricción del derrape
	inercia_rodar = inercia_rodar.move_toward(Vector2.ZERO, friccion_rodar * 120.0 * delta)

	# Si soltamos la tecla y la inercia baja, terminamos el rollo
	if not Input.is_action_pressed("Roll") and inercia_rodar.length() < 100.0:
		haciendo_rodar = false
		player.velocity = Vector2.ZERO
		cambiar_estado(States.IDLE)
		return

	# Si sigue presionada la tecla y nos estamos deteniendo, podemos mantener el impulso si hay input de movimiento
	if inercia_rodar.length() < 20.0:
		if Input.is_action_pressed("Roll"):
			var dir_input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
			if dir_input != Vector2.ZERO:
				iniciar_rodar(dir_input)
				return
		
		haciendo_rodar = false
		player.velocity = Vector2.ZERO
		cambiar_estado(States.IDLE)


# ==================================================
# 10. DASH
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
# 11. VIDA Y ESTADOS
# ==================================================

func cambiar_estado(nuevo_estado: States) -> void:
	if current_state == nuevo_estado:
		return
	current_state = nuevo_estado


func recibir_danio(cantidad: int) -> void:
	if vida_actual <= 0:
		return

	vida_actual = clampi(vida_actual - cantidad, 0, vida_maxima)
	actualizar_barra_vida()
	romper_combo()

	if vida_actual == 0:
		print("¡Candle ha muerto!")


func curar(cantidad: int) -> void:
	if vida_actual <= 0:
		return
	vida_actual = mini(vida_actual + cantidad, vida_maxima)
	actualizar_barra_vida()


func actualizar_barra_vida() -> void:
	barra_vida.max_value = vida_maxima
	barra_vida.value = vida_actual


# ==================================================
# 12. SISTEMA DE COMBOS Y MODO FRENESÍ
# ==================================================

func registrar_golpe_exitoso(enemigo: Node2D) -> void:
	contador_combo += 1
	puntos_totales += contador_combo * 150
	tiempo_reset_combo = 0.0

	if label_combo:
		label_combo.text = "🔥 COMBO x%d | PTS: %d" % [contador_combo, puntos_totales]

	if contador_combo >= 5 and not modo_frenesi:
		modo_frenesi = true
		print("¡MODO FRENESÍ ACTIVADO!")

	efecto_animacion_combo()


func efecto_animacion_combo() -> void:
	var tween = create_tween().set_parallel(true)
	sprite.scale = Vector2(1.3, 1.3)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_ELASTIC)
	
	sprite.modulate = Color(2.0, 1.5, 0.5) if modo_frenesi else Color(1.3, 1.3, 1.3)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.25)


func romper_combo() -> void:
	if contador_combo > 0:
		contador_combo = 0
		modo_frenesi = false
		if label_combo:
			label_combo.text = "COMBO ROTO ❌"


# ==================================================
# 13. ATAQUES Y DIRECCIÓN APUNTANDO AL MOUSE
# ==================================================

func obtener_direccion_hacia_mouse() -> Vector2:
	# Calcula el vector desde la posición global del jugador hasta el mouse en pantalla
	var mouse_pos = player.get_global_mouse_position()
	return player.global_position.direction_to(mouse_pos).normalized()


func iniciar_ataque(numero: int) -> void:
	# Usamos la dirección hacia el mouse para decidir la animación y el ataque
	var dir_mouse = obtener_direccion_hacia_mouse()
	var animacion: String = obtener_vista_desde_vector(dir_mouse) + "Attack" + str(numero)
	
	if not sprite.sprite_frames.has_animation(animacion):
		animacion = obtener_vista() + "Attack" + str(numero) # Respaldo si falta la específica
		if not sprite.sprite_frames.has_animation(animacion):
			return

	ataque_actual = numero
	ataque_en_curso = true
	combo_pendiente = false

	if numero == 1:
		estocada_desbloqueada = true
		estocada_pendiente = false
	elif numero == 2:
		estocada_desbloqueada = false
		estocada_pendiente = false

	cambiar_estado(States.ATTACK)
	
	# Fijamos la dirección de ataque hacia donde apunta el mouse
	direccion_ataque = dir_mouse
	hitbox.position = direccion_ataque * distancia_ataque
	enemigos_golpeados.clear()
	
	sprite.flip_h = direccion_ataque.x < 0.0
	hitbox.set_deferred("monitoring", true)
	sprite.play(animacion)


func iniciar_LargeStab(numero: int) -> void:
	var dir_mouse = obtener_direccion_hacia_mouse()
	var animacion: String = obtener_vista_desde_vector(dir_mouse) + "LargeStab" + str(numero)
	haciendo_dash = true
	tiempo_dash = 0.0
	if not sprite.sprite_frames.has_animation(animacion):
		return

	ataque_actual = 0
	ataque_en_curso = true
	combo_pendiente = false
	estocada_desbloqueada = false
	estocada_pendiente = false

	cambiar_estado(States.LARGESTAB)
	direccion_ataque = dir_mouse
	hitbox.position = direccion_ataque * distancia_ataque
	enemigos_golpeados.clear()
	
	sprite.flip_h = direccion_ataque.x < 0.0
	hitbox.set_deferred("monitoring", true)
	sprite.play(animacion)


func _on_hitbox_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemigos"):
		return
	if body in enemigos_golpeados:
		return

	if body.has_method("recibir_danio"):
		enemigos_golpeados.append(body)
		body.recibir_danio(danio)
		registrar_golpe_exitoso(body)


# ==================================================
# 14. SPIN ATTACK
# ==================================================

func iniciar_spin() -> void:
	if not sprite.sprite_frames.has_animation("SpinningAttack"):
		return

	ataque_en_curso = true
	ataque_actual = 0
	combo_pendiente = false
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

	if tiempo_spin >= duracion_spin:
		terminar_spin()
		return

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
	SpinningHitbox.set_deferred("monitoring", false)

	if player.velocity == Vector2.ZERO:
		cambiar_estado(States.IDLE)
		actualizar_animacion(Vector2.ZERO)
	else:
		cambiar_estado(States.WALK)
		actualizar_animacion(player.velocity.normalized())


func _on_spinning_hitbox_body_entered(body: Node2D) -> void:
	if current_state != States.SPINNINGATTACK:
		return
	if not body.is_in_group("enemigos"):
		return
	if body in enemigos_golpeados_spin:
		return

	if body.has_method("recibir_danio"):
		enemigos_golpeados_spin.append(body)
		body.recibir_danio(danio)
		registrar_golpe_exitoso(body)


# ==================================================
# 15. DIRECCIONES Y VISTAS (BASADAS EN MOVIMIENTO O MOUSE)
# ==================================================

func obtener_vista() -> String:
	return obtener_vista_desde_vector(ultima_direccion)


func obtener_vista_desde_vector(vec: Vector2) -> String:
	if vec.x != 0.0 and vec.y != 0.0:
		if vec.y < 0.0:
			return "Three-quarter2View"
		else:
			return "Three-quarterView"
	if vec.y < 0.0:
		return "BackView"
	if vec.y > 0.0:
		return "FrontView"
	return "SideView"


func actualizar_animacion(direccion: Vector2) -> void:
	var accion: String = "Idle" if direccion == Vector2.ZERO else "Walk"
	var animacion: String = obtener_vista() + accion

	sprite.flip_h = ultima_direccion.x < 0.0

	if sprite.sprite_frames.has_animation(animacion):
		if sprite.animation != animacion:
			sprite.play(animacion)


func _al_terminar_animacion() -> void:
	if sprite.animation == "Roll":
		# Si la tecla sigue presionada al terminar la animación de rodar, continuamos rodando
		if Input.is_action_pressed("Roll"):
			var dir_input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
			iniciar_rodar(dir_input)
		else:
			haciendo_rodar = false
			cambiar_estado(States.IDLE)
		return

	if not ataque_en_curso:
		return

	hitbox.set_deferred("monitoring", false)

	ataque_en_curso = false
	ataque_actual = 0
	combo_pendiente = false
	estocada_pendiente = false
	estocada_desbloqueada = false

	if player.velocity == Vector2.ZERO:
		cambiar_estado(States.IDLE)
		actualizar_animacion(Vector2.ZERO)
	else:
		cambiar_estado(States.WALK)
		actualizar_animacion(player.velocity.normalized())


# ==================================================
# 16. HURTBOX E INVULNERABILIDAD
# ==================================================

func _on_hurtbox_body_entered(body: Node2D) -> void:
	if not body.is_in_group("enemigos"):
		return
	if not ("danio" in body):
		return
	if invulnerable:
		return

	recibir_danio(body.danio)
	activar_invulnerabilidad()

	var tween = create_tween()
	sprite.modulate = Color.CRIMSON
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.5)


func activar_invulnerabilidad() -> void:
	if invulnerable:
		return
	invulnerable = true
	await get_tree().create_timer(0.5).timeout
	invulnerable = false
