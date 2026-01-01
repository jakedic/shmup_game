# base_enemy.gd
extends Area2D
class_name BaseEnemy  # Makes it available as a class

signal died(value: int)

# Common properties for ALL enemies
var start_pos = Vector2.ZERO
var speed = 0
var anchor
var follow_anchor = false

@onready var screensize = get_viewport_rect().size

# Must be implemented by child classes
var bullet_scene: PackedScene
func _ready():
	# If you want to set a specific bullet for this enemy type:
	bullet_scene = preload("res://bullets/enemy_bullet.tscn")

func start(pos: Vector2):
	follow_anchor = false
	speed = 0
	position = Vector2(pos.x, -pos.y)
	start_pos = pos
	await get_tree().create_timer(randf_range(0.25, 0.55)).timeout
	var tw = create_tween().set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "position:y", start_pos.y, 1.4)
	await tw.finished
	follow_anchor = true
	$MoveTimer.wait_time = randf_range(5, 20)
	$MoveTimer.start()
	$ShootTimer.wait_time = randf_range(4, 20)
	$ShootTimer.start()

func _process(delta):
	if follow_anchor:
		position = start_pos + anchor.position
	position.y += speed * delta
	if position.y > screensize.y + 32:
		start(start_pos)

func explode():
	speed = 0
	$AnimationPlayer.play("explode")
	set_deferred("monitorable", false)
	died.emit(5)  # Default 5 points
	await $AnimationPlayer.animation_finished
	queue_free()

func _on_timer_timeout():
	speed = randf_range(75, 100)
	follow_anchor = false

# Abstract method - child classes must override
func _on_shoot_timer_timeout():
	push_error("_on_shoot_timer_timeout not implemented in child class!")

# Common method for shooting
func shoot_bullet(bullet_position: Vector2):
	var b = bullet_scene.instantiate()
	get_tree().root.add_child(b)
	b.start(bullet_position)
