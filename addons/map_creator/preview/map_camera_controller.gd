extends Camera2D
class_name MapCreatorCameraController

@export var zoom_step: float = 1.15
@export var min_zoom: float = 0.02
@export var max_zoom: float = 4.0
@export var fit_margin: float = 0.9

var _layout_bounds := Rect2()
var _map_area := Rect2()
var _panning := false

func set_layout_bounds(bounds: Rect2) -> void:
	_layout_bounds = bounds

func set_map_area(area: Rect2) -> void:
	_map_area = area

func fit() -> void:
	if _layout_bounds.size.x <= 0.0 or _layout_bounds.size.y <= 0.0:
		return

	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var area := _map_area
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		area = Rect2(Vector2.ZERO, viewport_size)

	var fit_zoom := minf(
		area.size.x / _layout_bounds.size.x,
		area.size.y / _layout_bounds.size.y
	) * fit_margin
	fit_zoom = clampf(fit_zoom, min_zoom, max_zoom)

	zoom = Vector2(fit_zoom, fit_zoom)
	var viewport_center := viewport_size * 0.5
	var area_center := area.get_center()
	position = _layout_bounds.get_center() - (area_center - viewport_center) / zoom

func _process(_delta: float) -> void:
	if _panning and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_panning = false

func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event != null:
		if (
			key_event.pressed
			and not key_event.echo
			and key_event.keycode == KEY_F
			and get_viewport().gui_get_focus_owner() == null
		):
			fit()
			get_viewport().set_input_as_handled()
		return

	var mouse_button := event as InputEventMouseButton
	if mouse_button != null:
		var mouse := get_viewport().get_mouse_position()

		if (
			mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP
			or mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN
		):
			if mouse_button.pressed and _map_area.has_point(mouse):
				var factor := (
					zoom_step
					if mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP
					else 1.0 / zoom_step
				)
				_zoom_at(mouse, factor)
				get_viewport().set_input_as_handled()
			return

		if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			if mouse_button.pressed:
				_panning = _map_area.has_point(mouse)
			else:
				_panning = false

			if _panning:
				get_viewport().set_input_as_handled()
			return

	var mouse_motion := event as InputEventMouseMotion
	if mouse_motion != null and _panning:
		position -= mouse_motion.relative / zoom
		get_viewport().set_input_as_handled()

func _zoom_at(screen_position: Vector2, factor: float) -> void:
	var old_zoom := zoom.x
	var new_zoom := clampf(old_zoom * factor, min_zoom, max_zoom)
	if is_equal_approx(old_zoom, new_zoom):
		return

	var viewport_center := get_viewport_rect().size * 0.5
	var before := position + (screen_position - viewport_center) / zoom
	zoom = Vector2(new_zoom, new_zoom)
	var after := position + (screen_position - viewport_center) / zoom
	position += before - after
