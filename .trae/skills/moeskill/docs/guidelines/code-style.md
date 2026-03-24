# 代码风格规范

## 概述

统一的代码风格有助于提高代码的可读性、可维护性和一致性。本指南将详细介绍Moe Social项目的代码风格规范。

## 前端代码风格

### Flutter/Dart 代码风格

#### 1. 命名规范

- **类名**：使用大驼峰命名法（PascalCase）
  ```dart
  class UserProfilePage extends StatelessWidget {
    // ...
  }
  ```

- **方法名**：使用小驼峰命名法（camelCase）
  ```dart
  void updateUserProfile() {
    // ...
  }
  ```

- **变量名**：使用小驼峰命名法（camelCase）
  ```dart
  String userName = 'John';
  ```

- **常量**：使用全大写字母，单词间用下划线分隔
  ```dart
  const MAX_USER_AGE = 100;
  ```

- **私有成员**：使用下划线前缀
  ```dart
  int _privateVariable = 0;
  
  void _privateMethod() {
    // ...
  }
  ```

#### 2. 代码格式

- **缩进**：使用2个空格进行缩进
- **行长度**：每行不超过80个字符
- **空行**：
  - 在方法之间添加空行
  - 在逻辑块之间添加空行
  - 在类的成员之间添加空行

- **括号**：
  - 左括号与语句在同一行
  - 右括号单独占一行
  ```dart
  if (condition) {
    // 代码
  }
  ```

- **分号**：每条语句结束后添加分号

#### 3. 代码组织

- **导入顺序**：
  1. Dart核心库
  2. 第三方库
  3. 本地库
  4. 相对路径导入

  ```dart
  import 'dart:async';
  import 'package:flutter/material.dart';
  import 'package:provider/provider.dart';
  import 'package:moe_social/models/user.dart';
  import 'user_profile.dart';
  ```

- **文件组织**：
  - 每个文件只包含一个主要类
  - 文件名与类名保持一致
  - 相关功能放在同一目录下

#### 4. 注释规范

- **类注释**：使用文档注释（///）
  ```dart
  /// 用户个人资料页面
  ///
  /// 显示用户的个人信息和相关操作
  class UserProfilePage extends StatelessWidget {
    // ...
  }
  ```

- **方法注释**：使用文档注释（///）
  ```dart
  /// 更新用户资料
  ///
  /// [userData]：用户数据
  /// 返回：更新是否成功
  Future<bool> updateUserProfile(Map<String, dynamic> userData) async {
    // ...
  }
  ```

- **行注释**：使用单行注释（//）
  ```dart
  // 检查用户是否已登录
  if (user != null) {
    // ...
  }
  ```

#### 5. 最佳实践

- **使用const构造器**：对于不变的widget使用const构造器
  ```dart
  const Text('Hello World');
  ```

- **使用null safety**：利用Dart的空安全特性
  ```dart
  String? nullableString;
  String nonNullableString = 'Default';
  ```

- **避免使用print**：使用日志库进行日志记录
  ```dart
  // 避免
  print('Debug info');
  
  // 推荐
  logger.info('Debug info');
  ```

- **使用级联操作符**：对于多个连续操作使用级联操作符
  ```dart
  final user = User()
    ..name = 'John'
    ..age = 30
    ..email = 'john@example.com';
  ```

## 后端代码风格

### Go 代码风格

#### 1. 命名规范

- **包名**：使用小写字母，单词间用下划线分隔
  ```go
  package user_service
  ```

- **结构体名**：使用大驼峰命名法（PascalCase）
  ```go
  type User struct {
    // ...
  }
  ```

- **方法名**：使用大驼峰命名法（PascalCase）
  ```go
  func (u *User) GetProfile() {
    // ...
  }
  ```

- **变量名**：使用小驼峰命名法（camelCase）
  ```go
  userName := "John"
  ```

- **常量**：使用全大写字母，单词间用下划线分隔
  ```go
  const MaxUserAge = 100
  ```

- **接口名**：使用大驼峰命名法（PascalCase），通常以er结尾
  ```go
  type UserRepository interface {
    // ...
  }
  ```

#### 2. 代码格式

- **缩进**：使用4个空格进行缩进
- **行长度**：每行不超过80个字符
- **空行**：
  - 在函数之间添加空行
  - 在逻辑块之间添加空行
  - 在包声明和导入之间添加空行

- **括号**：
  - 左括号与语句在同一行
  - 右括号单独占一行
  ```go
  if condition {
    // 代码
  }
  ```

