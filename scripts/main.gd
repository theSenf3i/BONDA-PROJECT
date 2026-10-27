extends Node3D

var home_cleaned: Array = []
var home_achievement = false
var home_arrival_seen = false
const HOME_REMARK_SECONDS = 2.0

var visits: Node
var world: Node3D
var player: CharacterBody3D
var ui: CanvasLayer
var sound: Node
var cinema: Camera3D
var state = "menu"
var stage = "menu"
var checkpoint = "void"
var paused = false
var dialogue: Array = []
var dialogue_index = 0
var dialogue_done: Callable
var choice_callback: Callable
var clock = 0.0
var taxi_risk = 0
var taxi_question = 0
var affection = 0
var invite_question = 0
var player_hp = 100.0
var enemy_hp = 100.0
var enemy: Node3D
var attack_cooldown = 0.0
var enemy_cooldown = 1.4
var enemy_windup = 0.0
var enemy_state = "approach"
var hit_invulnerability = 0.0
var enemy_target = Vector3.ZERO
var telegraph: MeshInstance3D
var sparks: Array = []
var bullets: Array = []
var dodge_time = 30.0
var dodge_lives = 3
var fire_clock = 1.4
var wave_number = 0
var marker: Label3D
var npc_last: Dictionary = {}
var memories: Array = []
var memories_found = 0
var transition_serial = 0
var test_mode = false
var last_failure = ""
var dead = false

var street_fog: MeshInstance3D
var street_labels: CanvasLayer
var street_filter: ColorRect
var void_environment: WorldEnvironment
var default_environment: Environment
var void_sun: DirectionalLight3D
var void_filter: ColorRect
var void_hud: CanvasLayer
var void_heading: Label
var void_clock_label: Label
var void_caption: Label
var void_prompt: Label
var void_filter_label: Label
var void_elapsed = 0.0
var void_rest_index = 0
var void_cue_index = 0
var void_caption_time = 0.0
var void_respawns = 0
var void_reduced = false
var void_sequence: Node
var void_goal: Label
var void_controls: Label
var void_speaker: Label
var void_michael_cooldown = 0.0
var void_intro_seen = false

func _ready() -> void:
	test_mode = "--qa" in OS.get_cmdline_user_args() or "--qa-void" in OS.get_cmdline_user_args() or "--capture-void" in OS.get_cmdline_user_args()
	test_mode = test_mode or "--qa-home" in OS.get_cmdline_user_args() or "--qa-street" in OS.get_cmdline_user_args()
	test_mode = test_mode or "--qa-fixes" in OS.get_cmdline_user_args()
	load_home_profile()
	inputs()
	visits = load("res://scripts/visits.gd").new()
	visits.g = self
	add_child(visits)
	var helper = load("res://scripts/world.gd").new()
	helper.environment(self)
	helper.free()
	sound = load("res://scripts/sound.gd").new()
	add_child(sound)
	ui = load("res://scripts/interface.gd").new()
	add_child(ui)
	ui.process_mode = Node.PROCESS_MODE_ALWAYS
	ui.home_achievement = home_achievement
	ui.start_game.connect(new_game)
	ui.continue_game.connect(continue_saved)
	ui.advance.connect(next_line)
	ui.selected.connect(select_choice)
	ui.retry.connect(retry_checkpoint)
	ui.resume_game.connect(func(): pause_game(false))
	ui.quit_to_menu.connect(to_menu)
	ui.music_changed.connect(func(v): sound.music_volume = v)
	ui.effects_changed.connect(func(v): sound.effects_volume = v)
	ui.mute_requested.connect(func(): sound.muted = not sound.muted)
	ui.fullscreen_requested.connect(toggle_fullscreen)
	cinema = Camera3D.new()
	add_child(cinema)
	cinema.fov = 54
	setup_void_presentation()
	setup_street_presentation()
	street_labels = load("res://scripts/street_labels.gd").new()
	street_labels.game = self
	add_child(street_labels)
	ui.layer = 2
	to_menu()
	if "--qa-fixes" in OS.get_cmdline_user_args():
		call_deferred("run_fix_checks")
	if "--qa-street" in OS.get_cmdline_user_args():
		call_deferred("run_street_checks")
	if "--qa-home" in OS.get_cmdline_user_args():
		call_deferred("run_home_checks")
	if "--home" in OS.get_cmdline_user_args():
		ui.show_menu(false)
		new_game()
	if "--void" in OS.get_cmdline_user_args():
		start_void()
	if "--qa-void" in OS.get_cmdline_user_args() or "--capture-void" in OS.get_cmdline_user_args():
		call_deferred("run_void_checks")
	if "--qa" in OS.get_cmdline_user_args():
		call_deferred("run_qa")
	if "--capture" in OS.get_cmdline_user_args():
		call_deferred("capture_showcase")
	if "--capture-v2" in OS.get_cmdline_user_args():
		test_mode = true
		call_deferred("capture_revision")

func inputs() -> void:
	var map = {
		"forward": [KEY_W], "back": [KEY_S], "left": [KEY_A], "right": [KEY_D],
		"jump": [KEY_SPACE], "interact": [KEY_E], "sprint": [KEY_SHIFT],
		"dash": [KEY_Q], "attack": [KEY_J], "block": [KEY_K],
		"cam_left": [KEY_LEFT], "cam_right": [KEY_RIGHT]
	}
	for action in map:
		InputMap.add_action(action)
		for key in map[action]:
			var event = InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	var mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mouse)
	var block_mouse = InputEventMouseButton.new()
	block_mouse.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("block", block_mouse)

func rebuild(kind: String, spawn: Vector3, view_angle: float = 0.0) -> void:
	transition_serial += 1
	bullets.clear()
	sparks.clear()
	memories.clear()
	marker = null
	enemy = null
	telegraph = null
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = load("res://scripts/void_world.gd" if kind == "void" else "res://scripts/world.gd").new()
	add_child(world)
	if kind != "void":
		world.extended_street = kind == "neighborhood" and stage in ["neighborhood", "taxi"]
	world.build(kind)
	if kind == "home":
		world.home.restore(home_cleaned)
	apply_void_presentation(kind == "void")
	apply_street_presentation(kind == "neighborhood" and world.extended_street)
	player = load("res://scripts/player.gd").new()
	world.add_child(player)
	player.position = spawn
	world.pedestrian = player
	world.previous_pedestrian = spawn
	world.car_hit.connect(traffic_death)
	player.orbit = view_angle
	player.step.connect(func(): sound.effect("step"))
	player.enabled = false
	player.velocity = Vector3.ZERO
	hit_invulnerability = 0
	attack_cooldown = 0
	dead = false
	ui.combat(false)
	ui.survival.hide()
	ui.prompt.text = ""
	ui.danger.text = ""
	ui.toast_time = 0
	if kind in ["home", "clinic"]:
		player.bounds = Vector2(5.5, 5)
		player.distance = 3.6
	if kind == "neighborhood" and world.extended_street:
		player.bounds = Vector2(52, 25)
		player.camera.far = 260
		void_environment.environment.fog_enabled = true
		void_environment.environment.fog_density = 0.026
	if kind == "restaurant":
		player.bounds = Vector2(13, 9)
	if kind == "parking":
		player.bounds = Vector2(8.3, 11.5)

