shader_type canvas_item;

// Customizable parameters
uniform float corner_radius : hint_range(0.0, 100.0) = 45.0;
uniform float border_thickness : hint_range(0.0, 50.0) = 12.0;
uniform vec4 border_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool anti_aliasing = true;

// Calculate signed distance to a rounded rectangle
float rounded_rect_sdf(vec2 center_pos, vec2 size, float radius) {
	return length(max(abs(center_pos) - size + radius, 0.0)) - radius;
}

void fragment() {
	// Get texture size in pixels
	vec2 texture_size = vec2(textureSize(TEXTURE, 0));

	// Convert UV to pixel coordinates
	vec2 pixel_pos = UV * texture_size;

	// Calculate center position relative to texture center
	vec2 center = pixel_pos - texture_size * 0.5;
	vec2 half_size = texture_size * 0.5;

	// Calculate signed distance to the outer rounded rectangle edge
	float outer_dist = rounded_rect_sdf(center, half_size, corner_radius);

	// Calculate signed distance to the inner rounded rectangle (for border)
	float inner_dist = rounded_rect_sdf(center, half_size - border_thickness, corner_radius - border_thickness);

	// Sample the texture
	vec4 tex_color = texture(TEXTURE, UV);

	// Calculate alpha for rounded corners (clip anything outside outer edge)
	float outer_alpha = 1.0;
	if (anti_aliasing) {
		outer_alpha = smoothstep(1.0, -1.0, outer_dist);
	} else {
		outer_alpha = step(outer_dist, 0.0);
	}

	// Determine if we're in the border region
	// Border is where outer_dist < 0 (inside shape) but inner_dist > 0 (outside inner shape)
	float is_border = 0.0;
	if (anti_aliasing) {
		float outer_mask = smoothstep(1.0, -1.0, outer_dist);
		float inner_mask = smoothstep(1.0, -1.0, inner_dist);
		is_border = outer_mask * (1.0 - inner_mask);
	} else {
		is_border = step(outer_dist, 0.0) * step(0.0, inner_dist);
	}

	// Mix border color with texture color
	vec3 final_color = mix(tex_color.rgb, border_color.rgb, is_border);

	// Apply the rounded corner clipping
	float final_alpha = tex_color.a * outer_alpha;

	// Ensure border is opaque where it should be visible
	if (is_border > 0.5) {
		final_alpha = max(final_alpha, border_color.a * outer_alpha);
	}

	COLOR = vec4(final_color, final_alpha);
}
