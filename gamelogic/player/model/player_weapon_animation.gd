class_name PlayerWeaponAnimation
extends Node
## Поза оружия и одноразовые действия персонажа. Ходьба остаётся в player_model.gd.
@export var tree: AnimationTree
var _holder: WeaponHolder
var _weapon: Weapon
var _dead := false

func initialize(body: CharacterBody3D, holder: WeaponHolder) -> void:
	_holder = holder
	if body and body.has_signal(&"dashed"):
		body.dashed.connect(_on_dashed)
	if holder:
		holder.weapon_selected.connect(_on_weapon_selected)
	_on_weapon_selected(holder.current if holder else null)

func _process(_delta: float) -> void:
	if _dead:
		return
	if _weapon is Firearm:
		if _weapon.is_reloading:
			if not tree.get("parameters/ReloadFactor/active"):
				_on_reload_started()
		else:
			_abort(&"ReloadFactor")

func _on_weapon_selected(weapon: Weapon) -> void:
	_disconnect_weapon()
	_weapon = weapon
	_abort(&"ReloadFactor")
	_abort(&"AxeAttack")
	if _dead:
		return
	# PistolFactor: 0 — пистолет, 1 — винтовка. AxeFactor: 1 — топор.
	tree.set("parameters/PistolFactor/blend_amount", 0.0 if weapon and weapon.one_handed else 1.0)
	tree.set("parameters/AxeFactor/blend_amount", 1.0 if weapon is MeleeWeapon else 0.0)
	if weapon is Firearm:
		weapon.reload_started.connect(_on_reload_started)
		weapon.reload_finished.connect(_on_reload_finished)
	elif weapon is MeleeWeapon:
		weapon.character_animation = true
		weapon.swung.connect(_on_axe_swung)

func _disconnect_weapon() -> void:
	if not is_instance_valid(_weapon):
		return
	if _weapon is Firearm:
		if _weapon.reload_started.is_connected(_on_reload_started):
			_weapon.reload_started.disconnect(_on_reload_started)
		if _weapon.reload_finished.is_connected(_on_reload_finished):
			_weapon.reload_finished.disconnect(_on_reload_finished)
	elif _weapon is MeleeWeapon:
		_weapon.character_animation = false
		if _weapon.swung.is_connected(_on_axe_swung):
			_weapon.swung.disconnect(_on_axe_swung)

func _on_reload_started() -> void:
	if not _dead and _weapon is Firearm:
		_play(&"ReloadFactor", &"ReloadSpeed", &"move/reload", _weapon.reload_time)

func _on_reload_finished() -> void:
	_abort(&"ReloadFactor")

func _on_axe_swung() -> void:
	if not _dead and _weapon is MeleeWeapon:
		_play(&"AxeAttack", &"AxeAttackSpeed", &"move/axe_attack", _weapon.swing_interval)

func _on_dashed(_direction: Vector3, duration: float) -> void:
	if not _dead:
		_abort(&"ReloadFactor")
		_abort(&"AxeAttack")
		_play(&"Roll", &"RollSpeed", &"move/roll", duration)

## Возвращает время до показа меню смерти. Повторные вызовы ничего не перезапускают.
func play_death() -> float:
	if _dead:
		return 0.0
	_dead = true
	for action in [&"ReloadFactor", &"AxeAttack", &"Roll"]:
		_abort(action)
	var duration := _animation_length(&"move/die")
	_play(&"DieFactor", &"DieSpeed", &"move/die", duration)
	return duration

func _animation_length(animation: StringName) -> float:
	var clip := tree.get_animation(animation)
	return clip.length if clip else 0.01

func _play(action: StringName, speed: StringName, animation: StringName, duration: float) -> void:
	tree.set("parameters/%s/scale" % speed, _animation_length(animation) / maxf(duration, 0.01))
	tree.set("parameters/%s/request" % action, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func _abort(action: StringName) -> void:
	if tree.get("parameters/%s/active" % action):
		tree.set("parameters/%s/request" % action, AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
