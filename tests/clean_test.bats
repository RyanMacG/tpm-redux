#!/usr/bin/env bats

# Tests for bin/clean - Plugin cleanup command

load test_helper

setup() {
    setup_temp_dir
    export PROJECT_ROOT=$(get_project_root)
    export TMUX_PLUGIN_MANAGER_PATH="$TPM_TEST_DIR/plugins"
    export TPM_TEST_MODE=1
    mkdir -p "$TMUX_PLUGIN_MANAGER_PATH"

    # Source libraries
    source "$PROJECT_ROOT/lib/core.sh"
    source "$PROJECT_ROOT/lib/git.sh"
    source "$PROJECT_ROOT/bin/clean"
}

teardown() {
    teardown_temp_dir
}

# Test: get_installed_plugins function

@test "get_installed_plugins lists all plugin directories" {
    # Create some mock plugin directories
    mkdir -p "$TMUX_PLUGIN_MANAGER_PATH/plugin1"
    mkdir -p "$TMUX_PLUGIN_MANAGER_PATH/plugin2"
    mkdir -p "$TMUX_PLUGIN_MANAGER_PATH/plugin3"

    run get_installed_plugins
    [ "$status" -eq 0 ]
    [[ "$output" =~ "plugin1" ]]
    [[ "$output" =~ "plugin2" ]]
    [[ "$output" =~ "plugin3" ]]
}

@test "get_installed_plugins returns empty for no plugins" {
    run get_installed_plugins
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# Test: get_plugins_to_remove function

@test "get_plugins_to_remove identifies unused plugins" {
    # Create config with only plugin1
    local config="$TPM_TEST_DIR/tmux.conf"
    echo "set -g @plugin 'user/plugin1'" > "$config"

    # Create installed plugins
    mkdir -p "$TMUX_PLUGIN_MANAGER_PATH/plugin1"
    mkdir -p "$TMUX_PLUGIN_MANAGER_PATH/plugin2"
    mkdir -p "$TMUX_PLUGIN_MANAGER_PATH/plugin3"

    run get_plugins_to_remove "$config"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "plugin2" ]]
    [[ "$output" =~ "plugin3" ]]
    [[ ! "$output" =~ "plugin1" ]]
}

@test "get_plugins_to_remove returns empty when all are used" {
    local config="$TPM_TEST_DIR/tmux.conf"
    cat > "$config" <<'EOF'
set -g @plugin 'user/plugin1'
set -g @plugin 'user/plugin2'
EOF

    mkdir -p "$TMUX_PLUGIN_MANAGER_PATH/plugin1"
    mkdir -p "$TMUX_PLUGIN_MANAGER_PATH/plugin2"

    run get_plugins_to_remove "$config"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "get_plugins_to_remove handles tpm-redux itself" {
    local config="$TPM_TEST_DIR/tmux.conf"
    touch "$config"

    mkdir -p "$TMUX_PLUGIN_MANAGER_PATH/tpm-redux"
    mkdir -p "$TMUX_PLUGIN_MANAGER_PATH/unused-plugin"

    run get_plugins_to_remove "$config"
    [ "$status" -eq 0 ]
    # Should not suggest removing tpm-redux
    [[ ! "$output" =~ "tpm-redux" ]]
    [[ "$output" =~ "unused-plugin" ]]
}

# Test: remove_plugin function

@test "remove_plugin removes plugin directory" {
    local plugin_dir="$TMUX_PLUGIN_MANAGER_PATH/test-plugin"
    mkdir -p "$plugin_dir"
    echo "test" > "$plugin_dir/file.txt"

    run remove_plugin "test-plugin"
    [ "$status" -eq 0 ]
    [ ! -d "$plugin_dir" ]
}

@test "remove_plugin handles non-existent plugin" {
    run remove_plugin "nonexistent"
    [ "$status" -eq 1 ]
}

# Test: clean_plugins function

@test "clean_plugins removes unused plugins" {
    local config="$TPM_TEST_DIR/tmux.conf"
    echo "set -g @plugin 'user/plugin1'" > "$config"

    mkdir -p "$TMUX_PLUGIN_MANAGER_PATH/plugin1"
    mkdir -p "$TMUX_PLUGIN_MANAGER_PATH/plugin2"
    mkdir -p "$TMUX_PLUGIN_MANAGER_PATH/plugin3"

    run clean_plugins "$config"
    [ "$status" -eq 0 ]

    # plugin1 should still exist
    [ -d "$TMUX_PLUGIN_MANAGER_PATH/plugin1" ]

    # plugin2 and plugin3 should be removed
    [ ! -d "$TMUX_PLUGIN_MANAGER_PATH/plugin2" ]
    [ ! -d "$TMUX_PLUGIN_MANAGER_PATH/plugin3" ]
}

@test "clean_plugins handles no unused plugins" {
    local config="$TPM_TEST_DIR/tmux.conf"
    echo "set -g @plugin 'user/plugin1'" > "$config"

    mkdir -p "$TMUX_PLUGIN_MANAGER_PATH/plugin1"

    run clean_plugins "$config"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "No unused" || "$output" =~ "0 plugin" ]]
}

@test "clean_plugins handles empty plugin directory" {
    local config="$TPM_TEST_DIR/tmux.conf"
    echo "set -g @plugin 'user/plugin1'" > "$config"

    run clean_plugins "$config"
    [ "$status" -eq 0 ]
}

# Test: format_clean_output function

@test "format_clean_output formats success message" {
    run format_clean_output "test-plugin" "success"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "test-plugin" ]]
}

@test "format_clean_output formats error message" {
    run format_clean_output "test-plugin" "error"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "test-plugin" ]]
    [[ "$output" =~ "fail" || "$output" =~ "error" ]]
}

