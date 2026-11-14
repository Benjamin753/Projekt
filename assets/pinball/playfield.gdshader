shader_type canvas_item;

void fragment() {
	vec2 p = UV;
	float light = exp(-length((p - vec2(0.48, 0.35)) * vec2(1.3, 1.0)) * 2.5);
	float grain = fract(sin(dot(floor(p * vec2(960.0, 1640.0)), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 base = mix(vec3(0.025, 0.042, 0.069), vec3(0.075, 0.13, 0.17), light);
	base += (grain - 0.5) * 0.009;
	COLOR = vec4(base, 1.0);
}
