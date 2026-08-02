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
# Parses one config file via `tmux source-file`, prints its @plugin declarations,
# and follows source-file directives into the files they resolve to.
# _TPM_PARSE_VISITED guards against duplicate and circular includes.
#
# Example `tmux source-file -nv` output line:
# /home/user/.tmux.conf:14: set -g @plugin 'schasse/tmux-jump'
#
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
    config_dir="$(dirname "$canonical")"

    local line cmd plugin args_str word path
    local -a args sourced_paths
    local seen

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Drop the "<path>:<lineno>: " prefix tmux prints with -v.
        [[ "$line" =~ ^(.+):[0-9]+:\ (.*)$ ]] || continue
        cmd="${BASH_REMATCH[2]}"

        # @plugin declarations: tmux normalises to "set-option", strips surrounding
        # quotes, re-quotes when values contain special chars like '#'
        if [[ "$cmd" =~ ^set-option\ -g\ @plugin\ (.+)$ ]]; then
            plugin="${BASH_REMATCH[1]}"
            # Strip quotes, if needed.
            [[ "$plugin" =~ ^\"(.*)\"$ ]] && plugin="${BASH_REMATCH[1]}"
            [[ -n "$plugin" ]] && printf '%s\n' "$plugin"
            continue
        fi

        # source-file directives: tmux normalises to "source-file". Repeat
        # `tmux source-file` parsing for all args to resolve globs, ~, relative
        # paths, and flags, then recurse into each matched file.
        if [[ "$cmd" =~ ^source-file\ (.+)$ ]]; then
            args_str="${BASH_REMATCH[1]}"
            args=()
            # Use xargs for word splitting to preserve quoted words
            # without expanding globs or running command substitutions
            while IFS= read -r word; do
                [[ -n "$word" ]] && args+=("$word")
            done < <(printf '%s\n' "$args_str" | xargs printf '%s\n')
            (( ${#args[@]} )) || continue

            sourced_paths=()
            seen=""
            # Run from the sourcing file's directory so relative paths resolve
            # the same way as tmux sourcing.
            while IFS= read -r path; do
                # Each printed command carries a "<path>:<lineno>: " prefix;
                # the path is the matched file we recurse into.
                [[ "$path" =~ ^(.+):[0-9]+:\ (.*)$ ]] || continue
                path="${BASH_REMATCH[1]}"

                # Skip over paths already seen
                [[ ":$seen:" == *":$path:"* ]] && continue
                
                seen="${seen:+$seen:}$path"
                sourced_paths+=("$path")
            done < <( ( cd "$config_dir" && tmux source-file -nqv "${args[@]}" ) 2>/dev/null )

            for path in "${sourced_paths[@]}"; do
                _parse_plugins_recursive "$path"
            done
        fi
    done < <(tmux source-file -nqv "$config_file" 2>/dev/null)
}

# Parse plugin declarations from a tmux config file.
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
