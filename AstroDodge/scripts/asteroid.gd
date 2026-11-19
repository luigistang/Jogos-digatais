extends Area2D
# asteroide. cai de cima com velocidade e rotaçao aleatoria
# os marrons sao os grandes e precisam de 2 tiros

signal destroyed(asteroid: Area2D, by_player_bullet: bool)
signal damaged(pos: Vector2)
signal hit_player

var velocity := Vector2.ZERO
var spin := 0.0
var angle := 0.0
var radius := 20.0
var hp := 1
var max_hp := 1
var points := 10
var big := false
var base_color := Color.GRAY
var base_shape := PackedVector2Array()
var craters: Array = []
var flash := 0.0
var screen_size := Vector2.ZERO

# aqui define tudo do asteroide antes dele entrar no jogo
func setup(pos: Vector2, speed: float, is_big: bool) -> void:
	position = pos
	big = is_big
	radius = 34.0 if big else randf_range(15.0, 22.0)
	hp = 2 if big else 1
	max_hp = hp
	points = 25 if big else 10
	base_color = Color(0.62, 0.4, 0.26) if big else Color(0.45, 0.47, 0.56)
	velocity = Vector2(randf_range(-60, 60), speed)
	spin = randf_range(-2.0, 2.0)
	angle = randf() * TAU
	# formato de pedra: um circulo com os pontos meio tortos
	var n := 14
	for i in n:
		base_shape.append(Vector2.from_angle(TAU * i / n) * radius * randf_range(0.78, 1.08))
	# crateras (bolinhas mais escuras)
	for i in (3 if big else randi_range(1, 2)):
		craters.append({"pos": Vector2.from_angle(randf() * TAU) * radius * randf_range(0.1, 0.45), "r": radius * randf_range(0.12, 0.22)})

func _ready() -> void:
	add_to_group("asteroid")
	screen_size = get_viewport_rect().size
	# colisao um pouco menor q o desenho, assim fica mais justo pro jogador
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius * 0.85
	shape.shape = circle
	add_child(shape)
	area_entered.connect(_on_area_entered)

func _process(delta: float) -> void:
	position += velocity * delta
	angle += spin * delta  # gira so o desenho, ai a luz continua vindo de cima
	# bateu na parede, volta
	if position.x < radius or position.x > screen_size.x - radius:
		velocity.x = -velocity.x
		position.x = clamp(position.x, radius, screen_size.x - radius)
	# saiu por baixo, tchau
	if position.y > screen_size.y + radius * 2:
		queue_free()
	if flash > 0.0:
		flash -= delta
	queue_redraw()

# colisao: ou foi tiro ou bateu na nave
func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("bullet"):
		area.queue_free()  # o tiro some
		hp -= 1
		flash = 0.08  # fica branco rapidinho
		if hp <= 0:
			destroyed.emit(self, true)
			queue_free()
		else:
			damaged.emit(area.position)  # grande q levou so 1 tiro solta faisca
	elif area.is_in_group("player") and area.active and area.invulnerable_timer <= 0.0:
		# bateu na nave. F
		hit_player.emit()
		destroyed.emit(self, false)
		queue_free()

# gira os pontos do desenho (concerteza tem jeito mais facil mas funciona)
func _rotated(points: PackedVector2Array, scale_f: float, offset: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p.rotated(angle) * scale_f + offset)
	return out

func _draw() -> void:
	var col := Color.WHITE if flash > 0.0 else base_color
	var shape := _rotated(base_shape, 1.0, Vector2.ZERO)
	# sombra, parte clara e brilho. a luz vem de cima/esquerda
	draw_colored_polygon(shape, col.darkened(0.45))
	draw_colored_polygon(_rotated(base_shape, 0.82, Vector2(-radius, -radius) * 0.1), col)
	draw_colored_polygon(_rotated(base_shape, 0.45, Vector2(-radius, -radius) * 0.22), col.lightened(0.12))
	# crateras
	for c in craters:
		var cp: Vector2 = c.pos.rotated(angle)
		draw_circle(cp, c.r, col.darkened(0.3))
		draw_arc(cp, c.r, PI * 0.15, PI * 1.15, 10, col.lightened(0.25), 1.2, true)
	# rachadura laranja qnd o grande ja levou um tiro
	if big and hp < max_hp:
		var crack := PackedVector2Array([Vector2(-0.7, -0.3), Vector2(-0.35, -0.12), Vector2(-0.2, -0.28), Vector2(0.1, 0.02), Vector2(0.28, -0.08), Vector2(0.6, 0.28)])
		for i in crack.size():
			crack[i] *= radius
		var pts := _rotated(crack, 1.0, Vector2.ZERO)
		draw_polyline(pts, col.darkened(0.6), 4.0, true)
		draw_polyline(pts, Color(1.0, 0.6, 0.2), 1.8, true)
	# contorno
	draw_polyline(shape + PackedVector2Array([shape[0]]), col.darkened(0.65), 2.0, true)
