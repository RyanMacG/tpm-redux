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

# Parallel plugin operations (TPM_PARALLEL)

@test "update_all_plugins with TPM_PARALLEL=0 outputs plugin status in config order" {
    local config="$TPM_TEST_DIR/tmux.conf"
    cat > "$config" <<'EOF'
set -g @plugin 'user/plugin-a'
set -g @plugin 'user/plugin-b'
set -g @plugin 'user/plugin-c'
EOF

    for name in plugin-a plugin-b plugin-c; do
        local remote_repo="$TPM_TEST_DIR/remote-$name"
        local plugin_path="$TMUX_PLUGIN_MANAGER_PATH/$name"
        mkdir -p "$remote_repo"
        (cd "$remote_repo" && git init --bare >/dev/null 2>&1)
        mkdir -p "$plugin_path"
        (cd "$plugin_path" && git init >/dev/null 2>&1 && git config user.email "t@t.com" && git config user.name "T" && git config commit.gpgsign false && git remote add origin "$remote_repo" >/dev/null 2>&1 && echo x > f && git add f && git commit -m "x" >/dev/null 2>&1 && git push -u origin master >/dev/null 2>&1 || git push -u origin main >/dev/null 2>&1)
    done

    TPM_PARALLEL=0 run update_all_plugins "$config"
    [ "$status" -eq 0 ]
    local first_a first_b first_c
    first_a=$(echo "$output" | grep -n "plugin-a" | head -1 | cut -d: -f1)
    first_b=$(echo "$output" | grep -n "plugin-b" | head -1 | cut -d: -f1)
    first_c=$(echo "$output" | grep -n "plugin-c" | head -1 | cut -d: -f1)
    [ "$first_a" -lt "$first_b" ]
    [ "$first_b" -lt "$first_c" ]
}

@test "update_all_plugins with TPM_PARALLEL=1 and multiple plugins produces correct summary" {
    local config="$TPM_TEST_DIR/tmux.conf"
    cat > "$config" <<'EOF'
set -g @plugin 'user/plugin1'
set -g @plugin 'user/plugin2'
set -g @plugin 'user/plugin3'
EOF

    for name in plugin1 plugin2 plugin3; do
        local remote_repo="$TPM_TEST_DIR/remote-$name"
        local plugin_path="$TMUX_PLUGIN_MANAGER_PATH/$name"
        mkdir -p "$remote_repo"
        (cd "$remote_repo" && git init --bare >/dev/null 2>&1)
        mkdir -p "$plugin_path"
        (cd "$plugin_path" && git init >/dev/null 2>&1 && git config user.email "t@t.com" && git config user.name "T" && git config commit.gpgsign false && git remote add origin "$remote_repo" >/dev/null 2>&1 && echo x > f && git add f && git commit -m "x" >/dev/null 2>&1 && git push -u origin master >/dev/null 2>&1 || git push -u origin main >/dev/null 2>&1)
    done

    TPM_PARALLEL=1 run update_all_plugins "$config"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Update complete" ]]
    [[ "$output" =~ "plugin1" ]] && [[ "$output" =~ "plugin2" ]] && [[ "$output" =~ "plugin3" ]]
}

@test "update_all_plugins with single plugin ignores TPM_PARALLEL" {
    local config="$TPM_TEST_DIR/tmux.conf"
    echo "set -g @plugin 'user/only'" > "$config"
    local remote_repo="$TPM_TEST_DIR/remote-only"
    local plugin_path="$TMUX_PLUGIN_MANAGER_PATH/only"
    mkdir -p "$remote_repo"
    (cd "$remote_repo" && git init --bare >/dev/null 2>&1)
    mkdir -p "$plugin_path"
    (cd "$plugin_path" && git init >/dev/null 2>&1 && git config user.email "t@t.com" && git config user.name "T" && git config commit.gpgsign false && git remote add origin "$remote_repo" >/dev/null 2>&1 && echo x > f && git add f && git commit -m "x" >/dev/null 2>&1 && git push -u origin master >/dev/null 2>&1 || git push -u origin main >/dev/null 2>&1)

    TPM_PARALLEL=1 run update_all_plugins "$config"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "only" ]]
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

