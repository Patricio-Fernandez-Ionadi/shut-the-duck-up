# ExitZone: zona de extracción con progreso al permanecer dentro.
#
# RECIBE información de:
#   * Mundo físico: señales body_entered/body_exited del jugador.
#   * PlayerCharacter y Duck: posición del pato y su agitación.
#   * Grupo "guards": detecta si algún guardia sigue persiguiendo.
#   * GameState: run_reset y mission_completed.
#
# COMUNICA información a:
#   * HUD (por señal prompt_changed): texto de progreso o motivo de bloqueo.
#   * GameState: complete_mission() al sostener la extracción el tiempo justo.
#   * Su visual: el color de la zona cambia según el progreso.

extends Area2D
class_name ExitZone

signal prompt_changed(text: String)

@export var hold_time: float = 1.5
@export var max_duck_agitation: float = 70.0
@export var duck_max_distance: float = 80.0

var _player: PlayerCharacter = null
var _inside := false
var _progress := 0.0
var _last_prompt := ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	GameState.run_reset.connect(_on_run_reset)
	GameState.mission_completed.connect(_on_mission_completed)
	queue_redraw()
	set_process(true)

func _exit_tree() -> void:
	if GameState.run_reset.is_connected(_on_run_reset):
		GameState.run_reset.disconnect(_on_run_reset)
	if GameState.mission_completed.is_connected(_on_mission_completed):
		GameState.mission_completed.disconnect(_on_mission_completed)

func _process(delta: float) -> void:
	queue_redraw()

	if GameState.is_complete():
		_set_prompt("")
		return

	if not _inside:
		_progress = 0.0
		_set_prompt("")
		return

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as PlayerCharacter

	if _player == null:
		_progress = 0.0
		return

	var duck := _player.duck

	if duck == null:
		_progress = 0.0
		return

	if _is_guard_chasing():
		_progress = 0.0
		_set_prompt("No podés extraer mientras te persiguen.")
		return

	var duck_distance := _player.global_position.distance_to(duck.global_position)

	if duck_distance > duck_max_distance:
		_progress = 0.0
		_set_prompt("Necesitás al pato cerca para extraer.")
		return

	if duck.agitation >= max_duck_agitation:
		_progress = 0.0
		_set_prompt("Calmá al pato (E) para poder extraer.")
		return

	# La extracción exige mantener F dentro de la zona.
	if not Input.is_action_pressed("interact"):
		_progress = 0.0
		_set_prompt("Mantené F para extraer (con el pato calmado).")
		return

	_progress = minf(hold_time, _progress + delta)

	if _progress >= hold_time:
		_set_prompt("¡Extracción completa!")
		GameState.complete_mission()
		return

	_set_prompt(
		"Extrayendo… %d%% — seguí manteniendo F."
		% int(round(_progress / hold_time * 100.0))
	)

func _is_guard_chasing() -> bool:
	for node in get_tree().get_nodes_in_group("guards"):
		var guard := node as GuardEnemy
		if guard == null or not guard.alive:
			continue
		if guard.state == GuardEnemy.GuardState.CHASE:
			return true

	return false

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerCharacter:
		_player = body as PlayerCharacter
		_inside = true

func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_inside = false
		_progress = 0.0

func _on_run_reset() -> void:
	_inside = false
	_progress = 0.0
	_last_prompt = ""
	queue_redraw()

func _on_mission_completed(_results: Dictionary) -> void:
	_progress = hold_time
	queue_redraw()

func _set_prompt(text: String) -> void:
	if text == _last_prompt:
		return

	_last_prompt = text
	prompt_changed.emit(text)

func _draw() -> void:
	# El aro de la zona se cierra a medida que avanza la extracción.
	var ratio := clampf(_progress / maxf(0.01, hold_time), 0.0, 1.0)
	draw_arc(
		Vector2.ZERO,
		58.0,
		-PI * 0.5,
		-PI * 0.5 + TAU * ratio,
		40,
		Color(0.35, 1.0, 0.6, 0.85),
		4.0
	)
