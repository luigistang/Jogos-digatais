extends Node2D
# fundo do jogo: degrade, nebulosas e as estrelinhas caindo

var screen_size := Vector2.ZERO
var stars: Array = []
var nebulas: Array = []
var t := 0.0
var scrolling := true  # qnd pausa vira false e o fundo para

func _ready() -> void:
	screen_size = get_viewport_rect().size
	# 3 camadas de estrela. as do fundo sao menores e mais devagar, ai parece q tem profundidade
	var layers := [
		{"count": 60, "speed": 25.0, "size": 1.0, "alpha": 0.45},
		{"count": 35, "speed": 60.0, "size": 1.6, "alpha": 0.7},
		{"count": 14, "speed": 130.0, "size": 2.2, "alpha": 1.0},
	]
	# umas brancas, umas azuladas e umas amareladas
	var tints := [Color(1, 1, 1), Color(0.75, 0.85, 1.0), Color(1.0, 0.9, 0.75)]
	for layer in layers:
		for i in layer.count:
			stars.append({
				"pos": Vector2(randf() * screen_size.x, randf() * screen_size.y),
				"speed": layer.speed, "size": layer.size, "alpha": layer.alpha,
				"color": tints[randi() % tints.size()], "phase": randf() * TAU,
			})
	# nebulosa é so um circulo gigante bem transparente kkkk
	nebulas = [
		{"pos": Vector2(screen_size.x * 0.2, screen_size.y * 0.3), "r": 230.0, "color": Color(0.5, 0.15, 0.65)},
		{"pos": Vector2(screen_size.x * 0.9, screen_size.y * 0.7), "r": 260.0, "color": Color(0.1, 0.35, 0.7)},
		{"pos": Vector2(screen_size.x * 0.4, screen_size.y * 1.1), "r": 200.0, "color": Color(0.65, 0.15, 0.4)},
	]

func _process(delta: float) -> void:
	if not scrolling:
		return
	t += delta
	# estrela q sai por baixo volta la pra cima
	for s in stars:
		s.pos.y += s.speed * delta
		if s.pos.y > screen_size.y + 4:
			s.pos = Vector2(randf() * screen_size.x, -4)
	for n in nebulas:
		n.pos.y += 10.0 * delta
		if n.pos.y - n.r > screen_size.y:
			n.pos = Vector2(randf() * screen_size.x, -n.r)
	queue_redraw()

func _draw() -> void:
	# degrade roxo pro azul escuro. é maior q a tela por causa da tremida
	var top := Color(0.07, 0.02, 0.15)
	var bottom := Color(0.01, 0.04, 0.10)
	var m := 20.0
	draw_polygon(
		PackedVector2Array([Vector2(-m, -m), Vector2(screen_size.x + m, -m), screen_size + Vector2(m, m), Vector2(-m, screen_size.y + m)]),
		PackedColorArray([top, top, bottom, bottom]))
	# varios circulos transparentes um encima do outro = brilho suave
	for n in nebulas:
		for i in 10:
			var k := 1.0 - i / 10.0
			draw_circle(n.pos, n.r * k, Color(n.color, 0.035))
	# estrelas piscando (o sin faz o brilho ir e voltar)
	for s in stars:
		var c: Color = s.color
		c.a = s.alpha * (0.6 + 0.4 * sin(t * 3.0 + s.phase))
		draw_circle(s.pos, s.size, c)
		# as maiores ganham uma cruzinha de brilho
		if s.size > 2.0:
			var glow := Color(c, c.a * 0.4)
			draw_line(s.pos - Vector2(5, 0), s.pos + Vector2(5, 0), glow, 1.0)
			draw_line(s.pos - Vector2(0, 5), s.pos + Vector2(0, 5), glow, 1.0)
