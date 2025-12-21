// 表单验证工具类
class Validators {
  // 邮箱格式验证
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入邮箱';
    }
    
    // 基本的邮箱格式验证
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    
    if (!emailRegex.hasMatch(value)) {
      return '请输入有效的邮箱地址（例如：example@email.com）';
    }
    
    return null;
  }

  // 用户名验证
  static String? username(String? value) {
    if (value == null || value.isEmpty) {
      return '请输入用户名';
    }
    
    if (value.length < 3) {
      return '用户名长度不能少于3个字符';
    }
    
    if (value.length > 20) {
      return '用户名长度不能超过20个字符';
    }
    
    // 只允许字母、数字、下划线
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(value)) {
      return '用户名只能包含字母、数字和下划线';
    }
    
    return null;
  }

  // 密码验证
  static String? password(String? value, {int minLength = 6}) {
    if (value == null || value.isEmpty) {
      return '请输入密码';
    }
    
    if (value.length < minLength) {
      return '密码长度不能少于$minLength位';
    }
    
    return null;
  }

  // 确认密码验证
  static String? confirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return '请再次确认密码';
    }
    
    if (value != password) {
      return '两次输入的密码不一致';
    }
    
    return null;
  }

  // 必填字段验证
  static String? required(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '请输入$fieldName';
    }
    return null;
  }
}

