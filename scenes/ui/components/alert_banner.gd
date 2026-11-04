class_name AlertBanner extends Label
# AlertBanner: aviso global cuando la alarma está activa.

func _ready() -> void:
	visible = false


func set_alarm(active: bool, time_left: float) -> void:
	visible = active

	if active:
		text = "ALERTA — te están buscando (%.0f s)" % time_left
