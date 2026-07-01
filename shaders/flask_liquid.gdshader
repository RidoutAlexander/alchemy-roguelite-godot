shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D cavity_mask : filter_linear, repeat_disable;
uniform vec4 liquid_deep : source_color = vec4(0.05, 0.18, 0.08, 1.0);
uniform vec4 liquid_mid : source_color = vec4(0.12, 0.45, 0.22, 1.0);
uniform vec4 liquid_bright : source_color = vec4(0.35, 0.72, 0.38, 1.0);
uniform vec4 liquid_dark : source_color = vec4(0.03, 0.12, 0.05, 1.0);
uniform vec4 bubble_highlight : source_color = vec4(0.55, 0.95, 0.62, 1.0);
uniform vec4 ripple_color : source_color = vec4(0.65, 1.0, 0.72, 1.0);
uniform float fill_level : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform float uv_aspect = 0.5625;
uniform float texture_uv_aspect = 0.5625;
uniform vec2 uv_scale = vec2(1.0, 0.8889);
uniform vec2 uv_offset = vec2(0.0, 0.0556);
uniform float interior_center_x = 0.500;
uniform float interior_half_width = 0.097;
uniform float interior_top = 0.130;
uniform float interior_flat_bottom = 0.822;
uniform float interior_bottom = 0.877;

float hash11(float p) {
	return fract(sin(p * 127.1) * 43758.5453);
}

vec2 texture_uv(vec2 control_uv) {
	return (control_uv - uv_offset) / uv_scale;
}

float sample_cavity(vec2 tuv) {
	if (tuv.x < 0.0 || tuv.x > 1.0 || tuv.y < 0.0 || tuv.y > 1.0) {
		return 0.0;
	}
	float edge = max(fwidth(tuv.x), fwidth(tuv.y));
	return smoothstep(0.42, 0.58, texture(cavity_mask, tuv).r);
}

float tube_distance(vec2 uv, vec2 origin) {
	vec2 d = (uv - origin) / vec2(interior_half_width, interior_half_width * texture_uv_aspect);
	return length(d);
}

float bubble_shape(vec2 uv, vec2 center, float radius) {
	float dist = tube_distance(uv, center);
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
	float base_radius = 0.008 + hash11(seed * 16.4) * 0.012;
	if (size_roll > 0.86) {
		base_radius = 0.03 + hash11(seed * 15.1) * 0.028;
	} else if (size_roll > 0.52) {
		base_radius = 0.014 + hash11(seed * 17.3) * 0.018;
	}
	return base_radius * (0.8 + life * 0.45);
}

float expanding_ripples(vec2 uv, vec2 origin, float progress, float strength) {
	float dist = tube_distance(uv, origin);
	float fade = (1.0 - progress) * strength;
	float r1 = progress * 0.18;
	float r2 = progress * 0.11;
	float ring1 = smoothstep(0.014, 0.0, abs(dist - r1)) * fade;
	float ring2 = smoothstep(0.009, 0.0, abs(dist - r2)) * fade * 0.6;
	return clamp(ring1 + ring2, 0.0, 1.0);
}

float surface_dome(vec2 uv, vec2 origin, float life, float radius) {
	float dist = tube_distance(uv, origin);
	float emerge = smoothstep(0.0, 0.22, life) * (1.0 - smoothstep(0.6, 1.0, life));
	float dome_r = radius * (1.1 + life * 1.1);
	return (1.0 - smoothstep(dome_r * 0.1, dome_r * 0.65, dist)) * emerge;
}

float surface_shadow_ring(vec2 uv, vec2 origin, float life, float radius) {
	float dist = tube_distance(uv, origin);
	float emerge = smoothstep(0.05, 0.25, life) * (1.0 - smoothstep(0.55, 0.9, life));
	float dome_r = radius * (1.0 + life * 0.85);
	float shadow = smoothstep(dome_r * 0.7, dome_r * 0.88, dist);
	shadow *= 1.0 - smoothstep(dome_r * 0.88, dome_r * 1.08, dist);
	return shadow * emerge;
}

