shader_type spatial;
// Hallenboden: dunkle Metallplatten (4 m) mit Fugen und Nieten, leichte Gebrauchsspuren,
// leuchtender Ring um das Bauwerk und gelbe Markierungen zur Station.

uniform vec3 plate_a : source_color = vec3(0.16, 0.18, 0.22);
uniform vec3 plate_b : source_color = vec3(0.21, 0.23, 0.28);
uniform vec3 neon : source_color = vec3(0.18, 0.9, 1.0);
uniform vec3 paint : source_color = vec3(1.0, 0.76, 0.1);

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
	vec2 p = wpos.xz;
	vec2 cell = floor(p / 4.0);
	vec2 f = fract(p / 4.0) * 4.0;
	float seam = 1.0 - smoothstep(0.03, 0.07, min(min(f.x, 4.0 - f.x), min(f.y, 4.0 - f.y)));
	vec2 rv = abs(f - 0.35); vec2 rv2 = abs(f - 3.65);
	float rivet = 1.0 - smoothstep(0.05, 0.08, min(min(length(f - vec2(0.35)), length(f - vec2(3.65))), min(length(f - vec2(0.35, 3.65)), length(f - vec2(3.65, 0.35)))));
	vec3 c = mix(plate_a, plate_b, hash(cell));
	c *= 0.9 + 0.2 * noise(p * 6.0) * noise(p * 0.7);
	c = mix(c, c * 0.35, seam);
	c = mix(c, vec3(0.45, 0.5, 0.56), rivet);
	// Markierungen: Weg zur Station und Ring um das Bauwerk
	float r = length(p);
	float ring = smoothstep(0.12, 0.0, abs(r - 13.0)) + smoothstep(0.08, 0.0, abs(r - 13.6)) * 0.6;
	float lane = step(abs(p.x - 0.0), 3.2) * step(14.0, p.y) * step(p.y, 24.0);
	float lane_edge = lane * (1.0 - step(abs(p.x), 3.0));
	float chevron = lane * step(0.5, fract((p.y + abs(p.x) * 0.6) * 0.5)) * step(abs(p.x), 2.4);
	c = mix(c, paint, clamp(lane_edge + chevron * 0.85, 0.0, 1.0));
	ALBEDO = c;
	METALLIC = 0.6;
	ROUGHNESS = 0.45 + 0.25 * noise(p * 3.0) - seam * 0.1;
	EMISSION = neon * ring * 2.5;
}
