# TPM Redux

> A lightweight, performant reimplementation of the Tmux Plugin Manager

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Overview

TPM Redux is a modern, performance-focused reimplementation of [TPM (Tmux Plugin Manager)](https://github.com/tmux-plugins/tpm) with 100% backwards compatibility. It maintains the same plugin format and API while providing a cleaner codebase, comprehensive test coverage, and a foundation for enhanced features.

### Why TPM Redux?

- 🚀 **Drop-in replacement** - Works with your existing `.tmux.conf`, no changes needed
- ✅ **Well-tested** - 84 tests covering all functionality
- 📦 **Modern codebase** - Clean, maintainable bash with proper error handling
- 🔄 **Active development** - Built with future enhancements in mind
- 📖 **Comprehensive docs** - Clear installation and usage instructions

## Status

🎉 **v1.0 - Stable** - Production ready with 100% TPM feature parity!

## Features

### Core Functionality
- ✅ **Plugin installation** - Install plugins with `prefix + I`
- ✅ **Plugin updates** - Update all plugins with `prefix + U`
- ✅ **Plugin cleanup** - Remove unused plugins with `prefix + Alt+u`
- ✅ **Automatic plugin sourcing** - Plugins load automatically on tmux start
- ✅ **All TPM config formats** - GitHub shorthand, full URLs, SSH, branches
- ✅ **XDG config support** - Works with both `~/.tmux.conf` and `~/.config/tmux/tmux.conf`
- ✅ **Branch specification** - Install specific versions with `user/repo#branch`
- ✅ **100% TPM compatible** - Drop-in replacement for existing TPM installations
- ✅ **84 passing tests** - Comprehensive test coverage

### Enhanced Features (Coming Soon)
- Parallel plugin operations for faster installs/updates
- Plugin search and discovery
- Lock file support for reproducible installations
- Enhanced error messages and diagnostics

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

All keybindings are fully functional:

- `prefix + I` - **Install** new plugins and refresh tmux
- `prefix + U` - **Update** all installed plugins
- `prefix + Alt + u` - **Clean** unused plugins (removes plugins not in config)

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

Current test coverage: **84 passing tests** (100% of implemented features)

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

TPM Redux is designed as a drop-in replacement for TPM. Migration is simple:

1. **Backup** (optional): `cp -r ~/.tmux/plugins/tpm ~/.tmux/plugins/tpm.backup`
2. **Replace**: `rm -rf ~/.tmux/plugins/tpm && git clone https://github.com/RyanMacG/tpm-redux.git ~/.tmux/plugins/tpm`
3. **Or run alongside**: Keep TPM as `tpm` and install TPM Redux as `tpm-redux`

No configuration changes needed - your existing `.tmux.conf` works as-is!

## Release Notes

### v1.0.0 (Current)
- ✅ Complete TPM feature parity
- ✅ All core commands implemented (install, update, clean)
- ✅ 84 comprehensive tests
- ✅ Full backwards compatibility
- ✅ Production ready

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

Inspired by and compatible with [TPM](https://github.com/tmux-plugins/tpm) by Bruno Sutic and contributors.

