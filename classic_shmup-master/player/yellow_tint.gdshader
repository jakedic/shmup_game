// yellow_tint.gdshader - the yellow form's look: the normal player ship,
// tinted yellow (see player/player_visuals.gd update_form_tint()).
//
// Same trick as enemies/grayscale.gdshader: the node's modulate is captured
// in vertex() and applied on top, so the red damage flash / hit blink still
// show through.
//
//   tint     - the yellow
//   strength - how far the art is pushed toward the tint (0 = normal ship,
//              1 = fully yellow, details kept as light/dark)
//   flash    - 0..1, washes the ship toward bright solid yellow. Pulsed on
//              and off while the player is intangible after a full charge.
shader_type canvas_item;

uniform vec3 tint : source_color = vec3(1.0, 0.86, 0.2);
uniform float strength = 0.6;
uniform float flash = 0.0;

varying vec4 node_modulate;

void vertex() {
	node_modulate = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 colorized = tint * clamp(lum * 1.35 + 0.1, 0.0, 1.2);
	vec3 rgb = mix(tex.rgb, colorized, strength);
	rgb = mix(rgb, vec3(1.0, 0.95, 0.45), clamp(flash, 0.0, 1.0) * 0.85);
	COLOR = vec4(rgb, tex.a) * node_modulate;
}
