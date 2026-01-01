extends Node2D

var enemy_yellow = preload("res://Enemies/enemy_yellow.tscn")
var enemy_red = preload("res://Enemies/enemy_red.tscn")
var score = 0
var playing = false

@onready var start_button = $CanvasLayer/CenterContainer/Start
@onready var game_over = $CanvasLayer/CenterContainer/GameOver

func _ready():
	game_over.hide()
	start_button.show()
	var tween = create_tween().set_loops().set_parallel(false).set_trans(Tween.TRANS_SINE)
	tween.tween_property($EnemyAnchor, "position:x", $EnemyAnchor.position.x + 3, 1.0)
	tween.tween_property($EnemyAnchor, "position:x", $EnemyAnchor.position.x - 3, 1.0)
	var tween2 = create_tween().set_loops().set_parallel(false).set_trans(Tween.TRANS_BACK)
	tween2.tween_property($EnemyAnchor, "position:y", $EnemyAnchor.position.y + 3, 1.5).set_ease(Tween.EASE_IN_OUT)
	tween2.tween_property($EnemyAnchor, "position:y", $EnemyAnchor.position.y - 3, 1.5).set_ease(Tween.EASE_IN_OUT)	
	
func spawn_enemies():
	for x in range(9): 
		for y in range(4):
			var e
			if randf()<.5:
				e = enemy_yellow.instantiate()
			else:
				e = enemy_red.instantiate()
			var pos = Vector2(x * (16 + 8) + 24, 16 * 3 + y * 40)
			add_child(e)
			e.start(pos)
			e.anchor = $EnemyAnchor
			e.died.connect(_on_enemy_died)

func _on_enemy_died(value):
	score += value
	$CanvasLayer/UI.update_score(score)
	$Camera2D.add_trauma(0.5)
	
func _process(_delta):
	if get_tree().get_nodes_in_group("enemies").size() == 0 and playing:
		spawn_enemies()
	
func _on_player_died():
#	print("game over")
	playing = false
	get_tree().call_group("enemies", "queue_free")
	game_over.show()
	await get_tree().create_timer(2).timeout
	game_over.hide()
	get_tree().change_scene_to_file("res://levels/title_screen.tscn")
	start_button.show()
	
func new_game():
	score = 0
	$CanvasLayer/UI.update_score(score)
	$Player.start()
	spawn_enemies()
	playing = true 

func _on_start_pressed():
	start_button.hide()
	new_game()
	#spawn_enemies()
	
func _input(event):
	# Use the action you created in Input Map
	if event.is_action_pressed("start"):
		# Only start if we're at the start screen
		if start_button.visible and not playing:
			_on_start_pressed()
