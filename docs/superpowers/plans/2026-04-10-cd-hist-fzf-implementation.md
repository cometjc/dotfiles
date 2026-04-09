# cd-hist fzf Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 將 `cd_widget()` 的 selector 從 `percol` 改為 `fzf`，維持既有排序與取消語意。

**Architecture:** 保留現有 SQLite `display_line` 查詢、選中行解析與 `cd` 流程，只替換 selector 呼叫與缺件錯誤訊息。透過一個輕量回歸測試腳本驗證「不再依賴 percol、改用 fzf」的核心契約，再做語法檢查與手動 smoke test。

**Tech Stack:** Bash, SQLite (`sqlite3`), fzf, ripgrep

---

### Task 1: 建立 selector 契約回歸測試

**Files:**
- Create: `tests/cd-hist-selector-regression.bash`
- Test: `tests/cd-hist-selector-regression.bash`

- [ ] **Step 1: 撰寫失敗中的測試（先定義契約）**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
plugin="$repo_root/files/.bashrc.d/13-cd-hist-plugin"
content="$(cat "$plugin")"

if grep -q "percol" <<<"$content"; then
  echo "FAIL: plugin should not depend on percol"
  exit 1
fi

if ! grep -q "fzf" <<<"$content"; then
  echo "FAIL: plugin should call fzf"
  exit 1
fi

echo "PASS"
```

- [ ] **Step 2: 執行測試，確認目前會失敗**

Run: `bash tests/cd-hist-selector-regression.bash`
Expected: FAIL（目前仍包含 `percol`）

- [ ] **Step 3: 提交測試檔**

```bash
git add tests/cd-hist-selector-regression.bash
git commit -m "test(cd-hist): add selector backend regression check"
```

### Task 2: 實作 percol -> fzf 替換

**Files:**
- Modify: `files/.bashrc.d/13-cd-hist-plugin`
- Test: `tests/cd-hist-selector-regression.bash`

- [ ] **Step 1: 先修正文案與相依檢查邏輯**

```bash
# 在 cd_widget() 中：
# 1) 將「No tty available for percol」改為不綁定 percol 名稱
# 2) 新增 `command -v fzf` 檢查；缺件時印錯誤並 return 1
```

- [ ] **Step 2: 將 selector 命令改為 fzf（最小改動）**

```bash
cd_target=$(fzf --prompt='cd> ' <<<"$PATHS")
```

- [ ] **Step 3: 保留既有取消與 path 解析語意**

```bash
# - 空字串直接 return 0
# - 仍用固定前綴長度切 path
# - 保留 ~ 展開與 cd 行為
```

- [ ] **Step 4: 執行回歸測試，確認通過**

Run: `bash tests/cd-hist-selector-regression.bash`
Expected: PASS

- [ ] **Step 5: 提交功能變更**

```bash
git add files/.bashrc.d/13-cd-hist-plugin
git commit -m "feat(cd-hist): switch selector backend from percol to fzf"
```

### Task 3: 驗證與手動 smoke

**Files:**
- Modify: `files/.bashrc.d/13-cd-hist-plugin`（若驗證時發現需微調）
- Test: `tests/cd-hist-selector-regression.bash`

- [ ] **Step 1: 語法檢查**

Run: `bash -n files/.bashrc.d/13-cd-hist-plugin`
Expected: 無輸出、exit code 0

- [ ] **Step 2: 本地手動 smoke（互動）**

Run:
```bash
source files/.bashrc.d/13-cd-hist-plugin
# 在互動 shell 按 Alt+s
```

Expected:
- `fzf` 視窗可開啟
- 輸入關鍵字可過濾
- Enter 後可切換目錄
- ESC 取消不改變目錄

- [ ] **Step 3: 缺件情境驗證（可選）**

Run:
```bash
PATH="/nonexistent:$PATH" bash -ic 'source files/.bashrc.d/13-cd-hist-plugin; cd_widget'
```

Expected: 顯示缺少 `fzf` 的錯誤並安全返回

- [ ] **Step 4: 若有微調則提交**

```bash
git add files/.bashrc.d/13-cd-hist-plugin
git commit -m "fix(cd-hist): polish fzf selector behavior"
```
