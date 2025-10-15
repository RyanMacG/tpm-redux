#!/usr/bin/env bash

# Test runner for TPM Redux
# Usage: ./run_tests.sh [test_file]

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BATS="${SCRIPT_DIR}/tests/bats/bin/bats"

if [[ ! -x "$BATS" ]]; then
    echo "Error: bats not found. Run 'git submodule update --init --recursive'" >&2
    exit 1
fi

if [[ $# -eq 0 ]]; then
    # Run all tests
    echo "Running all tests..."
    "$BATS" tests/*.bats
else
    # Run specific test file
    "$BATS" "$@"
fi

