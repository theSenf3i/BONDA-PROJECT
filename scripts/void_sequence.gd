extends Node

var g: Node
var running = true
var phase = "arrival"
var elapsed = 0.0
var line_time = 0.0
var line_index = -1
var return_from: Transform3D
var return_fov = 48.0
var lines = [
	["JÚNIOR", "Michael? Cadê o Robson? Que lugar é esse?"],
	["MICHAEL", "Júnior, sua viagem deixou as dimensões viradas do avesso."],
	["JÚNIOR", "Eu atravessei tudo aquilo pra trazer ele de volta. E agora?"],
	["MICHAEL", "Os deuses do espaço estão furiosos com a bagunça. Eles não vão deixar vocês em paz desse jeito."],
	["JÚNIOR", "Tá. Me mostra como resolver."],
	["MICHAEL", "Minha força quase acabou. Ainda consigo abrir esta passagem."],
	["MICHAEL", "Entre nos portais, repare o que ficou para trás e feche as portas abertas."],
	["JÚNIOR", "E só assim eu consigo voltar pro Robson?"],
	["MICHAEL", "É o caminho que resta. Comece pela porta no alto da escada."]
]

func begin(game: Node) -> void:
	g = game
	g.state = "cutscene"
	g.player.enabled = false
	g.player.velocity = Vector3.ZERO
	g.player.camera_fixed = true
	g.player.face(g.world.michael.position)
	g.world.michael_lift = 3.4
	g.cinema.current = true
	g.cinema.fov = 48.0
	g.cinema.far = 450.0
	g.void_goal.visible = false
	g.void_controls.visible = false
	g.void_caption.text = ""
	g.void_speaker.text = ""
	g.void_caption_time = 3600.0
	g.void_prompt.text = ""
	position_camera(0.0)

func _process(dt: float) -> void:
	if not running or not is_instance_valid(g) or g.stage != "void":
		return
	elapsed += dt
	if phase == "arrival":
		var t = smoothstep(0.0, 4.0, elapsed)
		g.world.michael_lift = lerpf(3.4, 0.0, t)
		g.player.position.z = lerpf(12.0, 8.4, t)
		g.player.manual_walk_speed = 0.9 if t < 0.98 else 0.0
		g.player.face(g.world.michael.position)
		position_camera(t)
		if elapsed >= 4.0:
			phase = "conversation"
			g.player.manual_walk_speed = 0.0
			show_line(0)
	elif phase == "conversation":
		line_time += dt
		position_camera(1.0)
		if line_time >= maxf(3.0, float(lines[line_index][1].length()) / 19.0 + 1.0):
			advance()
	elif phase == "release":
		line_time += dt
		var t = smoothstep(0.0, 1.3, line_time)
		g.cinema.global_transform = return_from.interpolate_with(g.player.camera.global_transform, t)
		g.cinema.fov = lerpf(return_fov, g.player.camera.fov, t)
		if line_time >= 1.3:
			finish()

func position_camera(arrival: float) -> void:
	var focus = Vector3(1.2, 0.9, 7.0)
	var high = Vector3(4.0, 22.0, 14.0)
	var near = Vector3(7.5, 9.5, 14.0)
	var shift = Vector3(sin(elapsed * 0.23) * 0.65, sin(elapsed * 0.17) * 0.3, cos(elapsed * 0.19) * 0.4)
	g.cinema.position = high.lerp(near, arrival) + shift
	if phase == "conversation" and line_index >= 5:
		g.cinema.position += Vector3(-1.0, 2.5, -1.5)
	g.cinema.look_at(focus)
	g.cinema.rotate_object_local(Vector3.FORWARD, -0.065 + sin(elapsed * 0.37) * 0.02)

func show_line(index: int) -> void:
	line_index = index
	line_time = 0.0
	g.void_speaker.text = lines[index][0]
	g.void_caption.text = lines[index][1]
	g.void_caption_time = 3600.0
	g.void_prompt.text = "[ E ]  Próxima fala"
	g.world.michael_talking = lines[index][0] == "MICHAEL"

func advance() -> void:
	if not running or phase != "conversation" or line_time < 0.6:
		return
	if line_index + 1 < lines.size():
		show_line(line_index + 1)
	else:
		phase = "release"
		line_time = 0.0
		g.world.michael_talking = false
		g.void_prompt.text = ""
		return_from = g.cinema.global_transform
		return_fov = g.cinema.fov

func finish() -> void:
	running = false
	g.world.michael_talking = false
	g.world.michael_lift = 0.0
	g.player.manual_walk_speed = 0.0
	g.player.camera_fixed = false
	g.void_goal.visible = true
	g.void_controls.visible = true
	g.void_speaker.text = ""
	g.void_caption.text = "A porta no alto. Um mundo de cada vez."
	g.void_caption_time = 4.5
	g.void_prompt.text = ""
	g.void_intro_seen = true
	g.save_checkpoint("void")
	g.set_play()
