# Godot 原生回测

这个目录只用于验收工作台导出的 `spritesheet.png` 和 `spritesheet.json`，不是第二套动画编辑器。Godot 的 `Sprite2D` / `AnimatedSprite2D`、网格裁剪和动画播放均使用 Godot 原生能力；本工具只负责把源图片整理成标准透明序列帧。

工作台负责图片整理、透明蒙版、统一画布和导出；Godot 使用原生 `Sprite2D` 的 `hframes` / `vframes` 读取网格。回测脚本只验证真实导出能被加载、逐帧切换、顺序正确且每个 cell 存在可见像素。
