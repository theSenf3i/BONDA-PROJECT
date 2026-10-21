extends Node

func shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/" + name + ".png")
	print("CAPTURE ", name)

func run(g: Node) -> void:
	g.test_mode = true
	g.ui.show_menu(false)
	g.start_neighborhood()
	g.state = "cutscene"
	g.player.hide()
	g.player.enabled = false
	g.world.pedestrians_paused = true
	for i in range(3):
		var a = g.world.actors[i]
		a.position = Vector3(-10.5 + i * 1.8, .17, 5.2)
		a.rotation.y = 0
		a.pose = "talk"
		for label in a.find_children("*", "Label3D", true, false):
			label.text = ["JEAN", "VITO", "BIFFE"][i]
	g.cinema.current = true
	g.cinema.position = Vector3(-8.7, 1.8, -.5)
	g.cinema.look_at(Vector3(-8.7, 1.2, 5.2))
	for entry in g.world.cars:
		entry.node.hide()
	g.world.taxi.hide()
	g.ui.toast_time = 0
	g.marker.hide()
	for item in g.visits.papers:
		item.node.hide()
	g.ui.chapter.text = "A GALERA DO BAIRRO"
	g.ui.objective.text = "Jean, Vito e Biffe • quatro falas para cada um"
	await get_tree().create_timer(.4).timeout
	await shot("10_trio")
	g.start_neighborhood()
	g.player.position = Vector3(-23, .2, 6)
	g.player.orbit = .6
	await get_tree().create_timer(.2).timeout
	await shot("11_ficha")
	g.npc_talk(g.world.actors[0])
	g.ui.char_count = 1000
	await shot("12_jean_dialogo")
	g.ui.close_dialog()
	g.visits.start_coffee()
	while g.state == "dialogue":
		g.next_line()
	g.visits.take_coffee()
	g.player.position = Vector3(-1, .2, 5.2)
	g.player.orbit = 1.1
	await get_tree().create_timer(.3).timeout
	await shot("13_cafe")
	g.visits.start_stroll()
	g.player.position = Vector3(19.7, .2, -4.7)
	g.player.orbit = 1.1
	await get_tree().create_timer(.2).timeout
	g.ui.char_count = 1000
	await shot("14_caminhada")
	g.ui.close_dialog()
	g.start_dodge()
	g.dodge_time = 12
	g.wave_number = 2
	g.spawn_wave(2)
	await get_tree().create_timer(1).timeout
	await shot("15_rajada")
	g.start_neighborhood()
	g.player.position = Vector3(-9, .2, 1.5)
	g.traffic_death()
	await shot("16_atropelado")
	get_tree().quit()
