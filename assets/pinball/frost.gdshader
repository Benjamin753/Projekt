shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

void fragment() {
	vec3 background = textureLod(screen_texture, SCREEN_UV, 3.5).rgb;
	vec3 tint = mix(vec3(.161, .155, .148), vec3(.087, .083, .079), UV.y);
	COLOR = vec4(mix(tint, background, .56), 1.0);
}
