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

# Test: get_tmux_config_value function

@test "get_tmux_config_value reads config value" {
    local config="$TPM_TEST_DIR/tmux.conf"
    cat > "$config" <<'EOF'
set -g @tpm-redux-max-commits '5'
EOF

    run get_tmux_config_value "@tpm-redux-max-commits" "$config"
    [ "$status" -eq 0 ]
    [ "$output" = "5" ]
}

@test "get_tmux_config_value handles double quotes" {
    local config="$TPM_TEST_DIR/tmux.conf"
    cat > "$config" <<'EOF'
set -g @tpm-redux-max-commits "3"
EOF

    run get_tmux_config_value "@tpm-redux-max-commits" "$config"
    [ "$status" -eq 0 ]
    [ "$output" = "3" ]
}

@test "get_tmux_config_value returns empty for missing key" {
    local config="$TPM_TEST_DIR/tmux.conf"
    cat > "$config" <<'EOF'
set -g @plugin 'tmux-plugins/tmux-sensible'
EOF

    run get_tmux_config_value "@tpm-redux-max-commits" "$config"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "get_tmux_config_value handles missing config file" {
    run get_tmux_config_value "@tpm-redux-max-commits" "/nonexistent/config"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# Test: parse_plugins follows source directives

@test "parse_plugins follows source-file directive (absolute path)" {
    local config="$TPM_TEST_DIR/tmux.conf"
    local sourced="$TPM_TEST_DIR/plugins.conf"

    echo "set -g @plugin 'user/plugin-a'" > "$sourced"
    echo "source-file $sourced" > "$config"

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "$output" = "user/plugin-a" ]
}

@test "parse_plugins follows source directive (alias without -file)" {
    local config="$TPM_TEST_DIR/tmux.conf"
    local sourced="$TPM_TEST_DIR/plugins.conf"

    echo "set -g @plugin 'user/plugin-b'" > "$sourced"
    echo "source $sourced" > "$config"

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "$output" = "user/plugin-b" ]
}

@test "parse_plugins returns plugins from main and sourced file in order" {
    local config="$TPM_TEST_DIR/tmux.conf"
    local sourced="$TPM_TEST_DIR/plugins.conf"

    echo "set -g @plugin 'user/sourced-plugin'" > "$sourced"
    cat > "$config" <<EOF
set -g @plugin 'user/main-plugin'
source-file $sourced
EOF

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "user/main-plugin" ]
    [ "${lines[1]}" = "user/sourced-plugin" ]
    [ "${#lines[@]}" -eq 2 ]
}

@test "parse_plugins follows nested sourcing (A -> B -> C)" {
    local config="$TPM_TEST_DIR/tmux.conf"
    local b="$TPM_TEST_DIR/b.conf"
    local c="$TPM_TEST_DIR/c.conf"

    echo "set -g @plugin 'user/deep-plugin'" > "$c"
    echo "source-file $c" > "$b"
    echo "source-file $b" > "$config"

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "$output" = "user/deep-plugin" ]
}

@test "parse_plugins handles circular reference without infinite loop" {
    local a="$TPM_TEST_DIR/a.conf"
    local b="$TPM_TEST_DIR/b.conf"

    cat > "$a" <<EOF
set -g @plugin 'user/plugin-a'
source-file $b
EOF
    cat > "$b" <<EOF
set -g @plugin 'user/plugin-b'
source-file $a
EOF

    run parse_plugins "$a"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [[ "$output" == *"user/plugin-a"* ]]
    [[ "$output" == *"user/plugin-b"* ]]
}

@test "parse_plugins handles self-referencing config without infinite loop" {
    local config="$TPM_TEST_DIR/tmux.conf"

    cat > "$config" <<EOF
set -g @plugin 'user/plugin-a'
source-file $config
EOF

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [ "$output" = "user/plugin-a" ]
}

@test "parse_plugins silently skips missing sourced file" {
    local config="$TPM_TEST_DIR/tmux.conf"

    cat > "$config" <<EOF
source-file /nonexistent/path.conf
set -g @plugin 'user/real-plugin'
EOF

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "$output" = "user/real-plugin" ]
}

@test "parse_plugins resolves relative path in source-file directive" {
    mkdir -p "$TPM_TEST_DIR/subdir"
    local config="$TPM_TEST_DIR/tmux.conf"
    local sourced="$TPM_TEST_DIR/subdir/plugins.conf"

    echo "set -g @plugin 'user/relative-plugin'" > "$sourced"
    echo "source-file subdir/plugins.conf" > "$config"

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "$output" = "user/relative-plugin" ]
}

@test "parse_plugins expands tilde in source-file path" {
    export HOME="$TPM_TEST_DIR/home"
    mkdir -p "$HOME"
    local config="$TPM_TEST_DIR/tmux.conf"

    echo "set -g @plugin 'user/tilde-plugin'" > "$HOME/plugins.conf"
    echo "source-file ~/plugins.conf" > "$config"

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "$output" = "user/tilde-plugin" ]
}

