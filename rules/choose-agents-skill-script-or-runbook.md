# 依改善內容型態決定落到 AGENTS、skill、script 或 runbook/context

## 核心要求

- 每次收斂出可重複沿用的改善時，先判斷它屬於治理規則、情境 workflow、機械步驟，還是低頻知識/證據。
- 高頻、可泛化、跨案例的治理要求，放進本地 `AGENTS.md` 或被它索引的 `rules/` 章節。
- 有 trigger、決策節點、續作順序與 exit criteria 的 workflow，放進 skill。
- 輸入輸出明確、值得自動化的機械步驟，放進 `scripts/`。
- 低頻但關鍵的排障知識、證據與查表資訊，放進 runbook 或其他 context 落點，而不是堆進 `AGENTS.md`。
- 第二到第三次重複出現的手動步驟，應主動評估是否已達 script 化門檻。

## 本地同步時要討論什麼

- 本地 `AGENTS.md` 是否已明確區分治理規則與 workflow 細節。
- 哪些重複手動步驟已到 `scripts/` 化門檻。
- 本地有哪些既有 `docs/`、session artifacts 或其他 context 落點，可以承接低頻但關鍵的知識。

## 開發中途遇到需提問情境的固化流程

- 當命中「需要澄清」判準（欄位來源不唯一、空值策略不明、格式規則不明、覆蓋策略不明、或任何會改變資料狀態且猜錯回滾成本高）時，應立即進入 AUQ 流程，不得直接猜測實作。
- AUQ 預設採兩段式非阻塞流程：先 `ask_user_questions(nonBlocking: true)` 取得 `session_id`，再用 `get_answered_questions(session_id, blocking: true)` 等待答案。
- 若 `blocking: true` 等待逾時，應改用 `get_answered_questions(session_id, blocking: false)` 輪詢，直到有答案或使用者明示改變方向。
- 每次 AUQ 呼叫後必須等待回覆，再依回覆調整下一題；不得在尚未收到上一輪答案前連續發送新問題集合。
- 使用者回覆後，應在續作前明確宣告採用的假設與調整內容，並只提交與已確認範圍一致的最小變更。

## 驗證方式

- 檢查專案規則是否明確區分 AGENTS、skill、script、runbook/context 的責任邊界。
- 檢查新增 workflow 細節時，是否優先改 skill，而非直接堆進 `AGENTS.md`。
- 檢查重複手動操作是否在第二到第三次後被評估並收斂為 script。
- 檢查低頻排障知識是否被放進 runbook/context，而不是散落在臨時對話中。
- 檢查命中澄清判準時，是否有 AUQ 啟動證據（session 或提問記錄），而非直接猜測。
- 檢查 AUQ 逾時時，是否有改用 non-blocking 輪詢，而不是中斷流程或重複盲等。
