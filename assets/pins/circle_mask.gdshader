shader_type canvas_item;

uniform vec4 source_region;
uniform bool replace_number = false;
uniform vec4 accent : source_color = vec4(0.72, 0.78, 0.86, 1.0);
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 atlas_size = vec2(textureSize(TEXTURE, 0));
	vec2 local_uv = (UV * atlas_size - source_region.xy) / source_region.zw;
	vec2 p = local_uv - vec2(0.5);
	float radius = length(p);
	float edge = max(fwidth(radius), 0.001);
	vec3 sample_color = texture(TEXTURE, UV).rgb;
	vec3 enamel = sample_color;
	if (replace_number) {
		// Keep the atlas artwork outside the inset that covers its printed value.
		float low = min(sample_color.r, min(sample_color.g, sample_color.b));
		float high = max(sample_color.r, max(sample_color.g, sample_color.b));
		float ink = max(1.0 - smoothstep(0.45, 0.70, high), smoothstep(0.19, 0.65, high - low));
		float inset = 1.0 - smoothstep(0.90, 1.04, length(p / vec2(0.275, 0.185)));
		float reflection = clamp(0.55 - p.x * 0.65 - p.y * 0.8, 0.0, 1.0);
		vec3 base = mix(vec3(0.055, 0.08, 0.12), accent.rgb * 0.48, reflection);
		enamel = mix(base, accent.rgb, ink * (1.0 - inset) * 0.74);
		float rim = smoothstep(0.432, 0.445, radius) * (1.0 - smoothstep(0.466, 0.478, radius));
		enamel = mix(enamel, accent.rgb, rim * (0.45 + reflection * 0.55));
	}
	COLOR = vec4(enamel, 1.0) * tint;
	COLOR.a *= 1.0 - smoothstep(0.49 - edge * 0.5, 0.49 + edge * 0.5, radius);
}
