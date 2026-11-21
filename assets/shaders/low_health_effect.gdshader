shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_strength : hint_range(0.0, 5.0) = 1.4;
uniform float effect_weight : hint_range(0.0, 1.0) = 0.0;
uniform vec3 warm_tone : source_color = vec3(1.0, 0.76, 0.42);

void fragment() {
	if (effect_weight <= 0.001) {
		discard;
	}

	vec2 uv = SCREEN_UV;
	vec2 offset = SCREEN_PIXEL_SIZE * blur_strength * effect_weight * 1.6;

	// Subtle blur sampling using mipmap and screen offsets
	vec4 c_center = textureLod(screen_texture, uv, 1.2 * effect_weight);
	vec4 c_up     = textureLod(screen_texture, uv + vec2(0.0, offset.y), 0.8 * effect_weight);
	vec4 c_down   = textureLod(screen_texture, uv - vec2(0.0, offset.y), 0.8 * effect_weight);
	vec4 c_left   = textureLod(screen_texture, uv - vec2(offset.x, 0.0), 0.8 * effect_weight);
	vec4 c_right  = textureLod(screen_texture, uv + vec2(offset.x, 0.0), 0.8 * effect_weight);

	vec3 scene_color = (c_center.rgb * 2.0 + c_up.rgb + c_down.rgb + c_left.rgb + c_right.rgb) / 6.0;

	// Temperature Filter (Night Light mode):
	// Filter blue light heavily, increase red/amber warmth
	vec3 night_light = scene_color;
	night_light.r = min(1.0, night_light.r * 1.16);
	night_light.g = night_light.g * 0.95;
	night_light.b = night_light.b * 0.48; // Cut blue light by >50%

	// Add subtle warm incandescent ambient glow
	night_light += warm_tone * 0.06 * effect_weight;

	vec3 final_color = mix(scene_color, night_light, 0.82 * effect_weight);

	// Gentle cinematic vignette around screen edges
	vec2 dist = uv - vec2(0.5);
	float vignette = smoothstep(0.85, 0.25, length(dist));
	final_color = mix(final_color * 0.88, final_color, vignette);

	COLOR = vec4(final_color, effect_weight);
}
