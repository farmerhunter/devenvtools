#!/bin/zsh
# setup-macos-ls-style-modular.zsh
#
# Cross-platform setup for modular ls/eza aliases and colors in zsh.
#
# It writes the actual configuration to:
#   ${LS_STYLE_MODULE_DIR:-$HOME/bin/zsh}/ls-style.zsh
#
# It adds a compact managed source block to:
#   ${LS_STYLE_ZSHRC:-$HOME/.zshrc}
#
# Usage:
#   chmod +x setup-macos-ls-style-modular.zsh
#   ./setup-macos-ls-style-modular.zsh
#
# Optional:
#   ./setup-macos-ls-style-modular.zsh --install
#   ./setup-macos-ls-style-modular.zsh --install --install-font
#   ./setup-macos-ls-style-modular.zsh --module-dir "$HOME/.config/zsh"
#   ./setup-macos-ls-style-modular.zsh --zshrc "$HOME/.zshrc"
#   ./setup-macos-ls-style-modular.zsh --no-icons
#   ./setup-macos-ls-style-modular.zsh --dry-run

set -euo pipefail

DRY_RUN=0
INSTALL=0
INSTALL_FONT=0
USE_ICONS=1
UNSET_LS_COLORS=0

ZSHRC="${LS_STYLE_ZSHRC:-${HOME}/.zshrc}"
MODULE_DIR="${LS_STYLE_MODULE_DIR:-${HOME}/bin/zsh}"
MODULE_NAME="ls-style.zsh"

BEGIN_MARKER="# >>> managed-zsh-module-ls-style >>>"
END_MARKER="# <<< managed-zsh-module-ls-style <<<"

log() {
  print -P "%F{cyan}[info]%f $*"
}

warn() {
  print -P "%F{yellow}[warn]%f $*" >&2
}

fail() {
  print -P "%F{red}[error]%f $*" >&2
  exit 1
}

usage() {
  cat <<EOF
Usage:
  $0 [options]

Options:
  --install              Install eza when a supported package manager is available.
  --install-font         Also install Hack Nerd Font on macOS with Homebrew.
  --no-install           Compatibility alias; installs are skipped by default.
  --module-dir DIR       Write the zsh module to DIR/ls-style.zsh.
  --zshrc FILE           Add/update the managed source block in FILE.
  --no-icons             Do not pass --icons to eza aliases.
  --unset-ls-colors      Unset LS_COLORS in the generated module.
  --dry-run              Show planned actions without modifying files or installing packages.
  -h, --help             Show this help.

Environment overrides:
  LS_STYLE_MODULE_DIR    Default module directory.
  LS_STYLE_ZSHRC         Default zsh startup file.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --install)
      INSTALL=1
      shift
      ;;
    --install-font)
      INSTALL=1
      INSTALL_FONT=1
      shift
      ;;
    --no-install)
      INSTALL=0
      INSTALL_FONT=0
      shift
      ;;
    --module-dir)
      [[ "$#" -ge 2 ]] || fail "--module-dir requires a directory."
      MODULE_DIR="$2"
      shift 2
      ;;
    --module-dir=*)
      MODULE_DIR="${1#--module-dir=}"
      shift
      ;;
    --zshrc)
      [[ "$#" -ge 2 ]] || fail "--zshrc requires a file."
      ZSHRC="$2"
      shift 2
      ;;
    --zshrc=*)
      ZSHRC="${1#--zshrc=}"
      shift
      ;;
    --no-icons)
      USE_ICONS=0
      shift
      ;;
    --unset-ls-colors)
      UNSET_LS_COLORS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
done

[[ -n "$MODULE_DIR" ]] || fail "Module directory cannot be empty."
[[ -n "$ZSHRC" ]] || fail "zshrc path cannot be empty."

MODULE_DIR="${MODULE_DIR:A}"
ZSHRC="${ZSHRC:A}"
MODULE_FILE="${MODULE_DIR}/${MODULE_NAME}"

