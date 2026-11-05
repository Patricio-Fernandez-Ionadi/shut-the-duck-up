class_name ObjectivePanel extends Control
# ObjectivePanel: objetivo actual, mensajes de estado y toggle del panel.

#region ─── Constructor ────────────────────────────────────────────────────────
@onready var objective_label: Label = %ObjectiveLabel
@onready var status_label: Label = %ObjetiveStatus
@onready var toggle_button: Button = %ToggleObjetiveVisibility

const POS_X_OPENED := 22.0
const POS_X_CLOSED := -545.0
const DURATION := 0.6

var _status_timer := 0.0
var _default_status := ""
#endregion ─────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _status_timer > 0.0:
		_status_timer -= delta
	else:
		status_label.text = _default_status

func set_state(complete: bool, shift_pressed: bool) -> void:
	if complete:
		objective_label.text = "¡MISIÓN CUMPLIDA! Pulsa R para reiniciar."
	elif shift_pressed:
		objective_label.text = "CORRER: más rápido, pero el pato se agita más."
	else:
		objective_label.text = (
			"Objetivo: llegá a la salida verde y mantené F con el pato."
		)

func set_default_status(text: String) -> void:
	_default_status = text

func show_status(text: String, duration: float = 2.2) -> void:
	status_label.text = text
	_status_timer = duration

func reset() -> void:
	_status_timer = 0.0
	_default_status = ""
	status_label.text = ""

func _on_toggle_objetive_visibility_toggled(toggled_on: bool) -> void:
	toggle_button.text = "❌" if toggled_on else "👁"
	var target_x := POS_X_CLOSED if !toggled_on else POS_X_OPENED

	if toggled_on:
		create_tween().tween_property(self, "position:x", target_x, DURATION)\
		.set_trans(Tween.TRANS_BOUNCE)\
		.set_ease(Tween.EASE_OUT)
	else:
		create_tween().tween_property(self, "position:x", target_x, DURATION / 2)
