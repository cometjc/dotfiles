#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sync_script="$repo_root/files/shared_codes/shared-envrc-sync"
direnv_rc="$repo_root/files/.bashrc.d/51-env-direnv"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_file_contains() {
    local file="$1"
    local expected="$2"
    local message="$3"
    grep -F "$expected" "$file" >/dev/null || fail "$message"
}

create_temp_repo() {
    local temp_root
    temp_root="$(mktemp -d)"
    git -C "$temp_root" init >/dev/null 2>&1
    touch "$temp_root/.envrc"
    printf '%s\n' "$temp_root"
}

test_sync_on_enter_auto_updates_when_only_shared_changes() {
    local temp_home temp_repo
    temp_home="$(mktemp -d)"
    temp_repo="$(create_temp_repo)"
    trap 'rm -rf "$temp_home" "$temp_repo"' RETURN

    mkdir -p "$temp_home/shared_codes"
    cat >"$temp_home/shared_codes/.envrc" <<'EOF'
export SHARED_VERSION=2
EOF
    cat >"$temp_repo/.envrc" <<'EOF'
export SHARED_VERSION=1
EOF
    mkdir -p "$temp_repo/.git/user-global-envrc"
    cat >"$temp_repo/.git/user-global-envrc/base.envrc" <<'EOF'
export SHARED_VERSION=1
EOF

    (
        cd "$temp_repo"
        HOME="$temp_home" "$sync_script" sync-on-enter >/tmp/shared-envrc-sync-auto.log 2>&1
    ) || {
        cat /tmp/shared-envrc-sync-auto.log >&2
        fail "sync-on-enter should succeed when only the shared version changed"
    }

    assert_file_contains "$temp_repo/.envrc" "export SHARED_VERSION=2" \
        "sync-on-enter should update .envrc to the latest shared version"
    assert_file_contains "$temp_repo/.git/user-global-envrc/base.envrc" "export SHARED_VERSION=2" \
        "sync-on-enter should advance the recorded base version after auto-update"
}

test_sync_on_enter_prints_message_when_repo_becomes_managed() {
    local temp_home temp_repo
    temp_home="$(mktemp -d)"
    temp_repo="$(create_temp_repo)"
    trap 'rm -rf "$temp_home" "$temp_repo"' RETURN

    mkdir -p "$temp_home/shared_codes"
    cat >"$temp_home/shared_codes/.envrc" <<'EOF'
export SHARED_VERSION=1
EOF
    cat >"$temp_repo/.envrc" <<'EOF'
export LOCAL_VERSION=1
EOF

    (
        cd "$temp_repo"
        HOME="$temp_home" "$sync_script" sync-on-enter >/tmp/shared-envrc-sync-manage.out 2>/tmp/shared-envrc-sync-manage.err
    ) || {
        cat /tmp/shared-envrc-sync-manage.err >&2
        fail "sync-on-enter should succeed when first managing a repo"
    }

    assert_file_contains /tmp/shared-envrc-sync-manage.err "shared-envrc-sync: now managing this repo" \
        "sync-on-enter should announce when a repo becomes managed for the first time"
    assert_file_contains "$temp_repo/.git/user-global-envrc/state" "managed=1" \
        "sync-on-enter should mark the repo as managed after first initialization"
}

test_sync_on_enter_prints_message_when_repo_is_already_managed() {
    local temp_home temp_repo
    temp_home="$(mktemp -d)"
    temp_repo="$(create_temp_repo)"
    trap 'rm -rf "$temp_home" "$temp_repo"' RETURN

    mkdir -p "$temp_home/shared_codes" "$temp_repo/.git/user-global-envrc"
    cat >"$temp_home/shared_codes/.envrc" <<'EOF'
export SHARED_VERSION=1
EOF
    cat >"$temp_repo/.envrc" <<'EOF'
export SHARED_VERSION=1
EOF
    cat >"$temp_repo/.git/user-global-envrc/base.envrc" <<'EOF'
export SHARED_VERSION=1
EOF
    cat >"$temp_repo/.git/user-global-envrc/state" <<'EOF'
skip_permanently=0
dirty=0
managed=1
EOF

    (
        cd "$temp_repo"
        HOME="$temp_home" "$sync_script" sync-on-enter >/tmp/shared-envrc-sync-managed.out 2>/tmp/shared-envrc-sync-managed.err
    ) || {
        cat /tmp/shared-envrc-sync-managed.err >&2
        fail "sync-on-enter should succeed when a managed repo needs no updates"
    }

    assert_file_contains /tmp/shared-envrc-sync-managed.err "shared-envrc-sync: already managed, no updates needed" \
        "sync-on-enter should announce the no-op case for an already managed repo"
}

