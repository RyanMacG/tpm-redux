#!/usr/bin/env bats

# Tests for bin/update - Plugin update command

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
    source "$PROJECT_ROOT/bin/update"
}

teardown() {
    teardown_temp_dir
}

# Test: update_plugin_with_feedback function

@test "update_plugin_with_feedback updates installed plugin" {
    # Create a mock git repository with remote
    local remote_repo="$TPM_TEST_DIR/remote-repo"
    local plugin_path="$TMUX_PLUGIN_MANAGER_PATH/tmux-sensible"

    # Set up remote repo
    mkdir -p "$remote_repo"
    cd "$remote_repo"
    git init --bare >/dev/null 2>&1

    # Set up local plugin repo
    mkdir -p "$plugin_path"
    cd "$plugin_path"
    git init >/dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"
    git config commit.gpgsign false
    git remote add origin "$remote_repo" >/dev/null 2>&1

    # Create initial commit
    echo "# Test" > README.md
    git add README.md >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    git push -u origin master >/dev/null 2>&1 || git push -u origin main >/dev/null 2>&1

    run update_plugin_with_feedback "tmux-plugins/tmux-sensible"
    # Status will be 0 or 1 (success or up-to-date)
    [ "$status" -le 1 ]
    [[ "$output" =~ "tmux-sensible" ]]
}

@test "update_plugin_with_feedback handles non-existent plugin" {
    run update_plugin_with_feedback "tmux-plugins/nonexistent"
    [ "$status" -eq 2 ]  # Return code 2 means not installed
    [[ "$output" =~ "not installed" || "$output" =~ "not found" ]]
}

@test "update_plugin_with_feedback handles plugin without git" {
    # Create a directory without git
    local plugin_path="$TMUX_PLUGIN_MANAGER_PATH/not-a-repo"
    mkdir -p "$plugin_path"

    run update_plugin_with_feedback "user/not-a-repo"
    [ "$status" -eq 2 ]  # Return code 2 means not installed (no git repo)
}

# Test: update_all_plugins function

@test "update_all_plugins processes multiple plugins" {
    # Create a config with multiple plugins
    local config="$TPM_TEST_DIR/tmux.conf"
    cat > "$config" <<'EOF'
set -g @plugin 'user/plugin1'
set -g @plugin 'user/plugin2'
EOF

    # Create mock repos with remotes
    local remote_repo="$TPM_TEST_DIR/remote"
    mkdir -p "$remote_repo"
    cd "$remote_repo"
    git init --bare >/dev/null 2>&1

    for plugin in plugin1 plugin2; do
        local plugin_path="$TMUX_PLUGIN_MANAGER_PATH/$plugin"
        mkdir -p "$plugin_path"
        cd "$plugin_path"
        git init >/dev/null 2>&1
        git config user.email "test@example.com"
        git config user.name "Test User"
        git config commit.gpgsign false
        git remote add origin "$remote_repo" >/dev/null 2>&1
        echo "test" > README.md
        git add README.md >/dev/null 2>&1
        git commit -m "Initial" >/dev/null 2>&1
        git push -u origin master >/dev/null 2>&1 || git push -u origin main >/dev/null 2>&1
    done

    run update_all_plugins "$config"
    [ "$status" -eq 0 ]
}

@test "update_all_plugins handles empty config" {
    local config="$TPM_TEST_DIR/empty.conf"
    touch "$config"

    run update_all_plugins "$config"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "No plugins" || "$output" =~ "0 plugin" ]]
}

# Test: format_update_output function

@test "format_update_output formats success message" {
    run format_update_output "tmux-sensible" "success"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "tmux-sensible" ]]
}

@test "format_update_output formats up-to-date message" {
    run format_update_output "tmux-sensible" "up_to_date"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "tmux-sensible" ]]
    [[ "$output" =~ "up" || "$output" =~ "date" ]]
}

@test "format_update_output formats not installed message" {
    run format_update_output "tmux-sensible" "not_installed"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "tmux-sensible" ]]
    [[ "$output" =~ "not installed" || "$output" =~ "not found" ]]
}

@test "format_update_output formats error message" {
    run format_update_output "tmux-sensible" "error"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "tmux-sensible" ]]
    [[ "$output" =~ "fail" || "$output" =~ "error" ]]
}