OS="$(uname -s)"
case "$OS" in
  Darwin)
    PLATFORM="macos"
    ;;
  Linux)
    PLATFORM="linux"
    ;;
  *)
    PLATFORM="unknown"
    warn "Unsupported OS '$OS'. The module will still be written, but package installation is unavailable."
    ;;
esac

if [[ -z "${ZSH_VERSION:-}" ]]; then
  warn "This script is running outside zsh. It should still work, but it is intended for zsh."
fi

quote_zsh() {
  local value="$1"
  value="${value//\'/\'\\\'\'}"
  print -r -- "'${value}'"
}

SOURCE_BLOCK=$(cat <<EOF
$BEGIN_MARKER
[[ -f $(quote_zsh "$MODULE_FILE") ]] && source $(quote_zsh "$MODULE_FILE")
$END_MARKER
EOF
)

icon_flag() {
  if [[ "$USE_ICONS" -eq 1 ]]; then
    print -r -- "--icons "
  fi
}

generate_module_content() {
  local icons
  icons="$(icon_flag)"

  cat <<EOF
# ls-style.zsh
#
# Cross-platform directory listing setup for zsh.
# This file is intended to be sourced by a zsh startup file.
#
# Managed by setup-macos-ls-style-modular.zsh.

case "\$(uname -s)" in
  Darwin)
    # macOS/BSD ls color support.
    export CLICOLOR=1
    # BSD/macOS ls uses LSCOLORS, not LS_COLORS.
    export LSCOLORS=gxgxgxgxgxgxgxgxgxgxgx
    ;;
  Linux)
    # GNU ls color support.
    if command -v dircolors >/dev/null 2>&1; then
      eval "\$(dircolors -b)"
    fi
    ;;
esac

# eza uses EZA_COLORS for file and metadata colors.
# This palette avoids purple/magenta tones and keeps metadata grey.
export EZA_COLORS="di=38;5;111:ln=38;5;109:ex=38;5;114:da=38;5;245:ur=38;5;250:uw=38;5;246:ux=38;5;114:ue=38;5;245:gr=38;5;250:gw=38;5;246:gx=38;5;114:tr=38;5;250:tw=38;5;246:tx=38;5;114:sn=38;5;245:sb=38;5;245:uu=38;5;245:un=38;5;245:gu=38;5;245:gn=38;5;245:xx=38;5;244:lp=38;5;109:cc=38;5;244:bO=38;5;244:sp=38;5;244"
EOF

  if [[ "$UNSET_LS_COLORS" -eq 1 ]]; then
    cat <<'EOF'

# Optional isolation from inherited GNU ls palettes.
unset LS_COLORS
EOF
  fi

  cat <<EOF

if command -v eza >/dev/null 2>&1; then
  alias l='eza ${icons}--group-directories-first'
  alias ll='eza -lh ${icons}--group-directories-first --git --time-style=long-iso'
  alias la='eza -lah ${icons}--group-directories-first --git --time-style=long-iso'
  alias lt='eza -lh ${icons}--group-directories-first --git --sort=modified'
  alias tree='eza --tree ${icons}--group-directories-first'
  alias ldeep='eza --tree --level=3 ${icons}--group-directories-first --git'
else
  case "\$(uname -s)" in
    Darwin)
      alias l='ls -CF'
      alias ll='ls -lh'
      alias la='ls -lah'
      alias lt='ls -lht'
      ;;
    Linux)
      alias l='ls --color=auto -CF'
      alias ll='ls --color=auto -lh'
      alias la='ls --color=auto -lah'
      alias lt='ls --color=auto -lht'
      ;;
    *)
      alias l='ls -CF'
      alias ll='ls -lh'
      alias la='ls -lah'
      alias lt='ls -lht'
      ;;
  esac
fi
EOF
}

MODULE_CONTENT="$(generate_module_content)"

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

