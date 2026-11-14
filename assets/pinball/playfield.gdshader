shader_type canvas_item;

float hash(vec2 p) {
	vec3 v = fract(vec3(p.xyx) * .1031);
	v += dot(v, v.yzx + 33.33);
	return fract((v.x + v.y) * v.z);
}

float grain(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + 1.0), f.x), f.y);
}

void fragment() {
	vec2 p = UV;
	vec2 lamp = (p - vec2(.43, .36)) * vec2(1.4, .92);
	float light = exp(-dot(lamp, lamp) * 4.0);
	float fibers = grain(vec2(p.x * 186.0 + sin(p.y * 10.0 + p.x * 7.0) * 2.2, p.y * 3.0));
	float finish = grain(p * vec2(670.0, 70.0));
	float pores = hash(floor(p * vec2(576.0, 984.0)));
	vec3 wood = mix(vec3(.066, .055, .049), vec3(.202, .172, .142), light);
	wood += vec3(1.0, .82, .63) * ((fibers - .5) * .027 + (finish - .5) * .015 + (pores - .5) * .016);
	float edge = min(p.x, 1.0 - p.x);
	float lip = 1.0 - smoothstep(.019, .025, edge);
	vec3 cabinet = mix(vec3(.035, .032, .031), vec3(.14, .125, .105), smoothstep(.003, .016, edge));
	wood = mix(wood, cabinet, lip * .9);
	COLOR = vec4(wood, 1.0);
}
