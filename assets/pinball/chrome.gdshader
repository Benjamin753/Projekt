shader_type canvas_item;

void fragment() {
	float y = UV.y;
	float bevel = smoothstep(0.0, .19, y) * (1.0 - smoothstep(.80, 1.0, y));
	float key_light = exp(-pow((y - .25) * 8.0, 2.0));
	float bounce_light = exp(-pow((y - .79) * 13.0, 2.0));
	float brush = sin(y * 166.0 + sin(UV.x * 53.0) * 0.45) * .022;
	float value = .17 + bevel * .26 + key_light * .42 + bounce_light * .23 + brush;
	COLOR = vec4(vec3(value * 1.02, value, value * .94), COLOR.a);
}