@test "parse_plugins handles double-quoted path in source-file directive" {
    local config="$TPM_TEST_DIR/tmux.conf"
    local sourced="$TPM_TEST_DIR/plugins.conf"

    echo "set -g @plugin 'user/quoted-plugin'" > "$sourced"
    echo "source-file \"$sourced\"" > "$config"

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "$output" = "user/quoted-plugin" ]
}

@test "parse_plugins only includes plugins once when same file sourced twice" {
    local config="$TPM_TEST_DIR/tmux.conf"
    local sourced="$TPM_TEST_DIR/plugins.conf"

    echo "set -g @plugin 'user/only-once'" > "$sourced"
    cat > "$config" <<EOF
source-file $sourced
source-file $sourced
EOF

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [ "$output" = "user/only-once" ]
}

# Test: parse_plugins handles source-file flags, globs, and multiple paths
# source-file syntax: source-file [-Fnqv] [-t target-pane] path ...
# -q, -v: affect output only, irrelevant to plugin loading -> just strip
# -t: takes an argument (target-pane) that must also be skipped
# -n: parse but do NOT execute -> tmux loads no plugins, parser must skip
# -F: path is a format -> cannot expand without tmux; best-effort the path
# glob(7) patterns and multiple paths must both be handled

@test "parse_plugins follows source-file with -q flag" {
    local config="$TPM_TEST_DIR/tmux.conf"
    local sourced="$TPM_TEST_DIR/plugins.conf"

    echo "set -g @plugin 'user/quiet-plugin'" > "$sourced"
    echo "source-file -q $sourced" > "$config"

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "$output" = "user/quiet-plugin" ]
}

@test "parse_plugins follows source-file with combined short flags" {
    local config="$TPM_TEST_DIR/tmux.conf"
    local sourced="$TPM_TEST_DIR/plugins.conf"

    echo "set -g @plugin 'user/combined-flags'" > "$sourced"
    echo "source-file -qv $sourced" > "$config"

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "$output" = "user/combined-flags" ]
}

@test "parse_plugins follows source-file with separate flags" {
    local config="$TPM_TEST_DIR/tmux.conf"
    local sourced="$TPM_TEST_DIR/plugins.conf"

    echo "set -g @plugin 'user/separate-flags'" > "$sourced"
    echo "source-file -q -v $sourced" > "$config"

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "$output" = "user/separate-flags" ]
}

@test "parse_plugins follows source-file with -t target-pane flag" {
    local config="$TPM_TEST_DIR/tmux.conf"
    local sourced="$TPM_TEST_DIR/plugins.conf"

    echo "set -g @plugin 'user/target-plugin'" > "$sourced"
    echo "source-file -t target-pane $sourced" > "$config"

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "$output" = "user/target-plugin" ]
}

@test "parse_plugins follows source-file with mixed flags and target" {
    local config="$TPM_TEST_DIR/tmux.conf"
    local sourced="$TPM_TEST_DIR/plugins.conf"

    echo "set -g @plugin 'user/mixed-flags'" > "$sourced"
    echo "source-file -q -t target-pane $sourced" > "$config"

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "$output" = "user/mixed-flags" ]
}

@test "parse_plugins does not follow source-file -n (no execution)" {
    # -n means the file is parsed but commands are NOT executed, so tmux
    # would not load any @plugin declarations from it. The parser must
    # match that semantics and skip the file entirely.
    local config="$TPM_TEST_DIR/tmux.conf"
    local sourced="$TPM_TEST_DIR/plugins.conf"

    echo "set -g @plugin 'user/noexec-plugin'" > "$sourced"
    echo "source-file -n $sourced" > "$config"

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 0 ]
}

@test "parse_plugins follows source-file with multiple paths" {
    local config="$TPM_TEST_DIR/tmux.conf"
    local a="$TPM_TEST_DIR/a.conf"
    local b="$TPM_TEST_DIR/b.conf"

    echo "set -g @plugin 'user/multi-a'" > "$a"
    echo "set -g @plugin 'user/multi-b'" > "$b"
    echo "source-file $a $b" > "$config"

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [[ "$output" == *"user/multi-a"* ]]
    [[ "$output" == *"user/multi-b"* ]]
}

@test "parse_plugins follows source-file with flags and multiple paths" {
    local config="$TPM_TEST_DIR/tmux.conf"
    local a="$TPM_TEST_DIR/a.conf"
    local b="$TPM_TEST_DIR/b.conf"

    echo "set -g @plugin 'user/flag-multi-a'" > "$a"
    echo "set -g @plugin 'user/flag-multi-b'" > "$b"
    echo "source-file -q $a $b" > "$config"

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [[ "$output" == *"user/flag-multi-a"* ]]
    [[ "$output" == *"user/flag-multi-b"* ]]
}

