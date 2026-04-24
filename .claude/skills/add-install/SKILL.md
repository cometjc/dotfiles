---
name: add-install
description: Use when adding or updating a setup.d installer in this dotfiles repo and the task needs local style, placement, and smoke-check guidance
---

# Add Install

## Overview

在這個 repo 新增安裝步驟時，先判斷它應該落在哪個 `setup.d` 腳本，再比照既有 installer 寫法實作。重點不是把指令貼上去，而是讓它和現有執行順序、Early Skip 與驗證模型一致。

## When to Use

- 使用者要把新工具、新 app、或新的官方 installer 加進 `setup.d/`
- 需要判斷應該新增獨立腳本，還是併入既有分組腳本
- 需要比照這個 repo 的 `common-lib`、`pass/change/fail`、Early Skip 與 smoke check 慣例

不要用在：

- 單純修改 `files/` 內的 shell alias 或 env 設定，沒有碰 `setup.d/`
- 已有明確現成腳本，只是做小幅參數調整

## Workflow

1. 先找現況：
   - 搜 `setup.d/` 是否已有該工具或同類工具
   - 搜 `files/.bashrc`、`files/.profile` 是否已經有相關 env/init 片段
   - 讀 `setup.d/AGENTS.md`，確認 Early Skip 和前置依賴規則
2. 判斷歸位：
   - 若工具屬於既有集合而且同一腳本已管理同類 installer，才考慮併入
   - 若工具有獨立生命週期、獨立官方 installer、或和既有集合耦合低，優先新增獨立 `setup.d/<nn>-<name>`
3. 套用骨架：
   - 使用 `common-lib` 載入樣板
   - 只在「全部目標都已就緒」時 Early Skip
   - 缺少必要前置時要 `fail`，不能假裝 skip 成功
   - 若 installer 會寫入私有 bin/env 檔，安裝前後都要考慮載入該 env 再檢查 command
4. 做最小驗證：
   - `bash -n setup.d/<script>`
   - 若檔案是新建的，設 executable bit
   - 能低成本驗證時，再確認安裝後的主要 command 可被偵測

## Placement Heuristics

- `50-56` 類腳本偏向語言工具鏈與 package manager 生態
- `70+` 類腳本偏向獨立工具、桌面 app、或第三方安裝流程
- 有明確官方 `curl | sh` installer 的單一工具，通常適合獨立腳本，不要硬塞進語言工具集合

## Checklist

- 是否先確認 repo 內已有相關 shell/init 設定？
- 是否選了正確的 `setup.d` 編號與歸類？
- Early Skip 是否只檢查完整成功條件？
- 安裝後是否做了至少一個 smoke check？
- 是否避免改動不相干的 setup 腳本？
