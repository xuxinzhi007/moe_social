export function requiredValue(label: string, value: string) {
  if (!value.trim()) {
    return `请输入${label}`;
  }
  return '';
}

export function validateEmail(value: string) {
  if (!value.trim()) {
    return '请输入邮箱';
  }
  const email = value.trim().toLowerCase();
  const ok = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  return ok ? '' : '邮箱格式不正确';
}

export function validateAccount(value: string) {
  if (!value.trim()) {
    return '请输入邮箱、Moe 号或用户名';
  }
  return '';
}

export function validateUsername(value: string) {
  const next = value.trim();
  if (!next) {
    return '请输入用户名';
  }
  if (next.length < 2) {
    return '用户名至少 2 位';
  }
  return '';
}

export function validatePassword(value: string) {
  if (!value) {
    return '请输入密码';
  }
  if (value.length < 6) {
    return '密码至少 6 位';
  }
  return '';
}

export function validateConfirmPassword(value: string, password: string) {
  if (!value) {
    return '请再次输入密码';
  }
  if (value !== password) {
    return '两次输入的密码不一致';
  }
  return '';
}

export function validateVerifyCode(value: string) {
  if (!value.trim()) {
    return '请输入验证码';
  }
  if (value.trim().length !== 6) {
    return '验证码应为 6 位';
  }
  return '';
}

export function emailDomainCompletionCandidates(raw: string, limit = 5) {
  const value = raw.trim().toLowerCase();
  if (!value || !value.includes('@')) {
    return [];
  }

  const at = value.indexOf('@');
  if (at <= 0 || value.indexOf('@', at + 1) >= 0) {
    return [];
  }

  const local = value.slice(0, at);
  const domainPart = value.slice(at + 1);
  if (!local || validateEmail(value) === '') {
    return [];
  }

  const domains = [
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

  return domains
    .filter((domain) => !domainPart || domain.startsWith(domainPart))
    .slice(0, limit)
    .map((domain) => `${local}@${domain}`);
}
