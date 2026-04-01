shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.01, 0.03, 0.06, 0.72);
uniform vec4 mist_color : source_color = vec4(0.17, 0.29, 0.43, 0.20);
uniform vec4 glow_color : source_color = vec4(0.98, 0.72, 0.33, 0.14);
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
	float t = TIME * mix(0.0, 0.12, motion_amount);
	float fog_a = noise(uv * 3.0 + vec2(t * 0.55, -t * 0.24));
	float fog_b = noise(uv * 5.4 - vec2(t * 0.26, t * 0.33));
	float fog = smoothstep(0.28, 0.82, mix(fog_a, fog_b, 0.42));
	float diagonal = 0.5 + 0.5 * sin((uv.y * 4.5 - uv.x * 2.2) + t * 3.2);
	float glow_band = smoothstep(0.74, 1.0, diagonal);
	float vignette = smoothstep(1.35, 0.18, length(centered * vec2(1.08, 0.92)));

	vec3 rgb = base_color.rgb;
	rgb += mist_color.rgb * fog * mist_color.a;
	rgb += glow_color.rgb * glow_band * vignette * glow_color.a;
	rgb = mix(base_color.rgb * 0.86, rgb, vignette);

	float alpha = base_color.a * (0.72 + vignette * 0.28);
	COLOR = vec4(rgb, alpha);
}
