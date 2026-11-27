extends RefCounted

## Original Compatibility-friendly toy meshes, reused without embellishment by
## gameplay, the opening, the cosmetic shelf, the gallery and frozen share art.

const Options := preload("res://games/yacomio/yacomio_options.gd")
const Detail := preload("res://scripts/miniature_detail.gd")
const INK := Color("263c39")
const SHELL := Color("f1ddba")


static func build(
	stage: int, upgrades: Array[String], membrane: String = Options.DEFAULT_MEMBRANE,
	habitat: String = Options.DEFAULT_HABITAT
) -> Node3D:
	var root := Node3D.new()
	root.name = "Colony"
	var body := _colour(membrane, Options.DEFAULT_MEMBRANE)
	var basin := _colour(habitat, Options.DEFAULT_HABITAT)
	_cylinder(root, Vector3(0, -0.18, 0), 2.8, 0.36, basin.darkened(0.35))
	_ring(root, Vector3(0, 0.015, 0), 2.7, 2.86, basin.lightened(0.4))
	var surface := _cylinder(root, Vector3(0, 0.01, 0), 2.66, 0.06,
		basin if stage < 3 else Color("759568"))
	if stage < 3:
		var dish := ShaderMaterial.new()
		dish.shader = preload("res://games/yacomio/assets/culture_dish.gdshader")
		dish.set_shader_parameter("medium", basin)
		surface.material_override = dish
		_slide_holder(root, basin)
	if stage == 0:
		_microbe(root, Vector3(0, 0.82, 0), 1.0, body, upgrades)
	elif stage == 1:
		_microbe(root, Vector3(-1.1, 0.6, 0.4), 0.65, body, upgrades)
		_garden(root, upgrades.has("algae"), upgrades.has("photoprotection"))
		var sun := Node3D.new()
		sun.name = "Sun"
		root.add_child(sun)
		_sphere(sun, Vector3(0.5, 2.45, -1.2), Vector3.ONE * 0.32, Color("f4d477"))
		for index in 8:
			var angle := TAU * index / 8.0
			var ray := Vector3(cos(angle), sin(angle), 0)
			_segment(sun, Vector3(0.5, 2.45, -1.2) + ray * 0.42,
				Vector3(0.5, 2.45, -1.2) + ray * 0.6, 0.035, Color("f4d477"))
	elif stage == 2:
		_microbe(root, Vector3(-1.7, 0.5, 0.6), 0.38, body, upgrades)
		if upgrades.has("sponge"):
			_sponges(root, Vector3(-0.9, 0, -0.5), body)
		if upgrades.has("jellyfish"):
			_jellyfish(root, Vector3(0, 1.5, 0.2), body.lightened(0.2),
				upgrades.has("nervous_system"))
		if upgrades.has("fish"):
			_fish(root, Vector3(1.25, 0.95, 0.45), body, 0.0)
			_fish(root, Vector3(0.8, 0.65, -1.1), body.lightened(0.25), PI)
		_garden(root, false, upgrades.has("photoprotection"))
	elif stage in [3, 4]:
		_island(root, upgrades)
		if stage == 3:
			if upgrades.has("dinosaurs"):
				_dinosaur(root, Vector3(0.45, 0.06, -0.15), body, upgrades.has("feathers"))
			if upgrades.has("mammals"):
				_mammal(root, Vector3(-0.8, 0.06, 0.8), body.darkened(0.2))
				_mammal(root, Vector3(0.7, 0.06, 1.2), body.lightened(0.15), 0.6)
			if upgrades.has("insects"):
				_insect(root, Vector3(1.55, 0.12, 0.7), body)
		else:
			_town(root, upgrades, body)
	else:
		push_error("YaComio: cannot build unknown era %d." % stage)
	return root


