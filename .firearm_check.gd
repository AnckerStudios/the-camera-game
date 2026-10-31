extends SceneTree

class Target extends StaticBody3D:
	var hits: int = 0
	var total: float = 0.0
	func take_damage(amount: float, _source: Node) -> void:
		hits += 1
		total += amount

var failures: int = 0
var results: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func add_box(body: StaticBody3D, position: Vector3, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	root.add_child(body)
	body.position = position

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var owner_body := CharacterBody3D.new()
	world.add_child(owner_body)
	var holder := WeaponHolder.new()
	owner_body.add_child(holder)
	var weapon := Firearm.new()
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(2, 1.2, -0.5)
	weapon.add_child(muzzle)
	var sound := AudioStreamPlayer3D.new()
	sound.name = "ShootSound"
	weapon.add_child(sound)
	holder.add_child(weapon)
	weapon.damage = 12.0
	weapon.pellets = 3
	weapon.spread_degrees = 0.0
	weapon.pellet_fired.connect(func(origin, endpoint, target, amount):
		results.append({"origin": origin, "endpoint": endpoint, "target": target, "damage": amount}))
	var target := Target.new()
	add_box(target, Vector3(0, 1, -4), Vector3(1, 2, 1))
	# Пол не должен блокировать выстрел из центра тела.
	var floor_body := StaticBody3D.new()
	add_box(floor_body, Vector3(0, -0.5, 0), Vector3(20, 1, 20))
	await physics_frame
	await physics_frame
	weapon.shoot(1)
	check(target.hits == 3, "Each pellet must damage the target independently")
	check(is_equal_approx(target.total, 36.0), "Three pellets must deal 36 damage")
	check(results.size() == 3, "One result signal per pellet")
	if not results.is_empty():
		check(results[0].origin.is_equal_approx(Vector3(0, 1.2, 0)), "Logical origin must be character center")
		check(absf(results[0].endpoint.x) < 0.01, "Shot must not inherit sideways muzzle offset")
	weapon._fire_ray(Vector3.FORWARD, 7.0)
	check(target.hits == 4 and is_equal_approx(target.total, 43.0), "Per-pellet damage override")
	var wall := StaticBody3D.new()
	add_box(wall, Vector3(0, 1, -2), Vector3(1, 2, 0.3))
	await physics_frame
	await physics_frame
	weapon._fire_ray(Vector3.FORWARD, 99.0)
	check(target.hits == 4, "Wall must block target even when muzzle is outside wall width")
	check(results.back().endpoint.z > -2.5, "Tracer must stop at wall contact")
	print("FIREARM_CHECK failures=", failures)
	quit(1 if failures else 0)
