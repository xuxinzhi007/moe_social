import { test, expect } from '@playwright/test';

test('🔍 诊断：页面实际加载的内容', async ({ page }) => {
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('📋 诊断 Flutter Web 页面内容');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  // 1. 打开登录页
  await page.goto('/login');
  await page.waitForLoadState('domcontentloaded');
  await page.waitForTimeout(2000);  // 等 Flutter 完全渲染

  // 2. 页面标题
  const title = await page.title();
  console.log(`\n✅ 页面标题: ${title}`);
  console.log(`✅ 页面URL: ${page.url()}`);

  // 3. body 的文本内容（看 CanvasKit vs HTML 渲染差异）
  const bodyText = await page.evaluate(() => {
    return document.body.innerText || document.body.textContent || '';
  });
  console.log(`\n✅ body.innerText 长度: ${bodyText.length} 字符`);
  console.log(`\n📄 body.innerText 前500字符:`);
  console.log('────────────────────────────────────────────────────');
  console.log(bodyText.slice(0, 500) || '(空)');
  console.log('────────────────────────────────────────────────────');

  // 4. 查看页面上有哪些 DOM 元素（role=button, role=textbox等）
  const roles = await page.evaluate(() => {
    const allElements = Array.from(document.body.querySelectorAll('*'));
    const rolesMap = new Map<string, number>();

    for (const el of allElements) {
      const role = (el as HTMLElement).getAttribute && (el as HTMLElement).getAttribute('role');
      const tag = el.tagName.toLowerCase();
      const key = role ? `${tag}[role=${role}]` : tag;
      rolesMap.set(key, (rolesMap.get(key) || 0) + 1);
    }

    return Array.from(rolesMap.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 15);
  });

  console.log(`\n🔎 DOM 元素统计（Top 15）:`);
  roles.forEach(([tag, count]) => console.log(`   ${tag}: ${count} 个`));

  // 5. 查找所有按钮（包括 Flutter 的可点击元素）
  const allClickable = await page.evaluate(() => {
    const results: Array<{ tag: string; text: string; role: string; hasClick: boolean }> = [];
    document.body.querySelectorAll('*').forEach((el) => {
      const text = (el.textContent || '').trim().slice(0, 30);
      if (!text) return;

      const htmlEl = el as HTMLElement;
      const role = htmlEl.getAttribute ? htmlEl.getAttribute('role') : '';
      const tag = el.tagName.toLowerCase();
      const hasClick = htmlEl.onclick !== null || role === 'button' ||
                       (htmlEl.style && (htmlEl.style.cursor === 'pointer' || htmlEl.style.cursor === 'hand'));

      if (hasClick || role === 'button' || tag === 'button') {
        results.push({ tag, text, role: role || '', hasClick });
      }
    });
    return results.slice(0, 10);
  });

  console.log(`\n🔘 可点击元素（Top 10）:`);
  if (allClickable.length === 0) {
    console.log('   (空 — CanvasKit 渲染模式，DOM 中没有原生按钮)');
  } else {
    allClickable.forEach((el, i) => {
      console.log(`   ${i + 1}. <${el.tag}> role=${el.role}: "${el.text}"`);
    });
  }

  // 6. 查找所有文本框
  const allInputs = await page.evaluate(() => {
    const inputs = Array.from(document.body.querySelectorAll('input, textarea, [role=textbox], [role=input]'));
    return inputs.map((el, i) => {
      const htmlEl = el as HTMLInputElement;
      return {
        tag: el.tagName.toLowerCase(),
        role: htmlEl.getAttribute ? htmlEl.getAttribute('role') : '',
        placeholder: htmlEl.placeholder || '',
        type: htmlEl.type || '',
        text: (el.textContent || '').trim().slice(0, 30),
      };
    }).slice(0, 10);
  });

  console.log(`\n📝 文本输入框:`);
  if (allInputs.length === 0) {
    console.log('   (空 — CanvasKit 渲染模式，DOM 中没有原生 input)');
  } else {
    allInputs.forEach((el, i) => {
      console.log(`   ${i + 1}. <${el.tag}> role=${el.role} placeholder="${el.placeholder}" text="${el.text}"`);
    });
  }

  // 7. 截图（直观看到页面内容）
  await page.screenshot({ path: 'playwright-report/diagnose-login.png', fullPage: true });
  console.log(`\n📸 截图已保存: playwright-report/diagnose-login.png`);

  // 8. 总结：判断是 HTML 渲染还是 CanvasKit
  const hasCanvas = await page.evaluate(() => {
    return document.body.querySelector('canvas') !== null;
  });
  const hasGlassPane = await page.evaluate(() => {
    return document.body.querySelector('flt-glass-pane') !== null;
  });
  const htmlContentSize = bodyText.length;

  console.log(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
  console.log(`📊 渲染模式诊断:`);
  console.log(`   - 检测到 <canvas>: ${hasCanvas}`);
  console.log(`   - 检测到 <flt-glass-pane>: ${hasGlassPane}`);
  console.log(`   - body 文本长度: ${htmlContentSize}`);
  if (hasCanvas && htmlContentSize < 50) {
    console.log(`   ⚠️  当前是 CanvasKit 渲染 — DOM 中几乎看不到元素`);
    console.log(`   💡 需要启用 HTML 渲染器才能做自动化测试`);
  } else if (htmlContentSize > 50) {
    console.log(`   ✅ 当前是 HTML 渲染器 — 可以正常做自动化测试`);
  }
  console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);

  // 断言：页面至少有内容
  expect(title).toBeTruthy();
});

test('🔍 诊断：检查 Flutter HTML 渲染器', async ({ page }) => {
  await page.goto('/login');
  await page.waitForTimeout(2000);

  // 直接看 window.flutterWebRenderer 是否被设置
  const renderer = await page.evaluate(() => {
    return (window as any).flutterWebRenderer || '(未设置)';
  });
  console.log(`\n🌐 window.flutterWebRenderer = "${renderer}"`);

  // 检查实际渲染的 flt-glass-pane
  const glassPaneCount = await page.evaluate(() => {
    return document.body.querySelectorAll('flt-glass-pane, flt-renderer').length;
  });
  console.log(`🌐 flt-glass-pane 数量: ${glassPaneCount}`);

  // 检查 DOM 中有没有传统 HTML 元素
  const realDom = await page.evaluate(() => {
    const buttons = document.body.querySelectorAll('button').length;
    const inputs = document.body.querySelectorAll('input').length;
    const textareas = document.body.querySelectorAll('textarea').length;
    const divs = document.body.querySelectorAll('div').length;
    const canvases = document.body.querySelectorAll('canvas').length;
    return { buttons, inputs, textareas, divs, canvases };
  });
  console.log(`\n📊 真实 DOM 元素统计:`);
  console.log(`   - <button>: ${realDom.buttons}`);
  console.log(`   - <input>: ${realDom.inputs}`);
  console.log(`   - <textarea>: ${realDom.textareas}`);
  console.log(`   - <div>: ${realDom.divs}`);
  console.log(`   - <canvas>: ${realDom.canvases}`);

  await page.screenshot({ path: 'playwright-report/diagnose-renderer.png' });
});
