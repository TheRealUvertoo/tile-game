shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, unshaded;

// Works with Sprite3D material_override.
// Sprite3D auto-binds its texture to "texture_albedo".
// UV and COLOR are provided by Sprite3D (region_rect baked into UVs).

uniform sampler2D texture_albedo : source_color, filter_nearest;
uniform float brightness : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float alpha_scissor : hint_range(0.0, 1.0, 0.01) = 0.5;

void fragment() {
	vec4 tex = texture(texture_albedo, UV) * COLOR;
	ALBEDO = tex.rgb * tint_color.rgb * brightness;
	ALPHA = tex.a;
	if (ALPHA < alpha_scissor) {
		discard;
	}
}
