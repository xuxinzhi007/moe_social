# Implementation Plan: Profile Editor Enhancement

## Overview

本实现计划将分为后端和前端两部分，先完成后端API的扩展，再实现前端的UI优化和功能增强。

## Tasks

- [ ] 1. 后端：扩展用户模型和API
  - 添加新字段到 User 模型
  - 更新 UpdateUserInfo API
  - 添加数据库迁移
  - _Requirements: 3.1, 3.2, 3.3, 8.1, 8.2_

- [x] 1.1 添加用户模型新字段
  - 在 `backend/model/user.go` 中添加 `Signature`、`Gender`、`Birthday` 字段
  - 添加字段验证标签（长度限制、枚举值等）
  - _Requirements: 3.1, 3.2, 3.3_

- [x] 1.2 更新 API 定义
  - 在 `backend/api/super.api` 中更新 `UpdateUserInfoReq` 结构
  - 添加 `Signature`、`Gender`、`Birthday` 字段（设为 optional）
  - 更新 `User` 响应结构包含新字段
  - _Requirements: 3.5, 8.1_

- [ ] 1.3 重新生成 API 代码
  - 运行 `backend/api/generate_api.sh` 重新生成 API 代码
  - 运行 `backend/rpc/generate_rpc.sh` 重新生成 RPC 代码
  - _Requirements: 8.1_

- [ ] 1.4 更新 RPC 逻辑
  - 在 `backend/rpc/internal/logic/updateuserinfologic.go` 中添加新字段处理
  - 添加签名长度验证（最多100字符）
  - 添加性别枚举验证（male/female/secret）
  - 添加生日日期解析和验证
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 4.1_

- [ ]* 1.5 编写后端单元测试
  - 测试新字段的保存和读取
  - 测试签名长度限制
  - 测试性别枚举验证
  - 测试生日日期格式
  - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [ ] 1.6 创建数据库迁移脚本
  - 创建 SQL 迁移脚本添加新字段
  - 测试迁移脚本在开发环境
  - _Requirements: 3.1, 3.2, 3.3_

- [ ] 2. Checkpoint - 后端API测试
  - 使用 Postman 或 curl 测试更新后的 API
  - 确保新字段能正确保存和返回
  - 确保向后兼容性（不传新字段也能正常工作）
  - 询问用户是否有问题

- [ ] 3. 前端：扩展用户模型
  - 更新 Dart User 模型
  - 更新 API Service
  - _Requirements: 3.5, 8.2, 8.3_

- [ ] 3.1 更新 User 模型
  - 在 `lib/models/user.dart` 中添加 `signature`、`gender`、`birthday` 字段
  - 更新 `fromJson` 方法解析新字段
  - 更新 `toJson` 方法包含新字段
  - _Requirements: 3.5, 8.2_

- [ ] 3.2 更新 API Service
  - 在 `lib/services/api_service.dart` 中更新 `updateUserInfo` 方法
  - 添加 `signature`、`gender`、`birthday` 参数
  - 确保向后兼容（参数为可选）
  - _Requirements: 3.5, 8.1_

- [ ]* 3.3 编写模型单元测试
  - 测试 User 模型的 JSON 序列化和反序列化
  - 测试新字段的正确解析
  - 测试缺少新字段时的默认值处理
  - _Requirements: 8.2, 8.3_

- [ ] 4. 前端：创建可复用组件
  - 创建验证输入框组件
  - 创建性别选择器组件
  - 创建生日选择器组件
  - _Requirements: 3.2, 3.3, 4.1, 4.2_

- [ ] 4.1 创建 ValidatedTextField 组件
  - 在 `lib/widgets/` 下创建 `validated_text_field.dart`
  - 实现实时验证功能
  - 实现错误提示显示
  - 实现字符计数显示（可选）
  - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [ ] 4.2 创建 GenderSelector 组件
  - 在 `lib/widgets/` 下创建 `gender_selector.dart`
  - 实现三个选项：男/女/保密
  - 使用 Material Design 风格
  - _Requirements: 3.2_

- [ ] 4.3 创建 BirthdayPicker 组件
  - 在 `lib/widgets/` 下创建 `birthday_picker.dart`
  - 使用 Flutter 的 DatePicker
  - 限制日期范围（例如：1900年至今天）
  - _Requirements: 3.3_

- [ ]* 4.4 编写组件单元测试
  - 测试 ValidatedTextField 的验证逻辑
  - 测试 GenderSelector 的选择功能
  - 测试 BirthdayPicker 的日期选择
  - _Requirements: 4.1, 4.2, 3.2, 3.3_

- [ ] 5. 前端：重构 EditProfilePage
  - 重构页面布局
  - 添加新字段
  - 实现数据变更检测
  - _Requirements: 1.1, 3.1, 3.2, 3.3, 6.1, 6.2_

