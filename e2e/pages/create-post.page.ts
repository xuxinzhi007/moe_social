import type { Page, Locator } from '@playwright/test';

/**
 * 发帖页面的 Page Object。
 * 通过文本/角色定位 Flutter 渲染的元素。
 */
export class CreatePostPage {
  readonly page: Page;
  readonly contentInput: Locator;
  readonly publishButton: Locator;
  readonly imageButton: Locator;

  constructor(page: Page) {
    this.page = page;
    // 按关键字/角色定位 — Flutter Web 暴露的角色/标签
    this.contentInput = page.locator('textarea, input').filter({ hasText: /发布|动态|内容|写/ }).first();
    this.publishButton = page.getByText(/发布|发 布|发送/).first();
    this.imageButton = page.getByRole('button').filter({ hasText: /图|image/i }).first();
  }

  async goto() {
    await this.page.goto('/create-post');
    await this.page.waitForLoadState('networkidle');
  }

  /**
   * 写一段简单内容并发布
   * @param content 文本内容
   */
  async publishSimplePost(content: string) {
    // Flutter Web 的 textarea 需要先激活再输入
    await this.contentInput.click();
    await this.contentInput.fill(content);

    // 等待发布按钮可点击
    await this.publishButton.click();

    // 页面跳转到列表或首页
    await this.page.waitForURL(url => /home|feed|post/i.test(url.pathname), { timeout: 15000 });
  }
}
