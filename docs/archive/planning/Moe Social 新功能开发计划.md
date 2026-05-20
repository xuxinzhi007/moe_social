# Moe Social 前端功能开发计划（无后端）

## 项目现状分析

当前项目是一个基础的Flutter社交应用，包含以下核心功能：
- 登录/注册（内存存储）
- 首页（Banner、快捷操作、热门动态列表）
- 个人中心（静态用户信息）
- 设置页面（基础设置选项）

## 新功能设计（无后端依赖）

基于"moe_social"（萌社交）的定位，我将开发以下核心社交功能，全部使用前端本地数据模拟：

### 1. 动态发布功能
- **功能描述**：允许用户发布带文字、图片的动态内容
- **技术实现**：
  - 创建动态数据模型（内存存储）
  - 实现动态发布表单UI
  - 添加图片选择和预览功能（使用模拟数据）
  - 实现动态列表的实时更新

### 2. 动态互动功能
- **功能描述**：支持对动态进行点赞、评论和分享
- **技术实现**：
  - 添加点赞状态管理（内存存储）
  - 实现评论列表和评论发布（内存存储）
  - 添加分享功能（模拟分享）
  - 更新动态统计数据

### 3. 关注/粉丝系统
- **功能描述**：允许用户关注/取消关注其他用户，查看关注和粉丝列表
- **技术实现**：
  - 实现关注状态管理（内存存储）
  - 创建关注/粉丝数据模型
  - 添加关注/粉丝列表页面
  - 更新个人中心统计数据

### 4. 个人资料编辑功能
- **功能描述**：允许用户编辑自己的个人资料
- **技术实现**：
  - 创建资料编辑页面
  - 支持头像更换（使用模拟图片）
  - 实现资料更新功能（内存存储）
  - 同步更新个人中心显示

## 技术架构设计

### 数据模型设计
```dart
// 动态模型
class Post {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final String content;
  final List<String> images;
  final int likes;
  final int comments;
  final bool isLiked;
  final DateTime createdAt;
}

// 用户模型
class User {
  final String id;
  final String email;
  final String name;
  final String avatar;
  final int posts;
  final int following;
  final int followers;
  final DateTime createdAt;
}

// 评论模型
class Comment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String userAvatar;
  final String content;
  final DateTime createdAt;
}
```

### 存储方案
- 保持现有的内存存储方式
- 扩展AuthService为DataService，统一管理所有数据
- 所有数据在应用运行期间保存在内存中

## 实现步骤

### 第1步：扩展数据管理服务
- 扩展AuthService为DataService，添加动态、用户、评论的数据管理
- 实现内存数据存储和管理
- 添加模拟数据生成功能

### 第2步：实现动态发布功能
- 创建`post_create_page.dart`发布页面
- 实现动态发布表单
- 添加图片选择模拟功能
- 实现动态列表更新

### 第3步：实现动态互动功能
- 改进首页动态卡片，添加点赞、评论、分享按钮
- 实现点赞状态切换和计数
- 创建评论列表组件和评论发布功能
- 添加分享功能模拟

### 第4步：实现关注/粉丝系统
- 添加关注/取消关注按钮
- 实现关注状态管理
- 创建关注和粉丝列表页面
- 更新个人中心统计数据

### 第5步：实现个人资料编辑功能
- 创建`profile_edit_page.dart`编辑页面
- 实现头像更换功能（模拟）
- 支持编辑用户名等信息
- 同步更新个人中心显示

## 预期效果

通过开发这些新功能，Moe Social将从一个基础的展示应用转变为一个完整的社交平台前端，具有以下特点：

1. **完整的社交互动**：用户可以发布、点赞、评论动态
2. **真实的社交关系**：实现关注/粉丝系统
3. **个性化资料**：用户可以自由编辑个人资料
4. **流畅的用户体验**：良好的交互设计和响应式布局
5. **无后端依赖**：所有功能使用前端本地数据模拟
6. **可扩展架构**：为后续添加后端支持奠定基础

这些功能将使Moe Social成为一个功能完整的社交应用前端原型，展示核心社交功能的实现。