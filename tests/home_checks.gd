extends Node

var results: Array = []
var g: Node

func check(label: String, value: bool) -> void:
	results.append({"test":label,"passed":value})
	print("PASS " if value else "FAIL ",label)

func snapshot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/"+name+".png")

func run(game: Node) -> void:
	g = game
	g.ui.show_menu(false)
	g.start_home()
	g.ui.subtitle.visible_characters = -1
	await snapshot("home_arrival")
	g.ui.close_dialog()
	g.set_play()
	await get_tree().process_frame
	await get_tree().create_timer(.15).timeout
	await snapshot("home_gameplay")
	check("Home contains 17 optional tasks",g.world.home.tasks.size()==17)
	check("Appointment wording",g.world.home.get_node("AppointmentBoard").text=="Consulta hoje as 16:00")
	check("No cleaning checklist in objective",not "limp" in g.ui.objective.text.to_lower())
	check("No distant interaction",g.world.home.nearest(Vector3(0,0,0)).is_empty())
	g.ui.show_extras(false)
	check("Achievement concealed", "???" in g.ui.extras_text.text)
	g.ui.close_extras()
	g.ui.show_menu(false)
	g.cinema.current=true
	g.cinema.position=Vector3(1.8,3.7,4.7)
	g.cinema.look_at(Vector3(-1.5,.9,-2.4))
	await snapshot("home_dirty_living")
	g.cinema.position=Vector3(-1.8,3.2,3.7)
	g.cinema.look_at(Vector3(4,.8,-2.3))
	await snapshot("home_dirty_kitchen")
	var first: Dictionary=g.world.home.tasks[0]
	g.player.position=first.node.position
	g.exploration_tick()
	check("Nearby hidden action appears", "Arrumar" in g.ui.prompt.text)
	g.interact()
	check("Cleaning removes dirt",not first.node.visible)
	check("Partial cleaning does not unlock",not g.home_achievement)
	check("Duplicate cleanup rejected",not g.world.home.clean(first.id))
	g.rebuild("home",Vector3(0,.1,.7),PI)
	g.set_play()
	check("Cleaning survives house rebuild",g.world.home.completed.size()==1)
	g.pause_game(true)
	g.player.position=g.world.home.tasks[1].node.position
	var before=g.home_cleaned.size()
	g.interact()
	check("Pause blocks cleaning",g.home_cleaned.size()==before)
	g.pause_game(false)
	g.test_mode=false
	for item in g.world.home.tasks:
		if item.id in g.home_cleaned:
			continue
		g.player.position=item.node.position+Vector3(0,.1,0)
		g.interact()
	check("All proximity interactions complete",g.home_cleaned.size()==17)
	check("Secret achievement unlocked",g.home_achievement)
	check("Achievement shown in toast","Caja susa" in g.ui.toast.text)
	var saved=JSON.parse_string(FileAccess.get_file_as_string("res://save/checkpoint.json"))
	check("Campaign cleaning persisted",saved.home_cleaned.size()==17)
	g.home_achievement=false
	g.load_home_profile()
	check("Achievement loaded from disk",g.home_achievement)
	g.home_cleaned=[]
	g.continue_saved()
	g.ui.close_dialog()
	g.set_play()
	check("Continue restores clean home",g.world.home.completed.size()==17)
	g.cinema.current=true
	g.cinema.position=Vector3(1.8,3.7,4.7)
	g.cinema.look_at(Vector3(-1.5,.9,-2.4))
	await snapshot("home_clean")
	g.to_menu()
	g.ui.show_extras(false)
	check("Achievements area shows unlocked","1 / 1" in g.ui.extras_text.text)
	await snapshot("achievements")
	g.ui.close_extras()
	g.ui.show_extras(true)
	check("Menu changelog exactly matches TXT",g.ui.extras_text.text==FileAccess.get_file_as_string("res://CHANGELOG.txt"))
	check("History retained","VERSÃO 0.1" in g.ui.extras_text.text and "VERSÃO 0.4" in g.ui.extras_text.text)
	await snapshot("changelog")
	g.ui.close_extras()
	g.test_mode=true
	g.new_game()
	check("New game resets cleaning",g.home_cleaned.is_empty())
	check("New game preserves achievement",g.home_achievement)
	g.start_home()
	g.ui.close_dialog()
	g.set_play()
	g.player.position=Vector3(0,.1,4.5)
	g.interact()
	check("Exit allowed without cleaning",g.stage=="neighborhood")
	var file=FileAccess.open("res://tests/home_results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"\t"))
	file.close()
	var failed=results.filter(func(item):return not item.passed)
	print("HOME CHECKS: ",results.size()-failed.size(),"/",results.size())
	get_tree().quit(0 if failed.is_empty() else 1)
