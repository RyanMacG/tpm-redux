#!/usr/bin/env bats

# Test the testing infrastructure itself

load test_helper

@test "test helper loads successfully" {
    [ -n "$BATS_TEST_DIRNAME" ]
}

@test "can get project root" {
    run get_project_root
    [ "$status" -eq 0 ]
    [ -d "$output" ]
}

@test "can create and cleanup temp directory" {
    setup_temp_dir
    [ -n "$TPM_TEST_DIR" ]
    [ -d "$TPM_TEST_DIR" ]

    # Create a test file
    touch "$TPM_TEST_DIR/test_file"
    [ -f "$TPM_TEST_DIR/test_file" ]

    # Cleanup
    teardown_temp_dir
    [ ! -d "$TPM_TEST_DIR" ]
}

@test "can create mock config file" {
    setup_temp_dir

    local config="$TPM_TEST_DIR/tmux.conf"
    create_mock_config "$config" "user/plugin1" "user/plugin2"

    [ -f "$config" ]

    # Check content
    run cat "$config"
    [ "$status" -eq 0 ]
    [[ "$output" == *"set -g @plugin 'user/plugin1'"* ]]
    [[ "$output" == *"set -g @plugin 'user/plugin2'"* ]]

    teardown_temp_dir
}

@test "can create mock plugin directory" {
    setup_temp_dir

    local plugin_dir="$TPM_TEST_DIR/plugins"
    create_mock_plugin "$plugin_dir" "test-plugin"

    [ -d "$plugin_dir/test-plugin" ]
    [ -f "$plugin_dir/test-plugin/test-plugin.tmux" ]
    [ -x "$plugin_dir/test-plugin/test-plugin.tmux" ]

    teardown_temp_dir
}

@test "assert_file_exists works correctly" {
    setup_temp_dir

    touch "$TPM_TEST_DIR/test_file"
    run assert_file_exists "$TPM_TEST_DIR/test_file"
    [ "$status" -eq 0 ]

    run assert_file_exists "$TPM_TEST_DIR/nonexistent"
    [ "$status" -eq 1 ]

    teardown_temp_dir
}

@test "assert_dir_exists works correctly" {
    setup_temp_dir

    run assert_dir_exists "$TPM_TEST_DIR"
    [ "$status" -eq 0 ]

    run assert_dir_exists "$TPM_TEST_DIR/nonexistent"
    [ "$status" -eq 1 ]

    teardown_temp_dir
}

@test "assert_contains works correctly" {
    run assert_contains "hello world" "world"
    [ "$status" -eq 0 ]

    run assert_contains "hello world" "foo"
    [ "$status" -eq 1 ]
}

