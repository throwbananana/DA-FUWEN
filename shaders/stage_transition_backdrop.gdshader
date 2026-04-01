shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.04, 0.07, 0.12, 1.0);
uniform vec4 accent_color : source_color = vec4(0.98, 0.74, 0.34, 1.0);
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
	vec2 uv = UV;
	vec2 centered = uv * 2.0 - 1.0;
	float t = TIME * mix(0.0, 0.75, motion_amount);
	float ring = 1.0 - smoothstep(0.18, 1.08, length(centered * vec2(1.0, 0.74)));
	float sweep = 1.0 - abs(centered.x * 0.78 + centered.y * 1.15 - sin(t + uv.y * 8.0) * 0.16);
	sweep = smoothstep(0.55, 1.0, sweep);
	float grain = noise(uv * 10.0 + vec2(t * 0.7, -t * 0.45));
	float scan = 0.96 + sin((uv.y + t * 0.18) * 90.0) * 0.04 * motion_amount;
	float accent_mask = clamp(ring * 0.42 + sweep * 0.62 + grain * 0.12, 0.0, 1.0);

	vec3 rgb = mix(base_color.rgb, accent_color.rgb, accent_mask * 0.55);
	rgb *= scan;

	float alpha = COLOR.a * (0.86 + accent_mask * 0.18);
	COLOR = vec4(rgb, alpha);
}
