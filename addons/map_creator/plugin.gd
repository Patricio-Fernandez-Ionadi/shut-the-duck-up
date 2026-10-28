@tool
extends EditorPlugin

const PREVIEW_SCENE := "res://addons/map_creator/preview/map_preview.tscn"
const MENU_ITEM := "Ejecutar preview de Map Creator"

func _enter_tree() -> void:
	add_tool_menu_item(MENU_ITEM, _run_preview)

func _exit_tree() -> void:
	remove_tool_menu_item(MENU_ITEM)

func _run_preview() -> void:
	get_editor_interface().play_custom_scene(PREVIEW_SCENE)
