extends Area2D
## Mage projectile (wizard bullet). It flies straight from the caster toward the
## point the player was standing on when it fired, damages the player once, then
## frees itself.
##
## Robustness notes:
##  - It stores an explicit reference to its caster and ignores it, so a bullet
##    spawned at the mage can never collide with (or be blocked by) the shooter.
##  - It ignores every node in the "enemies" group, so enemies can never be hurt
##    by it and it never gets stuck on another enemy.
##  - Walls/level geometry stop it, and a lifetime cap removes it if it flies
##    off into the void. It therefore can never linger forever.

@export var velocidad: float = 300.0
@export var danio: int = 10
@export var tiempo_vida: float = 3.0

var direccion: Vector2 = Vector2.RIGHT
## The node that fired this bullet. Set through configurar().
var tirador: Node = null

var _edad: float = 0.0


## Directions the bullet and remembers who fired it. `nodo_tirador` may be null
## (e.g. for a trap), in which case only the "enemies" group is ignored.
func configurar(nueva_direccion: Vector2, nodo_tirador: Node = null) -> void:
	direccion = nueva_direccion.normalized()
	if direccion == Vector2.ZERO:
		direccion = Vector2.RIGHT
	rotation = direccion.angle()
	tirador = nodo_tirador


func _ready() -> void:
	body_entered.connect(_al_chocar)


func _physics_process(delta: float) -> void:
	global_position += direccion * velocidad * delta
	_edad += delta

	if _edad >= tiempo_vida:
		queue_free()


func _al_chocar(cuerpo: Node2D) -> void:
	# Never hit the caster or any enemy (including the mage that fired this).
	if tirador != null and cuerpo == tirador:
		return
	if cuerpo.is_in_group("enemigos"):
		return

	if cuerpo.is_in_group("jugador"):
		_aplicar_danio_al_jugador(cuerpo)
		queue_free()
		return

	# Walls and other level geometry stop the bullet. A TileMapLayer is detected
	# as its own node type, so it is handled explicitly here.
	if cuerpo is TileMapLayer or cuerpo is StaticBody2D \
			or cuerpo is CharacterBody2D or cuerpo is AnimatableBody2D:
		queue_free()


func _aplicar_danio_al_jugador(jugador: Node) -> void:
	var controlador: Node = jugador
	if not controlador.has_method("recibir_danio"):
		controlador = jugador.get_node_or_null("controlador")
	if controlador == null or not controlador.has_method("recibir_danio"):
		return
	if "invulnerable" in controlador and bool(controlador.invulnerable):
		return

	controlador.recibir_danio(danio)
	if controlador.has_method("activar_invulnerabilidad"):
		controlador.activar_invulnerabilidad()

	var sprite := jugador.get_node_or_null("AnimatedSprite2D") as CanvasItem
	if sprite:
		var tween := jugador.create_tween()
		sprite.modulate = Color.CRIMSON
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.5)
