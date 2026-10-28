# HUD: interfaz de la partida (CanvasLayer instanciado en main.tscn).
#
# RECIBE información de:
#   * PlayerCharacter: status_message (texto de estado).
#   * Duck: agitation (barra y ánimo).
#   * GameState: alarma, misión completada y reinicio (señales).
#   * Level/main.gd: bind() con las referencias y show_status() para mensajes.
#
# COMUNICA información a:
#   * No escribe estado de juego: solo refleja datos en labels y barras.
#   * Su panel de resultados se muestra al recibir mission_completed.

extends CanvasLayer
class_name GameHUD

@onready var title_label: Label = $Root/TopLeft/Title
@onready var objective_label: Label = $Root/TopLeft/Objective
@onready var status_label: Label = $Root/TopLeft/Status
@onready var agitation_bar: ProgressBar = $Root/TopLeft/AgitationBar
@onready var mood_label: Label = $Root/TopLeft/Mood
@onready var alert_banner: Label = $Root/AlertBanner
@onready var ammo_label: Label = $Root/BottomRight/Ammo
@onready var bottles_label: Label = $Root/BottomRight/Bottles
@onready var controls_label: Label = $Root/BottomRight/Controls
@onready var prompt_label: Label = $Root/Prompt
@onready var crosshair: Crosshair = $Root/Crosshair
@onready var results_root: Control = $Root/Results
@onready var results_title: Label = $Root/Results/Center/Panel/Margin/VBox/ResultsTitle
@onready var results_details: Label = $Root/Results/Center/Panel/Margin/VBox/ResultsDetails
@onready var results_hint: Label = $Root/Results/Center/Panel/Margin/VBox/ResultsHint

var player: PlayerCharacter = null
var duck: Duck = null
var _status_timer := 0.0

func _ready() -> void:
	# Estado inicial: paneles ocultos y suscripción a los eventos globales.
	results_root.visible = false
	alert_banner.visible = false
	ammo_label.visible = false
	bottles_label.visible = false
	prompt_label.text = ""
	controls_label.text = (
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

func bind(player_ref: PlayerCharacter, duck_ref: Duck) -> void:
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

func _process(delta: float) -> void:
	if player == null or duck == null:
		return

	_update_crosshair()
	_update_agitation()
	_update_objective()
	_update_status(delta)
	set_ammo(player.ammo, player.reserve_ammo, player.is_reloading)
	set_bottles(player.bottles)

	if GameState.alarm_active:
		alert_banner.text = "ALERTA — te están buscando (%.0f s)" % GameState.alarm_time_left

func show_status(text: String, duration: float = 2.2) -> void:
	status_label.text = text
	_status_timer = duration

func show_prompt(text: String) -> void:
	prompt_label.text = text

func clear_prompt() -> void:
	prompt_label.text = ""

func set_ammo(current: int, reserve: int, reloading: bool = false) -> void:
	ammo_label.visible = true

	if reloading:
		ammo_label.text = "Munición: recargando… (%d reserva)" % reserve
	else:
		ammo_label.text = "Munición: %d / %d" % [current, reserve]

func set_bottles(count: int) -> void:
	bottles_label.visible = true
	bottles_label.text = "Botellas: %d" % count

func _update_crosshair() -> void:
	# El panel de resultados tapa la mira y devuelve el cursor del sistema.
	if GameState.is_complete():
		crosshair.reset()
		return

	crosshair.set_aiming(player.is_aiming)
	crosshair.set_spread(player.aim_spread)
	crosshair.set_target_hostile(player.aim_target_hostile)
	crosshair.set_reloading(player.is_reloading)

func _update_status(delta: float) -> void:
	# Un mensaje temporal (ruido/disparo) tapa el estado normal del jugador.
	if _status_timer > 0.0:
		_status_timer -= delta
	else:
		status_label.text = player.status_message

func _update_agitation() -> void:
	agitation_bar.value = duck.agitation

	if duck.agitation < 35.0:
		agitation_bar.modulate = Color("5ebc83")
		mood_label.text = "Pato: calmado"
	elif duck.agitation < 70.0:
		agitation_bar.modulate = Color("e4b64f")
		mood_label.text = "Pato: nervioso"
	else:
		agitation_bar.modulate = Color("e45b5b")
		mood_label.text = "Pato: alterado · va a graznar"

func _update_objective() -> void:
	if GameState.is_complete():
		objective_label.text = "¡MISIÓN CUMPLIDA! Pulsa R para reiniciar."
	elif Input.is_key_pressed(KEY_SHIFT):
		objective_label.text = "CORRER: más rápido, pero el pato se agita más."
	else:
		objective_label.text = (
			"Objetivo: llegá a la salida verde y mantené F con el pato."
		)

func _on_alarm_changed(active: bool, _position: Vector2, time_left: float) -> void:
	alert_banner.visible = active

	if active:
		alert_banner.text = "ALERTA — te están buscando (%.0f s)" % time_left

func _on_mission_completed(results: Dictionary) -> void:
	prompt_label.text = ""
	crosshair.reset()
	results_root.visible = true
	results_title.text = "MISIÓN COMPLETA"

	var lines: Array[String] = [
		"Rango: %s — %s" % [
			String(results.get("rank", "C")),
			String(results.get("rank_title", "")),
		],
		"Tiempo: %s" % _format_time(float(results.get("time", 0.0))),
		"Detecciones: %d" % int(results.get("detections", 0)),
		"Bajas: %d · Derribos: %d" % [
			int(results.get("kills", 0)),
			int(results.get("takedowns", 0)),
		],
		"Disparos: %d · Botellas: %d" % [
			int(results.get("gunshots", 0)),
			int(results.get("bottles", 0)),
		],
		"Graznidos: %d · Ruidos: %d" % [
			int(results.get("honks", 0)),
			int(results.get("noise_events", 0)),
		],
		"Documentos: %d / 3" % int(results.get("loot", 0)),
	]
	results_details.text = "\n".join(lines)
	results_hint.text = "Pulsa R para volver a intentarlo."

func _on_run_reset() -> void:
	results_root.visible = false
	alert_banner.visible = false
	prompt_label.text = ""
	crosshair.reset()
	_status_timer = 0.0
	status_label.text = ""

func _format_time(seconds: float) -> String:
	var total := int(maxf(0.0, seconds))
	return "%02d:%02d" % [total / 60, total % 60]
