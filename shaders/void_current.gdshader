shader_type spatial;
render_mode unshaded, cull_disabled;

void vertex() {
    float ripple = sin(UV.x * 75.0 - TIME * 1.8 + UV.y * 6.28318);
    VERTEX += NORMAL * ripple * 0.045;
}

void fragment() {
    float flow = UV.x * 90.0 - TIME * 1.6;
    float swirl = sin(UV.y * 18.84956 + sin(flow * 0.18) * 2.0);
    float highlight = pow(max(0.0, sin(flow + swirl * 2.5)), 12.0);
    float sheen = 0.5 + 0.5 * sin(UV.y * 6.28318 + 0.6);
    vec3 water = mix(vec3(0.025, 0.12, 0.16), vec3(0.15, 0.40, 0.43), sheen);
    ALBEDO = water + vec3(0.25, 0.40, 0.36) * highlight * 0.5;
    EMISSION = ALBEDO * 0.15;
}
