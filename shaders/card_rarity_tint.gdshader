shader_type canvas_item;

uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 luma_tint = luma * tint_color.rgb;
	vec3 multiply_tint = tex.rgb * tint_color.rgb;
	vec3 tinted = mix(luma_tint, multiply_tint, 0.45);
	vec3 result = mix(tex.rgb, tinted, tint_strength);
	COLOR = vec4(result, tex.a) * COLOR;
}