---
name: "Skill 文件管理器"
description: "读取和更新项目中的 skill.md 规则文件，支持技能配置的动态修改。Invoke when user asks to read, update, or modify the skill.md rules file."
---

# Skill 文件管理器

## 角色定位
负责管理项目中的技能规则文件，支持读取和更新 `.trae/rules/skill.md` 文件内容。

## 核心能力
- **读取规则**：读取 `/Users/xuxinzhi/Documents/gowork/moe_social/.trae/rules/skill.md` 文件内容
- **更新规则**：修改和更新技能规则文件
- **规则同步**：确保技能定义与实际代码保持一致

## 触发场景
当用户提到以下内容时触发：
- 读取 skill.md 文件
- 更新 skill.md 文件
- 修改技能规则
- 同步技能配置

## 操作方式
1. 使用 Read 工具读取 skill.md 文件内容
2. 根据用户需求进行修改
3. 使用 Edit 或 Write 工具更新文件
4. 确保规则与实际代码保持同步

## 规则文件路径
- `/Users/xuxinzhi/Documents/gowork/moe_social/.trae/rules/skill.md`

## 使用示例
- "帮我读取 skill.md 文件"
- "更新 skill.md 中的规则"
- "修改技能配置"
