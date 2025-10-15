# TPM Redux

> A lightweight, performant reimplementation of the Tmux Plugin Manager

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Overview

TPM Redux is a modern, performance-focused reimplementation of [TPM (Tmux Plugin Manager)](https://github.com/tmux-plugins/tpm) with 100% backwards compatibility. It maintains the same plugin format and API while adding parallel operations, better error handling, and plugin discovery features.

## Status

🚧 **Work in Progress** - This project is in active development.

## Goals

- **100% TPM Compatibility**: Drop-in replacement for existing TPM installations
- **Performance**: Parallel plugin operations and optimized parsing
- **Lightweight**: Minimal dependencies, efficient bash implementation
- **Enhanced Features**: Plugin search, lock files, better diagnostics
- **Well-Tested**: Comprehensive test suite with TDD methodology

## Features

### Current (v0.1)
- Project structure and testing framework

### Planned
- Core plugin management (install, update, clean)
- Parallel plugin operations
- Plugin search and discovery
- Lock file support for reproducible installations
- Improved error messages and diagnostics

## Installation

_Installation instructions coming soon_

## Usage

TPM Redux maintains the same usage as TPM:

```bash
# In ~/.tmux.conf
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'

# Initialize TPM Redux
run '~/.tmux/plugins/tpm-redux/tpm'
```

Key bindings:
- `prefix + I` - Install plugins
- `prefix + U` - Update plugins
- `prefix + alt + u` - Uninstall plugins not in config

## Development

### Testing

We use [bats-core](https://github.com/bats-core/bats-core) for testing:

```bash
# Run all tests
tests/bats/bin/bats tests/

# Run specific test file
tests/bats/bin/bats tests/core_test.bats
```

### Contributing

We follow a TDD (Test-Driven Development) approach:
1. Write failing tests (RED)
2. Implement minimal code to pass (GREEN)
3. Refactor and optimize (REFACTOR)

All contributions should include tests and maintain backwards compatibility with TPM.

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

