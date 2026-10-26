shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 deep_color : source_color = vec4(0.025, 0.14, 0.18, 1.0);
uniform vec4 edge_color : source_color = vec4(0.25, 0.72, 0.68, 1.0);
uniform float phase = 0.0;
void fragment() {
    float r = length(UV - vec2(0.5));
    float ripple = sin(r * 95.0 - TIME * 0.65 + phase) * sin(UV.x * 50.0 + TIME * 0.2);
    float fine = pow(max(0.0, sin(r * 190.0 - TIME * 0.3)), 14.0);
    vec3 color = mix(deep_color.rgb, edge_color.rgb, 0.13 + ripple * 0.1 + fine * 0.15);
    ALBEDO = color;
    EMISSION = color * 0.2;
}
