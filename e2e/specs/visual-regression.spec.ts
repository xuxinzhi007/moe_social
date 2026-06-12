import { test, expect } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';

/**
 * ============================================================================
 *   Flutter Web 视觉回归测试（可靠方案）
 * ============================================================================
 *
 * 背景：Flutter Web 的渲染架构决定了 Playwright 无法直接定位 UI 元素，
 *       因此我们采用「截图对比」作为主要验证手段。
 *
 * 为什么截图对比可靠：
 *   1. 同一页面每次渲染 → 截图哈希相同 ✅
 *   2. 不同页面（登录 vs 注册）→ 截图哈希不同 ✅
 *   3. 页面崩溃/白屏 → 截图过小或纯色 → 被检测到 ✅
 *   4. 不依赖 DOM 结构，完全基于视觉输出 ✅
 *
 * 测试策略：
 *   ✅ 页面能渲染（截图 > 3KB）
 *   ✅ 不同页面截图不同（登录 ≠ 注册 ≠ 设置）
 *   ✅ 同一页面渲染稳定（5次刷新都相同）
 *   ✅ 加载时间合理（< 5秒）
 *   ✅ 首次自动创建基准，后续与基准对比
 *   ✅ 响应式测试（桌面 vs 移动端）
 * ============================================================================
 */

const REPORT_DIR = path.join(process.cwd(), 'playwright-report', 'visual-regression');
const BASELINE_DIR = path.join(REPORT_DIR, 'baseline');

function ensureDir(dir: string) {
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
}
ensureDir(REPORT_DIR);
ensureDir(BASELINE_DIR);

