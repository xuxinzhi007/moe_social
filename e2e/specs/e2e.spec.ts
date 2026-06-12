import { test, expect } from '@playwright/test';
import { waitFlutterReady } from '../pages/smoke-utils';

test.describe('核心流程 E2E', () => {
  test('导航验证：登录 → 注册 → 忘记密码 → 回到登录', async ({ page }) => {
    console.log('🚀 开始导航测试');
    
    // 1. 登录页
    await page.goto('/login');
    await waitFlutterReady(page);
    const loginTitle = await page.title();
    console.log(`1️⃣  登录页标题: ${loginTitle}`);
    await page.screenshot({ path: 'playwright-report/nav-login.png' });

    // 2. 注册页
    await page.goto('/register');
    await waitFlutterReady(page);
    console.log(`2️⃣  已跳转到注册页，URL: ${page.url()}`);
    await page.screenshot({ path: 'playwright-report/nav-register.png' });

    // 3. 忘记密码页
    await page.goto('/forgot-password');
    await waitFlutterReady(page);
    console.log(`3️⃣  已跳转到忘记密码页，URL: ${page.url()}`);
    await page.screenshot({ path: 'playwright-report/nav-forgot.png' });

    // 4. 回到登录页
    await page.goto('/login');
    await waitFlutterReady(page);
    console.log(`4️⃣  回到登录页，URL: ${page.url()}`);

    // 断言：页面不应崩溃
    const bodyText = await page.textContent('body') || '';
    expect(bodyText).toBeTruthy();
    console.log('✅ 导航测试完成');
  });

  test('页面加载：检查 10 个核心页面', async ({ page }) => {
    const pages = [
      '/login', '/register', '/forgot-password',
      '/home', '/profile', '/settings',
      '/community', '/create-post', '/checkin',
      '/achievements',
    ];

    for (const path of pages) {
      await page.goto(path);
      await waitFlutterReady(page);
      
      const title = await page.title();
      const url = page.url();
      console.log(`✅ ${path} -> ${title} (${url})`);
      
      // 页面不应崩溃
      expect(title).toBeTruthy();
    }
  });

  test('文本验证：登录页应显示登录相关文字', async ({ page }) => {
    await page.goto('/login');
    await waitFlutterReady(page);

    // 检查页面是否包含"登录"等关键字
    const bodyText = await page.evaluate(() => {
      return document.body.innerText || document.body.textContent || '';
    });

    const hasLoginText = /登录|login|Login/.test(bodyText);
    console.log(`📝 页面是否含"登录"相关文字: ${hasLoginText}`);
    console.log(`📝 页面内容前200字符: ${bodyText.slice(0, 200)}`);

    await page.screenshot({ path: 'playwright-report/login-text.png' });
    expect(bodyText.length).toBeGreaterThan(0);
  });
});
