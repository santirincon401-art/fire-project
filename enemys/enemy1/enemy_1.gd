
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
var puede_atacar: bool = true


func _ready() -> void:
	add_to_group("enemigos")

	vida = vida_maxima
	sprite.play("default")

	jugador = get_tree().get_first_node_in_group("jugador") as CharacterBody2D

	if jugador == null:
		print("No encontré al jugador")


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(jugador):
		return

	direccion = global_position.direction_to(jugador.global_position)
	velocity = direccion * velocidad
	move_and_slide()


func recibir_danio(cantidad: int) -> void:
	vida = clampi(vida - cantidad, 0, vida_maxima)

	var tween = create_tween()
	sprite.modulate = Color.CRIMSON
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.5)
	
	if vida <= 0:
		queue_free()


func _on_area_2d_body_entered(body: Node2D) -> void:
	if not body.is_in_group("jugador"):
		return

	if not puede_atacar:
		return

	if not body.has_method("recibir_danio"):
		return

	puede_atacar = false
	body.recibir_danio(danio)

	await get_tree().create_timer(tiempo_entre_ataques).timeout

	if is_instance_valid(self):
		puede_atacar = true
