#!/usr/bin/env bash

# Test helper functions for TPM Redux tests

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

