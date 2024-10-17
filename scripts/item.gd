class_name Item extends RigidBody3D

# Item
@onready var disable_when_picked = [ $Hitbox, ]
@onready var death_timer = $Death
@onready var death_particles = [ ]
@onready var remove_on_death = [ ]
@onready var afterlife_timer = $Afterlife
@onready var delete_particles = [ $DeleteParticles, ]
@onready var remove_on_delete = [ $Hitbox, $View, ]
var is_picked_up = false
var death_duration = 1.0
var is_dead = false
var is_deleted = false

# Scale
@onready var scaling_children = [ $Hitbox, $View, ]
const SCALE_SPEED = 3
const DEFAULT_SCALE = 1
const PICKED_UP_SCALE = .6
var current_scale = DEFAULT_SCALE
var target_scale = DEFAULT_SCALE
var is_target_scale_reached = false
var scale_direction = 0

# Rotation
@onready var model = $View/Model
const DEFAULT_ROTATION_SPEED = .012
const PICKED_UP_ROTATION_SPEED = -DEFAULT_ROTATION_SPEED / 2
var rotation_speed = DEFAULT_ROTATION_SPEED

# Movement
const SPEED = 7.5
const POSITION_ACCURACY = 3.0
var target_position = Vector3.ZERO
var is_in_manual_motion = false

# Animations
@onready var animation_player = $Animator
var animations = {
	'death': 'WOBBLE',
	'default': 'FLOAT',
	'picked': 'RESET',
	'delete': 'RESET',
}

# Physics
@onready var neighborhood_area = $Neighborhood

# Item

# BUG Not disabling hitbox on pickup (to be able to hit pickup raycast from inventory) can cause problems (like tile tile activation by picked up items)
# TODO Think of a better aproach instead of disable_children arg
func set_picked_up(value:bool, disable_children:bool = value):
	if is_dead: return
	if is_picked_up == value: return
	
	is_picked_up = value
	
	for shy_child in disable_when_picked:
		shy_child.disabled = disable_children
	
	if is_picked_up:
		freeze = true
		wake_up_neighbors()
		set_target_scale(PICKED_UP_SCALE)
		set_rotation_speed(PICKED_UP_ROTATION_SPEED)
		linear_velocity = Vector3.ZERO
		animation_player.play(animations.picked)
	else:
		freeze = false
		linear_velocity = Vector3.ZERO
		stop_moving()
		set_target_scale(DEFAULT_SCALE)
		set_rotation_speed(DEFAULT_ROTATION_SPEED)
		animation_player.play(animations.default)
	
	print('Picked up ' if is_picked_up else 'Dropped ', name)

func delete():
	if is_deleted: return
	
	is_deleted = true
	is_dead = true
	
	afterlife_timer.start(0)
	animation_player.play(animations.delete)
	freeze = true
	for child in remove_on_death:
		if child == null: continue
		
		child.queue_free()
	for child in remove_on_delete:
		child.queue_free()
	for particles in delete_particles:
		particles.emitting = true

func die(source_object:Object = null, death_time:float = death_duration):
	if is_dead: return
	if death_time <= .05:
		delete()
		return
	
	is_dead = true
	
	death_timer.wait_time = death_time
	death_timer.start(0)
	animation_player.play(animations.death)
	freeze = true # NOTE Can be removed if you want it bouncy when it hits the lava or somthn
	for child in remove_on_death:
		child.queue_free()
	for particles in death_particles:
		particles.emitting = true

# Scale

func set_target_scale(value:float):
	if is_dead: return
	if target_scale == value: return
	
	target_scale = value
	is_target_scale_reached = false
	scale_direction = 1 if target_scale > current_scale else -1

func update_scale(delta:float):
	if is_deleted: return
	if is_target_scale_reached: return
	
	# https://github.com/godotengine/godot/issues/5734
	# that was a time not well spent
	
	current_scale += SCALE_SPEED * scale_direction * delta
	
	if (scale_direction > 0 and current_scale > target_scale or
		scale_direction < 0 and current_scale < target_scale):
		current_scale = target_scale
	
	for scaling_child in scaling_children:
		scaling_child.scale = Vector3(current_scale, current_scale, current_scale)
	
	is_target_scale_reached = current_scale == target_scale
	
	if is_target_scale_reached:
		scale_direction = 0

# Rotation

func set_rotation_speed(value:float):
	rotation_speed = value

func apply_rotation():
	model.rotate_y(rotation_speed)

# Movement

func are_vectors_roughly_equal(vector_a:Vector3, vector_b:Vector3) -> bool:
	var accuracy = Vector3(
		0.1 ** POSITION_ACCURACY,
		0.1 ** POSITION_ACCURACY,
		0.1 ** POSITION_ACCURACY,
	)
	return snapped(vector_a, accuracy) == snapped(vector_b, accuracy)

# NOTE Could perhaps do movement with forces to be able to use it in non picked state
func update_position(delta:float):
	if not is_in_manual_motion: return
	if are_vectors_roughly_equal(global_position, target_position):
		stop_moving()
		return
	
	global_position = global_position.lerp(target_position, SPEED * delta)
	linear_velocity = Vector3.ZERO

func set_to_position(position_vector:Vector3):
	global_position = position_vector

func move_to_position(position_vector:Vector3):
	target_position = position_vector
	is_in_manual_motion = true
	freeze = true

func stop_moving():
	is_in_manual_motion = false
	freeze = false

# Physics

func wake_up_neighbors(velocity:Vector3 = Vector3(0, 1, 0)):
	# Could also just set can_sleep to false in _ready() instead
	# Docs https://docs.godot.community/classes/class_rigidbody3d.html#class-rigidbody3d-property-can-sleep
	for neighbor in neighborhood_area.get_overlapping_bodies():
		if not neighbor is RigidBody3D: continue
		# Changing sleep state same frame as disabling hitbox doesnt help
		neighbor.linear_velocity += velocity

# General

func _ready():
	animation_player.play(animations.default)

func _process(delta:float):
	update_position(delta)
	
	if is_deleted: return
	
	update_scale(delta)
	
	if is_dead: return
	
	apply_rotation()

func _on_death_timeout() -> void:
	delete()

func _on_afterlife_timeout() -> void:
	queue_free()