test_sync_on_enter_can_suppress_noop_message() {
    local temp_home temp_repo
    temp_home="$(mktemp -d)"
    temp_repo="$(create_temp_repo)"
    trap 'rm -rf "$temp_home" "$temp_repo"' RETURN

    mkdir -p "$temp_home/shared_codes" "$temp_repo/.git/user-global-envrc"
    cat >"$temp_home/shared_codes/.envrc" <<'EOF'
export SHARED_VERSION=1
EOF
    cat >"$temp_repo/.envrc" <<'EOF'
export SHARED_VERSION=1
EOF
    cat >"$temp_repo/.git/user-global-envrc/base.envrc" <<'EOF'
export SHARED_VERSION=1
EOF
    cat >"$temp_repo/.git/user-global-envrc/state" <<'EOF'
skip_permanently=0
dirty=0
managed=1
EOF

    (
        cd "$temp_repo"
        HOME="$temp_home" SHARED_ENVRC_SYNC_QUIET_NOOP=1 \
            "$sync_script" sync-on-enter >/tmp/shared-envrc-sync-quiet.out 2>/tmp/shared-envrc-sync-quiet.err
    ) || {
        cat /tmp/shared-envrc-sync-quiet.err >&2
        fail "sync-on-enter should succeed when quiet no-op output is requested"
    }

    if [[ -s /tmp/shared-envrc-sync-quiet.err ]]; then
        cat /tmp/shared-envrc-sync-quiet.err >&2
        fail "sync-on-enter should suppress the no-op message when SHARED_ENVRC_SYNC_QUIET_NOOP=1"
    fi
}

test_sync_on_enter_skips_forever_when_repo_is_remembered() {
    local temp_home temp_repo
    temp_home="$(mktemp -d)"
    temp_repo="$(create_temp_repo)"
    trap 'rm -rf "$temp_home" "$temp_repo"' RETURN

    mkdir -p "$temp_home/shared_codes"
    cat >"$temp_home/shared_codes/.envrc" <<'EOF'
export SHARED_VERSION=2
EOF
    cat >"$temp_repo/.envrc" <<'EOF'
export SHARED_VERSION=1
EOF
    mkdir -p "$temp_repo/.git/user-global-envrc"
    cat >"$temp_repo/.git/user-global-envrc/base.envrc" <<'EOF'
export SHARED_VERSION=1
EOF
    cat >"$temp_repo/.git/user-global-envrc/state" <<'EOF'
skip_permanently=1
EOF

    (
        cd "$temp_repo"
        HOME="$temp_home" "$sync_script" sync-on-enter >/tmp/shared-envrc-sync-skip.log 2>&1
    ) || {
        cat /tmp/shared-envrc-sync-skip.log >&2
        fail "sync-on-enter should succeed when the repo is permanently skipped"
    }

    assert_file_contains "$temp_repo/.envrc" "export SHARED_VERSION=1" \
        "sync-on-enter should leave .envrc untouched for permanently skipped repos"
}

test_sync_on_enter_overwrites_local_after_conflict_choice() {
    local temp_home temp_repo
    temp_home="$(mktemp -d)"
    temp_repo="$(create_temp_repo)"
    trap 'rm -rf "$temp_home" "$temp_repo"' RETURN

    mkdir -p "$temp_home/shared_codes"
    cat >"$temp_home/shared_codes/.envrc" <<'EOF'
export SHARED_LINE=shared
EOF
    cat >"$temp_repo/.envrc" <<'EOF'
export SHARED_LINE=local
EOF
    mkdir -p "$temp_repo/.git/user-global-envrc"
    cat >"$temp_repo/.git/user-global-envrc/base.envrc" <<'EOF'
export SHARED_LINE=base
EOF

    (
        cd "$temp_repo"
        HOME="$temp_home" SHARED_ENVRC_CHOICE=overwrite-local "$sync_script" sync-on-enter >/tmp/shared-envrc-sync-overwrite.log 2>&1
    ) || {
        cat /tmp/shared-envrc-sync-overwrite.log >&2
        fail "sync-on-enter should accept overwrite-local in conflict mode"
    }

    assert_file_contains "$temp_repo/.envrc" "export SHARED_LINE=shared" \
        "overwrite-local should replace the repo .envrc with the shared version"
    assert_file_contains "$temp_repo/.git/user-global-envrc/base.envrc" "export SHARED_LINE=shared" \
        "overwrite-local should advance the recorded base version"
}

