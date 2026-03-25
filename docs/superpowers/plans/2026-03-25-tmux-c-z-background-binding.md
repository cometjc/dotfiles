# tmux bare `C-z` background binding Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a bare `C-z` tmux binding that sends `Ctrl-Z`, waits for the shell to regain control, and then sends `bg` to the active pane so shell jobs keep running in the background.

**Architecture:** Keep the change small and local by editing the existing tmux config in `files/.tmux.conf`, adding a focused helper script in `scripts/tmux-background-job.sh`, and extending tmux regression coverage in `tests/tmux-config-regression.bash` plus a helper-specific regression in `tests/tmux-background-job-regression.bash`. Validate both the static config line and the helper's wait-until-shell-ready behavior.

**Tech Stack:** tmux, Bash, existing repo regression tests

---

## Chunk 1: Add the binding and lock it down with regression coverage

### File map

- Modify: `files/.tmux.conf` — add the bare `C-z` root-table binding in the existing non-prefix `bind-key -n` section.
- Add: `scripts/tmux-background-job.sh` — send `C-z`, wait for the foreground command to change, then send `bg`.
- Modify: `tests/tmux-config-regression.bash` — assert the binding delegates through the helper and validate runtime registration in an isolated tmux server.
- Add: `tests/tmux-background-job-regression.bash` — regression-test the helper's wait-before-`bg` behavior.
- Read for context: `docs/superpowers/specs/2026-03-25-tmux-c-z-background-binding-design.md`

### Task 1: Extend regression coverage before changing tmux config

**Files:**
- Modify: `tests/tmux-config-regression.bash:1-64`
- Read: `files/.tmux.conf:121-168`
- Spec: `docs/superpowers/specs/2026-03-25-tmux-c-z-background-binding-design.md`

- [ ] **Step 1: Write the failing test assertions**

Add code to `tests/tmux-config-regression.bash` that:

```bash
binding_matches="$(grep -E '^[[:space:]]*bind-key[[:space:]]+-n[[:space:]]+C-z([[:space:]]|$)' "$tmux_conf" || true)"
binding_count="$(printf '%s\n' "$binding_matches" | sed '/^$/d' | wc -l)"
binding_line="$(printf '%s\n' "$binding_matches" | sed -n '1p')"

if [[ "$binding_count" != "1" ]]; then
    fail "tmux.conf should define exactly one bare C-z binding"
fi

assert_contains "$binding_line" "send-keys C-z" \
    "tmux.conf should send literal Ctrl-Z before bg"
assert_contains "$binding_line" 'send-keys "bg" Enter' \
    "tmux.conf should send bg after Ctrl-Z"
```

Add isolated runtime validation using a dedicated tmux socket:

```bash
socket_name="copilot-tmux-c-z-test-$$"
tmux -L "$socket_name" -f /dev/null new-session -d -s cztmp
trap 'tmux -L "$socket_name" kill-server >/dev/null 2>&1 || true' EXIT
printf '%s\n' "$binding_line" | tmux -L "$socket_name" source-file -
root_keys="$(tmux -L "$socket_name" list-keys -T root)"
copy_mode_keys="$(tmux -L "$socket_name" list-keys -T copy-mode)"
copy_mode_vi_keys="$(tmux -L "$socket_name" list-keys -T copy-mode-vi)"
prefix_keys="$(tmux -L "$socket_name" list-keys -T prefix)"
```

Then assert:

```bash
assert_contains "$root_keys" "bind-key -T root C-z" \
    "root table should register bare C-z binding"
assert_contains "$root_keys" "send-keys bg Enter" \
    "root table should register the backgrounding action"
assert_not_contains "$prefix_keys" 'send-keys bg Enter' \
    "prefix table should not define the new backgrounding binding"
assert_not_contains "$copy_mode_keys" 'send-keys bg Enter' \
    "copy-mode table should not define the new backgrounding binding"
assert_not_contains "$copy_mode_vi_keys" 'send-keys bg Enter' \
    "copy-mode-vi table should not define the new backgrounding binding"
```

The trap handles cleanup automatically, including the expected failing-test run.

- [ ] **Step 2: Run the regression test and confirm it fails**

Run:

```bash
bash tests/tmux-config-regression.bash
```

Expected: FAIL with a message indicating that `tmux.conf` should define exactly one bare `C-z` binding.

### Task 2: Add the tmux binding with the smallest possible config change

**Files:**
- Modify: `files/.tmux.conf:121-168`
- Test: `tests/tmux-config-regression.bash`

- [ ] **Step 1: Add the binding in the existing non-prefix block**

Insert one line near the other `bind-key -n` mappings:

```tmux
bind-key -n C-z send-keys C-z \; send-keys "bg" Enter
```

Place it with the other direct pane keybindings, not in the prefix-bound section.

- [ ] **Step 2: Re-run the regression test and confirm it passes**

Run:

```bash
bash tests/tmux-config-regression.bash
```

Expected: PASS with `All tmux config regression tests passed`.

### Task 3: Perform the requested runtime behavior check

**Files:**
- No repository file changes required
- Use: local tmux session for manual verification

- [ ] **Step 1: Run a manual shell smoke test**

In a tmux shell pane, run:

```bash
tmux source-file "$HOME/repo/dotfiles/files/.tmux.conf"
sleep 100
```

Then press bare `Ctrl-Z`, and run:

```bash
jobs
```

Expected: the `sleep 100` job appears as running in the background instead of staying stopped.

- [ ] **Step 2: Verify accepted edge-case behavior is unchanged**

In a shell pane with no fresh foreground job to stop, press bare `Ctrl-Z`.

Expected: one of the accepted design outcomes occurs (`bg` becomes plain input, shell prints `bg: no current job`, or an older stopped job resumes). Do not add guard logic for these cases.

- [ ] **Step 3: Commit the finished change**

Run:

```bash
git add files/.tmux.conf tests/tmux-config-regression.bash
git commit -m "feat(tmux): bind bare C-z to background jobs"
```

Expected: a commit containing only the tmux config change and regression coverage from this implementation chunk.
