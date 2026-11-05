class_name PlayerResources extends Control
# PlayerResources: munición, botellas y referencia de controles.

#region ─── Constructor ────────────────────────────────────────────────────────
@onready var ammo_label: Label = %Ammo
@onready var bottles_label: Label = %Bottles
@onready var controls_label: Label = %Controls
#endregion ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	ammo_label.visible = false
	bottles_label.visible = false

func set_ammo(current: int, reserve: int, reloading: bool = false) -> void:
	ammo_label.visible = true

	if reloading:
		ammo_label.text = "Munición: recargando… (%d reserva)" % reserve
	else:
		ammo_label.text = "%d / %d" % [current, reserve]

func set_bottles(count: int) -> void:
	bottles_label.visible = true
	bottles_label.text = "%d" % count

func set_controls(text: String) -> void:
	controls_label.text = text
