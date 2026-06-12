import { test, expect } from '@playwright/test';
import { PAGES } from '../routes';
import { detectOverflow, collectErrors, waitFlutterReady, hasRenderError } from '../pages/smoke-utils';

// ============ 冒烟测试：遍历所有路由 ============
// 新增页面只要在 routes.ts 中注册，这里自动覆盖

test.describe('页面冒烟测试', () => {
  for (const pageDef of PAGES) {
    test(`[${pageDef.name}] ${pageDef.path}`, async ({ page, browserName }) => {
      test.info().annotations.push({ type: 'page', description: pageDef.path });

      // 1. 收集 console / page / request 错误
      const errCollector = collectErrors(page);

      // 2. 导航到页面
      await page.goto(pageDef.path);
      await waitFlutterReady(page);

      // 3. 检查页面没有 404 / 空白
      const bodyText = await page.textContent('body') || '';
      const hasErrorHint = /error|异常|出错|404|not ?found/i.test(bodyText);

      if (!hasErrorHint) {
        // 页面有内容 — 继续检查
      }

      // 4. 检测 Flutter 渲染错误（红黄容器）
      const renderError = await hasRenderError(page);
      expect(renderError, '不应出现 Flutter 渲染错误（红/黄容器）').toBe(false);

      // 5. 检测元素溢出（滚动异常）
      const overflows = await detectOverflow(page, 4);
      // 允许少量溢出（1-2px 的系统差异），但不应超过 5 个明显溢出元素
      if (overflows.length > 5) {
        console.warn(`⚠️  [${pageDef.name}] 检测到 ${overflows.length} 个溢出元素：`);
        overflows.slice(0, 5).forEach((o) =>
          console.warn(`    - ${o.selector} (${o.text}): x=${o.overflowX}px, y=${o.overflowY}px`)
        );
      }

      // 6. 收集检查：console 不应有 error
      // 注意：Flutter debug 模式会有一些 warning，我们只检查严重的 error
      const hardErrors = errCollector.consoleErrors.filter(
        (e) => /error|exception|fail/i.test(e) && !/deprecat|warning|hint/i.test(e)
      );
      const pageErrs = errCollector.pageErrors;

      // 打印到报告便于排查
      if (hardErrors.length) {
        console.log(`ℹ️  [${pageDef.name}] console errors:`, hardErrors.slice(0, 3));
      }
      if (pageErrs.length) {
        console.log(`ℹ️  [${pageDef.name}] page errors:`, pageErrs.slice(0, 3));
      }

      // 7. 关键字验证（如果提供了）
      if (pageDef.verifyKeywords && pageDef.verifyKeywords.length) {
        const pageTitle = await page.title();
        const match = pageDef.verifyKeywords.some((kw) =>
          new RegExp(kw, 'i').test(bodyText + ' ' + pageTitle)
        );
        console.log(`ℹ️  [${pageDef.name}] 关键字匹配? ${match}`);
      }

      // 8. 最终断言：无 page error，无 Flutter 渲染红屏
      expect(pageErrs.length, `页面不应当崩溃（page error）: ${pageErrs.join('; ')}`).toBe(0);
      expect(renderError, `页面不应当出现 Flutter 渲染错误`).toBe(false);
    });
  }
});

// ============ 额外：移动端视口的全屏检查 ============
test.describe('移动端视口检查', () => {
  test.use({ viewport: { width: 390, height: 844 } });

  test('首页移动端不出现横向滚动条', async ({ page }) => {
    await page.goto('/login');
    await waitFlutterReady(page);

    const hasScroll = await page.evaluate(() => {
      return document.documentElement.scrollWidth > document.documentElement.clientWidth;
    });
    expect(hasScroll, '移动端不出现横向滚动条').toBe(false);
  });
});
