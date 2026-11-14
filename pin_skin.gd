extends TextureRect

const MASK = preload("res://assets/pins/circle_mask.gdshader")
@export var point_value := -1
@export var accent := Color("#b7c7dd")
var value_label: Label

func _ready() -> void:
	set_skin(texture, point_value, accent)

func set_skin(skin: AtlasTexture, points: int, skin_accent: Color) -> void:
	texture = skin
	accent = skin_accent
	point_value = points
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if material == null:
		material = ShaderMaterial.new()
		material.shader = MASK
	material.set_shader_parameter("source_region", Vector4(skin.region.position.x, skin.region.position.y, skin.region.size.x, skin.region.size.y))
	material.set_shader_parameter("replace_number", points >= 0)
	material.set_shader_parameter("accent", accent)
	if not is_instance_valid(value_label):
		value_label = Label.new()
		value_label.name = "Value"
		value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value_label.add_theme_color_override("font_color", Color("#f3f7ff"))
		add_child(value_label)
		value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(update_font_size)
	value_label.visible = points >= 0
	value_label.text = str(points)
	update_font_size()

func update_font_size() -> void:
	if is_instance_valid(value_label):
		value_label.add_theme_font_size_override("font_size", maxi(9, roundi(size.x * 0.35)))
