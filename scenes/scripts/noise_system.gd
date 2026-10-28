extends Node

## Bus central de ruido (autoload "NoiseSystem").
##
## RECIBE llamadas a emit_noise() de:
##   * PlayerCharacter (disparos y pasos al correr).
##   * Duck (graznidos y al ser calmado).
##   * Botellas u otras distracciones (kind = "distraction").
##
## COMUNICA el evento noise_emitted a todos los suscriptores:
##   * GuardEnemy: pasa a investigar o perseguir según el radio.
##   * main.gd: muestra el origen y el radio en el HUD.
## Cada oyente decide cómo reaccionar a un sonido.

signal noise_emitted(
	origin: Vector2,
	radius: float,
	source: String,
	kind: String
)

const NOISE_RIPPLE_SCRIPT := preload(
	"res://scenes/scripts/noise_ripple.gd"
)

func emit_noise(
	origin: Vector2,
	radius: float,
	source: String,
	kind: String = "generic"
) -> void:
	# Reenvía el sonido a todos los nodos conectados a la señal.
	noise_emitted.emit(origin, radius, source, kind)

	# Feedback visual; los pasos solo se muestran en modo debug.
	_spawn_ripple(origin, radius, kind)

func _spawn_ripple(origin: Vector2, radius: float, kind: String) -> void:
	if kind == "footstep" and not GameState.debug_overlay:
		return

	var scene := get_tree().current_scene
	if scene == null:
		return

	var ripple := NOISE_RIPPLE_SCRIPT.new()
	scene.add_child(ripple)
	ripple.setup(origin, radius, kind)