- **分号**：Go语言自动添加分号，通常不需要手动添加

#### 3. 代码组织

- **导入顺序**：
  1. 标准库
  2. 第三方库
  3. 本地库

  ```go
  import (
    "fmt"
    "net/http"
    
    "github.com/gin-gonic/gin"
    "gorm.io/gorm"
    
    "moe_social/backend/model"
  )
  ```

- **文件组织**：
  - 每个文件只包含一个主要功能
  - 相关功能放在同一目录下
  - 遵循go-zero的目录结构

#### 4. 注释规范

- **包注释**：在包声明前添加注释
  ```go
  // user_service 提供用户相关的服务
  package user_service
  ```

- **函数注释**：使用文档注释
  ```go
  // GetUserByID 根据ID获取用户信息
  // id: 用户ID
  // 返回: 用户信息和错误
  func GetUserByID(id uint) (*User, error) {
    // ...
  }
  ```

- **行注释**：使用单行注释（//）
  ```go
  // 检查用户是否存在
  if user == nil {
    // ...
  }
  ```

#### 5. 最佳实践

- **错误处理**：及时处理错误，不要忽略错误
  ```go
  user, err := GetUserByID(id)
  if err != nil {
    return nil, err
  }
  ```

- **使用context**：在函数中传递context
  ```go
  func GetUserByID(ctx context.Context, id uint) (*User, error) {
    // ...
  }
  ```

- **避免全局变量**：尽量使用依赖注入
  ```go
  type UserService struct {
    repo UserRepository
  }
  
  func NewUserService(repo UserRepository) *UserService {
    return &UserService{repo: repo}
  }
  ```

- **使用结构体标签**：为结构体字段添加标签
  ```go
  type User struct {
    ID   uint   `json:"id" gorm:"primaryKey"`
    Name string `json:"name" gorm:"size:50;not null"`
  }
  ```

## 通用代码风格

### 1. 代码质量

- **代码简洁**：保持代码简洁明了，避免冗余代码
- **代码可读性**：使用有意义的变量名和函数名
- **代码复用**：提取重复代码为函数或方法
- **代码测试**：为代码编写测试

### 2. 安全性

- **输入验证**：验证所有用户输入
- **防止SQL注入**：使用参数化查询
- **防止XSS攻击**：对输出进行转义
- **密码安全**：使用安全的密码存储方式

### 3. 性能

- **避免不必要的计算**：缓存计算结果
- **优化数据库查询**：使用索引，避免全表扫描
- **减少网络请求**：合并请求，使用缓存
- **优化内存使用**：及时释放不需要的资源

### 4. 版本控制

- **提交信息**：使用清晰的提交信息
- **分支管理**：遵循分支管理策略
- **代码审查**：进行代码审查

## 代码审查

### 1. 审查标准

- **代码风格**：是否符合代码风格规范
- **代码质量**：是否存在冗余、复杂的代码
- **安全性**：是否存在安全漏洞
- **性能**：是否存在性能问题
- **测试**：是否有足够的测试覆盖

### 2. 审查流程

1. **提交代码**：开发者提交代码到feature分支
2. **创建PR**：创建Pull Request
3. **代码审查**：其他开发者审查代码
4. **修复问题**：开发者修复审查中发现的问题
5. **合并代码**：审查通过后合并代码

## 工具和配置

### 1. 前端工具

- **Dartfmt**：自动格式化Dart代码
  ```bash
  dart format .
  ```

- **Flutter lints**：代码风格检查
  ```bash
  flutter analyze
  ```

- **EditorConfig**：统一编辑器配置
  ```ini
  # .editorconfig
  root = true

  [*.dart]
  indent_style = space
  indent_size = 2
  line_length = 80
  trim_trailing_whitespace = true
  insert_final_newline = true
  ```

### 2. 后端工具

- **Go fmt**：自动格式化Go代码
  ```bash
  go fmt ./...
  ```

- **Go lint**：代码风格检查
  ```bash
  golint ./...
  ```

- **EditorConfig**：统一编辑器配置
  ```ini
  # .editorconfig
  root = true

  [*.go]
  indent_style = space
  indent_size = 4
  line_length = 80
  trim_trailing_whitespace = true
  insert_final_newline = true
  ```

## 总结

统一的代码风格是团队协作的重要基础，有助于提高代码质量和开发效率。本指南提供了详细的代码风格规范，希望团队成员能够严格遵守，共同维护高质量的代码库。

在实际开发中，应不断总结和改进代码风格规范，以适应项目的发展和变化。