- [ ] 5.1 重构页面布局结构
  - 使用卡片式布局分区（头像区、基本信息区、账户信息区）
  - 优化间距和视觉层次
  - 添加底部固定的保存按钮
  - _Requirements: 1.1, 5.1_

- [ ] 5.2 实现头像区域
  - 显示当前头像
  - 添加"选择图片"和"输入URL"两个选项
  - 实现图片预览功能
  - _Requirements: 2.1, 2.2_

- [ ] 5.3 添加基本信息字段
  - 使用 ValidatedTextField 替换原有的 TextFormField
  - 添加个性签名输入框（带字符计数）
  - 添加性别选择器
  - 添加生日选择器
  - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [ ] 5.4 实现数据变更检测
  - 在 initState 中记录初始数据
  - 监听所有字段的变化
  - 实现 `_detectChanges()` 方法
  - 根据变更状态启用/禁用保存按钮
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [ ]* 5.5 编写页面单元测试
  - 测试页面初始化
  - 测试数据变更检测
  - 测试保存按钮状态
  - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [ ] 6. 前端：实现表单验证
  - 实现用户名验证
  - 实现邮箱验证
  - 实现签名验证
  - 实现验证反馈显示
  - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

- [ ] 6.1 实现验证规则
  - 在 `lib/utils/validators.dart` 中添加签名验证方法
  - 添加性别验证方法
  - 优化现有的用户名和邮箱验证
  - _Requirements: 4.1, 4.2, 3.4_

- [ ]* 6.2 编写验证属性测试
  - **Property 5: Username Validation**
  - 生成随机用户名测试验证规则
  - 验证3-20字符、字母数字下划线的规则
  - **Validates: Requirements 4.1**

- [ ]* 6.3 编写邮箱验证属性测试
  - **Property 6: Email Validation**
  - 生成随机邮箱测试验证规则
  - 验证邮箱格式的正确性
  - **Validates: Requirements 4.2**

- [ ]* 6.4 编写签名验证属性测试
  - **Property 3: Signature Character Limit**
  - 生成随机长度的签名测试字符限制
  - 验证100字符限制和字符计数显示
  - **Validates: Requirements 3.4**

- [ ] 6.5 实现验证反馈UI
  - 在 ValidatedTextField 中实现错误提示显示
  - 实现成功状态显示（绿色边框或图标）
  - 实现字符计数显示
  - _Requirements: 4.3, 4.4, 3.4_

- [ ]* 6.6 编写验证反馈属性测试
  - **Property 7: Validation Feedback Display**
  - 测试任意无效输入显示错误提示
  - 测试任意有效输入移除错误提示
  - **Validates: Requirements 4.3, 4.4**

- [ ] 6.7 实现表单提交验证
  - 在保存前验证所有字段
  - 阻止无效数据提交
  - 高亮显示错误字段
  - 滚动到第一个错误字段
  - _Requirements: 4.5_

- [ ]* 6.8 编写提交验证属性测试
  - **Property 8: Invalid Data Submission Prevention**
  - 生成各种无效数据组合
  - 验证表单阻止提交
  - **Validates: Requirements 4.5**

- [ ] 7. Checkpoint - 表单验证测试
  - 手动测试所有验证规则
  - 测试错误提示显示
  - 测试无效数据提交阻止
  - 询问用户是否有问题

- [ ] 8. 前端：实现头像上传功能
  - 实现图片选择
  - 实现图片上传
  - 实现上传进度显示
  - 实现错误处理
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

- [ ] 8.1 实现图片选择功能
  - 使用 `image_picker` 包选择图片
  - 实现图片预览
  - 添加图片大小和格式验证
  - _Requirements: 2.1, 2.2_

- [ ]* 8.2 编写图片预览属性测试
  - **Property 2: Avatar Preview Display**
  - 生成随机图片文件
  - 验证预览是否正确显示
  - **Validates: Requirements 2.2**

- [ ] 8.3 实现图片上传功能
  - 调用 `ApiService.uploadImage` 方法
  - 实现上传进度显示
  - 处理上传成功和失败
  - _Requirements: 2.3, 2.4, 2.5_

- [ ]* 8.4 编写图片上传属性测试
  - **Property 1: Avatar Upload Success**
  - 生成随机有效图片数据
  - 验证上传成功返回URL
  - **Validates: Requirements 2.3**

- [ ] 8.5 实现URL输入功能
  - 添加URL输入对话框
  - 验证URL格式
  - 实现URL预览
  - _Requirements: 2.1, 2.2_

- [ ] 8.6 实现头像上传错误处理
  - 显示上传失败提示
  - 保留原头像
  - 提供重试选项
  - _Requirements: 2.4, 7.5_

