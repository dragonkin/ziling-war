extends Node2D
## 战斗单位：英雄 / 小怪 / Boss 通用基类（用 TextureRect 动态加载立绘）

@export var max_hp: int = 100
@export var is_enemy: bool = true
@export var art_path: String = ""

var hp: int = 100
var alive := true
var home_pos := Vector2.ZERO

var _sprite: TextureRect
var _hp_bar: ProgressBar
var _hp_bar_bg: ColorRect
var _shake_t := 0.0
var _hurt_flash := 0.0
var _breath_t := 0.0


## 工厂：先建节点、设参数、再入树，避免 @onready 时序问题
static func create(p_art: String, p_hp: int, p_enemy: bool, p_pos: Vector2) -> Node2D:
	var n := Node2D.new()
	n.set_script(load("res://scripts/Fighter.gd"))
	n.art_path = p_art
	n.max_hp = p_hp
	n.is_enemy = p_enemy
	n.hp = p_hp
	n.position = p_pos
	return n


func setup(p_art: String, p_hp: int, p_enemy: bool) -> void:
	art_path = p_art
	max_hp = p_hp
	is_enemy = p_enemy
	hp = p_hp


func _ready() -> void:
	home_pos = position
	_build()


func _build() -> void:
	# 立绘
	_sprite = TextureRect.new()
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if art_path != "" and ResourceLoader.exists(art_path):
		_sprite.texture = load(art_path)
	add_child(_sprite)
	# 根据立绘原始比例定尺寸，统一高度
	var target_h := 300.0
	if _sprite.texture:
		var tw: float = float(_sprite.texture.get_width())
		var th: float = float(_sprite.texture.get_height())
		var ratio: float = tw / max(1.0, th)
		_sprite.size = Vector2(target_h * ratio, target_h)
	else:
		_sprite.size = Vector2(220, target_h)
	_sprite.position = -_sprite.size * 0.5
	# 敌人朝左（翻转）
	if is_enemy:
		_sprite.scale.x = -1.0
		_sprite.position.x = -_sprite.size.x * 0.5

	# 血条（浮在头顶）
	var bw := 120.0
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.color = Color(0, 0, 0, 0.55)
	_hp_bar_bg.size = Vector2(bw + 4, 14)
	_hp_bar_bg.position = Vector2(-bw * 0.5 - 2, -_sprite.size.y * 0.5 - 34)
	add_child(_hp_bar_bg)

	_hp_bar = ProgressBar.new()
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp
	_hp_bar.show_percentage = false
	_hp_bar.size = Vector2(bw, 10)
	_hp_bar.position = Vector2(-bw * 0.5, -_sprite.size.y * 0.5 - 32)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#e24b4b") if is_enemy else Color("#4be28a")
	sb.set_corner_radius_all(3)
	_hp_bar.add_theme_stylebox_override("fill", sb)
	var sb2 := StyleBoxFlat.new()
	sb2.bg_color = Color(0.12, 0.1, 0.14, 0.9)
	sb2.set_corner_radius_all(3)
	_hp_bar.add_theme_stylebox_override("background", sb2)
	add_child(_hp_bar)


func take_damage(dmg: int) -> void:
	if not alive:
		return
	hp = max(0, hp - dmg)
	if _hp_bar:
		_hp_bar.value = hp
	_hurt_flash = 0.18
	_shake_t = 0.22
	# 受击后仰
	var t := create_tween()
	var back := 26.0 if is_enemy else -26.0
	t.tween_property(self, "position", home_pos + Vector2(back, -8), 0.07)
	t.tween_property(self, "position", home_pos, 0.12)
	if hp <= 0:
		die()


func die() -> void:
	alive = false
	Sfx.play("hit", 0.8, -4.0)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(_sprite, "modulate:a", 0.0, 0.45)
	t.tween_property(_sprite, "position:y", _sprite.position.y - 40, 0.45)
	if _hp_bar:
		t.tween_property(_hp_bar, "modulate:a", 0.0, 0.3)
	if _hp_bar_bg:
		t.tween_property(_hp_bar_bg, "modulate:a", 0.0, 0.3)


func _process(delta: float) -> void:
	_breath_t += delta
	# 呼吸 / 浮动动画（让立绘"活"起来）
	if alive and _sprite:
		var base_y := -_sprite.size.y * 0.5
		_sprite.position.y = base_y + sin(_breath_t * 2.2) * 5.0
	# 受击白闪
	if _hurt_flash > 0.0:
		_hurt_flash -= delta
		if _sprite:
			_sprite.modulate = Color(1, 1, 1) if fmod(_hurt_flash, 0.06) > 0.03 else Color(3, 0.6, 0.6)
	else:
		if _sprite:
			_sprite.modulate = Color(1, 1, 1, _sprite.modulate.a)
	# 受击震动
	if _shake_t > 0.0:
		_shake_t -= delta
		if _sprite:
			_sprite.position.x = -_sprite.size.x * 0.5 + randf_range(-5, 5)
	else:
		if _sprite:
			_sprite.position.x = -_sprite.size.x * 0.5


## 攻击动作（挥向对手方向）
func play_attack() -> void:
	var t := create_tween()
	var lunge := 40.0 if not is_enemy else -40.0
	t.tween_property(self, "position", home_pos + Vector2(lunge, 0), 0.09)
	t.tween_property(self, "position", home_pos, 0.14)