static func _slide_holder(root: Node3D, basin: Color) -> void:
	var mount := Detail.new()
	var ink := basin.darkened(0.52)
	mount.box(Vector3(0, -0.43, 0), Vector3(5.55, 0.19, 4.38), ink)
	for side: float in [-1, 1]:
		var latch := Vector3(side * 2.65, -0.19, 0)
		mount.box(latch, Vector3(0.59, 0.34, 1.24), basin.lightened(0.12))
		for rib in 3:
			mount.box(latch + Vector3(side * 0.19, 0.20, (rib - 1) * 0.30),
				Vector3(0.17, 0.07, 0.13), SHELL)
	mount.box(Vector3(-1.47, -0.43, 2.203), Vector3(1.71, 0.104, 0.032), SHELL)
	for bar in 7:
		mount.box(Vector3(-2.17 + bar * 0.17, -0.43, 2.227),
			Vector3(0.045 + (bar % 3) * 0.022, 0.080, 0.02), ink)
	var base := Vector3(-2.17, -0.35, -1.72)
	var elbow := base + Vector3(0, 1.97, 0)
	var nose := elbow + Vector3(0.87, 0.36, 0.10)
	mount.rod(base, elbow, 0.19, ink)
	mount.rod(elbow, nose, 0.20, ink)
	mount.rod(elbow + Vector3.FORWARD * 0.20, elbow + Vector3.BACK * 0.24, 0.43, basin)
	mount.rod(elbow + Vector3.BACK * 0.24, elbow + Vector3.BACK * 0.29, 0.24, SHELL)
	var tip := nose + Vector3(0.24, -0.65, 0.16)
	mount.rod(nose, tip, 0.27, SHELL)
	mount.rod(tip, tip + Vector3(0.056, -0.16, 0.039), 0.22, ink)
	mount.attach(root, "SpecimenCarrier")


static func bounds(root: Node3D, transform: Transform3D = Transform3D.IDENTITY) -> AABB:
	var box := AABB()
	var found := false
	if root is MeshInstance3D:
		var part := root as MeshInstance3D
		if part.mesh != null:
			box = transform * part.mesh.get_aabb()
			found = true
	for child in root.get_children():
		if child is not Node3D:
			continue
		var spatial := child as Node3D
		var child_box := bounds(spatial, transform * spatial.transform)
		if child_box.size == Vector3.ZERO:
			continue
		box = box.merge(child_box) if found else child_box
		found = true
	return box


static func _colour(id: String, fallback: String) -> Color:
	var item := Options.store_item(id)
	if item.is_empty():
		push_warning("YaComio: unknown cosmetic '%s'; showing the original look." % id)
		item = Options.store_item(fallback)
	return item["color"]


