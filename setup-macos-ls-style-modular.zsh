#!/bin/zsh
# Compatibility wrapper for the old macOS-specific filename.

exec "${0:A:h}/setup-ls-style-modular.zsh" "$@"
