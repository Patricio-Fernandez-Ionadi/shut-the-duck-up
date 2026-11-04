extends Node2D

# USED BY: _set_camera_for_level
@onready var player_cam: Camera2D = $Player/Camera
@onready var ground_layer: TileMapLayer = $level_design/ground


func _ready() -> void:
	_set_camera_for_level()

func _set_camera_for_level():
	var rect := ground_layer.get_used_rect()
	var ts := ground_layer.tile_set.tile_size
	player_cam.limit_left   = rect.position.x * ts.x
	player_cam.limit_top    = rect.position.y * ts.y
	player_cam.limit_right  = rect.end.x * ts.x
	player_cam.limit_bottom = rect.end.y * ts.y
	
