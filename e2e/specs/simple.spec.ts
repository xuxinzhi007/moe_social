import { test, expect } from '@playwright/test';

test('简单测试：检查首页', async ({ page }) => {
  console.log('🚀 开始测试');
  
  try {
    await page.goto('/login');
    console.log('✅ 页面已加载');
    
    const title = await page.title();
    console.log(`📄 页面标题: ${title}`);
    
    const bodyText = await page.textContent('body');
    console.log(`📝 页面内容长度: ${bodyText?.length || 0} 字符`);
    
    await page.screenshot({ path: 'playwright-report/simple-test.png' });
    console.log('📸 截图已保存');
    
    expect(title).toBeTruthy();
    console.log('✅ 测试通过');
  } catch (error) {
    console.error('❌ 测试失败:', error);
    throw error;
  }
});
