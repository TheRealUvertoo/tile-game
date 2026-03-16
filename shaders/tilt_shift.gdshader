shader_type canvas_item;

// Tilt-shift post-process: sharp focal band in center, blur increases toward edges.
// Attach to a fullscreen ColorRect on a CanvasLayer.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

uniform float blur_strength : hint_range(0.0, 8.0) = 3.0;
uniform float focal_center : hint_range(0.0, 1.0) = 0.45;    // vertical center of sharp band
uniform float focal_width : hint_range(0.0, 0.5) = 0.15;      // half-width of sharp band
uniform float focal_falloff : hint_range(0.5, 10.0) = 3.0;    // how fast blur ramps up
uniform int blur_samples : hint_range(4, 16) = 8;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel_size = SCREEN_PIXEL_SIZE;

	// Distance from focal band (vertical only for tilt-shift look)
	float dist_from_center = abs(uv.y - focal_center);
	float blur_factor = smoothstep(focal_width, focal_width + (1.0 / focal_falloff), dist_from_center);
	float radius = blur_strength * blur_factor;

	if (radius < 0.01) {
		// Inside focal band — no blur needed
		COLOR = textureLod(screen_texture, uv, 0.0);
	} else {
		// Directional blur (horizontal-dominant for tilt-shift feel)
		vec4 sum = vec4(0.0);
		float total_weight = 0.0;
		float samples_f = float(blur_samples);

		for (int i = 0; i < blur_samples; i++) {
			float t = (float(i) / (samples_f - 1.0)) * 2.0 - 1.0; // -1..1
			// Elliptical kernel: wider horizontal, narrow vertical
			vec2 offset = vec2(t * radius * 1.5, t * radius * 0.6) * pixel_size;
			float w = 1.0 - abs(t) * 0.5; // center-weighted
			sum += textureLod(screen_texture, uv + offset, 0.0) * w;
			total_weight += w;
		}

		// Second pass: perpendicular direction for smoother bokeh
		for (int i = 0; i < blur_samples; i++) {
			float t = (float(i) / (samples_f - 1.0)) * 2.0 - 1.0;
			vec2 offset = vec2(-t * radius * 0.6, t * radius * 1.2) * pixel_size;
			float w = 1.0 - abs(t) * 0.5;
			sum += textureLod(screen_texture, uv + offset, 0.0) * w;
			total_weight += w;
		}

		COLOR = sum / total_weight;
	}
}
