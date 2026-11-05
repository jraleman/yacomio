extends Control

## One isolated 3D set for all colony presentation. Views never simulate time,
## buy upgrades, grant tokens or write saves.

const Options := preload("res://games/yacomio/yacomio_options.gd")
const Models := preload("res://games/yacomio/colony_models.gd")
const FOV := 36.0

@export_enum("play", "gallery", "store", "intro", "share") var role := "play"

var _viewport: SubViewport
var _world: Node3D
var _camera: Camera3D
var _model: Node3D
var _configured: Dictionary = {}
var _signature := ""
var _focus := Vector3.ZERO
var _radius := 1.0
var _yaw := 0.0
var _pitch := 0.0
var _zoom := 1.0
var _motion := false
var _time := 0.0
var _inert := false
var _draw_queued := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inert = DisplayServer.get_name() == "headless"
	set_process(false)
	if _inert:
		return
	var frame := SubViewportContainer.new()
	frame.name = "ColonyViewportContainer"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.stretch = true
	frame.stretch_shrink = 2
	add_child(frame)
	_viewport = SubViewport.new()
	_viewport.name = "ColonyViewport"
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	frame.add_child(_viewport)
	_world = Node3D.new()
	_world.name = "ColonyWorld"
	_viewport.add_child(_world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("173a32")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d9e5e0")
	environment.environment.ambient_light_energy = 0.7
	_world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -35, 0)
	light.light_color = Color("fff0d6")
	light.light_energy = 1.25
	_world.add_child(light)
	_camera = Camera3D.new()
	_camera.current = true
	_camera.near = 0.05
	_camera.far = 150.0
	_world.add_child(_camera)
	resized.connect(_apply_camera)
	visibility_changed.connect(_request_draw)
	configure(_configured)


func configure(data: Dictionary) -> void:
	_configured = data.duplicate(true)
	if _inert or _world == null:
		return
	var subject: Dictionary = _configured.get("colony", _configured)
	var stage := int(subject.get("stage", 0))
	var upgrades: Array[String] = []
	upgrades.assign(subject.get("upgrades", []))
	var membrane := str(subject.get("membrane", Options.DEFAULT_MEMBRANE))
	var habitat := str(subject.get("habitat", Options.DEFAULT_HABITAT))
	if role == "store" and subject.has("id"):
		var item := Options.store_item(str(subject["id"]))
		if not item.is_empty():
			if str(item["kind"]) == "membrane":
				membrane = str(item["id"])
			else:
				habitat = str(item["id"])
		upgrades.assign(["rna", "dna", "membrane"])
	elif role == "gallery":
		var store := get_node_or_null("/root/Store")
		if store != null:
			membrane = str(store.call("equipped_id", Options.GAME_ID, Options.MEMBRANE_SLOT))
			habitat = str(store.call("equipped_id", Options.GAME_ID, Options.HABITAT_SLOT))
	var signature := str([stage, upgrades, membrane, habitat])
	if signature != _signature:
		_signature = signature
		if _model != null:
			_world.remove_child(_model)
			_model.queue_free()
		_model = Models.build(stage, upgrades, membrane, habitat)
		_world.add_child(_model)
		var box := Models.bounds(_model)
		_focus = box.get_center()
		_radius = maxf(box.size.length() * 0.5, 0.1)
		_apply_camera()
	var sun := _model.get_node_or_null("Sun")
	if sun is Node3D:
		(sun as Node3D).visible = bool(subject.get("daylight", true))
	_request_draw()


func set_view(yaw: float, pitch: float, zoom: float) -> void:
	_yaw = yaw
	_pitch = pitch
	_zoom = maxf(zoom, 0.01)
	_apply_camera()


## The shared gallery supplies its own spin through set_view().
func set_auto_spin(_enabled: bool) -> void:
	pass


func set_preview_running(_running: bool) -> void:
	_request_draw()


func set_motion(enabled: bool) -> void:
	_motion = enabled
	set_process(enabled and not _inert)
	if not enabled and _model != null:
		_time = 0.0
		_model.position = Vector3.ZERO
		_model.rotation = Vector3.ZERO
	_request_draw()


func _process(delta: float) -> void:
	if _model == null:
		return
	_time += delta
	_model.rotation.y = sin(_time * 0.3) * 0.08
	_model.position.y = sin(_time * 0.8) * 0.025


func _apply_camera() -> void:
	if _camera == null or size.x < 1.0 or size.y < 1.0:
		return
	var half := deg_to_rad(FOV) * 0.5
	var narrow := minf(size.x / size.y, 1.0)
	var distance := _radius * 1.08 / sin(atan(tan(half) * narrow)) / _zoom
	var yaw := 0.38 + _yaw
	var pitch := clampf(0.38 + _pitch, -1.3, 1.3)
	var direction := Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
	_camera.fov = FOV
	_camera.position = _focus + direction * distance
	_camera.look_at(_focus)
	_request_draw()


func _request_draw() -> void:
	if _viewport == null or not is_visible_in_tree():
		return
	if _motion or role == "gallery":
		_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	elif not _draw_queued:
		_draw_queued = true
		RenderingServer.frame_post_draw.connect(_draw_once, CONNECT_ONE_SHOT)


func _draw_once() -> void:
	_draw_queued = false
	if _viewport != null and is_visible_in_tree():
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
