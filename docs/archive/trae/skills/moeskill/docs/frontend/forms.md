# Flutter表单与输入处理

## 概述

表单是用户交互的核心组件。Flutter提供了强大的表单处理功能，包括验证、状态管理和用户输入处理。

## 基础表单

### Form + TextFormField

```dart
class LoginForm extends StatefulWidget {
  @override
  _LoginFormState createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      // 表单验证通过，处理登录逻辑
      final email = _emailController.text;
      final password = _passwordController.text;
      
      print('邮箱: $email, 密码: $password');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(
              labelText: '邮箱',
              hintText: '请输入邮箱地址',
              prefixIcon: Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.blue, width: 2),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return '请输入邮箱';
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!)) {
                return '邮箱格式不正确';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: '密码',
              hintText: '请输入密码',
              prefixIcon: Icon(Icons.lock),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            obscureText: true,
            validator: (value) {
              if (value?.isEmpty ?? true) {
                return '请输入密码';
              }
              if (value!.length < 6) {
                return '密码长度至少6位';
              }
              return null;
            },
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: _handleLogin,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              child: Text('登录'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

## 输入框配置

### 装饰配置

```dart
TextFormField(
  decoration: InputDecoration(
    // 标签
    labelText: '用户名',
    labelStyle: TextStyle(color: Colors.grey),
    
    // 提示文本
    hintText: '请输入用户名',
    hintStyle: TextStyle(color: Colors.grey[400]),
    
    // 前缀图标
    prefixIcon: Icon(Icons.person),
    
    // 后缀图标
    suffixIcon: IconButton(
      icon: Icon(Icons.clear),
      onPressed: () {
        // 清除文本
      },
    ),
    
    // 边框
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey),
    ),
    
    // 聚焦边框
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.blue, width: 2),
    ),
    
    // 错误边框
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.red),
    ),
    
    // 填充颜色
    filled: true,
    fillColor: Colors.grey[100],
    
    // 内容内边距
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  ),
)
```

### 键盘类型

```dart
TextFormField(
  keyboardType: TextInputType.emailAddress,  // 邮箱键盘
  // keyboardType: TextInputType.phone,      // 电话键盘
  // keyboardType: TextInputType.number,     // 数字键盘
  // keyboardType: TextInputType.url,        // URL键盘
  // keyboardType: TextInputType.multiline,  // 多行文本
)
```

### 输入操作

```dart
TextFormField(
  textInputAction: TextInputAction.next,  // 下一个输入框
  // textInputAction: TextInputAction.done,   // 完成
  // textInputAction: TextInputAction.search, // 搜索
  // textInputAction: TextInputAction.send,   // 发送
  onFieldSubmitted: (value) {
    // 点击键盘上的操作按钮
    FocusScope.of(context).nextFocus();  // 聚焦到下一个输入框
  },
)
```

## 表单验证

### 同步验证

```dart
String? validateEmail(String? value) {
  if (value?.isEmpty ?? true) {
    return '请输入邮箱';
  }
  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!)) {
    return '邮箱格式不正确';
  }
  return null;
}

String? validatePassword(String? value) {
  if (value?.isEmpty ?? true) {
    return '请输入密码';
  }
  if (value!.length < 6) {
    return '密码长度至少6位';
  }
  if (!value.contains(RegExp(r'[A-Z]'))) {
    return '密码必须包含大写字母';
  }
  if (!value.contains(RegExp(r'[0-9]'))) {
    return '密码必须包含数字';
  }
  return null;
}
```

### 异步验证

```dart
Future<String?> validateUsernameAsync(String? value) async {
  if (value?.isEmpty ?? true) {
    return '请输入用户名';
  }
  
  // 异步检查用户名是否已存在
  final exists = await ApiService.checkUsernameExists(value!);
  if (exists) {
    return '用户名已存在';
  }
  
  return null;
}
```

### 自定义验证器

```dart
class Validator {
  static String? required(String? value, String fieldName) {
    if (value?.isEmpty ?? true) {
      return '请输入$fieldName';
    }
    return null;
  }
  
  static String? minLength(String? value, int length, String fieldName) {
    if ((value?.length ?? 0) < length) {
      return '$fieldName长度至少$length位';
    }
    return null;
  }
  
