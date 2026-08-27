#!/usr/bin/env bash
# ============================================================================
# scripts/check_ui_hardcode.sh — UI 硬编码防新增护栏
#
# 用法：
#   scripts/check_ui_hardcode.sh [base]
#   - base 缺省为 HEAD：检测「工作区未提交改动」相对 HEAD 的新增行（提交前自检）
#   - CI 场景可传目标分支：scripts/check_ui_hardcode.sh origin/main
#
# 检测范围：
#   - lib/ 下 *.dart 文件相对 base 的「新增行」（diff 中 + 行），存量代码不追溯
#   - 并纳入 untracked 新文件（git ls-files --others --exclude-standard），
#     untracked 文件按全文件所有行扫描（新文件即全部新增）
#
# 违规模式：
#   1. 硬编码颜色：Colors. 与 Color(0x          （注释行除外）
#      → 应引用 MoeTokens / MoeTheme extension
#      放行：中性色 Colors.white / Colors.black / Colors.transparent
#   2. 硬编码圆角：BorderRadius.circular(
#      → 应使用 MoeTokens.radius* 档位
#      放行：实参为 token 的调用，如 BorderRadius.circular(MoeTokens.radiusLg)、
#            BorderRadius.circular(MoeTokens.btnHeightMd / 2)
#   3. 裸组件：TextField( / TextFormField( / SnackBar( / CircularProgressIndicator(
#      → 应使用 MoeInputField / MoeToast / MoeLoading / CustomButton(isLoading)
#
# 输出：违规清单，格式 `文件:行号:[类型] 内容`。
# 退出码：0 = 无新增违规；1 = 存在新增违规；2 = 环境错误（非 git 仓库 / base 无效）。
#
# 豁免方式：
#   - 单行豁免：在违规行末尾追加注释 `// ui-hardcode: ignore`
#   - 整文件豁免：在文件前 10 行内加入 `// ui-hardcode: ignore-file`
#   - 路径豁免：环境变量 EXCLUDES（冒号分隔的路径子串），
#     默认豁免 lib/theme/moe_tokens.dart（色值 SSOT，硬编码颜色的合法源头）。
# ============================================================================
set -uo pipefail

BASE="${1:-HEAD}"
EXCLUDES="${EXCLUDES:-lib/theme/moe_tokens.dart}"
IGNORE_LINE="ui-hardcode: ignore"
IGNORE_FILE="ui-hardcode: ignore-file"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "check_ui_hardcode: 当前不在 git 仓库内" >&2
  exit 2
}
cd "$repo_root"

if ! git rev-parse --verify "$BASE" >/dev/null 2>&1; then
  echo "check_ui_hardcode: 无效的 base: $BASE" >&2
  exit 2
fi

# 判断路径是否命中 EXCLUDES（子串匹配）
is_excluded() {
  local f="$1" IFS=':'
  for pat in $EXCLUDES; do
    [ -n "$pat" ] && case "$f" in *"$pat"*) return 0 ;; esac
  done
  return 1
}

# 单文件通用豁免检查（EXCLUDES / ignore-file 标记）
file_excluded() {
  local f="$1"
  is_excluded "$f" && return 0
  head -n 10 "$f" | grep -q "$IGNORE_FILE" && return 0
  return 1
}

# 共享 AWK 程序：check_line() 为统一违规判定，diff 模式扫 + 行，full 模式扫全文件
AWK_PROG='
  function check_line(line, lineno,    tmp, reason, trimmed) {
    if (index(line, ignore) > 0) return        # 单行豁免
    trimmed = line
    sub(/^[ \t]+/, "", trimmed)
    if (trimmed ~ /^\/\//) return              # 注释行排除
    reason = ""
    if (trimmed ~ /Colors\./ || trimmed ~ /Color\(0x/) {
      # 放行中性色：Colors.white / Colors.black / Colors.transparent
      # （含 .withValues(...) 链式调用与行尾变体；white60 等透明度变体不放行）
      tmp = trimmed
      gsub(/Colors\.(white|black|transparent)[ \t)*,;:.]/, "", tmp)
      gsub(/Colors\.(white|black|transparent)$/, "", tmp)
      if (tmp ~ /Colors\./ || tmp ~ /Color\(0x/) reason = "硬编码颜色"
    } else if (trimmed ~ /BorderRadius\.circular\(/) {
      # 放行 token 实参（含 MoeTokens.x / y 推导式）
      if (trimmed !~ /BorderRadius\.circular\([ \t]*MoeTokens\./) reason = "硬编码圆角"
    } else if (trimmed ~ /TextField\(/ || trimmed ~ /TextFormField\(/ || \
               trimmed ~ /SnackBar\(/ || trimmed ~ /CircularProgressIndicator\(/) {
      reason = "裸组件"
    }
    if (reason != "") printf "%s:%d:[%s] %s\n", file, lineno, reason, trimmed
  }
  mode == "full" { check_line($0, NR); next }
  /^@@/ {
    # hunk 头 `@@ -a,b +s,e @@`，$3 = "+s,e" 或 "+s"
    plus = substr($3, 2)
    split(plus, a, ",")
    lineno = a[1] - 1
    next
  }
  /^\+\+\+/ { next }
  /^\+/ { lineno++; check_line(substr($0, 2), lineno) }
'

total=0
scan_output() {
  # $1 = 输出文本；非空则打印并累计行数
  if [ -n "$1" ]; then
    printf '%s\n' "$1"
    total=$((total + $(printf '%s\n' "$1" | wc -l | tr -d ' ')))
  fi
}

# --- 已跟踪文件：仅扫相对 base 的新增行 ---
files="$(git diff --name-only --diff-filter=ACMR "$BASE" -- 'lib/' | grep '\.dart$' || true)"
for f in $files; do
  [ -f "$f" ] || continue # 已删除文件跳过
  if file_excluded "$f"; then continue; fi
  out="$(git diff -U0 "$BASE" -- "$f" | awk -v file="$f" -v ignore="$IGNORE_LINE" -v mode="diff" "$AWK_PROG")"
  scan_output "$out"
done

# --- untracked 新文件：全文件按新增行扫描 ---
ufiles="$(git ls-files --others --exclude-standard -- 'lib/' | grep '\.dart$' || true)"
for f in $ufiles; do
  if file_excluded "$f"; then continue; fi
  out="$(awk -v file="$f" -v ignore="$IGNORE_LINE" -v mode="full" "$AWK_PROG" "$f")"
  scan_output "$out"
done

if [ "$total" -gt 0 ]; then
  echo "" >&2
  echo "check_ui_hardcode: 发现 $total 处新增违规（见上方清单）。" >&2
  echo "  修复：改用 MoeTokens / 统一组件；确需保留时行尾加 // $IGNORE_LINE" >&2
  exit 1
fi

echo "check_ui_hardcode: 无新增违规 ✓"
exit 0
