import { test, expect } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';

const DEBUG_DIR = path.join(process.cwd(), 'playwright-report', 'route-debug');
fs.mkdirSync(DEBUG_DIR, { recursive: true });

test.describe('🔍 Flutter Web 路由诊断', () => {
  test('1️⃣ 从根路径(/) 启动，再导航', async ({ page }) => {
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('方式 1：从根路径启动，再通过 navigator 导航');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    await page.goto('/');
    await page.waitForTimeout(3000);
    const url1 = page.url();
    const shot1 = await page.screenshot({ path: `${DEBUG_DIR}/01-root.png` });
    console.log(`\n1. 初始访问 /  → URL: ${url1}`);
    console.log(`   截图大小: ${(shot1.length / 1024).toFixed(1)} KB`);
    console.log(`   内容哈希: ${crypto.createHash('sha256').update(shot1).digest('hex').slice(0, 12)}`);

    // 用 Flutter 内部导航（点击页面元素）
    await page.goto('/register');
    await page.waitForTimeout(2000);
    const url2 = page.url();
    const shot2 = await page.screenshot({ path: `${DEBUG_DIR}/02-register.png` });
    console.log(`\n2. 跳转 /register → URL: ${url2}`);
    console.log(`   截图大小: ${(shot2.length / 1024).toFixed(1)} KB`);
    console.log(`   内容哈希: ${crypto.createHash('sha256').update(shot2).digest('hex').slice(0, 12)}`);
    console.log(`   与上一步相同? ${Buffer.compare(shot1, shot2) === 0 ? '是 ❌' : '否 ✅'}`);

    await page.goto('/settings');
    await page.waitForTimeout(2000);
    const url3 = page.url();
    const shot3 = await page.screenshot({ path: `${DEBUG_DIR}/03-settings.png` });
    console.log(`\n3. 跳转 /settings → URL: ${url3}`);
    console.log(`   截图大小: ${(shot3.length / 1024).toFixed(1)} KB`);
    console.log(`   内容哈希: ${crypto.createHash('sha256').update(shot3).digest('hex').slice(0, 12)}`);
    console.log(`   与上一步相同? ${Buffer.compare(shot2, shot3) === 0 ? '是 ❌' : '否 ✅'}`);

    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  });

  test('2️⃣ 直接在 URL 中访问不同路由', async ({ page }) => {
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('方式 2：直接访问完整 URL（模拟用户在地址栏输入）');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    const routes = ['/login', '/register', '/forgot-password', '/home', '/settings'];
    const screenshots: { route: string; hash: string; size: number }[] = [];

    for (const route of routes) {
      await page.goto(route, { waitUntil: 'domcontentloaded' });
      await page.waitForTimeout(2500);

      const url = page.url();
      const shot = await page.screenshot({
        path: `${DEBUG_DIR}/direct-${route.replace(/\//g, '-')}.png`,
      });
      const hash = crypto.createHash('sha256').update(shot).digest('hex').slice(0, 12);

      screenshots.push({ route, hash, size: shot.length });
      console.log(`\n   ${route} → ${url}`);
      console.log(`     大小: ${(shot.length / 1024).toFixed(1)} KB, hash: ${hash}`);
    }

    // 统计唯一的哈希值
    const uniqueHashes = new Set(screenshots.map((s) => s.hash));
    console.log(`\n📊 结果: ${screenshots.length} 个路由，产生 ${uniqueHashes.size} 个不同页面`);
    console.log(`   ${uniqueHashes.size === screenshots.length ? '✅ 每个路由都渲染不同页面' : '⚠️  部分路由渲染相同页面（Flutter 可能没正确响应 URL）'}`);

    if (uniqueHashes.size < screenshots.length) {
      console.log('\n💡 提示：Flutter Web 可能需要配置 usePathUrlStrategy 才能正确响应 URL 路由');
      console.log('💡 或者需要在 MaterialApp 中配置正确的 navigatorKey / routes');
    }
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  });

  test('3️⃣ 在浏览器 Console 检查 Flutter 状态', async ({ page }) => {
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('方式 3：通过 JavaScript 注入检查 Flutter 运行时');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    await page.goto('/login');
    await page.waitForTimeout(3000);

    // 检查 window.flutter 相关对象
    const flutterObjects = await page.evaluate(() => {
      const win = window as any;
      return {
        flutterInited: typeof win.flutter_get_callback !== 'undefined',
        hasWindowLocation: win.location ? true : false,
        currentPath: win.location ? win.location.pathname : '',
        currentHash: win.location ? win.location.hash : '',
        documentTitle: document.title,
        bodyChildrenCount: document.body ? document.body.children.length : 0,
        bodyHTML: document.body ? document.body.innerHTML.slice(0, 500) : '',
        hasCanvas: document.body ? !!document.body.querySelector('canvas') : false,
      };
    });

    console.log(`\n📊 Flutter Web 状态:`);
    console.log(`   flutter_get_callback: ${flutterObjects.flutterInited}`);
    console.log(`   window.location.pathname: ${flutterObjects.currentPath}`);
    console.log(`   window.location.hash: ${flutterObjects.currentHash}`);
    console.log(`   document.title: ${flutterObjects.documentTitle}`);
    console.log(`   body.children.length: ${flutterObjects.bodyChildrenCount}`);
    console.log(`   有 <canvas>: ${flutterObjects.hasCanvas}`);
    console.log(`   body.innerHTML (前500字符): ${flutterObjects.bodyHTML}`);

    await page.screenshot({ path: `${DEBUG_DIR}/flutter-state.png` });
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  });

  test('4️⃣ 通过 Dart 方法触发路由（在 Flutter 运行时内导航）', async ({ page }) => {
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('方式 4：Flutter 加载完成后，观察页面初始状态');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // Flutter Web 可能在应用启动时自动导航到 initialRoute
    // 我们需要在 Flutter 应用完全初始化后再测试

    const waitDuration = 5000;
    console.log(`\n⏳ 等待 Flutter 完全启动 (${waitDuration}ms)...`);

    await page.goto('/login');
    await page.waitForTimeout(waitDuration);

    const initialShot = await page.screenshot({ path: `${DEBUG_DIR}/4-initial-login.png` });
    const initialHash = crypto.createHash('sha256').update(initialShot).digest('hex').slice(0, 12);
    console.log(`\n1. 初始状态 (/login): hash=${initialHash}, size=${(initialShot.length / 1024).toFixed(1)}KB`);

    // 尝试通过浏览器历史改变 URL（不触发页面 reload）
    await page.evaluate(() => {
      window.history.pushState({}, '', '/register');
    });
    await page.waitForTimeout(2000);

    const shot2 = await page.screenshot({ path: `${DEBUG_DIR}/4-pushstate-register.png` });
    const hash2 = crypto.createHash('sha256').update(shot2).digest('hex').slice(0, 12);
    console.log(`2. pushState(/register) 后: hash=${hash2}`);
    console.log(`   ${hash2 !== initialHash ? '✅ 页面有变化（Flutter 响应了 history）' : '⚠️  页面没变化（Flutter 没响应）'}`);

    // 重新加载为 /register
    await page.goto('/register');
    await page.waitForTimeout(2000);

    const shot3 = await page.screenshot({ path: `${DEBUG_DIR}/4-direct-register.png` });
    const hash3 = crypto.createHash('sha256').update(shot3).digest('hex').slice(0, 12);
    console.log(`\n3. 直接访问 /register: hash=${hash3}`);
    console.log(`   ${hash3 !== initialHash ? '✅ 页面有变化（路由生效）' : '⚠️  页面没变化（路由没生效）'}`);

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  });
});