func set_play() -> void:
	state = "play"
	player.enabled = true
	player.camera.current = true
	sound.duck = false
	if not test_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func set_objective(chapter: String, text: String) -> void:
	ui.chapter.text = chapter
	ui.objective.text = text

func target(pos: Vector3, text: String) -> void:
	if is_instance_valid(marker):
		marker.queue_free()
	marker = world.text3(world, text, pos, 27, Color("ffe2a0"))
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = false

func save_checkpoint(value: String) -> void:
	checkpoint = value
	if test_mode:
		return
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://save")):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://save"))
	var file = FileAccess.open("res://save/checkpoint.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"stage": value, "memories": memories_found, "version": 6, "home_arrival_seen": home_arrival_seen, "home_cleaned": home_cleaned, "void_intro_seen": void_intro_seen, "papers": visits.collected, "coffee": visits.coffee_level}))

func to_menu() -> void:
	pause_game(false)
	ui.close_dialog()
	ui.result_panel.hide()
	state = "menu"
	stage = "menu"
	rebuild("neighborhood", Vector3(-22, .3, 6), PI)
	player.hide()
	cinema.current = true
	cinema.position = Vector3(-14, 3.5, 5.5)
	cinema.look_at(Vector3(7, 1.6, -7))
	ui.show_menu(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	sound.duck = false
	sound.play("dedadao", 0, 17)

func new_game() -> void:
	home_cleaned.clear()
	home_arrival_seen = false
	memories_found = 0
	void_intro_seen = false
	visits.collected.clear()
	ui.show_menu(false)
	ui.result_panel.hide()
	start_void()

func continue_saved() -> void:
	var file = FileAccess.open("res://save/checkpoint.json", FileAccess.READ)
	if not file:
		new_game()
		return
	if file:
		var data = JSON.parse_string(file.get_as_text())
		if not data is Dictionary:
			new_game()
			return
		if data is Dictionary:
			home_cleaned = data.get("home_cleaned", [])
			checkpoint = data.get("stage", "void")
			home_arrival_seen = bool(data.get("home_arrival_seen", false))
			void_intro_seen = bool(data.get("void_intro_seen", false))
			visits.collected = data.get("papers", [])
			visits.coffee_level = float(data.get("coffee", 100.0))
			memories_found = int(data.get("memories", 0))
	ui.show_menu(false)
	retry_checkpoint()

func start_home() -> void:
	stage = "home"
	rebuild("home", Vector3(0, .1, .7), 0)
	save_checkpoint("home")
	set_objective("01 / 04   •   UMA CONSULTA NORMAL", "Saia de casa e encontre o ponto de táxi.")
	sound.play("dedadao", 0, 17)
	target(Vector3(0, 2.6, 4.8), "SAIR DE CASA  ↓")
	if home_arrival_seen:
		set_play()
		return
	say([
		["Júnior", "Cadê a escada? Cadê o Michael? Eu passei pela porta e vim parar... aqui?"],
		["Júnior", "Os deuses do espaço estão putos com a bagunça das dimensões. Se virem essa pia, vão achar que fui eu também."],
		["Júnior", "Calma. O Michael mandou entrar nos portais e consertar o que ficou pra trás. Isso aqui deve ser o primeiro mundo."],
		["Júnior", "Robson, eu ainda tô indo atrás de você. Só não esperava passar por um colchão nesse estado."],
		["Júnior", "O quadro diz: Consulta hoje as 16:00. Atravessei o espaço e o tempo pra cair no dia de ir ao médico. Puta que pariu."],
		["Júnior", "Tá. Primeiro essa consulta. Deve ter um táxi lá fora. Um mundo de cada vez, até achar o caminho de volta."]
	], finish_home_arrival)

func finish_home_arrival() -> void:
	home_arrival_seen = true
	save_checkpoint("home")
	set_play()

func start_neighborhood() -> void:
	stage = "neighborhood"
	rebuild("neighborhood", Vector3(-22, .22, 7.6), 0)
	save_checkpoint("neighborhood")
	set_objective("01 / 04   •   O BAIRRO", "Encontre o táxi amarelo. Explore se quiser.")
	target(Vector3(-8, 3, 2.6), "TÁXI  ↓")
	sound.play("condominio_life", 0, 41)
	for pos in [Vector3(-17, .6, -6), Vector3(8, .6, 6), Vector3(31, .6, -6)]:
		var item = world.box(world, pos, Vector3(.45, .3, .12), Color("bda1d1"))
		memories.append(item)
	visits.setup_papers()
	set_play()
	ui.notify("E para conversar • Q para uma esquiva rápida")

func start_taxi() -> void:
	stage = "taxi"
	save_checkpoint("taxi")
	if world.scene_kind != "neighborhood":
		rebuild("neighborhood", Vector3(-8, .2, 4.8))
	taxi_risk = 0
	taxi_question = 0
	ui.toast_time = 0
	ui.prompt.text = ""
	if is_instance_valid(marker):
		marker.hide()
	player.hide()
	player.enabled = false
	world.taxi.position = Vector3(-8, 0, 3.35)
	world.moving_taxi = true
	world.taxi_progress = 0
	cinema.current = true
	set_objective("01 / 04   •   CONVERSA DE TAXISTA", "Chegue à clínica sem se expor demais.")
	sound.effect("door")
	sound.play("condominio_life", 0, 41)
	say([
		["Motorista", "Clínica do Douglas, né? Pode entrar. Mas esse GPS aí… ultimamente ele inventa cada caminho."],
		["Viajante", "O endereço tá certo. Pode seguir o trajeto principal."],
		["Motorista", "Claro, claro. Só gosto de conhecer melhor quem entra no meu carro."]
	], taxi_ask)

func taxi_ask() -> void:
	var questions = [
		["Vai ter alguém te esperando quando voltar?", ["Prefiro falar só do trajeto.", "Um amigo sabe onde eu estou.", "Ninguém. Moro sozinho."]],
		["E você mora em qual casa? A de portão azul?", ["Pode seguir o endereço da clínica.", "Aqui perto, mas não preciso dizer onde.", "A número 3. Deixo a chave no vaso."]],
		["Tem um atalho bem vazio. Ninguém passa por lá. Bora?", ["Não. Siga pela avenida, por favor.", "Vou conferir o trajeto no celular.", "Pode ir. Meu celular tá sem bateria."]]
	]
	if taxi_question >= questions.size():
		taxi_arrive()
		return
	var q = questions[taxi_question]
	ask("Motorista", q[0], q[1], taxi_answer)
	ui.danger.text = "DESCONFIANÇA   " + "●".repeat(taxi_risk) + "○".repeat(maxi(0, 3 - taxi_risk))

func taxi_answer(index: int) -> void:
	taxi_risk += 2 if index == 2 else 0
	taxi_question += 1
	if taxi_risk >= 3:
		world.taxi.rotation.y = -.45
		sound.play("tiro_de_nine", 0, 20)
		say([["Motorista", "Sozinho, sem bateria… então a gente vai mudar o destino."], ["Viajante", "Ei. A clínica não é por aí. PARA ESSA PORRA!"]], func(): fail("O motorista mudou o trajeto. Você revelou informações demais.\nPista: mantenha o destino e proteja seus dados pessoais."))
	else:
		if index == 2:
			sound.play("tiro_de_nine", 0, 20)
			say([["Motorista", "Ah, ninguém vai estranhar se você demorar… bom saber."], ["Viajante", "Ele tá olhando mais pro retrovisor do que pra rua. Melhor fechar a boca."]], taxi_ask)
		else:
			say([["Motorista", "Tá certo. Vamos pela avenida, então."]], taxi_ask)

func taxi_arrive() -> void:
	say([["Motorista", "Chegamos. A clínica fica do outro lado da rua."], ["Viajante", "Valeu. Essa conversa já foi mais invasiva que a consulta."]], arrive_clinic_street)

func arrive_clinic_street() -> void:
	stage = "clinic_street"
	rebuild("clinic_street", Vector3(20, .2, 5.5), 0)
	world.taxi.position.x = 20
	world.moving_taxi = false
	save_checkpoint("clinic_street")
	set_objective("01 / 04   •   CHEGOU A HORA", "Atravesse a rua e entre na Clínica Douglas.")
	target(Vector3(22, 3, -8), "CONSULTÓRIO  ↓")
	sound.play("dedadao", 0, 17)
	set_play()

func start_clinic() -> void:
	stage = "clinic"
	rebuild("clinic", Vector3(0, .1, 2.4), 0)
	save_checkpoint("clinic")
	set_objective("02 / 04   •   DOUTOR DOUGLAS", "Converse com Douglas.")
	target(Vector3(.2, 2.6, -1.7), "DOUGLAS  ↓")
	sound.play("dedadao", 0, 38)
	set_play()

func clinic_conversation() -> void:
	if is_instance_valid(marker):
		marker.hide()
	player.face(Vector3(.2, 0, -1.7))
	world.actors[0].pose = "talk"
	cinema.current = true
	cinema.position = Vector3(4.7, 2.4, 2.6)
	cinema.look_at(Vector3(.3, 1.1, -.4))
	say([
		["Douglas", "Charles? Pode entrar. Você tá segurando essa ficha como se ela fosse um escudo."],
		["Viajante", "É a primeira vez. Eu gosto de saber onde ficam as saídas."],
		["Douglas", "Relaxa. Vou explicar tudo antes. Se precisar parar, é só falar."],
		["Viajante", "Tá. Se eu desmaiar, considera uma crítica construtiva."],
		["Douglas", "Deita na maca. Respira. A gente não tá com pressa."]
	], exam)

func exam() -> void:
	state = "cutscene"
	player.enabled = false
	player.position = Vector3(2.5, 1.15, -.75)
	player.actor.rotation = Vector3(PI / 2, 0, 0)
	cinema.current = true
	cinema.position = Vector3(4, 3.3, 3)
	cinema.look_at(Vector3(1.7, 1.2, -1.5))
	sound.play("dedadao", 18, 57)
	say([["Viajante", "…"], ["Viajante", "Caralho. Eu ensaiei o pânico a manhã inteira e agora não sei o que fazer com ele."]], visits_montage)

func visits_montage() -> void:
	state = "cutscene"
	ui.close_dialog()
	player.enabled = false
	player.actor.rotation = Vector3.ZERO
	var serial = transition_serial
	await ui.transition("EM CASA, MAIS TARDE…", .8)
	if serial != transition_serial:
		return
	rebuild("home", Vector3(0, .1, .6), 0)
	stage = "clinic"
	set_objective("02 / 04   •   DE VOLTA A CASA", "Alguma coisa ficou diferente.")
	say([["Viajante", "Era pra eu ficar aliviado por ter acabado. Por que eu tô pensando em voltar?"]], week_later)

func week_later() -> void:
	state = "cutscene"
	ui.close_dialog()
	var serial = transition_serial
	await ui.transition("UMA SEMANA DEPOIS…", 1.0)
	if serial != transition_serial:
		return
	visits.start_coffee()

func more_visits() -> void:
	visits.start_stroll()

func start_invite(rebuild_room: bool = true) -> void:
	stage = "invite"
	if rebuild_room:
		rebuild("clinic", Vector3(0, .1, 1.8))
	player.camera.current = true
	player.actor.rotation = Vector3.ZERO
	save_checkpoint("invite")
	affection = 0
	invite_question = 0
	set_objective("02 / 04   •   FORA DO HORÁRIO", "Convide Douglas para sair. Seja sincero.")
	sound.play("douglas_e_eu", 0, 39)
	say([["Douglas", "Hoje você veio sem ficha, Charles. Mas parece que ainda quer perguntar alguma coisa."], ["Viajante", "Dessa vez não tem nada a ver com a consulta."]], invite_ask)

func invite_ask() -> void:
	var questions = [
		["Então… o que você queria me dizer?", ["Queria te conhecer fora daqui.", "Você me deve um encontro.", "Quanto custa jantar com você?"]],
		["Fora daqui eu não sou seu médico. Você entende isso?", ["Sim. Sem ficha e sem consulta.", "Mas dá pra continuar sendo meu doutor?", "Eu decido isso depois."]],
		["E se eu não quiser?", ["Tudo bem. O convite não é obrigação.", "Aí você vai me deixar muito puto.", "Vou insistir até você aceitar."]]
	]
	if invite_question >= questions.size():
		if affection >= 2:
			say([["Douglas", "Assim eu aceito. Tem um bistrô aqui perto. Depois do expediente?"], ["Viajante", "Fechado. Prometo não levar a ficha."]], start_restaurant)
		else:
			say([["Douglas", "Não. Você não tá me ouvindo. Melhor a gente ficar só na consulta."]], func(): fail("Douglas recusou o convite.\nOuça o que ele diz e respeite os limites dele. Você pode tentar esta conversa de novo."))
		return
	var q = questions[invite_question]
	ask("Douglas", q[0], q[1], invite_answer)

func invite_answer(index: int) -> void:
	if index == 0:
		affection += 1
	invite_question += 1
	say([["Douglas", "É bom ouvir isso." if index == 0 else "Calma. Não é bem por aí."]], invite_ask)

func start_restaurant() -> void:
	stage = "restaurant"
	rebuild("restaurant", Vector3(-1, .1, -1), 0)
	save_checkpoint("fight")
	set_objective("03 / 04   •   SÓ NÓS DOIS", "Aproveite o encontro. O que poderia acontecer?")
	sound.play("douglas_e_eu", 40, 93)
	enemy = world.actor("rival", Vector3(3.5, 0, -2), PI / 3)
	world.actors[0].pose = "talk"
	say([
		["Douglas", "Viu? Um encontro sem cheiro de álcool hospitalar."],
		["Viajante", "Já tá no meu top três experiências fora de um consultório."],
		["Outro paciente", "Doutor Douglas! Que coincidência. Posso roubar sua atenção um minutinho?"],
		["Viajante", "Pega uma senha, porra. Hoje ele tá comigo."],
		["Outro paciente", "Nossa. A consulta agora dá direito a exclusividade?"],
		["Douglas", "Vocês dois vão mesmo transformar um jantar nisso?"],
		["Como jogar", "WASD: mover. J ou clique: soco. K ou botão direito: defender. Q: esquivar. Espere o rival anunciar o golpe e aproveite a abertura."]
	], func(): start_fight(false))

func start_fight(rebuild_arena: bool = true) -> void:
	stage = "fight"
	if rebuild_arena:
		rebuild("restaurant", Vector3(0, .1, 4), 0)
		enemy = world.actor("rival", Vector3(0, 0, -.3), PI)
	else:
		player.position = Vector3(0, .1, 4)
		enemy.position = Vector3(0, 0, -.3)
	player_hp = 100
	enemy_hp = 100
	enemy_cooldown = 1.4
	enemy_windup = 0
	enemy_state = "approach"
	attack_cooldown = 0
	hit_invulnerability = 0
	save_checkpoint("fight")
	set_objective("03 / 04   •   CIÚME NÃO PAGA A CONTA", "Vença a disputa. Defenda e contra-ataque.")
	sound.play("tiro_de_nine", 18, 62)
	ui.combat(true)
	ui.player_bar.value = player_hp
	ui.enemy_bar.value = enemy_hp
	player.bounds = Vector2(4.8, 8.5)
	telegraph = world.cylinder(world, Vector3(0, .03, 0), 1.5, .025, Color("e69970"))
	telegraph.hide()
	set_play()
	ui.notify("Golpe laranja: saia de perto ou segure K")

func fight_tick(dt: float) -> void:
	if not is_instance_valid(enemy):
		return
	attack_cooldown = maxf(0, attack_cooldown - dt)
	enemy_cooldown -= dt
	var d: Vector3 = player.position - enemy.position
	d.y = 0
	enemy.rotation.y = lerp_angle(enemy.rotation.y, atan2(-d.x, -d.z), dt * 7)
	if enemy_state == "approach":
		if d.length() > 1.85:
			enemy.position += d.normalized() * 2.0 * dt
			enemy.walk_speed = 2
		else:
			enemy.walk_speed = 0
			if enemy_cooldown <= 0:
				enemy_state = "windup"
				enemy_windup = .82
				enemy_target = player.position
				telegraph.position = Vector3(enemy_target.x, .04, enemy_target.z)
				telegraph.show()
				ui.danger.text = "ELE VAI BATER!  •  K DEFENDE / Q ESQUIVA"
				sound.effect("danger")
	elif enemy_state == "windup":
		enemy_windup -= dt
		enemy.pose = "block"
		if enemy_windup <= 0:
			enemy.punch = 1
			enemy.pose = "idle"
			telegraph.hide()
			if Vector2(player.position.x - enemy_target.x, player.position.z - enemy_target.z).length() < 1.7 and d.length() < 3.1 and player.position.y < 1.0:
				hurt_player(5 if player.block else 19)
			enemy_state = "recover"
			enemy_cooldown = 1.1
			ui.danger.text = "ABERTURA!  •  APROXIME E ATAQUE"
	elif enemy_state == "recover":
		if enemy_cooldown <= 0:
			enemy_state = "approach"
			enemy_cooldown = .6
			ui.danger.text = ""
	enemy.position.x = clampf(enemy.position.x, -4.6, 4.6)
	enemy.position.z = clampf(enemy.position.z, -2.4, 8.0)
	if Input.is_action_just_pressed("attack"):
		attack()
	ui.player_bar.value = player_hp
	ui.enemy_bar.value = enemy_hp

func attack() -> void:
	if stage != "fight" or state != "play" or attack_cooldown > 0:
		return
	attack_cooldown = .42
	player.actor.punch = 1
	player.face(enemy.position)
	sound.effect("select")
	if player.position.distance_to(enemy.position) < 2.3:
		var amount = 18 if enemy_state == "recover" else 10
		enemy_hp = maxf(0, enemy_hp - amount)
		enemy.hit = 1
		burst(enemy.position + Vector3(0, 1.2, 0), Color("f8ce89"))
		sound.effect("hit")
		if enemy_hp <= 0:
			fight_won()

func hurt_player(amount: float) -> void:
	if hit_invulnerability > 0 or player.dash_time > 0 or state != "play":
		return
	hit_invulnerability = 1.15
	player.actor.hit = 1
	burst(player.position + Vector3(0, 1.1, 0), Color("df867f"))
	sound.effect("hit")
	if stage == "fight":
		player_hp = maxf(0, player_hp - amount)
		if player_hp <= 0:
			fail("O ciúme bateu primeiro. O rival bateu depois.\nSegure K para defender e ataque durante a abertura laranja.")
	elif stage == "dodge":
		dodge_lives -= 1
		if dodge_lives <= 0:
			fail("Você foi atingido três vezes.\nMude de direção, use o espaço para pular e Q para escapar de um aperto.")

func fight_won() -> void:
	state = "cutscene"
	player.enabled = false
	enemy.walk_speed = 0
	enemy.rotation.z = -1.2
	telegraph.hide()
	ui.combat(false)
	sound.play("douglas_e_eu", 93, 133)
	say([["Outro paciente", "Tá, chega! Eu só queria perguntar do estacionamento!"], ["Douglas", "Você é um desastre, Charles."], ["Viajante", "Um desastre com reserva pra dois."], ["Douglas", "Vem. Antes que você arrume briga com a sobremesa."]], holding_hands)

func holding_hands() -> void:
	state = "cutscene"
	player.enabled = false
	var douglas = world.actors[0]
	player.position = Vector3(-.43, 0, 2)
	douglas.position = Vector3(.43, 0, 2)
	player.actor.rotation.y = PI
	douglas.rotation.y = PI
	douglas.pose = "hug"
	player.actor.pose = "hug"
	player.manual_walk_speed = 1.3
	douglas.walk_speed = 1.3
	cinema.current = true
	cinema.position = Vector3(5, 2.6, 8)
	cinema.look_at(Vector3(0, 1, 3))
	var t = create_tween().set_parallel(true)
	t.tween_property(player, "position:z", 5.0, 2.5)
	t.tween_property(douglas, "position:z", 5.0, 2.5)
	await t.finished
	if stage == "fight" and state == "cutscene":
		start_parking()

func start_parking() -> void:
	stage = "parking"
	rebuild("parking", Vector3(0, .1, 6), 0)
	save_checkpoint("dodge")
	set_objective("04 / 04   •   A GENTE PRECISA CONVERSAR", "Encare as consequências.")
	sound.play("douglas_e_ele", 0, 37)
	say([
		["Namorada", "De mãos dadas. Que bonito. E eu achando que você tava fazendo um tratamento."],
		["Viajante", "Eu posso explicar…"],
		["Namorada", "Não precisa. Eu li as mensagens. Todas. Você devia ter conversado comigo antes."],
		["Douglas", "Charles… você não me contou essa parte."],
		["Namorada", "Acabou. E leva essas suas coisas junto!"],
		["Como jogar", "Sobreviva por 30 segundos. Você tem 3 vidas. WASD move em todas as direções; ESPAÇO pula; Q esquiva. O ritmo aumenta aos poucos."]
	], func(): start_dodge(false))

func start_dodge(rebuild_arena: bool = true) -> void:
	stage = "dodge"
	if rebuild_arena:
		rebuild("parking", Vector3(0, .1, 6), 0)
	dodge_time = 30
	dodge_lives = 3
	fire_clock = 1.4
	wave_number = 0
	hit_invulnerability = 0
	for entry in bullets:
		if is_instance_valid(entry.node):
			entry.node.queue_free()
	bullets.clear()
	player.position = Vector3(0, .1, 6)
	player.velocity = Vector3.ZERO
	player.bounds = Vector2(8.0, 10)
	player.distance = 7.0
	player.pitch = -.42
	save_checkpoint("dodge")
	set_objective("04 / 04   •   DESVIA DESSA", "Sobreviva por 30 segundos. Você tem espaço.")
	sound.play("douglas_e_ele", 37, 89)
	ui.survival.show()
	set_play()

func dodge_tick(dt: float) -> void:
	dodge_time = maxf(0, dodge_time - dt)
	if dodge_time <= 0:
		dodge_won()
		return
	var intensity = mini(3, int((30 - dodge_time) / 7.5))
	ui.survival.text = "%02d s   •   %s" % [int(ceil(dodge_time)), "♥".repeat(dodge_lives) + "♡".repeat(3 - dodge_lives)]
	ui.danger.text = ["RESPIRA. TEM ESPAÇO.", "ELA PEGOU OUTRA SACOLA.", "MUDE DE DIREÇÃO.", "ÚLTIMOS SEGUNDOS!"][intensity]
	fire_clock -= dt
	if fire_clock <= 0:
		fire_clock = [1.10, .94, .80, .68][intensity]
		spawn_wave(intensity)
	for i in range(bullets.size() - 1, -1, -1):
		var b = bullets[i]
		b.node.position += b.velocity * dt
		b.node.rotation += Vector3(2.1, 1.4, .6) * dt
		b.life -= dt
		var center = player.position + Vector3(0, .85, 0)
		if b.node.position.distance_to(center) < .63 and hit_invulnerability <= 0:
			hurt_player(1)
			b.life = 0
		if b.life <= 0 or absf(b.node.position.x) > 14 or absf(b.node.position.z) > 15:
			b.node.queue_free()
			bullets.remove_at(i)

func spawn_wave(intensity: int) -> void:
	wave_number += 1
	var origin = Vector3(0, 1.1, -9)
	var lead = Vector3(player.velocity.x, 0, player.velocity.z) * (.18 if intensity >= 2 else 0.0)
	var destination = player.position + Vector3(0, .8, 0) + lead
	var forward = (destination - origin).normalized()
	var count = 3 if intensity >= 1 and wave_number % 3 == 0 else 1
	for i in range(count):
		var spread = (float(i) - float(count - 1) / 2.0) * .21
		var direction = forward.rotated(Vector3.UP, spread)
		var projectile = world.box(world, origin, Vector3(.32, .16, .55), Color("e7b28f") if wave_number % 2 else Color("d295b8"))
		bullets.append({"node": projectile, "velocity": direction * (7.0 + intensity * .8), "life": 6.0})
	world.actors[0].punch = 1
	sound.effect("select")

func dodge_won() -> void:
	state = "cutscene"
	player.enabled = false
	ui.survival.text = "00 s   •   VOCÊ CONSEGUIU"
	ui.danger.text = ""
	for b in bullets:
		b.node.queue_free()
	bullets.clear()
	sound.play("douglas_e_ele", 89, 128)
	say([["Namorada", "Fiquem juntos, então. Só não me procure mais."], ["Viajante", "Você tem razão de estar brava. Eu devia ter sido honesto."], ["Douglas", "Não dá pra atravessar a vida escondendo tudo, Charles."]], ending)

func ending() -> void:
	stage = "ending"
	state = "cutscene"
	var ex = world.actors[0]
	var douglas = world.actors[1]
	ex.walk_speed = 5
	ex.rotation.y = PI / 2
	var t = create_tween()
	t.tween_property(ex, "position:x", -18.0, 2)
	player.position = Vector3(-.3, 0, 3)
	douglas.position = Vector3(.3, 0, 2.7)
	player.face(douglas.position)
	douglas.rotation.y = -PI / 2
	player.actor.pose = "hug"
	douglas.pose = "hug"
	cinema.current = true
	cinema.position = Vector3(4, 2.5, 7)
	cinema.look_at(Vector3(0, 1, 3))
	say([["Viajante", "Um portal tá abrindo. De novo."], ["Douglas", "Então faz essa passagem valer a pena."], ["Viajante", "Eu vou lembrar de você. Mesmo quando meu nome não for Charles."]], open_portal)

func open_portal() -> void:
	stage = "portal"
	ui.combat(false)
	ui.danger.text = ""
	for b in bullets:
		if is_instance_valid(b.node):
			b.node.queue_free()
	bullets.clear()
	player.actor.pose = "idle"
	world.create_portal(Vector3(0, 0, -4))
	player.position = Vector3(0, .1, 3)
	player.orbit = 0
	set_objective("DIMENSÃO CONCLUÍDA", "Parabéns! Atravesse o novo portal quando quiser.")
	save_checkpoint("portal")
	sound.effect("portal")
	sound.play("douglas_e_eu", 133, 194)
	set_play()
	ui.notify("DIMENSÃO DEDADÃO CONCLUÍDA")

func complete() -> void:
	stage = "complete"
	state = "gameover"
	player.enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.result_title.text = "ATÉ A PRÓXIMA DIMENSÃO."
	ui.result_title.add_theme_font_size_override("font_size", 35)
	ui.result_text.text = "Dedadão concluída. O caminho de volta a Robson continua.\n\nVocê terminou as quatro partes desta fase."
	ui.result_button.text = "VOLTAR AO MENU"
	ui.result_panel.show()
	ui.result_button.grab_focus()

func fail(reason: String) -> void:
	if state == "gameover":
		return
	last_failure = reason
	ui.toast_time = 0
	ui.prompt.text = ""
	state = "gameover"
	dead = true
	player.enabled = false
	player.actor.visible = true
	world.moving_taxi = false
	sound.duck = true
	ui.danger.text = ""
	ui.failure(reason)
	sound.effect("danger")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func traffic_death() -> void:
	if state != "play" or stage not in ["neighborhood", "clinic_street", "coffee", "stroll"]:
		return
	player.actor.rotation.z = PI / 2
	player.velocity = Vector3.ZERO
	world.traffic_enabled = false
	if stage == "neighborhood":
		save_checkpoint("neighborhood")
	burst(player.position + Vector3(0, 1, 0), Color("eed6a8"))
	fail("ATROPELADO. A rua não perdoou a distração.\nOlhe para os dois lados e espere uma brecha. O carro também acerta durante a esquiva.")

func retry_checkpoint() -> void:
	if stage == "complete":
		to_menu()
		return
	ui.result_panel.hide()
	ui.close_dialog()
	ui.show_menu(false)
	match checkpoint:
		"void": start_void()
		"home": start_home()
		"neighborhood": start_neighborhood()
		"taxi": rebuild("neighborhood", Vector3(-8, .2, 4.8)); start_taxi()
		"clinic_street": arrive_clinic_street()
		"clinic": start_clinic()
		"coffee": visits.start_coffee()
		"stroll": visits.start_stroll()
		"invite": start_invite()
		"fight": start_fight()
		"dodge": start_dodge()
		"portal": rebuild("parking", Vector3(0, .1, 3)); open_portal()
		_: new_game()

func say(lines: Array, done: Callable) -> void:
	ui.toast_time = 0
	ui.prompt.text = ""
	dialogue = lines
	dialogue_index = 0
	dialogue_done = done
	choice_callback = Callable()
	state = "dialogue"
	player.enabled = false
	player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	sound.duck = true
	show_line()

func show_line() -> void:
	var row = dialogue[dialogue_index]
	ui.line(row[0], row[1])

func next_line() -> void:
	if state != "dialogue" or choice_callback.is_valid():
		return
	sound.effect("select")
	dialogue_index += 1
	if dialogue_index >= dialogue.size():
		ui.close_dialog()
		var done = dialogue_done
		dialogue_done = Callable()
		if done.is_valid():
			done.call()
	else:
		show_line()

func ask(who: String, text: String, choices: Array, callback: Callable) -> void:
	ui.toast_time = 0
	ui.prompt.text = ""
	state = "dialogue"
	player.enabled = false
	sound.duck = true
	choice_callback = callback
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ui.line(who, text, choices)

func select_choice(index: int) -> void:
	if not choice_callback.is_valid() or state != "dialogue":
		return
	var cb = choice_callback
	choice_callback = Callable()
	ui.close_dialog()
	sound.effect("select")
	cb.call(index)

func interact() -> void:
	if state != "play" or paused:
		return
	if stage == "void":
		if player.position.distance_to(world.michael.position) < 2.8:
			if void_michael_cooldown <= 0:
				void_michael_cooldown = 2.5
				void_speaker.text = "MICHAEL"
				void_caption.text = "Hee hee"
				void_caption_time = 2.2
				world.michael_reaction = 1.0
				sound.effect("michael_hee")
			return
		enter_void_portal()
		return
	if stage == "home" and clean_home_nearby():
		return
	if visits.interact():
		return
	match stage:
		"home":
			if player.position.distance_to(Vector3(0, 0, 4.5)) < 1.3:
				sound.effect("door")
				start_neighborhood()
				return
		"neighborhood":
			if player.position.distance_to(world.taxi.position) < 3.5:
				if visits.collected.size() < 3:
					ui.notify("Sua ficha voou! Recolha as três folhas amarelas antes de embarcar.")
				else:
					start_taxi()
				return
		"clinic_street":
			if player.position.distance_to(Vector3(22, 0, -8)) < 3:
				sound.effect("door")
				start_clinic()
				return
		"clinic":
			if player.position.distance_to(Vector3(.2, 0, -1.7)) < 3:
				clinic_conversation()
				return
		"portal":
			if player.position.distance_to(Vector3(0, 0, -4)) < 2.5:
				complete()
				return
	if stage in ["neighborhood", "clinic_street", "coffee"]:
		for a in world.actors:
			if player.position.distance_to(a.position) < 2.5:
				npc_talk(a)
				return

func npc_talk(a: Node3D) -> void:
	var entry = load("res://scripts/neighbors.gd").ROSTER[int(a.get_meta("npc_id", 0))]
	var id: String = entry.id
	var selection = (int(npc_last.get(id, -1)) + 1) % entry.lines.size()
	npc_last[id] = selection
	a.pose = "talk"
	a.walk_speed = 0
	player.face(a.position)
	var d = player.position - a.position
	a.rotation.y = atan2(-d.x, -d.z)
	say([[entry.name, entry.lines[selection]]], func():
		if is_instance_valid(a):
			a.pose = "idle"
		set_play())

func exploration_tick() -> void:
	var text = ""
	match stage:
		"home":
			if player.position.distance_to(Vector3(0, 0, 4.5)) < 1.3: text = "[ E ]  Sair de casa"
		"neighborhood":
			var dist = player.position.distance_to(world.taxi.position)
			if dist < 3.5: text = "[ E ]  Entrar no táxi"
		"clinic_street":
			if player.position.distance_to(Vector3(22, 0, -8)) < 3: text = "[ E ]  Entrar na clínica"
		"clinic":
			if player.position.distance_to(Vector3(.2, 0, -1.7)) < 3: text = "[ E ]  Conversar com Douglas"
		"portal":
			if player.position.distance_to(Vector3(0, 0, -4)) < 2.5: text = "[ E ]  Atravessar o portal"
	if text == "" and stage in ["neighborhood", "clinic_street", "coffee"]:
		for a in world.actors:
			if player.position.distance_to(a.position) < 2.5:
				text = "[ E ]  " + a.get_meta("display_name", "Conversar")
		for i in range(memories.size() - 1, -1, -1):
			var item = memories[i]
			item.rotation.y += .02
			if player.position.distance_to(item.position) < 1.1:
				item.queue_free()
				memories.remove_at(i)
				memories_found += 1
				ui.notify("FITA ENCONTRADA • %d / 3  |  Um eco de outra dimensão" % memories_found)
				sound.effect("portal")
	if stage == "home" and text == "":
		var nearby: Dictionary = world.home.nearest(player.position)
		if not nearby.is_empty():
			text = "[ E ]  " + nearby.title
	var mission_prompt: String = visits.prompt()
	ui.prompt.text = mission_prompt if mission_prompt != "" else text

func burst(pos: Vector3, tint: Color) -> void:
	for i in range(9):
		var p = world.box(world, pos, Vector3.ONE * .07, tint)
		sparks.append({"node": p, "velocity": Vector3(randf_range(-2, 2), randf_range(.2, 3), randf_range(-2, 2)), "life": .4})

func _process(dt: float) -> void:
	clock += dt
	if not is_instance_valid(player):
		return
	ui.music_label.text = "♫  " + sound.title + ("  •  SILENCIADO" if sound.muted else "")
	hit_invulnerability = maxf(0, hit_invulnerability - dt)
	if hit_invulnerability > 0 and state == "play":
		player.actor.visible = int(clock * 14) % 2 == 0
	else:
		player.actor.visible = true
	if stage == "menu":
		cinema.position.x = -14 + sin(clock * .09) * 1.5
		cinema.look_at(Vector3(7, 1.6, -7))
	if stage == "taxi":
		var p: Vector3 = world.taxi.position
		cinema.position = p + Vector3(5.4, 3.6, 6.6)
		cinema.look_at(p + Vector3(.4, .7, 0))
	if stage == "void":
		void_tick(dt)
		return
	world.traffic_enabled = state == "play" and stage in ["neighborhood", "clinic_street", "coffee", "stroll"]
	world.pedestrians_paused = state in ["dialogue", "gameover"]
	if state == "play":
		visits.tick(dt)
		if state != "play":
			return
		if stage == "fight":
			fight_tick(dt)
		elif stage == "dodge":
			dodge_tick(dt)
		else:
			exploration_tick()
	for i in range(sparks.size() - 1, -1, -1):
		var p = sparks[i]
		p.node.position += p.velocity * dt
		p.life -= dt
		if p.life <= 0:
			p.node.queue_free()
			sparks.remove_at(i)

func _unhandled_input(event: InputEvent) -> void:
	if stage == "void" and state == "cutscene" and not paused and event.is_action_pressed("interact") and not event.is_echo():
		if is_instance_valid(void_sequence) and void_sequence.running:
			void_sequence.advance()
			get_viewport().set_input_as_handled()
			return
	if stage == "void" and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
		void_reduced = not void_reduced
		void_filter.material.set_shader_parameter("strength", 0.15 if void_reduced else 1.0)
		void_filter_label.text = "V  restaurar VHS   ·   ESC  pausa" if void_reduced else "V  reduzir VHS   ·   ESC  pausa"
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and state != "menu":
			pause_game(not paused)
	if not paused and event.is_action_pressed("interact") and not event.is_echo():
		interact()

func toggle_fullscreen() -> void:
	var mode = DisplayServer.window_get_mode()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode == DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)

func pause_game(value: bool) -> void:
	paused = value
	get_tree().paused = value
	if not is_instance_valid(ui):
		return
	ui.pause_panel.visible = value
	if is_instance_valid(void_hud):
		void_hud.visible = stage == "void" and not value
	if value:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif state == "play" and not test_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func run_qa() -> void:
	var suite = load("res://tests/run.gd").new()
	add_child(suite)
	await suite.run(self)

func capture_showcase() -> void:
	test_mode = true
	var suite = load("res://tests/showcase.gd").new()
	add_child(suite)
	await suite.run(self)

func capture_revision() -> void:
	var suite = load("res://tests/revision_capture.gd").new()
	add_child(suite)
	await suite.run(self)

func setup_void_presentation() -> void:
	for child in get_children():
		if child is WorldEnvironment:
			void_environment = child
			default_environment = child.environment.duplicate(true)
		if child is DirectionalLight3D:
			void_sun = child
	var post = CanvasLayer.new()
	post.layer = 0
	add_child(post)
	void_filter = ColorRect.new()
	void_filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	void_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	void_filter.material = ShaderMaterial.new()
	void_filter.material.shader = load("res://shaders/void_tape.gdshader")
	post.add_child(void_filter)
	void_filter.hide()
	void_hud = CanvasLayer.new()
	void_hud.layer = 2
	add_child(void_hud)
	var overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	void_hud.add_child(overlay)
	void_heading = ui.label(overlay, "FITA 00    /    FORA DO TEMPO", Vector2(38, 30), Vector2(640, 24), 17, Color("c0c8c2"))
	void_goal = ui.label(overlay, "Encontre a porta no alto da escadaria.", Vector2(38, 61), Vector2(700, 38), 23, Color("ede5cf"))
	void_clock_label = ui.label(overlay, "REPRODUÇÃO   00:00", Vector2(925, 30), Vector2(320, 25), 17, Color("c0c8c2"))
	void_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	void_caption = ui.label(overlay, "", Vector2(190, 522), Vector2(900, 76), 26, Color("f1ecd9"))
	void_speaker = ui.label(overlay, "", Vector2(190, 489), Vector2(900, 27), 19, Color("c0cfcd"))
	void_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	void_speaker.add_theme_constant_override("outline_size", 6)
	void_speaker.add_theme_color_override("font_outline_color", Color("101b21"))
	void_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	void_caption.add_theme_constant_override("outline_size", 8)
	void_caption.add_theme_color_override("font_outline_color", Color("101b21"))
	void_prompt = ui.label(overlay, "", Vector2(270, 605), Vector2(740, 36), 23, Color("f2e2bb"))
	void_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	void_prompt.add_theme_constant_override("outline_size", 6)
	void_prompt.add_theme_color_override("font_outline_color", Color("101b21"))
	void_controls = ui.label(overlay, "WASD  caminhar     SHIFT  correr     MOUSE  olhar     E  atravessar", Vector2(38, 667), Vector2(950, 25), 15, Color("bdc8c1"))
	void_filter_label = ui.label(overlay, "V  reduzir VHS   ·   ESC  pausa", Vector2(904, 667), Vector2(340, 25), 15, Color("bdc8c1"))
	void_filter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	void_hud.hide()

func apply_void_presentation(active: bool) -> void:
	if not is_instance_valid(void_filter):
		return
	void_filter.visible = active
	void_hud.visible = active
	void_filter.material.set_shader_parameter("whiteout", 0.0)
	ui.hud.visible = not active and stage != "menu"
	if not active:
		void_environment.environment = default_environment.duplicate(true)
		void_sun.light_color = Color("ffd4a2")
		void_sun.light_energy = 0.72
		void_sun.rotation_degrees = Vector3(-35, -35, 0)
		return
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0b1b25")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8caeb5")
	env.ambient_light_energy = 0.63
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("112732")
	env.fog_density = 0.0024
	void_environment.environment = env
	void_sun.light_color = Color("b7c5c2")
	void_sun.light_energy = 0.9
	void_sun.rotation_degrees = Vector3(-28, -42, -12)

