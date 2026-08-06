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

# Internal recursive helper for parse_plugins
#
# Parses output of `tmux source-file`, prints @plugin declarations,
# and recursively follows source-file directives.
#
# _TPM_PARSE_VISITED (an associative array declared by parse_plugins) guards
# against duplicate and circular includes.
#
# Example `tmux source-file -nqv` output line:
# /home/user/.tmux.conf:14: set -g @plugin 'schasse/tmux-jump'
#
# Args:
#   $1 - raw source-file args: may include flags with one or more absolute, relative, or glob paths
#   $2 - optional config directory for resolving relative paths
_parse_plugins_recursive() {
    local source_args="$1"
    local config_dir="$2"

    [[ -z "$source_args" ]] && return 0

    local line cmd plugin next_source_args next_config_dir path file
    local -A prev_visited=() # snapshot of visited files from previous calls

    for file in "${!_TPM_PARSE_VISITED[@]}"; do
        prev_visited["$file"]=true
    done

    while IFS= read -r line || [[ -n "$line" ]]; do
        # match `path` and `cmd` from "<path>:<lineno>: <cmd>"
        [[ "$line" =~ ^(.+):[0-9]+:\ (.*)$ ]] || continue
        path="${BASH_REMATCH[1]}"
        cmd="${BASH_REMATCH[2]}"

        # Mark path as visited
        [[ -n "$path" && ! -v _TPM_PARSE_VISITED["$path"] ]] && _TPM_PARSE_VISITED["$path"]=true

        # Skip paths already visited in previous calls, but not this call, to ensure we finish the loop
        [[ -n "$path" && -v prev_visited["$path"] ]] && continue

        # @plugin declarations: tmux normalises `set` to `set-option`, strips
        # surrounding quotes, re-quotes when values contain special chars like '#'
        if [[ "$cmd" =~ ^set-option\ -g\ @plugin\ (.+)$ ]]; then
            plugin="${BASH_REMATCH[1]}"
            # Strip quotes, if needed.
            [[ "$plugin" =~ ^\"(.*)\"$ ]] && plugin="${BASH_REMATCH[1]}"
            [[ -n "$plugin" ]] && printf '%s\n' "$plugin"
            continue
        fi

        # source-file directives: tmux normalises `source` to `source-file`
        if [[ "$cmd" =~ ^source-file\ (.+)$ ]]; then
            next_source_args="${BASH_REMATCH[1]}"
            next_config_dir="$(dirname "$path")"

            _parse_plugins_recursive "$next_source_args" "$next_config_dir"
        fi

    # cd to config directory, if supplied, to resolve relative paths
    # Pass the raw $source_args value back to tmux source-file unquoted to expand args
    done < <( [[ -d "$config_dir" ]] && cd "$config_dir" || true; tmux source-file -nqv $source_args 2>/dev/null)
}

# Parse plugin declarations from tmux config files.
# Extracts all 'set -g @plugin' lines and returns plugin names, following
# source-file/source directives (including globs, ~, flags and nested
# includes) into the files they reference.
# Args:
#   $1 - path to tmux config file
parse_plugins() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        return 0
    fi

    local -A _TPM_PARSE_VISITED=()
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
