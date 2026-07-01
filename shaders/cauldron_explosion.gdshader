shader_type canvas_item;
render_mode blend_mix;

uniform float expand_t : hint_range(0.0, 1.0, 0.001) = 0.0;
uniform vec2 burst_origin = vec2(0.5, 0.4);
uniform float max_scale = 0.52;
uniform vec4 liquid_deep : source_color = vec4(0.14, 0.02, 0.34, 1.0);
uniform vec4 liquid_mid : source_color = vec4(0.42, 0.1, 0.72, 1.0);
uniform vec4 liquid_bright : source_color = vec4(0.62, 0.28, 0.88, 1.0);
uniform vec4 splash_highlight : source_color = vec4(0.88, 0.62, 1.0, 1.0);

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * noise(p);
		p *= 2.03;
		amplitude *= 0.5;
	}
	return value;
}

vec2 splatter_local(vec2 uv, float scale) {
	vec2 delta = uv - burst_origin;
	return delta / max(scale, 0.0008);
}

float soft_blob(vec2 p, vec2 center, float radius, vec2 stretch) {
	vec2 d = (p - center) / (radius * stretch);
	return 1.0 - smoothstep(0.48, 1.0, dot(d, d));
}

float splatter_body_raw(vec2 p) {
	float shape = 0.0;

	shape = max(shape, soft_blob(p, vec2(0.0, 0.0), 0.2, vec2(1.1, 0.9)));
	shape = max(shape, soft_blob(p, vec2(-0.36, -0.06), 0.17, vec2(1.12, 0.86)));
	shape = max(shape, soft_blob(p, vec2(-0.2, -0.28), 0.13, vec2(0.94, 1.02)));
	shape = max(shape, soft_blob(p, vec2(0.1, -0.32), 0.12, vec2(1.04, 0.94)));
	shape = max(shape, soft_blob(p, vec2(0.32, -0.2), 0.11, vec2(1.06, 0.88)));
	shape = max(shape, soft_blob(p, vec2(0.4, 0.04), 0.15, vec2(1.08, 0.9)));
	shape = max(shape, soft_blob(p, vec2(-0.3, 0.14), 0.1, vec2(1.04, 0.94)));
	shape = max(shape, soft_blob(p, vec2(0.24, 0.18), 0.11, vec2(0.92, 1.05)));
	shape = max(shape, soft_blob(p, vec2(-0.04, 0.26), 0.13, vec2(1.0, 1.0)));
	shape = max(shape, soft_blob(p, vec2(0.1, 0.34), 0.1, vec2(0.88, 1.08)));
	shape = max(shape, soft_blob(p, vec2(0.34, 0.3), 0.09, vec2(0.95, 1.02)));
	shape = max(shape, soft_blob(p, vec2(-0.4, 0.26), 0.085, vec2(1.02, 0.96)));
	shape = max(shape, soft_blob(p, vec2(-0.14, 0.38), 0.08, vec2(0.9, 1.06)));
	shape = max(shape, soft_blob(p, vec2(0.22, 0.42), 0.075, vec2(0.86, 1.1)));
	shape = max(shape, soft_blob(p, vec2(-0.24, 0.46), 0.05, vec2(1.0, 1.0)));
	shape = max(shape, soft_blob(p, vec2(0.18, 0.5), 0.048, vec2(1.0, 1.0)));
	shape = max(shape, soft_blob(p, vec2(-0.52, -0.14), 0.075, vec2(1.0, 1.0)));
	shape = max(shape, soft_blob(p, vec2(0.5, -0.08), 0.07, vec2(1.0, 1.0)));
	shape = max(shape, soft_blob(p, vec2(-0.54, 0.04), 0.045, vec2(1.0, 1.0)));
	shape = max(shape, soft_blob(p, vec2(0.54, 0.16), 0.04, vec2(1.0, 1.0)));
	shape = max(shape, soft_blob(p, vec2(-0.22, -0.42), 0.042, vec2(1.0, 1.0)));
	shape = max(shape, soft_blob(p, vec2(0.16, -0.48), 0.04, vec2(1.0, 1.0)));

	return shape;
}

float splatter_body(vec2 p) {
	float edge_warp = fbm(p * 2.4) * 0.06;
	return smoothstep(0.22 + edge_warp, 0.52 + edge_warp, splatter_body_raw(p));
}

float splatter_at(vec2 uv, float expansion) {
	float eased = pow(expansion, 0.68);
	float scale = mix(0.006, max_scale, eased);
	vec2 p = splatter_local(uv, scale);
	float body = splatter_body(p);

	if (expansion < 0.1) {
		float pop = 1.0 - smoothstep(0.0, 0.1, length(splatter_local(uv, 0.006)));
		body = max(body, pop * smoothstep(0.0, 0.1, expansion));
	}

	float flash = (1.0 - smoothstep(0.0, 0.12, expansion)) * body;
	body = max(body, flash * 0.4);

	return clamp(body, 0.0, 1.0);
}

void fragment() {
	vec2 uv = UV;

	float splatter = splatter_at(uv, expand_t);
	if (splatter < 0.01) {
		discard;
	}

	vec3 col = mix(liquid_deep.rgb, liquid_mid.rgb, splatter * 0.58);
	col = mix(col, liquid_bright.rgb, splatter * 0.18);

	float shimmer = fbm(uv * 34.0 + vec2(TIME * 0.8, 0.0)) * 0.06;
	col += shimmer * splatter;

	float flash = (1.0 - smoothstep(0.0, 0.1, expand_t)) * splatter;
	col = mix(col, splash_highlight.rgb, flash * 0.5);

	COLOR = vec4(col, splatter * 0.98);
}