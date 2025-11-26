#!/usr/bin/env bats

# Tests for lib/core.sh - Core TPM Redux functionality

load test_helper

setup() {
    setup_temp_dir
    export PROJECT_ROOT=$(get_project_root)

    # Source the core library
    source "$PROJECT_ROOT/lib/core.sh"
}

teardown() {
    teardown_temp_dir
}

# Test: get_tmux_config_path function

@test "get_tmux_config_path finds ~/.tmux.conf" {
    # Create mock config in home directory
    export HOME="$TPM_TEST_DIR/home"
    unset XDG_CONFIG_HOME

    mkdir -p "$HOME"
    touch "$HOME/.tmux.conf"

    run get_tmux_config_path
    [ "$status" -eq 0 ]
    [ "$output" = "$HOME/.tmux.conf" ]
}

@test "get_tmux_config_path prefers XDG config path" {

    export HOME="$TPM_TEST_DIR/home"
    export XDG_CONFIG_HOME="$TPM_TEST_DIR/xdg"

    mkdir -p "$HOME"
    mkdir -p "$XDG_CONFIG_HOME/tmux"

    touch "$HOME/.tmux.conf"
    touch "$XDG_CONFIG_HOME/tmux/tmux.conf"


    run get_tmux_config_path
    [ "$status" -eq 0 ]
    [ "$output" = "$XDG_CONFIG_HOME/tmux/tmux.conf" ]
}

@test "get_tmux_config_path handles missing config" {

    export HOME="$TPM_TEST_DIR/home"
    unset XDG_CONFIG_HOME
    mkdir -p "$HOME"


    run get_tmux_config_path
    [ "$status" -eq 0 ]
    [ "$output" = "$HOME/.tmux.conf" ]
}

# Test: parse_plugins function

@test "parse_plugins extracts single plugin" {

    local config="$TPM_TEST_DIR/tmux.conf"
    echo "set -g @plugin 'tmux-plugins/tmux-sensible'" > "$config"


    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "$output" = "tmux-plugins/tmux-sensible" ]
}

@test "parse_plugins extracts multiple plugins" {

    local config="$TPM_TEST_DIR/tmux.conf"
    cat > "$config" <<'EOF'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'tmux-plugins/tmux-resurrect'
EOF


    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "tmux-plugins/tmux-sensible" ]
    [ "${lines[1]}" = "tmux-plugins/tmux-yank" ]
    [ "${lines[2]}" = "tmux-plugins/tmux-resurrect" ]
}

@test "parse_plugins handles double quotes" {

    local config="$TPM_TEST_DIR/tmux.conf"
    echo 'set -g @plugin "tmux-plugins/tmux-sensible"' > "$config"


    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "$output" = "tmux-plugins/tmux-sensible" ]
}

@test "parse_plugins handles no quotes" {

    local config="$TPM_TEST_DIR/tmux.conf"
    echo "set -g @plugin tmux-plugins/tmux-sensible" > "$config"


    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "$output" = "tmux-plugins/tmux-sensible" ]
}

@test "parse_plugins ignores comments" {

    local config="$TPM_TEST_DIR/tmux.conf"
    cat > "$config" <<'EOF'
# This is a comment
set -g @plugin 'tmux-plugins/tmux-sensible'
# set -g @plugin 'tmux-plugins/commented-out'
set -g @plugin 'tmux-plugins/tmux-yank'
EOF


    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "tmux-plugins/tmux-sensible" ]
    [ "${lines[1]}" = "tmux-plugins/tmux-yank" ]
    [ "${#lines[@]}" -eq 2 ]
}

@test "parse_plugins handles set-option syntax" {

    local config="$TPM_TEST_DIR/tmux.conf"
    echo "set-option -g @plugin 'tmux-plugins/tmux-sensible'" > "$config"


    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "$output" = "tmux-plugins/tmux-sensible" ]
}

# Test: get_plugin_name function

