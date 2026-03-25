# tmux bare `C-z` background binding design

## Problem

Inside tmux, the user wants bare `C-z` to suspend the foreground job in the active pane and immediately resume it in the shell background so the process keeps running without requiring a manual `bg`.

## Approved approach

Add a global tmux key binding in `files/.tmux.conf` using `bind-key -n C-z`.

When triggered, tmux will:

1. Invoke a helper script with the active pane id and the current foreground command name.
2. Have the helper script send a literal `C-z` keystroke to the active pane.
3. Wait until `#{pane_current_command}` no longer matches the pre-suspend foreground command, or until a short timeout window expires.
4. Send `bg` followed by Enter to the same pane.

This binding is added only to tmux's root table via `bind-key -n`. No copy-mode, prompt, or other table-specific bindings are added.

Supported context:

- Guaranteed: normal interactive pane usage where tmux is dispatching keys through the root table.
- Accepted but undefined: copy-mode, command-prompt, and any other non-root-table interaction context. The design does not add special handling for those modes.

This keeps the change aligned with the user's request for global bare `C-z` behavior while staying explicit about the contexts we are intentionally not tailoring.

## Placement

Keep the binding inside the existing `bind-key -n` block in `files/.tmux.conf`, next to the other non-prefix pane keybindings, so the configuration stays organized alongside other direct pane input mappings.

Add the helper implementation in `scripts/tmux-background-job.sh`.

## Validation

Extend `tests/tmux-config-regression.bash` to extract the exact `bind-key -n C-z` line from `files/.tmux.conf`, assert that exactly one such line exists, and assert that the line delegates through `tmux-background-job.sh` with both `#{pane_id}` and `#{pane_current_command}`.

Add a helper-script regression test that verifies the helper sends `C-z`, polls `#{pane_current_command}` until it changes away from the captured foreground command, then sends `bg Enter`. Also verify that the helper still falls back to sending `bg` after the timeout budget expires.

Add a runtime validation step that uses an isolated tmux server started with `-f /dev/null` and a dedicated socket name. Feed the exact extracted `bind-key -n C-z` line from `files/.tmux.conf` into that isolated server, then verify:

1. `tmux list-keys -T root` shows the expected `C-z` binding.
2. `tmux list-keys -T prefix`, `tmux list-keys -T copy-mode`, and `tmux list-keys -T copy-mode-vi` do not show the helper binding outside `root`.

This runtime check validates tmux parsing and table registration without loading the repository's full `.tmux.conf`, plugin bootstrap, or hooks, so it stays deterministic and does not interfere with the user's live tmux environment.

Run the existing tmux regression test after the change.

Perform a manual tmux smoke test in an interactive shell pane with a simple foreground job such as `sleep 100`. Press bare `C-z`, then run `jobs` and confirm the job appears resumed in the background rather than remaining stopped.

## Trade-offs

- In shell panes with job control, this should suspend the foreground job, wait for the shell to regain control, and then resume it with `bg`, matching the requested workflow.
- If `C-z` does not create a new stopped job, the subsequent `bg` may be delivered as plain input, may produce shell feedback such as `bg: no current job`, or may resume an older stopped job already known to the shell. These outcomes are acceptable for this design; the binding does not attempt to detect or suppress them.
- In non-shell programs inside tmux, tmux will still send `C-z` and then `bg`, which may not be meaningful. This is an accepted consequence of the requested global binding.
- The design intentionally avoids shell detection and uses a small helper script with condition-based waiting instead of a blind fixed delay.

## Out of scope

- Detecting whether the active pane is running a shell.
- Falling back to prefix-based behavior.
- Reusing the existing tmux `bg` session/window-moving workflow bound on `Prefix + b`.
