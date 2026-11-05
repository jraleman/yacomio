extends RefCounted

## Original Compatibility-friendly toy meshes, reused without embellishment by
## gameplay, the opening, the cosmetic shelf, the gallery and frozen share art.

const Options := preload("res://games/yacomio/yacomio_options.gd")


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
	_cylinder(root, Vector3(0, 0.01, 0), 2.66, 0.06,
		basin if stage < 3 else Color("759568"))
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


static func _sponges(parent: Node3D, position: Vector3, colour: Color) -> void:
	for index in 3:
		var base := position + Vector3((index - 1) * 0.4, 0, (index % 2) * 0.3)
		var height := 0.7 + index * 0.2
		_cylinder(parent, base + Vector3(0, height * 0.5, 0), 0.23, height, colour)
		_ring(parent, base + Vector3(0, height, 0), 0.12, 0.24, colour.lightened(0.2))
		_cylinder(parent, base + Vector3(0, height + 0.005, 0), 0.12, 0.012, colour.darkened(0.6))
		for hole in 4:
			_sphere(parent, base + Vector3(0.07 * sin(hole * 2.0), 0.18 + hole * 0.12, 0.23),
				Vector3(0.055, 0.06, 0.015), colour.darkened(0.45))


static func _jellyfish(parent: Node3D, position: Vector3, colour: Color, nerves: bool) -> void:
	_sphere(parent, position, Vector3(0.55, 0.27, 0.5), colour)
	_cylinder(parent, position + Vector3(0, -0.12, 0), 0.48, 0.06, colour.darkened(0.12))
	for index in 5:
		var x := (index - 2) * 0.16
		var start := position + Vector3(x, -0.15, 0.1)
		for segment in 3:
			var end := start + Vector3(sin(index + segment) * 0.09, -0.2, 0.02)
			_segment(parent, start, end, 0.035, colour.lightened(0.15))
			start = end
		if nerves:
			_sphere(parent, position + Vector3(x, 0.03, 0.45),
				Vector3.ONE * 0.045, Color("eaaa86"))


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
	_box(fish, Vector3(-0.08, -0.12, 0.26), Vector3(0.28, 0.06, 0.3),
		colour.darkened(0.18)).rotation.x = -0.4
	_box(fish, Vector3(-0.08, 0.3, 0), Vector3(0.32, 0.2, 0.04), colour.darkened(0.18))
	_sphere(fish, Vector3(0.34, 0.09, 0.2), Vector3.ONE * 0.075, Color("edf5e8"))
	_sphere(fish, Vector3(0.37, 0.09, 0.25), Vector3.ONE * 0.035, Color("163031"))


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
	for x in [-0.38, 0.38]:
		for z in [-0.22, 0.22]:
			_segment(animal, Vector3(x, 0.05, z), Vector3(x, 0.65, z), 0.1, colour.darkened(0.1))
	_segment(animal, Vector3(0.4, 0.8, 0), Vector3(0.65, 1.65, 0), 0.15, colour)
	_sphere(animal, Vector3(0.78, 1.7, 0), Vector3(0.32, 0.22, 0.22), colour)
	_sphere(animal, Vector3(0.92, 1.77, 0.19), Vector3.ONE * 0.045, Color("23382e"))
	_segment(animal, Vector3(-0.5, 0.7, 0), Vector3(-1.2, 0.55, 0), 0.1, colour)
	if feathers:
		for index in 4:
			_cylinder(animal, Vector3(-0.4 + index * 0.2, 1.1, 0),
				0.12, 0.22, colour.lightened(0.35), 0.0)


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
	for z in [-0.17, 0.17]:
		_sphere(animal, Vector3(0.38, 0.83, z), Vector3.ONE * 0.11, colour.lightened(0.15))
		_sphere(animal, Vector3(0.51, 0.62, z), Vector3.ONE * 0.035, Color("23382e"))
		for x in [-0.28, 0.28]:
			_segment(animal, Vector3(x, 0.04, z), Vector3(x, 0.3, z), 0.06, colour.darkened(0.2))
	_sphere(animal, Vector3(-0.48, 0.4, 0), Vector3.ONE * 0.11, colour)


static func _insect(parent: Node3D, position: Vector3, colour: Color) -> void:
	_sphere(parent, position + Vector3(0, 0.2, 0), Vector3(0.19, 0.12, 0.15), colour)
	_sphere(parent, position + Vector3(0.2, 0.18, 0), Vector3.ONE * 0.1, Color("314a38"))
	for index in 3:
		for side in [-1.0, 1.0]:
			_segment(parent, position + Vector3((index - 1) * 0.12, 0.16, side * 0.08),
				position + Vector3((index - 1) * 0.2, 0.03, side * 0.3), 0.022, Color("314a38"))


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


static func _person(parent: Node3D, position: Vector3, colour: Color) -> void:
	_cylinder(parent, position + Vector3(0, 0.24, 0), 0.11, 0.32, colour)
	_sphere(parent, position + Vector3(0, 0.5, 0), Vector3.ONE * 0.13, Color("d5b090"))
	for side in [-1.0, 1.0]:
		_segment(parent, position + Vector3(side * 0.07, 0.03, 0),
			position + Vector3(side * 0.06, 0.22, 0), 0.045, Color("4b6060"))


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
