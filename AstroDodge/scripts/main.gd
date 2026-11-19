extends Node2D
# cerebro do jogo: estados (menu, jogando, pausado, game over), asteroides,
# pontos, vidas, efeitos e a interface

enum State { MENU, PLAYING, PAUSED, GAME_OVER }

const PlayerScript := preload("res://scripts/player.gd")
const BulletScript := preload("res://scripts/bullet.gd")
const AsteroidScript := preload("res://scripts/asteroid.gd")
const BackgroundScript := preload("res://scripts/background.gd")
const ShockwaveScript := preload("res://scripts/shockwave.gd")
const SfxScript := preload("res://scripts/sfx.gd")
const SAVE_PATH := "user://highscore.save"
const START_LIVES := 3
const LEVEL_TIME := 15.0  # a cada 15 seg sobe o nivel

var state: State = State.MENU
var score := 0
var high_score := 0
var new_record := false
var lives := START_LIVES
var level := 1
var elapsed := 0.0
var spawn_timer := 0.0
var shake := 0.0
var t := 0.0

var screen_size := Vector2.ZERO
var background: Node2D
var world: Node2D  # tudo q é asteroide, tiro e explosao fica aqui dentro
var player: Area2D
var sfx: Node

# coisas da interface
var bold_font: FontVariation
var title_font: FontVariation
var top_bar: Control
var score_label: Label
var level_label: Label
var lives_icons: Control
var center_box: CenterContainer
var panel_title: Label
var panel_sub: Label
var controls_grid: GridContainer
var panel_info: Label
var record_label: Label
var prompt_label: Label
var dim_overlay: ColorRect
var damage_flash: ColorRect
var level_banner: Label

var fire_ramp: Gradient
var spark_ramp: Gradient

func _ready() -> void:
	randomize()
	screen_size = get_viewport_rect().size
	load_high_score()
	make_fonts()
	# cores da explosao: branco, amarelo, laranja e some
	fire_ramp = make_gradient([Color(1, 1, 0.9, 1), Color(1, 0.85, 0.3, 1), Color(1, 0.4, 0.1, 0.8), Color(0.5, 0.1, 0.1, 0)], [0.0, 0.2, 0.55, 1.0])
	spark_ramp = make_gradient([Color(1, 0.95, 0.7, 1), Color(1, 0.5, 0.2, 0)], [0.0, 1.0])

	# a ordem importa: o q é adicionado primeiro fica atras
	background = BackgroundScript.new()
	add_child(background)
	world = Node2D.new()
	add_child(world)
	player = PlayerScript.new()
	player.shot_fired.connect(_on_shot_fired)
	player.hit.connect(_on_player_hit)
	add_child(player)
	player.reset(Vector2(screen_size.x / 2, screen_size.y - 90))
	sfx = SfxScript.new()
	add_child(sfx)

	build_hud()
	change_state(State.MENU)

# ---------- estados do jogo ----------
func change_state(new_state: State) -> void:
	state = new_state
	player.active = state == State.PLAYING
	# pausado = para os asteroides, a nave e o fundo
	var paused := state == State.PAUSED
	world.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT
	player.process_mode = world.process_mode
	background.scrolling = not paused
	if state == State.GAME_OVER:
		player.visible = false
		new_record = score > high_score
		if new_record:
			high_score = score
			save_high_score()
	update_hud()

func start_game() -> void:
	# limpa tudo do jogo anterior
	for c in world.get_children():
		c.queue_free()
	score = 0
	lives = START_LIVES
	level = 1
	elapsed = 0.0
	spawn_timer = 1.0
	new_record = false
	player.reset(Vector2(screen_size.x / 2, screen_size.y - 90))
	sfx.play("start")
	change_state(State.PLAYING)

# teclas do jogo: enter, pause e som
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("start") and state in [State.MENU, State.GAME_OVER]:
		start_game()
	elif event.is_action_pressed("pause"):
		if state == State.PLAYING:
			change_state(State.PAUSED)
		elif state == State.PAUSED:
			change_state(State.PLAYING)
	elif event.is_action_pressed("mute"):
		var muted := not AudioServer.is_bus_mute(0)
		AudioServer.set_bus_mute(0, muted)
		show_banner("SOM DESLIGADO" if muted else "SOM LIGADO")

