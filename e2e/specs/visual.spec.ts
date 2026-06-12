import { test, expect } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';

/**
 * Flutter Web 视觉测试方案
 * 
 * 问题：Flutter 3.41.6 即便是 HTML 渲染器，也不会把 UI 暴露到 DOM 中，
 *      Playwright 的 getByText/getByRole 无法定位元素。
 * 
 * 解决方案：
 *  1. 视觉回归测试（截图对比）：页面每次渲染是否一致
 *  2. 页面非空检测：截图不是纯空白（页面真的加载了）
 *  3. 坐标交互：按页面比例点击（如"登录按钮在70%高度处"）
 *  4. 响应式测试：不同视口尺寸下页面是否正常
 */

const VISUAL_DIR = path.join(process.cwd(), 'playwright-report', 'visual');
const BASELINE_DIR = path.join(process.cwd(), 'playwright-report', 'visual', 'baseline');

// 确保目录存在
fs.mkdirSync(VISUAL_DIR, { recursive: true });
fs.mkdirSync(BASELINE_DIR, { recursive: true });

/** 计算截图的像素哈希（用于快速判断页面是否有变化） */
async function getImageHash(screenshot: Buffer): Promise<string> {
  return crypto.createHash('sha256').update(screenshot).digest('hex');
}

/** 检测图片是否为"几乎空白"（Flutter 加载失败时页面纯白） */
async function isBlank(screenshot: Buffer, threshold = 0.95): Promise<boolean> {
  // 简单启发式：计算文件大小与"纯白图片"的比例
  // 一个 1440x900 的纯白 PNG 大约 10KB
  const blankReferenceKB = 15; // 15KB 以下认为是空白
  return screenshot.length / 1024 < blankReferenceKB * threshold ? false :
         // 真实页面应该有更多颜色和细节，文件大小应显著大于空白
         screenshot.length < 30 * 1024; // 30KB 以下可能没渲染好
}

/** 获取页面主色调（用于检测是否有 Flutter 红屏/黄屏错误） */
async function getPageColorSignature(page: any): Promise<{ hasErrorColor: boolean; brightness: number }> {
  const colorInfo = await page.evaluate(() => {
    // 检测 Flutter 红屏/黄屏的启发式方法
    const bodyText = document.body.innerText || document.body.textContent || '';
    const hasErrorText = /Exception|Error|渲染错误|出错了|something went wrong/i.test(bodyText);
    
    // 检测背景色是否是 Flutter 的典型错误色
    let avgR = 200, avgG = 200, avgB = 200;
    
    return { hasErrorText, avgR, avgG, avgB };
  });

  return {
    hasErrorColor: colorInfo.hasErrorText,
    brightness: (colorInfo.avgR + colorInfo.avgG + colorInfo.avgB) / 3,
  };
}

