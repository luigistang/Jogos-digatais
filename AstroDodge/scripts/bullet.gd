extends Area2D
# o tiro. so sobe reto ate sair da tela

const SPEED := 650.0

func _ready() -> void:
	add_to_group("bullet")
	# colisao retangular
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(6, 18)
	shape.shape = rect
	add_child(shape)
	# modo ADD soma as cores e parece q ta brilhando
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat

func _process(delta: float) -> void:
	position.y -= SPEED * delta  # na godot y negativo é pra cima (confuso né)
	if position.y < -30:
		queue_free()  # saiu da tela apaga, senao vai acumulando tiro e fica lento

func _draw() -> void:
	# 3 linhas uma encima da outra: borda azul fraquinha, meio azul e o centro branco
	draw_line(Vector2(0, -11), Vector2(0, 11), Color(0.2, 0.8, 1.0, 0.25), 10.0)
	draw_line(Vector2(0, -10), Vector2(0, 10), Color(0.4, 0.95, 1.0, 0.6), 5.0)
	draw_line(Vector2(0, -9), Vector2(0, 9), Color(1, 1, 1), 2.0)