func start_void() -> void:
	stage = "void"
	ui.close_dialog()
	ui.show_menu(false)
	ui.result_panel.hide()
	rebuild("void", Vector3(0, 0.12, 12))
	player.bounds = Vector2(100, 180)
	player.distance = 5.7
	player.pitch = 0.08
	player.walk_speed = 3.6
	player.run_speed = 5.8
	player.reset_on_fall = false
	player.camera.far = 450
	void_elapsed = 0
	void_rest_index = 0
	void_cue_index = 0
	void_caption_time = 6.0
	void_caption.text = "Não tô mais em casa."
	void_respawns = 0
	void_michael_cooldown = 0.0
	void_speaker.text = ""
	void_goal.visible = true
	void_controls.visible = true
	save_checkpoint("void")
	set_objective("00 / FORA DO TEMPO", "Encontre a porta no alto da escadaria.")
	if sound.fade and sound.fade.is_valid():
		sound.fade.kill()
	for track_player in sound.players:
		track_player.stop()
	sound.current = ""
	sound.title = ""
	set_play()
	apply_void_presentation(true)
	if not void_intro_seen:
		void_sequence = load("res://scripts/void_sequence.gd").new()
		world.add_child(void_sequence)
		void_sequence.begin(self)

func void_tick(dt: float) -> void:
	void_elapsed += dt
	void_michael_cooldown = maxf(0, void_michael_cooldown - dt)
	void_filter.material.set_shader_parameter("tape_time", void_elapsed)
	void_clock_label.text = "REPRODUÇÃO   %02d:%02d" % [int(void_elapsed) / 60, int(void_elapsed) % 60]
	void_caption_time -= dt
	void_caption.modulate.a = clampf(void_caption_time, 0, 1)
	void_speaker.modulate.a = void_caption.modulate.a
	if state != "play":
		return
	for i in range(world.rest_points.size()):
		var p: Vector3 = world.rest_points[i]
		if i > void_rest_index and Vector2(player.position.x - p.x, player.position.z - p.z).length() < 3.5 and absf(player.position.y - p.y) < 1.3:
			void_rest_index = i
	var safe: Vector3 = world.rest_points[void_rest_index]
	if player.position.y < safe.y - 6.0:
		player.position = safe + Vector3(0, 0.25, 0)
		player.velocity = Vector3.ZERO
		void_respawns += 1
		void_speaker.text = ""
		void_caption.text = "Mesmo perdido, sigo em frente."
		void_caption_time = 4.0
	var cues = [
		[-19.0, "Montanhas dentro de lagos."],
		[-46.0, "Cidades inexistentes. Universos paralelos."],
		[-73.0, "Nada mais tem um sentido."],
		[-96.0, "Robson, cê me espera que eu já tô chegando."]
	]
	if void_cue_index < cues.size() and player.position.z < cues[void_cue_index][0]:
		void_speaker.text = "JÚNIOR"
		void_caption.text = cues[void_cue_index][1]
		void_caption_time = 4.5
		void_cue_index += 1
	var near_door = player.position.distance_to(world.PORTAL_POSITION + Vector3(0, 0, 1.4)) < 3.4
	var near_michael = player.position.distance_to(world.michael.position) < 2.8
	void_prompt.text = "[ E ]  Falar com Michael" if near_michael else ("[ E ]  Atravessar a porta" if near_door else "")

