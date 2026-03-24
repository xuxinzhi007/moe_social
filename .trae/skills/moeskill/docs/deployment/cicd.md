# CI/CD 流程

## 概述

Moe Social项目使用CI/CD（持续集成/持续部署）流程来自动化构建、测试和发布过程。本指南将详细介绍项目的CI/CD配置和最佳实践。

## CI/CD 工具

项目使用以下CI/CD工具：

- **GitHub Actions**：用于自动化构建、测试和发布
- **Flutter CI**：用于Flutter应用的构建和测试
- **Go CI**：用于Go后端的构建和测试

## 配置文件

### GitHub Actions 配置

项目的GitHub Actions配置文件位于 `.github/workflows/flutter-release.yml`：

```yaml
name: Flutter Release

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - name: Set up Flutter
      uses: subosito/flutter-action@v2
      with:
        flutter-version: '3.10.0'

    - name: Install dependencies
      run: flutter pub get

    - name: Run tests
      run: flutter test

    - name: Build web
      run: flutter build web

    - name: Build Android
      run: flutter build apk

    - name: Build iOS
      run: flutter build ios --no-codesign

    - name: Upload artifacts
      uses: actions/upload-artifact@v3
      with:
        name: build-artifacts
        path: |
          build/web
          build/app/outputs/apk/release
          build/ios/iphoneos
```

## 构建流程

### 1. 代码提交

当开发者向GitHub仓库提交代码时，GitHub Actions会自动触发构建流程。

### 2. 环境设置

- **设置Flutter**：安装指定版本的Flutter
- **设置Go**：安装指定版本的Go
- **安装依赖**：安装项目依赖

### 3. 代码检查

- **代码分析**：运行静态代码分析
- **单元测试**：运行单元测试
- **集成测试**：运行集成测试

### 4. 构建应用

- **Web构建**：构建Web版本
- **Android构建**：构建Android APK
- **iOS构建**：构建iOS应用
- **后端构建**：构建Go后端服务

### 5. 发布流程

- **版本号生成**：根据提交记录生成版本号
- **应用签名**：对Android和iOS应用进行签名
- **发布到应用商店**：发布到Google Play和App Store
- **部署后端**：部署后端服务到服务器

## 分支策略

### 分支管理

- **main**：主分支，用于生产环境
- **develop**：开发分支，用于集成测试
- **feature/**：功能分支，用于开发新功能
- **hotfix/**：热修复分支，用于修复生产环境问题

### 合并流程

1. **功能开发**：在feature分支上开发新功能
2. **代码审查**：创建Pull Request进行代码审查
3. **测试**：GitHub Actions自动运行测试
4. **合并**：测试通过后合并到develop分支
5. **发布**：从develop分支合并到main分支进行发布

## 环境管理

### 环境变量

项目使用环境变量来管理不同环境的配置：

- **开发环境**：`development`
- **测试环境**：`staging`
- **生产环境**：`production`

### 配置文件

- **`lib/config/app_config.dart`**：Flutter应用配置
- **`backend/config/config.yaml`**：Go后端配置

## 测试策略

### 单元测试

- **Flutter测试**：使用Flutter测试框架
- **Go测试**：使用Go测试框架

### 集成测试

- **API测试**：测试API接口
- **UI测试**：测试用户界面
- **端到端测试**：测试完整的用户流程

### 测试覆盖率

- **Flutter测试覆盖率**：使用 `flutter test --coverage`
- **Go测试覆盖率**：使用 `go test -cover`

## 部署策略

### 后端部署

1. **构建**：构建Go后端服务
2. **打包**：打包成Docker镜像
3. **部署**：部署到服务器
4. **监控**：设置监控和告警

### 前端部署

1. **构建**：构建各平台应用
2. **签名**：对应用进行签名
3. **发布**：发布到应用商店
4. **分发**：分发给测试用户

## 监控与告警

### 监控指标

- **构建状态**：监控CI/CD构建状态
- **测试结果**：监控测试结果
- **部署状态**：监控部署状态
- **应用性能**：监控应用性能指标

### 告警机制

- **构建失败**：构建失败时发送告警
- **测试失败**：测试失败时发送告警
- **部署失败**：部署失败时发送告警
- **性能异常**：性能异常时发送告警

## 最佳实践

### 1. 自动化

- **自动构建**：代码提交后自动构建
- **自动测试**：构建后自动运行测试
- **自动部署**：测试通过后自动部署

### 2. 标准化

- **统一配置**：使用统一的CI/CD配置
- **规范流程**：遵循标准化的开发流程
- **代码规范**：使用统一的代码规范

### 3. 安全性

- **密钥管理**：安全管理API密钥和凭证
- **代码扫描**：扫描代码中的安全漏洞
- **依赖检查**：检查依赖中的安全漏洞

### 4. 可追溯性

- **版本控制**：使用Git进行版本控制
- **构建记录**：记录每次构建的详细信息
- **部署记录**：记录每次部署的详细信息

## 常见问题

### 构建失败

- **依赖问题**：检查依赖是否正确安装
- **代码错误**：检查代码中是否有错误
- **配置问题**：检查CI/CD配置是否正确

### 测试失败

- **测试用例问题**：检查测试用例是否正确
- **环境问题**：检查测试环境是否正确配置
- **代码问题**：检查代码是否符合测试要求

### 部署失败

- **服务器问题**：检查服务器是否正常运行
- **网络问题**：检查网络连接是否正常
- **配置问题**：检查部署配置是否正确

## 总结

CI/CD流程为Moe Social项目提供了自动化的构建、测试和部署能力，提高了开发效率和代码质量。通过合理的配置和最佳实践，可以确保项目的持续集成和持续部署顺利进行。

在实际开发中，应根据项目需求和团队规模，选择合适的CI/CD工具和策略，并不断优化流程，以提高开发效率和产品质量。