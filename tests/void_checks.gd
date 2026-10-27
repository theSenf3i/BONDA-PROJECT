extends Node

var results: Array = []
var capture = false

func check(label: String, passed: bool, detail = "") -> void:
	results.append({"check": label, "passed": passed, "detail": detail})
	print(("PASS " if passed else "FAIL ") + label + " " + str(detail))

func shot(name: String) -> void:
	if not capture:
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image = get_viewport().get_texture().get_image()
	image.save_png("res://tests/" + name + ".png")

func run(g: Node) -> void:
	var checkpoint_path = "res://save/checkpoint.json"
	var had_checkpoint = FileAccess.file_exists(checkpoint_path)
	var original_checkpoint = FileAccess.get_file_as_bytes(checkpoint_path) if had_checkpoint else PackedByteArray()
	capture = "--capture-void" in OS.get_cmdline_user_args()
	g.new_game()
	await get_tree().create_timer(0.5).timeout
	check("New game starts with a locked cinematic", g.stage == "void" and g.state == "cutscene" and not g.player.enabled)
	check("Opening uses an overhead filming camera", g.cinema.current and g.cinema.position.y > 15)
	var initial_position: Vector3 = g.player.position
	Input.action_press("left")
	await get_tree().create_timer(0.3).timeout
	Input.action_release("left")
	check("Player cannot steer during opening", absf(g.player.position.x - initial_position.x) < 0.01)
	var drift_start: Transform3D = g.world.drifters[0].node.transform
	await get_tree().create_timer(0.7).timeout
	check("Floating scenery moves during cinematic", not g.world.drifters[0].node.transform.is_equal_approx(drift_start))
	await shot("void_07_overhead")
	g.pause_game(true)
	var frozen_time: float = g.void_sequence.elapsed
	await get_tree().create_timer(0.15, true).timeout
	check("Pause freezes cinematic clock", is_equal_approx(g.void_sequence.elapsed, frozen_time))
	g.pause_game(false)
	while g.void_sequence.phase == "arrival":
		await get_tree().process_frame
	check("Michael dialogue precedes gameplay", g.void_sequence.line_index == 0 and not g.player.enabled)
	await shot("void_08_michael")
	var watched_lines: Array[int] = []
	var intro_limit = 0.0
	while g.void_sequence.running and intro_limit < 60.0:
		if g.void_sequence.phase == "conversation" and g.void_sequence.line_index not in watched_lines:
			watched_lines.append(g.void_sequence.line_index)
		await get_tree().physics_frame
		intro_limit += 1.0 / Engine.physics_ticks_per_second
	check("All briefing lines appear before release", watched_lines.size() == g.void_sequence.lines.size())
	check("Cinematic releases player control", g.state == "play" and g.player.enabled and g.player.camera.current and not g.player.camera_fixed)
	check("Opening completion recorded", g.void_intro_seen)
	var interaction_position: Vector3 = g.player.position
	g.player.position = g.world.michael.position + Vector3(0, 0.1, 1.8)
	g.interact()
	check("Michael only replies with Hee hee", g.void_caption.text == "Hee hee" and g.state == "play")
	check("Michael reaction uses local clip", g.sound.sfx.stream == g.sound.effects["michael_hee"] and is_equal_approx(g.sound.sfx.pitch_scale, 1.0))
	g.interact()
	check("Repeated interaction respects cooldown", g.void_michael_cooldown > 2.0)
	await shot("void_09_interaction")
	g.player.position = interaction_position
	g.player.velocity = Vector3.ZERO
	check("80 steps and elevated portal", g.world.STEP_COUNT == 80 and is_equal_approx(g.world.PORTAL_POSITION.y, 17.6))
	check("Void filter isolated", g.void_filter.visible and not g.ui.hud.visible)
	g.interact()
	check("Portal cannot activate away from summit", g.stage == "void" and g.state == "play")
	var sight = PhysicsRayQueryParameters3D.create(g.player.camera.global_position, g.player.global_position + Vector3(0, 1.0, 0))
	sight.exclude = [g.player.get_rid()]
	check("Opening camera sees traveler without a wall blocking", g.player.get_world_3d().direct_space_state.intersect_ray(sight).is_empty())
	await shot("void_01_entry")
	g.cinema.current = true
	g.cinema.position = Vector3(33, 20, 23)
	g.cinema.look_at(Vector3(-3, 8, -48))
	await shot("void_02_overview")
	g.player.camera.current = true
	var route: Array = g.world.route.duplicate()
	var elapsed = 0.0
	var maximum = 50.0
	var visited = 0
	var mark = Time.get_ticks_msec()
	g.player.camera_fixed = true
	Input.action_press("forward")
	for point in route:
		while Vector2(g.player.position.x - point.x, g.player.position.z - point.z).length() > 0.65 and elapsed < maximum:
			var dir: Vector3 = point - g.player.position
			g.player.orbit = atan2(-dir.x, -dir.z)
			await get_tree().physics_frame
			elapsed += 1.0 / Engine.physics_ticks_per_second
		visited += 1
		if capture and visited == 3:
			Input.action_release("forward")
			g.cinema.current = true
			g.cinema.position = g.player.position + Vector3(5, 5, 7)
			g.cinema.look_at(g.player.position + Vector3(-5, 5, -24))
			await shot("void_03_midway")
			g.player.camera.current = true
			Input.action_press("forward")
	Input.action_release("forward")
	g.player.camera_fixed = false
	check("Continuous walk reaches summit without jumping", elapsed < maximum and g.player.position.z < -107 and g.player.position.y > 17, {"seconds_simulated": elapsed, "position": str(g.player.position), "wall_ms": Time.get_ticks_msec() - mark})
	check("No falls during staircase traversal", g.void_respawns == 0)
	check("Landing recovery advanced", g.void_rest_index == 4)
	g.player.orbit = 0
	g.player.pitch = 0.08
	await get_tree().create_timer(0.4).timeout
	await shot("void_04_portal")
	var before_pause: Vector3 = g.player.position
	g.pause_game(true)
	await get_tree().create_timer(0.1, true).timeout
	check("Pause freezes player", g.player.position.is_equal_approx(before_pause))
	check("Pause hides opening captions", not g.void_hud.visible)
	await shot("void_06_pause")
	g.pause_game(false)
	check("Resume restores opening captions", g.void_hud.visible)
	var key = InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_V
	g._unhandled_input(key)
	check("V reduces tape effect", g.void_reduced)
	g._unhandled_input(key)
	check("V restores tape effect", not g.void_reduced)
	g.player.position = Vector3(40, -12, -105)
	g.player.velocity = Vector3.ZERO
	await get_tree().create_timer(0.1).timeout
	check("Fall recovers at latest landing", g.void_respawns == 1 and g.player.position.distance_to(g.world.rest_points[4]) < 1.2)
	g.player.position = Vector3(0, 17.7, -108)
	g.player.velocity = Vector3.ZERO
	g.interact()
	await get_tree().create_timer(2.7).timeout
	check("Portal leads into existing Dedadão home", g.stage == "home" and g.state == "dialogue")
	check("VHS and void HUD removed after portal", not g.void_filter.visible and not g.void_hud.visible)
	check("Original world lighting restored", g.void_environment.environment.background_mode == Environment.BG_SKY)
	await shot("void_05_destination")
	check("Portal destination retains messy home and 17 tasks", g.world.home.tasks.size() == 17 and g.home_cleaned.is_empty())
	check("Arrival conversation blocks movement", not g.player.enabled)
	check("Arrival ties Michael and Robson to appointment board", "Michael" in str(g.dialogue) and "Robson" in str(g.dialogue) and "Consulta hoje as 16:00" in str(g.dialogue))
	g.test_mode = false
	while g.state == "dialogue":
		g.next_line()
	check("Finishing arrival releases player", g.state == "play" and g.player.enabled and g.home_arrival_seen)
	var arrival_save = JSON.parse_string(FileAccess.get_file_as_string("res://save/checkpoint.json"))
	check("Arrival completion persisted at home checkpoint", arrival_save.get("home_arrival_seen", false) and arrival_save.get("stage", "") == "home")
	g.home_arrival_seen = false
	g.continue_saved()
	check("Continue home avoids replaying arrival", g.stage == "home" and g.state == "play" and g.home_arrival_seen)
	g.player.position = g.world.home.tasks[0].node.position
	g.interact()
	check("Optional cleaning remark keeps exploration playable", g.state == "play" and "Robson" in g.ui.toast.text)
	g.player.position = Vector3(0, .1, 4.5)
	g.interact()
	check("House exit still leads to neighborhood", g.stage == "neighborhood")
	check("Portal-home route enters dark extended street", g.world.extended_street and g.street_filter.visible and g.street_fog.visible)
	while not g.visits.papers.is_empty():
		g.player.position = g.visits.papers[0].node.position
		g.interact()
	g.player.position = Vector3(-8, .2, 4.5)
	g.interact()
	check("Full route reaches taxi dialogue", g.stage == "taxi" and g.state == "dialogue" and g.world.moving_taxi)

	var invalid_save = FileAccess.open("res://save/checkpoint.json", FileAccess.WRITE)
	invalid_save.store_string("invalid")
	invalid_save.close()
	g.continue_saved()
	check("Invalid save begins in void", g.stage == "void" and g.state == "cutscene")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://save/checkpoint.json"))
	g.continue_saved()
	check("Missing save begins in void", g.stage == "void" and g.state == "cutscene")
	g.test_mode = true
	g.void_sequence.finish()
	g.checkpoint = "void"
	g.retry_checkpoint()
	await get_tree().create_timer(0.1).timeout
	check("Void checkpoint restarts without replaying briefing", g.stage == "void" and g.player.position.z > 10 and g.state == "play")
	g.to_menu()
	await get_tree().process_frame
	check("Menu restored without void overlay", g.stage == "menu" and not g.void_hud.visible)
	g.test_mode = false
	g.save_checkpoint("void")
	var file = FileAccess.open("res://save/checkpoint.json", FileAccess.READ)
	var saved = JSON.parse_string(file.get_as_text()) if file else {}
	check("Void checkpoint persisted", saved.get("stage", "") == "void")
	g.test_mode = true
	g.continue_saved()
	await get_tree().process_frame
	check("Continue restores playable void", g.stage == "void" and g.state == "play" and g.void_intro_seen)
	g.new_game()
	check("New game resets arrival dialogue", not g.home_arrival_seen)
	check("New game replays Michael briefing", g.stage == "void" and g.state == "cutscene" and not g.void_intro_seen)
	g.to_menu()
	await get_tree().create_timer(0.2).timeout
	check("Exiting cinematic keeps menu control", g.stage == "menu" and g.state == "menu" and not g.void_hud.visible)
	var output = FileAccess.open("res://tests/void_results.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"results": results, "walk_seconds": elapsed, "rendered": capture}, "\t"))
	if had_checkpoint:
		var restored = FileAccess.open(checkpoint_path, FileAccess.WRITE)
		restored.store_buffer(original_checkpoint)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(checkpoint_path))
	var failed = results.filter(func(r): return not r.passed).size()
	print("VOID_CHECKS_COMPLETE failures=" + str(failed))
	get_tree().quit(1 if failed > 0 else 0)
