extends Node

func shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/" + name + ".png")
	print("RENDER_STATS ", name, " fps=", Engine.get_frames_per_second(), " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))

func run(g: Node) -> void:
	await get_tree().create_timer(1).timeout
	await shot("01_menu")
	g.ui.show_menu(false)
	g.start_neighborhood()
	g.player.position = Vector3(-13, .2, 6)
	g.player.orbit = .65
	g.player.pitch = -.24
	g.player.actor.rotation.y = PI
	await get_tree().create_timer(.8).timeout
	await shot("02_bairro")
	g.start_clinic()
	g.player.position = Vector3(.2, .1, 1.7)
	g.clinic_conversation()
	g.ui.char_count = 1000
	await get_tree().create_timer(.3).timeout
	await shot("03_clinica")
	g.ui.close_dialog()
	g.start_fight()
	g.player.position = Vector3(.3, .1, 2.6)
	await get_tree().create_timer(.4).timeout
	await shot("04_luta")
	g.start_dodge()
	g.spawn_wave(3)
	await get_tree().create_timer(1).timeout
	await shot("05_esquiva")
	g.open_portal()
	await get_tree().create_timer(.5).timeout
	await shot("06_portal")
	g.start_home()
	g.ui.char_count = 1000
	await get_tree().create_timer(.3).timeout
	await shot("07_casa")
	g.ui.close_dialog()
	g.start_neighborhood()
	g.start_taxi()
	g.next_line()
	g.next_line()
	g.next_line()
	g.ui.char_count = 1000
	await get_tree().create_timer(.6).timeout
	await shot("08_taxi_escolhas")
	g.fail("Você revelou informações demais.\nTente manter o destino e proteger seus dados pessoais.")
	await shot("09_reinicio")
	print("CAPTURES_OK")
	get_tree().quit()
