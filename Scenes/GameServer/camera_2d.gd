extends Camera2D

const SPEED := 4000

#region PROCESS
func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	
	if Input.is_action_pressed("ui_up"):
		dir.y -= 1
	if Input.is_action_pressed("ui_down"):
		dir.y += 1
	if Input.is_action_pressed("ui_left"):
		dir.x -= 1
	if Input.is_action_pressed("ui_right"):
		dir.x += 1
	
	if dir != Vector2.ZERO:
		dir = dir.normalized()
		position += dir * SPEED * delta
#endregion
