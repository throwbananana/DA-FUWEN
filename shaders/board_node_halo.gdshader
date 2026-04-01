shader_type canvas_item;
render_mode blend_add;

uniform vec4 halo_color : source_color = vec4(1.0, 0.84, 0.42, 1.0);
uniform float intensity : hint_range(0.0, 1.5) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 centered = UV * 2.0 - 1.0;
	float radial = length(centered * vec2(0.92, 0.78));
	float outer = 1.0 - smoothstep(0.56, 1.14, radial);
	float inner = 1.0 - smoothstep(0.24, 0.74, radial);
	float ring = clamp(outer - inner * 0.78, 0.0, 1.0);
	float sweep = 1.0 - abs(centered.x * 0.78 - centered.y * 0.42);
	sweep = smoothstep(0.52, 1.0, sweep);
	float energy = intensity * mix(0.62, 1.0, pulse);
	float alpha = clamp((ring + sweep * 0.22) * energy, 0.0, 1.0);
	COLOR = vec4(halo_color.rgb, alpha * halo_color.a);
}