install_packages() {
  if [[ "$INSTALL" -eq 0 ]]; then
    log "Package installation skipped. Pass --install to install eza."
    return 0
  fi

  case "$PLATFORM" in
    macos)
      command -v brew >/dev/null 2>&1 || fail "Homebrew is not installed or not in PATH. Install it from https://brew.sh, or rerun without --install."

      if command -v eza >/dev/null 2>&1; then
        log "eza already installed: $(command -v eza)"
      else
        log "Installing eza with Homebrew..."
        run brew install eza
      fi

      if [[ "$INSTALL_FONT" -eq 1 ]]; then
        if brew list --cask font-hack-nerd-font >/dev/null 2>&1; then
          log "Hack Nerd Font cask already installed."
        else
          log "Installing Hack Nerd Font with Homebrew..."
          run brew install --cask font-hack-nerd-font
        fi
      fi
      ;;
    linux)
      if command -v eza >/dev/null 2>&1; then
        log "eza already installed: $(command -v eza)"
      elif command -v apt-get >/dev/null 2>&1; then
        log "Installing eza with apt-get..."
        if [[ "$DRY_RUN" -eq 1 ]]; then
          echo "[dry-run] sudo apt-get update"
          echo "[dry-run] sudo apt-get install -y eza"
        else
          sudo apt-get update
          sudo apt-get install -y eza
        fi
      elif command -v apt >/dev/null 2>&1; then
        log "Installing eza with apt..."
        if [[ "$DRY_RUN" -eq 1 ]]; then
          echo "[dry-run] sudo apt update"
          echo "[dry-run] sudo apt install -y eza"
        else
          sudo apt update
          sudo apt install -y eza
        fi
      else
        fail "No supported package manager found for automatic eza install. Install eza manually, or rerun without --install."
      fi

      if [[ "$INSTALL_FONT" -eq 1 ]]; then
        warn "--install-font is only automated on macOS. Install a Nerd Font manually on Linux if you keep icons enabled."
      fi
      ;;
    *)
      fail "Automatic package installation is not supported on OS '$OS'."
      ;;
  esac
}

backup_file_if_exists() {
  local file="$1"
  local backup

  if [[ -f "$file" && "$DRY_RUN" -eq 0 ]]; then
    backup="$(mktemp "${file}.bak.XXXXXXXXXX")"
    cp -p "$file" "$backup"
    log "Backed up $file to $backup"
  fi
}

validate_module_content() {
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/ls-style-module.XXXXXXXXXX")"
  print -r -- "$MODULE_CONTENT" > "$tmp"
  if ! zsh -n "$tmp"; then
    rm -f "$tmp"
    fail "Generated module content failed zsh syntax validation."
  fi
  rm -f "$tmp"
}

write_file_atomically() {
  local target="$1"
  local content="$2"
  local dir
  local tmp

  dir="${target:h}"
  mkdir -p "$dir"
  tmp="$(mktemp "${dir}/.${target:t}.tmp.XXXXXXXXXX")"
  print -r -- "$content" > "$tmp"
  mv "$tmp" "$target"
}

write_module() {
  log "Writing module file: $MODULE_FILE"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] mkdir -p $MODULE_DIR"
    echo "[dry-run] write $MODULE_FILE"
    return 0
  fi

  backup_file_if_exists "$MODULE_FILE"
  write_file_atomically "$MODULE_FILE" "$MODULE_CONTENT"
}

existing_source_regex() {
  local escaped
  escaped="${MODULE_FILE//\\/\\\\}"
  escaped="${escaped//./\\.}"
  escaped="${escaped//\//\\/}"
  print -r -- "^[[:space:]]*(source|\\.)[[:space:]]+['\"]?(${escaped}|\\\$HOME/${MODULE_FILE#${HOME}/}|~/${MODULE_FILE#${HOME}/})['\"]?[[:space:]]*$"
}

