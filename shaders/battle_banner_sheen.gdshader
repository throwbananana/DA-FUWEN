shader_type canvas_item;

uniform float motion_amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV) * COLOR;
	if (base.a <= 0.0) {
		COLOR = base;
	} else {
		vec2 centered = UV * 2.0 - 1.0;
		float t = TIME * mix(0.0, 0.92, motion_amount);
		float sweep_line = fract(t * 0.34) * 1.9 - 0.45;
		float sweep = 1.0 - abs((UV.x - UV.y * 0.22) - sweep_line);
		sweep = smoothstep(0.78, 1.0, sweep);
		float center_glow = smoothstep(1.12, 0.16, length(centered * vec2(1.0, 1.38)));
		float edge_glow = smoothstep(0.94, 0.18, 1.0 - abs(centered.y));
		float sheen = clamp(center_glow * 0.22 + edge_glow * 0.16 + sweep * 0.36, 0.0, 0.56);
		vec3 lift = mix(base.rgb, vec3(1.0), 0.72);
		COLOR = vec4(base.rgb + lift * sheen, base.a);
	}
}
