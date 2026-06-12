import { test, expect } from '@playwright/test';

test('🔬 深度诊断：Shadow DOM / 自定义元素', async ({ page }) => {
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('🔬 Flutter Web 深度 DOM 诊断');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  await page.goto('/login');
  await page.waitForLoadState('domcontentloaded');
  await page.waitForTimeout(3000);

  // 1. 完整的 outerHTML（前2000字符）
  const fullHTML = await page.evaluate(() => document.documentElement.outerHTML);
  console.log(`\n📄 完整 HTML 长度: ${fullHTML.length} 字符`);
  console.log('────────────────────────────────────────────────────');
  console.log(fullHTML.slice(0, 2000));
  console.log('────────────────────────────────────────────────────');

  // 2. 遍历所有元素（包括 shadow root）
  const allElements = await page.evaluate(() => {
    const elements: Array<{
      tag: string;
      depth: number;
      hasShadow: boolean;
      text: string;
      attributes: Record<string, string>;
    }> = [];

    function traverse(el: Element | ShadowRoot, depth: number) {
      if (depth > 8) return;
      if (el instanceof ShadowRoot) {
        elements.push({
          tag: '#shadow-root',
          depth,
          hasShadow: false,
          text: (el.textContent || '').trim().slice(0, 40),
          attributes: {},
        });
        Array.from(el.children || []).forEach((c) => traverse(c, depth + 1));
        return;
      }

      const htmlEl = el as HTMLElement;
      const attrs: Record<string, string> = {};
      if (htmlEl.attributes) {
        for (let i = 0; i < htmlEl.attributes.length; i++) {
          const attr = htmlEl.attributes[i];
          attrs[attr.name] = attr.value.slice(0, 40);
        }
      }

      elements.push({
        tag: el.tagName.toLowerCase(),
        depth,
        hasShadow: !!(el as HTMLElement).shadowRoot,
        text: (el.textContent || '').trim().slice(0, 40),
        attributes: attrs,
      });

      // 检查 shadow root
      if ((el as HTMLElement).shadowRoot) {
        traverse((el as HTMLElement).shadowRoot!, depth + 1);
      }

      Array.from(el.children).forEach((c) => traverse(c, depth + 1));
    }

    traverse(document.body, 0);
    return elements.slice(0, 50);
  });

  console.log(`\n🌳 DOM 树（前50个节点）:`);
  allElements.forEach((el) => {
    const indent = '  '.repeat(el.depth);
    const attrsStr = Object.entries(el.attributes)
      .map(([k, v]) => `${k}="${v}"`)
      .join(' ')
      .slice(0, 60);
    console.log(
      `${indent}${el.tag}${el.hasShadow ? ' [SHADOW]' : ''}${attrsStr ? ' {' + attrsStr + '}' : ''}${el.text ? ' "' + el.text + '"' : ''}`
    );
  });

  // 3. 统计所有自定义标签
  const customTags = await page.evaluate(() => {
    const tags = new Map<string, number>();
    document.body.querySelectorAll('*').forEach((el) => {
      const tag = el.tagName.toLowerCase();
      if (tag.includes('-') || tag.startsWith('flt')) {
        tags.set(tag, (tags.get(tag) || 0) + 1);
      }
      // 检查 shadow root 内的
      const htmlEl = el as HTMLElement;
      if (htmlEl.shadowRoot) {
        htmlEl.shadowRoot.querySelectorAll('*').forEach((sel) => {
          const stag = sel.tagName.toLowerCase();
          if (stag.includes('-') || stag.startsWith('flt') || stag.length > 5) {
            tags.set('shadow::' + stag, (tags.get('shadow::' + stag) || 0) + 1);
          }
        });
      }
    });
    return Array.from(tags.entries()).sort((a, b) => b[1] - a[1]).slice(0, 20);
  });

  console.log(`\n🎨 自定义标签统计:`);
  customTags.forEach(([tag, count]) => console.log(`   ${tag}: ${count}`));

  // 4. 截图（清晰大图）
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.screenshot({ path: 'playwright-report/deep-diagnose.png', fullPage: true });
  console.log(`\n📸 截图: playwright-report/deep-diagnose.png`);

  // 5. 用 Playwright 的 getByText 查找已知文本（登录、邮箱等）
  const knownTexts = ['登录', '登 录', '邮箱', '密码', '注册', '忘记密码', 'Moe'];
  console.log(`\n🔎 Playwright getByText 查找结果:`);
  for (const text of knownTexts) {
    try {
      const count = await page.getByText(text, { exact: false }).count();
      console.log(`   "${text}": ${count} 个匹配`);
    } catch (e) {
      console.log(`   "${text}": 错误`);
    }
  }

  // 6. 检查页面的实际渲染（通过可视区域大小）
  const viewport = await page.evaluate(() => ({
    width: window.innerWidth,
    height: window.innerHeight,
    scrollWidth: document.documentElement.scrollWidth,
    scrollHeight: document.documentElement.scrollHeight,
    clientWidth: document.documentElement.clientWidth,
    clientHeight: document.documentElement.clientHeight,
  }));
  console.log(`\n📐 视口信息:`);
  console.log(`   window: ${viewport.width}x${viewport.height}`);
  console.log(`   scroll: ${viewport.scrollWidth}x${viewport.scrollHeight}`);
  console.log(`   client: ${viewport.clientWidth}x${viewport.clientHeight}`);

  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
});
