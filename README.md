# TPM Redux

> A lightweight, performant reimplementation of the Tmux Plugin Manager

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Overview

TPM Redux is a modern, performance-focused reimplementation of [TPM (Tmux Plugin Manager)](https://github.com/tmux-plugins/tpm) with 100% backwards compatibility. It maintains the same plugin format and API while adding parallel operations, better error handling, and plugin discovery features.

## Status

✅ **Alpha** - Core functionality is working and ready for testing!

## Features

### Current (v0.3)
- ✅ Plugin installation (`prefix + I`)
- ✅ Automatic plugin sourcing
- ✅ Config parsing (all TPM formats)
- ✅ Branch specification support
- ✅ XDG config path support
- ✅ 63 passing tests

### Coming Soon
- Plugin updates (`prefix + U`)
- Plugin cleanup (`prefix + Alt+u`)
- Parallel plugin operations
- Plugin search and discovery
- Lock file support

## Requirements

- tmux 1.9 or higher
- git
- bash

## Installation

### Quick Install

Clone TPM Redux to your tmux plugins directory:

```bash
git clone https://github.com/RyanMacG/tpm-redux.git ~/.tmux/plugins/tpm-redux
```

### Configure tmux

Add this to the **bottom** of `~/.tmux.conf` (or `~/.config/tmux/tmux.conf`):

```bash
# List your plugins
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-yank'

# Initialize TPM Redux (keep this line at the very bottom)
run '~/.tmux/plugins/tpm-redux/tpm'
```

### Activate

Reload tmux configuration:

```bash
# From inside tmux, press:
#   prefix + :
# Then type:
#   source ~/.tmux.conf

# Or from terminal:
tmux source ~/.tmux.conf
```

### Install Plugins

Inside tmux, press:
```
prefix + I
```

Your plugins will be cloned and loaded automatically!

## Usage

### Key Bindings

- `prefix + I` - **Install** new plugins and refresh tmux
- `prefix + U` - **Update** plugins (coming soon)
- `prefix + Alt + u` - **Clean** unused plugins (coming soon)

### Plugin Formats

TPM Redux supports all TPM plugin formats:

```bash
# GitHub shorthand
set -g @plugin 'tmux-plugins/tmux-sensible'

# GitHub shorthand with branch
set -g @plugin 'tmux-plugins/tmux-yank#v2.3.0'

# Full git URL
set -g @plugin 'https://github.com/tmux-plugins/tmux-sensible.git'

# SSH URL
set -g @plugin 'git@github.com:tmux-plugins/tmux-sensible.git'
```

### Example Configuration

```bash
# ~/.tmux.conf

# Basic settings
set -g mouse on
set -g default-terminal "screen-256color"

# Plugins
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'tmux-plugins/tmux-yank'
set -g @plugin 'tmux-plugins/tmux-resurrect'

# Plugin settings (if any)
set -g @resurrect-capture-pane-contents 'on'

# Initialize TPM Redux (keep at bottom!)
run '~/.tmux/plugins/tpm-redux/tpm'
```

### Manual Installation

You can also install plugins from the command line:

```bash
# Install all plugins from config
~/.tmux/plugins/tpm-redux/bin/install
```

## Troubleshooting

### Plugins not installing?

1. Check that git is installed: `git --version`
2. Check tmux version: `tmux -V` (must be 1.9+)
3. Verify TPM Redux is sourced in `.tmux.conf`
4. Try reloading tmux: `tmux source ~/.tmux.conf`
5. Check for errors: `tmux show-messages`

### Where are plugins installed?

By default: `~/.tmux/plugins/`

If using XDG config: `~/.config/tmux/plugins/`

### Manual installation not working?

Run the install command directly to see errors:

```bash
~/.tmux/plugins/tpm-redux/bin/install
```

### Still having issues?

Check the [tmux-plugins/tpm troubleshooting guide](https://github.com/tmux-plugins/tpm/blob/master/docs/tpm_not_working.md) - most solutions apply to TPM Redux too.

## Development

### Testing

We use [bats-core](https://github.com/bats-core/bats-core) for testing:

```bash
# Run all tests
./run_tests.sh

# Run specific test file
./run_tests.sh tests/core_test.bats
```

Current test coverage: **63 passing tests**

### Contributing

We follow TDD principles with all tests passing before committing. All contributions should:
- Include comprehensive tests
- Maintain 100% backwards compatibility with TPM
- Follow existing code style
- Update documentation as needed

See test files in `tests/` for examples.

## Compatibility

TPM Redux aims for 100% compatibility with TPM, supporting:
- All plugin name formats (`user/repo`, `user/repo#branch`, full Git URLs)
- Standard plugin directory structure (`~/.tmux/plugins/`)
- Plugin execution via `*.tmux` files
- XDG config paths
- Same environment variables and keybindings

## Migration from TPM

TPM Redux is designed as a drop-in replacement. Simply replace your TPM installation with TPM Redux - no configuration changes required.

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

Inspired by and compatible with [TPM](https://github.com/tmux-plugins/tpm) by Bruno Sutic and contributors.

