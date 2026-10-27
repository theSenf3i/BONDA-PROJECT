extends Node3D

var w: Node3D

func build(world: Node3D) -> void:
	w = world
	var rng = RandomNumberGenerator.new()
	rng.seed = 6300
	for i in range(52):
		var x = rng.randf_range(-52, 52)
		var z = rng.randf_range(-3.6, 3.6)
		var crack = w.box(self, Vector3(x, .027, z), Vector3(rng.randf_range(.25, 1.5), .006, .035), Color("272d2d"))
		crack.rotation.y = rng.randf_range(-1, 1)
	for x in [-37, -21, -4, 12, 36]:
		var puddle = w.orb(self, Vector3(x, .04, -3.3), Vector3(2.6, .015, .85), Color("35474a"))
		puddle.material_override = w.material(Color("35474a"))
	for x in range(-44, 45, 11):
		for side in [-1, 1]:
			if side < 0 and x == 22:
				continue
			var z = side * 8.7
			for offset in [-2.4, 2.4]:
				var plank = w.box(self, Vector3(x + offset, 2.1, z), Vector3(1.8, .18, .10), Color("4d4540"))
				plank.rotation.z = -.24 if side == 1 else .3
			for i in range(3):
				w.box(self, Vector3(x + rng.randf_range(-3,3), rng.randf_range(.4,3.5), z), Vector3(rng.randf_range(.2,.65), rng.randf_range(.3,.8), .02), Color("48504a"))
		w.box(self, Vector3(x + 4, .32, 7.5), Vector3(.7, .65, .65), Color("303b38"), true)
	for x in [-45, -20, 5, 30, 55]:
		for i in range(8):
			var offset = float(i) * 3.125
			var y = 6.5 - sin(float(i) / 8.0 * PI) * .7
			var wire = w.box(self, Vector3(x + offset, y, -7), Vector3(3.25, .035, .035), Color("1d292b"))
			wire.rotation.z = -cos(float(i) / 8.0 * PI) * .09
	var sign = w.box(self, Vector3(-8, 3.2, 6.6), Vector3(2.2, .65, .1), Color("202c2b"))
	var text = w.text3(sign, "TÁXI", Vector3(0, 0, .08), 42, Color("d9bb75"))
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