  static String? pattern(String? value, String pattern, String errorMessage) {
    if (value != null && !RegExp(pattern).hasMatch(value)) {
      return errorMessage;
    }
    return null;
  }
}

// 使用
TextFormField(
  validator: (value) {
    return Validator.required(value, '用户名') ??
           Validator.minLength(value, 3, '用户名');
  },
)
```

## 复杂表单示例

### 注册表单

```dart
class RegisterForm extends StatefulWidget {
  @override
  _RegisterFormState createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // 用户名
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: '用户名',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return '请输入用户名';
                }
                if (value!.length < 3) {
                  return '用户名至少3个字符';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            
            // 邮箱
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: '邮箱',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return '请输入邮箱';
                }
                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value!)) {
                  return '邮箱格式不正确';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            
            // 密码
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: '密码',
                prefixIcon: Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword 
                    ? Icons.visibility_off 
                    : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                border: OutlineInputBorder(),
              ),
              obscureText: _obscurePassword,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return '请输入密码';
                }
                if (value!.length < 6) {
                  return '密码至少6位';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            
            // 确认密码
            TextFormField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: '确认密码',
                prefixIcon: Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirmPassword 
                    ? Icons.visibility_off 
                    : Icons.visibility),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
                border: OutlineInputBorder(),
              ),
              obscureText: _obscureConfirmPassword,
              validator: (value) {
                if (value?.isEmpty ?? true) {
                  return '请确认密码';
                }
                if (value != _passwordController.text) {
                  return '两次输入的密码不一致';
                }
                return null;
              },
            ),
            SizedBox(height: 16),
            
            // 同意条款
            CheckboxListTile(
              title: Text('我同意服务条款和隐私政策'),
              value: _agreeToTerms,
              onChanged: (value) {
                setState(() {
                  _agreeToTerms = value ?? false;
                });
              },
            ),
            SizedBox(height: 24),
            
            // 注册按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _agreeToTerms ? _handleRegister : null,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('注册'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleRegister() {
    if (_formKey.currentState!.validate()) {
      // 处理注册逻辑
      print('注册成功');
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
```

## 焦点管理

### 自动聚焦

```dart
TextFormField(
  autofocus: true,  // 页面加载时自动聚焦
)
```

### 焦点切换

```dart
class FocusExample extends StatelessWidget {
  final _usernameFocus = FocusNode();
  final _passwordFocus = FocusNode();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          focusNode: _usernameFocus,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) {
            FocusScope.of(context).requestFocus(_passwordFocus);
          },
        ),
        TextFormField(
          focusNode: _passwordFocus,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) {
            _handleSubmit();
          },
        ),
      ],
    );
  }

  void _handleSubmit() {
    // 处理提交
  }

  @override
  void dispose() {
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }
}
```

## 最佳实践

### 1. 及时释放资源

```dart
@override
void dispose() {
  _controller.dispose();  // 释放TextEditingController
  _focusNode.dispose();   // 释放FocusNode
  super.dispose();
}
```

### 2. 使用const优化性能

```dart
const InputDecoration(
  labelText: '用户名',
  prefixIcon: const Icon(Icons.person),
)
```

### 3. 表单状态管理

```dart
// 保存表单状态
_formKey.currentState?.save();

// 重置表单
_formKey.currentState?.reset();

// 验证表单
_formKey.currentState?.validate();
```

### 4. 错误处理

```dart
try {
  final result = await ApiService.submitForm(data);
  if (result.success) {
    MoeToast.success(context, '提交成功');
  } else {
    // 显示服务器返回的错误
    MoeToast.error(context, result.errorMessage);
  }
} catch (e) {
  MoeToast.error(context, '网络错误，请稍后重试');
}
```

## 总结

表单开发的关键点：

1. **使用Form + TextFormField**：统一管理表单状态
2. **合理配置InputDecoration**：提升用户体验
3. **完善的验证逻辑**：前端验证 + 后端验证
4. **焦点管理**：优化输入流程
5. **及时释放资源**：避免内存泄漏
6. **错误处理**：友好的错误提示

通过遵循这些最佳实践，可以构建出用户体验良好的表单界面。
