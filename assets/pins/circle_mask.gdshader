shader_type canvas_item;

// Atlas UVs refer to the unchanged reference image. Hide only the exterior.
uniform vec4 source_region;
uniform bool replace_number = false;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 local_uv = (UV * vec2(textureSize(TEXTURE, 0)) - source_region.xy) / source_region.zw;
	float distance_to_center = length(local_uv - vec2(0.5));
	float edge = max(fwidth(distance_to_center), 0.001);
	vec4 skin = texture(TEXTURE, UV);
	if (replace_number) {
		vec2 extent = abs(local_uv - vec2(0.5)) / vec2(0.23, 0.14);
		float cover = 1.0 - smoothstep(0.97, 1.03, max(extent.x, extent.y));
		vec2 clean_uv = (source_region.xy + vec2(0.5, 0.34) * source_region.zw) / vec2(textureSize(TEXTURE, 0));
		skin.rgb = mix(skin.rgb, texture(TEXTURE, clean_uv).rgb, cover);
	}
	COLOR = skin * tint;
	COLOR.a *= 1.0 - smoothstep(0.5 - edge * 0.25, 0.5 + edge * 0.25, distance_to_center);
}