func _process(delta: float) -> void:
	t += delta
	# textos piscando
	prompt_label.modulate.a = 0.35 + 0.65 * absf(sin(t * 3.0))
	record_label.modulate.a = 0.5 + 0.5 * absf(sin(t * 6.0))

	if state == State.PLAYING:
		elapsed += delta
		# sobe de nivel com o tempo
		var new_level := 1 + int(elapsed / LEVEL_TIME)
		if new_level > level:
			level = new_level
			show_banner("NÍVEL %d" % level)
			sfx.play("start")
			update_hud()
		# qnt mais tempo, mais asteroide (nao mecher nesses numeros senao fica impossivel)
		var interval := maxf(0.25, 1.0 - elapsed * 0.012)
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = interval
			spawn_asteroid()
	elif state != State.PAUSED:
		# no menu e no game over passa uns asteroides no fundo so de enfeite
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			spawn_timer = 1.3
			spawn_asteroid()

	# tremida da tela qnd apanha
	if shake > 0.0:
		shake -= delta
		var s := shake * 20.0
		position = Vector2(randf_range(-s, s), randf_range(-s, s))
	else:
		position = Vector2.ZERO

func spawn_asteroid() -> void:
	var a := AsteroidScript.new()
	var big := randf() < 0.25  # 25% de chance de vir um grandao
	var speed := randf_range(120, 200) + elapsed * 3.0
	a.setup(Vector2(randf_range(40, screen_size.x - 40), -40), speed, big)
	a.destroyed.connect(_on_asteroid_destroyed)
	a.damaged.connect(_on_asteroid_damaged)
	a.hit_player.connect(player.take_damage)
	world.add_child(a)

# ---------- eventos (tiro, colisao, dano) ----------
func _on_shot_fired(pos: Vector2) -> void:
	var b := BulletScript.new()
	b.position = pos
	world.add_child(b)
	sfx.play("shoot")

func _on_asteroid_damaged(pos: Vector2) -> void:
	make_particles(pos, 12, 0.3, 60.0, 170.0, spark_ramp, true, 1.5, 3.0)

func _on_asteroid_destroyed(asteroid: Area2D, by_bullet: bool) -> void:
	spawn_explosion(asteroid.position, asteroid.radius, asteroid.base_color)
	sfx.play("explosion")
	if by_bullet and state == State.PLAYING:
		score += asteroid.points
		var col := Color(1, 0.85, 0.35) if asteroid.big else Color(0.7, 1, 1)
		spawn_popup(asteroid.position, "+%d" % asteroid.points, col)
		update_hud()

func _on_player_hit() -> void:
	lives -= 1
	shake = 0.35
	sfx.play("hit")
	# tela pisca vermelho
	damage_flash.color.a = 0.22
	create_tween().tween_property(damage_flash, "color:a", 0.0, 0.4)
	update_hud()
	if lives <= 0:
		spawn_explosion(player.position, 45.0, Color(0.35, 0.85, 1.0))
		change_state(State.GAME_OVER)

# ---------- efeitos ----------
func spawn_explosion(pos: Vector2, size: float, rock_color: Color) -> void:
	# fogo
	make_particles(pos, int(size * 1.3), 0.6, 50.0, 220.0, fire_ramp, true, 2.0, 5.0)
	# pedacinhos de pedra
	var debris := make_gradient([rock_color.lightened(0.2), Color(rock_color, 0.0)], [0.0, 1.0])
	make_particles(pos, int(size * 0.5), 0.9, 40.0, 150.0, debris, false, 2.0, 4.0)
	# anel
	var ring := ShockwaveScript.new()
	ring.position = pos
	ring.max_radius = size * 1.8
	world.add_child(ring)

# explosao de particulas pra todo lado
func make_particles(pos: Vector2, amount: int, life: float, vmin: float, vmax: float, ramp: Gradient, glow: bool, smin: float, smax: float) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = maxi(amount, 4)
	p.one_shot = true
	p.explosiveness = 1.0  # sai tudo de uma vez
	p.lifetime = life
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.damping_min = 60.0  # vai freiando
	p.damping_max = 120.0
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	p.color_ramp = ramp
	if glow:
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = mat
	p.emitting = true
	world.add_child(p)
	# apaga depois q acaba (o tween para junto qnd pausa)
	p.create_tween().tween_callback(p.queue_free).set_delay(life + 0.5)

