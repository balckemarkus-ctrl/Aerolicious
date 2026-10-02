shader_type spatial;
// Wiesenboden: sattes Grün mit weichen Farbflecken (passend zu den Grashalmen).

uniform vec3 color_a : source_color = vec3(0.30, 0.68, 0.17);
uniform vec3 color_b : source_color = vec3(0.45, 0.80, 0.22);
uniform vec3 color_dry : source_color = vec3(0.62, 0.78, 0.25);

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = noise(wpos.xz * 0.08) * 0.6 + noise(wpos.xz * 0.5) * 0.3 + noise(wpos.xz * 3.0) * 0.1;
	vec3 c = mix(color_a, color_b, n);
	c = mix(c, color_dry, smoothstep(0.72, 0.95, noise(wpos.xz * 0.03 + 7.0)) * 0.35);
	ALBEDO = c;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
}