test_ensure_hooks_wraps_existing_hook_and_chains_shared_sync() {
    local temp_home temp_repo
    temp_home="$(mktemp -d)"
    temp_repo="$(create_temp_repo)"
    trap 'rm -rf "$temp_home" "$temp_repo"' RETURN

    mkdir -p "$temp_home/shared_codes"
    cat >"$temp_home/shared_codes/.envrc" <<'EOF'
export SHARED_VERSION=1
EOF
    mkdir -p "$temp_repo/.git/hooks"
    cat >"$temp_repo/.git/hooks/post-checkout" <<'EOF'
#!/bin/sh
echo legacy-post-checkout >>"$HOOK_LOG"
EOF
    chmod +x "$temp_repo/.git/hooks/post-checkout"

    (
        cd "$temp_repo"
        HOME="$temp_home" "$sync_script" ensure-hooks >/tmp/shared-envrc-hooks.log 2>&1
    ) || {
        cat /tmp/shared-envrc-hooks.log >&2
        fail "ensure-hooks should succeed for repos with an existing post-checkout hook"
    }

    [[ -x "$temp_repo/.git/hooks/post-checkout" ]] || fail "ensure-hooks should install a dispatcher post-checkout hook"
    [[ -x "$temp_repo/.git/hooks/post-checkout.d/10-legacy" ]] || fail "ensure-hooks should preserve the original hook as a chained legacy script"
    [[ -x "$temp_repo/.git/hooks/post-checkout.d/50-shared-envrc" ]] || fail "ensure-hooks should install the shared-envrc hook runner"

    local hook_log="$temp_repo/hook.log"
    (
        cd "$temp_repo"
        HOME="$temp_home" SHARED_ENVRC_SYNC_SCRIPT="$sync_script" HOOK_LOG="$hook_log" \
            .git/hooks/post-checkout old new 1 >/tmp/shared-envrc-hooks-run.log 2>&1
    ) || {
        cat /tmp/shared-envrc-hooks-run.log >&2
        fail "dispatcher post-checkout hook should run successfully"
    }

    assert_file_contains "$hook_log" "legacy-post-checkout" \
        "dispatcher post-checkout hook should continue to invoke the original hook"
    assert_file_contains "$temp_repo/.git/user-global-envrc/state" "dirty=1" \
        "shared-envrc hook runner should mark the repo dirty after git events"
}

test_install-templates_creates_dispatcher_hooks() {
    local temp_home
    temp_home="$(mktemp -d)"
    trap 'rm -rf "$temp_home"' RETURN

    HOME="$temp_home" "$sync_script" install-templates >/tmp/shared-envrc-templates.log 2>&1 \
        || {
            cat /tmp/shared-envrc-templates.log >&2
            fail "install-templates should succeed"
        }

    [[ -x "$temp_home/.git-templates/hooks/post-checkout" ]] || fail "install-templates should provision a post-checkout dispatcher"
    [[ -x "$temp_home/.git-templates/hooks/post-merge" ]] || fail "install-templates should provision a post-merge dispatcher"
    [[ -x "$temp_home/.git-templates/hooks/post-rewrite" ]] || fail "install-templates should provision a post-rewrite dispatcher"
}

test_init_repo_installs_shared_envrc_templates() {
    local temp_home temp_repo
    temp_home="$(mktemp -d)"
    temp_repo="$(mktemp -d)"
    trap 'rm -rf "$temp_home" "$temp_repo"' RETURN

    cp "$repo_root/init-repo" "$temp_repo/init-repo"
    : >"$temp_repo/.gitattributes"
    mkdir -p "$temp_home/shared_codes"
    cp "$sync_script" "$temp_home/shared_codes/shared-envrc-sync"
    chmod +x "$temp_home/shared_codes/shared-envrc-sync"

    (
        cd "$temp_repo"
        HOME="$temp_home" ./init-repo >/tmp/shared-envrc-init-repo.log 2>&1
    ) || {
        cat /tmp/shared-envrc-init-repo.log >&2
        fail "init-repo should succeed while provisioning shared envrc templates"
    }

    [[ -x "$temp_home/.git-templates/hooks/post-checkout" ]] || fail "init-repo should install the shared envrc post-checkout template"
}

test_chpwd_sync_hook_suppresses_sync_output() {
    local temp_home temp_repo output
    temp_home="$(mktemp -d)"
    temp_repo="$(mktemp -d)"
    trap 'rm -rf "$temp_home" "$temp_repo"' RETURN

    mkdir -p "$temp_home/shared_codes" "$temp_repo"
    cat >"$temp_home/shared_codes/shared-envrc-sync" <<'EOF'
#!/bin/bash
echo "stdout from sync"
echo "stderr from sync" >&2
exit 0
EOF
    chmod +x "$temp_home/shared_codes/shared-envrc-sync"

    output="$(
        HOME="$temp_home" bash -lc '
            source "'"$repo_root"'/files/.bashrc.d/02-functions"
            source "'"$repo_root"'/files/.bashrc.d/10-init-zsh-cd-hooks"
            source "'"$direnv_rc"'"
            _shared_envrc_sync_on_chpwd
        ' 2>&1
    )"

    if [[ -n "$output" ]]; then
        printf '%s\n' "$output" >&2
        fail "the chpwd shared envrc hook should suppress sync command output"
    fi
}

test_sync_on_enter_auto_updates_when_only_shared_changes
test_sync_on_enter_prints_message_when_repo_becomes_managed
test_sync_on_enter_prints_message_when_repo_is_already_managed
test_sync_on_enter_can_suppress_noop_message
test_sync_on_enter_skips_forever_when_repo_is_remembered
test_sync_on_enter_overwrites_local_after_conflict_choice
test_ensure_hooks_wraps_existing_hook_and_chains_shared_sync
test_install-templates_creates_dispatcher_hooks
test_init_repo_installs_shared_envrc_templates
test_chpwd_sync_hook_suppresses_sync_output

echo "All shared envrc sync regression tests passed"