@test "parse_plugins follows globbed source-file path (absolute)" {
    mkdir -p "$TPM_TEST_DIR/conf.d"
    local config="$TPM_TEST_DIR/tmux.conf"

    echo "set -g @plugin 'user/glob-plugin-a'" > "$TPM_TEST_DIR/conf.d/a.conf"
    echo "set -g @plugin 'user/glob-plugin-b'" > "$TPM_TEST_DIR/conf.d/b.conf"
    echo "source-file $TPM_TEST_DIR/conf.d/*.conf" > "$config"

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [[ "$output" == *"user/glob-plugin-a"* ]]
    [[ "$output" == *"user/glob-plugin-b"* ]]
}

@test "parse_plugins follows globbed source-file with -q flag" {
    mkdir -p "$TPM_TEST_DIR/conf.d"
    local config="$TPM_TEST_DIR/tmux.conf"

    echo "set -g @plugin 'user/glob-one'" > "$TPM_TEST_DIR/conf.d/plugins.conf"
    echo "set -g @plugin 'user/glob-two'" > "$TPM_TEST_DIR/conf.d/other.conf"
    echo "source-file -q $TPM_TEST_DIR/conf.d/*.conf" > "$config"

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [[ "$output" == *"user/glob-one"* ]]
    [[ "$output" == *"user/glob-two"* ]]
}

@test "parse_plugins follows globbed source-file with tilde path" {
    export HOME="$TPM_TEST_DIR/home"
    mkdir -p "$HOME/.tmux/conf.d"
    local config="$TPM_TEST_DIR/tmux.conf"

    echo "set -g @plugin 'user/tilde-glob-a'" > "$HOME/.tmux/conf.d/a.conf"
    echo "set -g @plugin 'user/tilde-glob-b'" > "$HOME/.tmux/conf.d/b.conf"
    echo "source-file ~/.tmux/conf.d/*.conf" > "$config"

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [[ "$output" == *"user/tilde-glob-a"* ]]
    [[ "$output" == *"user/tilde-glob-b"* ]]
}

@test "parse_plugins follows relative globbed source-file path" {
    mkdir -p "$TPM_TEST_DIR/subdir"
    local config="$TPM_TEST_DIR/tmux.conf"

    echo "set -g @plugin 'user/relative-glob-a'" > "$TPM_TEST_DIR/subdir/a.conf"
    echo "set -g @plugin 'user/relative-glob-b'" > "$TPM_TEST_DIR/subdir/b.conf"
    echo "source-file subdir/*.conf" > "$config"

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 2 ]
    [[ "$output" == *"user/relative-glob-a"* ]]
    [[ "$output" == *"user/relative-glob-b"* ]]
}

@test "parse_plugins silently skips globbed source-file matching no files" {
    mkdir -p "$TPM_TEST_DIR/conf.d"
    local config="$TPM_TEST_DIR/tmux.conf"

    echo "source-file $TPM_TEST_DIR/conf.d/*.conf" > "$config"
    echo "set -g @plugin 'user/main-plugin'" >> "$config"

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [ "$output" = "user/main-plugin" ]
}

@test "parse_plugins expands globbed source-file alongside explicit sourced files" {
    mkdir -p "$TPM_TEST_DIR/conf.d"
    local config="$TPM_TEST_DIR/tmux.conf"
    local explicit="$TPM_TEST_DIR/explicit.conf"

    echo "set -g @plugin 'user/explicit-plugin'" > "$explicit"
    echo "set -g @plugin 'user/globbed-a'" > "$TPM_TEST_DIR/conf.d/a.conf"
    echo "set -g @plugin 'user/globbed-b'" > "$TPM_TEST_DIR/conf.d/b.conf"
    cat > "$config" <<EOF
set -g @plugin 'user/main-plugin'
source-file $explicit
source-file $TPM_TEST_DIR/conf.d/*.conf
EOF

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 4 ]
    [[ "$output" == *"user/main-plugin"* ]]
    [[ "$output" == *"user/explicit-plugin"* ]]
    [[ "$output" == *"user/globbed-a"* ]]
    [[ "$output" == *"user/globbed-b"* ]]
}

@test "parse_plugins does not duplicate plugins from glob and explicit source" {
    mkdir -p "$TPM_TEST_DIR/conf.d"
    local config="$TPM_TEST_DIR/tmux.conf"
    local shared="$TPM_TEST_DIR/conf.d/shared.conf"

    echo "set -g @plugin 'user/shared-plugin'" > "$shared"
    cat > "$config" <<EOF
source-file $shared
source-file $TPM_TEST_DIR/conf.d/*.conf
EOF

    run parse_plugins "$config"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [ "$output" = "user/shared-plugin" ]
}
