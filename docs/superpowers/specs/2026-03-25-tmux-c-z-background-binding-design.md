# tmux bare `C-z` background binding

## Problem

Inside tmux, bare `C-z` should suspend the foreground job in the active pane and resume it in the shell background so the process keeps running without a manual `bg`.

The naive implementation sent `C-z` and `bg` back-to-back, which could queue `bg` too early and deliver it to the foreground program instead of the shell.

## Implemented solution

The final implementation keeps the binding global in tmux's root table, but delegates the sequencing to a helper:

- `files/.tmux.conf` binds bare `C-z` with `bind-key -n C-z`
- the binding calls `scripts/tmux-background-job.sh`
- the helper receives both `#{pane_id}` and the pre-suspend `#{pane_current_command}`
- the helper sends literal `C-z` to the active pane
- the helper waits until both of these are true:
  - `#{pane_current_command}` no longer matches the original foreground command
  - the bottom of the pane shows a visible `Stopped ... <command>` marker
- only then does the helper send `bg` and Enter

If those conditions never stabilize within the configured polling window, the helper still falls back to sending `bg` so the behavior remains bounded.

## File map

- `files/.tmux.conf` — bare `C-z` binding in the existing non-prefix keybinding block
- `scripts/tmux-background-job.sh` — helper that sequences `C-z`, condition-based waiting, and `bg`
- `tests/tmux-config-regression.bash` — static and runtime validation of the tmux binding
- `tests/tmux-background-job-regression.bash` — focused regression coverage for helper timing behavior

## Supported context

- Guaranteed: normal interactive pane usage where tmux dispatches keys through the root table
- Accepted but undefined: copy-mode, command-prompt, and other non-root-table contexts; no table-specific handling is added

## Validation

`tests/tmux-config-regression.bash` verifies that:

- exactly one bare `bind-key -n C-z` line exists
- the binding delegates through `tmux-background-job.sh`
- the binding passes both `#{pane_id}` and `#{pane_current_command}`
- an isolated tmux server registers the binding in `root`
- the helper binding does not appear in `prefix`, `copy-mode`, or `copy-mode-vi`

`tests/tmux-background-job-regression.bash` verifies that the helper:

- sends `C-z` first
- polls until shell handoff and a visible `Stopped ... <command>` marker are both present
- sends `bg Enter` only after those conditions are met
- falls back to sending `bg` after the timeout budget if the stopped marker never appears

## Manual verification

In a tmux shell pane:

```bash
tmux source-file "$HOME/repo/dotfiles/files/.tmux.conf"
sleep 100
```

Then press bare `Ctrl-Z` and run:

```bash
jobs
```

Expected: the job appears resumed in the background rather than remaining stopped.

## Trade-offs

- This intentionally remains a global bare `C-z` tmux binding.
- If `C-z` does not create a fresh stopped job, the later `bg` may still become plain input, print shell feedback such as `bg: no current job`, or resume an older stopped job.
- The implementation avoids shell detection and uses condition-based waiting instead of a blind fixed delay.

## Out of scope

- Detecting whether the active pane is running a shell
- Falling back to a prefix-only binding
- Reusing the separate tmux `bg` session/window-moving workflow on `Prefix + b`
