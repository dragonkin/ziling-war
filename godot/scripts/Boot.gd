extends Node
## 启动引导：闪一下 logo 后进主菜单（也用来做首帧初始化）

func _ready() -> void:
	await get_tree().create_timer(0.1).timeout
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
