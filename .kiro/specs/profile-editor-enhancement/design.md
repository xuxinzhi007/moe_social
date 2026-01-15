# Design Document: Profile Editor Enhancement

## Overview

本设计文档描述了个人资料编辑器的优化方案。我们将重构现有的 `EditProfilePage`，使其具有更好的用户体验、更完善的功能和更健壮的错误处理。

主要改进包括：
- 现代化的UI设计，采用卡片式布局和Material Design风格
- 头像上传功能，支持从本地选择图片
- 新增个性签名、性别、生日等字段
- 实时表单验证和友好的错误提示
- 智能的数据变更检测
- 优化的保存流程和状态反馈

## Architecture

### 组件结构

```
EditProfilePage (StatefulWidget)
├── _EditProfilePageState
│   ├── Form Controllers (用户名、邮箱、签名等)
│   ├── State Management (加载状态、错误状态、变更检测)
│   ├── Validation Logic (表单验证)
│   └── API Integration (保存、上传)
│
├── UI Components
│   ├── AvatarSection (头像区域)
│   │   ├── Avatar Display
│   │   ├── Upload Button
│   │   └── Upload Progress
│   │
│   ├── BasicInfoSection (基本信息区)
│   │   ├── Username Field
│   │   ├── Email Field
│   │   ├── Signature Field
│   │   ├── Gender Selector
│   │   └── Birthday Picker
│   │
│   ├── AccountInfoSection (账户信息区)
│   │   ├── User ID
│   │   ├── VIP Status
│   │   ├── VIP Expiry
│   │   └── Registration Date
│   │
│   └── ActionSection (操作区)
│       ├── Save Button
│       └── Cancel Button
```

### 数据流

```
User Input → Form Controllers → Validation → State Update → UI Update
                                                    ↓
                                            Change Detection
                                                    ↓
                                            Enable/Disable Save Button
                                                    ↓
User Clicks Save → Upload Avatar (if changed) → Update Profile → Show Result
```

## Components and Interfaces

### 1. EditProfilePage Widget

主要的页面组件，负责整体布局和状态管理。

**State Variables:**
```dart
class _EditProfilePageState extends State<EditProfilePage> {
  // Form Controllers
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _signatureController;
  
  // Avatar
  File? _selectedImage;
  String? _avatarUrl;
  bool _isUploadingAvatar = false;
  
  // Additional Fields
  String? _selectedGender;
  DateTime? _selectedBirthday;
  
  // State Management
  bool _isSaving = false;
  bool _hasChanges = false;
  Map<String, String> _initialData = {};
  Map<String, String?> _fieldErrors = {};
  
  // ...
}
```

**Key Methods:**
- `initState()`: 初始化控制器和初始数据
- `_detectChanges()`: 检测数据是否有变更
- `_validateField(String field, String value)`: 验证单个字段
- `_pickImage()`: 选择图片
- `_uploadAvatar()`: 上传头像
- `_saveProfile()`: 保存资料
- `_showUnsavedChangesDialog()`: 显示未保存变更对话框

### 2. AvatarSection Component

头像编辑区域，支持两种方式设置头像：
1. 从本地选择图片上传（调用 `/api/upload` 接口）
2. 直接输入图片URL

**Interface:**
```dart
class AvatarSection extends StatelessWidget {
  final String? avatarUrl;
  final File? selectedImage;
  final bool isUploading;
  final VoidCallback onPickImage;  // 选择本地图片
  final VoidCallback onInputUrl;   // 输入URL
  
  const AvatarSection({
    required this.avatarUrl,
    this.selectedImage,
    required this.isUploading,
    required this.onPickImage,
    required this.onInputUrl,
  });
}
```

**头像设置流程：**
- 本地图片：选择图片 → 显示预览 → 保存时上传到 `/api/upload` → 获取URL → 提交到 `UpdateUserInfo`
- URL方式：输入URL → 显示预览 → 直接提交到 `UpdateUserInfo`

### 3. ValidatedTextField Component

带实时验证的文本输入框。

**Interface:**
```dart
class ValidatedTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final String? Function(String?) validator;
  final Function(String)? onChanged;
  final String? errorText;
  final int? maxLength;
  final int? maxLines;
  final TextInputType? keyboardType;
  
  const ValidatedTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    required this.validator,
    this.onChanged,
    this.errorText,
    this.maxLength,
    this.maxLines,
    this.keyboardType,
  });
}
```

### 4. GenderSelector Component

性别选择器。

