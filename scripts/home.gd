extends Node3D

var w: Node3D
var tasks: Array = []
var completed: Array = []

func build(world: Node3D) -> void:
	w = world
	w.box(self, Vector3(0,-.2,0), Vector3(12,.4,11), Color("625d50"), true, "tile")
	w.box(self, Vector3(0,4.3,0), Vector3(12,.2,11), Color("827963"))
	w.box(self, Vector3(0,2.1,-5.4), Vector3(12,4.2,.25), Color("9c9a79"), true, "plaster")
	for x in [-5.9,5.9]:
		w.box(self, Vector3(x,2.1,0), Vector3(.25,4.2,11), Color("a09c7d"), true, "plaster")
	for x in [-3.5,3.5]:
		w.box(self, Vector3(x,2.1,5.4), Vector3(5,4.2,.25), Color("939176"), true, "plaster")
	w.box(self, Vector3(0,3.5,5.4), Vector3(2,1.4,.25), Color("939176"), true)
	w.box(self, Vector3(0,1.4,5.5), Vector3(1.8,2.8,.1), Color("594f3b"))
	var rng = RandomNumberGenerator.new()
	rng.seed = 4016
	for i in range(70):
		var side = i % 3
		var pos = Vector3(rng.randf_range(-5.5,5.5),rng.randf_range(.15,3.9),-5.25)
		var size = Vector3(rng.randf_range(.12,1.1),rng.randf_range(.08,.55),.018)
		if side != 0:
			pos = Vector3(-5.75 if side == 1 else 5.75,pos.y,rng.randf_range(-5,5))
			size = Vector3(.018,size.y,size.x)
		w.box(self,pos,size,Color("696c55") if i % 3 == 0 else Color("c6bba0"))
	for i in range(24):
		w.box(self,Vector3(rng.randf_range(-5.5,5.5),.008,rng.randf_range(-5,5)),Vector3(rng.randf_range(.1,.6),.012,.035),Color("46463d"))
	w.box(self,Vector3(-2,2.7,-5.21),Vector3(2,1.3,.14),Color("453e32"))
	w.box(self,Vector3(-2,2.7,-5.12),Vector3(1.8,1.1,.06),Color("779084"))
	for x in [-2.6,-2,-1.4]:
		w.box(self,Vector3(x,2.7,-5.06),Vector3(.04,1.15,.05),Color("302f29"))
	w.box(self,Vector3(.5,2.4,-5.19),Vector3(2.7,.95,.12),Color("5a3826"))
	w.box(self,Vector3(.5,2.4,-5.11),Vector3(2.53,.78,.06),Color("ded2a6"))
	var note = w.text3(self,"Consulta hoje as 16:00",Vector3(.5,2.4,-5.06),35,Color("302a24"))
	note.pixel_size = .005
	note.outline_size = 0
	note.name = "AppointmentBoard"
	var mattress = w.box(self,Vector3(-4.5,.18,-3.5),Vector3(2.2,.36,3.2),Color("b3a47e"),true)
	w.box(self,Vector3(-4.5,.42,-4.55),Vector3(1.5,.2,.6),Color("bfb491"))
	var bed = task("mattress","Arrumar o colchão",Vector3(-3.2,0,-3))
	for i in range(10):
		w.orb(bed,Vector3(rng.randf_range(-2.15,-.4),.365,rng.randf_range(-1.9,.8)),Vector3(.35,.012,.5),Color("6c6040"))
	bed.set_meta("surface",mattress)
	var table = w.box(self,Vector3(-3.5,.92,1),Vector3(1.8,.13,1.4),Color("a12c23"),true)
	for x in [-4.2,-2.8]:
		for z in [.5,1.5]:
			w.box(self,Vector3(x,.45,z),Vector3(.1,.9,.1),Color("8d2921"),true)
	w.box(self,Vector3(-3.5,1.5,1),Vector3(1.22,1.05,.85),Color("292d29"),true)
	w.box(self,Vector3(-3.5,1.53,1.45),Vector3(.98,.76,.08),Color("3a605b"))
	for i in range(20):
		w.box(self,Vector3(-3.5,1.2+i*.033,1.496),Vector3(.9,.01,.007),Color("739484") if i % 3 == 0 else Color("35463f"))
	for x in [-3.7,-3.3]:
		var antenna = w.cylinder(self,Vector3(x,2.35,1),.018,.65,Color("6d756b"))
		antenna.rotation.z = -.45 if x < -3.5 else .45
	var dust = task("table","Limpar a mesa",Vector3(-2.25,0,1.2))
	w.box(dust,Vector3(-1.2,1,.35),Vector3(1.3,.014,.2),Color("7c684d"))
	dust.set_meta("surface",table)
	var chair = Node3D.new()
	add_child(chair)
	chair.position = Vector3(-3.5,0,2.8)
	chair.rotation.y = .25
	w.box(chair,Vector3(0,.55,0),Vector3(.72,.12,.72),Color("a33225"),true)
	w.box(chair,Vector3(0,1,.3),Vector3(.72,.8,.09),Color("a33225"),true)
	for x in [-.28,.28]:
		for z in [-.28,.28]:
			w.box(chair,Vector3(x,.26,z),Vector3(.07,.52,.07),Color("8c2b22"))
	var clothing = task("chair","Arrumar a cadeira",Vector3(-2.3,0,2.8))
	w.box(clothing,Vector3(-1.2,.65,0),Vector3(.65,.12,.6),Color("575560"))
	clothing.set_meta("chair",chair)
	w.box(self,Vector3(4.7,.65,-4.55),Vector3(.9,1.25,.5),Color("b6b599"),true)
	w.cylinder(self,Vector3(4.7,.23,-3.95),.33,.46,Color("b6b599"))
	w.orb(self,Vector3(4.7,.52,-3.9),Vector3(1.04,.62,1.3),Color("c2c0a2"))
	w.box(self,Vector3(4.7,.3,-3.9),Vector3(.8,.6,1),Color("a9a88f"),true)
	w.orb(self,Vector3(4.7,.8,-3.9),Vector3(.73,.025,.96),Color("494a35"))
	var rim = MeshInstance3D.new()
	var ring = TorusMesh.new()
	ring.inner_radius = .29
	ring.outer_radius = .42
	ring.rings = 24
	ring.ring_segments = 12
	rim.mesh = ring
	rim.material_override = w.material(Color("d2ceb1"))
	add_child(rim)
	rim.position = Vector3(4.7,.8,-3.9)
	rim.scale.z = 1.3
	var toilet = task("toilet","Limpar o vaso",Vector3(3.5,0,-3.7))
	for i in range(8):
		w.orb(toilet,Vector3(1.2+rng.randf_range(-.3,.3),.82,-.2+rng.randf_range(-.45,.45)),Vector3(.12,.02,.19),Color("64532b"))
	w.cylinder(self,Vector3(3.4,.25,-4.8),.26,.5,Color("626b58"))
	w.cylinder(self,Vector3(3.4,.52,-4.8),.28,.05,Color("858973"))
	w.cylinder(self,Vector3(3.4,.7,-4.8),.16,.3,Color("e2ddc4"))
	w.cylinder(self,Vector3(3.4,.855,-4.8),.065,.01,Color("71634e"))
	w.box(self,Vector3(4.8,.55,-.9),Vector3(1.65,1.1,2.8),Color("686d5b"),true)
	w.box(self,Vector3(4.8,1.13,-.9),Vector3(1.8,.12,2.9),Color("aaa994"))
	w.box(self,Vector3(4.8,1.2,-1.35),Vector3(1.25,.05,1.2),Color("414b44"))
	for x in [4.13,5.47]:
		w.box(self,Vector3(x,1.24,-1.35),Vector3(.09,.1,1.35),Color("9fa899"))
	w.cylinder(self,Vector3(5.35,1.5,-1.4),.045,.55,Color("9ba999"))
	w.box(self,Vector3(5.15,1.75,-1.4),Vector3(.45,.07,.07),Color("9ba999"))
	var dishes = task("sink","Lavar a louça e limpar a pia",Vector3(3.4,0,-1))
	for i in range(12):
		var plate = w.cylinder(dishes,Vector3(1.2+rng.randf_range(-.3,.3),1.27+i*.035,-.35+rng.randf_range(-.3,.3)),.32,.035,Color("c8c3a5"))
		plate.rotation.z = rng.randf_range(-.15,.15)
		w.orb(dishes,plate.position+Vector3(0,.023,0),Vector3(.3,.015,.24),Color("6c713c"))
	for i in range(6):
		w.orb(dishes,Vector3(rng.randf_range(.6,1.8),1.2,rng.randf_range(.3,1.2)),Vector3(.24,.015,.32),Color("4b5734"))
	var points = [Vector3(-1,0,-3.8),Vector3(1.9,0,-3.6),Vector3(-2.3,0,-.8),Vector3(.3,0,-1.9),Vector3(2.7,0,.8),Vector3(4.6,0,2.4),Vector3(3,0,3.6),Vector3(1.4,0,2.2),Vector3(-.7,0,2.6),Vector3(-4.9,0,.1),Vector3(-4.7,0,4),Vector3(-2,0,4.3)]
	for i in range(points.size()):
		var rubbish = task("trash_%02d" % i,"Recolher latas e lixo",points[i])
		for j in range(3):
			var pos = Vector3(rng.randf_range(-.38,.38),.13,rng.randf_range(-.35,.35))
			if j < 2:
				var can = Node3D.new()
				rubbish.add_child(can)
				can.position = pos
				can.rotation = Vector3(0,rng.randf_range(-PI,PI),1.2 if (i+j) % 2 == 0 else 0)
				w.cylinder(can,Vector3.ZERO,.11,.3,Color("d8b729") if j == 0 else Color("181e1c"))
				w.cylinder(can,Vector3(0,.155,0),.105,.012,Color("a7ada7"))
				var logo = w.text3(can,"SKOL" if j == 0 else "MONSTER",Vector3(0,0,.112),26,Color("ab251d") if j == 0 else Color("7fbe36"))
				logo.pixel_size = .0015
				logo.outline_size = 0
			else:
				var paper = w.box(rubbish,pos*Vector3(1,.15,1),Vector3(.38,.025,.26),Color("a89e78"))
				paper.rotation.y = rng.randf_range(-PI,PI)
	var lamp = OmniLight3D.new()
	add_child(lamp)
	lamp.position = Vector3(0,3.5,0)
	lamp.light_color = Color("e7ce86")
	lamp.light_energy = .7
	lamp.omni_range = 10
	w.cylinder(self,Vector3(0,3.92,0),.025,.7,Color("302e26"))
	w.orb(self,Vector3(0,3.55,0),Vector3(.2,.3,.2),Color("f0db9d"))

func task(id: String, title: String, pos: Vector3) -> Node3D:
	var node = Node3D.new()
	add_child(node)
	node.position = pos
	tasks.append({"id":id,"title":title,"node":node})
	return node

func nearest(pos: Vector3) -> Dictionary:
	var result: Dictionary = {}
	var distance = 1.5
	for item in tasks:
		if item.id in completed:
			continue
		var d = Vector2(pos.x-item.node.position.x,pos.z-item.node.position.z).length()
		if d < distance:
			distance = d
			result = item
	return result

func restore(ids: Array) -> void:
	for id in ids:
		clean(str(id))

func clean(id: String) -> bool:
	if id in completed:
		return false
	for item in tasks:
		if item.id == id:
			completed.append(id)
			item.node.hide()
			if item.node.has_meta("surface"):
				item.node.get_meta("surface").material_override = w.material(Color("d0c4a4") if id == "mattress" else Color("b52b20"))
			if item.node.has_meta("chair"):
				item.node.get_meta("chair").rotation.y = 0
			return true
	return false