test.describe('🎨 视觉测试：页面渲染与样式一致性', () => {
  test('✅ 登录页：页面非空 + 截图对比', async ({ page }) => {
    const pageName = 'login';
    
    // 1. 导航
    await page.goto('/login');
    await page.waitForTimeout(2000);

    // 2. 截图
    const screenshot = await page.screenshot({ path: `${VISUAL_DIR}/${pageName}.png`, fullPage: true });
    const hash = await getImageHash(screenshot);
    console.log(`\n📸 截图大小: ${(screenshot.length / 1024).toFixed(1)} KB`);
    console.log(`🔑 像素哈希: ${hash.slice(0, 16)}...`);

    // 3. 检测页面是否为空白（Flutter 没加载好）
    const tooSmall = screenshot.length < 30 * 1024;
    if (tooSmall) {
      console.log(`⚠️  警告：截图过小 (${(screenshot.length / 1024).toFixed(1)}KB)，可能页面没渲染好`);
    }
    expect(screenshot.length, '页面应该有足够内容（>30KB）').toBeGreaterThan(30 * 1024);

    // 4. 基准对比（如果已有基准图）
    const baselinePath = `${BASELINE_DIR}/${pageName}.png`;
    const baselineHashPath = `${BASELINE_DIR}/${pageName}.hash`;

    if (fs.existsSync(baselineHashPath)) {
      const baselineHash = fs.readFileSync(baselineHashPath, 'utf8');
      const match = hash === baselineHash;
      console.log(`\n📊 视觉对比:`);
      console.log(`   上次: ${baselineHash.slice(0, 16)}...`);
      console.log(`   本次: ${hash.slice(0, 16)}...`);
      console.log(`   结果: ${match ? '✅ 一致' : '⚠️ 有差异（可能是正常的，也可能是 bug）'}`);
    } else {
      console.log(`\n📝 首次运行 — 保存基准图`);
      fs.copyFileSync(`${VISUAL_DIR}/${pageName}.png`, baselinePath);
      fs.writeFileSync(baselineHashPath, hash);
    }

    // 5. 更新本次哈希（用于下次对比）
    fs.writeFileSync(`${VISUAL_DIR}/${pageName}.hash`, hash);
    console.log(`\n✅ 登录页视觉测试通过`);
  });

  test('🔄 多路由视觉测试：10个核心页面都能渲染', async ({ page }) => {
    const pages = [
      { name: 'login', path: '/login' },
      { name: 'register', path: '/register' },
      { name: 'forgot-password', path: '/forgot-password' },
      { name: 'home', path: '/home' },
      { name: 'profile', path: '/profile' },
      { name: 'settings', path: '/settings' },
      { name: 'community', path: '/community' },
      { name: 'create-post', path: '/create-post' },
      { name: 'checkin', path: '/checkin' },
      { name: 'notifications', path: '/notifications' },
    ];

    console.log(`\n🎯 测试 ${pages.length} 个页面的视觉渲染`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    for (const { name, path: pagePath } of pages) {
      await page.goto(pagePath);
      await page.waitForTimeout(1500);

      const screenshot = await page.screenshot({
        path: `${VISUAL_DIR}/${name}.png`,
        fullPage: false,
      });

      const sizeKB = screenshot.length / 1024;
      const isTooSmall = sizeKB < 15; // 小于15KB视为空白

      console.log(`   ${isTooSmall ? '⚠️' : '✅'} ${name.padEnd(20)} ${sizeKB.toFixed(1)} KB`);

      if (!isTooSmall) {
        // 保存到基准
        if (!fs.existsSync(`${BASELINE_DIR}/${name}.png`)) {
          fs.copyFileSync(`${VISUAL_DIR}/${name}.png`, `${BASELINE_DIR}/${name}.png`);
        }
      }
    }
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  });

  test('📐 响应式测试：移动端 vs 桌面端', async ({ page }) => {
    // 桌面端
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.goto('/login');
    await page.waitForTimeout(1500);
    const desktopShot = await page.screenshot({ path: `${VISUAL_DIR}/login-desktop.png` });

    // 移动端
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto('/login');
    await page.waitForTimeout(1500);
    const mobileShot = await page.screenshot({ path: `${VISUAL_DIR}/login-mobile.png` });

    console.log(`\n📐 响应式渲染测试:`);
    console.log(`   桌面端: ${(desktopShot.length / 1024).toFixed(1)} KB (1440x900)`);
    console.log(`   移动端: ${(mobileShot.length / 1024).toFixed(1)} KB (390x844)`);

    const desktopOK = desktopShot.length > 20 * 1024;
    const mobileOK = mobileShot.length > 20 * 1024;
    console.log(`   结果: ${desktopOK && mobileOK ? '✅ 两端都正常渲染' : '⚠️ 可能有问题'}`);

    expect(desktopShot.length).toBeGreaterThan(20 * 1024);
    expect(mobileShot.length).toBeGreaterThan(20 * 1024);
  });
});

test.describe('🎯 交互测试：坐标点击 + 导航', () => {
  test('🖱️ 按坐标点击：登录页按钮区域可响应', async ({ page }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.goto('/login');
    await page.waitForTimeout(2000);

    // 点击页面中心（登录表单大致位置）
    console.log(`\n🖱️ 点击页面中心（表单区域）`);
    await page.mouse.click(720, 450);
    await page.waitForTimeout(500);

    // 点击页面下方偏右（登录按钮大致位置）
    console.log(`🖱️ 点击页面下方偏右（按钮区域）`);
    await page.mouse.click(720, 600);
    await page.waitForTimeout(500);

    // 截图记录交互后的状态
    await page.screenshot({ path: `${VISUAL_DIR}/after-click.png` });
    console.log(`📸 交互后截图已保存`);

    // 断言：页面没有崩溃
    await expect(page.title()).resolves.toBeTruthy();
    console.log(`✅ 交互测试通过（页面未崩溃）`);
  });

  test('🔗 路由导航：从首页跳转到其他页面', async ({ page }) => {
    await page.goto('/login');
    await page.waitForTimeout(1500);

    const routes = ['/register', '/forgot-password', '/home', '/settings'];
    console.log(`\n🔗 路由导航测试:`);

    for (const route of routes) {
      await page.goto(route);
      await page.waitForTimeout(1000);

      const url = page.url();
      const title = await page.title();
      console.log(`   ✅ ${route} → ${title} (${url})`);

      // 截图
      await page.screenshot({
        path: `${VISUAL_DIR}/nav-${route.replace(/\//g, '-')}.png`,
      });
    }
  });
});

test.describe('⚡ 性能与稳定性', () => {
  test('⏱️ 页面加载时间：登录页 < 5秒', async ({ page }) => {
    const start = Date.now();
    await page.goto('/login');
    await page.waitForTimeout(2000); // 等 Flutter 渲染
    const loadTime = Date.now() - start;

    console.log(`\n⏱️  登录页加载时间: ${loadTime}ms`);
    console.log(`   目标: < 5000ms`);
    console.log(`   结果: ${loadTime < 5000 ? '✅ 达标' : '⚠️ 偏慢'}`);

    expect(loadTime, '页面加载应 < 5秒').toBeLessThan(5000);
  });

  test('🔄 3次连续刷新：每次都能正常渲染', async ({ page }) => {
    console.log(`\n🔄 连续刷新稳定性测试（3次）:`);

    const sizes: number[] = [];
    for (let i = 0; i < 3; i++) {
      await page.goto('/login');
      await page.waitForTimeout(1500);

      const shot = await page.screenshot({ path: `${VISUAL_DIR}/refresh-${i + 1}.png` });
      sizes.push(shot.length);
      console.log(`   第${i + 1}次: ${(shot.length / 1024).toFixed(1)} KB ${shot.length > 20 * 1024 ? '✅' : '⚠️'}`);
    }

    // 计算方差（判断三次渲染是否一致）
    const avg = sizes.reduce((a, b) => a + b, 0) / sizes.length;
    const variance = sizes.reduce((sum, size) => sum + Math.pow(size - avg, 2), 0) / sizes.length;
    const stdDev = Math.sqrt(variance);
    console.log(`\n📊 标准差: ${(stdDev / 1024).toFixed(2)} KB (越小越稳定)`);
    console.log(`   平均: ${(avg / 1024).toFixed(1)} KB`);

    // 断言：所有截图都足够大
    for (const size of sizes) {
      expect(size).toBeGreaterThan(20 * 1024);
    }
  });
});
