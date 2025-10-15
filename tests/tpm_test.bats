#!/usr/bin/env bats

# Tests for main tpm entry point

load test_helper

setup() {
    setup_temp_dir
    export PROJECT_ROOT=$(get_project_root)
    export TMUX_PLUGIN_MANAGER_PATH="$TPM_TEST_DIR/plugins"
    export TPM_TEST_MODE=1  # Enable test mode for version checking
    mkdir -p "$TMUX_PLUGIN_MANAGER_PATH"
}

teardown() {
    teardown_temp_dir
}

# Test: source_plugin function

@test "source_plugin executes .tmux files in plugin directory" {
    source "$PROJECT_ROOT/tpm"

    # Create a mock plugin with a .tmux file
    local plugin_dir="$TMUX_PLUGIN_MANAGER_PATH/test-plugin"
    mkdir -p "$plugin_dir"

    # Create a .tmux file that writes to a test file
    cat > "$plugin_dir/test-plugin.tmux" <<'EOF'
#!/usr/bin/env bash
echo "plugin executed" > "$TPM_TEST_MARKER"
EOF
    chmod +x "$plugin_dir/test-plugin.tmux"

    # Set marker file path
    export TPM_TEST_MARKER="$TPM_TEST_DIR/marker.txt"

    # Source the plugin
    source_plugin "test-plugin"

    # Check if plugin was executed
    [ -f "$TPM_TEST_MARKER" ]
    [ "$(cat "$TPM_TEST_MARKER")" = "plugin executed" ]
}

@test "source_plugin handles multiple .tmux files" {
    source "$PROJECT_ROOT/tpm"

    local plugin_dir="$TMUX_PLUGIN_MANAGER_PATH/multi-plugin"
    mkdir -p "$plugin_dir"

    # Create multiple .tmux files
    echo '#!/usr/bin/env bash' > "$plugin_dir/first.tmux"
    echo 'echo "first" >> "$TPM_TEST_MARKER"' >> "$plugin_dir/first.tmux"
    chmod +x "$plugin_dir/first.tmux"

    echo '#!/usr/bin/env bash' > "$plugin_dir/second.tmux"
    echo 'echo "second" >> "$TPM_TEST_MARKER"' >> "$plugin_dir/second.tmux"
    chmod +x "$plugin_dir/second.tmux"

    export TPM_TEST_MARKER="$TPM_TEST_DIR/marker.txt"

    source_plugin "multi-plugin"

    [ -f "$TPM_TEST_MARKER" ]
    grep -q "first" "$TPM_TEST_MARKER"
    grep -q "second" "$TPM_TEST_MARKER"
}

@test "source_plugin handles missing plugin gracefully" {
    source "$PROJECT_ROOT/tpm"

    # Should not crash when plugin doesn't exist
    run source_plugin "nonexistent-plugin"
    [ "$status" -eq 0 ]
}

@test "source_plugin handles plugin without .tmux files" {
    source "$PROJECT_ROOT/tpm"

    local plugin_dir="$TMUX_PLUGIN_MANAGER_PATH/empty-plugin"
    mkdir -p "$plugin_dir"

    # Should not crash when no .tmux files exist
    run source_plugin "empty-plugin"
    [ "$status" -eq 0 ]
}

# Test: source_all_plugins function

@test "source_all_plugins sources plugins from config" {
    source "$PROJECT_ROOT/tpm"

    # Create mock config
    local config="$TPM_TEST_DIR/tmux.conf"
    cat > "$config" <<'EOF'
set -g @plugin 'user/plugin1'
set -g @plugin 'user/plugin2'
EOF

    # Create mock plugins
    for plugin in plugin1 plugin2; do
        local plugin_dir="$TMUX_PLUGIN_MANAGER_PATH/$plugin"
        mkdir -p "$plugin_dir"
        cat > "$plugin_dir/${plugin}.tmux" <<EOF
#!/usr/bin/env bash
echo "$plugin" >> "\$TPM_TEST_MARKER"
EOF
        chmod +x "$plugin_dir/${plugin}.tmux"
    done

    export TPM_TEST_MARKER="$TPM_TEST_DIR/marker.txt"

    # Source all plugins
    source_all_plugins "$config"

    [ -f "$TPM_TEST_MARKER" ]
    grep -q "plugin1" "$TPM_TEST_MARKER"
    grep -q "plugin2" "$TPM_TEST_MARKER"
}

# Test: check_tmux_version function

@test "check_tmux_version validates minimum version" {
    source "$PROJECT_ROOT/tpm"

    # These should pass (version >= 1.9)
    run check_tmux_version "1.9"
    [ "$status" -eq 0 ]

    run check_tmux_version "2.0"
    [ "$status" -eq 0 ]

    run check_tmux_version "3.2"
    [ "$status" -eq 0 ]
}

@test "check_tmux_version rejects old versions" {
    source "$PROJECT_ROOT/tpm"

    # These should fail (version < 1.9)
    run check_tmux_version "1.8"
    [ "$status" -eq 1 ]

    run check_tmux_version "1.7"
    [ "$status" -eq 1 ]
}

# Test: version comparison

@test "version_greater_or_equal compares versions correctly" {
    source "$PROJECT_ROOT/tpm"

    # Equal versions
    run version_greater_or_equal "1.9" "1.9"
    [ "$status" -eq 0 ]

    # Greater versions
    run version_greater_or_equal "2.0" "1.9"
    [ "$status" -eq 0 ]

    run version_greater_or_equal "1.10" "1.9"
    [ "$status" -eq 0 ]

    # Lesser versions
    run version_greater_or_equal "1.8" "1.9"
    [ "$status" -eq 1 ]

    run version_greater_or_equal "1.9" "2.0"
    [ "$status" -eq 1 ]
}

