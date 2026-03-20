#!/usr/bin/env bats

# Tests for lock file support

load test_helper

setup() {
    setup_temp_dir
    export PROJECT_ROOT=$(get_project_root)
    export TMUX_PLUGIN_MANAGER_PATH="$TPM_TEST_DIR/plugins"
    export TPM_TEST_MODE=1
    mkdir -p "$TMUX_PLUGIN_MANAGER_PATH"

    source "$PROJECT_ROOT/lib/core.sh"
    source "$PROJECT_ROOT/lib/git.sh"
    source "$PROJECT_ROOT/bin/install"
    source "$PROJECT_ROOT/bin/lock"
}

teardown() {
    teardown_temp_dir
}

# Helper: create a minimal git repo with one commit
_make_git_repo() {
    local dir="$1"
    mkdir -p "$dir"
    (
        cd "$dir"
        git init -q
        git config commit.gpgsign false
        git config user.email "test@test.com"
        git config user.name "Test"
        touch README
        git add README
        git commit -q -m "init"
    )
}

@test "generates lock file at correct path" {
    local config="$TPM_TEST_DIR/tmux.conf"
    echo "set -g @plugin 'user/myplugin'" > "$config"
    _make_git_repo "$TMUX_PLUGIN_MANAGER_PATH/myplugin"

    generate_lock_file "$config"

    local expected_lock
    expected_lock="$(dirname "${TMUX_PLUGIN_MANAGER_PATH%/}")/tpm.lock"
    [ -f "$expected_lock" ]
}

@test "lock file contains plugin spec and full commit hash" {
    local config="$TPM_TEST_DIR/tmux.conf"
    echo "set -g @plugin 'user/myplugin'" > "$config"
    _make_git_repo "$TMUX_PLUGIN_MANAGER_PATH/myplugin"

    local expected_hash
    expected_hash="$(cd "$TMUX_PLUGIN_MANAGER_PATH/myplugin" && git rev-parse HEAD)"

    generate_lock_file "$config"

    local lock_file
    lock_file="$(dirname "${TMUX_PLUGIN_MANAGER_PATH%/}")/tpm.lock"

    # Lock file must contain "user/myplugin <full-40-char-hash>"
    grep -q "^user/myplugin $expected_hash$" "$lock_file"
}

@test "lock file skips plugins not installed" {
    local config="$TPM_TEST_DIR/tmux.conf"
    cat > "$config" <<'EOF'
set -g @plugin 'user/installed'
set -g @plugin 'user/missing'
EOF
    _make_git_repo "$TMUX_PLUGIN_MANAGER_PATH/installed"

    generate_lock_file "$config"

    local lock_file
    lock_file="$(dirname "${TMUX_PLUGIN_MANAGER_PATH%/}")/tpm.lock"

    grep -q "user/installed" "$lock_file"
    ! grep -q "user/missing" "$lock_file"
}

@test "install uses pinned hash from lock file" {
    local config="$TPM_TEST_DIR/tmux.conf"
    echo "set -g @plugin 'user/myplugin'" > "$config"

    # Write a lock file with a fake 40-char hash
    local fake_hash="aabbccddeeff00112233445566778899aabbccdd"
    local lock_file
    lock_file="$(dirname "${TMUX_PLUGIN_MANAGER_PATH%/}")/tpm.lock"
    {
        echo "# tpm.lock"
        echo "user/myplugin $fake_hash"
    } > "$lock_file"

    # Track what branch arg clone_plugin receives
    local captured_branch_file="$TPM_TEST_DIR/captured_branch"

    # Override clone_plugin to capture its branch arg without actually cloning
    clone_plugin() {
        echo "$2" > "$captured_branch_file"
        return 0
    }

    install_plugin_with_feedback "user/myplugin"

    [ -f "$captured_branch_file" ]
    local captured_branch
    captured_branch="$(cat "$captured_branch_file")"
    [ "$captured_branch" = "$fake_hash" ]
}

@test "install without lock file works normally" {
    # No lock file present — install should proceed without error
    local config="$TPM_TEST_DIR/tmux.conf"
    echo "set -g @plugin 'user/myplugin'" > "$config"

    # Confirm no lock file exists
    local lock_file
    lock_file="$(dirname "${TMUX_PLUGIN_MANAGER_PATH%/}")/tpm.lock"
    [ ! -f "$lock_file" ]

    # Override clone_plugin to succeed without network
    clone_plugin() { return 0; }

    run install_plugin_with_feedback "user/myplugin"
    [ "$status" -eq 0 ]
}

@test "lock file path uses XDG dir when appropriate" {
    local xdg_dir="$TPM_TEST_DIR/xdg"
    mkdir -p "$xdg_dir/tmux"
    touch "$xdg_dir/tmux/tmux.conf"

    export XDG_CONFIG_HOME="$xdg_dir"
    # TMUX_PLUGIN_MANAGER_PATH points to XDG plugins dir
    export TMUX_PLUGIN_MANAGER_PATH="$xdg_dir/tmux/plugins"
    mkdir -p "$TMUX_PLUGIN_MANAGER_PATH"

    # Re-source core.sh so get_tpm_path picks up the new env
    source "$PROJECT_ROOT/lib/core.sh"

    local lock_path
    lock_path="$(get_lock_file_path)"
    [ "$lock_path" = "$xdg_dir/tmux/tpm.lock" ]
}
