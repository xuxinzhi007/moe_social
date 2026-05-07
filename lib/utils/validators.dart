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

  /// 常见邮箱后缀补全（登录/注册输入框下方展示，不改变 [loginAccount]/[email] 规则）。
  ///
  /// 仅在已出现 `@`、本地部分非空、且整串尚不符合完整邮箱格式时返回候选（最多 [limit] 条）。
  static List<String> emailDomainCompletionCandidates(String raw,
      {int limit = 8}) {
    final value = raw.trim();
    if (value.isEmpty || !value.contains('@')) return [];

    final at = value.indexOf('@');
    if (at <= 0) return [];
    if (value.indexOf('@', at + 1) >= 0) return [];

    final local = value.substring(0, at);
    if (local.isEmpty) return [];

    final domainPart = value.substring(at + 1);
    if (email(value) == null) return [];

    // 顺序影响默认展示的前几条（limit）；国内常用放前。
    const domains = <String>[
      'qq.com',
      '163.com',
      '126.com',
      'foxmail.com',
      'gmail.com',
      'outlook.com',
      'hotmail.com',
      'icloud.com',
      'sina.com',
      'yeah.net',
    ];

    final out = <String>[];
    for (final d in domains) {
      if (domainPart.isEmpty || d.startsWith(domainPart)) {
        out.add('$local@$d');
      }
      if (out.length >= limit) break;
    }
    return out;
  }

  /// 登录账号：邮箱或 10 位 Moe 号
  static String? loginAccount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入邮箱或 Moe 号';
    }
    final t = value.trim();
    if (t.contains('@')) {
      return email(t);
    }
    if (!RegExp(r'^\d{10}$').hasMatch(t)) {
      return '请输入有效邮箱，或 10 位数字 Moe 号';
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

