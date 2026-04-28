# setup.d 規則

## Early Skip

- Early Skip 只能用於「正向完成條件」：必須先驗證該 script 的安裝目標全部已存在，才可 `exit 0` 跳過。
- 只要該 script 會安裝多個 package/工具/檔案，Early Skip 就必須逐一覆蓋完整目標清單，不可只檢查部分目標。
- 缺少必要前置（例如依賴前序 setup script 準備的執行檔或環境）時，不可視為成功跳過；應明確 `fail` 並以非 0 結束。
- 訊息語意要與行為一致：
  - 僅在「全部目標已就緒」時輸出 `already installed` / `skipping` 類訊息。
  - 前置不足或安裝失敗時輸出 `fail` 類訊息。

## Early Skip Template

```bash
# 前置依賴（由較前序 setup script 準備）
if ! command -v <prerequisite> >/dev/null 2>&1; then
    fail "<prerequisite> not found. prerequisite setup.d/<xx-setup> should prepare it first."
    exit 1
fi

# 安裝目標清單（多目標時必填完整）
required_commands=(
    cmd-a
    cmd-b
)
required_files=(
    "$HOME/path/to/file-a"
    "$HOME/path/to/file-b"
)

all_targets_ready=true
for cmd in "${required_commands[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        all_targets_ready=false
        break
    fi
done
if $all_targets_ready; then
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            all_targets_ready=false
            break
        fi
    done
fi

if $all_targets_ready; then
    pass "<targets> are already installed, skipping"
    exit 0
fi
```

## Review Checklist

- 若 script 會安裝多個工具，`required_commands` 是否完整覆蓋？
- 若 script 會安裝設定檔/資源檔，`required_files` 是否完整覆蓋？
- Skip 判斷是否只出現在 `all_targets_ready=true` 的分支？
- 缺前置時是否為 `fail + exit 1`（不是 `pass` / `exit 0`）？

## Node 全域工具

- 在 `setup.d` 內安裝 Node 全域 CLI 時，預設使用 `bun`，不要新增 `npm install -g ...`。
