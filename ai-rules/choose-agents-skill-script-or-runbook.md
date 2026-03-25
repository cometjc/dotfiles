# 依改善內容型態決定落到 AGENTS、skill、script 或 runbook/context

## 核心要求

- 每次收斂出可重複沿用的改善時，先判斷它屬於治理規則、情境 workflow、機械步驟，還是低頻知識/證據。
- 高頻、可泛化、跨案例的治理要求，放進本地 `AGENTS.md` 或被它索引的 `ai-rules/` 章節。
- 有 trigger、決策節點、續作順序與 exit criteria 的 workflow，放進 skill。
- 輸入輸出明確、值得自動化的機械步驟，放進 `scripts/`。
- 低頻但關鍵的排障知識、證據與查表資訊，放進 runbook 或其他 context 落點，而不是堆進 `AGENTS.md`。
- 第二到第三次重複出現的手動步驟，應主動評估是否已達 script 化門檻。

## 本地同步時要討論什麼

- 本地 `AGENTS.md` 是否已明確區分治理規則與 workflow 細節。
- 哪些重複手動步驟已到 `scripts/` 化門檻。
- 本地有哪些既有 `docs/`、session artifacts 或其他 context 落點，可以承接低頻但關鍵的知識。

## 驗證方式

- 檢查專案規則是否明確區分 AGENTS、skill、script、runbook/context 的責任邊界。
- 檢查新增 workflow 細節時，是否優先改 skill，而非直接堆進 `AGENTS.md`。
- 檢查重複手動操作是否在第二到第三次後被評估並收斂為 script。
- 檢查低頻排障知識是否被放進 runbook/context，而不是散落在臨時對話中。
