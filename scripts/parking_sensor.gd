class_name ParkingSensor
extends Node3D

@export var line_control: bool = false
@export_flags_3d_physics var collision_mask: int
@export var sphere_material: Material

var sphere: MeshInstance3D
var value: float = 0.0

func _ready():
	# Create sphere mesh
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.1  # Half of 0.1 since radius is used instead of scale
	sphere_mesh.height = 0.2
	sphere_mesh.radial_segments = 16
	sphere_mesh.rings = 8
	
	
	# Create sphere instance
	sphere = MeshInstance3D.new()
	sphere.mesh = sphere_mesh
	
	if sphere_material:
		sphere.material_override = sphere_material
		
	add_child(sphere)

func _process(_delta):
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	query.from = global_position
	query.to = global_position + global_transform.basis.z * 10.0
	query.collision_mask = collision_mask
	
	var result = space_state.intersect_ray(query)
	
	if result:
		sphere.global_position = result.position
	else:
		sphere.global_position = global_position + global_transform.basis.z * 10.0
	
	# Using DebugDraw addon for line visualization
	var line_color = Color.BLUE if line_control else Color.RED
	DebugDraw3D.draw_line(
		global_position,
		sphere.global_position,
		line_color
	)
	
	value = global_position.distance_to(sphere.global_position)

func get_value() -> float:
	return value
