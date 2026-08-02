#!/usr/bin/env bash

# Test helper functions for TPM Redux tests

# Give each test file its own private tmux server on a separate socket.
#
# Having access to a tmux server calling tmux commands such as source-file
# for parsing configuration.
# 
# Two things have to line up for bare `tmux` calls to hit the private server
# (and, crucially, for `kill-server` to tear down only it):
#   - TMUX_TMPDIR redirects tmux's default socket into a private directory; and
#   - TMUX is unset, otherwise it pins bare `tmux` at the *current* session's
#     server (the user's live one) and overrides TMUX_TMPDIR. Forgetting this
#     makes `teardown_file`'s kill-server destroy the user's tmux session.
# The server inherits this process's HOME and is killed in teardown_file.
setup_file() {
    # Redirect default tmux socket to private directory
    local tmpdir
    tmpdir="$(mktemp -d)"
    export TMUX_TMPDIR="$tmpdir"
    export TPM_TEST_TMPDIR="$tmpdir"

    # Unset TMUX to isolate from any existing tmux server
    unset TMUX
    tmux new-session -d -s tpm-parse-test 'sleep 86400' >/dev/null 2>&1 || true
}

teardown_file() {
    if [[ -n "${TMUX_TMPDIR:-}" ]]; then
        tmux kill-server >/dev/null 2>&1 || true
        unset TMUX_TMPDIR
    fi
    if [[ -n "${TPM_TEST_TMPDIR:-}" && -d "${TPM_TEST_TMPDIR:-}" ]]; then
        rm -rf "$TPM_TEST_TMPDIR" 2>/dev/null || true
    fi
}

# Get the project root directory
get_project_root() {
    cd "${BATS_TEST_DIRNAME}/.." && pwd
}

# Create a temporary test directory
setup_temp_dir() {
    export TPM_TEST_DIR="/tmp/tpm-redux-test-$$"
    mkdir -p "$TPM_TEST_DIR"
}

# Clean up temporary test directory
teardown_temp_dir() {
    if [[ -n "$TPM_TEST_DIR" ]] && [[ -d "$TPM_TEST_DIR" ]]; then
        rm -rf "$TPM_TEST_DIR"
    fi
}

# Point this file's tmux server at the current HOME.
#
# tmux expands a leading ~ in source-file paths against the server's HOME,
# which is fixed when the server starts in setup_file. Tests that override
# HOME to a temp dir must sync the server's HOME too for ~ to resolve there.
# No restore is needed: the server is owned and killed in teardown_file.
sync_server_home() {
    tmux set-environment -g HOME "$HOME" >/dev/null 2>&1 || true
}

# Create a mock tmux.conf file with plugins
create_mock_config() {
    local config_file="$1"
    shift
    local plugins=("$@")

    for plugin in "${plugins[@]}"; do
        echo "set -g @plugin '$plugin'" >> "$config_file"
    done
}

# Create a mock plugin directory structure
create_mock_plugin() {
    local plugin_dir="$1"
    local plugin_name="$2"

    mkdir -p "$plugin_dir/$plugin_name"

    # Create a simple .tmux file
    cat > "$plugin_dir/$plugin_name/${plugin_name}.tmux" <<'EOF'
#!/usr/bin/env bash
# Mock plugin file
exit 0
EOF
    chmod +x "$plugin_dir/$plugin_name/${plugin_name}.tmux"
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Assert that a file exists
assert_file_exists() {
    [[ -f "$1" ]] || {
        echo "Expected file to exist: $1" >&2
        return 1
    }
}

# Assert that a directory exists
assert_dir_exists() {
    [[ -d "$1" ]] || {
        echo "Expected directory to exist: $1" >&2
        return 1
    }
}

# Assert that a string contains a substring
assert_contains() {
    local haystack="$1"
    local needle="$2"

    [[ "$haystack" == *"$needle"* ]] || {
        echo "Expected '$haystack' to contain '$needle'" >&2
        return 1
    }
}

