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

# Resolve a file path to its canonical absolute path
# Falls back to the original path if resolution fails
# Args:
#   $1 - path to resolve
_resolve_path() {
    local path="$1"
    if command -v realpath &>/dev/null; then
        realpath "$path" 2>/dev/null || echo "$path"
    else
        readlink -f "$path" 2>/dev/null || echo "$path"
    fi
}

# Global visited-files tracker for parse_plugins (reset on each top-level call)
_TPM_PARSE_VISITED=""

# Internal recursive helper for parse_plugins
# Reads a config file, prints @plugin declarations, and follows source directives
# Uses _TPM_PARSE_VISITED global to prevent duplicate/circular processing
# Args:
#   $1 - path to config file
_parse_plugins_recursive() {
    local config_file="$1"

    [[ ! -f "$config_file" ]] && return 0

    local canonical
    canonical="$(_resolve_path "$config_file")"

    # Skip if already visited (handles duplicates and circular references)
    if [[ ":${_TPM_PARSE_VISITED}:" == *":${canonical}:"* ]]; then
        return 0
    fi

    _TPM_PARSE_VISITED="${_TPM_PARSE_VISITED:+${_TPM_PARSE_VISITED}:}${canonical}"

    local config_dir
    config_dir="$(dirname "$config_file")"

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comment lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        # Match @plugin declarations
        if [[ "$line" =~ ^[[:space:]]*set(-option)?[[:space:]]+-g[[:space:]]+@plugin[[:space:]] ]]; then
            local plugin
            plugin=$(echo "$line" | awk '{plugin=$4; gsub(/["'"'"']/, "", plugin); print plugin}')
            [[ -n "$plugin" ]] && echo "$plugin"
            continue
        fi

        # Match source-file or source directives
        # source-file [-Fnqv] [-t target-pane] path ...
        if [[ "$line" =~ ^[[:space:]]*(source-file|source)[[:space:]] ]]; then
            local rest word skip_source expect_target
            local -a src_paths=() tokens=()
            rest=$(echo "$line" | awk '{
                sub(/^[[:space:]]*(source-file|source)[[:space:]]+/, "")
                print
            }')
            read -ra tokens <<< "$rest"
            skip_source=0
            expect_target=0
            for word in "${tokens[@]}"; do
                if (( expect_target )); then
                    expect_target=0
                    continue
                fi
                word="${word#\"}"; word="${word%\"}"
                word="${word#\'}"; word="${word%\'}"
                if [[ "$word" =~ ^-[Fnqvt]+$ ]]; then
                    [[ "$word" == *n* ]] && skip_source=1
                    [[ "$word" == *t* ]] && expect_target=1
                    continue
                fi
                src_paths+=("$word")
            done
            # -n means parse but do not execute: tmux loads no plugins, so skip
            (( skip_source )) && continue
            local p expanded _nullglob
            local -a matches=()
            _nullglob=$(shopt -p nullglob)
            shopt -s nullglob
            for p in "${src_paths[@]}"; do
                p="${p/#\~/$HOME}"
                [[ "$p" != /* ]] && p="$config_dir/$p"
                matches=($p)
                for expanded in "${matches[@]}"; do
                    _parse_plugins_recursive "$expanded"
                done
            done
            eval "$_nullglob"
        fi
    done < "$config_file"
}

# Parse plugin declarations from tmux config file
# Extracts all 'set -g @plugin' lines and returns plugin names
# Also follows source-file and source directives to find plugins in sourced files
# Args:
#   $1 - path to tmux config file
parse_plugins() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        return 0
    fi

    _TPM_PARSE_VISITED=""
    _parse_plugins_recursive "$config_file"
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


# Get the path to the lock file
# Lock file lives alongside the plugins directory (one level up from it)
get_lock_file_path() {
    local tpm_path
    tpm_path="$(get_tpm_path)"
    echo "$(dirname "${tpm_path%/}")/tpm.lock"
}

# Parse the lock file, returning non-comment, non-blank lines
# Returns 1 if no lock file exists
parse_lock_file() {
    local lock_file
    lock_file="$(get_lock_file_path)"
    [[ -f "$lock_file" ]] || return 1
    grep -v '^#' "$lock_file" | grep -v '^[[:space:]]*$'
}

# Get the locked commit hash for a given plugin spec
# Returns empty string if not found or no lock file
get_locked_hash() {
    local plugin_spec="$1"
    parse_lock_file 2>/dev/null | while IFS=' ' read -r spec hash; do
        if [[ "$spec" == "$plugin_spec" ]]; then
            echo "$hash"
            return
        fi
    done
}

# Get a tmux configuration value
# Reads values like @tpm-redux-max-commits from tmux config file
# Args:
#   $1 - config key (e.g., "@tpm-redux-max-commits")
#   $2 - optional config path (defaults to detected config)
# Returns:
#   The value if found, empty string otherwise
get_tmux_config_value() {
    local key="$1"
    local config_path="${2:-$(get_tmux_config_path)}"
    
    if [[ ! -f "$config_path" ]]; then
        return 0
    fi
    
    # Match: set -g @key 'value' or set-option -g @key "value"
    # Extract value (everything after the key, removing quotes)
    awk -v key="$key" '
        /^[[:space:]]*set(-option)?[[:space:]]+-g[[:space:]]+@/ {
            # Check if this line matches our key
            if ($0 ~ key) {
                # Find the value (everything after the key)
                # Remove quotes and print
                for (i=4; i<=NF; i++) {
                    value = value (i>4 ? " " : "") $i
                }
                gsub(/^["'\''"]|["'\''"]$/, "", value)
                print value
                exit
            }
        }
    ' "$config_path"
}
