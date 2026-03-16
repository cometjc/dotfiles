# dotfiles

## Setup

Run the full setup flow with:

```bash
./setup
```

The setup entrypoint discovers `setup.d/[0-9][0-9]-*` steps, validates them,
then runs them in order.

### Useful flags

```bash
./setup -f
./setup --dry-run
./setup --only 53-python-apps
./setup --from 50-mise
```

- `-f`, `--force`: force selected setup steps to rerun
- `--dry-run`: print selected steps without executing them
- `--only <step>`: run only the named setup step
- `--from <step>`: run the named step and all later steps

When `--dry-run`, `--only`, or `--from` is used, the final repo-specific
cleanup steps are skipped on purpose.

## Requirements

- Linux-focused environment
- network access for package managers and release downloads
- `sudo` access for system package / system file changes

Several setup steps also repair runtime directories under `~/.cache`,
`~/.local/share`, and `~/.npm` when prior root-owned leftovers would block
tool installation.

## Verification

Run the setup regression suite with:

```bash
./tests/run-setup-regression
```

This verifies key setup guarantees such as:

- existing directories can be merged before being replaced by symlinks
- release downloads use asset metadata instead of guessed URLs
- root-owned runtime caches are repaired before tool installation
- malformed uv tool environments are cleaned up automatically
- optional shell integrations fail closed instead of printing shell errors

## Troubleshooting

- `Setup step is not executable`: restore the executable bit on the step file
- `Setup step is missing a shebang`: add a shell shebang such as `#!/bin/bash`
- cache permission failures under `~/.cache/*` or `~/.npm`: rerun `./setup`
  and let the setup helpers repair ownership
- release download failures: rerun the affected step with `./setup --only <step>`
  after checking upstream release assets

## Backup settings before reinstall OS

- `/etc/auto.*`
- `/etc/resolvconf/resolv.conf.d/base`