func enter_void_portal() -> void:
	if state != "play" or player.position.distance_to(world.PORTAL_POSITION + Vector3(0, 0, 1.4)) >= 3.4:
		return
	var serial = transition_serial
	state = "cutscene"
	player.enabled = false
	player.velocity = Vector3.ZERO
	void_prompt.text = ""
	void_speaker.text = "JÚNIOR"
	void_caption.text = "Uma porta tá se abrindo."
	void_caption_time = 5.0
	sound.effect("portal")
	var tween = create_tween().set_parallel(true)
	tween.tween_property(void_filter.material, "shader_parameter/whiteout", 1.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(player, "position", world.PORTAL_POSITION + Vector3(0, 0.7, 0.5), 1.4)
	await tween.finished
	if serial != transition_serial or stage != "void":
		return
	start_home()
	ui.veil.color = Color(1, 0.98, 0.88, 1)
	var reveal = create_tween()
	reveal.tween_property(ui.veil, "color:a", 0.0, 0.85)
	await reveal.finished
	ui.veil.color = Color(0.055, 0.045, 0.075, 0)

func run_void_checks() -> void:
	var suite = load("res://tests/void_checks.gd").new()
	add_child(suite)
	await suite.run(self)

func load_home_profile() -> void:
	if test_mode:
		return
	if FileAccess.file_exists("res://save/achievements.json"):
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://save/achievements.json"))
		if data is Dictionary:
			home_achievement = bool(data.get("clean_home", false))

func save_home_profile() -> void:
	if test_mode:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://save"))
	var file = FileAccess.open("res://save/achievements.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"clean_home": home_achievement}))

func clean_home_nearby() -> bool:
	if player.position.distance_to(Vector3(0, 0, 4.5)) < 1.3:
		return false
	var nearby: Dictionary = world.home.nearest(player.position)
	if nearby.is_empty():
		return false
	if world.home.clean(nearby.id):
		home_cleaned = world.home.completed.duplicate()
		save_checkpoint("home")
		sound.effect("select")
		if home_cleaned.size() == world.home.tasks.size() and not home_achievement:
			home_achievement = true
			ui.home_achievement = true
			save_home_profile()
			ui.notify("CONQUISTA DESBLOQUEADA\nCaja susa, chão sujo...")
		else:
			var remarks = {
				"mattress": "Júnior: Robson merece uma cama melhor.",
				"table": "Júnior: Até aqui o chiado me segue.",
				"chair": "Júnior: Uma pausa entre dois portais.",
				"toilet": "Júnior: Achei a dimensão condenada.",
				"sink": "Júnior: Michael não falou nada de louça."
			}
			ui.notify(remarks.get(nearby.id, "Pronto."))
			ui.toast_time = HOME_REMARK_SECONDS if nearby.id in remarks else 1.0
	return true

func run_home_checks() -> void:
	var checks = load("res://tests/home_checks.gd").new()
	add_child(checks)
	await checks.run(self)

func run_street_checks() -> void:
	var checks = load("res://tests/street_checks.gd").new()
	add_child(checks)
	await checks.run(self)

func setup_street_presentation() -> void:
	street_fog = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(2, 2)
	street_fog.mesh = quad
	street_fog.extra_cull_margin = 16384.0
	street_fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fog_material = ShaderMaterial.new()
	fog_material.shader = load("res://shaders/street_fog.gdshader")
	street_fog.material_override = fog_material
	add_child(street_fog)
	street_fog.hide()
	var layer = CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	street_filter = ColorRect.new()
	street_filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	street_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	street_filter.material = ShaderMaterial.new()
	street_filter.material.shader = load("res://shaders/street_pixels.gdshader")
	layer.add_child(street_filter)
	street_filter.hide()

func apply_street_presentation(active: bool) -> void:
	street_filter.visible = active
	street_fog.visible = active
	if not active:
		return
	var env = void_environment.environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("192326")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9aaea8")
	env.ambient_light_energy = .62
	env.fog_enabled = true
	env.fog_light_color = Color("283638")
	env.fog_density = .026
	env.fog_sky_affect = 1.0
	void_sun.light_color = Color("a3b4be")
	void_sun.light_energy = .42
	void_sun.rotation_degrees = Vector3(-20, -55, 0)

func run_fix_checks() -> void:
	var runner = load("res://tests/street_fix_checks.gd").new()
	add_child(runner)
	runner.run(self)
