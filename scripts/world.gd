extends Node3D

signal car_hit

var pedestrian: CharacterBody3D
var previous_pedestrian = Vector3.ZERO
var traffic_enabled = false
var pedestrians_paused = false
var materials: Dictionary = {}
var actors: Array = []
var cars: Array = []
var taxi: Node3D
var portal: Node3D
var scene_kind = ""
var home: Node3D
var clock = 0.0
var moving_taxi = false
var taxi_origin = Vector3.ZERO
var taxi_progress = 0.0

func material(color: Color, texture_name: String = "", emission: float = 0.0) -> StandardMaterial3D:
	var key = str(color) + texture_name + str(emission)
	if materials.has(key):
		return materials[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	if texture_name != "":
		m.albedo_texture = load("res://assets/textures/" + texture_name + ".png")
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.65
	if emission > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	materials[key] = m
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid: bool = false, texture_name: String = "") -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var shape = BoxMesh.new()
	shape.size = size
	node.mesh = shape
	node.material_override = material(color, texture_name)
	parent.add_child(node)
	node.position = pos
	if solid:
		var body = StaticBody3D.new()
		var collision = CollisionShape3D.new()
		var volume = BoxShape3D.new()
		volume.size = size
		collision.shape = volume
		body.add_child(collision)
		node.add_child(body)
	return node

func profile_mesh(parent: Node3D, profile: Array, width: float, color: Color) -> MeshInstance3D:
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices: Array[Vector3] = []
	for z in [-width / 2, width / 2]:
		for point in profile:
			vertices.append(Vector3(point.x, point.y, z))
	var count = profile.size()
	for side in [0, 1]:
		for i in range(1, count - 1):
			var triangle = [side * count, side * count + i, side * count + i + 1]
			if side == 1:
				triangle.reverse()
			for index in triangle:
				tool.add_vertex(vertices[index])
	for i in range(count):
		var next = (i + 1) % count
		for index in [i, next + count, next, i, i + count, next + count]:
			tool.add_vertex(vertices[index])
	tool.generate_normals()
	var instance = MeshInstance3D.new()
	instance.mesh = tool.commit()
	instance.material_override = material(color)
	parent.add_child(instance)
	return instance

func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, top: float = -1) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var shape = CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = radius if top < 0 else top
	shape.height = height
	shape.radial_segments = 10
	node.mesh = shape
	node.material_override = material(color)
	parent.add_child(node)
	node.position = pos
	return node

