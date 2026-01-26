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

    # If it's already a full URL (starts with http:// https:// file:// or git@), return as-is
    if [[ "$plugin_spec" =~ ^(https?://|file://|git@) ]]; then
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

# Check if a string looks like a commit hash (7+ hex characters)
# Args:
#   $1 - string to check
# Returns:
#   0 if it looks like a commit hash, 1 otherwise
is_commit_hash() {
    local str="$1"
    # Commit hashes are typically 7+ hexadecimal characters
    # Check if it's all hex and at least 7 characters
    if [[ -n "$str" ]] && [[ "$str" =~ ^[0-9a-f]{7,}$ ]]; then
        return 0
    fi
    return 1
}

# Clone a plugin repository
# Args:
#   $1 - plugin specification
#   $2 - optional branch name, tag, or commit hash
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
    local clone_opts=(--recursive)
    local clone_result

    if [[ -n "$branch" ]]; then
        # Check if branch is actually a commit hash
        if is_commit_hash "$branch"; then
            # For commit hashes, clone without -b, then checkout the commit
            # We can't use --single-branch with commit hashes
            GIT_TERMINAL_PROMPT=0 git clone "${clone_opts[@]}" "$plugin_url" "$plugin_path" 2>&1
            clone_result=$?
            if [[ $clone_result -eq 0 ]]; then
                # Checkout the specific commit
                cd "$plugin_path" || return 1
                GIT_TERMINAL_PROMPT=0 git checkout "$branch" >/dev/null 2>&1
                clone_result=$?
            fi
            return $clone_result
        else
            # For branches/tags, use -b flag with --single-branch
            clone_opts+=(--single-branch -b "$branch")
        fi
    else
        # No branch specified, use --single-branch for efficiency
        clone_opts+=(--single-branch)
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
    local branch
    local current_ref
    local default_branch

    plugin_path="$(get_plugin_path "$plugin_spec")"

    if [[ ! -d "$plugin_path" ]]; then
        return 1
    fi

    if ! is_git_repo "$plugin_path"; then
        return 1
    fi

    cd "$plugin_path" || return 1

    # Get the branch/tag/commit from plugin spec
    branch="$(get_plugin_branch "$plugin_spec")"

    # Check if HEAD is detached (common when cloned with commit hash)
    current_ref="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
    if [[ "$current_ref" == "HEAD" ]]; then
        # HEAD is detached - need to checkout appropriate branch/commit first
        if [[ -n "$branch" ]]; then
            if is_commit_hash "$branch"; then
                # Specified commit hash - checkout that commit (no pull needed)
                GIT_TERMINAL_PROMPT=0 git checkout "$branch" >/dev/null 2>&1
                return $?
            else
                # Specified branch/tag - checkout that branch/tag, then pull
                GIT_TERMINAL_PROMPT=0 git checkout "$branch" >/dev/null 2>&1
                if [[ $? -ne 0 ]]; then
                    return 1
                fi
            fi
        else
            # No branch specified - checkout default branch (main or master)
            # Try to determine default branch from remote
            default_branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')"
            if [[ -z "$default_branch" ]]; then
                # Fallback: try main, then master
                if git show-ref --verify --quiet refs/remotes/origin/main; then
                    default_branch="main"
                elif git show-ref --verify --quiet refs/remotes/origin/master; then
                    default_branch="master"
                else
                    # Last resort: use whatever branch exists
                    default_branch="$(git branch -r | head -1 | sed 's@^origin/@@' | xargs)"
                fi
            fi
            if [[ -n "$default_branch" ]]; then
                GIT_TERMINAL_PROMPT=0 git checkout "$default_branch" >/dev/null 2>&1
                if [[ $? -ne 0 ]]; then
                    return 1
                fi
            fi
        fi
    elif [[ -n "$branch" ]] && ! is_commit_hash "$branch"; then
        # HEAD is not detached, but we have a branch/tag specified
        # Check if we're already on the right branch
        if [[ "$current_ref" != "$branch" ]]; then
            GIT_TERMINAL_PROMPT=0 git checkout "$branch" >/dev/null 2>&1
            if [[ $? -ne 0 ]]; then
                return 1
            fi
        fi
    fi

    # Pull latest changes
    GIT_TERMINAL_PROMPT=0 git pull --ff-only --recurse-submodules 2>&1
    return $?
}

# Get the current HEAD commit hash for a plugin (short format)
# Args:
#   $1 - plugin specification
# Returns:
#   Short commit hash (7 characters) or empty string on error
get_plugin_commit_hash() {
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
    git rev-parse --short HEAD 2>/dev/null
}

# Get all commits between two commit hashes
# Returns newline-separated list of commits, each line format: hash|message|time
# Args:
#   $1 - old commit hash (or empty for all commits up to new)
#   $2 - new commit hash
#   $3 - plugin path
get_plugin_commits_between() {
    local old_hash="$1"
    local new_hash="$2"
    local plugin_path="$3"
    local range

    if [[ ! -d "$plugin_path" ]]; then
        return 1
    fi

    if ! is_git_repo "$plugin_path"; then
        return 1
    fi

    cd "$plugin_path" || return 1

    # Build range for git log
    if [[ -z "$old_hash" ]]; then
        range="$new_hash"
    else
        # Use ^old_hash to exclude it and show commits after it
        range="${old_hash}..${new_hash}"
    fi

    # Get commits with hash, message, and relative time
    # Format: short_hash|message|relative_time
    git log --format="%h|%s|%ar" "$range" 2>/dev/null
}

# Format commit time as relative time (e.g., "2 hours ago")
# Args:
#   $1 - commit hash
#   $2 - plugin path
format_commit_time() {
    local commit_hash="$1"
    local plugin_path="$2"

    if [[ ! -d "$plugin_path" ]]; then
        return 1
    fi

    if ! is_git_repo "$plugin_path"; then
        return 1
    fi

    cd "$plugin_path" || return 1
    git log -1 --format="%ar" "$commit_hash" 2>/dev/null
}

# Get commit information (hash, message, time) for a single commit
# Args:
#   $1 - commit hash
#   $2 - plugin path
# Returns:
#   Format: hash|message|time
get_commit_info() {
    local commit_hash="$1"
    local plugin_path="$2"

    if [[ ! -d "$plugin_path" ]]; then
        return 1
    fi

    if ! is_git_repo "$plugin_path"; then
        return 1
    fi

    cd "$plugin_path" || return 1
    git log -1 --format="%h|%s|%ar" "$commit_hash" 2>/dev/null
}

