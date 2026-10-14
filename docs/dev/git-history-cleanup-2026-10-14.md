# Git 历史瘦身与多机同步记录（2026-10-14）

## 背景

仓库 `.git` 曾膨胀到 571M，原因是历史提交里误提交了大量编译产物（Go 二进制、node_modules 原生模块、cover.out 等）。虽然这些文件早已被 `.gitignore` 挡住，但已经进历史的对象不会自动消失。

同时工作目录里还有一批可再生的构建缓存占空间。

## 做了什么

### 批 A：删除零风险的再生产物（已 ignore，可随时删）

```bash
rm -rf build .dart_tool moe-admin/node_modules
```

回收约 700M，无任何功能影响（下次 flutter / npm 会自动重建）。

### 批 B：重写 git 历史，剔除大文件

```bash
# 1. 备份（镜像，含全部分支+tag）
git clone --mirror . /tmp/moe_social-backup.git

# 2. 重写历史：剔除所有 >5M 的 blob
brew install git-filter-repo
git filter-repo --strip-blobs-bigger-than 5M --force

# 3. filter-repo 会摘掉 origin，重新挂上
git remote add origin git@github.com:xuxinzhi007/moe_social.git

# 4. 强推（远程只有这 3 个分支 + 全部 tag）
git push --force origin main feat/kratos-hybrid-migration feat/social-main-path --tags
```

结果：`.git` 571M → 133M，历史中 >5M blob 清零，分支/tag 全保留。

## 多机同步方法

**结论：历史重写后，所有 commit SHA 都变了。旧机器上 `git pull` 会分叉报错，必须按下面处理。**

### 情形 1：机器上没有要保留的本地改动（最常见）

直接删掉重 clone：

```bash
rm -rf moe_social
git clone git@github.com:xuxinzhi007/moe_social.git
```

### 情形 2：不想重新下大目录，或要保留本地的 ignore 产物

在旧 clone 里原地同步（不重 clone）：

```bash
git fetch origin
git reset --hard origin/<分支名>        # 每个分支都要做
git fetch --tags --force origin          # tag 也被重写了，要强制重新拉

# 想让本地 .git 也变小，再补两步（否则旧对象还在 reflog 里）
git reflog expire --expire=now --all
git gc --prune=now --aggressive
```

> ⚠️ `reset --hard` / `git clean -fd` 会丢本地未提交、未推送的内容，动手前先确认。

## 注意事项

- **不要**在旧 clone 里 `git pull`：新旧历史分叉，merge 会把旧大文件又带回来，前功尽弃。
- 重写只影响 commit SHA，提交内容、提交信息、分支、tag 全部保留。
- 强推后 GitHub 会在后台自动回收旧对象，新 clone 的体积立即变小（实测 113M）。

## 踩坑记录（2026-10-14 实际遇到）

1. **filter-repo 因 `.git/config` 里 `user.name` 末尾有多余换行符而崩溃**（`ValueError: dictionary update sequence element #21 has length 1`）。修法：`git config --local user.name "xuxinzhi007"`（值不变，只去掉脏换行）。
2. **IDE 自动 fetch 会把旧对象拉回本地**。重写并强推后，Cursor/VS Code 的自动 fetch（特征命令 `fetch origin --recurse-submodules=no --progress --prune`）在过渡窗口里可能把旧 SHA 写回 `refs/remotes/origin/*`，导致本地 `.git` 再次膨胀（本次从 133M 涨回 537M）。修法：

   ```bash
   git fetch origin --prune                          # 把跟踪引用拉回新 SHA
   git reflog expire --expire=now --all
   git gc --prune=now --aggressive                   # 清掉不可达旧对象
   ```

3. **确认没有别的机器/脚本在 force-push 旧历史**。若远程被反复覆盖回旧 SHA，检查是否有另一台机器或定时任务在 `git push --force`。判定方法：`git ls-remote origin refs/heads/main` 连续两次看是否稳定，或 `git reflog show refs/remotes/origin/main` 看谁在更新。

## 未来预防

- `.gitignore` 已覆盖 `backend/bin/`、`backend/rpc/`、`*.exe`、`build/`、`.dart_tool/`、`**/node_modules/` 等，不要再提交这些。
- `backend/config/config.yaml` 目前含七牛 `access_key` / `secret_key` 明文（已跟踪）。若仓库转公开，需先轮换密钥并改为 `MOE_QINIU_ACCESS_KEY` / `MOE_QINIU_SECRET_KEY` 环境变量注入。
- 大文件（>5M）如需入库，考虑用 Git LFS 或外部存储（后端已有 `BlobStore` 抽象：local / oss / qiniu）。
