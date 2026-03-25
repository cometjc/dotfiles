# dotfiles rules

這個 repo 以 `AGENTS.md` 為本地規則的唯一權威入口。
正式規則章節放在 `ai-rules/*.md`，並由這份索引維持一致。

## 目的

- 為這個專案提供單一可查找的治理入口。
- 讓 shared baseline 的共用規則能以本地術語與本地例外落地。
- 避免規則散落在對話、臨時文件或重複的工具 adapter 中。

## 權威入口

- `AGENTS.md` 是本專案的唯一權威入口與索引。
- `ai-rules/*.md` 只存放被這裡索引的正式規則章節。
- 規則差異的脈絡優先由 git diff 與 commit message 承接。
- 調整規則時，應同步更新 `AGENTS.md` 與受影響章節，避免索引漂移。

## 核心章節

- [ai-rules/adoption-workflow.md](ai-rules/adoption-workflow.md): shared baseline 差異如何整理成本地採納條目並逐條決策。
- [ai-rules/shared-baseline-sync-and-local-adoption.md](ai-rules/shared-baseline-sync-and-local-adoption.md): shared baseline 同步與本地落地的核心工作模型。
- [ai-rules/commit-each-minimum-viable-change.md](ai-rules/commit-each-minimum-viable-change.md): 每完成一個可獨立驗證的最小變更單位就先提交，並盤點剩餘未提交變更。
- [ai-rules/choose-agents-skill-script-or-runbook.md](ai-rules/choose-agents-skill-script-or-runbook.md): 依改善內容型態決定該落到 AGENTS、skill、script 或 runbook/context。
- [ai-rules/distinguish-rule-suggestions-from-established-process-state.md](ai-rules/distinguish-rule-suggestions-from-established-process-state.md): 區分新的規則建議與既定流程狀態說明。
- [ai-rules/surface-stale-untracked-governance-files-at-stop.md](ai-rules/surface-stale-untracked-governance-files-at-stop.md): 停工回報時清查超齡 untracked 治理條目。
- [ai-rules/verify-third-party-module-interface-before-integration.md](ai-rules/verify-third-party-module-interface-before-integration.md): 第三方模組接入前先驗證官方介面與最小 smoke check。

## 語言

- 以繁體中文（zh-TW）思考並回覆所有對話。

## 目錄

- `ai-rules/`: 本專案的正式規則章節
- `docs/`: 已落地的 spec、設計脈絡與其他可提交文件
- `scripts/`: 值得自動化的機械步驟
- session artifacts: 不應提交到 repo 的暫時規劃或工作中產物
