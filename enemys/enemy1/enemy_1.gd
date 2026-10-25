extends CharacterBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var area: Area2D = $Area2D

@export var velocidad: float = 100.0
@export var danio: int = 10
@export var vida_maxima: int = 5
@export var tiempo_entre_ataques: float = 1.0

var vida: int
var jugador: CharacterBody2D
var direccion: Vector2

var jugador_en_area: bool = false
var tiempo_desde_ultimo_ataque: float = 0.0


func _ready() -> void:
	add_to_group("enemigos")

	vida = vida_maxima
	sprite.play("default")

	jugador = get_tree().get_first_node_in_group("jugador") as CharacterBody2D

	if jugador == null:
		print("No encontré al jugador")

	# Conectamos las señales por código para asegurar su funcionamiento
	if area:
		if not area.body_entered.is_connected(_on_area_2d_body_entered):
			area.body_entered.connect(_on_area_2d_body_entered)
		if not area.body_exited.is_connected(_on_area_2d_body_exited):
			area.body_exited.connect(_on_area_2d_body_exited)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(jugador):
		return

	# Movimiento hacia el jugador
	direccion = global_position.direction_to(jugador.global_position)
	velocity = direccion * velocidad
	move_and_slide()

	# GESTIÓN DEL DAÑO CONTINUO
	if jugador_en_area:
		# Acumulamos el tiempo que pasa frame a frame
		tiempo_desde_ultimo_ataque += delta
		
		# Si ya pasó el tiempo necesario, atacamos de nuevo
		if tiempo_desde_ultimo_ataque >= tiempo_entre_ataques:
			_aplicar_danio_al_jugador()
			tiempo_desde_ultimo_ataque = 0.0 # Reiniciamos el contador


func recibir_danio(cantidad: int) -> void:
	vida = clampi(vida - cantidad, 0, vida_maxima)

	var tween = create_tween()
	sprite.modulate = Color.CRIMSON
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.5)

	if vida <= 0:
		queue_free()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("jugador"):
		jugador_en_area = true
		
		# Forzamos a que el primer golpe ocurra de inmediato al tocarlo
		_aplicar_danio_al_jugador()
		
		# Reiniciamos el contador interno para que el siguiente golpe espere el tiempo exacto
		tiempo_desde_ultimo_ataque = 0.0


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("jugador"):
		jugador_en_area = false
		tiempo_desde_ultimo_ataque = 0.0


func _aplicar_danio_al_jugador() -> void:
	if is_instance_valid(jugador) and jugador.has_method("recibir_danio"):
		jugador.recibir_danio(danio)
