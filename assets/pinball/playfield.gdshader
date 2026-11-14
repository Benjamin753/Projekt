shader_type canvas_item;

void fragment() {
	vec2 p = UV;
	float light = exp(-length((p - vec2(0.48, 0.30)) * vec2(1.2, 0.86)) * 2.1);
	vec3 base = mix(vec3(0.035, 0.047, 0.078), vec3(0.105, 0.16, 0.235), light);
	float grain = fract(sin(dot(floor(p * vec2(960.0, 1640.0)), vec2(12.9898, 78.233))) * 43758.5453);
	vec2 pixel = p * vec2(480.0, 820.0);
	vec2 tile = mod(pixel, 18.0) - vec2(9.0);
	float dot_pattern = 1.0 - smoothstep(0.5, 1.1, length(tile));
	float satin = 0.5 + 0.5 * sin((pixel.y + pixel.x * 0.7) * 0.22);
	base += (grain - 0.5) * 0.012 + satin * 0.008 + dot_pattern * 0.048;
	COLOR = vec4(base, 1.0);
}
