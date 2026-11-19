extends Area2D
# a nave do jogador. aqui fica o movimento e o tiro

signal shot_fired(pos: Vector2)
signal hit

const SPEED := 320.0
const SHOOT_COOLDOWN := 0.18   # tempo entre um tiro e outro
const INVULNERABLE_TIME := 1.5 # tempo q fica imortal depois de apanhar

var screen_size := Vector2.ZERO
var shoot_timer := 0.0
var invulnerable_timer := 0.0
var active := false  # so mexe qnd ta jogando, no menu fica paradinha
var tilt := 0.0      # inclinaçao qnd vai pros lados
var t := 0.0

func _ready() -> void:
	add_to_group("player")
	screen_size = get_viewport_rect().size
	# colisao em circulo, nao precisa ser perfeito
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 13.0
	shape.shape = circle
	add_child(shape)
	_make_engine_trail()

# fogo saindo do motor (particulas)
func _make_engine_trail() -> void:
	var trail := CPUParticles2D.new()
	trail.position = Vector2(0, 15)
	trail.amount = 40
	trail.lifetime = 0.45
	trail.local_coords = false  # isso faz o fogo ficar pra tras qnd a nave anda, sem isso fica estranho
	trail.direction = Vector2(0, 1)
	trail.spread = 12.0
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 90.0
	trail.initial_velocity_max = 150.0
	trail.scale_amount_min = 2.0
	trail.scale_amount_max = 4.5
	# cor vai de amarelo pra laranja e some
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	ramp.colors = PackedColorArray([Color(1, 0.95, 0.6, 1), Color(1, 0.55, 0.15, 0.8), Color(1, 0.25, 0.1, 0)])
	trail.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD  # brilha
	trail.material = mat
	trail.show_behind_parent = true
	add_child(trail)

func _process(delta: float) -> void:
	t += delta
	var dir := Vector2.ZERO
	if active:
		# pega as teclas (WASD ou setinhas)
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		# anda mexendo direto na posiçao (transform)
		position += dir * SPEED * delta
		# nao deixa sair da tela (nem entrar na barra de cima)
		position = position.clamp(Vector2(20, 70), screen_size - Vector2(20, 20))

		# atirar (espaço ou clique). tem um tempinho entre os tiros senao vira metralhadora
		shoot_timer -= delta
		if Input.is_action_pressed("shoot") and shoot_timer <= 0.0:
			shoot_timer = SHOOT_COOLDOWN
			shot_fired.emit(position + Vector2(0, -24))
	# inclina a nave devagarinho pro lado q ta indo
	tilt = lerpf(tilt, dir.x * 0.3, 10.0 * delta)
	rotation = tilt

	if invulnerable_timer > 0.0:
		invulnerable_timer -= delta
	queue_redraw()

# chamado qnd um asteroide bate na nave
func take_damage() -> void:
	if invulnerable_timer > 0.0 or not active:
		return  # ta imortal, nao toma dano
	invulnerable_timer = INVULNERABLE_TIME
	hit.emit()

# volta a nave pro lugar do começo
func reset(pos: Vector2) -> void:
	position = pos
	invulnerable_timer = 0.0
	shoot_timer = 0.0
	tilt = 0.0
	visible = true

# a nave é desenhada com poligonos, nao tem imagem nenhuma
func _draw() -> void:
	# pisca enquanto ta imortal
	var a := 1.0
	if invulnerable_timer > 0.0 and int(invulnerable_timer * 12.0) % 2 == 0:
		a = 0.3
	# brilhinho em volta
	draw_circle(Vector2(0, 2), 26, Color(0.2, 0.7, 1.0, 0.07 * a))
	# asas
	var wings := PackedVector2Array([Vector2(0, -6), Vector2(18, 11), Vector2(16, 17), Vector2(0, 11), Vector2(-16, 17), Vector2(-18, 11)])
	draw_colored_polygon(wings, Color(0.12, 0.45, 0.78, a))
	draw_polyline(wings + PackedVector2Array([wings[0]]), Color(0.5, 0.85, 1.0, 0.7 * a), 1.2, true)
	# corpo, com um lado mais escuro pra parecer 3D (mais ou menos kkkk)
	var body := PackedVector2Array([Vector2(0, -22), Vector2(7, -4), Vector2(6, 14), Vector2(-6, 14), Vector2(-7, -4)])
	draw_colored_polygon(body, Color(0.4, 0.88, 1.0, a))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -22), Vector2(7, -4), Vector2(6, 14), Vector2(0, 14)]), Color(0.22, 0.62, 0.92, a))
	draw_polyline(body + PackedVector2Array([body[0]]), Color(0.85, 0.98, 1.0, 0.9 * a), 1.5, true)
	# cabine do piloto
	draw_circle(Vector2(0, -5), 4.0, Color(0.85, 1.0, 1.0, a))
	draw_circle(Vector2(-1.2, -6.2), 1.4, Color(1, 1, 1, a))
	# luzinhas nas asas igual aviao (vermelha e verde)
	var blink := 0.4 + 0.6 * absf(sin(t * 4.0))
	draw_circle(Vector2(17, 14), 2.0, Color(1, 0.3, 0.35, blink * a))
	draw_circle(Vector2(-17, 14), 2.0, Color(0.35, 1, 0.5, blink * a))
	# escudo qnd ta imortal
	if invulnerable_timer > 0.0:
		var pulse := 0.5 + 0.5 * sin(t * 10.0)
		draw_arc(Vector2.ZERO, 27, 0, TAU, 40, Color(0.4, 0.9, 1.0, 0.3 + 0.35 * pulse), 2.0, true)
