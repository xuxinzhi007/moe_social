import type { Page } from '@playwright/test';

/**
 * 等待 Flutter Web 页面稳定
 * - HTML 渲染器：等待 DOM ready + network idle
 * - CanvasKit 渲染器：等待 flt-glass-pane 出现
 */
export async function waitFlutterReady(page: Page, timeoutMs = 10000): Promise<void> {
  try {
    await page.waitForLoadState('domcontentloaded', { timeout: timeoutMs });
    await page.waitForLoadState('networkidle', { timeout: timeoutMs }).catch(() => {});
    await page.waitForTimeout(300);
  } catch (e) {
    // 忽略超时，继续测试
  }
}

/**
 * 检测元素溢出视口
 * @returns 溢出元素列表
 */
export async function detectOverflow(page: Page, tolerance = 4) {
  try {
    return page.evaluate((tol) => {
      const vw = document.documentElement.clientWidth;
      const vh = document.documentElement.clientHeight;
      const overflows: Array<{ selector: string; overflowX: number; overflowY: number; text: string }> = [];

      document.body.querySelectorAll('*').forEach((el) => {
        const rect = el.getBoundingClientRect();
        if (rect.width === 0 || rect.height === 0) return;
        const ox = rect.right - vw;
        const oy = rect.bottom - vh;
        if (ox > tol || oy > tol) {
          overflows.push({
            selector: el.tagName.toLowerCase() + (el.className ? '.' + String(el.className).split(' ')[0] : ''),
            overflowX: Math.round(ox),
            overflowY: Math.round(oy),
            text: (el.textContent || '').trim().slice(0, 30),
          });
        }
      });

      return overflows.slice(0, 10);
    }, tolerance);
  } catch (e) {
    return [];
  }
}

/**
 * 收集 console.error 和 page error
 * 用于检测页面崩溃/异常
 */
export function collectErrors(page: Page): { consoleErrors: string[]; pageErrors: string[] } {
  const consoleErrors: string[] = [];
  const pageErrors: string[] = [];

  page.on('console', (msg) => {
    if (msg.type() === 'error') {
      consoleErrors.push(msg.text());
    }
  });

  page.on('pageerror', (err) => {
    pageErrors.push(err.message || String(err));
  });

  return { consoleErrors, pageErrors };
}

/**
 * 检测 Flutter 渲染错误（红屏/黄屏）
 * 通过启发式检查：大量红色背景元素或特定错误文本
 */
export async function hasRenderError(page: Page): Promise<boolean> {
  try {
    return page.evaluate(() => {
      const bodyText = document.body.innerText || document.body.textContent || '';
      // Flutter 渲染错误典型文本
      if (/Exception|Error occurred|渲染错误|Something went wrong/i.test(bodyText)) {
        return true;
      }
      // 启发式：检查是否有大量红色背景元素
      let redCount = 0;
      const elements = document.body.querySelectorAll('*');
      for (const el of elements) {
        const style = window.getComputedStyle(el as Element);
        const bg = style.backgroundColor;
        if (bg && (bg.startsWith('rgb(255') || bg.startsWith('#ff')) && parseInt(bg.replace(/\D/g, '').slice(3, 6)) < 100) {
          redCount++;
          if (redCount >= 3) return true;
        }
      }
      return false;
    });
  } catch (e) {
    return false;
  }
}
