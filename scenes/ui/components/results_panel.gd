class_name ResultsPanel extends Control
# ResultsPanel: informe de fin de misión y formateo de estadísticas.

@onready var title: Label = $Center/Panel/Margin/VBox/ResultsTitle
@onready var details: Label = $Center/Panel/Margin/VBox/ResultsDetails
@onready var hint: Label = $Center/Panel/Margin/VBox/ResultsHint


func _ready() -> void:
	visible = false


func show_results(results: Dictionary) -> void:
	visible = true
	title.text = "MISIÓN COMPLETA"

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
	details.text = "\n".join(lines)
	hint.text = "Pulsa R para volver a intentarlo."


func hide_results() -> void:
	visible = false


func _format_time(seconds: float) -> String:
	var total := int(maxf(0.0, seconds))
	return "%02d:%02d" % [total / 60, total % 60]
