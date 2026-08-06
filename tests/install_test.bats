#!/usr/bin/env bats

# Tests for bin/install - Plugin installation command

load test_helper

setup_file() {
    setup_tmux_server
}

teardown_file() {
    teardown_tmux_server
}

setup() {
    setup_temp_dir
    export PROJECT_ROOT=$(get_project_root)
    export TMUX_PLUGIN_MANAGER_PATH="$TPM_TEST_DIR/plugins"
    export TPM_TEST_MODE=1
    mkdir -p "$TMUX_PLUGIN_MANAGER_PATH"

    # Source libraries
    source "$PROJECT_ROOT/lib/core.sh"
    source "$PROJECT_ROOT/lib/git.sh"
    source "$PROJECT_ROOT/bin/install"
}

teardown() {
    teardown_temp_dir
}

# Test: install_plugin_with_feedback function

@test "install_plugin_with_feedback installs new plugin" {
    skip "Requires network access for real git clone"
    # This would be an integration test
}

@test "install_plugin_with_feedback skips already installed plugin" {
    # Create a mock installed plugin
    local plugin_path="$TMUX_PLUGIN_MANAGER_PATH/tmux-sensible"
    mkdir -p "$plugin_path"
    cd "$plugin_path"
    git init >/dev/null 2>&1
    git config commit.gpgsign false
    git remote add origin "https://github.com/tmux-plugins/tmux-sensible" >/dev/null 2>&1

    run install_plugin_with_feedback "tmux-plugins/tmux-sensible"
    [ "$status" -eq 1 ]  # Return code 1 means already installed
    # Should output that it's already installed
    [[ "$output" =~ "Already installed" ]] || [[ "$output" =~ "already" ]]
}

@test "install_plugin_with_feedback handles branch specification" {
    local plugin="user/repo#develop"
    local branch

    branch=$(get_plugin_branch "$plugin")
    [ "$branch" = "develop" ]
}

# Test: install_all_plugins function

@test "install_all_plugins processes multiple plugins" {
    # Create a config with multiple plugins
    local config="$TPM_TEST_DIR/tmux.conf"
    cat > "$config" <<'EOF'
set -g @plugin 'user/plugin1'
set -g @plugin 'user/plugin2'
EOF

    # Mock the plugins as already installed to avoid network
    for plugin in plugin1 plugin2; do
        local plugin_path="$TMUX_PLUGIN_MANAGER_PATH/$plugin"
        mkdir -p "$plugin_path"
        cd "$plugin_path"
        git init >/dev/null 2>&1
        git config commit.gpgsign false
        git remote add origin "https://github.com/user/$plugin" >/dev/null 2>&1
    done

    run install_all_plugins "$config"
    [ "$status" -eq 0 ]
}

@test "install_all_plugins handles empty config" {
    local config="$TPM_TEST_DIR/empty.conf"
    touch "$config"

    run install_all_plugins "$config"
    [ "$status" -eq 0 ]
}

# Test: format_plugin_output function

@test "format_plugin_output formats success message" {
    run format_plugin_output "tmux-sensible" "success"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "tmux-sensible" ]]
}

@test "format_plugin_output formats already installed message" {
    run format_plugin_output "tmux-sensible" "already_installed"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "tmux-sensible" ]]
    [[ "$output" =~ "installed" || "$output" =~ "already" ]]
}

@test "format_plugin_output formats error message" {
    run format_plugin_output "tmux-sensible" "error"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "tmux-sensible" ]]
    [[ "$output" =~ "fail" || "$output" =~ "error" ]]
}

# Test: count_plugins function

@test "count_plugins counts plugins in config" {
    local config="$TPM_TEST_DIR/tmux.conf"
    cat > "$config" <<'EOF'
set -g @plugin 'user/plugin1'
set -g @plugin 'user/plugin2'
set -g @plugin 'user/plugin3'
EOF

    run count_plugins "$config"
    [ "$status" -eq 0 ]
    [ "$output" = "3" ]
}

@test "count_plugins returns zero for empty config" {
    local config="$TPM_TEST_DIR/empty.conf"
    touch "$config"

    run count_plugins "$config"
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

# Parallel plugin operations (TPM_PARALLEL)

@test "install_all_plugins with TPM_PARALLEL=0 outputs plugin status in config order" {
    local config="$TPM_TEST_DIR/tmux.conf"
    cat > "$config" <<'EOF'
set -g @plugin 'user/plugin-a'
set -g @plugin 'user/plugin-b'
set -g @plugin 'user/plugin-c'
EOF

    # Mock all three as already installed
    for name in plugin-a plugin-b plugin-c; do
        local plugin_path="$TMUX_PLUGIN_MANAGER_PATH/$name"
        mkdir -p "$plugin_path"
        (cd "$plugin_path" && git init >/dev/null 2>&1 && git config commit.gpgsign false && git remote add origin "https://github.com/user/$name" >/dev/null 2>&1)
    done

    TPM_PARALLEL=0 run install_all_plugins "$config"
    [ "$status" -eq 0 ]
    # First plugin status line should be for plugin-a, then plugin-b, then plugin-c
    local lines
    lines=$(echo "$output" | grep -E "^(✓|→|✗)" || true)
    [[ "$lines" =~ plugin-a ]]
    [[ "$lines" =~ plugin-b ]]
    [[ "$lines" =~ plugin-c ]]
    # Order: plugin-a must appear before plugin-b, plugin-b before plugin-c
    local first_a first_b first_c
    first_a=$(echo "$output" | grep -n "plugin-a" | head -1 | cut -d: -f1)
    first_b=$(echo "$output" | grep -n "plugin-b" | head -1 | cut -d: -f1)
    first_c=$(echo "$output" | grep -n "plugin-c" | head -1 | cut -d: -f1)
    [ "$first_a" -lt "$first_b" ]
    [ "$first_b" -lt "$first_c" ]
}

@test "install_all_plugins with TPM_PARALLEL=1 and multiple plugins produces correct summary" {
    local config="$TPM_TEST_DIR/tmux.conf"
    cat > "$config" <<'EOF'
set -g @plugin 'user/plugin1'
set -g @plugin 'user/plugin2'
set -g @plugin 'user/plugin3'
EOF

    for name in plugin1 plugin2 plugin3; do
        local plugin_path="$TMUX_PLUGIN_MANAGER_PATH/$name"
        mkdir -p "$plugin_path"
        (cd "$plugin_path" && git init >/dev/null 2>&1 && git config commit.gpgsign false && git remote add origin "https://github.com/user/$name" >/dev/null 2>&1)
    done

    TPM_PARALLEL=1 run install_all_plugins "$config"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Already installed: 3" ]]
    [[ "$output" =~ "Installed: 0" ]]
    [[ "$output" =~ plugin1 ]] && [[ "$output" =~ plugin2 ]] && [[ "$output" =~ plugin3 ]]
}

@test "install_all_plugins with single plugin ignores TPM_PARALLEL" {
    local config="$TPM_TEST_DIR/tmux.conf"
    echo "set -g @plugin 'user/only'" > "$config"
    local plugin_path="$TMUX_PLUGIN_MANAGER_PATH/only"
    mkdir -p "$plugin_path"
    (cd "$plugin_path" && git init >/dev/null 2>&1 && git config commit.gpgsign false && git remote add origin "https://github.com/user/only" >/dev/null 2>&1)

    TPM_PARALLEL=1 run install_all_plugins "$config"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Already installed: 1" ]]
    [[ "$output" =~ "only" ]]
}