**Interface:**
```dart
class GenderSelector extends StatelessWidget {
  final String? selectedGender;
  final Function(String?) onChanged;
  
  const GenderSelector({
    required this.selectedGender,
    required this.onChanged,
  });
}
```

### 5. BirthdayPicker Component

生日选择器。

**Interface:**
```dart
class BirthdayPicker extends StatelessWidget {
  final DateTime? selectedDate;
  final Function(DateTime?) onChanged;
  
  const BirthdayPicker({
    required this.selectedDate,
    required this.onChanged,
  });
}
```

## Data Models

### User Model Extension

需要扩展现有的 User 模型以支持新字段：

**前端 Dart 模型：**
```dart
class User {
  final String id;
  final String username;
  final String email;
  final String avatar;
  final String? signature;      // 新增：个性签名
  final String? gender;         // 新增：性别 (male/female/secret)
  final DateTime? birthday;     // 新增：生日
  final bool isVip;
  final String? vipExpiresAt;
  final bool autoRenew;
  final String createdAt;
  final String updatedAt;
  
  // ...
}
```

**后端 Go 模型（需要添加）：**
```go
type User struct {
  ID          uint           `gorm:"primarykey" json:"id"`
  Username    string         `gorm:"uniqueIndex;size:50;not null" json:"username"`
  Password    string         `gorm:"size:100;not null" json:"-"`
  Email       string         `gorm:"uniqueIndex;size:100;not null" json:"email"`
  Avatar      string         `gorm:"type:text" json:"avatar"`
  Signature   string         `gorm:"size:100" json:"signature"`           // 新增
  Gender      string         `gorm:"size:10" json:"gender"`               // 新增
  Birthday    *time.Time     `json:"birthday,omitempty"`                  // 新增
  IsVip       bool           `gorm:"default:false" json:"is_vip"`
  VipStartAt  *time.Time     `json:"vip_start_at,omitempty"`
  VipEndAt    *time.Time     `json:"vip_end_at,omitempty"`
  AutoRenew   bool           `gorm:"default:false" json:"auto_renew"`
  Balance     float64        `gorm:"default:0" json:"balance"`
  CreatedAt   time.Time      `json:"created_at"`
  UpdatedAt   time.Time      `json:"updated_at"`
  DeletedAt   gorm.DeletedAt `gorm:"index" json:"-"`
  
  // ...
}
```

**后端 API 定义（需要更新）：**
```go
type UpdateUserInfoReq {
  UserId    string `path:"user_id"`
  Username  string `json:"username"`
  Email     string `json:"email"`
  Avatar    string `json:"avatar"`
  Signature string `json:"signature,optional"`  // 新增
  Gender    string `json:"gender,optional"`     // 新增
  Birthday  string `json:"birthday,optional"`   // 新增，ISO8601格式
}
```

### ProfileUpdateRequest

用于提交更新的数据模型：

