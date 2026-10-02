shader_type spatial;
// Blöcke des Brockens: matter Kunststoff in satten Farben (Farbe je Instanz),
// gestreifte Panzerblöcke (INSTANCE_CUSTOM.r = 1) und glänzende Goldblöcke (INSTANCE_CUSTOM.g = 1).

uniform float roughness = 0.42;

varying vec3 local_pos;
varying vec3 local_n;
varying float striped;
varying float golden;
varying float explosive;
varying float crystal;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	local_pos = VERTEX;
	local_n = NORMAL;
	striped = INSTANCE_CUSTOM.r;
	golden = INSTANCE_CUSTOM.g;
	explosive = INSTANCE_CUSTOM.b;
	crystal = INSTANCE_CUSTOM.a;
}

void fragment() {
	vec3 c = srgb_to_linear(COLOR.rgb);
	vec3 an = abs(local_n);
	vec2 uv = an.x > 0.5 ? local_pos.zy : (an.y > 0.5 ? local_pos.xz : local_pos.xy);
	float band = smoothstep(0.46, 0.5, fract((uv.x + uv.y) * 2.6)) - smoothstep(0.96, 1.0, fract((uv.x + uv.y) * 2.6));
	c = mix(c, c * 0.62, striped * band);
	// Kanten leicht aufhellen (weiche Fase fängt Licht)
	float edge = smoothstep(0.38, 0.48, max(max(abs(local_pos.x) * (1.0 - an.x), abs(local_pos.y) * (1.0 - an.y)), abs(local_pos.z) * (1.0 - an.z)));
	// Explosivblock: breite schwarz-gelbe Warnstreifen und pulsierender Glutkern
	float hz = step(0.5, fract((uv.x - uv.y) * 1.6));
	c = mix(c, mix(c, vec3(0.03), hz), explosive);
	float pulse = 0.5 + 0.5 * sin(TIME * 6.0);
	ALBEDO = c * (1.0 + edge * 0.18);
	ROUGHNESS = mix(roughness, 0.18, golden);
	METALLIC = golden * 0.75;
	// Neon-Kanten in der Blockfarbe
	EMISSION = c * (golden * 0.35 + edge * 1.4 + crystal * 1.6) + vec3(1.0, 0.25, 0.05) * explosive * pulse * (1.0 - hz) * 0.8;
	ROUGHNESS = mix(ROUGHNESS, 0.05, crystal);
	SPECULAR = mix(0.45, 1.0, crystal);
}
