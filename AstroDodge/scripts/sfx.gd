extends Node
# sons do jogo. é tudo feito por codigo, nao tem nenhum arquivo de audio

const RATE := 22050  # qualidade do som
var players := {}

func _ready() -> void:
	# cada som: duraçao, frequencia inicial, frequencia final, quanto de chiado e volume
	_add("shoot", _make_sound(0.09, 900.0, 300.0, 0.0, 0.12))     # piu piu
	_add("explosion", _make_sound(0.45, 120.0, 40.0, 0.9, 0.5))   # boom
	_add("hit", _make_sound(0.35, 220.0, 55.0, 0.4, 0.5))         # qnd a nave apanha
	_add("start", _make_sound(0.2, 440.0, 990.0, 0.0, 0.2))       # começar e subir de nivel

func play(sound: String) -> void:
	if players.has(sound):
		players[sound].play()

func _add(sound: String, stream: AudioStreamWAV) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.max_polyphony = 4  # deixa o msm som tocar varias vezes junto
	p.volume_db = -6.0
	add_child(p)
	players[sound] = p

# monta um som curtinho: uma onda q vai de f0 ate f1, com chiado, e o volume vai abaixando
# parece complicado mas é so matematica
func _make_sound(duration: float, f0: float, f1: float, noise: float, volume: float) -> AudioStreamWAV:
	var n := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var rumble := 0.0
	for i in n:
		var k := float(i) / n
		phase += lerpf(f0, f1, k) / RATE
		var wave := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0  # onda quadrada = som de videogame antigo
		rumble = lerpf(rumble, randf_range(-1.0, 1.0), 0.25)  # chiado abafado (pra explosao)
		var envelope := pow(1.0 - k, 2.0)  # volume caindo ate zero
		var s := (wave * (1.0 - noise) + rumble * noise * 2.5) * envelope * volume
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767))  # vira numero de 16 bits
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
