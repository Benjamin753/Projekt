shader_type canvas_item;

void fragment() {
	vec2 p = UV;
	float angle = p.x * .56 + p.y;
	float reflection = exp(-pow((angle - .46) * 11.0, 2.0));
	float shoulder = exp(-pow((angle - .53) * 43.0, 2.0));
	float falloff = smoothstep(.0, .20, p.y) * (1.0 - smoothstep(.50, .86, p.y));
	float inset = smoothstep(.025, .10, p.x) * (1.0 - smoothstep(.92, .995, p.x));
	COLOR = vec4(.96, .95, .89, (reflection * .039 + shoulder * .022) * falloff * inset);
}
