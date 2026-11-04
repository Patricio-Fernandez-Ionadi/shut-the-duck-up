class_name DuckStatus extends VBoxContainer
# DuckStatus: ánimo y barra de agitación del pato.

@onready var agitation_bar: ProgressBar = %AgitationBar
@onready var mood_label: Label = %Mood


func set_agitation(value: float, complete: bool = false) -> void:
	if complete:
		return

	agitation_bar.value = value

	if value < 35.0:
		agitation_bar.modulate = Color("5ebc83")
		mood_label.text = "Pato: calmado"
		mood_label.modulate = Color("ffffff")
	elif value < 70.0:
		agitation_bar.modulate = Color("e4b64f")
		mood_label.text = "Pato: nervioso"
		mood_label.modulate = Color("e4b64f")
	else:
		agitation_bar.modulate = Color("e45b5b")
		mood_label.text = "Pato: alterado · va a graznar"
		mood_label.modulate = Color("e45b5b")
