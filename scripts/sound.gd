extends Node

var tracks: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var active = 0
var current = ""
var music_volume = .7
var effects_volume = .65
var duck = false
var muted = false
var fade: Tween
var loop_from = 0.0
var loop_to = 0.0
var sfx: AudioStreamPlayer
var effects: Dictionary = {}
var title = ""

func _ready() -> void:
	for track in ["dedadao", "douglas_e_eu", "douglas_e_ele", "condominio_life", "tiro_de_nine"]:
		tracks[track] = load("res://audio/" + track + ".ogg")
	for i in range(2):
		var p = AudioStreamPlayer.new()
		add_child(p)
		p.volume_db = -60
		players.append(p)
	sfx = AudioStreamPlayer.new()
	sfx.max_polyphony = 6
	add_child(sfx)
	for id in ["step", "select", "hit", "door", "portal", "danger", "jump"]:
		effects[id] = make_effect(id)

func play(track: String, begin: float = 0, end: float = 0, force: bool = false) -> void:
	if not force and current == track and absf(loop_from - begin) < .1 and absf(loop_to - end) < .1:
		return
	current = track
	title = {"dedadao": "Dedadão · BONDA 2", "douglas_e_eu": "Douglas & Eu · BONDA GOOD 4SS JOB", "douglas_e_ele": "Douglas & Ele · BONDA GOOD 4SS JOB", "condominio_life": "Condomínio Life · BONDA 2", "tiro_de_nine": "Não Erro Tiro de Nine · BONDA 2"}.get(track, "")
	if fade and fade.is_valid():
		fade.kill()
	var old = active
	active = 1 - active
	players[active].stream = tracks[track]
	players[active].volume_db = -55
	players[active].play(begin)
	loop_from = begin
	loop_to = end if end > begin else tracks[track].get_length() - .2
	fade = create_tween().set_parallel(true)
	fade.tween_property(players[old], "volume_db", -60.0, .8)
	fade.tween_property(players[active], "volume_db", target_db(), .8)
	fade.chain().tween_callback(players[old].stop)

func target_db() -> float:
	return -65.0 if muted else linear_to_db(maxf(.001, music_volume)) - (9.0 if duck else 0.0)

func _process(dt: float) -> void:
	if players.is_empty():
		return
	if not fade or not fade.is_running():
		players[active].volume_db = move_toward(players[active].volume_db, target_db(), dt * 22)
	if current != "" and (not players[active].playing or players[active].get_playback_position() >= loop_to - .8):
		play(current, loop_from, loop_to, true)
	sfx.volume_db = -65 if muted else linear_to_db(maxf(.001, effects_volume))

func effect(id: String) -> void:
	if effects.has(id):
		sfx.stream = effects[id]
		sfx.pitch_scale = randf_range(.94, 1.06)
		sfx.play()

func make_effect(id: String) -> AudioStreamWAV:
	var duration = .15
	var freq = 400.0
	var noise = .0
	match id:
		"step": duration = .07; freq = 80; noise = .65
		"hit": duration = .17; freq = 90; noise = .7
		"door": duration = .25; freq = 100; noise = .4
		"danger": duration = .30; freq = 230
		"portal": duration = .65; freq = 620; noise = .08
		"jump": duration = .15; freq = 280
	var data = PackedByteArray()
	var rng = RandomNumberGenerator.new()
	rng.seed = 727
	for i in range(int(22050 * duration)):
		var t = float(i) / 22050.0
		var amp = pow(1.0 - t / duration, 2)
		var sample = (sin(TAU * freq * t * (1 + t)) * (1 - noise) + rng.randf_range(-1, 1) * noise) * amp * .22
		var value = int(sample * 32767)
		data.append(value & 255)
		data.append((value >> 8) & 255)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	return stream
