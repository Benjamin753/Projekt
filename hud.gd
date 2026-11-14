extends CanvasLayer

const IVORY := Color("#f0eee2")
const MUTED := Color("#8996ad")
const CYAN := Color("#71e3dd")
const GOLD := Color("#ffca7d")
var values: Array[Label] = []
var game: Node2D

func _ready() -> void:
	game = get_parent()
	var panel := Panel.new()
	panel.position = Vector2(16, 12)
	panel.size = Vector2(448, 96)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color("#101725")
	surface.border_color = Color("#293447")
	surface.set_border_width_all(1)
	surface.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", surface)
	add_child(panel)
	add_label("STEEL BALLZ RUN", Vector2(30, 20), Vector2(310, 22), 17, IVORY)
	var tag := add_label("PINBALL", Vector2(365, 23), Vector2(83, 18), 10, CYAN)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var headings := ["Aktueller Run", "Highscore", "Guthaben", "Kugeln"]
	var positions := [30.0, 153.0, 276.0, 399.0]
	var widths := [113.0, 113.0, 113.0, 49.0]
	var colors := [CYAN, IVORY, GOLD, IVORY]
	for index in headings.size():
		add_label(headings[index], Vector2(positions[index], 50), Vector2(widths[index], 17), 11, MUTED)
		values.append(add_label("0", Vector2(positions[index], 68), Vector2(widths[index], 28), 23, colors[index]))
	refresh()

func add_label(content: String, at: Vector2, bounds: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.position = at
	label.size = bounds
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func _process(_delta: float) -> void:
	refresh()

func refresh() -> void:
	var numbers := [game.score, game.high_score, game.credit, game.balls_left]
	for index in numbers.size():
		var content := str(numbers[index])
		if values[index].text != content:
			values[index].text = content
			values[index].add_theme_font_size_override("font_size", 18 if content.length() > 7 else 23)
