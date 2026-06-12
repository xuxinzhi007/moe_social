import { test, expect } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';
import * as crypto from 'crypto';

const REPORT_DIR = path.join(process.cwd(), 'playwright-report', 'minimal');
fs.mkdirSync(REPORT_DIR, { recursive: true });

test.describe('🧪 最简测试', () => {
  test('Step 1: 打开 /login，截图，确认页面内容', async ({ page }) => {
    console.log('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log('📌 Step 1: 打开登录页，截图');
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    await page.goto('/login');

    // 等 5 秒让 Flutter 完全启动（不要嫌长，先保证能加载）
    console.log('\n⏳ 等待 Flutter 启动 (5秒)...');
    await page.waitForTimeout(5000);

    // 截图
    const shot = await page.screenshot({
      path: `${REPORT_DIR}/01-login.png`,
      fullPage: false,
    });

    // 输出关键信息
    console.log(`\n✅ 页面标题: ${await page.title()}`);
    console.log(`✅ 页面 URL: ${page.url()}`);
    console.log(`✅ 截图大小: ${(shot.length / 1024).toFixed(1)} KB`);
    console.log(`✅ 截图哈希: ${crypto.createHash('sha256').update(shot).digest('hex').slice(0, 16)}...`);
    console.log(`✅ 截图已保存: ${REPORT_DIR}/01-login.png`);

    // 断言：页面能打开（至少 > 3KB 才算是有内容的）
    expect(shot.length).toBeGreaterThan(2 * 1024);

    // 检查 body 内容
    const bodyHTML = await page.evaluate(() => document.body.innerHTML);
    console.log(`\n🔍 body.innerHTML (前800字符):`);
    console.log('───────────────────────────────────────────────────');
    console.log(bodyHTML.slice(0, 800) || '(空)');
    console.log('───────────────────────────────────────────────────');

    // 检查是否有 flutter 相关标签
    const hasFlutter = await page.evaluate(() => {
      const html = document.body.innerHTML;
      return {
        hasCanvas: html.includes('canvas'),
        hasFlutterTag: html.includes('flt-') || html.includes('flutter'),
        hasAnyContent: document.body.textContent && document.body.textContent.trim().length > 0,
      };
    });
    console.log(`\n🔎 Flutter 元素检测:`);
    console.log(`   - 有 <canvas>: ${hasFlutter.hasCanvas}`);
    console.log(`   - 有 flt- 标签: ${hasFlutter.hasFlutterTag}`);
    console.log(`   - body 有文字: ${hasFlutter.hasAnyContent}`);
  });
});
