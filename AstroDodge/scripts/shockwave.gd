extends Node2D
# aquele anel q cresce qnd alguma coisa explode

var max_radius := 40.0
var life := 0.4  # quanto tempo dura
var color := Color(1, 0.8, 0.4)
var t := 0.0

func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()  # acabou, some
		return
	queue_redraw()

func _draw() -> void:
	var k := t / life  # vai de 0 ate 1
	# qnt mais cresce mais fino e transparente fica
	draw_arc(Vector2.ZERO, max_radius * k, 0, TAU, 40, Color(color, 1.0 - k), 1.0 + 3.0 * (1.0 - k), true)