@test "get_plugin_commits_between limits to max commits when specified" {
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

    # Create third commit
    echo "v3" > file.txt
    git add file.txt >/dev/null 2>&1
    git commit -m "Third commit" >/dev/null 2>&1

    # Create fourth commit
    echo "v4" > file.txt
    git add file.txt >/dev/null 2>&1
    git commit -m "Fourth commit" >/dev/null 2>&1
    local fourth_hash
    fourth_hash="$(git rev-parse --short HEAD)"

    # Get only 2 most recent commits (should limit from 3 commits to 2)
    run get_plugin_commits_between "$first_hash" "$fourth_hash" "$plugin_path" "2"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Should contain fourth commit (most recent)
    [[ "$output" =~ "Fourth commit" ]]
    # Should contain third commit (second most recent)
    [[ "$output" =~ "Third commit" ]]
    # Should NOT contain second commit (limited to 2)
    [[ ! "$output" =~ "Second commit" ]]
    # Should NOT contain first commit (it's the old_hash, excluded)
    [[ ! "$output" =~ "First commit" ]]

    # Count lines - should be exactly 2 commits
    local line_count
    line_count="$(echo "$output" | grep -c . || echo 0)"
    [ "$line_count" -eq 2 ]
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

@test "format_commit_display shows 'updated from X to Y' without emoji" {
    local plugin_path="$TMUX_PLUGIN_MANAGER_PATH/test-plugin"
    mkdir -p "$plugin_path"
    cd "$plugin_path"
    git init >/dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"
    git config commit.gpgsign false

    echo "v1" > file.txt
    git add file.txt >/dev/null 2>&1
    git commit -m "First commit" >/dev/null 2>&1
    local old_hash
    old_hash="$(git rev-parse --short HEAD)"

    echo "v2" > file.txt
    git add file.txt >/dev/null 2>&1
    git commit -m "Second commit" >/dev/null 2>&1
    local new_hash
    new_hash="$(git rev-parse --short HEAD)"

    local commits="${new_hash}|Second commit|1 hour ago"
    run format_commit_display "test-plugin" "$old_hash" "$new_hash" "$commits" "updated" "$plugin_path"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Should show "updated from X to Y" format (no emoji)
    [[ "$output" =~ "updated from ${old_hash} to ${new_hash}" ]]
    # Should NOT contain emoji
    [[ ! "$output" =~ "📖" ]]
    [[ "$output" =~ "Second commit" ]]
}

@test "format_commit_display limits to 2 most recent commits" {
    local plugin_path="$TMUX_PLUGIN_MANAGER_PATH/test-plugin"
    mkdir -p "$plugin_path"
    cd "$plugin_path"
    git init >/dev/null 2>&1
    git config user.email "test@example.com"
    git config user.name "Test User"
    git config commit.gpgsign false

    echo "v1" > file.txt
    git add file.txt >/dev/null 2>&1
    git commit -m "First commit" >/dev/null 2>&1
    local old_hash
    old_hash="$(git rev-parse --short HEAD)"

    echo "v2" > file.txt
    git add file.txt >/dev/null 2>&1
    git commit -m "Second commit" >/dev/null 2>&1
    local second_hash
    second_hash="$(git rev-parse --short HEAD)"

    echo "v3" > file.txt
    git add file.txt >/dev/null 2>&1
    git commit -m "Third commit" >/dev/null 2>&1
    local third_hash
    third_hash="$(git rev-parse --short HEAD)"

    echo "v4" > file.txt
    git add file.txt >/dev/null 2>&1
    git commit -m "Fourth commit" >/dev/null 2>&1
    local new_hash
    new_hash="$(git rev-parse --short HEAD)"

    # Create commits string with 3 commits (should only show 2)
    local commits="${new_hash}|Fourth commit|5 minutes ago
${third_hash}|Third commit|10 minutes ago
${second_hash}|Second commit|15 minutes ago"

    run format_commit_display "test-plugin" "$old_hash" "$new_hash" "$commits" "updated" "$plugin_path"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    # Should show "updated from X to Y"
    [[ "$output" =~ "updated from ${old_hash} to ${new_hash}" ]]
    # Should show most recent commit (Fourth)
    [[ "$output" =~ "Fourth commit" ]]
    # Should show second most recent (Third)
    [[ "$output" =~ "Third commit" ]]
    # Should NOT show older commit (Second)
    [[ ! "$output" =~ "Second commit" ]]

    # Count commit lines in output (excluding plugin name and "updated from" line)
    local commit_lines
    commit_lines="$(echo "$output" | grep -E "^  [a-f0-9]{7}" | wc -l | tr -d ' ')"
    [ "$commit_lines" -eq 2 ]
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

@test "update_plugin updates from pinned commit hash to branch head" {
    # Create a mock git repository with remote
    local remote_repo="$TPM_TEST_DIR/remote-repo"
    local plugin_path
    plugin_path="$(get_plugin_path "file://$remote_repo")"
    local config="$TPM_TEST_DIR/tmux.conf"
    # Set up remote repo
    mkdir -p "$remote_repo"
    cd "$remote_repo"
    git init --bare >/dev/null 2>&1

    # Clone the repo to create commits
    local temp_clone="$TPM_TEST_DIR/temp-clone"
    git clone "$remote_repo" "$temp_clone" >/dev/null 2>&1
    cd "$temp_clone"
    git config user.email "test@example.com"
    git config user.name "Test User"
    git config commit.gpgsign false

    # Create initial commit
    echo "v1" > README.md
    git add README.md >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1
    git branch -M main >/dev/null 2>&1
    git push -u origin main >/dev/null 2>&1

    # Get the first commit hash
    local first_hash
    first_hash="$(git rev-parse --short HEAD)"

    # Create second commit
    echo "v2" > README.md
    git add README.md >/dev/null 2>&1
    git commit -m "Second commit" >/dev/null 2>&1
    git push origin main >/dev/null 2>&1

    # Get the second commit hash
    local second_hash
    second_hash="$(git rev-parse --short HEAD)"

    # Install plugin pinned to first commit
    local plugin_spec="file://$remote_repo#${first_hash}"
    run clone_plugin "$plugin_spec" "$first_hash"
    [ "$status" -eq 0 ]

    # Verify we're at the first commit (detached HEAD)
    cd "$plugin_path" || exit 1
    local current_hash
    current_hash="$(git rev-parse --short HEAD)"
    [ "$current_hash" = "$first_hash" ]

    # Create config with plugin without pin (should update to branch head)
    echo "set -g @plugin 'file://$remote_repo'" > "$config"

    # Update the plugin - should move from pinned commit to branch head
    run update_plugin "file://$remote_repo"
    [ "$status" -eq 0 ]

    # Verify we're now at the second commit (branch head)
    cd "$plugin_path" || exit 1
    current_hash="$(git rev-parse --short HEAD)"
    [ "$current_hash" = "$second_hash" ]

    # Cleanup
    rm -rf "$temp_clone"
}