void fragment() {
	vec2 uv = UV;
	vec2 tuv = texture_uv(uv);
	float cavity = sample_cavity(tuv);
	if (cavity < 0.01 || fill_level < 0.005) {
		discard;
	}

	float fill_top = interior_top;
	float fill_bottom = interior_bottom;
	float meniscus = fill_top + (1.0 - fill_level) * (fill_bottom - fill_top);
	meniscus += sin(TIME * 2.4 + tuv.x * 16.0) * 0.004 * fill_level;

	if (tuv.y < meniscus) {
		discard;
	}

	float depth = (tuv.y - meniscus) / max(fill_bottom - meniscus, 0.001);
	vec3 col = mix(liquid_bright.rgb, liquid_mid.rgb, depth * 0.55);
	col = mix(col, liquid_deep.rgb, depth * 0.75);
	col = mix(col, liquid_dark.rgb, smoothstep(0.7, 1.0, depth) * 0.25);

	float fill_span = max(fill_bottom - meniscus, 0.001);
	float slosh = sin(TIME * 2.2 + tuv.y * 18.0 + tuv.x * 9.0) * 0.018 * fill_level;
	col = mix(col, liquid_bright.rgb, slosh * (0.35 + depth * 0.45));
	col = mix(col, liquid_mid.rgb, sin(TIME * 1.6 + depth * 11.0) * 0.012 * fill_level);

	float bubble_glow = 0.0;
	float ripple_glow = 0.0;
	float dome_light = 0.0;
	float shadow_ring = 0.0;

	for (float layer = 0.0; layer < 3.0; layer += 1.0) {
		float layer_seed = layer * 97.0;
		for (float i = 0.0; i < 22.0; i += 1.0) {
			float seed = i + layer_seed;
			float anchor_x = hash11(seed * 2.11) - 0.5;
			float rise_speed = 0.11 + hash11(seed * 8.1) * 0.16;
			float rise_phase = fract(TIME * rise_speed + hash11(seed * 9.73));
			float spawn_depth = hash11(seed * 3.07);
			float bubble_y = fill_bottom - rise_phase * fill_span * 0.94 - fill_span * 0.03;
			float width_scale = mix(0.5, 1.0, sqrt(clamp((bubble_y - meniscus) / fill_span, 0.0, 1.0)));
			float sway = sin(TIME * (4.5 + hash11(seed * 5.3) * 3.5) + seed) * interior_half_width * 0.32;
			vec2 home = vec2(
				interior_center_x + anchor_x * interior_half_width * 1.25 * width_scale + sway,
				bubble_y
			);
			float inside_fill = step(meniscus, bubble_y) * step(bubble_y, fill_bottom);
			float life = inside_fill;
			life *= smoothstep(0.0, 0.08, rise_phase);
			life *= 1.0 - smoothstep(0.9, 1.0, rise_phase);
			life *= 0.55 + bubble_pop(TIME * 0.85 + seed, seed) * 0.45;

			if (life > 0.01) {
				float radius = bubble_radius(seed, life);
				float ripple_progress = clamp(rise_phase * 1.15, 0.0, 1.0);
				float ripple_strength = (1.0 - ripple_progress) * life * 0.65;
				ripple_glow = max(ripple_glow, expanding_ripples(tuv, home, ripple_progress, ripple_strength));
				dome_light = max(dome_light, surface_dome(tuv, home, life, radius));
				shadow_ring = max(shadow_ring, surface_shadow_ring(tuv, home, life, radius));

				vec2 emerge_pos = home + vec2(sway * 0.15, -life * radius * 0.35);
				float shape = bubble_shape(tuv, emerge_pos, radius * (0.65 + life * 0.55)) * life;
				bubble_glow = max(bubble_glow, shape);
			}
		}
	}

	col = mix(col, liquid_dark.rgb, shadow_ring * 0.38);
	col = mix(col, liquid_bright.rgb, dome_light * 0.45);
	col = mix(col, ripple_color.rgb, ripple_glow * 0.36);
	col = mix(col, bubble_highlight.rgb, bubble_glow * 0.52);

	COLOR = vec4(col, cavity * 0.96);
}