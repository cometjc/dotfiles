# setup.d 規則

## Early Skip

- Early Skip 只能用於「正向完成條件」：必須先驗證該 script 的安裝目標全部已存在，才可 `exit 0` 跳過。
- 只要該 script 會安裝多個 package/工具/檔案，Early Skip 就必須逐一覆蓋完整目標清單，不可只檢查部分目標。
- 缺少必要前置（例如依賴前序 setup script 準備的執行檔或環境）時，不可視為成功跳過；應明確 `fail` 並以非 0 結束。
- 訊息語意要與行為一致：
  - 僅在「全部目標已就緒」時輸出 `already installed` / `skipping` 類訊息。
  - 前置不足或安裝失敗時輸出 `fail` 類訊息。
