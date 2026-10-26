// grayscale.gdshader - draws a sprite in greyscale (used by the gray enemies,
// see enemies/gray_enemy.gd and gray_*.tscn).
//
// In Godot 4 the fragment's COLOR input is already texture * modulate, so
// greyscaling COLOR would bring the art's own colors back in. Instead the
// node's modulate is captured in vertex() (where COLOR is just the modulate)
// and applied on top of the greyscaled texture - so the red damage flash
// still shows over the grey.
shader_type canvas_item;

// Brightness controls - defaults leave the image unchanged. Set per scene on
// the Sprite2D's ShaderMaterial (e.g. gray_bee.tscn brightens the bee).
//   brightness - multiplies the grey value (1.0 = unchanged)
//   lift       - raises the darkest greys toward white (0.0 = unchanged)
uniform float brightness = 1.0;
uniform float lift = 0.0;

varying vec4 node_modulate;

void vertex() {
	node_modulate = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	lum = clamp(lift + (1.0 - lift) * lum * brightness, 0.0, 1.0);
	COLOR = vec4(vec3(lum), tex.a) * node_modulate;
}