# numerozinho "+10" subindo
func spawn_popup(pos: Vector2, text: String, color: Color) -> void:
	var l := make_label(20, color, bold_font)
	l.text = text
	l.position = pos - Vector2(30, 14)
	l.size.x = 60
	world.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 45, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)

# texto grande no meio da tela q some sozinho ("NÍVEL 2", "SOM DESLIGADO"...)
func show_banner(text: String) -> void:
	level_banner.text = text
	level_banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(level_banner, "modulate:a", 0.0, 0.5)

func make_gradient(colors: Array, offsets: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g

# ---------- interface ----------
# fonte em negrito usando a fonte padrao da godot (assim nao precisa baixar fonte)
func make_fonts() -> void:
	bold_font = FontVariation.new()
	bold_font.base_font = ThemeDB.fallback_font
	bold_font.variation_embolden = 0.8
	title_font = FontVariation.new()
	title_font.base_font = ThemeDB.fallback_font
	title_font.variation_embolden = 1.2
	title_font.spacing_glyph = 3

func build_hud() -> void:
	var hud := CanvasLayer.new()  # o canvas layer nao treme junto com a tela
	add_child(hud)

	# tela vermelha rapidinha qnd leva dano
	damage_flash = ColorRect.new()
	damage_flash.color = Color(1, 0.1, 0.15, 0)
	full_rect(damage_flash)
	hud.add_child(damage_flash)

	# barra de cima: pontos, nivel e vidas
	top_bar = Control.new()
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(top_bar)
	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0, 0, 0.05, 0.45)
	bar_bg.size = Vector2(screen_size.x, 56)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(bar_bg)
	var line := ColorRect.new()
	line.color = Color(0.35, 0.85, 1.0, 0.5)
	line.position = Vector2(0, 56)
	line.size = Vector2(screen_size.x, 2)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(line)

	add_caption("PONTOS", Vector2(16, 6), 120, HORIZONTAL_ALIGNMENT_LEFT)
	score_label = make_label(24, Color.WHITE, bold_font)
	score_label.position = Vector2(16, 19)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top_bar.add_child(score_label)

	add_caption("NÍVEL", Vector2(0, 6), screen_size.x, HORIZONTAL_ALIGNMENT_CENTER)
	level_label = make_label(24, Color(0.5, 0.9, 1.0), bold_font)
	level_label.position = Vector2(0, 19)
	level_label.size.x = screen_size.x
	top_bar.add_child(level_label)

	add_caption("VIDAS", Vector2(screen_size.x - 136, 6), 120, HORIZONTAL_ALIGNMENT_RIGHT)
	lives_icons = Control.new()
	lives_icons.position = Vector2(screen_size.x - 104, 26)
	lives_icons.size = Vector2(90, 24)
	lives_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lives_icons.draw.connect(draw_lives)
	top_bar.add_child(lives_icons)

	# fundo escuro qnd pausa
	dim_overlay = ColorRect.new()
	dim_overlay.color = Color(0, 0, 0, 0.5)
	full_rect(dim_overlay)
	hud.add_child(dim_overlay)

	# texto grandao q aparece no meio
	level_banner = make_label(38, Color(0.5, 0.95, 1.0), title_font)
	level_banner.position = Vector2(0, screen_size.y * 0.3)
	level_banner.size.x = screen_size.x
	level_banner.modulate.a = 0.0
	hud.add_child(level_banner)

	# painel do meio. menu, pause e game over usam o msm painel, so muda o texto
	center_box = CenterContainer.new()
	full_rect(center_box)
	hud.add_child(center_box)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.03, 0.09, 0.78)
	sb.border_color = Color(0.35, 0.85, 1.0, 0.6)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(26)
	sb.shadow_color = Color(0.2, 0.7, 1.0, 0.25)
	sb.shadow_size = 14
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(380, 0)
	center_box.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	panel_title = make_label(38, Color(0.45, 0.9, 1.0), title_font)
	panel_title.add_theme_constant_override("shadow_offset_x", 0)
	panel_title.add_theme_constant_override("shadow_offset_y", 0)
	panel_title.add_theme_constant_override("shadow_outline_size", 16)  # brilho em volta do titulo
	box.add_child(panel_title)

	panel_sub = make_label(15, Color(0.7, 0.78, 0.95))
	panel_sub.text = "desvie  •  atire  •  sobreviva"
	box.add_child(panel_sub)
	box.add_child(make_divider())

	# tabelinha dos controles
	controls_grid = GridContainer.new()
	controls_grid.columns = 2
	controls_grid.add_theme_constant_override("h_separation", 18)
	controls_grid.add_theme_constant_override("v_separation", 6)
	controls_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for row in [["WASD / Setas", "mover"], ["Espaço / Clique", "atirar"], ["P / Esc", "pausar"], ["M", "som liga/desliga"]]:
		var key := make_label(17, Color(1, 0.85, 0.35), bold_font)
		key.text = row[0]
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		controls_grid.add_child(key)
		var action := make_label(17, Color(0.9, 0.93, 1.0))
		action.text = row[1]
		action.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		controls_grid.add_child(action)
	box.add_child(controls_grid)

	panel_info = make_label(20, Color.WHITE, bold_font)
	box.add_child(panel_info)

	record_label = make_label(22, Color(1, 0.82, 0.25), bold_font)
	record_label.text = "NOVO RECORDE!"
	box.add_child(record_label)

	prompt_label = make_label(19, Color(1, 0.85, 0.35), bold_font)
	box.add_child(prompt_label)

