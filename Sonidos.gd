extends Node

# Arrastra o escribe la ruta de tus archivos .wav aquí:
var efectos = {
	"mejora": preload("res://Assets//sonidos/mejora.wav"),
	"explosion": preload("res://Assets//sonidos/Explosion.wav"),
	"game_over": preload("res://Assets//sonidos/Has_muerto.wav"),
	"seleccion": preload("res://Assets//sonidos/Seleccion.wav"),
	"Hit_jugador": preload("res://Assets//sonidos/hit_jugador.wav"),
	"Hit_ene": preload("res://Assets//sonidos/hit_enemigos.wav"),
	"disparo_mago": preload("res://Assets//sonidos/Laser_shoot 2.wav")
}

func play(nombre: String) -> void:
	if efectos.has(nombre):
		var player = AudioStreamPlayer.new()
		player.stream = efectos[nombre]
		
		# Clave para que suene aunque el juego esté en pausa (como en el menú de mejoras)
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		
		add_child(player)
		player.play()
		
		# Se borra solo al terminar de reproducirse para no saturar memoria
		await player.finished
		player.queue_free()
	else:
		print("¡Falta el sonido: ", nombre, "!")
