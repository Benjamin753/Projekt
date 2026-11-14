shader_type canvas_item;

uniform bool shadow = false;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	if (shadow) {
		float r = length(p);
		COLOR = vec4(0.025, 0.020, 0.015, 0.57 * exp(-r * r * 4.6) * (1.0 - smoothstep(0.75, 1.0, r)));
	} else {
		float rim = smoothstep(0.80, 0.94, length(p)) * (1.0 - smoothstep(0.94, 1.0, length(p)));
		float facing = smoothstep(-0.35, 1.0, dot(-p, normalize(vec2(0.65, 1.0))));
		vec2 streak = (p - vec2(-0.28, -0.57)) / vec2(0.38, 0.16);
		float gloss = exp(-dot(streak, streak) * 1.8) * 0.39;
		COLOR = vec4(1.0, 0.97, 0.87, (rim * facing * 0.33 + gloss) * (1.0 - smoothstep(0.94, 1.0, length(p))));
	}
}
