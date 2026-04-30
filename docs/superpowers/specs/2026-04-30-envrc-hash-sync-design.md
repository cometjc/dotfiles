# .envrc Hash-Based Sync Design (A1)

Date: 2026-04-30
Status: approved for planning

## Context

Current `.envrc` sync behavior is split between:

- `files/.bashrc.d/51-env-direnv` (chpwd-triggered sync)
- `files/shared_codes/.envrc` (direnv-triggered sync)
- `files/shared_codes/shared-envrc-sync` (core merge/sync engine)

Goal: simplify governance to a single source of truth (`~/shared_codes/.envrc`) while making update decisions explicit and safe.

## Goals

- Keep `~/shared_codes/.envrc` as the single upstream template.
- Replace implicit auto-merge behavior with explicit conflict actions.
- Use Git blob hash as version identity.
- Preserve local safety: never auto-overwrite when local `.envrc` has uncommitted changes.
- Keep pre-commit non-blocking while auto-maintaining version base hashes.

## Non-goals

- No changes to `.env` sanitize filter behavior.
- No global (cross-repo) skip state.
- No automatic resolver for mismatch; user must choose explicitly.

## Source of truth and state

- Upstream template: `~/shared_codes/.envrc`
- Base hash list: `~/shared_codes/.envrc_base_hash`
  - One hash per line
  - Always normalized as `sort -u`
- Repo-local state file: `.git/user-global-envrc/state`
  - Stores `skip_permanently` and existing management flags

## Version identity

Use Git blob hash (A1):

- `shared_hash`: blob hash of `~/shared_codes/.envrc`
- `local_hash`: blob hash of repo `.envrc`
- Hash match condition:
  - `local_hash == shared_hash`, or
  - `local_hash` exists in `~/.envrc_base_hash` allowlist

## Sync decision flow

### Early exits

1. If non-interactive shell and action required, default to `skip-and-reminder`.
2. If repo `.envrc` has any uncommitted diff (staged or unstaged), do `skip-and-reminder`.
3. If repo is marked `skip-and-reminder permanently`, skip until manually unskipped.

### Match path

If hash match:

- Fast-forward update repo `.envrc` from `~/shared_codes/.envrc`.
- Keep state as managed.

### Mismatch path (explicit options only)

If hash mismatch, always show diff and prompt:

1. Push local `.envrc` to `~/shared_codes/.envrc` as new version (requires second confirmation)
2. Pull upstream and overwrite local
3. Merge local/upstream, then push merged result as new upstream version (requires second confirmation)
4. `skip-and-reminder permanently` (repo scope)

Automatic three-way merge is removed from default mismatch handling.

## Non-interactive behavior

When prompt cannot be shown (non-TTY), default action is:

- `skip-and-reminder`

No implicit overwrite, merge, or promote in non-interactive mode.

## Permanently skip behavior

- Scope: repo-local only (`.git/user-global-envrc/state`)
- Clear behavior: manual command only (`shared-envrc-sync unskip`)
- Reminder output must include usage hint for unskip.

## Option 3 AI merge prompt template

This template is shown automatically when user picks option 3:

```text
請幫我合併三份 .envrc：

- LOCAL: <repo>/.envrc
- SHARED: ~/shared_codes/.envrc
- （可選參考）BASE HASH LIST: ~/shared_codes/.envrc_base_hash

目標：
1) 輸出合併結果到 <repo>/.envrc
2) 保留 shared 的版本治理骨架
3) 保留 local 必要客製（若不衝突）
4) 不可留下 <<<<<<<, =======, >>>>>>> 標記
5) 合併完成後，請給我：
   - 摘要差異
   - 建議是否推送為 shared 新版本
```

## Pre-commit behavior

Scope: only when staged file includes `shared_codes/.envrc`.

On trigger:

1. Compute current blob hash for `shared_codes/.envrc`
2. Append hash into `shared_codes/.envrc_base_hash` if missing
3. Normalize `shared_codes/.envrc_base_hash` with `sort -u`
4. `git add shared_codes/.envrc_base_hash`
5. Exit 0 (this step is non-blocking)

This guarantees base hash lineage tracks every committed upstream template revision.

## Error handling

- Hash computation failure: emit warning and fallback to `skip-and-reminder`
- Missing upstream/shared files: no-op with reminder
- Prompt failure in interactive mismatch path: fallback to `skip-and-reminder`

## Test plan

Minimum regression coverage:

1. Hash match -> fast-forward local `.envrc`
2. Hash mismatch -> show 1/2/3/4 options
3. Non-interactive mismatch -> `skip-and-reminder`
4. Local staged/unstaged diff -> `skip-and-reminder`
5. Option 4 sets repo-local permanent skip
6. `unskip` clears permanent skip
7. Pre-commit updates `.envrc_base_hash` and stages it
8. Pre-commit keeps passing with exit 0

## Open implementation notes

- Add explicit `unskip` command to `shared-envrc-sync` usage and dispatcher.
- Keep reminder wording consistent (`skip-and-reminder`).
- Keep `51-env-direnv` aligned with scheme A entrypoint decisions during implementation phase.
