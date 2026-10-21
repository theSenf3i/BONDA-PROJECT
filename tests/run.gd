extends Node

var assertions = 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)
		push_error("QA FAILED: " + message)
	else:
		print("PASS: " + message)

func skip_lines(g: Node) -> void:
	var guard = 0
	while g.state == "dialogue" and not g.choice_callback.is_valid() and guard < 40:
		g.next_line()
		guard += 1

func run(g: Node) -> void:
	g.test_mode = true
	g.ui.show_menu(false)
	g.start_home()
	skip_lines(g)
	check(g.stage == "home" and g.state == "play", "Início em casa e controle após legendas")
	check(g.player.actor.arm_l != null and g.player.actor.leg_r != null, "Modelo importado com articulações")
	g.player.position = Vector3(0, .1, 4.4)
	g.interact()
	check(g.stage == "neighborhood", "Porta leva ao bairro")
	check(g.world.actors.size() == 9 and g.world.cars.size() == 5, "Bairro contém moradores e trânsito")
	var original_position: Vector3 = g.player.position
	Input.action_press("forward")
	await get_tree().create_timer(.5).timeout
	Input.action_release("forward")
	check(g.player.position.distance_to(original_position) > .4, "Movimento físico responde a input")
	var npc = g.world.actors[0]
	g.npc_talk(npc)
	var first = g.npc_last[npc.get_meta("identity")]
	skip_lines(g)
	g.npc_talk(npc)
	check(g.npc_last[npc.get_meta("identity")] != first, "NPC não repete frase consecutiva")
	skip_lines(g)
	var roster = load("res://scripts/neighbors.gd").ROSTER
	check(roster.size() == 9, "Nove participantes do círculo de criadores no bairro")
	var all_unique = true
	for entry in roster:
		all_unique = all_unique and entry.lines.size() == 4
	check(all_unique, "Cada morador tem quatro falas próprias")
	for i in range(3):
		var a = g.world.actors[i]
		var seen = []
		for j in range(4):
			g.npc_talk(a)
			seen.append(g.dialogue[0][1])
			skip_lines(g)
		check(seen.size() == 4 and seen[0] != seen[1] and seen[0] != seen[3], "Ciclo de falas do NPC " + roster[i].id)
	var sidewalk_ok = true
	g.world.traffic_enabled = false
	for tick in range(2000):
		g.world._physics_process(.05)
		for a in g.world.actors:
			var origin: Vector3 = a.get_meta("origin")
			sidewalk_ok = sidewalk_ok and absf(a.position.z) >= 4.7 and absf(a.position.z) <= 7.0 and absf(a.position.x - origin.x) <= float(a.get_meta("span")) + .01
	check(sidewalk_ok, "Cem segundos de patrulha mantêm todos nas calçadas e nas rotas")
	g.npc_talk(g.world.actors[0])
	var talking_position = g.world.actors[0].position
	g.world._physics_process(.5)
	check(g.world.actors[0].position == talking_position, "NPC para de andar enquanto conversa")
	skip_lines(g)
	g.player.position = Vector3(-8, .2, 4.8)
	g.interact()
	check(g.stage == "neighborhood", "Não embarca sem resgatar a ficha")
	while not g.visits.papers.is_empty():
		g.player.position = g.visits.papers[0].node.position
		g.interact()
	check(g.visits.collected.size() == 3, "Três folhas podem ser recolhidas por interação")
	g.player.position = g.world.cars[0].node.position
	g.world.previous_pedestrian = g.player.position
	g.world.traffic_enabled = true
	g.player.dash_time = .19
	g.world._physics_process(.016)
	check(g.state == "gameover" and g.dead, "Atropelamento mata mesmo durante dash")
	g.retry_checkpoint()
	check(g.stage == "neighborhood" and g.visits.papers.is_empty(), "Reinício na calçada preserva a ficha recolhida")
	g.world.traffic_enabled = true
	g.world.previous_pedestrian = g.player.position
	g.world._physics_process(.016)
	check(g.state == "play", "Trânsito não mata jogador seguro na calçada")
	var car = g.world.cars[0].node
	car.position.x = g.player.position.x - 5
	g.player.position.z = car.position.z
	g.world.previous_pedestrian = g.player.position
	g.world.traffic_enabled = true
	g.world._physics_process(3.0)
	check(g.state == "gameover", "Colisão contínua detecta carro atravessando jogador entre quadros")
	g.retry_checkpoint()
	g.start_taxi()
	skip_lines(g)
	check(g.choice_callback.is_valid() and g.taxi_question == 0, "Táxi apresenta escolhas")
	var initial_taxi = g.world.taxi.position.x
	await get_tree().create_timer(.2).timeout
	check(g.world.taxi.position.x > initial_taxi, "Táxi anda durante conversa")
	g.select_choice(2)
	skip_lines(g)
	g.select_choice(2)
	skip_lines(g)
	check(g.state == "gameover" and g.ui.result_panel.visible, "Informações demais causam derrota com tela de reinício")
	g.retry_checkpoint()
	check(g.taxi_risk == 0 and g.stage == "taxi", "Reinício do táxi limpa risco")
	skip_lines(g)
	for i in range(3):
		g.select_choice(0)
		skip_lines(g)
	check(g.stage == "clinic_street" and g.state == "play", "Respostas reservadas chegam à rua da clínica")
	check(not g.world.moving_taxi and g.player.visible, "Jogador sai do carro")
	g.player.position = Vector3(22, .2, -7)
	g.interact()
	check(g.stage == "clinic", "Entrada da clínica funciona")
	check(g.world.taxi == null, "Clínica não mantém interação de táxi")
	g.clinic_conversation()
	skip_lines(g)
	check(g.state == "cutscene", "Consulta encena atendimento e inicia retorno")
	await get_tree().create_timer(1.9).timeout
	check(g.world.scene_kind == "home" and g.state == "dialogue", "Retorno pós-consulta realmente acontece em casa")
	skip_lines(g)
	await get_tree().create_timer(2.1).timeout
	check(g.stage == "coffee" and g.state == "dialogue", "Uma semana depois abre missão jogável do café")
	skip_lines(g)
	g.player.position = g.visits.CAFE
	g.interact()
	check(g.visits.carrying and g.ui.survival.visible, "Interação pega café e mostra quantidade")
	g.player.velocity = Vector3(4.3, 0, 0)
	g.visits.tick(2)
	check(g.visits.coffee_level == 100, "Caminhada normal preserva café")
	g.player.velocity = Vector3(6.3, 0, 0)
	g.visits.tick(1)
	check(g.visits.coffee_level < 100, "Correr derrama café")
	g.visits.coffee_level = 1
	g.visits.tick(1)
	check(g.state == "gameover", "Copo vazio oferece nova tentativa")
	g.retry_checkpoint()
	skip_lines(g)
	check(g.stage == "coffee" and not g.visits.carrying and g.visits.coffee_level == 100, "Reinício do café não repete consulta ou táxi")
	g.player.position = g.visits.CAFE
	g.interact()
	g.player.position = g.visits.CLINIC
	g.interact()
	check(g.stage == "coffee_scene" and g.world.scene_kind == "clinic", "Entrega leva ao diálogo íntimo com Douglas")
	skip_lines(g)
	check(g.choice_callback.is_valid(), "Conversa do café oferece resposta pessoal")
	g.select_choice(0)
	skip_lines(g)
	check(g.stage == "stroll", "Conversa inicia caminhada de sexta")
	g.player.position = Vector3(40, .2, -5)
	var doctor_position = g.visits.doctor.position
	g.visits.stroll_tick(.1)
	check(g.visits.doctor.position == doctor_position, "Douglas espera quando jogador se afasta")
	for i in range(160):
		g.player.position = g.visits.doctor.position + Vector3(0, 0, .9)
		g.visits.stroll_tick(.1)
		skip_lines(g)
	check(g.visits.stroll_ready and absf(g.visits.doctor.position.z) >= 4.7, "Caminhada chega ao banco pela calçada")
	g.player.position = g.visits.doctor.position + Vector3(0, 0, .8)
	g.interact()
	skip_lines(g)
	check(g.stage == "invite", "Momento no banco leva ao convite original")
	g.start_invite()
	skip_lines(g)
	for i in range(3):
		g.select_choice(1)
		skip_lines(g)
	check(g.state == "gameover" and g.checkpoint == "invite", "Convite pode resultar em rejeição")
	g.retry_checkpoint()
	check(g.affection == 0 and g.invite_question == 0, "Reinício do convite limpa pontuação")
	skip_lines(g)
	for i in range(3):
		g.select_choice(0)
		skip_lines(g)
	check(g.stage == "fight" and g.state == "play", "Convite aceito leva a encontro e combate")
	g.hit_invulnerability = 0
	g.hurt_player(100)
	check(g.state == "gameover", "Combate tem derrota")
	g.retry_checkpoint()
	check(g.player_hp == 100 and g.enemy_hp == 100 and g.stage == "fight", "Combate reinicia diretamente e restaura HP")
	g.player.position = g.enemy.position + Vector3(0, 0, 1.5)
	for i in range(10):
		g.attack_cooldown = 0
		g.attack()
	check(g.enemy_hp <= 0 and g.state == "dialogue", "Ataques de gameplay vencem o combate")
	g.start_dodge()
	check(g.dodge_time == 30 and g.dodge_lives == 3, "Esquiva usa correção final: 30 segundos e 3 vidas")
	g.spawn_wave(0)
	check(g.bullets.size() == 1, "Padrão inicial tem um projétil")
	check(is_equal_approx(g.bullets[0].velocity.length(), 7.0), "Disparo inicial ficou mais rápido")
	g.wave_number = 2
	var before_fan = g.bullets.size()
	g.spawn_wave(1)
	check(g.bullets.size() == before_fan + 3, "Rajada de três começa no segundo estágio")
	for i in range(3):
		g.hit_invulnerability = 0
		g.hurt_player(1)
	check(g.state == "gameover" and g.dodge_lives == 0, "Três impactos encerram esquiva")
	g.retry_checkpoint()
	check(g.dodge_time == 30 and g.dodge_lives == 3 and g.bullets.is_empty(), "Reinício limpa projéteis, tempo e vidas")
	g.hurt_player(1)
	g.hurt_player(1)
	check(g.dodge_lives == 2, "Invulnerabilidade impede dano duplicado")
	g.hit_invulnerability = 100
	for i in range(1801):
		if g.state == "play":
			g.dodge_tick(1.0 / 60.0)
	check(g.dodge_time == 0 and g.state == "dialogue", "Sobrevivência conclui aos 30 segundos")
	check(g.bullets.is_empty(), "Conclusão remove projéteis restantes")
	skip_lines(g)
	check(g.stage == "portal" and is_instance_valid(g.world.portal), "Final oferece portal acessível")
	check(not g.ui.survival.visible and g.ui.danger.text == "", "Portal limpa HUD do desafio final")
	g.player.position = Vector3(0, .1, -3)
	g.interact()
	check(g.stage == "complete" and g.ui.result_panel.visible, "Portal conclui somente esta dimensão")
	check(g.sound.tracks.size() == 5, "Cinco músicas carregadas")
	g.ui.line("Teste", "Palavras com espaços intactos.")
	g.ui.input_lock = 0
	g.ui.next()
	check(g.ui.subtitle.text == "Palavras com espaços intactos.", "Completar digitação preserva espaços")
	g.ui.close_dialog()
	g.pause_game(true)
	check(get_tree().paused and g.ui.pause_panel.visible, "Pausa congela o jogo e mantém interface")
	g.pause_game(false)
	check(not get_tree().paused, "Retomar sai da pausa")
	var result = {"assertions": assertions, "failures": failures, "passed": failures.is_empty()}
	var file = FileAccess.open("res://tests/result.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("QA_RESULT: ", JSON.stringify(result))
	get_tree().quit(0 if failures.is_empty() else 1)
