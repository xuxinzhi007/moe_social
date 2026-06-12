import type { Page, Locator } from '@playwright/test';

/**
 * Flutter Web 登录页面的 Page Object。
 * 
 * Flutter Web 用 canvas 渲染元素，DOM 中暴露的是语义标签
 * 所以用文本定位（getByText / getByRole）是最可靠的方式
 */
export class LoginPage {
  readonly page: Page;
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly loginButton: Locator;
  readonly registerLink: Locator;
  readonly forgotPassword: Locator;
  readonly wechatLogin: Locator;
  readonly feishuLogin: Locator;

  constructor(page: Page) {
    this.page = page;
    // 按文本/角色定位 — 对 Flutter Web 最稳定
    this.emailInput = page.getByRole('textbox').filter({
      hasText: /邮箱|email|moe/i,
    }).first();
    this.passwordInput = page.getByRole('textbox').nth(1);
    this.loginButton = page.getByText(/登\s*录/).first();
    this.registerLink = page.getByText(/立即注册|注册/);
    this.forgotPassword = page.getByText(/忘记密码/);
    this.wechatLogin = page.getByText(/微信/).first();
    this.feishuLogin = page.getByText(/飞书/).first();
  }

  async goto() {
    await this.page.goto('/login');
  }

  async loginWithEmail(email: string, password: string) {
    // Flutter Web 的文本框需要先点击再输入
    await this.emailInput.click();
    await this.emailInput.fill(email);
    await this.passwordInput.click();
    await this.passwordInput.fill(password);
    await this.loginButton.click();

    // 等待跳转
    await this.page.waitForURL(url => url.pathname === '/home', { timeout: 15000 });
  }

  async isOnLoginPage(): Promise<boolean> {
    const body = await this.page.textContent('body');
    return /登录|Login/.test(body || '');
  }
}
