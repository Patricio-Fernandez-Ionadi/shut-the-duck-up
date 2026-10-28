# main.gd: orquestador del nivel.
#
# RECIBE información de:
#   * PlayerCharacter: instancia del jugador (posición/estado).
#   * ExitZone: señal prompt_changed (progreso o bloqueo de la extracción).
#   * NoiseSystem: señal noise_emitted (estadísticas y mensajes del HUD).
#
# COMUNICA información a:
#   * GameState: reinicia la run y registra ruidos.
#   * HUD: enlaza jugador/pato, muestra avisos y el prompt de extracción.
#   * Árbol de escena: registra al jugador en el grupo "player" para los guardias.

extends Node2D
@export var levels: Array[PackedScene]

@onready var player: PlayerCharacter = $LevelTutorial/Player
@onready var duck: Duck = $LevelTutorial/Player/Duck
@onready var hud: GameHUD = $LevelTutorial/HUD
@onready var exit_area: ExitZone = $LevelTutorial/Exit


func _ready() -> void:
	# Estado limpio para cada carga del nivel.
	GameState.reset_run()

	# El jugador se registra para que GuardEnemy lo encuentre por grupo.
	player.add_to_group("player")

	# Conexiones de eventos externos hacia este script.
	exit_area.prompt_changed.connect(hud.show_prompt)
	NoiseSystem.noise_emitted.connect(_on_noise_emitted)

	# El HUD lee directamente el estado del jugador y del pato.
	hud.bind(player, duck)

func _exit_tree() -> void:
	if NoiseSystem.noise_emitted.is_connected(_on_noise_emitted):
		NoiseSystem.noise_emitted.disconnect(_on_noise_emitted)

func _process(_delta: float) -> void:
	# F3 alterna los conos de visión y radios de ruido en el mundo.
	if Input.is_action_just_pressed("toggle_debug"):
		GameState.debug_overlay = not GameState.debug_overlay

	# Reinicio manual al terminar la misión.
	if Input.is_action_just_pressed("restart") and GameState.is_complete():
		get_tree().reload_current_scene()

func _on_noise_emitted(
	_origin: Vector2,
	radius: float,
	source: String,
	_kind: String
) -> void:
	# Reacción del nivel al bus de ruido: estadística + mensaje en el HUD.
	GameState.increment_stat("noise_events")
	hud.show_status("%s — radio aproximado: %d px" % [
		source,
		int(radius),
	])
