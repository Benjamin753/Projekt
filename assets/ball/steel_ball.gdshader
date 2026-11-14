shader_type canvas_item;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	// The original has a transparent margin around its printed circular silhouette.
	vec2 source_uv = (vec2(320.0, 310.5) + p * vec2(275.0, 278.5)) / vec2(640.0, 628.0);
	vec4 image = texture(TEXTURE, source_uv);
	float radius = length(p);
	float aa = max(fwidth(radius), 0.02);
	COLOR = vec4(image.rgb, image.a * (1.0 - smoothstep(1.0 - aa, 1.0, radius)));
}
