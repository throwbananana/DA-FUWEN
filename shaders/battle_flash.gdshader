shader_type canvas_item;
render_mode blend_add;

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
	vec4 tint = COLOR;
	if (tint.a <= 0.0) {
		COLOR = tint;
	} else {
		vec2 uv = UV;
		vec2 centered = uv * 2.0 - 1.0;
		float t = TIME * mix(0.0, 1.15, motion_amount);
		float radial = 1.0 - smoothstep(0.08, 1.02, length(centered * vec2(0.94, 1.08)));
		float sweep = 1.0 - abs(centered.x * 0.88 - centered.y * 0.42 - sin(t + uv.y * 9.0) * 0.10);
		sweep = smoothstep(0.52, 1.0, sweep);
		float grain = noise(uv * 13.0 + vec2(t * 0.75, -t * 0.28));
		float mask = clamp(radial * 0.74 + sweep * 0.56 + grain * 0.14, 0.0, 1.0);

		vec3 rgb = tint.rgb * (0.72 + mask * 0.85);
		COLOR = vec4(rgb, tint.a * mask);
	}
}