@test "get_plugin_name extracts name from user/repo format" {


    run get_plugin_name "tmux-plugins/tmux-sensible"
    [ "$status" -eq 0 ]
    [ "$output" = "tmux-sensible" ]
}

@test "get_plugin_name extracts name from full git URL" {


    run get_plugin_name "https://github.com/tmux-plugins/tmux-sensible"
    [ "$status" -eq 0 ]
    [ "$output" = "tmux-sensible" ]
}

@test "get_plugin_name handles .git extension" {


    run get_plugin_name "https://github.com/tmux-plugins/tmux-sensible.git"
    [ "$status" -eq 0 ]
    [ "$output" = "tmux-sensible" ]
}

@test "get_plugin_name handles branch specification" {


    run get_plugin_name "tmux-plugins/tmux-sensible#develop"
    [ "$status" -eq 0 ]
    [ "$output" = "tmux-sensible" ]
}

# Test: get_plugin_branch function

@test "get_plugin_branch extracts branch from plugin spec" {


    run get_plugin_branch "tmux-plugins/tmux-sensible#develop"
    [ "$status" -eq 0 ]
    [ "$output" = "develop" ]
}

@test "get_plugin_branch returns empty for no branch" {


    run get_plugin_branch "tmux-plugins/tmux-sensible"
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

# Test: get_plugin_path function

@test "get_plugin_path constructs correct path" {

    export TMUX_PLUGIN_MANAGER_PATH="$TPM_TEST_DIR/plugins"


    run get_plugin_path "tmux-plugins/tmux-sensible"
    [ "$status" -eq 0 ]
    [ "$output" = "$TPM_TEST_DIR/plugins/tmux-sensible" ]
}

@test "get_plugin_path handles full URL" {

    export TMUX_PLUGIN_MANAGER_PATH="$TPM_TEST_DIR/plugins"


    run get_plugin_path "https://github.com/tmux-plugins/tmux-sensible.git"
    [ "$status" -eq 0 ]
    [ "$output" = "$TPM_TEST_DIR/plugins/tmux-sensible" ]
}

# Test: get_tpm_path function

@test "get_tpm_path uses TMUX_PLUGIN_MANAGER_PATH if set" {

    export TMUX_PLUGIN_MANAGER_PATH="$TPM_TEST_DIR/custom-plugins"


    run get_tpm_path
    [ "$status" -eq 0 ]
    [ "$output" = "$TPM_TEST_DIR/custom-plugins" ]
}

@test "get_tpm_path defaults to ~/.tmux/plugins/" {

    export HOME="$TPM_TEST_DIR/home"
    unset TMUX_PLUGIN_MANAGER_PATH
    unset XDG_CONFIG_HOME


    run get_tpm_path
    [ "$status" -eq 0 ]
    [ "$output" = "$HOME/.tmux/plugins/" ]
}

@test "get_tpm_path uses XDG path if config exists there" {

    export HOME="$TPM_TEST_DIR/home"
    export XDG_CONFIG_HOME="$TPM_TEST_DIR/xdg"
    unset TMUX_PLUGIN_MANAGER_PATH

    mkdir -p "$XDG_CONFIG_HOME/tmux"
    touch "$XDG_CONFIG_HOME/tmux/tmux.conf"


    run get_tpm_path
    [ "$status" -eq 0 ]
    [ "$output" = "$XDG_CONFIG_HOME/tmux/plugins/" ]
}

@test "get_tpm_path expands quoted tilde in env var (regression)" {
    # Simulate user exporting with single quotes:
    # export TMUX_PLUGIN_MANAGER_PATH='~/.tmux/plugins'
    # or set-environment -g TMUX_PLUGIN_MANAGER_PATH '~/.tmux/plugins'
    #
    # This ensures the script expands it to $HOME manually
    export TMUX_PLUGIN_MANAGER_PATH='~/.tmux/test-plugins'

    run get_tpm_path
    [ "$status" -eq 0 ]
    [ "$output" = "$HOME/.tmux/test-plugins" ]
}
