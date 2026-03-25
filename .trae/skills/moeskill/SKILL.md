---
name: "moeskill"
description: "为Moe Social项目提供开发支持，包括初始化、功能实现、飞书文档管理、代码审查和bug修复。当用户需要为项目添加新功能或维护现有功能时调用。"
---

# Moe Social 开发助手

## 功能概述

本技能为Moe Social项目提供全方位的开发支持，包括：

1. **项目初始化**：帮助设置开发环境和项目配置
2. **功能实现**：支持添加新功能和改进现有功能
3. **AutoGLM智能助手**：集成AI驱动的智能助手系统开发
4. **飞书文档管理**：完成功能后自动创建飞书文档记录（归属于个人账号）
   - 使用 `useUAT: true` 参数确保文档创建在个人用户账号下，而不是飞书机器人账号
   - 确保文档内容完整，包含功能实现、技术细节和优化点
5. **文档检索**：快速找到项目相关的飞书文档
6. **代码审查**：分析代码质量和潜在问题
7. **Bug修复**：识别并修复项目中的bug
8. **CI/CD流程**：支持自动化构建和发布
9. **多平台支持**：确保在Android、iOS、Web等平台正常运行
10. **安全特性**：实现安全配置和权限管理

## 文档结构

为了方便使用和维护，我们将文档分为以下几个主要部分：

### 1. 快速开始
- [项目初始化](./docs/quickstart/initialization.md) - 环境搭建和项目启动
- [开发环境配置](./docs/quickstart/environment.md) - 前端和后端开发环境设置

### 2. 前端开发
- [Flutter基础](./docs/frontend/flutter-basics.md) - Flutter框架使用指南
- [UI组件库](./docs/frontend/ui-components.md) - 项目内置组件使用
- [页面开发](./docs/frontend/pages.md) - 页面创建和导航
- [状态管理](./docs/frontend/state-management.md) - 应用状态管理

### 3. 后端开发
- [go-zero框架](./docs/backend/go-zero.md) - go-zero框架使用指南
- [API开发](./docs/backend/api-development.md) - API接口开发流程
- [数据库操作](./docs/backend/database.md) - MySQL和GORM使用
- [WebSocket](./docs/backend/websocket.md) - 实时通信实现

### 4. AutoGLM智能助手
- [系统架构](./docs/autoglm/architecture.md) - 三层架构设计
- [核心功能](./docs/autoglm/core-features.md) - 智能任务规划和设备操作
- [API接口](./docs/autoglm/api.md) - 方法通道和事件通道
- [性能优化](./docs/autoglm/performance.md) - 执行效率和内存优化

### 5. 部署与发布
- [CI/CD流程](./docs/deployment/cicd.md) - 自动构建和发布
- [多平台构建](./docs/deployment/multi-platform.md) - 各平台构建指南
- [签名配置](./docs/deployment/signing.md) - Android签名配置
- [App更新](./docs/deployment/update.md) - 应用内更新功能

### 6. 开发规范
- [代码风格](./docs/guidelines/code-style.md) - 前端和后端代码规范
- [安全最佳实践](./docs/guidelines/security.md) - 安全开发指南
- [文档规范](./docs/guidelines/documentation.md) - 项目文档标准
- [版本控制](./docs/guidelines/version-control.md) - Git使用规范

### 7. 故障排查
- [常见问题](./docs/troubleshooting/common-issues.md) - 开发中常见问题
- [错误处理](./docs/troubleshooting/error-handling.md) - 错误定位和解决
- [性能问题](./docs/troubleshooting/performance.md) - 性能瓶颈分析

## 如何使用这些文档

1. **快速开始**：如果您是第一次接触项目，从快速开始文档入手
2. **功能开发**：根据开发需求查看相应的前端或后端文档
3. **问题解决**：遇到问题时参考故障排查文档
4. **规范遵循**：开发过程中遵循开发规范文档
5. **部署发布**：准备发布时查看部署相关文档

## 示例使用场景

### 场景1：添加新功能
1. 分析需求并确定实现方案
2. 编写代码实现功能
3. 测试功能是否正常工作
4. 调用飞书MCP创建文档记录功能实现过程（归属于个人账号）
5. 代码审查和CI/CD发布

### 场景2：修复Bug
1. 复现问题并分析根本原因
2. 设计并实施修复方案
3. 验证修复效果
4. 创建修复记录文档
5. 进行回归测试

### 场景3：AutoGLM智能助手开发
1. 设计系统架构和交互流程
2. 实现前端任务规划器和执行引擎
3. 开发Android原生无障碍服务
4. 集成AI模型和意图理解
5. 测试和性能优化

## AI项目规则限制

为确保AI在项目开发过程中的合理使用，我们制定了以下规则：

1. **代码生成规则**
   - AI生成的代码必须符合项目的代码风格和规范
   - 生成的代码必须经过人工审查才能合并到主分支
   - 禁止AI直接修改核心业务逻辑

2. **文档管理规则**
   - AI生成的文档必须经过人工审核
   - 文档内容必须准确反映项目实际情况
   - 禁止AI创建与项目无关的文档

3. **安全规则**
   - AI不得访问或处理敏感信息
   - 生成的代码必须符合安全最佳实践
   - 禁止AI执行可能导致安全风险的操作

4. **权限规则**
   - AI只能在指定的项目范围内活动
   - 禁止AI修改项目配置和依赖
   - AI操作必须有明确的用户授权

5. **质量控制规则**
   - AI生成的代码必须通过单元测试
   - 生成的功能必须经过集成测试
   - 禁止AI提交未经测试的代码

## 开发注意事项

### 1. 常量表达式限制
- **Colors.black.withOpacity(0.1)** 等方法调用不是常量表达式，不能在 `const` 构造函数中使用
- **Colors.grey[600]** 等索引操作也不是常量表达式，不能在 `const` 构造函数中使用
- 解决方案：将包含这些表达式的构造函数改为非 `const`，或使用常量颜色值

### 2. 布局溢出问题
- 当使用 `Row` 或 `Column` 布局时，确保内容不会超出容器宽度
- 解决方案：对长文本使用 `Expanded` 组件和 `overflow: TextOverflow.ellipsis`

### 3. 飞书文档创建
- 使用 `useUAT: true` 参数确保文档创建在个人用户账号下
- 确保文档内容完整，包含功能实现、技术细节和优化点

## 总结

本技能旨在成为Moe Social项目的智能开发助手，帮助开发者更高效地完成功能实现、代码审查和Bug修复工作，同时通过飞书文档管理保持项目知识的系统性和可追溯性。

通过结构化的文档体系和严格的AI项目规则，您可以确保AI在项目开发中发挥积极作用，同时避免潜在的风险和问题。

通过合理使用本技能，您可以快速找到所需的开发指南和参考资料，提高开发效率和代码质量，确保项目的顺利进行。