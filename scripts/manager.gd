class_name Manager
extends Node

signal result(score :int)

@export var manual: bool = true
# Settings
@export var motor_force: float
@export var break_force: float
@export var max_steer_angle: float

# Vehicle body reference
@export var vehicle_body: VehicleBody3D

# Wheel nodes
@onready var front_left_wheel: VehicleWheel3D = vehicle_body.get_node("FL")
@onready var front_right_wheel: VehicleWheel3D  = vehicle_body.get_node("FR")
@onready var rear_left_wheel: VehicleWheel3D = vehicle_body.get_node("RL")
@onready var rear_right_wheel: VehicleWheel3D = vehicle_body.get_node("RR")


@onready var parking_sensors: Array[ParkingSensor] = [
	vehicle_body.get_node("Parking Sensor 0"),
	vehicle_body.get_node("Parking Sensor 1"),
	vehicle_body.get_node("Parking Sensor 2"),
	vehicle_body.get_node("Parking Sensor 3"),
	vehicle_body.get_node("Parking Sensor 4"),
	vehicle_body.get_node("Parking Sensor 5"),
	vehicle_body.get_node("Parking Sensor 6"),
	vehicle_body.get_node("Parking Sensor 7")
]
@onready var line_sensors: Array[ParkingSensor] = [
	vehicle_body.get_node("Line Sensor 0"),
	vehicle_body.get_node("Line Sensor 1")
]

var horizontal_input: float
var current_steer_angle: float
var target_steer_angle: float
var current_break_force: float
var handbrake: bool = false
var throttle: float = 0.0
var speed: float = 0.0
var direction: int = 1
var current_setted_speed: float = 0.0
var current_angle: float = 0.0
var angle_step: float = 0.01
var elapsed_time: float = 0.0
var queue: Array[float] = []
var current_tween: Tween

func _ready() -> void:
	elapsed_time = 0.0
	assert(vehicle_body != null, "Vehicle body reference is required!")
	target_steer_angle = 0.0
	current_steer_angle = 0.0

func _physics_process(delta: float) -> void:
	if manual:
		get_input_manual()
	else:
		get_input()
	
	
	handle_steering()
	
	handle_motor()
	
	elapsed_time += delta

func get_input() -> void:
	horizontal_input = clamp(horizontal_input, -1.0, 1.0)
	
	if current_setted_speed == 0:
		if vehicle_body.linear_velocity.length() < 0.1:
			throttle = 0
		else:
			if vehicle_body.transform.basis.z.dot(vehicle_body.linear_velocity) * 3.6 < current_setted_speed:
				throttle = 1
			else:
				throttle = -1
	else:
		if vehicle_body.transform.basis.z.dot(vehicle_body.linear_velocity) * 3.6 < current_setted_speed:
			throttle = 1
		else:
			throttle = -1
	
	speed = vehicle_body.linear_velocity.length() * 3.6

func get_input_manual() -> void:
	if Input.is_action_just_pressed("t"):
		end_of_parking()
	
	horizontal_input = Input.get_axis("ui_left", "ui_right")
	
	target_steer_angle = horizontal_input * max_steer_angle
	current_steer_angle = lerp(current_steer_angle, target_steer_angle, 0.1)
	
	throttle = Input.get_axis("ui_down", "ui_up")
	handbrake = Input.is_action_pressed("space")

func handle_motor() -> void:
	var motor_torque = direction * throttle * motor_force

	vehicle_body.engine_force = motor_torque
	
	current_break_force = break_force if handbrake else 0.0
	apply_breaking()

func apply_breaking() -> void:
	vehicle_body.brake = current_break_force
	
	if handbrake:
		vehicle_body.engine_force = 0

func handle_steering() -> void:
	if horizontal_input >= 0:
		front_left_wheel.steering = -deg_to_rad(current_steer_angle)
		front_right_wheel.steering = -deg_to_rad(current_steer_angle + horizontal_input * 10)
	else:
		
		front_left_wheel.steering = -deg_to_rad(current_steer_angle + horizontal_input * 10)
		front_right_wheel.steering = -deg_to_rad(current_steer_angle)
	
	

func set_speed(value: float) -> void:
	current_setted_speed = clamp(value, -60.0, 60.0)

func set_steering_angle(value: float) -> void:
	value = clamp(value, -1.0, 1.0)
	
	if current_tween:
		queue.append(value)
		return
	
	change_angle(value * max_steer_angle)

func change_angle(new_angle: float) -> void:
	current_tween = create_tween()
	current_tween.set_trans(Tween.TRANS_QUAD)
	current_tween.set_ease(Tween.EASE_OUT)
	
	current_tween.tween_property(self, "current_steer_angle", new_angle, 
		abs(new_angle - current_steer_angle) / (max_steer_angle * angle_step) * 0.008)
	
	await current_tween.finished
	
	current_angle = new_angle / max_steer_angle
	current_tween = null
	
	if not queue.is_empty():
		var next_value = queue.pop_front()
		set_steering_angle(next_value)

func get_parking_sensor_distance(index: int) -> float:
	if index >= parking_sensors.size() or index < 0:
		return -1.0
	
	return parking_sensors[index].value

func get_distance_to_line(index: int) -> float:
	if index > 1 or index < 0:
		return -1.0
	
	return line_sensors[index].value

func end_of_parking() -> void:
	if current_setted_speed != 0:
		print("Car in move!")
		print("Score: 0")
		return
	
	#while speed > 0.01:
	#	await get_tree().physics_frame
	
	print("Time: ", elapsed_time)
	if elapsed_time > 50.0:
		print("Time Limit!")
	
	var euler_y = rad_to_deg(vehicle_body.rotation.y)
	print("Car angle: ", euler_y)
	
	var angle_score := 0.0
	if -1 <= euler_y and euler_y <= 1:
		angle_score = 1.0 
	elif -45 <= euler_y and euler_y < 0:
		angle_score = (euler_y + 45) / 45  
	elif 0 < euler_y and euler_y <= 45:
		angle_score = (45 - euler_y) / 45 
	
	var alpha = euler_y > 90 if euler_y - 90 else 90 - euler_y
	var l = min(get_distance_to_line(0), get_distance_to_line(1))
	var min_dist_to_line = l * cos(deg_to_rad(alpha))
	
	print("Distance to line: ", min_dist_to_line)
	
	var line_score = 0.0
	if 0.7 < min_dist_to_line and min_dist_to_line < 3:
		line_score = (min_dist_to_line - 0.7) / (3 - 0.7)
	elif min_dist_to_line >= 3:
		line_score = 1.0
	
	print("Distance to back obstacle: ", get_parking_sensor_distance(4))
	
	var distance_score = 0.0
	var back_distance = get_parking_sensor_distance(4)
	
	if back_distance < 0.2:
		distance_score = back_distance / 0.2
	elif 0.2 <= back_distance and back_distance <= 0.4:
		distance_score = 1.0
	elif 0.4 < back_distance and back_distance < 0.6:
		distance_score = (back_distance - 0.6) / (0.4 - 0.6)
	
	print(angle_score, " ",  distance_score, " ", line_score)
	
	if elapsed_time <= 50.0:
		print("Score: ", int(100 * min(angle_score, distance_score, line_score)))
		result.emit(int(100 * min(angle_score, distance_score, line_score)))
	else:
		print("Score: 0")
		result.emit(0)
	
	
	
