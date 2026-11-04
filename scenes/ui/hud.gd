class_name GameHUD extends CanvasLayer
# HUD: composición de la interfaz de partida (CanvasLayer instanciado en main.tscn).
#
# RECIBE información de:
#   * Player: status_message, arma y botellas.
#   * Duck: agitation.
#   * GameState: alarma, misión completada y reinicio (señales).
#   * Level/main.gd: bind() con las referencias y show_status() para mensajes.
#
# COMUNICA información a:
#   * Componentes visuales (DuckStatus, ObjectivePanel, AlertBanner,
#     PlayerResources, ResultsPanel): solo les pasa datos para mostrar.

#region ─── Constructor ────────────────────────────────────────────────────────
@onready var game_root: Control = $Root/IGame
@onready var prompt_label: Label = $Root/Prompt
@onready var crosshair: Crosshair = $Root/Crosshair

@onready var duck_status: DuckStatus = $Root/IGame/DuckStatus
@onready var objective_panel: ObjectivePanel = $Root/IGame/ObjectivePanel
@onready var alert_banner: AlertBanner = $Root/IGame/AlertBanner
@onready var player_resources: PlayerResources = $Root/IGame/PlayerResources
@onready var results_panel: ResultsPanel = $Root/Results

var player: Player = null
var duck: Duck = null
#endregion ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	prompt_label.text = ""
	player_resources.set_controls(
		"WASD mover · Shift correr · Ctrl/C agacharse · E calmar · F derribar · "
		+ "Q botella · RMB apuntar · LMB disparar · F3 debug"
	)

	GameState.alarm_changed.connect(_on_alarm_changed)
	GameState.mission_completed.connect(_on_mission_completed)
	GameState.run_reset.connect(_on_run_reset)

func _exit_tree() -> void:
	# Evita conexiones colgadas al recargar la escena.
	if GameState.alarm_changed.is_connected(_on_alarm_changed):
		GameState.alarm_changed.disconnect(_on_alarm_changed)
	if GameState.mission_completed.is_connected(_on_mission_completed):
		GameState.mission_completed.disconnect(_on_mission_completed)
	if GameState.run_reset.is_connected(_on_run_reset):
		GameState.run_reset.disconnect(_on_run_reset)
	if (
		is_instance_valid(crosshair)
		and is_instance_valid(player)
		and player.shot_hit.is_connected(crosshair.flash_hit)
	):
		player.shot_hit.disconnect(crosshair.flash_hit)

func bind(player_ref: Player, duck_ref: Duck) -> void:
	if (
		is_instance_valid(crosshair)
		and is_instance_valid(player)
		and player.shot_hit.is_connected(crosshair.flash_hit)
	):
		player.shot_hit.disconnect(crosshair.flash_hit)

	player = player_ref
	duck = duck_ref

	if player != null and not player.shot_hit.is_connected(crosshair.flash_hit):
		player.shot_hit.connect(crosshair.flash_hit)

func _process(_delta: float) -> void:
	if player == null or duck == null:
		return

	_update_crosshair()
	duck_status.set_agitation(duck.agitation, GameState.is_complete())
	objective_panel.set_state(GameState.is_complete(), Input.is_key_pressed(KEY_SHIFT))
	objective_panel.set_default_status(player.status_message)
	alert_banner.set_alarm(GameState.alarm_active, GameState.alarm_time_left)
	player_resources.set_ammo(
		player.weapon.ammo,
		player.weapon.reserve_ammo,
		player.weapon.is_reloading
	)
	player_resources.set_bottles(player.bottles)

func show_status(text: String, duration: float = 2.2) -> void:
	objective_panel.show_status(text, duration)

func show_prompt(text: String) -> void:
	prompt_label.text = text

func clear_prompt() -> void:
	prompt_label.text = ""

func _update_crosshair() -> void:
	# El panel de resultados tapa la mira y devuelve el cursor del sistema.
	if GameState.is_complete():
		crosshair.reset()
		return

	crosshair.set_aiming(player.is_aiming)
	crosshair.set_spread(player.weapon.aim_spread)
	crosshair.set_target_hostile(player.weapon._last_target_hostile)
	crosshair.set_reloading(player.weapon.is_reloading)

func _on_alarm_changed(active: bool, _position: Vector2, time_left: float) -> void:
	alert_banner.set_alarm(active, time_left)

func _on_mission_completed(results: Dictionary) -> void:
	prompt_label.text = ""
	crosshair.reset()
	game_root.visible = false
	results_panel.show_results(results)

func _on_run_reset() -> void:
	results_panel.hide_results()
	alert_banner.set_alarm(false, 0.0)
	prompt_label.text = ""
	crosshair.reset()
	objective_panel.reset()