ensure_source_block() {
  local zshrc_dir
  local tmp

  zshrc_dir="${ZSHRC:h}"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    if [[ -f "$ZSHRC" ]]; then
      if grep -qF "$BEGIN_MARKER" "$ZSHRC" && grep -qF "$END_MARKER" "$ZSHRC"; then
        echo "[dry-run] would replace block between markers in $ZSHRC"
      else
        echo "[dry-run] would append managed source block to $ZSHRC"
      fi
    else
      echo "[dry-run] would create $ZSHRC and append managed source block"
    fi
    return 0
  fi

  mkdir -p "$zshrc_dir"
  if [[ ! -f "$ZSHRC" ]]; then
    log "$ZSHRC does not exist; it will be created."
    touch "$ZSHRC"
  fi

  tmp="$(mktemp "${zshrc_dir}/.${ZSHRC:t}.tmp.XXXXXXXXXX")"

  if grep -qF "$BEGIN_MARKER" "$ZSHRC" && grep -qF "$END_MARKER" "$ZSHRC"; then
    log "Updating existing ls-style source block in $ZSHRC"

    awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" -v block="$SOURCE_BLOCK" '
      BEGIN { in_block=0 }
      index($0, begin) { print block; in_block=1; next }
      index($0, end) { in_block=0; next }
      !in_block { print }
    ' "$ZSHRC" > "$tmp"
  elif grep -qF "$BEGIN_MARKER" "$ZSHRC" || grep -qF "$END_MARKER" "$ZSHRC"; then
    rm -f "$tmp"
    fail "$ZSHRC contains only one ls-style managed marker. Fix the broken block manually."
  else
    if grep -Eq "$(existing_source_regex)" "$ZSHRC"; then
      rm -f "$tmp"
      fail "$ZSHRC already appears to source $MODULE_FILE outside the managed block. Remove that line first."
    fi

    log "Appending compact ls-style source block to $ZSHRC"
    {
      cat "$ZSHRC"
      echo ""
      print -r -- "$SOURCE_BLOCK"
    } > "$tmp"
  fi

  zsh -n "$tmp" || {
    rm -f "$tmp"
    fail "Updated $ZSHRC content failed zsh syntax validation. No changes were written."
  }

  backup_file_if_exists "$ZSHRC"
  mv "$tmp" "$ZSHRC"
}

verify_aliases() {
  local verify_out
  local verify_err

  log "Verifying generated aliases are loadable..."
  verify_out="$(mktemp "${TMPDIR:-/tmp}/ls-style-verify-out.XXXXXXXXXX")"
  verify_err="$(mktemp "${TMPDIR:-/tmp}/ls-style-verify-err.XXXXXXXXXX")"

  if zsh -f -c "source $(quote_zsh "$MODULE_FILE"); alias ll >/dev/null && alias l >/dev/null && echo alias-check-ok" >"$verify_out" 2>"$verify_err"; then
    if grep -q "alias-check-ok" "$verify_out"; then
      log "Alias verification passed."
    else
      cat "$verify_out" >&2 || true
      rm -f "$verify_out" "$verify_err"
      fail "Alias verification did not return expected result."
    fi
  else
    cat "$verify_err" >&2 || true
    rm -f "$verify_out" "$verify_err"
    fail "Failed to source generated module or verify aliases."
  fi

  rm -f "$verify_out" "$verify_err"
}

install_packages

log "Validating generated module syntax..."
validate_module_content

write_module
ensure_source_block

if [[ "$DRY_RUN" -eq 0 ]]; then
  log "Validating written module syntax..."
  zsh -n "$MODULE_FILE" || fail "zsh syntax validation failed for $MODULE_FILE."

  log "Validating zsh startup file syntax..."
  zsh -n "$ZSHRC" || fail "zsh syntax validation failed for $ZSHRC."

  verify_aliases
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  RESULT="Dry run complete. No files were changed."
else
  RESULT="Installed modular ls/eza setup."
fi

cat <<EOF

$RESULT

Platform:
  $PLATFORM ($OS)

Module:
  $MODULE_FILE

Startup file:
  $ZSHRC

Managed source block:
  $SOURCE_BLOCK

Icons:
  $([[ "$USE_ICONS" -eq 1 ]] && echo "enabled" || echo "disabled")

Apply now:
  source $(quote_zsh "$ZSHRC")

Test:
  ll
  la
  tree
  ldeep

EOF

if [[ "$USE_ICONS" -eq 1 ]]; then
  warn "Icons require a Nerd Font in your terminal. Use --no-icons if you do not want that dependency."
fi

log "Done."
