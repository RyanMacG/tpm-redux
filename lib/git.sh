#!/usr/bin/env bash

# Git operations library for TPM Redux
# Handles cloning, updating, and managing plugin repositories

# Source core library for path functions
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [[ -z "$TPM_REDUX_CORE_LOADED" ]]; then
    source "$SCRIPT_DIR/core.sh"
    TPM_REDUX_CORE_LOADED=1
fi

# Expand plugin specification to full Git URL
# Converts GitHub shorthand (user/repo) to full HTTPS URL
# Args:
#   $1 - plugin specification
expand_plugin_url() {
    local plugin_spec="$1"

    # Remove branch specification if present
    plugin_spec="${plugin_spec%%#*}"

    # If it's already a full URL (starts with http:// https:// or git@), return as-is
    if [[ "$plugin_spec" =~ ^(https?://|git@) ]]; then
        echo "$plugin_spec"
        return 0
    fi

    # Otherwise, assume GitHub shorthand and expand
    echo "https://github.com/${plugin_spec}"
}

# Check if a plugin is already installed
# Returns 0 if installed (has .git directory and remote), 1 otherwise
# Args:
#   $1 - plugin specification
plugin_already_installed() {
    local plugin_spec="$1"
    local plugin_path

    plugin_path="$(get_plugin_path "$plugin_spec")"

    # Check if directory exists and is a git repo with a remote
    if [[ -d "$plugin_path" ]]; then
        cd "$plugin_path" || return 1
        if git remote >/dev/null 2>&1; then
            return 0
        fi
    fi

    return 1
}

# Check if a directory is a git repository
# Args:
#   $1 - directory path
is_git_repo() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        return 1
    fi

    cd "$dir" || return 1
    if git rev-parse --git-dir >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Get the remote URL for an installed plugin
# Args:
#   $1 - plugin specification
get_plugin_remote_url() {
    local plugin_spec="$1"
    local plugin_path

    plugin_path="$(get_plugin_path "$plugin_spec")"

    if [[ ! -d "$plugin_path" ]]; then
        return 1
    fi

    cd "$plugin_path" || return 1
    git remote get-url origin 2>/dev/null
}

# Clone a plugin repository
# Args:
#   $1 - plugin specification
#   $2 - optional branch name
clone_plugin() {
    local plugin_spec="$1"
    local branch="$2"
    local plugin_url
    local plugin_path

    plugin_url="$(expand_plugin_url "$plugin_spec")"
    plugin_path="$(get_plugin_path "$plugin_spec")"

    # Ensure parent directory exists
    mkdir -p "$(dirname "$plugin_path")"

    # Clone with appropriate options
    local clone_opts=(--single-branch --recursive)

    if [[ -n "$branch" ]]; then
        clone_opts+=(-b "$branch")
    fi

    # Disable git terminal prompts for automation
    GIT_TERMINAL_PROMPT=0 git clone "${clone_opts[@]}" "$plugin_url" "$plugin_path" 2>&1
    return $?
}

# Update an installed plugin
# Args:
#   $1 - plugin specification
update_plugin() {
    local plugin_spec="$1"
    local plugin_path

    plugin_path="$(get_plugin_path "$plugin_spec")"

    if [[ ! -d "$plugin_path" ]]; then
        return 1
    fi

    if ! is_git_repo "$plugin_path"; then
        return 1
    fi

    cd "$plugin_path" || return 1

    # Pull latest changes
    GIT_TERMINAL_PROMPT=0 git pull --ff-only --recurse-submodules 2>&1
    return $?
}

