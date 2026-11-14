shader_type canvas_item;

// Atlas UVs refer to the unchanged reference image. Hide only the exterior.
uniform vec4 source_region;

void fragment() {
	vec2 local_uv = (UV * vec2(textureSize(TEXTURE, 0)) - source_region.xy) / source_region.zw;
	float distance_to_center = length(local_uv - vec2(0.5));
	float edge = max(fwidth(distance_to_center), 0.001);
	COLOR.a *= 1.0 - smoothstep(0.5 - edge * 0.25, 0.5 + edge * 0.25, distance_to_center);
}
