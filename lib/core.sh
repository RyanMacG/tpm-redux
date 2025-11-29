#!/usr/bin/env bash

# Core TPM Redux library
# Handles config parsing, plugin detection, and path management

# Get the path to the tmux configuration file
# Prefers XDG config path if it exists, falls back to ~/.tmux.conf
get_tmux_config_path() {
    local xdg_config="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"
    local home_config="$HOME/.tmux.conf"

    if [[ -f "$xdg_config" ]]; then
        echo "$xdg_config"
    else
        echo "$home_config"
    fi
}

# Parse plugin declarations from tmux config file
# Extracts all 'set -g @plugin' lines and returns plugin names
# Args:
#   $1 - path to tmux config file
parse_plugins() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        return 0
    fi

    # Use awk for efficient single-pass parsing
    # Matches: set -g @plugin 'name' or set-option -g @plugin "name"
    awk '
        /^[[:space:]]*set(-option)?[[:space:]]+-g[[:space:]]+@plugin[[:space:]]/ {
            # Extract the plugin name (4th field)
            plugin = $4
            # Remove quotes (single or double)
            gsub(/["'\'']/, "", plugin)
            if (plugin != "") {
                print plugin
            }
        }
    ' "$config_file"
}

# Get the plugin name from a plugin specification
# Handles: user/repo, user/repo#branch, full URLs, .git extensions
# Args:
#   $1 - plugin specification
get_plugin_name() {
    local plugin_spec="$1"

    # Remove branch specification if present (everything after #)
    plugin_spec="${plugin_spec%%#*}"

    # Get the basename (last part after /)
    local basename="${plugin_spec##*/}"

    # Remove .git extension if present
    basename="${basename%.git}"

    echo "$basename"
}

# Get the branch from a plugin specification
# Returns empty string if no branch specified
# Args:
#   $1 - plugin specification (e.g., user/repo#branch)
get_plugin_branch() {
    local plugin_spec="$1"

    # Check if branch is specified (contains #)
    if [[ "$plugin_spec" == *"#"* ]]; then
        echo "${plugin_spec##*#}"
    else
        echo ""
    fi
}

# Get the full path where a plugin should be installed
# Args:
#   $1 - plugin specification
get_plugin_path() {
    local plugin_spec="$1"
    local plugin_name
    local tpm_path

    plugin_name="$(get_plugin_name "$plugin_spec")"
    tpm_path="$(get_tpm_path)"

    # Remove trailing slash from tpm_path if present, then add plugin_name
    echo "${tpm_path%/}/${plugin_name}"
}

# Get the TPM plugins directory path
# Priority:
#   1. TMUX_PLUGIN_MANAGER_PATH environment variable
#   2. XDG config path (if tmux.conf exists there)
#   3. Default: ~/.tmux/plugins/
get_tpm_path() {
    # If explicitly set, use it
    if [[ -n "${TMUX_PLUGIN_MANAGER_PATH}" ]]; then
        # Manually expand leading tilde if user quoted it in their env var
        # ${var/#pattern/replacement} matches pattern only at start of string
        echo "${TMUX_PLUGIN_MANAGER_PATH/#\~/${HOME}}"
        return 0
    fi

    # Check if using XDG config
    local xdg_config="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/tmux.conf"
    if [[ -f "$xdg_config" ]]; then
        echo "${XDG_CONFIG_HOME:-$HOME/.config}/tmux/plugins/"
        return 0
    fi

    # Default path
    echo "$HOME/.tmux/plugins/"
}

