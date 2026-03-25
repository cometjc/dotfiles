# 以 shared baseline 同步共同規則，並在本地逐條討論採納

## 核心要求

- `AGENTS.md` 是本地規則的唯一權威入口；正式章節只放在它索引的文件中。
- 本專案以自己的 `adopted/<project>` baseline branch 表示最近一次完成同步的 shared baseline。
- 後續跟進時，應根據 baseline diff 與其間 commit message 整理採納條目，再逐條討論本地採納。
- 本地落地完成後，才更新 `adopted/<project>` baseline branch。

## 本地同步時要討論什麼

- 本地是否已有對應章節或流程，可直接映射 shared baseline 的要求。
- 這次 baseline diff 代表的是新規則、責任邊界調整，還是既有要求被加嚴或放寬。
- 哪些差異應採更本地化、更通用、更積極、保守或不採納的策略。

## 驗證方式

- 檢查 `AGENTS.md` 是否能獨立說明本專案的規則入口與核心章節。
- 檢查保留的 `ai-rules/*.md` 是否都是 `AGENTS.md` 索引的正式章節。
- 檢查同步流程是否明確要求同時查看 baseline diff 與 commit message。
- 檢查 `adopted/<project>` baseline branch 的更新時機是否落在本地採納完成之後。
