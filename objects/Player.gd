extends KinematicBody

const MAX_DIAGNOSTIC_LINES = 12
const DIAGNOSTIC_FONT = preload("res://assets/fonts/Anonymous_Pro.tres")

export(NodePath) var movement_field: NodePath

export(float) var mouse_sensitivity: float = 0.002
export(float) var speed: float = 8.0
export(float) var weight: float = -30
export(bool) var fix_camera: bool = false
export(bool) var fix_movement: bool = false

var _velocity: Vector3 = Vector3.ZERO

onready var _camera_pivot : Spatial = $CameraPivot as Spatial
onready var _animation_player: AnimationPlayer = $AnimationPlayer as AnimationPlayer
onready var _audio_player: AudioStreamPlayer3D = $Wheel/WheelWhirr as AudioStreamPlayer3D
onready var _vector_field_node: Spatial
onready var _vector_field: Image
onready var _vector_field_size: Vector2
onready var _cameras = []
onready var _current_camera_index = 0

func _ready():
#	_animation_player.play("Bootup")
	yield(get_tree(), "idle_frame")
	call_deferred("_setup_vector_field")

func _setup_vector_field():
	if movement_field:
		_vector_field_node = get_node(movement_field) as Spatial
		_vector_field = _vector_field_node.texture.get_data()
		_vector_field.lock()
		_vector_field_size = _vector_field.get_size() * _vector_field_node.pixel_size
		_vector_field_size *= Vector2(_vector_field_node.scale.x, _vector_field_node.scale.z)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	if fix_camera: 
		return
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	var motion := (event as InputEventMouseMotion).relative
	rotate_y(-motion.x * mouse_sensitivity)
	_camera_pivot.rotate_x(-motion.y * mouse_sensitivity)
	_camera_pivot.rotation.x = clamp(_camera_pivot.rotation.x, -1.2, 1.2)

func _get_movement_input() -> Vector3:
	var input_dir := Vector3.ZERO
	if fix_movement:
		return input_dir
	if Input.is_action_pressed("move_forward"):
		input_dir += -global_transform.basis.z
	if Input.is_action_pressed("move_back"):
		input_dir += global_transform.basis.z
	if Input.is_action_pressed("move_left"):
		input_dir += -global_transform.basis.x
	if Input.is_action_pressed("move_right"):
		input_dir += global_transform.basis.x
	input_dir = input_dir.normalized()
	return input_dir

func _get_movement_vector_force() -> Vector3:
	var position := _get_texture_unit_position()
	$HUD/Debug/Position.text = str(position)
	if position.x < 0.0 or position.y < 0.0 or position.x > 1.0 or position.y > 1.0:
		$HUD/Debug/Colour.text = "---"
		return Vector3.ZERO
	var field_data := _vector_field.get_pixelv(position * _vector_field.get_size())
	var colour := Vector3(field_data.r, field_data.g, field_data.b)
	$HUD/Debug/Colour.text = str(colour)
	var offset : Vector3 = 2 * (colour - Vector3(0.5, 0.5, 0.5))
	offset.z *= 1
	$HUD/Debug/Offset.text = str(offset)
	return offset

func _get_texture_unit_position() -> Vector2:
	var relative_position: Vector3 = global_transform.origin - _vector_field_node.global_transform.origin
	var position := Vector2(relative_position.x, -relative_position.z)
	var unit_position: Vector2 = position / _vector_field_size
	unit_position.y = 1.0 - unit_position.y
	return unit_position

func _physics_process(delta: float) -> void:
	var movement := _get_movement_input()
	if movement != Vector3.ZERO and _vector_field:
		movement += _get_movement_vector_force()
	_velocity.y += weight * delta
	var desired_velocity := movement * speed
	_velocity.x = desired_velocity.x
	_velocity.z = desired_velocity.z
	_velocity = move_and_slide(_velocity, Vector3.UP, true)
	if _velocity.length_squared() < pow(speed / 2, 2.0):
		_audio_player.pitch_scale = 2.0
	else:
		_audio_player.pitch_scale = 1.5
	if movement != Vector3.ZERO:
		_audio_player.play()
	else:
		_audio_player.stop()

func _add_diagnostic(message: String) -> void:
	var label := Label.new()
	if $HUD/Diagnostics.get_child_count() >= MAX_DIAGNOSTIC_LINES:
		$HUD/Diagnostics.remove_child($HUD/Diagnostics.get_child(0))
	$HUD/Diagnostics.add_child(label)
	label.text = message
	label.set("custom_fonts/font", DIAGNOSTIC_FONT)
