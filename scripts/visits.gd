extends Node

var g: Node
var collected: Array = []
var papers: Array = []
var coffee_level = 100.0
var carrying = false
var cup: Node3D
var doctor: Node3D
var stroll_point = 0
var stroll_ready = false
var last_dash = false
var last_air = false
var elapsed = 0.0
const CAFE = Vector3(-2, .17, 6.8)
const CLINIC = Vector3(22, .17, -8)
const PAPER_SPOTS = [Vector3(-24, .6, 5.5), Vector3(-19, .6, 5.5), Vector3(-12, .6, 5.5)]
const WALK = [Vector3(20, .17, -5), Vector3(14, .17, -5), Vector3(8, .17, -5)]

func setup_papers() -> void:
	papers.clear()
	for i in range(PAPER_SPOTS.size()):
		if i in collected:
			continue
		var sheet = g.world.box(g.world, PAPER_SPOTS[i], Vector3(.5, .025, .7), Color("ffdb7d"))
		g.world.box(sheet, Vector3(0, .02, -.15), Vector3(.34, .008, .045), Color("665247"))
		g.world.box(sheet, Vector3(0, .02, 0), Vector3(.34, .008, .045), Color("665247"))
		var tag = g.world.text3(sheet, "FICHA", Vector3(0, .6, 0), 21, Color("ffe4a1"))
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		papers.append({"node": sheet, "id": i})
	update_paper_objective()
	if collected.size() < 3:
		g.target(PAPER_SPOTS[papers[0].id] + Vector3(0, 1.4, 0), "A FICHA VOOU!")

func update_paper_objective() -> void:
	if collected.size() < 3:
		g.set_objective("01 / 04 • VENTO CONTRA", "Recolha a ficha: %d / 3 folhas. [E] perto delas." % collected.size())
	else:
		g.set_objective("01 / 04 • FICHA RESGATADA", "Agora sim: encontre o táxi amarelo.")
		g.target(Vector3(-8, 3, 2.6), "TÁXI")

func take_paper(index: int) -> void:
	var item = papers[index]
	collected.append(item.id)
	item.node.queue_free()
	papers.remove_at(index)
	g.sound.effect("select")
	g.save_checkpoint("neighborhood")
	update_paper_objective()
	if not papers.is_empty():
		g.target(PAPER_SPOTS[papers[0].id] + Vector3(0, 1.4, 0), "FOLHA DA CONSULTA")
	var comments = [
		["Viajante", "O vento já examinou minha ficha antes do médico. Ótimo começo."],
		["Viajante", "Nome, horário... e eu correndo atrás de um papel como se fosse uma carta de amor."],
		["Viajante", "Pronto. Se o taxista perguntar, eu estava fazendo cardio."]
	]
	g.ui.notify(comments[collected.size() - 1][1])

func make_cup(parent: Node3D, position: Vector3) -> Node3D:
	var node = Node3D.new()
	parent.add_child(node)
	node.position = position
	g.world.cylinder(node, Vector3.ZERO, .095, .24, Color("ead4ac"), .12)
	g.world.cylinder(node, Vector3(0, .13, 0), .125, .025, Color("49393b"))
	g.world.cylinder(node, Vector3(0, .01, 0), .104, .09, Color("a57554"), .114)
	return node

func start_coffee() -> void:
	g.stage = "coffee"
	g.rebuild("neighborhood", Vector3(-4, .22, 5.1), PI / 2)
	carrying = false
	coffee_level = 100
	last_dash = false
	last_air = false
	g.world.box(g.world, CAFE + Vector3(0, .65, .1), Vector3(2.3, 1.3, .65), Color("936149"), true, "wood")
	g.world.text3(g.world, "CAFÉ DO BAIRRO", CAFE + Vector3(0, 2.15, .1), 32).rotation.y = PI
	cup = make_cup(g.world, CAFE + Vector3(0, 1.45, -.25))
	g.target(CAFE + Vector3(0, 2.9, 0), "UM CAFÉ PRA DOIS")
	g.set_objective("02 / 04 • UMA SEMANA DEPOIS", "Pegue o café na banca. [E] para interagir.")
	g.sound.play("douglas_e_eu", 0, 39)
	g.save_checkpoint("coffee")
	g.set_play()
	g.say([["Viajante", "O Douglas comentou que mal sobra tempo pro café. Tá aí uma desculpa melhor do que inventar outra consulta."], ["Viajante", "Levar um copo sem derramar. Eu sobrevivi a um portal; isso devia ser fácil."]], g.set_play)

