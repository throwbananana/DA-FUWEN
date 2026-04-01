shader_type canvas_item;

uniform vec4 sheen_color : source_color = vec4(1.0, 0.95, 0.74, 1.0);
uniform float motion_amount : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void fragment() {
	vec4 base = COLOR;
	if (base.a <= 0.0) {
		COLOR = base;
	} else {
		vec2 uv = UV;
		vec2 centered = uv * 2.0 - 1.0;
		float t = TIME * mix(0.0, 0.82, motion_amount);
		float diagonal = uv.x - uv.y * 0.34;
		float sweep = 1.0 - abs(diagonal - (fract(t * 0.22) * 1.7 - 0.35));
		sweep = smoothstep(0.78, 1.0, sweep);
		float center_glow = smoothstep(1.18, 0.12, length(centered * vec2(1.0, 1.25)));
		float sparkle = smoothstep(0.72, 0.98, noise(uv * 9.0 + vec2(t * 0.35, -t * 0.22)));
		float sheen = clamp(center_glow * 0.16 + sweep * 0.28 + sparkle * 0.10, 0.0, 0.42);

		vec3 rgb = base.rgb + sheen_color.rgb * sheen;
		COLOR = vec4(rgb, base.a);
	}
}
