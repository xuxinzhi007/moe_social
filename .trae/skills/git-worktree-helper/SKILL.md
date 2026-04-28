---
name: "Git Worktree 开发助手"
description: "基于 Git Worktree 提供分支管理和开发支持，自动创建包含原分支名称的开发分支、在独立目录中开发、合并修复并清理临时分支。Invoke when user needs to develop new features or fix bugs."
---

# Git Worktree 开发助手

## 角色定位
为 Moe Social 项目提供 Git Worktree 分支管理支持，简化功能开发和 bug 修复流程，确保开发环境隔离。

## 核心能力
- **创建开发分支**：基于当前分支创建新的功能/修复分支（命名格式：feature/ai-<原分支名>-<功能名> 或 fix/ai-<原分支名>-<问题描述>）
- **创建 Worktree**：在独立目录中创建 worktree，不影响当前工作目录的修改
- **分支开发支持**：在独立 worktree 中进行开发，原目录代码不受影响
- **代码验证**：开发完成后执行代码分析和编译验证
- **代码合并**：验证通过后合并到原分支（根据分支名称识别目标分支）
- **分支清理**：合并成功后删除临时开发分支和 worktree

## 触发场景
当用户提到以下内容时触发：
- 开发新功能
- 修复 bug
- 创建分支
- 创建 worktree
- 合并代码
- 清理分支

## 工作流程

### 1. 创建开发分支和 Worktree

```bash
# 获取当前分支名称
current_branch=$(git rev-parse --abbrev-ref HEAD)

# 创建开发分支（包含原分支名称）
git checkout -b feature/ai-${current_branch}-<功能名>
# 或
git checkout -b fix/ai-${current_branch}-<问题描述>

# 切换回原分支（保留当前修改）
git checkout ${current_branch}

# 在独立目录创建 worktree
git worktree add ../moe_social_<功能名> feature/ai-${current_branch}-<功能名>
```

### 2. 开发阶段

```bash
# 切换到 worktree 目录进行开发
cd ../moe_social_<功能名>
# 在独立环境中修改代码，不影响原目录
```

### 3. 代码验证（关键步骤）

开发完成后，**必须先验证代码**：

```bash
# 1. 运行代码分析
flutter analyze

# 2. 编译验证
flutter build <platform>

# 3. 运行测试（如有）
flutter test
```

### 4. 合并确认（关键步骤）

验证通过后，**必须先确认再合并**：

```bash
# 切换到原分支
cd /Users/xuxinzhi/Documents/gowork/moe_social
git checkout ${current_branch}

# 【重要】检查分支状态和差异
git diff ${current_branch} feature/ai-${current_branch}-<功能名>

# 【重要】确认合并前的代码状态
git status

# 【重要】显示待合并的提交日志
git log --oneline ${current_branch}..feature/ai-${current_branch}-<功能名>

# 询问用户是否确认合并
# 用户确认后执行合并
git merge feature/ai-${current_branch}-<功能名> --no-ff -m "feat: 合并功能描述"
```

### 5. 清理分支和 Worktree（关键步骤）

**合并成功后**，才能删除临时开发分支和 worktree：

```bash
# 【重要】确认合并成功
git log --oneline -1

# 检查 worktree 状态
git worktree list

# 删除 worktree（推荐方式）
git worktree remove ../moe_social_<功能名>

# 如果目录已手动删除，清理 git 记录
git worktree prune

# 删除临时分支（先确认已合并）
git branch -d feature/ai-${current_branch}-<功能名>
```

## 分支命名规范
- **功能开发**: `feature/ai-<原分支名>-<功能名>`
- **Bug 修复**: `fix/ai-<原分支名>-<问题描述>`

## Worktree 目录命名规范
- **功能开发**: `../moe_social_<功能名>`
- **Bug 修复**: `../moe_social_fix_<问题描述>`

## 使用示例
- 当前分支: `main`，"帮我开发一个新功能：用户头像上传" → 创建 `feature/ai-main-user-avatar-upload` 和 `../moe_social_user-avatar-upload`
- 当前分支: `develop`，"修复登录页面的 bug" → 创建 `fix/ai-develop-login-page-bug` 和 `../moe_social_fix_login-page-bug`
- "合并当前分支到原分支" → 从分支名称提取原分支，验证代码并确认后合并
- "删除临时分支" → 确认合并成功后删除 ai 分支和 worktree

## 关键优势
- **环境隔离**：在独立目录中开发，不影响原分支的未提交修改
- **无需 stash**：不用暂存代码，修改安全保留
- **共享仓库**：底层共享同一个 git 仓库，提交自动同步
- **智能识别**：通过分支名称自动识别原分支，方便合并
- **安全验证**：合并前自动执行代码分析和编译验证

## 注意事项
- 创建 worktree 前会检查当前工作目录状态，保留未提交修改
- **合并前必须执行代码验证（analyze + build）**
- **合并前必须显示分支差异并获得用户确认**
- **删除分支前必须确认分支已成功合并**
- worktree 目录创建在项目同级目录

## 典型场景示例
1. **新功能开发**：用户需要开发新功能，自动创建 feature/ai-xxx 分支和独立 worktree
2. **Bug 修复**：用户报告问题，创建 fix/ai-xxx 分支和独立 worktree 进行修复
3. **代码审查**：在独立 worktree 中进行审查，验证通过后合并
4. **临时测试**：创建临时分支和 worktree 进行测试，完成后清理

## 安全检查清单

在执行合并和删除操作前，必须完成以下检查：

| 步骤 | 操作 | 检查内容 |
|------|------|----------|
| 1 | `flutter analyze` | 代码分析无错误 |
| 2 | `flutter build` | 编译通过 |
| 3 | `git diff` | 确认合并内容符合预期 |
| 4 | `git status` | 工作目录干净，无冲突 |
| 5 | 用户确认 | 获得用户明确同意 |
| 6 | `git log` | 确认合并成功 |
| 7 | 删除分支 | 确认合并成功后执行 |