func take_coffee() -> void:
	carrying = true
	if is_instance_valid(cup):
		cup.queue_free()
	cup = make_cup(g.player.actor, Vector3(-.28, 1.09, -.43))
	g.player.actor.pose = "carry"
	g.target(CLINIC + Vector3(0, 2.6, 0), "CAFÉ PARA DOUGLAS")
	g.set_objective("02 / 04 • NÃO DERRAMA!", "Leve à clínica. Correr, pular e esquivar derrama.")
	g.ui.survival.show()
	g.ui.notify("Ande com calma. Espere uma brecha no trânsito antes de atravessar.")

func deliver_coffee() -> void:
	carrying = false
	g.rebuild("clinic", Vector3(0, .1, 1.2), 0)
	g.stage = "coffee_scene"
	g.player.camera.current = true
	g.world.actors[0].pose = "talk"
	make_cup(g.world, Vector3(-1.5, 1.02, -1.8))
	g.set_objective("02 / 04 • LEMBREI DE VOCÊ", "Desta vez, nenhuma consulta marcada.")
	var response = "Você lembrou. E ainda chegou cheio." if coffee_level >= 70 else "Veio pela metade... mas chegou. Você trouxe isso pra mim?"
	g.say([["Douglas", response], ["Viajante", "Eu ia dizer que estava passando. Mas eu atravessei o bairro inteiro segurando esse copo."], ["Douglas", "Eu gosto mais dessa versão. Sem inventar um sintoma pra me ver."]], coffee_choice)

func coffee_choice() -> void:
	g.ask("Douglas", "O que você faz quando não está inventando desculpa pra vir aqui?", ["Eu queria saber mais de você também.", "Ultimamente? Ensaio essa conversa."], func(index):
		var answer = "Eu desenho nas horas vagas. Nada incrível. Mas eu gosto quando alguém pergunta." if index == 0 else "Então relaxa. Eu também ensaiei o que ia falar quando você voltasse."
		g.say([["Douglas", answer], ["Viajante", "Pela primeira vez, o silêncio aqui não tá me dando medo."], ["Douglas", "Na sexta eu saio mais cedo. A gente pode caminhar um pouco."]], start_stroll))

func start_stroll() -> void:
	g.stage = "stroll"
	g.rebuild("clinic_street", Vector3(22, .22, -5.2), PI / 2)
	doctor = g.world.actor("douglas", Vector3(20, .17, -5.0))
	stroll_point = 0
	stroll_ready = false
	g.world.bench(Vector3(8, .17, -6.7))
	g.save_checkpoint("stroll")
	g.set_objective("02 / 04 • SEXTA, FORA DO HORÁRIO", "Caminhe ao lado de Douglas até o banco.")
	g.sound.play("douglas_e_eu", 40, 93)
	g.set_play()
	g.ui.notify("Douglas espera se você ficar para trás. Chegue perto para continuar.")

