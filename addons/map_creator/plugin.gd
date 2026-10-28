@tool
extends EditorPlugin

const PREVIEW_SCENE := "res://addons/map_creator/preview/map_preview.tscn"
const PROJECT_PREVIEW_SCENE := "res://scenes/tools/map_creator_preview.tscn"
const MENU_ITEM := "Ejecutar preview de Map Creator"

func _enter_tree() -> void:
	add_tool_menu_item(MENU_ITEM, _run_preview)

func _exit_tree() -> void:
	remove_tool_menu_item(MENU_ITEM)

func _run_preview() -> void:
	var scene_path := (
		PROJECT_PREVIEW_SCENE
		if ResourceLoader.exists(PROJECT_PREVIEW_SCENE)
		else PREVIEW_SCENE
	)
	get_editor_interface().play_custom_scene(scene_path)