static func _part(parent: Node3D, mesh: Mesh, position: Vector3, colour: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.8
	part.mesh = mesh
	part.material_override = material
	part.position = position
	parent.add_child(part)
	return part


static func _sphere(parent: Node3D, position: Vector3, scale: Vector3, colour: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	_part(parent, mesh, position, colour).scale = scale


static func _cylinder(
	parent: Node3D, position: Vector3, radius: float, height: float, colour: Color,
	top_radius: float = -1.0
) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 20
	return _part(parent, mesh, position, colour)


static func _ring(parent: Node3D, position: Vector3, inner: float, outer: float, colour: Color) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 24
	mesh.ring_segments = 8
	_part(parent, mesh, position, colour)


static func _box(
	parent: Node3D, position: Vector3, size: Vector3, colour: Color
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _part(parent, mesh, position, colour)


static func _segment(
	parent: Node3D, start: Vector3, end: Vector3, radius: float, colour: Color
) -> void:
	var direction := end - start
	var part := _cylinder(parent, (start + end) * 0.5, radius, direction.length(), colour)
	part.basis = Basis(Quaternion(Vector3.UP, direction.normalized()))


static func _microbe(
	parent: Node3D, position: Vector3, size: float, colour: Color, upgrades: Array[String]
) -> void:
	var cell := Node3D.new()
	cell.name = "Microbe"
	cell.position = position
	cell.scale = Vector3.ONE * size
	parent.add_child(cell)
	_sphere(cell, Vector3.ZERO, Vector3(1.05, 0.65, 0.82), colour)
	_sphere(cell, Vector3(-0.2, 0.2, 0.69), Vector3(0.27, 0.24, 0.13), colour.darkened(0.4))
	var detail := Detail.new()
	# Large contrasting inclusions keep the cell legible on the colony shelf.
	detail.oval(Vector3(-0.23, 0.235, 0.808), Vector3(0.19, 0.15, 0.064), colour.darkened(0.62))
	detail.oval(Vector3(-0.26, 0.272, 0.839), Vector3(0.075, 0.048, 0.02), SHELL)
	for i in 4:
		var angle := 0.65 + i * 1.59
		detail.oval(Vector3(0.52 * cos(angle), 0.37 * sin(angle), 0.645),
			Vector3(0.19, 0.15, 0.10), colour.lightened(0.26))
	detail.attach(cell, "CellInclusions")
	for index in 10:
		var angle := TAU * index / 10.0
		var start := Vector3(cos(angle), 0.0, sin(angle) * 0.8)
		_segment(cell, start, start * 1.35 + Vector3(0, 0.12, 0), 0.045, colour.lightened(0.3))
	if upgrades.has("rna"):
		for index in 9:
			_sphere(cell, Vector3(-0.65 + index * 0.14, -0.2 + sin(index * 0.9) * 0.08, 0.8),
				Vector3.ONE * 0.065, Color("f0c36d"))
	if upgrades.has("dna"):
		for index in 8:
			var y := -0.4 + index * 0.115
			var x := sin(index * 0.85) * 0.13
			var left := Vector3(0.4 + x, y, 0.82)
			var right := Vector3(0.4 - x, y, 0.98)
			_sphere(cell, left, Vector3.ONE * 0.065, Color("f19296"))
			_sphere(cell, right, Vector3.ONE * 0.065, Color("8dbfea"))
			_segment(cell, left, right, 0.024, Color("edf5e6"))
	if upgrades.has("membrane"):
		_sphere(cell, Vector3(-1.15, -0.15, -0.55), Vector3(0.55, 0.45, 0.48), colour.lightened(0.12))
		_sphere(cell, Vector3(-1.2, -0.05, -0.12), Vector3.ONE * 0.14, colour.darkened(0.35))
	if upgrades.has("chloroplast"):
		for index in 4:
			_sphere(cell, Vector3(-0.55 + index * 0.32, 0.4, 0.58),
				Vector3(0.13, 0.06, 0.1), Color("397c4e"))
	Detail.ink_figure(cell)


static func _garden(parent: Node3D, full: bool, protected: bool) -> void:
	for index in (5 if full else 2):
		var x := -0.2 + index * 0.44
		var base := Vector3(x, 0.05, -0.95 - (index % 2) * 0.35)
		var height := 1.0 + (index % 3) * 0.25
		var colour := Color("9ab874") if protected else Color("73b971")
		_segment(parent, base, base + Vector3(0.08, height, 0), 0.05, colour.darkened(0.25))
		for leaf in 3:
			var spot := base + Vector3(0, 0.3 + leaf * 0.3, 0)
			_sphere(parent, spot + Vector3(-0.15, 0.05, 0),
				Vector3(0.23, 0.07, 0.12), colour)
			_sphere(parent, spot + Vector3(0.18, 0.16, 0),
				Vector3(0.25, 0.08, 0.13), colour.lightened(0.1))


static func _sponges(dish: Node3D, position: Vector3, colour: Color) -> void:
	var parent := _group(dish, "Sponges", position)
	var detail := Detail.new()
	for index in 3:
		var base := Vector3((index - 1) * 0.4, 0, (index % 2) * 0.3)
		var height := 0.7 + index * 0.2
		_cylinder(parent, base + Vector3(0, height * 0.5, 0), 0.23, height, colour)
		_ring(parent, base + Vector3(0, height, 0), 0.12, 0.24, colour.lightened(0.2))
		_cylinder(parent, base + Vector3(0, height + 0.005, 0), 0.12, 0.012, colour.darkened(0.6))
		for hole in 4:
			detail.oval(base + Vector3(0.07 * sin(hole * 2.0), 0.18 + hole * 0.12, 0.213),
				Vector3(0.15, 0.17, 0.046), colour.lightened(0.24))
			_sphere(parent, base + Vector3(0.07 * sin(hole * 2.0), 0.18 + hole * 0.12, 0.23),
				Vector3(0.055, 0.06, 0.015), colour.darkened(0.45))
	detail.attach(parent, "SpongePoreLips")
	Detail.ink_figure(parent)


static func _jellyfish(dish: Node3D, position: Vector3, colour: Color, nerves: bool) -> void:
	var parent := _group(dish, "Jellyfish", position)
	_sphere(parent, Vector3.ZERO, Vector3(0.55, 0.27, 0.5), colour)
	_cylinder(parent, Vector3(0, -0.12, 0), 0.48, 0.06, colour.darkened(0.12))
	var bell := Detail.new()
	for i in 12:
		var angle := i * TAU / 12
		bell.oval(Vector3(0.461 * cos(angle), -0.124, 0.427 * sin(angle)),
			Vector3(0.16, 0.12, 0.15), colour.lightened(0.18))
	bell.attach(parent, "ScallopedBell")
	for index in 5:
		var x := (index - 2) * 0.16
		var start := Vector3(x, -0.15, 0.1)
		for segment in 3:
			var end := start + Vector3(sin(index + segment) * 0.09, -0.2, 0.02)
			_segment(parent, start, end, 0.035, colour.lightened(0.15))
			start = end
		if nerves:
			_sphere(parent, Vector3(x, 0.03, 0.45),
				Vector3.ONE * 0.045, Color("eaaa86"))
	Detail.ink_figure(parent)


static func _fish(parent: Node3D, position: Vector3, colour: Color, yaw: float) -> void:
	var fish := Node3D.new()
	fish.name = "Fish"
	fish.position = position
	fish.rotation.y = yaw
	parent.add_child(fish)
	_sphere(fish, Vector3.ZERO, Vector3(0.58, 0.29, 0.25), colour)
	var tail := _cylinder(fish, Vector3(-0.62, 0, 0), 0.32, 0.35, colour.darkened(0.18), 0.03)
	tail.rotation.z = -PI * 0.5
	tail.scale.z = 0.22
	var detail := Detail.new()
	for side: float in [-1.0, 1.0]:
		var fin := Vector3(-0.08, -0.092, side * 0.229)
		detail.oval(fin + Vector3(-0.046, -0.02, side * 0.08), Vector3(0.34, 0.064, 0.28),
			colour.darkened(0.2), Vector3(side * 0.28, side * 0.39, 0))
		detail.oval(Vector3(0.36, 0.082, side * 0.185), Vector3.ONE * 0.205, SHELL)
		detail.oval(Vector3(0.388, 0.079, side * 0.265), Vector3.ONE * 0.115, INK)
		detail.oval(Vector3(0.41, 0.104, side * 0.31), Vector3.ONE * 0.035, Color.WHITE)
		detail.tube([Vector3(0.32, 0.041, side * 0.221), Vector3(0.274, -0.023, side * 0.226),
			Vector3(0.311, -0.106, side * 0.193)], [0.009, 0.020, 0.006], colour.darkened(0.31))
		for stripe in 3:
			detail.oval(Vector3(-0.24 + stripe * 0.133, 0.12, side * (0.192 + stripe * 0.014)),
				Vector3(0.058, 0.132, 0.035), colour.lightened(0.26), Vector3(0, 0, -0.30))
	detail.sweep(Vector3(0.14, 0.22, 0), Vector3(-0.32, 0.50, 0), Vector3(0.34, 0.05, 0),
		Vector3(0, 0, 0.038), colour.darkened(0.18))
	detail.attach(fish, "GillsAndFins")
	Detail.ink_figure(fish)


static func _island(parent: Node3D, upgrades: Array[String]) -> void:
	for index in 9:
		var angle := TAU * index / 9.0
		_sphere(parent, Vector3(cos(angle) * 2.2, 0.07, sin(angle) * 2.2),
			Vector3(0.35, 0.16, 0.28), Color("91a291"))
	if not upgrades.has("land_plants") and not upgrades.has("agriculture"):
		return
	for index in 3:
		var base := Vector3(-1.55 + index * 1.3, 0.05, -1.4)
		_segment(parent, base, base + Vector3(0, 1.3, 0), 0.08, Color("977657"))
		_sphere(parent, base + Vector3(0, 1.3, 0),
			Vector3(0.55, 0.55, 0.45), Color("6eaa6c"))
		if upgrades.has("flowering_plants"):
			for petal in 5:
				var angle := TAU * petal / 5.0
				_sphere(parent, base + Vector3(cos(angle) * 0.16, 1.55 + sin(angle) * 0.16, 0.4),
					Vector3.ONE * 0.09, Color("efb3aa"))


static func _dinosaur(parent: Node3D, position: Vector3, colour: Color, feathers: bool) -> void:
	var animal := Node3D.new()
	animal.name = "Dinosaur"
	animal.position = position
	parent.add_child(animal)
	_sphere(animal, Vector3(0, 0.7, 0), Vector3(0.7, 0.4, 0.35), colour)
	var detail := Detail.new()
	for x in [-0.38, 0.38]:
		for z in [-0.22, 0.22]:
			_segment(animal, Vector3(x, 0.05, z), Vector3(x, 0.65, z), 0.1, colour.darkened(0.1))
			detail.oval(Vector3(x, 0.54, z), Vector3(0.30, 0.45, 0.25), colour)
			detail.oval(Vector3(x + 0.046, 0.083, z), Vector3(0.29, 0.16, 0.24), colour.darkened(0.18))
	detail.tube([Vector3(0.32, 0.77, 0), Vector3(0.48, 0.92, 0), Vector3(0.51, 1.17, 0),
		Vector3(0.51, 1.41, 0), Vector3(0.59, 1.59, 0), Vector3(0.71, 1.69, 0)],
		[0.25, 0.215, 0.168, 0.14, 0.143, 0.15], colour)
	detail.tube([Vector3(-0.39, 0.74, 0), Vector3(-0.67, 0.72, 0.034),
		Vector3(-0.92, 0.64, 0.10), Vector3(-1.12, 0.62, 0.15), Vector3(-1.31, 0.71, 0.17)],
		[0.215, 0.161, 0.106, 0.051, 0.008], colour)
	_sphere(animal, Vector3(0.78, 1.7, 0), Vector3(0.32, 0.22, 0.22), colour)
	for side: float in [-1.0, 1.0]:
		detail.oval(Vector3(0.911, 1.756, side * 0.187), Vector3(0.174, 0.195, 0.123), SHELL)
		detail.oval(Vector3(0.927, 1.754, side * 0.239), Vector3(0.092, 0.12, 0.065), INK)
		detail.oval(Vector3(1.02, 1.688, side * 0.105), Vector3(0.075, 0.034, 0.042), colour.darkened(0.5))
	detail.oval(Vector3(0.922, 1.613, 0), Vector3(0.39, 0.14, 0.33), colour.lightened(0.24))
	detail.attach(animal, "HaunchesFeetAndFace")
	if feathers:
		for index in 4:
			_cylinder(animal, Vector3(-0.4 + index * 0.2, 1.1, 0),
				0.12, 0.22, colour.lightened(0.35), 0.0)
	Detail.ink_figure(animal)


static func _mammal(
	parent: Node3D, position: Vector3, colour: Color, size: float = 1.0
) -> void:
	var animal := Node3D.new()
	animal.name = "Mammal"
	animal.position = position
	animal.scale = Vector3.ONE * size
	parent.add_child(animal)
	_sphere(animal, Vector3(0, 0.38, 0), Vector3(0.48, 0.28, 0.3), colour)
	_sphere(animal, Vector3(0.4, 0.58, 0), Vector3(0.26, 0.25, 0.23), colour)
	var detail := Detail.new()
	detail.oval(Vector3(0.595, 0.535, 0), Vector3(0.25, 0.18, 0.30), SHELL)
	detail.oval(Vector3(0.701, 0.575, 0), Vector3(0.088, 0.079, 0.113), INK)
	detail.oval(Vector3(0.64, 0.484, 0), Vector3(0.149, 0.070, 0.179), INK)
	detail.oval(Vector3(0.683, 0.470, 0.021), Vector3(0.083, 0.043, 0.083), Color("db8d86"))
	for z in [-0.17, 0.17]:
		_sphere(animal, Vector3(0.38, 0.83, z), Vector3.ONE * 0.11, colour.lightened(0.15))
		detail.oval(Vector3(0.436, 0.828, z + signf(z) * 0.064), Vector3(0.11, 0.13, 0.09),
			colour.darkened(0.25))
		var eye := Vector3(0.535, 0.648, z * 1.06)
		detail.oval(eye, Vector3(0.137, 0.147, 0.091), SHELL)
		detail.oval(eye + Vector3(0.012, -0.002, signf(z) * 0.039), Vector3(0.088, 0.102, 0.047), INK)
		detail.oval(eye + Vector3(0.024, 0.022, signf(z) * 0.060), Vector3.ONE * 0.028, Color.WHITE)
		detail.oval(eye + Vector3(-0.021, 0.081, -signf(z) * 0.036),
			Vector3(0.114, 0.034, 0.045), colour.darkened(0.35), Vector3(0, 0, 0.31))
		detail.sweep(Vector3(0.45, 0.55, z), Vector3(0.36, 0.47, z * 1.63),
			Vector3(0.16, 0.027, 0), Vector3(0, 0.018, signf(z) * 0.078), colour.lightened(0.15))
		for x in [-0.28, 0.28]:
			_segment(animal, Vector3(x, 0.04, z), Vector3(x, 0.3, z), 0.06, colour.darkened(0.2))
			detail.oval(Vector3(x, 0.258, z), Vector3(0.20, 0.285, 0.19), colour)
			detail.oval(Vector3(x + 0.035, 0.065, z), Vector3(0.19, 0.11, 0.14), colour.darkened(0.12))
	detail.attach(animal, "EarCupsPawsAndMuzzle")
	_sphere(animal, Vector3(-0.48, 0.4, 0), Vector3.ONE * 0.11, colour)
	Detail.ink_figure(animal)


static func _insect(island: Node3D, position: Vector3, colour: Color) -> void:
	var parent := _group(island, "Insect", position)
	var detail := Detail.new()
	for side: float in [-1.0, 1.0]:
		detail.oval(Vector3(-0.046, 0.26, side * 0.071),
			Vector3(0.30, 0.146, 0.134), colour.lightened(0.17))
		var start := Vector3(0.245, 0.23, side * 0.049)
		var tip := Vector3(0.34, 0.33, side * 0.13)
		detail.rod(start, tip, 0.015, INK)
		detail.oval(tip, Vector3.ONE * 0.046, SHELL)
	detail.attach(parent, "WingCasesAndFeelers")
	_sphere(parent, Vector3(0, 0.2, 0), Vector3(0.19, 0.12, 0.15), colour)
	_sphere(parent, Vector3(0.2, 0.18, 0), Vector3.ONE * 0.1, Color("314a38"))
	for index in 3:
		for side in [-1.0, 1.0]:
			_segment(parent, Vector3((index - 1) * 0.12, 0.16, side * 0.08),
				Vector3((index - 1) * 0.2, 0.03, side * 0.3), 0.022, Color("314a38"))
	Detail.ink_figure(parent)


static func _group(parent: Node3D, title: String, at: Vector3) -> Node3D:
	var animal := Node3D.new()
	animal.name = title
	animal.position = at
	parent.add_child(animal)
	return animal


static func _town(parent: Node3D, upgrades: Array[String], colour: Color) -> void:
	if upgrades.has("primates"):
		_person(parent, Vector3(0.8, 0.06, 0.6), colour)
		_person(parent, Vector3(-0.7, 0.06, 0.75), colour.lightened(0.2))
	if upgrades.has("tools"):
		_box(parent, Vector3(0.85, 0.32, 1.05), Vector3(0.65, 0.1, 0.32), Color("b48e65"))
		for x in [0.6, 1.1]:
			_box(parent, Vector3(x, 0.16, 1.05), Vector3(0.06, 0.28, 0.24), Color("977657"))
	if upgrades.has("language"):
		_house(parent, Vector3(-0.8, 0.06, -0.3), colour, 0.8)
	if upgrades.has("agriculture"):
		for row in 3:
			for column in 4:
				var spot := Vector3(-1.2 + column * 0.19, 0.12, 0.65 + row * 0.22)
				_box(parent, spot, Vector3(0.16, 0.12, 0.16), Color("c7b977"))
				_segment(parent, spot, spot + Vector3(0, 0.24, 0), 0.025, Color("7faa64"))
	if upgrades.has("culture"):
		_house(parent, Vector3(0.3, 0.06, -0.75), colour.lightened(0.1), 0.95)
		_cylinder(parent, Vector3(0.2, 0.08, 0.25), 0.35, 0.12, Color("bcad88"))
	if upgrades.has("science"):
		_cylinder(parent, Vector3(1.15, 0.42, -0.5), 0.4, 0.75, Color("d5d4b9"))
		_sphere(parent, Vector3(1.15, 0.82, -0.5), Vector3(0.44, 0.3, 0.44), colour)
		_segment(parent, Vector3(1.15, 0.95, -0.5), Vector3(1.5, 1.15, -0.4),
			0.075, Color("4c6568"))
	if upgrades.has("civilization"):
		for index in 3:
			var spot := Vector3(-1.3 + index * 0.7, 0.06, -1.3)
			_house(parent, spot, colour, 1.1 + index * 0.15)
		_box(parent, Vector3(0, 0.08, 0.8), Vector3(0.2, 0.03, 1.8), Color("c4bd9e"))
		_person(parent, Vector3(1.3, 0.06, 0.5), colour.darkened(0.1))


static func _person(town: Node3D, position: Vector3, colour: Color) -> void:
	var parent := Node3D.new()
	town.add_child(parent)
	var detail := Detail.new()
	var skin := Color("d5b090")
	_cylinder(parent, position + Vector3(0, 0.24, 0), 0.11, 0.32, colour)
	_sphere(parent, position + Vector3(0, 0.5, 0), Vector3.ONE * 0.13, skin)
	detail.oval(position + Vector3(0, 0.585, -0.01), Vector3(0.253, 0.12, 0.25), INK)
	detail.oval(position + Vector3(0, 0.49, 0.128), Vector3(0.052, 0.049, 0.051), skin)
	detail.grin(position + Vector3(0, 0.465, 0.126), Vector3.RIGHT * 0.049,
		Vector3.UP * 0.031, Vector3.BACK * 0.009, 0.17, SHELL)
	for side in [-1.0, 1.0]:
		_segment(parent, position + Vector3(side * 0.07, 0.03, 0),
			position + Vector3(side * 0.06, 0.22, 0), 0.045, Color("4b6060"))
		detail.oval(position + Vector3(side * 0.049, 0.533, 0.114), Vector3(0.063, 0.066, 0.037), SHELL)
		detail.oval(position + Vector3(side * 0.048, 0.53, 0.131), Vector3(0.034, 0.045, 0.022), INK)
		detail.oval(position + Vector3(side * 0.11, 0.338, 0), Vector3.ONE * 0.12, colour)
		var elbow := Vector3(side * 0.15, 0.28, 0.018)
		var hand := Vector3(side * 0.15, 0.219, 0.042)
		if side > 0:
			elbow = Vector3(0.179, 0.354, 0.010)
			hand = Vector3(0.211, 0.434, 0.028)
		detail.tube([position + Vector3(side * 0.119, 0.335, 0), position + elbow,
			position + hand], [0.035, 0.031, 0.025], skin)
		detail.oval(position + hand, Vector3(0.059, 0.071, 0.055), skin)
		detail.oval(position + Vector3(side * 0.07, 0.029, 0.024), Vector3(0.10, 0.058, 0.14), INK)
	detail.sweep(position + Vector3(-0.046, 0.63, 0.043), position + Vector3(0.08, 0.55, 0.108),
		Vector3(-0.093, -0.036, 0), Vector3(0, 0.025, 0.024), INK)
	detail.attach(parent, "Villager")
	Detail.ink_figure(parent)


static func _house(parent: Node3D, position: Vector3, colour: Color, height: float) -> void:
	_box(parent, position + Vector3(0, height * 0.5, 0),
		Vector3(0.48, height, 0.45), Color("e0d5b5"))
	var roof := _cylinder(parent, position + Vector3(0, height + 0.12, 0),
		0.4, 0.3, colour, 0.0)
	roof.scale.z = 0.8
	_box(parent, position + Vector3(0, 0.18, 0.23),
		Vector3(0.12, 0.3, 0.025), Color("50676a"))
	_box(parent, position + Vector3(0.12, height * 0.65, 0.23),
		Vector3(0.1, 0.12, 0.025), Color("a9d8d7"))