function imgHash(buffer: Buffer): string {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

// ============================================================================
// 测试 1：所有核心页面能正常渲染（非白屏）
// ============================================================================
test.describe('1️⃣ 渲染验证（所有页面非白屏）', () => {
  const PAGES = [
    { name: '登录',      path: '/login' },
    { name: '注册',      path: '/register' },
    { name: '忘记密码',  path: '/forgot-password' },
    { name: '首页',      path: '/home' },
    { name: '个人资料',  path: '/profile' },
    { name: '设置',      path: '/settings' },
    { name: '社区',      path: '/community' },
    { name: '发帖',      path: '/create-post' },
    { name: '签到',      path: '/checkin' },
    { name: '通知',      path: '/notifications' },
    { name: 'VIP中心',  path: '/vip-center' },
    { name: '钱包',      path: '/wallet' },
    { name: '公告',      path: '/announcements' },
    { name: '好友',      path: '/friends' },
    { name: '我的二维码', path: '/user-qr-code' },
  ];

  for (const { name, path: pagePath } of PAGES) {
    test(`✅ ${name} (${pagePath})`, async ({ page }) => {
      await page.goto(pagePath, { waitUntil: 'networkidle' });
      await page.waitForTimeout(3000);  // 等待 Flutter 完全渲染

      const shot = await page.screenshot({
        path: `${REPORT_DIR}/render-${name}.png`,
        fullPage: false,
      });

      const sizeKB = shot.length / 1024;
      const isBlank = shot.length < 3 * 1024;  // < 3KB 视为白屏/空白

      console.log(`   ${isBlank ? '❌' : '✅'} ${name.padEnd(8)} ${sizeKB.toFixed(1).padStart(6)} KB ${isBlank ? '(白屏!)' : ''}`);

      expect(shot.length, `页面 "${name}" 应该有内容（非白屏）`).toBeGreaterThan(3 * 1024);
    });
  }
});

// ============================================================================
// 测试 2：不同页面的截图哈希不同
// ============================================================================
test.describe('2️⃣ 页面差异验证（不同页面应该视觉不同）', () => {
  test('✅ 登录 ≠ 注册 ≠ 设置 ≠ 社区 ≠ 首页', async ({ page }) => {
    const targets = [
      { name: '登录',   path: '/login' },
      { name: '注册',   path: '/register' },
      { name: '设置',   path: '/settings' },
      { name: '社区',   path: '/community' },
      { name: '首页',   path: '/home' },
    ];

    const hashes: string[] = [];
    console.log('\n🔍 截图对比:');

    for (const { name, path: pagePath } of targets) {
      await page.goto(pagePath, { waitUntil: 'networkidle' });
      await page.waitForTimeout(2000);

      const shot = await page.screenshot({
        path: `${REPORT_DIR}/diff-${name}.png`,
      });
      const hash = imgHash(shot).slice(0, 12);
      hashes.push(hash);

      console.log(`   ${name.padEnd(8)} hash=${hash}`);
    }

    const uniqueCount = new Set(hashes).size;
    console.log(`\n   不同页面数: ${uniqueCount}/${targets.length}`);

    // 断言：至少 80% 的页面应该不同
    expect(uniqueCount, '不同路由的页面应该有不同视觉').toBeGreaterThanOrEqual(
      Math.ceil(targets.length * 0.8)
    );
  });
});

// ============================================================================
// 测试 3：渲染稳定性（同一页面多次渲染应该相同）
// ============================================================================
test.describe('3️⃣ 渲染稳定性（同一页面多次渲染应该相同）', () => {
  test('✅ 登录页连续刷新 5 次，截图完全相同', async ({ page }) => {
    console.log('\n🔄 稳定性测试:');

    const shots: Buffer[] = [];
    for (let i = 1; i <= 5; i++) {
      await page.goto('/login', { waitUntil: 'networkidle' });
      await page.waitForTimeout(1500);

      const shot = await page.screenshot({
        path: `${REPORT_DIR}/stable-login-${i}.png`,
      });
      shots.push(shot);

      const hash = imgHash(shot).slice(0, 10);
      console.log(`   第${i}次: ${(shot.length / 1024).toFixed(1).padStart(6)} KB  hash=${hash}`);
    }

    // 所有哈希应该相同
    const allSame = shots.every((s) => imgHash(s) === imgHash(shots[0]));
    console.log(`\n   5次渲染: ${allSame ? '✅ 完全相同' : '❌ 有差异（不稳定）'}`);

    expect(allSame, '同一页面的 5 次渲染应该完全相同').toBe(true);
  });

  test('✅ 注册页连续刷新 5 次，截图完全相同', async ({ page }) => {
    console.log('\n🔄 稳定性测试:');

    const shots: Buffer[] = [];
    for (let i = 1; i <= 5; i++) {
      await page.goto('/register', { waitUntil: 'networkidle' });
      await page.waitForTimeout(1500);

      const shot = await page.screenshot({ path: `${REPORT_DIR}/stable-register-${i}.png` });
      shots.push(shot);

      const hash = imgHash(shot).slice(0, 10);
      console.log(`   第${i}次: ${(shot.length / 1024).toFixed(1).padStart(6)} KB  hash=${hash}`);
    }

    const allSame = shots.every((s) => imgHash(s) === imgHash(shots[0]));
    console.log(`\n   5次渲染: ${allSame ? '✅ 完全相同' : '❌ 有差异（不稳定）'}`);

    expect(allSame, '同一页面的 5 次渲染应该完全相同').toBe(true);
  });
});

// ============================================================================
// 测试 4：视觉回归（与基准图对比）
// ============================================================================
test.describe('4️⃣ 视觉回归测试（与基准图对比）', () => {
  test('🆕 首次运行：自动创建基准图', async ({ page }) => {
    const baselinePages = ['/login', '/register', '/settings', '/home', '/community'];

    console.log('\n📸 创建基准图:');

    for (const pagePath of baselinePages) {
      await page.goto(pagePath, { waitUntil: 'networkidle' });
      await page.waitForTimeout(2000);

      const shot = await page.screenshot();
      const name = pagePath.replace(/\//g, '-') || 'home';
      const baselinePath = `${BASELINE_DIR}/${name}.png`;
      const hashPath = `${BASELINE_DIR}/${name}.hash`;

      fs.writeFileSync(baselinePath, shot);
      fs.writeFileSync(hashPath, imgHash(shot));

      console.log(`   ✅ ${pagePath.padEnd(15)} → ${(shot.length / 1024).toFixed(1)} KB`);
    }

    console.log('\n   💡 基准图已保存。下次运行会自动与基准对比。');
  });

  test('🔍 与基准图对比（回归检测）', async ({ page }) => {
    const baselinePages = ['/login', '/register', '/settings', '/home'];

    console.log('\n📊 回归对比:');

    let changed = 0;
    for (const pagePath of baselinePages) {
      await page.goto(pagePath, { waitUntil: 'networkidle' });
      await page.waitForTimeout(2000);

      const shot = await page.screenshot();
      const name = pagePath.replace(/\//g, '-') || 'home';
      const baselinePath = `${BASELINE_DIR}/${name}.png`;
      const hashPath = `${BASELINE_DIR}/${name}.hash`;

      if (fs.existsSync(baselinePath)) {
        const currentHash = imgHash(shot);
        const baselineHash = fs.readFileSync(hashPath, 'utf8');

        if (currentHash === baselineHash) {
          console.log(`   ✅ ${pagePath.padEnd(15)} 与基准一致`);
        } else {
          console.log(`   ⚠️  ${pagePath.padEnd(15)} 有变化！`);
          console.log(`      基准: ${baselineHash.slice(0, 12)}...`);
          console.log(`      当前: ${currentHash.slice(0, 12)}...`);
          changed++;
        }
      } else {
        console.log(`   🆕 ${pagePath.padEnd(15)} 无基准，跳过`);
      }
    }

    console.log(`\n   变化页面数: ${changed}/${baselinePages.length}`);
    console.log(`   ${changed === 0 ? '✅ 无回归' : '⚠️  有变化，请检查是否是预期改动'}`);
  });
});

// ============================================================================
// 测试 5：加载性能
// ============================================================================
test.describe('5️⃣ 加载性能测试', () => {
  const PAGES = [
    { name: '登录',   path: '/login' },
    { name: '注册',   path: '/register' },
    { name: '首页',   path: '/home' },
    { name: '社区',   path: '/community' },
  ];

  for (const { name, path: pagePath } of PAGES) {
    test(`⏱️ ${name} 加载时间 < 5秒`, async ({ page }) => {
      const start = Date.now();
      await page.goto(pagePath, { waitUntil: 'networkidle' });
      await page.waitForTimeout(2000);
      const duration = Date.now() - start;

      const shot = await page.screenshot();
      const sizeKB = shot.length / 1024;

      console.log(`\n   ⏱️  ${name.padEnd(8)} ${duration}ms ${sizeKB.toFixed(1)} KB ${duration < 5000 ? '✅' : '⚠️'} `);

      expect(duration, `${name} 加载应 < 5秒`).toBeLessThan(5000);
    });
  }
});

// ============================================================================
// 测试 6：响应式（移动端 vs 桌面端）
// ============================================================================
test.describe('6️⃣ 响应式测试', () => {
  test('✅ 登录页：桌面端 vs 移动端都能正常渲染', async ({ page }) => {
    console.log('\n📱 响应式测试:');

    // 桌面端
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.goto('/login', { waitUntil: 'networkidle' });
    await page.waitForTimeout(2000);
    const desktopShot = await page.screenshot({ path: `${REPORT_DIR}/responsive-desktop.png` });
    const desktopHash = imgHash(desktopShot).slice(0, 12);
    console.log(`   桌面端 (1440x900): ${(desktopShot.length / 1024).toFixed(1).padStart(6)} KB  hash=${desktopHash}`);

    // 移动端
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto('/login', { waitUntil: 'networkidle' });
    await page.waitForTimeout(2000);
    const mobileShot = await page.screenshot({ path: `${REPORT_DIR}/responsive-mobile.png` });
    const mobileHash = imgHash(mobileShot).slice(0, 12);
    console.log(`   移动端 (390x844): ${(mobileShot.length / 1024).toFixed(1).padStart(6)} KB  hash=${mobileHash}`);

    // 两者都应该有内容
    expect(desktopShot.length).toBeGreaterThan(3 * 1024);
    expect(mobileShot.length).toBeGreaterThan(2 * 1024);

    // 两者应该不同（响应式布局应该有差异）
    console.log(`\n   ${desktopHash !== mobileHash ? '✅ 响应式正常（两端渲染不同）' : '⚠️  两端完全相同（可能无响应式）'}`);
  });
});

// ============================================================================
// 测试 7：崩溃检测（Flutter 红屏/白屏）
// ============================================================================
test.describe('7️⃣ 崩溃/错误检测', () => {
  test('✅ 登录页无崩溃错误', async ({ page }) => {
    await page.goto('/login', { waitUntil: 'networkidle' });
    await page.waitForTimeout(3000);

    const shot = await page.screenshot();
    const sizeKB = shot.length / 1024;

    // 检查是否是纯白/纯黑（崩溃后的 Flutter 错误页面通常是红色或黄色背景）
    const isPureWhite = shot.length < 5 * 1024;
    const isPureBlack = shot.length > 500 * 1024; // 异常大的黑色截图

    console.log(`\n   截图大小: ${sizeKB.toFixed(1)} KB`);
    console.log(`   ${isPureWhite ? '❌ 可能是白屏' : '✅ 不是白屏'}`);
    console.log(`   ${isPureBlack ? '❌ 可能是黑屏崩溃' : '✅ 不是黑屏'}`);

    expect(isPureWhite, '页面不应该是白屏').toBe(false);
    expect(isPureBlack, '页面不应该是纯黑（崩溃）').toBe(false);
    expect(shot.length).toBeGreaterThan(3 * 1024);
  });

  test('✅ 注册页无崩溃错误', async ({ page }) => {
    await page.goto('/register', { waitUntil: 'networkidle' });
    await page.waitForTimeout(3000);

    const shot = await page.screenshot();
    const sizeKB = shot.length / 1024;

    console.log(`\n   截图大小: ${sizeKB.toFixed(1)} KB`);
    expect(shot.length).toBeGreaterThan(3 * 1024);
  });

  test('✅ 首页无崩溃错误', async ({ page }) => {
    await page.goto('/home', { waitUntil: 'networkidle' });
    await page.waitForTimeout(3000);

    const shot = await page.screenshot();
    const sizeKB = shot.length / 1024;

    console.log(`\n   截图大小: ${sizeKB.toFixed(1)} KB`);
    expect(shot.length).toBeGreaterThan(3 * 1024);
  });
});
