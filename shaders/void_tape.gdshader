shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float tape_time = 0.0;
uniform float strength = 1.0;
uniform float whiteout = 0.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
void fragment() {
    vec2 uv = SCREEN_UV;
    float row = floor(uv.y * 360.0);
    float tracking = exp(-pow((uv.y - fract(tape_time * 0.055)) * 85.0, 2.0));
    uv.x += (sin(row * 0.7 + tape_time * 4.0) * 0.00035 + tracking * 0.002) * strength;
    vec2 grid = vec2(960.0, 540.0);
    uv = mix(uv, (floor(uv * grid) + 0.5) / grid, strength * 0.55);
    vec2 offset = vec2(0.0013 * strength, 0.0);
    vec3 c = vec3(texture(screen_texture, uv + offset).r, texture(screen_texture, uv).g, texture(screen_texture, uv - offset).b);
    c += (hash(vec2(row, floor(tape_time * 24.0)) + uv * 150.0) - 0.5) * 0.035 * strength;
    c *= 1.0 - (0.5 + 0.5 * sin(uv.y * 1080.0 * 3.14159)) * 0.065 * strength;
    vec2 edge = uv * (1.0 - uv);
    float vignette = clamp(pow(edge.x * edge.y * 16.0, 0.18), 0.0, 1.0);
    c *= mix(1.0, vignette, 0.56 * strength);
    c = mix(c, vec3(1.0, 0.98, 0.88), whiteout);
    COLOR = vec4(c, 1.0);
}
