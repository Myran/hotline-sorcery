#NOTE: if you find any missspelling please ignore it i'm dumb
class_name PlayerScript extends CharacterBody2D

@export var body_anim: AnimatedSprite2D
@export var legs_anim: AnimatedSprite2D
@export var camera: Camera2D
@export var wep_manager: Node2D
@export var floor_color: ColorRect
@export var UI: PlayerUI
@export var sfx_player: AudioStreamPlayer

@export var max_ang: float = 45
@export var tilt_strength: float = 10
@export var distance: Vector2 = Vector2.ZERO #this limits the distance the camera offsets from the player good for ranged attack
@export var pan_speed: float = 10.0 #this variables changes the speed the camera offsets
#-----movement variables------#
var target_dir: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.ZERO #the direction the player is going to
var acceleration: float = 10.0 #the player's friction on the floor (low values makes movment slippery)
var speed: float

#-------mouse variables-------#
var mouse_pos: Vector2 = Vector2.ZERO

#-------misc stuff------------#
@onready var blood: PackedScene = preload("res://misc/blood_particle.tscn")
@onready var cur_scene: Node = get_tree().current_scene

signal shake_cam
signal switch_floor
signal died

@export var INVINSIBLE: bool = false
var LOCK_MOVE: bool = false
var LOCK_CAM: bool = false
var IS_DEAD: bool = false
var mana: float = 12
#-------debugging stuff----------#
var test_point: PackedScene = preload("res://entites/player/test_mesh.tscn")
#-------------------------------------------------------#
func _ready() -> void:
	self.connect("shake_cam", shake_camera)
	cur_scene.connect("switched_floor", _on_floor_changed)
	camera.make_current()

func _physics_process(delta: float) -> void:
	if !LOCK_MOVE:
		if !IS_DEAD:
			#storing the mouse position in a variable so we don't call the method more thazn once
			mouse_pos = get_global_mouse_position()
			
			#makes the player look where the mouse is pointing at for aiming
			look_at(mouse_pos)
			
			velocity = lerp(velocity, target_dir, acceleration * delta)
			#-----------------------------------------------------#
			if !LOCK_CAM:
				shake_camera()
				_camera_process(delta)
			_animation_process(delta)
			
		else:
			velocity = velocity.lerp(Vector2.ZERO, 5 * get_physics_process_delta_time())
			if velocity.is_equal_approx(Vector2(1, 1)):
				$body.disabled = true
		
			if Input.is_action_just_pressed("restart"):
				get_tree().reload_current_scene()
	else:
		look_at(global_position + Vector2.DOWN)
		direction = Vector2.DOWN
		velocity = lerp(velocity, direction * 50, acceleration * delta)
	
		
	
	_push_rigid()
	move_and_slide()

func looking_at() -> Vector2:
	return global_position.direction_to(mouse_pos)

func _animation_process(_delta: float) -> void:
	if direction != Vector2.ZERO and !velocity.is_zero_approx():
		body_anim.play("run_anim")
		legs_anim.play("legs1")
	else:
		body_anim.stop()
		legs_anim.stop()
		legs_anim.rotation_degrees = 0
	
	#NOTE: this is fpr rotating the legs depending on the firection the player is walkin to
	#var legs_direction: float = position.angle_to(to_global(direction))
	#legs_anim.global_rotation = lerp(legs_anim.global_rotation, legs_direction, 100 * delta)

func _camera_process(delta: float) -> void:
	var pan_dis: float = pan_speed * 1.5 if Input.is_action_pressed("zoom") else pan_speed
	var thres: Vector2 = distance * 2 if Input.is_action_pressed("zoom") else distance
	var look_to_direction: Vector2 = (mouse_pos - global_position)
	
	camera.offset = (look_to_direction * pan_dis) * delta
	
	#limit the pan raduis
	camera.offset = clamp(camera.offset, -thres, thres)

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var CAM_SHAKING: bool = false
func shake_camera() -> void:
	if Input.is_action_pressed("fire") and mana > 0:
		var rang: float = rng.randf_range(-10, 10) 
		camera.position = lerp(camera.position, Vector2(rang, rang), get_physics_process_delta_time() * 20)
	else:
		camera.position = lerp(camera.position, Vector2.ZERO, 1)
	$Camera2D/cam_shaker.start()
	#NOTE: this was supposed to be the camera strafe
	#TODO: figure out how to overwrite godot's shitty camera rotation inheritance 
	#camera.rotation_degrees = clamp(camera.rotation_degrees, -max_ang, max_ang)
	#camera.rotation_degrees = lerp(camera.rotation_degrees, direction.x, tilt_strength * delta)

func _push_rigid() -> void:
	if !move_and_slide():
		return
	else:
		for collider_index in get_slide_collision_count():
			var collision: KinematicCollision2D = get_slide_collision(collider_index)
			if collision.get_collider() is RigidBody2D and collision.get_collider().is_in_group("doors"):
				collision.get_collider().apply_central_impulse(collision.get_normal() * -5000)

func death(direc: Vector2) -> void:
	legs_anim.visible = false
	body_anim.play("death")
	if !IS_DEAD:
		velocity = direc * 200
		IS_DEAD = true
		var blood_ins: GPUParticles2D = blood.instantiate()
		blood_ins.global_position = global_position
		blood_ins.amount = 64
		blood_ins.rotate_towards(direc)
		
		cur_scene.add_child(blood_ins)
		
		emit_signal("died")
		sfx_player.play()
	

func _on_floor_changed(floor_pos: Vector2) -> void:
	var tween: Tween = get_tree().create_tween()
	
	tween.tween_property(floor_color, "modulate", Color(1, 1, 1, 1), 0.6)
	await tween.finished
	#tween.tween_callback(func(): global_position = floor_pos)
	global_position = floor_pos
	
	tween = get_tree().create_tween()
	tween.tween_property(floor_color, "modulate", Color(1, 1, 1, 0), 0.5).set_delay(0.1)
