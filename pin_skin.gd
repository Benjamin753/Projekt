extends TextureRect

const MASK = preload("res://assets/pins/circle_mask.gdshader")

func _ready() -> void:
	set_skin(texture)

func set_skin(skin: AtlasTexture) -> void:
	texture = skin
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if material == null:
		material = ShaderMaterial.new()
		material.shader = MASK
	material.set_shader_parameter("source_region", Vector4(skin.region.position.x, skin.region.position.y, skin.region.size.x, skin.region.size.y))
