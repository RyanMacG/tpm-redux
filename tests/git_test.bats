#!/usr/bin/env bats

# Tests for lib/git.sh - Git operations for plugin management

load test_helper

setup() {
    setup_temp_dir
    export PROJECT_ROOT=$(get_project_root)

    # Source both core and git libraries
    source "$PROJECT_ROOT/lib/core.sh"
    source "$PROJECT_ROOT/lib/git.sh"

    # Set up test plugin path
    export TMUX_PLUGIN_MANAGER_PATH="$TPM_TEST_DIR/plugins"
    mkdir -p "$TMUX_PLUGIN_MANAGER_PATH"
}

teardown() {
    teardown_temp_dir
}

# Test: expand_plugin_url function

@test "expand_plugin_url handles GitHub shorthand" {
    run expand_plugin_url "tmux-plugins/tmux-sensible"
    [ "$status" -eq 0 ]
    [ "$output" = "https://github.com/tmux-plugins/tmux-sensible" ]
}

@test "expand_plugin_url passes through full HTTPS URL" {
    run expand_plugin_url "https://github.com/user/repo.git"
    [ "$status" -eq 0 ]
    [ "$output" = "https://github.com/user/repo.git" ]
}

@test "expand_plugin_url passes through SSH URL" {
    run expand_plugin_url "git@github.com:user/repo.git"
    [ "$status" -eq 0 ]
    [ "$output" = "git@github.com:user/repo.git" ]
}

@test "expand_plugin_url handles GitHub shorthand with branch" {
    run expand_plugin_url "tmux-plugins/tmux-sensible#develop"
    [ "$status" -eq 0 ]
    [ "$output" = "https://github.com/tmux-plugins/tmux-sensible" ]
}

# Test: plugin_already_installed function

@test "plugin_already_installed returns false for non-existent plugin" {
    run plugin_already_installed "tmux-plugins/tmux-sensible"
    [ "$status" -eq 1 ]
}

@test "plugin_already_installed returns false for directory without git" {
    mkdir -p "$TMUX_PLUGIN_MANAGER_PATH/tmux-sensible"
    run plugin_already_installed "tmux-plugins/tmux-sensible"
    [ "$status" -eq 1 ]
}

@test "plugin_already_installed returns true for installed plugin" {
    # Create a mock git repository
    local plugin_path="$TMUX_PLUGIN_MANAGER_PATH/tmux-sensible"
    mkdir -p "$plugin_path"
    cd "$plugin_path"
    git init >/dev/null 2>&1
    git config commit.gpgsign false
    git remote add origin "https://github.com/tmux-plugins/tmux-sensible" >/dev/null 2>&1

    run plugin_already_installed "tmux-plugins/tmux-sensible"
    [ "$status" -eq 0 ]
}

# Test: clone_plugin function

@test "clone_plugin clones from GitHub shorthand" {
    skip "Requires network access and real git clone"
    # This would be an integration test
}

@test "clone_plugin creates directory structure" {
    # Test with a mock that doesn't actually clone
    # We'll test the path is correct even if clone fails
    local plugin="nonexistent/plugin"

    # Try to clone (will fail but we check it tried the right path)
    run clone_plugin "$plugin"
    [ "$status" -ne 0 ]

    # Directory shouldn't be created on failure
    [ ! -d "$TMUX_PLUGIN_MANAGER_PATH/plugin" ]
}

@test "clone_plugin handles branch specification" {
    # We can test that the function attempts to use the right parameters
    # by checking it extracts the branch correctly
    local plugin="user/repo#develop"
    local branch=$(get_plugin_branch "$plugin")

    [ "$branch" = "develop" ]
}

# Test: update_plugin function

@test "update_plugin fails for non-existent plugin" {
    run update_plugin "tmux-plugins/nonexistent"
    [ "$status" -eq 1 ]
}

@test "update_plugin works with installed plugin" {
    # Create two git repositories - one as "remote", one as "local"
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
    git config commit.gpgsign false  # Disable GPG signing for tests
    git remote add origin "$remote_repo" >/dev/null 2>&1

    # Create initial commit and push
    echo "# Test" > README.md
    git add README.md >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    git push -u origin master >/dev/null 2>&1 || git push -u origin main >/dev/null 2>&1

    # Now test update
    run update_plugin "tmux-plugins/tmux-sensible"
    [ "$status" -eq 0 ]
}

# Test: get_plugin_remote_url function

@test "get_plugin_remote_url returns URL for installed plugin" {
    local plugin_path="$TMUX_PLUGIN_MANAGER_PATH/tmux-sensible"
    mkdir -p "$plugin_path"
    cd "$plugin_path"
    git init >/dev/null 2>&1
    git config commit.gpgsign false
    git remote add origin "https://github.com/tmux-plugins/tmux-sensible.git" >/dev/null 2>&1

    run get_plugin_remote_url "tmux-plugins/tmux-sensible"
    [ "$status" -eq 0 ]
    [ "$output" = "https://github.com/tmux-plugins/tmux-sensible.git" ]
}

@test "get_plugin_remote_url fails for non-existent plugin" {
    run get_plugin_remote_url "tmux-plugins/nonexistent"
    [ "$status" -eq 1 ]
}

# Test: is_git_repo function

@test "is_git_repo returns true for git repository" {
    local test_repo="$TPM_TEST_DIR/test-repo"
    mkdir -p "$test_repo"
    cd "$test_repo"
    git init >/dev/null 2>&1
    git config commit.gpgsign false

    run is_git_repo "$test_repo"
    [ "$status" -eq 0 ]
}

@test "is_git_repo returns false for non-git directory" {
    local test_dir="$TPM_TEST_DIR/not-a-repo"
    mkdir -p "$test_dir"

    run is_git_repo "$test_dir"
    [ "$status" -eq 1 ]
}

@test "is_git_repo returns false for non-existent directory" {
    run is_git_repo "$TPM_TEST_DIR/nonexistent"
    [ "$status" -eq 1 ]
}

