shader_type canvas_item;
render_mode unshaded;
uniform sampler2D scene_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 resolution = vec2(320.0, 180.0);

void fragment() {
	vec2 pixel = floor(SCREEN_UV * resolution);
	vec2 uv = (pixel + vec2(0.5)) / resolution;
	vec3 color = texture(scene_texture, uv).rgb;
	float checker = mod(pixel.x + mod(pixel.y, 2.0), 2.0) - 0.5;
	float luminance = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(luminance), color, 0.72);
	color *= vec3(0.92, 1.0, 1.015);
	color = floor(clamp(color + checker / 48.0, 0.0, 1.0) * 40.0 + 0.5) / 40.0;
	vec2 center = SCREEN_UV * 2.0 - 1.0;
	color *= 1.0 - smoothstep(0.5, 1.5, length(center)) * 0.22;
	COLOR = vec4(color, 1.0);
}
