// rainbow.gdshader - recolors a sprite as a shifting rainbow (used by the
// rainbow astroid boss, enemies/boss_rainbow_astroid.tscn).
//
// Same idea as golden.gdshader: the astroid art is very dark, so tinting it
// can't make it bright. Each pixel's brightness becomes the brightness of the
// rainbow color, and the hue runs diagonally across the sprite and slides
// over time. Modulate is captured in vertex() and applied after, so the
// damage flash still works.
shader_type canvas_item;

// The art's brightest useful value - raise it if the colors look washed out.
uniform float brightness_range = 0.45;
uniform float hue_speed = 0.35;    // how fast the colors slide (rainbows per second)
uniform float hue_spread = 3.0;    // how many rainbows fit across the screen diagonal
uniform float saturation = 0.85;
uniform float min_value = 0.3;     // darkest parts of the art never go fully black

varying vec4 node_modulate;

void vertex() {
	node_modulate = COLOR;
}

vec3 hsv2rgb(vec3 c) {
	vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float t = clamp(lum / brightness_range, 0.0, 1.0);

	// Screen position (not UV) so the bands don't spin with the astroid and
	// work with the atlas region the sprite uses.
	float diag = (SCREEN_UV.x + SCREEN_UV.y) * 0.5;
	float hue = fract(diag * hue_spread - TIME * hue_speed);
	float sat = saturation * (1.0 - 0.6 * smoothstep(0.75, 1.0, t));   // highlights go a bit whiter
	vec3 col = hsv2rgb(vec3(hue, sat, mix(min_value, 1.0, t)));

	COLOR = vec4(col, tex.a) * node_modulate;
}
