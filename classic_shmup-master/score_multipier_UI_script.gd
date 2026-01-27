extends HBoxContainer

var digit_coords = {
	1: Vector2(7, 5),
}

func _ready():
	display_digits(1)

func display_digits(n):
	var s = "%08d" % n
	for i in 8:
		get_child(i).texture.region = Rect2(digit_coords[int(s[i])], Vector2(8, 8))
