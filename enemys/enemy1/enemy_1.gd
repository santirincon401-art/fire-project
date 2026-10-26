extends CharacterBody2D

enum Estado { SIGILO, EMBOSCADA, ATAQUE, RECTIFICACION }

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area: Area2D = $Area2D

@export_category("Estadísticas Base")
@export var velocidad_base: float = 80.0
@export var velocidad_emboscada: float = 280.0
@export var danio: int = 15
@export var vida_maxima: int = 5
@export var tiempo_entre_ataques: float = 0.8

@export_category("Mecánica de Emboscada")
@export var distancia_deteccion: float = 250.0
@export var distancia_emboscada: float = 120.0
@export var opacidad_sigilo: float = 0.2

var estado_actual: Estado = Estado.SIGILO
var vida: int
var jugador: CharacterBody2D
var direccion: Vector2 = Vector2.ZERO

var jugador_en_area: bool = false
var tiempo_desde_ultimo_ataque: float = 0.0
var en_cd_emboscada: bool = false


func _ready() -> void:
	add_to_group("enemigos")
	vida = vida_maxima
	sprite.play("default")
	
	# Mantenemos el camuflaje inicial
	sprite.modulate.a = opacidad_sigilo

	jugador = get_tree().get_first_node_in_group("jugador") as CharacterBody2D

	if area:
		if not area.body_entered.is_connected(_on_area_2d_body_entered):
			area.body_entered.connect(_on_area_2d_body_entered)
		if not area.body_exited.is_connected(_on_area_2d_body_exited):
			area.body_exited.connect(_on_area_2d_body_exited)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(jugador):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var distancia: float = global_position.distance_to(jugador.global_position)
	direccion = global_position.direction_to(jugador.global_position)

	# Lógica de la máquina de estados
	_procesar_estados(distancia)

	# Movimiento y rotación del sprite
	move_and_slide()
	_actualizar_orientacion()

	# Sistema de daño continuo
	if jugador_en_area:
		tiempo_desde_ultimo_ataque += delta
		if tiempo_desde_ultimo_ataque >= tiempo_entre_ataques:
			_aplicar_danio_al_jugador()
			tiempo_desde_ultimo_ataque = 0.0


func _procesar_estados(distancia: float) -> void:
	match estado_actual:
		Estado.SIGILO:
			# Movimiento lento acosando en la distancia
			velocity = direccion * velocidad_base
			
			# Prepara la emboscada si entra en la zona de peligro
			if distancia <= distancia_emboscada and not en_cd_emboscada:
				_iniciar_emboscada()

		Estado.EMBOSCADA:
			# Carga rápida en dirección fija hacia el objetivo
			velocity = direccion * velocidad_emboscada

		Estado.ATAQUE:
			velocity = Vector2.ZERO

		Estado.RECTIFICACION:
			# Retirada táctica rápida hacia atrás para volver a esconderse
			velocity = -direccion * (velocidad_base * 1.5)


func _iniciar_emboscada() -> void:
	estado_actual = Estado.EMBOSCADA
	en_cd_emboscada = true

	# Revelamos al personaje con un efecto de transición rápida
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 1.0, 0.15)
	
	# Carga de 0.4 segundos antes de volver al estado normal o rectificar
	await get_tree().create_timer(0.4).timeout
	
	if estado_actual == Estado.EMBOSCADA:
		_entrar_en_cooldown_y_volver_a_sigilo()


func _entrar_en_cooldown_y_volver_a_sigilo() -> void:
	estado_actual = Estado.RECTIFICACION
	
	# Pequeña retirada táctica
	await get_tree().create_timer(0.3).timeout
	
	estado_actual = Estado.SIGILO
	
	# Volver a ocultar paulatinamente
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", opacidad_sigilo, 0.5)

	# Cooldown de 3 segundos antes de poder emboscar otra vez
	await get_tree().create_timer(3.0).timeout
	en_cd_emboscada = false


func _actualizar_orientacion() -> void:
	if direccion.x != 0:
		sprite.flip_h = direccion.x < 0


func recibir_danio(cantidad: int) -> void:
	vida = clampi(vida - cantidad, 0, vida_maxima)

	# Revela al enemigo momentáneamente si es golpeado
	sprite.modulate.a = 1.0
	var tween = create_tween()
	sprite.modulate = Color.CRIMSON
	tween.tween_property(sprite, "modulate", Color(1, 1, 1, opacidad_sigilo if estado_actual == Estado.SIGILO else 1.0), 0.3)

	if vida <= 0:
		queue_free()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("jugador"):
		jugador_en_area = true
		_aplicar_danio_al_jugador()
		tiempo_desde_ultimo_ataque = 0.0


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("jugador"):
		jugador_en_area = false
		tiempo_desde_ultimo_ataque = 0.0


func _aplicar_danio_al_jugador() -> void:
	if is_instance_valid(jugador) and jugador.has_method("recibir_danio"):
		jugador.recibir_danio(danio)
