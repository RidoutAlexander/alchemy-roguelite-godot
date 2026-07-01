shader_type canvas_item;
render_mode blend_mix;

uniform vec4 liquid_deep : source_color = vec4(0.14, 0.02, 0.34, 1.0);
uniform vec4 liquid_mid : source_color = vec4(0.42, 0.1, 0.72, 1.0);
uniform vec4 liquid_bright : source_color = vec4(0.62, 0.28, 0.88, 1.0);
uniform vec4 liquid_dark : source_color = vec4(0.1, 0.01, 0.22, 1.0);
uniform vec4 bubble_highlight : source_color = vec4(0.78, 0.48, 0.95, 1.0);
uniform vec4 ripple_color : source_color = vec4(0.88, 0.62, 1.0, 1.0);
uniform vec2 bowl_center = vec2(0.5, 0.52);
uniform vec2 bowl_radius = vec2(0.48, 0.46);
uniform float activity_level : hint_range(0.0, 1.0, 0.001) = 0.0;

float hash11(float p) {
	return fract(sin(p * 127.1) * 43758.5453);
}

float ellipse_mask(vec2 uv) {
	vec2 d = (uv - bowl_center) / bowl_radius;
	float ellipse = dot(d, d);
	return 1.0 - smoothstep(0.88, 1.0, ellipse);
}

float ellipse_dist(vec2 uv, vec2 origin) {
	vec2 d = (uv - origin) / bowl_radius;
	return length(d);
}

float bubble_shape(vec2 uv, vec2 center, float radius) {
	float dist = ellipse_dist(uv, center);
	float edge = max(fwidth(dist) * 0.85, 0.001);
	float ring = smoothstep(radius - edge, radius - edge * 0.25, dist);
	ring *= 1.0 - smoothstep(radius + edge * 0.05, radius + edge, dist);
	float glint = 1.0 - smoothstep(radius * 0.4, radius * 0.08, dist);
	return clamp(max(ring * 0.85, glint * 0.5), 0.0, 1.0);
}

float bubble_pop(float time, float seed) {
	float cycle_len = 2.8 + hash11(seed * 11.3) * 4.8;
	float cycle = fract(time / cycle_len + hash11(seed * 9.73));
	float pop_len = 0.24 + hash11(seed * 14.2) * 0.26;
	if (cycle > pop_len) {
		return 0.0;
	}
	float t = cycle / pop_len;
	return sin(t * 3.14159265);
}

float bubble_radius(float seed, float life) {
	float size_roll = hash11(seed * 4.19);
	float base_radius = 0.006 + hash11(seed * 16.4) * 0.01;
	if (size_roll > 0.86) {
		base_radius = 0.036 + hash11(seed * 15.1) * 0.038;
	} else if (size_roll > 0.52) {
		base_radius = 0.014 + hash11(seed * 17.3) * 0.02;
	}
	return base_radius * (0.8 + life * 0.45);
}

float expanding_ripples(vec2 uv, vec2 origin, float progress, float strength) {
	float dist = ellipse_dist(uv, origin);
	float fade = (1.0 - progress) * strength;
	float r1 = progress * 0.2;
	float r2 = progress * 0.13;
	float r3 = progress * 0.07;
	float ring1 = smoothstep(0.016, 0.0, abs(dist - r1)) * fade;
	float ring2 = smoothstep(0.011, 0.0, abs(dist - r2)) * fade * 0.6;
	float ring3 = smoothstep(0.007, 0.0, abs(dist - r3)) * fade * 0.35;
	return clamp(ring1 + ring2 + ring3, 0.0, 1.0);
}

float surface_dome(vec2 uv, vec2 origin, float life, float radius) {
	float dist = ellipse_dist(uv, origin);
	float emerge = smoothstep(0.0, 0.22, life) * (1.0 - smoothstep(0.6, 1.0, life));
	float dome_r = radius * (1.1 + life * 1.1);
	float dome = (1.0 - smoothstep(dome_r * 0.1, dome_r * 0.65, dist)) * emerge;
	return dome;
}

float surface_shadow_ring(vec2 uv, vec2 origin, float life, float radius) {
	float dist = ellipse_dist(uv, origin);
	float emerge = smoothstep(0.05, 0.25, life) * (1.0 - smoothstep(0.55, 0.9, life));
	float dome_r = radius * (1.0 + life * 0.85);
	float shadow = smoothstep(dome_r * 0.7, dome_r * 0.88, dist);
	shadow *= 1.0 - smoothstep(dome_r * 0.88, dome_r * 1.08, dist);
	return shadow * emerge;
}

void fragment() {
	vec2 uv = UV;
	float mask = ellipse_mask(uv);
	if (mask < 0.01) {
		discard;
	}

	vec2 bowl_d = (uv - bowl_center) / bowl_radius;
	float radial = clamp(dot(bowl_d, bowl_d), 0.0, 1.0);

	vec3 col = mix(liquid_mid.rgb, liquid_deep.rgb, radial * 0.45);
	col = mix(col, liquid_dark.rgb, smoothstep(0.55, 1.0, radial) * 0.22);
	col = mix(col, liquid_bright.rgb, (1.0 - radial) * 0.06);

	float fill = clamp(activity_level, 0.0, 1.0);
	float effect_boost = mix(1.0, 2.45, fill);
	float bubble_count = floor(mix(28.0, 88.0, fill) + 0.5);
	float time_scale = mix(1.0, 2.8, fill);
	float bubble_glow = 0.0;
	float ripple_glow = 0.0;
	float dome_light = 0.0;
	float shadow_ring = 0.0;

	for (float layer = 0.0; layer < 3.0; layer += 1.0) {
		float layer_seed = layer * 97.0;

		for (float i = 0.0; i < bubble_count; i += 1.0) {
			float seed = i + layer_seed;
			float anchor_x = hash11(seed * 2.11) - 0.5;
			float anchor_y = hash11(seed * 3.07) - 0.5;
			vec2 home = bowl_center + vec2(anchor_x, anchor_y) * bowl_radius * 1.85;
			vec2 home_d = (home - bowl_center) / bowl_radius;
			float inside = step(dot(home_d, home_d), 1.0);

			float life = bubble_pop(TIME * time_scale, seed) * inside;

			if (life > 0.01) {
				float radius = bubble_radius(seed, life) * mix(1.0, 1.15, fill);
				float ripple_progress = clamp(life * 2.0, 0.0, 1.0);
				float ripple_strength = (1.0 - ripple_progress) * life;
				ripple_glow = max(ripple_glow, expanding_ripples(uv, home, ripple_progress, ripple_strength));

				dome_light = max(dome_light, surface_dome(uv, home, life, radius));
				shadow_ring = max(shadow_ring, surface_shadow_ring(uv, home, life, radius));

				vec2 emerge_pos = home + vec2(0.0, -life * radius * 2.2);
				float emerge_radius = radius * (0.65 + life * 0.7);
				float shape = bubble_shape(uv, emerge_pos, emerge_radius) * life;
				bubble_glow = max(bubble_glow, shape);
			}
		}
	}

	col = mix(col, liquid_dark.rgb, shadow_ring * 0.38 * effect_boost);
	col = mix(col, liquid_bright.rgb, dome_light * 0.45 * effect_boost);
	col = mix(col, ripple_color.rgb, ripple_glow * 0.36 * effect_boost);
	col = mix(col, bubble_highlight.rgb, bubble_glow * 0.52 * effect_boost);

	COLOR = vec4(col, mask * 0.96);
}