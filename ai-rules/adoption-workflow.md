# Shared baseline 採納流程

## Tracking model

- 本專案以自己的 `adopted/<project>` baseline branch 表示最近一次完成同步的 shared baseline。
- 查看 shared baseline 變化時，應同時檢查 baseline diff 與其間的 commit message。
- 若本專案尚未建立 `adopted/<project>`，第一次同步前應全量閱讀 `AGENTS.md` 與它索引的正式章節。
- 不得借用其他專案的 `adopted/*` branch 當作本專案的同步基線。

## Review loop

### 1. Inspect the baseline delta

- 已有同步基線：查看 baseline diff 與 commit message。
- 尚無同步基線：全量閱讀 `AGENTS.md` 與 `ai-rules/` 的正式章節。

### 2. Turn changes into adoption items

- 不要把 shared baseline 的文字直接當成本地必須原封不動落地的模板。
- 應先把差異收斂成可討論的採納條目，例如新流程、嚴格度調整、責任邊界重寫或索引調整。

### 3. Discuss each adoption item

- 逐條比對本地現況、觸發時機、嚴格度、落點與術語。
- 每個採納條目至少整理 4 個可選方案，並附上建議。

### 4. Integrate locally

- 將採納結果映射回本地 `AGENTS.md`、`ai-rules/`、skill、script 或既有文件。
- 若本地已有文件覆蓋相同主題，優先整併進既有落點，而不是平行新增近似檔案。

### 5. Update the baseline

- 只有在本地落地完成後，才更新 `adopted/<project>` baseline branch。
- 不要在討論途中提早更新 baseline，否則後續 diff 會掩蓋尚未消化的差異。

## 驗證方式

- 檢查 shared baseline 差異是否先被收斂成可討論的採納條目。
- 檢查每個採納條目是否有至少 4 個本地可選方案與建議。
- 檢查本地規則是否落在正確的本地文件或工具，而不是直接照抄 shared baseline。
