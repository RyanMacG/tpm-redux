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

@test "clone_plugin handles branch (not commit hash) correctly" {
    # Create a mock git repository with remote and a branch
    local remote_repo="$TPM_TEST_DIR/remote-repo"
    local plugin_path="$TMUX_PLUGIN_MANAGER_PATH/test-plugin"

    # Set up remote repo
    mkdir -p "$remote_repo"
    cd "$remote_repo"
    git init --bare >/dev/null 2>&1

    # Clone the repo first to create commits and branch
    local temp_clone="$TPM_TEST_DIR/temp-clone"
    git clone "$remote_repo" "$temp_clone" >/dev/null 2>&1
    cd "$temp_clone"
    git config user.email "test@example.com"
    git config user.name "Test User"
    git config commit.gpgsign false

    # Create initial commit on main
    echo "v1" > file.txt
    git add file.txt >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    git branch -M main >/dev/null 2>&1
    git push -u origin main >/dev/null 2>&1

    # Create a develop branch
    git checkout -b develop >/dev/null 2>&1
    echo "v2-dev" > file.txt
    git add file.txt >/dev/null 2>&1
    git commit -m "Develop commit" >/dev/null 2>&1
    git push -u origin develop >/dev/null 2>&1

    # Test cloning with branch name (not commit hash)
    local plugin_spec="file://$remote_repo"

    # Clone should use -b develop (branch, not commit hash)
    run clone_plugin "$plugin_spec" "develop"
    [ "$status" -eq 0 ]

    # Verify it cloned the develop branch
    local cloned_name="${remote_repo##*/}"
    local actual_path="$TMUX_PLUGIN_MANAGER_PATH/$cloned_name"
    [ -d "$actual_path" ]

    cd "$actual_path" || exit 1
    local current_branch
    current_branch="$(git rev-parse --abbrev-ref HEAD)"
    [ "$current_branch" = "develop" ]

    # Verify it has the develop commit content
    [ "$(cat file.txt)" = "v2-dev" ]

    # Cleanup
    rm -rf "$temp_clone"
}

@test "clone_plugin handles commit hash specification" {
    # Create a mock git repository with remote
    local remote_repo="$TPM_TEST_DIR/remote-repo"
    local plugin_path="$TMUX_PLUGIN_MANAGER_PATH/test-plugin"

    # Set up remote repo
    mkdir -p "$remote_repo"
    cd "$remote_repo"
    git init --bare >/dev/null 2>&1

    # Clone the repo first to create commits
    local temp_clone="$TPM_TEST_DIR/temp-clone"
    git clone "$remote_repo" "$temp_clone" >/dev/null 2>&1
    cd "$temp_clone"
    git config user.email "test@example.com"
    git config user.name "Test User"
    git config commit.gpgsign false

    # Create first commit
    echo "v1" > file.txt
    git add file.txt >/dev/null 2>&1
    git commit -m "First commit" >/dev/null 2>&1
    git branch -M main >/dev/null 2>&1
    git push -u origin main >/dev/null 2>&1

    # Create second commit
    echo "v2" > file.txt
    git add file.txt >/dev/null 2>&1
    git commit -m "Second commit" >/dev/null 2>&1
    local second_hash
    second_hash="$(git rev-parse --short HEAD)"
    git push origin main >/dev/null 2>&1

    # Create third commit
    echo "v3" > file.txt
    git add file.txt >/dev/null 2>&1
    git commit -m "Third commit" >/dev/null 2>&1
    git push origin main >/dev/null 2>&1

    # Test cloning with commit hash - use file:// URL
    # The plugin_spec format: file://path#hash gets parsed, hash is passed as branch param
    local plugin_spec="file://$remote_repo"

    # Test that clone_plugin correctly handles commit hash as second parameter
    run clone_plugin "$plugin_spec" "$second_hash"
    [ "$status" -eq 0 ]

    # Verify the cloned directory exists and is at the right commit
    # get_plugin_path will extract "remote-repo" as the name from file:// URL
    local cloned_name="${remote_repo##*/}"
    local actual_path="$TMUX_PLUGIN_MANAGER_PATH/$cloned_name"
    [ -d "$actual_path" ]

    cd "$actual_path" || exit 1
    local current_hash
    current_hash="$(git rev-parse --short HEAD)"
    [ "$current_hash" = "$second_hash" ]

    # Cleanup
    rm -rf "$temp_clone"
}

@test "clone_plugin handles tag (not commit hash) correctly" {
    # Create a mock git repository with remote and a tag
    local remote_repo="$TPM_TEST_DIR/remote-repo"
    local plugin_path="$TMUX_PLUGIN_MANAGER_PATH/test-plugin"

    # Set up remote repo
    mkdir -p "$remote_repo"
    cd "$remote_repo"
    git init --bare >/dev/null 2>&1

    # Clone the repo first to create commits and tag
    local temp_clone="$TPM_TEST_DIR/temp-clone"
    git clone "$remote_repo" "$temp_clone" >/dev/null 2>&1
    cd "$temp_clone"
    git config user.email "test@example.com"
    git config user.name "Test User"
    git config commit.gpgsign false

    # Create initial commit
    echo "v1" > file.txt
    git add file.txt >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    git branch -M main >/dev/null 2>&1
    git push -u origin main >/dev/null 2>&1

    # Create a tag
    git tag v1.0.0 >/dev/null 2>&1
    git push origin v1.0.0 >/dev/null 2>&1

    # Create another commit after the tag
    echo "v2" > file.txt
    git add file.txt >/dev/null 2>&1
    git commit -m "Second commit" >/dev/null 2>&1
    git push origin main >/dev/null 2>&1

    # Test cloning with tag name (not commit hash)
    local plugin_spec="file://$remote_repo"

    # Clone should use -b v1.0.0 (tag, not commit hash)
    run clone_plugin "$plugin_spec" "v1.0.0"
    [ "$status" -eq 0 ]

    # Verify it cloned the tag
    local cloned_name="${remote_repo##*/}"
    local actual_path="$TMUX_PLUGIN_MANAGER_PATH/$cloned_name"
    [ -d "$actual_path" ]

    cd "$actual_path" || exit 1
    # Check that we're at the tag (detached HEAD)
    local current_ref
    current_ref="$(git describe --tags --exact-match HEAD 2>/dev/null || echo "")"
    [ "$current_ref" = "v1.0.0" ]

    # Verify it has the v1.0.0 commit content
    [ "$(cat file.txt)" = "v1" ]

    # Cleanup
    rm -rf "$temp_clone"
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