```dart
class ProfileUpdateRequest {
  final String? username;
  final String? email;
  final String? avatar;
  final String? signature;
  final String? gender;
  final DateTime? birthday;
  
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (username != null) data['username'] = username;
    if (email != null) data['email'] = email;
    if (avatar != null) data['avatar'] = avatar;
    if (signature != null) data['signature'] = signature;
    if (gender != null) data['gender'] = gender;
    if (birthday != null) data['birthday'] = birthday.toIso8601String();
    return data;
  }
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Avatar Upload Success

*For any* valid image file, when uploaded through the Avatar_Upload component, the upload should complete successfully and return a valid URL.

**Validates: Requirements 2.3**

### Property 2: Avatar Preview Display

*For any* selected image file, the Avatar_Upload component should display a preview of the image before saving.

**Validates: Requirements 2.2**

### Property 3: Signature Character Limit

*For any* input in the signature field, the Profile_Editor should enforce a maximum of 100 characters and display the remaining character count.

**Validates: Requirements 3.4**

### Property 4: All Fields Submission

*For any* profile update operation, all modified fields (username, email, avatar, signature, gender, birthday) should be included in the API request.

**Validates: Requirements 3.5**

### Property 5: Username Validation

*For any* username input, the Form_Validation should accept only strings of 3-20 characters containing letters, numbers, and underscores, and reject all other inputs.

**Validates: Requirements 4.1**

### Property 6: Email Validation

*For any* email input, the Form_Validation should accept only valid email formats and reject invalid formats.

**Validates: Requirements 4.2**

### Property 7: Validation Feedback Display

*For any* field validation result, the Form_Validation should display error messages for invalid inputs and remove error messages for valid inputs.

**Validates: Requirements 4.3, 4.4**

### Property 8: Invalid Data Submission Prevention

*For any* form state with validation errors, the Profile_Editor should prevent form submission and highlight the fields with errors.

**Validates: Requirements 4.5**

### Property 9: Change Detection

*For any* field modification, the Profile_Editor should detect the change and update the save button state accordingly.

**Validates: Requirements 6.2**

### Property 10: Save Button State Management

*For any* form state, the save button should be enabled when there are unsaved changes and disabled when there are no changes.

**Validates: Requirements 6.3, 6.4**

### Property 11: Server Error Display

*For any* server error response, the Profile_Editor should display the error message returned by the server.

**Validates: Requirements 7.2**

## Error Handling

### 1. Network Errors

当网络请求失败时：
- 显示友好的错误提示："网络连接失败，请检查网络设置"
- 保持当前页面状态，不清空用户输入
- 提供重试选项

### 2. Validation Errors

当表单验证失败时：
- 在对应字段下方显示红色错误提示
- 阻止表单提交
- 高亮显示错误字段
- 滚动到第一个错误字段

### 3. Server Errors

当服务器返回错误时：
- 显示服务器返回的具体错误信息
- 特殊处理常见错误：
  - 用户名已被占用：在用户名字段下显示
  - 邮箱已被使用：在邮箱字段下显示
  - 认证失败：提示重新登录

### 4. Upload Errors

当图片上传失败时：
- 显示"图片上传失败，请重试"
- 保留原头像
- 允许用户重新选择图片

### 5. Unsaved Changes

当用户尝试离开页面且有未保存的变更时：
- 显示确认对话框
- 提供"保存"、"放弃"、"取消"三个选项

## Testing Strategy

### Unit Tests

使用 Flutter 的 `flutter_test` 包进行单元测试：

1. **Validation Tests**
   - 测试用户名验证规则
   - 测试邮箱验证规则
   - 测试签名字符限制

2. **Change Detection Tests**
   - 测试初始状态无变更
   - 测试修改后检测到变更
   - 测试恢复原值后无变更

3. **Error Handling Tests**
   - 测试网络错误处理
   - 测试服务器错误处理
   - 测试验证错误处理

4. **UI Component Tests**
   - 测试头像区域渲染
   - 测试表单字段渲染
   - 测试保存按钮状态

### Property-Based Tests

使用 `test` 包和自定义生成器进行属性测试：

1. **Avatar Upload Property Test**
   - 生成随机图片数据
   - 验证上传成功返回URL
   - 最少100次迭代

2. **Validation Property Tests**
   - 生成随机用户名测试验证规则
   - 生成随机邮箱测试验证规则
   - 最少100次迭代

3. **Change Detection Property Test**
   - 生成随机字段修改
   - 验证变更检测正确性
   - 最少100次迭代

4. **Field Submission Property Test**
   - 生成随机字段组合
   - 验证所有字段都包含在请求中
   - 最少100次迭代

### Integration Tests

使用 `integration_test` 包进行集成测试：

1. **Complete Edit Flow**
   - 打开编辑页面
   - 修改各个字段
   - 保存并验证成功

2. **Avatar Upload Flow**
   - 选择图片
   - 上传图片
   - 保存资料

3. **Error Recovery Flow**
   - 触发各种错误
   - 验证错误提示
   - 验证恢复机制

### Test Configuration

所有属性测试应配置为运行最少100次迭代，并使用以下标签格式：

```dart
test('Property 1: Avatar Upload Success', () {
  // Feature: profile-editor-enhancement, Property 1: Avatar Upload Success
  // ...
}, tags: ['property-test', 'profile-editor']);
```

## Implementation Notes

### 1. 向后兼容性

为了保持向后兼容性：
- 新字段在 User 模型中设为可选
- API 请求只包含非空字段
- 解析响应时处理缺失字段
- UI 根据字段是否存在动态调整

### 2. 性能优化

- 使用 `debounce` 延迟验证，避免频繁验证
- 图片上传前进行压缩
- 使用 `CachedNetworkImage` 缓存头像
- 表单字段使用 `AutovalidateMode.onUserInteraction`

### 3. 用户体验

- 保存成功后自动返回上一页面
- 使用 `SnackBar` 显示操作结果
- 加载时禁用所有交互
- 提供清晰的视觉反馈

### 4. 安全性

- 客户端验证 + 服务端验证
- 图片上传前检查文件类型和大小
- 敏感信息（如邮箱）修改需要额外验证
- 使用 HTTPS 传输数据