# atualiza todos os textos da tela
func update_hud() -> void:
	score_label.text = "%05d" % score
	level_label.text = str(level)
	lives_icons.queue_redraw()
	top_bar.visible = state != State.MENU
	center_box.visible = state != State.PLAYING
	dim_overlay.visible = state == State.PAUSED
	panel_sub.visible = state == State.MENU
	controls_grid.visible = state == State.MENU
	record_label.visible = state == State.GAME_OVER and new_record
	prompt_label.visible = state != State.PAUSED
	match state:
		State.MENU:
			set_title("ASTRO DODGE", Color(0.45, 0.9, 1.0))
			panel_info.text = "Recorde: %d" % high_score
			prompt_label.text = "ENTER para jogar"
		State.PAUSED:
			set_title("PAUSADO", Color(0.9, 0.95, 1.0))
			panel_info.text = "P ou Esc para continuar"
		State.GAME_OVER:
			set_title("GAME OVER", Color(1, 0.35, 0.45))
			panel_info.text = "Pontuação: %d\nRecorde: %d" % [score, high_score]
			prompt_label.text = "ENTER para jogar de novo"

func set_title(text: String, color: Color) -> void:
	panel_title.text = text
	panel_title.add_theme_color_override("font_color", color)
	panel_title.add_theme_color_override("font_shadow_color", Color(color, 0.45))

# coraçoes das vidas (as perdidas ficam cinza)
func draw_lives() -> void:
	for i in START_LIVES:
		var col := Color(1, 0.3, 0.42) if i < lives else Color(0.25, 0.25, 0.33)
		draw_heart(lives_icons, Vector2(14 + i * 30, 12), 10.0, col)

# coraçao = 2 bolinhas + 1 triangulo
func draw_heart(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_circle(c + Vector2(-s * 0.5, -s * 0.2), s * 0.55, col)
	ci.draw_circle(c + Vector2(s * 0.5, -s * 0.2), s * 0.55, col)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 1.02, 0), c + Vector2(s * 1.02, 0), c + Vector2(0, s)]), col)

func make_label(font_size: int, color: Color, font: Font = null) -> Label:
	var l := Label.new()
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

# textinho pequeno em cima dos numeros da barra
func add_caption(text: String, pos: Vector2, width: float, align: HorizontalAlignment) -> void:
	var l := make_label(12, Color(0.55, 0.8, 1.0, 0.9))
	l.text = text
	l.position = pos
	l.size.x = width
	l.horizontal_alignment = align
	top_bar.add_child(l)

func make_divider() -> ColorRect:
	var d := ColorRect.new()
	d.color = Color(0.35, 0.85, 1.0, 0.25)
	d.custom_minimum_size = Vector2(0, 2)
	return d

# faz o controle ocupar a tela toda e nao bloquear o mouse
func full_rect(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

# ---------- recorde (salva num arquivo pra nao perder qnd fecha o jogo) ----------
func load_high_score() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		high_score = f.get_32()

func save_high_score() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_32(high_score)