- [ ] 9. 前端：实现保存功能
  - 实现保存逻辑
  - 实现加载状态
  - 实现成功反馈
  - 实现错误处理
  - _Requirements: 5.2, 5.3, 5.4, 7.1, 7.2, 7.3, 7.4_

- [ ] 9.1 实现保存逻辑
  - 收集所有字段数据
  - 如果有本地图片，先上传获取URL
  - 调用 `ApiService.updateUserInfo` 提交数据
  - _Requirements: 3.5, 5.2_

- [ ]* 9.2 编写字段提交属性测试
  - **Property 4: All Fields Submission**
  - 生成随机字段组合
  - 验证所有修改的字段都包含在API请求中
  - **Validates: Requirements 3.5**

- [ ] 9.3 实现保存状态管理
  - 显示加载动画
  - 禁用所有交互
  - 禁用保存按钮
  - _Requirements: 5.2_

- [ ] 9.4 实现保存成功处理
  - 显示成功提示（SnackBar）
  - 返回上一页面
  - 传递更新标志
  - _Requirements: 5.3_

- [ ] 9.5 实现保存错误处理
  - 处理网络错误
  - 处理服务器错误
  - 处理特定错误（用户名占用、邮箱占用）
  - 显示友好的错误提示
  - _Requirements: 5.4, 7.1, 7.2, 7.3, 7.4_

- [ ]* 9.6 编写错误处理属性测试
  - **Property 11: Server Error Display**
  - 生成各种服务器错误响应
  - 验证错误信息正确显示
  - **Validates: Requirements 7.2**

- [ ] 10. 前端：实现未保存变更提示
  - 实现返回拦截
  - 显示确认对话框
  - 处理用户选择
  - _Requirements: 6.5_

- [ ] 10.1 实现返回拦截
  - 使用 `WillPopScope` 拦截返回操作
  - 检查是否有未保存的变更
  - 如果有变更，显示确认对话框
  - _Requirements: 6.5_

- [ ] 10.2 实现确认对话框
  - 显示"保存"、"放弃"、"取消"三个选项
  - 处理"保存"：执行保存逻辑
  - 处理"放弃"：直接返回
  - 处理"取消"：留在当前页面
  - _Requirements: 6.5_

- [ ]* 10.3 编写变更检测属性测试
  - **Property 9: Change Detection**
  - 生成随机字段修改
  - 验证变更检测正确性
  - **Validates: Requirements 6.2**

- [ ]* 10.4 编写按钮状态属性测试
  - **Property 10: Save Button State Management**
  - 测试有变更时按钮启用
  - 测试无变更时按钮禁用
  - **Validates: Requirements 6.3, 6.4**

- [ ] 11. Checkpoint - 完整流程测试
  - 测试完整的编辑和保存流程
  - 测试头像上传（本地图片和URL）
  - 测试所有新字段的保存
  - 测试数据变更检测
  - 测试未保存变更提示
  - 测试各种错误场景
  - 询问用户是否有问题

- [ ] 12. 前端：优化和完善
  - 优化UI细节
  - 添加动画效果
  - 优化性能
  - _Requirements: 1.2, 1.3, 1.4_

- [ ] 12.1 优化UI细节
  - 调整间距和对齐
  - 优化颜色和字体
  - 添加阴影和圆角
  - 确保Material Design一致性
  - _Requirements: 1.2_

- [ ] 12.2 添加动画效果
  - 添加页面过渡动画
  - 添加按钮点击动画
  - 添加加载动画
  - 添加错误提示动画
  - _Requirements: 1.3_

- [ ] 12.3 优化性能
  - 使用 `debounce` 延迟验证
  - 使用 `CachedNetworkImage` 缓存头像
  - 优化图片上传前压缩
  - _Requirements: 1.4_

- [ ]* 12.4 编写集成测试
  - 测试完整的编辑流程
  - 测试头像上传流程
  - 测试错误恢复流程
  - _Requirements: 1.1, 2.1, 2.2, 2.3, 3.1, 3.2, 3.3_

- [ ] 13. Final Checkpoint - 全面测试
  - 在多个设备上测试（Android、iOS、Web）
  - 测试不同屏幕尺寸的适配
  - 测试网络不稳定情况
  - 测试向后兼容性
  - 确保所有测试通过
  - 询问用户是否满意

## Notes

- 任务标记 `*` 的为可选任务，可以跳过以加快MVP开发
- 每个任务都引用了具体的需求编号，便于追溯
- Checkpoint 任务确保增量验证
- 属性测试验证通用正确性属性
- 单元测试验证具体示例和边界情况
- 集成测试验证端到端流程
