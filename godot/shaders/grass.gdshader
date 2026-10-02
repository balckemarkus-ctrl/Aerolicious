shader_type spatial;
render_mode cull_disabled;
// Grashalme rund um die Spielfigur. Die Halme liegen auf einem festen Weltgitter (Abstand spacing),
// Zufall (Versatz, Höhe, Drehung, Farbe) hängt nur von der Weltposition ab: Beim Mitwandern des
// Feldes springen die Halme nicht. Wind biegt die Spitzen.

uniform float spacing = 0.3;
uniform float radius = 16.0;
uniform vec4 no_grass = vec4(-14.0, 23.0, 14.0, 38.0); // x0, z0, x1, z1 (Stationsboden)
uniform vec3 base_color : source_color = vec3(0.18, 0.47, 0.10);
uniform vec3 tip_color : source_color = vec3(0.55, 0.86, 0.25);

varying float tip;
varying float shade;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec2 cell = floor(root.xz / spacing + 0.5);
	float h1 = hash(cell);
	float h2 = hash(cell + 17.3);
	float h3 = hash(cell + 41.7);
	vec2 jitter = (vec2(h1, h2) - 0.5) * spacing;
	float dist = length(root.xz + jitter - NODE_POSITION_WORLD.xz);
	float height = (0.2 + h3 * 0.22) * smoothstep(radius, radius - 4.0, dist);
	vec2 p = root.xz + jitter;
	if (p.x > no_grass.x && p.x < no_grass.z && p.y > no_grass.y && p.y < no_grass.w) height = 0.0;
	float ang = h1 * 6.2831;
	float t = VERTEX.y; // 0 = Wurzel, 1 = Spitze
	vec3 v = vec3(VERTEX.x * cos(ang), t * height, VERTEX.x * sin(ang));
	float wind = sin(TIME * 1.7 + p.x * 0.35 + p.y * 0.25) * 0.5 + sin(TIME * 3.1 + p.x * 1.3) * 0.15;
	v.x += (wind * 0.16 + (h2 - 0.5) * 0.12) * t * t;
	v.z += (wind * 0.08) * t * t;
	v.xz += jitter;
	VERTEX = v;
	NORMAL = vec3(0.0, 1.0, 0.0);
	tip = t;
	shade = 0.85 + h2 * 0.3;
}

void fragment() {
	ALBEDO = mix(base_color, tip_color, tip) * shade;
	BACKLIGHT = vec3(0.25, 0.45, 0.1) * tip;
	ROUGHNESS = 0.75;
	SPECULAR = 0.25;
}
