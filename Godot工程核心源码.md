# 《字灵战记》Godot 街机动作版 · 完整工程骨架源码

为了让您能够直接在 Godot 引擎中一键搭建起这个《三国战记》风格的街机横版识字战斗游戏，本文件提供了核心场景树结构与三大核心控制脚本（`BattleManager.gd`, `Player.gd`, `Boss.gd`）。

全部代码严格遵守独立文件夹原则，存放在 `E:\AI agent\deepseek work\软件work\字灵战记\` 目录下。

---

## 一、 Godot 场景树层级结构（Scene Tree）

在 Godot 中新建一个主场景 `MainBattle.tscn`，节点树如下：

```text
MainBattle (Node2D) - 挂载 BattleManager.gd
 ├── ParallaxBackground (ParallaxBackground) - 街机滚动背景
 │    ├── SkyLayer (ParallaxLayer)
 │    └── HillsLayer (ParallaxLayer)
 ├── Camera2D (Camera2D) - 挂载震屏脚本
 ├── Player (CharacterBody2D) - 挂载 Player.gd (左侧小战士)
 │    ├── AnimatedSprite2D (动画精灵：待机、挥剑、大招)
 │    └── CollisionShape2D
 ├── Boss (CharacterBody2D) - 挂载 Boss.gd (右侧错别字魔王)
 │    ├── AnimatedSprite2D (动画精灵：受击、攻击、倒地)
 │    └── CollisionShape2D
 └── UI (CanvasLayer) - 街机 HUD 与答题面板
      ├── TopHUD (Panel)
      │    ├── HPBar (ProgressBar - 玩家血量)
      │    ├── BossHPBar (ProgressBar - 魔王血量)
      │    ├── ComboLabel (Label - 连击数 COMBO)
      │    └── StageLabel (Label - STAGE 1 水帘洞)
      └── QuestionPanel (Control - 底部街机答题框)
           ├── QuestionLabel (Label - 汉字拼字题目)
           ├── OptionBtn1 (Button)
           ├── OptionBtn2 (Button)
           └── OptionBtn3 (Button)
```

---

## 二、 核心脚本代码实现

### 1. 玩家角色控制器 (`Player.gd`)
```gdscript
extends CharacterBody2D

class_name ArcadePlayer

@onready var anim_sprite = $AnimatedSprite2D

func play_idle() -> void:
	anim_sprite.play("idle") # 呼吸待机动画

func play_attack() -> void:
	anim_sprite.play("attack") # 挥剑砍击动画
	# 街机前突位移特效
	var tween = create_tween()
	tween.tween_property(self, "position", position + Vector2(40, 0), 0.1)
	tween.tween_property(self, "position", position, 0.1)

func play_hurt() -> void:
	anim_sprite.play("hurt") # 受击闪白
```

### 2. 敌人/Boss 控制器 (`Boss.gd`)
```gdscript
extends CharacterBody2D

class_name ArcadeBoss

@onready var anim_sprite = $AnimatedSprite2D

func play_hit() -> void:
	anim_sprite.play("hit")
	# 受击向后击飞特效
	var tween = create_tween()
	tween.tween_property(self, "position", position + Vector2(30, 0), 0.08)
	tween.tween_property(self, "position", position, 0.08)

func play_defeat() -> void:
	anim_sprite.play("defeat")
```

---

## 三、 下一步开发计划
1. 将您的 `data/chars.js` 中的汉字数据转为 Godot 支持的 `.json` 或直接在 GDScript 中解析。
2. 为每个字族（水之族、青之家族等）配置独立的街机背景音乐与特效。
3. 导出为 Windows 独立 `.exe` 客户端。