func stroll_tick(dt: float) -> void:
	if stroll_ready or not is_instance_valid(doctor):
		return
	if g.player.position.distance_to(doctor.position) > 3.6:
		doctor.walk_speed = 0
		g.ui.danger.text = "Douglas está esperando você."
		return
	g.ui.danger.text = ""
	var destination: Vector3 = WALK[stroll_point]
	var delta: Vector3 = destination - doctor.position
	if delta.length() > .15:
		doctor.position = doctor.position.move_toward(destination, dt * 1.7)
		doctor.walk_speed = 1.7
		doctor.rotation.y = atan2(-delta.x, -delta.z)
		return
	doctor.walk_speed = 0
	stroll_point += 1
	if stroll_point == 1:
		g.say([["Douglas", "Aqui fora você pode me chamar só de Douglas."], ["Viajante", "Ainda bem. Eu já tava cansado de usar a consulta como assunto."]], g.set_play)
	elif stroll_point == 2:
		g.say([["Douglas", "Você falou de procurar um caminho de volta. Tem alguém te esperando?"], ["Viajante", "Tem. E eu ainda não entendi o que essa dimensão quer de mim."], ["Douglas", "Então não me promete uma vida inteira hoje. Só fica aqui um minuto."]], g.set_play)
	else:
		stroll_ready = true
		doctor.rotation.y = PI
		g.target(Vector3(8, 2.5, -6), "UM MINUTO SEM DESCULPAS")
		g.set_objective("02 / 04 • UM MINUTO SEM DESCULPAS", "Chegue perto de Douglas e aperte E.")

func finish_stroll() -> void:
	g.player.face(doctor.position)
	doctor.pose = "talk"
	g.say([["Viajante", "Eu não sei quanto tempo eu tenho aqui. Mas não quero passar esse tempo inventando motivo pra te ver."], ["Douglas", "Então faz um convite de verdade."]], func(): g.start_invite())

func prompt() -> String:
	if g.stage == "neighborhood":
		for item in papers:
			if is_instance_valid(item.node) and g.player.position.distance_to(item.node.position) < 1.65:
				return "[ E ] Recolher folha da ficha"
	elif g.stage == "coffee":
		if not carrying and g.player.position.distance_to(CAFE) < 2.1:
			return "[ E ] Pegar café para Douglas"
		if carrying and g.player.position.distance_to(CLINIC) < 3:
			return "[ E ] Entregar café"
	elif g.stage == "stroll" and stroll_ready and g.player.position.distance_to(doctor.position) < 3:
		return "[ E ] Ficar com Douglas"
	return ""

func interact() -> bool:
	if prompt() == "":
		return false
	if g.stage == "neighborhood":
		for i in range(papers.size()):
			if g.player.position.distance_to(papers[i].node.position) < 1.65:
				take_paper(i)
				return true
	elif g.stage == "coffee":
		if carrying:
			deliver_coffee()
		else:
			take_coffee()
		return true
	elif g.stage == "stroll":
		finish_stroll()
		return true
	return false

func tick(dt: float) -> void:
	elapsed += dt
	if g.stage == "neighborhood":
		for item in papers:
			if not is_instance_valid(item.node):
				continue
			var spot: Vector3 = PAPER_SPOTS[item.id]
			item.node.position = spot + Vector3(sin(elapsed * .8 + item.id) * .85, sin(elapsed * 2 + item.id) * .13, 0)
			item.node.rotation.z = sin(elapsed * 1.5) * .18
	elif g.stage == "coffee" and carrying:
		g.player.actor.pose = "carry"
		var speed: float = Vector2(g.player.velocity.x, g.player.velocity.z).length()
		if speed > 4.8:
			coffee_level = maxf(0, coffee_level - dt * 13)
		var dash: bool = g.player.dash_time > 0
		var air: bool = g.player.velocity.y > 2
		if dash and not last_dash:
			coffee_level = maxf(0, coffee_level - 22)
		if air and not last_air:
			coffee_level = maxf(0, coffee_level - 14)
		last_dash = dash
		last_air = air
		g.ui.survival.text = "CAFÉ  %d%%" % int(ceil(coffee_level))
		g.ui.danger.text = "Tá derramando! Vá com calma." if speed > 4.8 else "Café na mão, olho na rua."
		if coffee_level <= 0:
			g.fail("O café virou lembrança. Ficou tudo pelo caminho.\nTente novamente na banca. Caminhar preserva o copo; correr, pular e esquivar derrama.")
	elif g.stage == "stroll":
		stroll_tick(dt)
