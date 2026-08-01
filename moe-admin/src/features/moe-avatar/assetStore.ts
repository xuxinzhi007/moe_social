import { clearImageCache } from './composer/loadImage'

/** 会话内上传/覆盖的 PNG（导出 zip 时写入对应相对路径） */
export class AvatarAssetStore {
  private readonly blobs = new Map<string, Blob>()
  private readonly objectUrls = new Map<string, string>()

  has(relativePath: string): boolean {
    return this.blobs.has(relativePath)
  }

  get(relativePath: string): Blob | undefined {
    return this.blobs.get(relativePath)
  }

  /** 相对路径 → 可加载 URL（blob 或 undefined 表示走 pack 静态资源） */
  objectUrl(relativePath: string): string | undefined {
    return this.objectUrls.get(relativePath)
  }

  set(relativePath: string, blob: Blob): void {
    this.revoke(relativePath)
    this.blobs.set(relativePath, blob)
    const url = URL.createObjectURL(blob)
    this.objectUrls.set(relativePath, url)
    clearImageCache()
  }

  revoke(relativePath: string): void {
    const url = this.objectUrls.get(relativePath)
    if (url) URL.revokeObjectURL(url)
    this.objectUrls.delete(relativePath)
    this.blobs.delete(relativePath)
  }

  dispose(): void {
    for (const rel of [...this.objectUrls.keys()]) {
      this.revoke(rel)
    }
    clearImageCache()
  }
}
