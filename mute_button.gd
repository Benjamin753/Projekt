extends Button

signal mute_changed(muted: bool)

func _ready() -> void:
	pressed.connect(update_state)
	update_state()

func update_state() -> void:
	tooltip_text = "Ton einschalten" if button_pressed else "Ton stummschalten"
	accessibility_name = tooltip_text
	mute_changed.emit(button_pressed)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		release_focus.call_deferred()

func _draw() -> void:
	var origin := size / 2.0 - Vector2(9, 8)
	var ink := Color("#eeeae2") if not disabled else Color("#b8afa4")
	var speaker := PackedVector2Array([Vector2(0, 6), Vector2(4, 6), Vector2(8, 2), Vector2(8, 14), Vector2(4, 10), Vector2(0, 10)])
	for i in speaker.size():
		speaker[i] += origin
	draw_colored_polygon(speaker, ink)
	if button_pressed:
		draw_line(origin + Vector2(12, 6), origin + Vector2(17, 11), ink, 1.4, true)
		draw_line(origin + Vector2(17, 6), origin + Vector2(12, 11), ink, 1.4, true)
	else:
		draw_arc(origin + Vector2(9, 8), 4.0, -.83, .83, 16, ink, 1.3, true)
		draw_arc(origin + Vector2(9, 8), 7.0, -.83, .83, 16, ink, 1.3, true)
