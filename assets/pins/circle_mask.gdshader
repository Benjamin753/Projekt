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
	vec2 p = local_uv * 2.0 - 1.0;
	float r = length(p);
	float aa = max(fwidth(r), 0.013);
	vec3 face = texture(TEXTURE, UV).rgb;
	if (replace_number) {
		float low = min(face.r, min(face.g, face.b));
		float high = max(face.r, max(face.g, face.b));
		float engraving = max(1.0 - smoothstep(0.45, 0.70, high), smoothstep(0.19, 0.65, high - low));
		float number_inset = 1.0 - smoothstep(.90, 1.05, length(p / vec2(.57, .41)));
		float lift = sqrt(max(0.0, 1.0 - r * r));
		vec3 normal = normalize(vec3(p, lift));
		float key = max(dot(normal, normalize(vec3(-.52, -.73, .75))), 0.0);
		float groove = smoothstep(.52, .73, r) * (1.0 - smoothstep(.79, .86, r));
		vec3 cap = accent.rgb * (.16 + lift * .21 + key * .14);
		cap += accent.rgb * groove * .29;
		cap += accent.rgb * engraving * (1.0 - number_inset) * .48;
		vec2 reflection = (p - vec2(-.22, -.52)) / vec2(.40, .13);
		cap += vec3(.98, .94, .83) * exp(-dot(reflection, reflection) * 1.6) * .46;
		float bevel = smoothstep(.78, .83, r);
		float lip = smoothstep(.86, .89, r) * (1.0 - smoothstep(.93, .985, r));
		vec3 steel = vec3(.34, .33, .30) + key * .20 + lip * .42;
		face = mix(cap, steel, bevel);
	}
	COLOR = vec4(face, 1.0) * tint;
	COLOR.a *= 1.0 - smoothstep(.985 - aa, 1.0, r);
}
