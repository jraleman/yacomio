shader_type spatial;

uniform vec4 medium : source_color;
varying vec2 dish;

void vertex() {
	dish = VERTEX.xz / 2.66;
}

void fragment() {
	float r = length(dish);
	float ring = 1.0 - smoothstep(0.002, 0.012, abs(r - 0.82));
	float theta = atan(dish.y, dish.x + 0.0001);
	float graduations = smoothstep(0.78, 0.96, cos(theta * 32.0)) * smoothstep(0.87, 0.89, r);
	float lens = 1.0 - smoothstep(0.0, 1.2, length(dish + vec2(0.24, 0.19)));
	vec3 water = medium.rgb * (0.62 + 0.43 * lens);
	ALBEDO = mix(water, vec3(0.80, 0.95, 0.87), lens * 0.12 + ring * 0.27 + graduations * 0.65);
	ROUGHNESS = 0.48;
}
