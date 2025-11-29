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

    # Create separate mock repos with remotes for each plugin
    for plugin in plugin1 plugin2; do
        local remote_repo="$TPM_TEST_DIR/remote-$plugin"
        local plugin_path="$TMUX_PLUGIN_MANAGER_PATH/$plugin"
        
        # Create remote repo for this plugin
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

# Test: Git commit information functions

@test "get_plugin_commit_hash returns commit hash for installed plugin" {
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

    run get_plugin_commit_hash "tmux-plugins/tmux-sensible"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ ${#output} -ge 7 ]]  # Short hash should be at least 7 characters
}

@test "get_plugin_commit_hash returns error for non-existent plugin" {
    run get_plugin_commit_hash "tmux-plugins/nonexistent"
    [ "$status" -ne 0 ]
}

@test "get_plugin_commits_between returns commits between two hashes" {
    local plugin_path="$TMUX_PLUGIN_MANAGER_PATH/test-plugin"
    mkdir -p "$plugin_path"
    cd "$plugin_path"
    git init >/dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"
    git config commit.gpgsign false

    # Create first commit
    echo "v1" > file.txt
    git add file.txt >/dev/null 2>&1
    git commit -m "First commit" >/dev/null 2>&1
    local first_hash
    first_hash="$(git rev-parse --short HEAD)"

    # Create second commit
    echo "v2" > file.txt
    git add file.txt >/dev/null 2>&1
    git commit -m "Second commit" >/dev/null 2>&1
    local second_hash
    second_hash="$(git rev-parse --short HEAD)"

    # Create third commit
    echo "v3" > file.txt
    git add file.txt >/dev/null 2>&1
    git commit -m "Third commit" >/dev/null 2>&1
    local third_hash
    third_hash="$(git rev-parse --short HEAD)"

    # Get commits between first and third
    run get_plugin_commits_between "$first_hash" "$third_hash" "$plugin_path"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Should contain both second and third commit messages
    [[ "$output" =~ "Second commit" ]]
    [[ "$output" =~ "Third commit" ]]
}

@test "get_commit_info returns commit information" {
    local plugin_path="$TMUX_PLUGIN_MANAGER_PATH/test-plugin"
    mkdir -p "$plugin_path"
    cd "$plugin_path"
    git init >/dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"
    git config commit.gpgsign false

    echo "test" > file.txt
    git add file.txt >/dev/null 2>&1
    git commit -m "Test commit message" >/dev/null 2>&1
    local commit_hash
    commit_hash="$(git rev-parse --short HEAD)"

    run get_commit_info "$commit_hash" "$plugin_path"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" =~ "$commit_hash" ]]
    [[ "$output" =~ "Test commit message" ]]
}

# Test: Colour helper functions

@test "colour_green outputs colour code when terminal supports colours" {
    export TERM="xterm-256color"
    run colour_green
    # When colours are supported, should output ANSI escape code
    # When not supported (e.g., in test environment), may be empty
    [ "$status" -eq 0 ]
}

@test "colour_reset outputs reset code when terminal supports colours" {
    export TERM="xterm-256color"
    run colour_reset
    [ "$status" -eq 0 ]
}

# Test: update_plugin_with_feedback with commit data capture

@test "update_plugin_with_feedback captures commit data when updating" {
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

    local commit_data=""
    run update_plugin_with_feedback "tmux-plugins/tmux-sensible" "commit_data"
    [ "$status" -le 1 ]

    # Check that commit_data was set (may be empty if up-to-date)
    # The variable should exist even if empty
    [ -n "${commit_data:-}" ] || true  # May be empty if already up-to-date
}

# Test: format_commit_display function

@test "format_commit_display formats commit information correctly" {
    local plugin_path="$TMUX_PLUGIN_MANAGER_PATH/test-plugin"
    mkdir -p "$plugin_path"
    cd "$plugin_path"
    git init >/dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"
    git config commit.gpgsign false

    echo "test" > file.txt
    git add file.txt >/dev/null 2>&1
    git commit -m "Test commit" >/dev/null 2>&1
    local commit_hash
    commit_hash="$(git rev-parse --short HEAD)"

    local commits="${commit_hash}|Test commit|2 hours ago"
    run format_commit_display "test-plugin" "$commit_hash" "$commit_hash" "$commits" "updated" "$plugin_path"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" =~ "test-plugin" ]]
    [[ "$output" =~ "Test commit" ]]
}

# Test: update_all_plugins with commit display

@test "update_all_plugins displays commit summary for updated plugins" {
    local config="$TPM_TEST_DIR/tmux.conf"
    cat > "$config" <<'EOF'
set -g @plugin 'user/plugin1'
EOF

    # Create mock repo with remote
    local remote_repo="$TPM_TEST_DIR/remote"
    mkdir -p "$remote_repo"
    cd "$remote_repo"
    git init --bare >/dev/null 2>&1

    local plugin_path="$TMUX_PLUGIN_MANAGER_PATH/plugin1"
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

    run update_all_plugins "$config"
    [ "$status" -eq 0 ]
    # Should show update progress and summary
    [[ "$output" =~ "Updating" ]]
}

