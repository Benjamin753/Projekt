extends CanvasLayer

const IVORY := Color("#fbf8f1")
const MUTED := Color("#d0c7bd")
const SILVER := Color("#f7f4ed")
const GOLD := Color("#efd6ab")
@export var font: Font
@export var strong_font: Font
var values: Array[Label] = []
var launch_hint: Label
var game: Node2D

func _ready() -> void:
	game = get_parent()
	var panel := Panel.new()
	panel.position = Vector2(16, 12)
	panel.size = Vector2(448, 96)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color("#34302ddf")
	surface.border_color = Color("#cfc2b74d")
	surface.set_border_width_all(1)
	surface.set_corner_radius_all(18)
	surface.shadow_color = Color("#100c0950")
	surface.shadow_size = 5
	surface.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", surface)
	add_child(panel)
	var title := add_label("STEEL BALLZ RUN", Vector2(32, 21), Vector2(205, 24), 17, IVORY)
	title.add_theme_font_override("font", strong_font)
	var launch_text := "Feder halten und loslassen" if DisplayServer.is_touchscreen_available() else "Leertaste halten und loslassen"
	launch_hint = add_label(launch_text, Vector2(111, 796), Vector2(230, 21), 12, MUTED)
	launch_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var headings := ["Aktueller Run", "Highscore", "Guthaben", "Kugeln"]
	var positions := [32.0, 151.0, 270.0, 389.0]
	var widths := [108.0, 108.0, 108.0, 59.0]
	var colors := [SILVER, IVORY, GOLD, IVORY]
	for index in headings.size():
		add_label(headings[index], Vector2(positions[index], 54), Vector2(widths[index], 17), 11, MUTED)
		var value := add_label("0", Vector2(positions[index], 69), Vector2(widths[index], 30), 24, colors[index])
		value.add_theme_font_override("font", strong_font)
		values.append(value)
	refresh()

func add_label(content: String, at: Vector2, bounds: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.position = at
	label.size = bounds
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	launch_hint.visible = game.phase == game.Phase.START
	var numbers := [game.score, game.high_score, game.credit, game.balls_left]
	for index in numbers.size():
		var content := str(numbers[index])
		if values[index].text != content:
			values[index].text = content
			var fit := floori(values[index].size.x / strong_font.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x * 24.0)
			values[index].add_theme_font_size_override("font_size", clampi(fit, 8, 24))
