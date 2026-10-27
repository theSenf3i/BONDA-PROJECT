shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, depth_test_disabled;
uniform sampler2D scene_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 fog_color = vec3(0.12, 0.17, 0.18);
uniform float fog_start = 15.0;
uniform float fog_end = 60.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float distance_from_camera = length(view.xyz / view.w);
	float mist = smoothstep(fog_start, fog_end, distance_from_camera);
	vec3 color = texture(scene_texture, SCREEN_UV).rgb;
	ALBEDO = mix(color, fog_color, mist);
}