func orb(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var shape = SphereMesh.new()
	shape.radial_segments = 9
	shape.rings = 5
	node.mesh = shape
	node.scale = size
	node.material_override = material(color)
	parent.add_child(node)
	node.position = pos
	return node

func text3(parent: Node3D, text: String, pos: Vector3, size: int = 48, tint: Color = Color("fff0c9")) -> Label3D:
	var node = Label3D.new()
	node.text = text
	node.font_size = size
	node.pixel_size = 0.008
	node.modulate = tint
	node.outline_size = 4
	node.outline_modulate = Color("302a35")
	parent.add_child(node)
	node.position = pos
	return node

func actor(kind: String, pos: Vector3, angle: float = 0.0) -> Node3D:
	var a = load("res://scripts/actor.gd").new()
	add_child(a)
	a.setup(kind)
	a.position = pos
	a.rotation.y = angle
	actors.append(a)
	return a

func build(kind: String) -> void:
	scene_kind = kind
	if kind in ["home", "clinic"]:
		interior(kind)
	elif kind in ["neighborhood", "taxi", "clinic_street"]:
		neighborhood()
	elif kind == "restaurant":
		restaurant()
	else:
		parking()

func environment(parent: Node3D) -> void:
	var world_env = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("596378")
	sky_mat.sky_horizon_color = Color("edb493")
	sky_mat.ground_bottom_color = Color("554552")
	sky_mat.ground_horizon_color = Color("edb493")
	sky_mat.sun_angle_max = 7.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c8bac8")
	env.ambient_light_energy = 0.32
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("bd9394")
	env.fog_density = 0.0035
	world_env.environment = env
	parent.add_child(world_env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -35, 0)
	sun.light_color = Color("ffd4a2")
	sun.light_energy = 0.72
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65
	parent.add_child(sun)

func building(pos: Vector3, color: Color, title: String, face: float = 0, width: float = 8) -> Node3D:
	var b = Node3D.new()
	add_child(b)
	b.position = pos
	b.rotation.y = face
	box(b, Vector3(0, 2, 0), Vector3(width, 4, 6), color, true, "plaster")
	box(b, Vector3(0, .35, 3.06), Vector3(width + .1, .6, .18), color.darkened(.25), false, "brick")
	var roof = MeshInstance3D.new()
	var prism = PrismMesh.new()
	prism.size = Vector3(width + .8, 1.6, 6.7)
	roof.mesh = prism
	roof.material_override = material(Color("965749"), "roof")
	b.add_child(roof)
	roof.position.y = 4.65
	box(b, Vector3(0, 1.15, 3.07), Vector3(1.2, 2.3, .15), Color("51464b"))
	box(b, Vector3(.42, 1.12, 3.18), Vector3(.09, .09, .08), Color("e0bc68"))
	for x in [-width * .3, width * .3]:
		box(b, Vector3(x, 2.2, 3.12), Vector3(1.65, 1.5, .14), Color("e6ceab"))
		box(b, Vector3(x, 2.2, 3.21), Vector3(1.38, 1.25, .08), Color("40616a"))
		box(b, Vector3(x, 2.2, 3.27), Vector3(.06, 1.3, .05), Color("b7b5a4"))
		box(b, Vector3(x, 2.2, 3.27), Vector3(1.4, .06, .05), Color("b7b5a4"))
	if title != "":
		box(b, Vector3(0, 3.5, 3.17), Vector3(width * .85, .75, .16), Color("34434e"))
		text3(b, title, Vector3(0, 3.5, 3.28), 36)
	return b

func tree(pos: Vector3) -> void:
	cylinder(self, pos + Vector3(0, 1.3, 0), .22, 2.6, Color("695348"), .14)
	box(self, pos + Vector3(0, .2, 0), Vector3(.5, .4, .5), Color("695348"), true)
	orb(self, pos + Vector3(-.5, 3.1, 0), Vector3(3, 2.6, 2.8), Color("666d47"))
	orb(self, pos + Vector3(.6, 3.5, .3), Vector3(2.4, 2.4, 2.2), Color("7f8553"))

func bench(pos: Vector3, rotation_y: float = 0) -> void:
	var b = Node3D.new()
	add_child(b)
	b.position = pos
	b.rotation.y = rotation_y
	for z in [-.18, .02, .22]:
		box(b, Vector3(0, .55, z), Vector3(2.1, .1, .15), Color("95704f"), false, "wood")
	for y in [.9, 1.15]:
		box(b, Vector3(0, y, .3), Vector3(2.1, .16, .1), Color("95704f"), false, "wood")
	for x in [-.8, .8]:
		box(b, Vector3(x, .32, 0), Vector3(.1, .55, .5), Color("414449"), true)

func lamp(pos: Vector3) -> void:
	cylinder(self, pos + Vector3(0, 2.5, 0), .07, 5.0, Color("514950"))
	box(self, pos + Vector3(.35, 4.9, 0), Vector3(.8, .1, .12), Color("514950"))
	var bulb = orb(self, pos + Vector3(.65, 4.85, 0), Vector3(.5, .17, .3), Color("ffe6a9"))
	bulb.material_override = material(Color("ffe6a9"), "", 1.2)
	var light = OmniLight3D.new()
	add_child(light)
	light.position = pos + Vector3(.65, 4.4, 0)
	light.light_color = Color("ffd092")
	light.omni_range = 7
	light.light_energy = .8

func car(pos: Vector3, color: Color, is_taxi: bool = false) -> Node3D:
	var c = Node3D.new()
	add_child(c)
	c.position = pos
	profile_mesh(c, [Vector2(-1.9, .35), Vector2(1.85, .35), Vector2(1.95, .65), Vector2(1.6, .89), Vector2(.9, .93), Vector2(-1.45, .88), Vector2(-1.9, .72)], 1.6, color)
	profile_mesh(c, [Vector2(-1.3, .88), Vector2(1, .92), Vector2(.44, 1.55), Vector2(-.75, 1.55)], 1.42, color)
	var window_profile = [Vector2(-1.16, 1.0), Vector2(.82, 1.02), Vector2(.38, 1.47), Vector2(-.69, 1.47)]
	profile_mesh(c, window_profile, 1.435, Color("354b5b"))
	var windshield = box(c, Vector3(.72, 1.24, 0), Vector3(.04, .7, 1.25), Color("597784"))
	windshield.rotation.z = .72
	var rear_window = box(c, Vector3(-1.02, 1.22, 0), Vector3(.04, .65, 1.25), Color("354b5b"))
	rear_window.rotation.z = -.66
	box(c, Vector3(0, 1.25, .76), Vector3(.08, .5, .05), color)
	box(c, Vector3(0, 1.25, -.76), Vector3(.08, .5, .05), color)
	for z in [-.82, .82]:
		box(c, Vector3(-.25, .85, z), Vector3(.28, .045, .03), Color("c4c1ac"))
		box(c, Vector3(.55, 1.03, z * 1.13), Vector3(.2, .12, .18), color)
	for x in [-1.1, 1.15]:
		for z in [-.83, .83]:
			var wheel = cylinder(c, Vector3(x, .4, z), .36, .18, Color("292930"))
			wheel.rotation.x = PI / 2
			var hub = cylinder(c, Vector3(x, .4, z * 1.1), .17, .02, Color("b2aaa0"))
			hub.rotation.x = PI / 2
	for z in [-.55, .55]:
		box(c, Vector3(1.86, .73, z), Vector3(.02, .24, .32), Color("ffdd9e"))
		box(c, Vector3(-1.86, .73, z), Vector3(.02, .24, .32), Color("b84c42"))
	box(c, Vector3(1.9, .42, 0), Vector3(.1, .17, 1.5), Color("b6b4a6"))
	if is_taxi:
		box(c, Vector3(0, 1.69, 0), Vector3(.7, .27, .38), Color("f1e8c9"))
		text3(c, "TÁXI", Vector3(0, 1.69, .21), 23, Color("292b39"))
	return c

func fence(pos: Vector3, length: float) -> void:
	box(self, pos + Vector3(0, .65, 0), Vector3(length, 1.3, .12), Color("967359"), true, "wood")
	for i in range(int(length / .5) + 1):
		box(self, pos + Vector3(i * .5 - length / 2, .73, .04), Vector3(.08, 1.5, .14), Color("725b4f"))

func neighborhood() -> void:
	box(self, Vector3(0, -.27, 0), Vector3(120, .5, 72), Color("8d9164"), true, "grass")
	box(self, Vector3(0, .005, 0), Vector3(114, .03, 8), Color("6b6570"), false, "asphalt")
	for side in [-1, 1]:
		box(self, Vector3(0, .08, side * 5.6), Vector3(112, .16, 3.2), Color("b7aaa1"), true, "pavement")
		box(self, Vector3(0, .09, side * 4.08), Vector3(113, .2, .17), Color("e2d0b5"))
	for x in range(-52, 54, 5):
		box(self, Vector3(x, .035, 0), Vector3(2.4, .015, .12), Color("ead29c"))
	for x in [-26, 22]:
		for z in range(-3, 4):
			box(self, Vector3(x, .04, z), Vector3(2, .015, .5), Color("dfd5bb"))
	var palette = [Color("b69275"), Color("7a9390"), Color("c1a16f"), Color("997f8d"), Color("b47f69")]
	for i in range(9):
		var x = -44.0 + i * 11.0
		var title = ""
		if i == 2:
			title = "CASA  •  03"
		if i == 5:
			title = "BAR DO ZÉ"
		var house = building(Vector3(x, 0, 12), palette[i % 5], title, PI)
		if i in [0, 4, 7]:
			box(house, Vector3(0, 5.6, 0), Vector3(6.9, 3, 5.8), palette[i % 5], true, "plaster")
			box(house, Vector3(0, 7.15, 0), Vector3(7.3, .2, 6.1), Color("dad2b7"))
			for wx in [-1.8, 1.8]:
				box(house, Vector3(wx, 5.8, 2.95), Vector3(1.4, 1.3, .1), Color("617d80"))
		if i != 6:
			building(Vector3(x, 0, -12), palette[(i + 2) % 5], "MERCEARIA" if i == 3 else "")
		if i % 2 == 0:
			tree(Vector3(x + 4.7, 0, 7.5))
			lamp(Vector3(x - 3, 0, -5.8))
	building(Vector3(22, 0, -12), Color("b9d0c6"), "CLÍNICA DOUGLAS", 0, 9)
	for x in [-39, -18, 4, 17, 28]:
		cylinder(self, Vector3(x, .4, -7.2), .32, .6, Color("a57357"), .4)
		orb(self, Vector3(x, 1, -7.2), Vector3(.9, 1.2, .9), Color("6e8759"))
	for i in range(8):
		box(self, Vector3(-11 + i * .5, 3.3, -8), Vector3(.5, .12, 2.1), Color("9c534e") if i % 2 else Color("d9c6a4"))
	text3(self, "+", Vector3(22, 5.65, -8.7), 120, Color("a8d7c9"))
	bench(Vector3(-15, .16, 6.2), PI)
	bench(Vector3(27, .16, -6.1))
	fence(Vector3(-33, 0, 8), 8)
	for x in range(-48, 54, 24):
		cylinder(self, Vector3(x, 3.5, -7), .12, 7, Color("756e67"))
		box(self, Vector3(x + 12, 6.6, -7), Vector3(24, .025, .025), Color("34343c"))
	taxi = car(Vector3(-8, 0, 2.6), Color("d9ad53"), true)
	text3(self, "PONTO DE TÁXI", Vector3(-8, 2.4, 5.8), 28)
	for i in range(5):
		var c = car(Vector3(-45 + 19 * i, 0, -2.2 if i % 2 else 1.5), palette[i])
		if i % 2:
			c.rotation.y = PI
		cars.append({"node": c, "speed": 4.0 + i, "dir": -1 if i % 2 else 1})
	var roster = load("res://scripts/neighbors.gd").ROSTER
	for i in range(roster.size()):
		var entry = roster[i]
		var a = actor(entry.model, Vector3(entry.x, .17, entry.z))
		a.set_meta("origin", a.position)
		a.set_meta("walk", true)
		a.set_meta("npc_id", i)
		a.set_meta("identity", entry.id)
		a.set_meta("display_name", entry.name)
		a.set_meta("span", entry.span)
		a.set_meta("direction", 1.0 if i % 2 == 0 else -1.0)
		a.set_meta("wait", float(i) * .17)
		a.gesture = entry.gesture
		if i >= 3:
			a.tint_clothes([Color("a17360"), Color("667e87"), Color("a48b58"), Color("7a6985")][i % 4])
		var tag = text3(a, entry.name, Vector3(0, 2.3, 0), 20)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.visibility_range_end = 12
	for x in [-58, 58]:
		box(self, Vector3(x, 3, 0), Vector3(1, 6, 70), Color("897e7d"), true, "brick")
	for z in [-28, 28]:
		box(self, Vector3(0, 3, z), Vector3(116, 6, 1), Color("897e7d"), true, "brick")

func interior(kind: String) -> void:
	if kind == "home":
		home = load("res://scripts/home.gd").new()
		add_child(home)
		home.build(self)
		return
	var clinic = kind == "clinic"
	box(self, Vector3(0, -.2, 0), Vector3(12, .4, 11), Color("b6aaa0"), true, "tile" if clinic else "wood")
	var wall = Color("aebeb4") if clinic else Color("bb9b81")
	box(self, Vector3(0, 4.3, 0), Vector3(12, .2, 11), Color("c5b9a7"))
	box(self, Vector3(0, 2.1, -5.4), Vector3(12, 4.2, .25), wall, true, "plaster")
	for x in [-5.9, 5.9]:
		box(self, Vector3(x, 2.1, 0), Vector3(.25, 4.2, 11), wall, true, "plaster")
	box(self, Vector3(-3.5, 2.1, 5.4), Vector3(5, 4.2, .25), wall, true)
	box(self, Vector3(3.5, 2.1, 5.4), Vector3(5, 4.2, .25), wall, true)
	box(self, Vector3(0, 3.5, 5.4), Vector3(2, 1.4, .25), wall, true)
	box(self, Vector3(0, 1.4, 5.5), Vector3(1.8, 2.8, .1), Color("5e716e"))
	text3(self, "SAÍDA", Vector3(0, 3, 5.2), 28).rotation.y = PI
	box(self, Vector3(-3, 2.3, -5.2), Vector3(2.6, 1.8, .15), Color("e4cfad"))
	box(self, Vector3(-3, 2.3, -5.09), Vector3(2.3, 1.5, .1), Color("718994"))
	box(self, Vector3(-3, 2.3, -5), Vector3(.05, 1.5, .05), Color("ead8b8"))
	if clinic:
		box(self, Vector3(2.5, .85, -1.9), Vector3(1.35, .2, 2.6), Color("e1dfc6"), true)
		box(self, Vector3(2.5, 1.02, -1.9), Vector3(1.25, .17, 2.45), Color("608981"))
		box(self, Vector3(2.5, 1.18, -2.8), Vector3(.95, .22, .5), Color("deded0"))
		for x in [2.05, 2.95]:
			for z in [-2.7, -.9]:
				cylinder(self, Vector3(x, .43, z), .04, .8, Color("bec2b9"))
		box(self, Vector3(-2.3, .8, -2), Vector3(2.8, .15, 1.2), Color("8e725c"), true, "wood")
		for x in [-3.4, -1.2]:
			for z in [-2.4, -1.6]:
				box(self, Vector3(x, .4, z), Vector3(.09, .75, .09), Color("5f5148"))
		box(self, Vector3(-2.3, 1.25, -2.25), Vector3(.8, .6, .09), Color("39424b"))
		text3(self, "DR. DOUGLAS\nUROLOGIA", Vector3(.5, 2.7, -5.17), 40)
		bench(Vector3(-4.8, 0, 2), PI / 2)
		actor("douglas", Vector3(.2, 0, -1.7), PI)
	else:
		box(self, Vector3(-3, .4, -2), Vector3(2.3, .8, 3.4), Color("6b5360"), true)
		box(self, Vector3(-3, .86, -2), Vector3(2.2, .16, 3.3), Color("a39599"))
		box(self, Vector3(-3, 1.03, -3.1), Vector3(1.8, .18, .7), Color("dfcbb4"))
		box(self, Vector3(3.5, 1.35, -3.5), Vector3(2.1, 2.7, 1.1), Color("715b50"), true, "wood")
		box(self, Vector3(2.8, .8, 1), Vector3(2.3, .15, 1.3), Color("836750"), true, "wood")
		for x in [1.8, 3.8]:
			for z in [.5, 1.5]:
				box(self, Vector3(x, .4, z), Vector3(.1, .75, .1), Color("5f5148"))
		box(self, Vector3(2.8, 1, 1), Vector3(.45, .04, .6), Color("e2d7bf"))
		text3(self, "CONSULTA\nHOJE • 16:00", Vector3(2.8, 1.45, 1), 24).billboard = BaseMaterial3D.BILLBOARD_ENABLED
		text3(self, "OUTRA DIMENSÃO.\nO MESMO AZAR.", Vector3(.7, 2.6, -5.2), 34)
	var light = OmniLight3D.new()
	add_child(light)
	light.position = Vector3(0, 3.5, 0)
	light.omni_range = 10
	light.light_color = Color("ffe0ad")
	light.light_energy = .55

func restaurant() -> void:
	box(self, Vector3(0, -.2, 0), Vector3(36, .4, 30), Color("a59686"), true, "pavement")
	building(Vector3(0, 0, -10), Color("985f59"), "BISTRÔ  •  SÓ NÓS DOIS", 0, 19)
	box(self, Vector3(0, 3.5, -5.3), Vector3(20, .18, 4), Color("d0ac79"))
	for x in [-9, 9]:
		cylinder(self, Vector3(x, 1.7, -3.5), .08, 3.4, Color("665345"))
	for pos in [Vector3(-6, 0, -4), Vector3(6, 0, -4), Vector3(-7, 0, 3), Vector3(7, 0, 3)]:
		table(pos)
	tree(Vector3(-12, 0, 0))
	tree(Vector3(12, 0, 0))
	for x in [-10, 10]:
		lamp(Vector3(x, 0, 6))
	fence(Vector3(0, 0, 11), 30)
	box(self, Vector3(-15, 1, 0), Vector3(.4, 2, 22), Color("a27e60"), true, "brick")
	box(self, Vector3(15, 1, 0), Vector3(.4, 2, 22), Color("a27e60"), true, "brick")
	actor("douglas", Vector3(-2.7, 0, -3.5), PI)

func table(pos: Vector3) -> void:
	cylinder(self, pos + Vector3(0, .8, 0), .85, .12, Color("d3b887"))
	cylinder(self, pos + Vector3(0, .39, 0), .08, .75, Color("5a4b49"))
	for s in [-1, 1]:
		box(self, pos + Vector3(s * 1.25, .5, 0), Vector3(.55, .1, .6), Color("74584c"), true)
		box(self, pos + Vector3(s * 1.5, .9, 0), Vector3(.08, .8, .6), Color("74584c"))
	cylinder(self, pos + Vector3(0, 1.04, 0), .1, .35, Color("657d64"))
	orb(self, pos + Vector3(0, 1.3, 0), Vector3(.25, .3, .25), Color("d9868c"))

func parking() -> void:
	box(self, Vector3(0, -.22, 0), Vector3(30, .4, 34), Color("696574"), true, "asphalt")
	for x in [-9, 9]:
		box(self, Vector3(x, .12, 0), Vector3(.3, .25, 24), Color("d3bca5"), true)
		box(self, Vector3(x * 1.5, 1.2, 0), Vector3(.3, 2.4, 34), Color("907968"), true, "brick")
		for z in [-9, -3, 3, 9]:
			box(self, Vector3(x * 1.17, .01, z), Vector3(4, .04, .12), Color("d4c2a2"))
		lamp(Vector3(x * 1.25, 0, 5))
	for z in [-13, 13]:
		box(self, Vector3(0, 1.2, z), Vector3(27, 2.4, .4), Color("9e8270"), true, "brick")
	for x in [-11, 11]:
		car(Vector3(x, 0, -5), Color("5e7e80"))
		car(Vector3(x, 0, 7), Color("a6786a"))
	building(Vector3(0, 0, -19), Color("a87768"), "ESTACIONAMENTO", 0, 23)
	text3(self, "SAÍDA  →", Vector3(0, .05, 8), 70, Color("dfc890")).rotation.x = -PI / 2
	actor("ex", Vector3(0, 0, -10), PI)
	actor("douglas", Vector3(7, 0, 8), .4)

func create_portal(pos: Vector3) -> Node3D:
	portal = Node3D.new()
	add_child(portal)
	portal.position = pos
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 1.05
	torus.outer_radius = 1.25
	torus.rings = 32
	torus.ring_segments = 8
	ring.mesh = torus
	ring.rotation.x = PI / 2
	ring.position.y = 1.65
	ring.scale.y = 1.35
	ring.material_override = material(Color("bda0eb"), "", 2)
	portal.add_child(ring)
	orb(portal, Vector3(0, 1.65, 0), Vector3(2.1, 2.9, .12), Color("5d3f86"))
	text3(portal, "A PRÓXIMA DIMENSÃO", Vector3(0, 3.6, 0), 28)
	return portal

func _physics_process(dt: float) -> void:
	for entry in cars:
		var c: Node3D = entry.node
		var old_position = c.position
		c.position.x += entry.speed * entry.dir * dt
		if traffic_enabled and is_instance_valid(pedestrian):
			var bounds = AABB(Vector3(-2.16, -1.82, -1.04), Vector3(4.32, 3.42, 2.08))
			var contact = bounds.intersects_segment(previous_pedestrian - old_position, pedestrian.position - c.position)
			if contact != null:
				traffic_enabled = false
				car_hit.emit()
		if abs(c.position.x) > 55:
			c.position.x = -55 * entry.dir
	if is_instance_valid(pedestrian):
		previous_pedestrian = pedestrian.position
	for a in actors:
		if not a.get_meta("walk", false):
			continue
		if pedestrians_paused or a.pose == "talk":
			a.walk_speed = 0
			continue
		var wait: float = maxf(0, a.get_meta("wait", 0.0) - dt)
		a.set_meta("wait", wait)
		if wait > 0:
			a.walk_speed = 0
			continue
		var origin: Vector3 = a.get_meta("origin")
		var span: float = a.get_meta("span")
		var direction: float = a.get_meta("direction")
		var speed = .7 + float(a.get_meta("npc_id")) * .035
		a.position.x = clampf(a.position.x + direction * speed * dt, origin.x - span, origin.x + span)
		a.position.z = origin.z
		a.position.y = .17
		a.rotation.y = lerp_angle(a.rotation.y, -PI / 2 if direction > 0 else PI / 2, dt * 7)
		a.walk_speed = speed
		if absf(a.position.x - origin.x) >= span - .01:
			a.set_meta("direction", -direction)
			a.set_meta("wait", .8 + float(a.get_meta("npc_id")) * .1)

func _process(dt: float) -> void:
	clock += dt
	if moving_taxi and is_instance_valid(taxi):
		taxi_progress = minf(taxi_progress + dt * 1.0, 28.0)
		taxi.position.x = -8 + taxi_progress
	if is_instance_valid(portal):
		portal.rotation.y = sin(clock * .5) * .12
