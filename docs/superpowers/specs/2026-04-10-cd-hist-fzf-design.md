# cd-hist percol -> fzf 設計

## 背景
目前 `files/.bashrc.d/13-cd-hist-plugin` 的 `cd_widget()` 使用 SQLite 查詢 `display_line`，再交給 `percol` 選取目錄。
目標是把 selector 從 `percol` 改成 `fzf`，並維持既有使用手感。

## 目標與非目標
### 目標
- 將 `cd_widget()` 的互動選單改為 `fzf`。
- 維持既有候選來源與排序：`last_access DESC, access_count DESC`。
- 維持取消時不報錯且不切換目錄。

### 非目標
- 不調整 SQLite schema、migration、或 history 清理策略。
- 不改動 Alt+s 綁定邏輯（僅 selector 替換）。

## 決策
採用「`fzf` 優先 + 明確缺件提示」策略：
- 若 `fzf` 可用，使用 `fzf` 進行候選過濾與選取。
- 若 `fzf` 不可用，顯示簡短錯誤訊息後返回，不進行目錄切換。

## 設計細節
### 元件邊界
- 僅修改 `cd_widget()` 內 selector 呼叫區塊。
- 保留 `PATHS` 來源 SQL 與後續 path 解析流程（前綴切除、`~` 展開、`cd`）。

### 資料流
1. 查詢 `display_line`（最多 100 筆）。
2. 將候選串流送入 `fzf`。
3. 取回選中行，依既有格式切除 22 字元前綴取得 path。
4. 展開 `~` 後 `cd` 到目標目錄。

### 錯誤處理
- 無 TTY：沿用現況，回傳 `1`。
- 無 `fzf`：輸出錯誤到 `stderr`，回傳 `1`。
- 使用者取消選單：回傳 `0`。
- `cd` 失敗：回傳 `1`。

## 測試策略
### 靜態檢查
- `bash -n files/.bashrc.d/13-cd-hist-plugin`

### 手動 smoke
1. 載入設定後按 `Alt+s`，確認 `fzf` 開啟。
2. 輸入關鍵字可過濾並 Enter 切換目錄。
3. ESC 取消不切換目錄且不中斷 shell。
4. `fzf` 不存在時，輸出明確提示並安全返回。

## 風險與緩解
- 風險：`fzf` 選單視覺方向與 `percol` 不完全一致。
- 緩解：保留原排序與結果解析，互動差異控制在最小範圍。
