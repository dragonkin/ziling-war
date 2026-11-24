# 字灵战记

Godot 4.4 街机识字游戏。把生字学习做成街机式战斗，面向小学低年级。

## 玩法

每一关出现生字，玩家在限定时间内选出正确读音 / 字形，触发角色释放连招击败「字灵」。
生字库与关卡由 `data/*.json` 定义，可按教学进度替换。

## 目录结构

- `scripts/` — GDScript 脚本（地形、大招、切场等）
- `scenes/` — 场景文件
- `data/` — 关卡与字库数据（JSON）
- `assets/` — 美术与音频
  - `heroes/` `char/` `roster/` `raw*/` — 角色立绘与原始素材
  - `bg2/` `bg3/` — 背景贴图
  - `fx/` — 特效
  - `voice2/` `voice_story/` — 语音
  - `fonts/` — 字体（霞鹜文楷）

## 未纳入版本管理

以下目录体积大且可重建，已通过 `.gitignore` 排除：

- `tools/` — Godot 编辑器本体与下载缓存（约 1.4 GB）
- `.godot/` — 导入缓存（可由 `.import` 侧车文件重建）
- `shots/` — 调试截图

## 运行

使用 Godot 4.4.1 打开 `project.godot`。导出模板位于 `%APPDATA%\Godot\export_templates\4.4.1.stable\`。

## 层级约定

`BG=-1000` < `Terrain=-20` < `Ambience=-10` < 角色 `int(y)` < `Foreground=4000`。
