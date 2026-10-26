// golden.gdshader - recolors a sprite as shiny gold (used by the golden
// astroid, enemies/astroid_golden.tscn).
//
// The astroid art is very dark brown, so tinting it can't make it gold.
// Instead each pixel's brightness is mapped onto a gold color ramp (dark
// outline -> rich gold -> pale highlight), and a soft shine band sweeps
// across it every few seconds. Modulate is captured in vertex() and applied
// after, same as grayscale.gdshader, so the damage flash still works.
shader_type canvas_item;

uniform vec3 shadow_color : source_color = vec3(0.15, 0.08, 0.0);
uniform vec3 body_color : source_color = vec3(0.93, 0.66, 0.10);
uniform vec3 light_color : source_color = vec3(1.0, 0.86, 0.35);
uniform vec3 highlight_color : source_color = vec3(1.0, 0.98, 0.8);
// The art's brightest useful value - raise it if the gold looks too pale.
uniform float brightness_range = 0.45;
uniform float shine_interval = 2.5;   // seconds between shine sweeps
uniform float shine_width = 0.12;
uniform float shine_strength = 0.55;

varying vec4 node_modulate;

void vertex() {
	node_modulate = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float t = clamp(lum / brightness_range, 0.0, 1.0);

	vec3 gold = mix(shadow_color, body_color, smoothstep(0.0, 0.3, t));
	gold = mix(gold, light_color, smoothstep(0.3, 0.6, t));
	gold = mix(gold, highlight_color, smoothstep(0.6, 1.0, t));

	// Diagonal shine band. Uses screen position so it reads the same no
	// matter how the astroid is spinning or which part of the atlas it uses.
	float phase = fract(TIME / shine_interval) * 2.0 - 0.5;   // sweeps -0.5 .. 1.5
	float diag = (SCREEN_UV.x + SCREEN_UV.y) * 0.5;
	float band = 1.0 - smoothstep(0.0, shine_width, abs(diag - phase));
	gold = mix(gold, vec3(1.0), band * shine_strength * step(0.08, t));

	COLOR = vec4(gold, tex.a) * node_modulate;
}
