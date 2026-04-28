#!/bin/zsh
# setup-zsh-proxy-functions-modular.zsh
#
# Modular setup for proxy_on / proxy_off / proxy_status in zsh.
#
# It writes the actual functions to:
#   ~/bin/zsh/proxy.zsh
#
# It only adds a compact managed source block to the selected zsh rc file.
#
# Usage:
#   chmod +x setup-zsh-proxy-functions-modular.zsh
#   ./setup-zsh-proxy-functions-modular.zsh
#
# Optional:
#   ./setup-zsh-proxy-functions-modular.zsh --proxy http://127.0.0.1:15236
#   ./setup-zsh-proxy-functions-modular.zsh --test-url https://api.openai.com/v1/models
#   ./setup-zsh-proxy-functions-modular.zsh --timeout 10
#   ./setup-zsh-proxy-functions-modular.zsh --no-proxy localhost,127.0.0.1,::1
#   ./setup-zsh-proxy-functions-modular.zsh --rc-file ~/.zshrc
#   ./setup-zsh-proxy-functions-modular.zsh --module-file ~/bin/zsh/proxy.zsh
#   ./setup-zsh-proxy-functions-modular.zsh --dry-run
#   ./setup-zsh-proxy-functions-modular.zsh --force

set -euo pipefail

ZSHRC="${HOME}/.zshrc"
MODULE_FILE="${HOME}/bin/zsh/proxy.zsh"

DEFAULT_PROXY_SERVER="http://127.0.0.1:15236"
DEFAULT_TEST_URL="https://api.openai.com/v1/models"
DEFAULT_TIMEOUT=10
DEFAULT_NO_PROXY="localhost,127.0.0.1,::1"

PROXY_SERVER="$DEFAULT_PROXY_SERVER"
TEST_URL="$DEFAULT_TEST_URL"
TIMEOUT="$DEFAULT_TIMEOUT"
NO_PROXY_VALUE="$DEFAULT_NO_PROXY"
DRY_RUN=0
FORCE=0

BEGIN_MARKER="# >>> managed-zsh-module-proxy >>>"
END_MARKER="# <<< managed-zsh-module-proxy <<<"

SOURCE_BLOCK=$(cat <<'EOF'
# >>> managed-zsh-module-proxy >>>
[[ -f __MODULE_FILE_QUOTED__ ]] && source __MODULE_FILE_QUOTED__
# <<< managed-zsh-module-proxy <<<
EOF
)

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
  --proxy URL       Proxy server URL. Default: $DEFAULT_PROXY_SERVER
  --test-url URL    URL used to test proxy reachability. Default: $DEFAULT_TEST_URL
  --timeout SEC     curl timeout in seconds. Default: $DEFAULT_TIMEOUT
  --no-proxy LIST   Comma-separated no_proxy list. Default: $DEFAULT_NO_PROXY
  --rc-file PATH    zsh startup file to update. Default: $ZSHRC
  --module-file PATH
                   Module file to write. Default: $MODULE_FILE
  --dry-run         Show planned actions without modifying files.
  --force           Continue even if unmanaged proxy functions are detected in the rc file.
  -h, --help        Show help.

Example:
  $0 --proxy http://127.0.0.1:7897 --test-url https://api.openai.com/v1/models
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --proxy)
      shift
      [[ $# -gt 0 ]] || fail "--proxy requires a URL argument."
      PROXY_SERVER="$1"
      ;;
    --test-url)
      shift
      [[ $# -gt 0 ]] || fail "--test-url requires a URL argument."
      TEST_URL="$1"
      ;;
    --timeout)
      shift
      [[ $# -gt 0 ]] || fail "--timeout requires a seconds argument."
      TIMEOUT="$1"
      ;;
    --no-proxy)
      shift
      [[ $# -gt 0 ]] || fail "--no-proxy requires a comma-separated list."
      NO_PROXY_VALUE="$1"
      ;;
    --rc-file)
      shift
      [[ $# -gt 0 ]] || fail "--rc-file requires a path argument."
      ZSHRC="${~1}"
      ;;
    --module-file)
      shift
      [[ $# -gt 0 ]] || fail "--module-file requires a path argument."
      MODULE_FILE="${~1}"
      ;;
    --dry-run)
      DRY_RUN=1
      ;;
    --force)
      FORCE=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "Unknown argument: $1"
      ;;
  esac
  shift
done

if ! command -v zsh >/dev/null 2>&1; then
  fail "zsh not found."
fi

if ! command -v curl >/dev/null 2>&1; then
  fail "curl not found."
fi

if [[ "$PROXY_SERVER" != http://* && "$PROXY_SERVER" != https://* && "$PROXY_SERVER" != socks5://* && "$PROXY_SERVER" != socks5h://* ]]; then
  fail "Proxy URL should start with http://, https://, socks5://, or socks5h://. Got: $PROXY_SERVER"
fi

if [[ "$TEST_URL" != http://* && "$TEST_URL" != https://* ]]; then
  fail "Test URL should start with http:// or https://. Got: $TEST_URL"
fi

if ! [[ "$TIMEOUT" =~ '^[1-9][0-9]*$' ]]; then
  fail "Timeout must be a positive integer. Got: $TIMEOUT"
fi

MODULE_DIR="${MODULE_FILE:h}"
quoted_module_file="${(qqq)MODULE_FILE}"
SOURCE_BLOCK="${SOURCE_BLOCK//__MODULE_FILE_QUOTED__/$quoted_module_file}"

quoted_proxy_server="${(qqq)PROXY_SERVER}"
quoted_test_url="${(qqq)TEST_URL}"
quoted_timeout="${(qqq)TIMEOUT}"
quoted_no_proxy="${(qqq)NO_PROXY_VALUE}"

MODULE_CONTENT=$(cat <<EOF
# proxy.zsh
#
# Proxy helper functions for zsh.
# This file is intended to be sourced by ~/.zshrc.
#
# Managed by setup-zsh-proxy-functions-modular.zsh.

typeset -g DEFAULT_PROXY_SERVER=$quoted_proxy_server
typeset -g DEFAULT_PROXY_TEST_URL=$quoted_test_url
typeset -g DEFAULT_PROXY_TIMEOUT=$quoted_timeout
typeset -g DEFAULT_NO_PROXY=$quoted_no_proxy

proxy_on() {
  local proxy_server="\${1:-\$DEFAULT_PROXY_SERVER}"
  local test_url="\${2:-\$DEFAULT_PROXY_TEST_URL}"
  local timeout="\${3:-\$DEFAULT_PROXY_TIMEOUT}"
  local http_code
  local curl_rc

  if [[ -z "\$proxy_server" ]]; then
    echo "proxy_on: proxy server is empty." >&2
    return 2
  fi

  if ! [[ "\$timeout" =~ '^[1-9][0-9]*$' ]]; then
    echo "proxy_on: timeout must be a positive integer; got '\$timeout'." >&2
    return 2
  fi

  echo "Testing proxy: \$proxy_server"
  echo "Test URL: \$test_url"

  http_code=\$(curl -x "\$proxy_server" \\
                   --max-time "\$timeout" \\
                   --silent \\
                   --output /dev/null \\
                   --write-out "%{http_code}" \\
                   "\$test_url")
  curl_rc=\$?

  echo "curl_exit=\$curl_rc http_code=\$http_code"

  if [[ \$curl_rc -ne 0 ]]; then
    echo "proxy_on: proxy test failed; environment variables were not changed." >&2
    return \$curl_rc
  fi

  if [[ "\$http_code" == "000" ]]; then
    echo "proxy_on: proxy test returned HTTP 000; environment variables were not changed." >&2
    return 1
  fi

  export HTTP_PROXY="\$proxy_server"
  export HTTPS_PROXY="\$proxy_server"
  export ALL_PROXY="\$proxy_server"
  export http_proxy="\$proxy_server"
  export https_proxy="\$proxy_server"
  export all_proxy="\$proxy_server"

  if [[ -n "\${DEFAULT_NO_PROXY:-}" ]]; then
    export NO_PROXY="\$DEFAULT_NO_PROXY"
    export no_proxy="\$DEFAULT_NO_PROXY"
  fi

  echo "Proxy enabled: \$proxy_server"
}

proxy_off() {
  unset HTTP_PROXY HTTPS_PROXY ALL_PROXY
  unset http_proxy https_proxy all_proxy
  unset NO_PROXY no_proxy
  echo "Proxy disabled for current shell session."
}

proxy_status() {
  echo "HTTP_PROXY=\${HTTP_PROXY:-}"
  echo "HTTPS_PROXY=\${HTTPS_PROXY:-}"
  echo "ALL_PROXY=\${ALL_PROXY:-}"
  echo "http_proxy=\${http_proxy:-}"
  echo "https_proxy=\${https_proxy:-}"
  echo "all_proxy=\${all_proxy:-}"
  echo "NO_PROXY=\${NO_PROXY:-}"
  echo "no_proxy=\${no_proxy:-}"
}

proxy_test() {
  local proxy_server="\${1:-\$DEFAULT_PROXY_SERVER}"
  local test_url="\${2:-\$DEFAULT_PROXY_TEST_URL}"
  local timeout="\${3:-\$DEFAULT_PROXY_TIMEOUT}"
  local http_code
  local curl_rc

  if ! [[ "\$timeout" =~ '^[1-9][0-9]*$' ]]; then
    echo "proxy_test: timeout must be a positive integer; got '\$timeout'." >&2
    return 2
  fi

  http_code=\$(curl -x "\$proxy_server" \\
                   --max-time "\$timeout" \\
                   --silent \\
                   --show-error \\
                   --output /dev/null \\
                   --write-out "%{http_code}" \\
                   "\$test_url")
  curl_rc=\$?

  echo "curl_exit=\$curl_rc http_code=\$http_code"
  return \$curl_rc
}
EOF
)

backup_file_if_exists() {
  local file="$1"
  if [[ -f "$file" && "$DRY_RUN" -eq 0 ]]; then
    cp "$file" "${file}.bak.$(date +%Y%m%d-%H%M%S)"
  fi
}

file_mode_or_default() {
  local file="$1"
  local default_mode="$2"
  local mode

  mode="$(stat -f "%Lp" "$file" 2>/dev/null || stat -c "%a" "$file" 2>/dev/null || true)"
  if [[ -n "$mode" ]]; then
    print -r -- "$mode"
  else
    print -r -- "$default_mode"
  fi
}

detect_unmanaged_duplicates() {
  if [[ ! -f "$ZSHRC" ]]; then
    return 0
  fi

  local cleaned_content duplicates
  cleaned_content="$(awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
    index($0, begin) { in_block=1; next }
    index($0, end) { in_block=0; next }
    !in_block { print }
  ' "$ZSHRC")"

  duplicates="$(print -r -- "$cleaned_content" | grep -En '(^|[[:space:]])(function[[:space:]]+)?proxy_(on|off|status)[[:space:]]*(\(\))?[[:space:]]*\{|^alias[[:space:]]+proxy_(on|off|status)=' || true)"

  if [[ -n "$duplicates" && "$FORCE" -eq 0 ]]; then
    cat >&2 <<EOF
[error] Unmanaged proxy function or alias definitions were found in $ZSHRC:

$duplicates

This modular installer keeps ~/.zshrc clean by sourcing:
  $MODULE_FILE

Recommended:
  1. Remove old proxy_on/proxy_off/proxy_status definitions from ~/.zshrc, then rerun.
  2. Or rerun with --force if you intentionally want to leave old definitions in place.

EOF
    exit 1
  fi
}

write_module() {
  log "Writing module file: $MODULE_FILE"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] mkdir -p $MODULE_DIR"
    echo "[dry-run] write $MODULE_FILE"
    return 0
  fi

  mkdir -p "$MODULE_DIR"
  local mode
  mode="$(file_mode_or_default "$MODULE_FILE" "644")"
  backup_file_if_exists "$MODULE_FILE"

  local tmp
  tmp="$(mktemp "${MODULE_DIR}/proxy.zsh.tmp.XXXXXX")"
  print -r -- "$MODULE_CONTENT" > "$tmp"
  zsh -n "$tmp" || {
    rm -f "$tmp"
    fail "Generated module failed zsh syntax validation."
  }
  chmod "$mode" "$tmp"
  mv "$tmp" "$MODULE_FILE"
}

ensure_source_block() {
  local tmp
  local mode
  mode="$(file_mode_or_default "$ZSHRC" "644")"
  tmp="$(mktemp)"

  if [[ ! -f "$ZSHRC" ]]; then
    log "$ZSHRC does not exist; it will be created."
    if [[ "$DRY_RUN" -eq 0 ]]; then
      touch "$ZSHRC"
    fi
  fi

  if grep -qF "$BEGIN_MARKER" "$ZSHRC" && grep -qF "$END_MARKER" "$ZSHRC"; then
    log "Updating existing proxy source block in $ZSHRC"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "[dry-run] would replace block between markers in $ZSHRC"
      return 0
    fi

    backup_file_if_exists "$ZSHRC"

    {
      local in_block=0
      local line
      while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "$BEGIN_MARKER" ]]; then
          print -r -- "$SOURCE_BLOCK"
          in_block=1
          continue
        fi
        if [[ "$line" == "$END_MARKER" ]]; then
          in_block=0
          continue
        fi
        if [[ "$in_block" -eq 0 ]]; then
          print -r -- "$line"
        fi
      done < "$ZSHRC"
    } > "$tmp"
    zsh -n "$tmp" || {
      rm -f "$tmp"
      fail "Updated $ZSHRC would fail zsh syntax validation."
    }
    chmod "$mode" "$tmp"
    mv "$tmp" "$ZSHRC"

  elif grep -qF "$BEGIN_MARKER" "$ZSHRC" || grep -qF "$END_MARKER" "$ZSHRC"; then
    fail "$ZSHRC contains only one proxy managed marker. Fix the broken block manually."

  else
    # Avoid duplicating an identical unmanaged source line.
    if grep -qF "$MODULE_FILE" "$ZSHRC" || grep -qF 'source "$HOME/bin/zsh/proxy.zsh"' "$ZSHRC" || grep -qF "source '$HOME/bin/zsh/proxy.zsh'" "$ZSHRC" || grep -qF 'source ~/bin/zsh/proxy.zsh' "$ZSHRC"; then
      warn "An unmanaged proxy source line may already exist in $ZSHRC."
      fail "Remove the old proxy source line or rerun after cleaning ~/.zshrc."
    fi

    log "Appending compact proxy source block to $ZSHRC"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "[dry-run] would append managed proxy source block to $ZSHRC"
      return 0
    fi

    backup_file_if_exists "$ZSHRC"

    {
      cat "$ZSHRC"
      echo ""
      echo "$SOURCE_BLOCK"
    } > "$tmp"
    zsh -n "$tmp" || {
      rm -f "$tmp"
      fail "Updated $ZSHRC would fail zsh syntax validation."
    }
    chmod "$mode" "$tmp"
    mv "$tmp" "$ZSHRC"
  fi

  rm -f "$tmp" 2>/dev/null || true
}

detect_unmanaged_duplicates
write_module
ensure_source_block

if [[ "$DRY_RUN" -eq 0 ]]; then
  log "Validating module syntax..."
  zsh -n "$MODULE_FILE" || fail "zsh syntax validation failed for $MODULE_FILE."

  log "Validating ~/.zshrc syntax..."
  zsh -n "$ZSHRC" || fail "zsh syntax validation failed for $ZSHRC."

  log "Verifying functions are loadable from module..."
  VERIFY_OUT="$(mktemp)"
  VERIFY_ERR="$(mktemp)"

  if zsh -fc "source ${(qqq)MODULE_FILE}; whence -w proxy_on proxy_off proxy_status proxy_test" >"$VERIFY_OUT" 2>"$VERIFY_ERR"; then
    if grep -q "proxy_on: function" "$VERIFY_OUT" && \
       grep -q "proxy_off: function" "$VERIFY_OUT" && \
       grep -q "proxy_status: function" "$VERIFY_OUT" && \
       grep -q "proxy_test: function" "$VERIFY_OUT"; then
      log "Function verification passed."
    else
      cat "$VERIFY_OUT" >&2 || true
      fail "Function verification did not find expected functions."
    fi
  else
    cat "$VERIFY_ERR" >&2 || true
    fail "Could not load proxy functions from ~/.zshrc."
  fi

  rm -f "$VERIFY_OUT" "$VERIFY_ERR"
fi

cat <<EOF

Installed modular proxy setup.

Module:
  $MODULE_FILE

.zshrc only contains:
  $SOURCE_BLOCK

Apply now:
  source ~/.zshrc

Use:
  proxy_on
  proxy_off
  proxy_status
  proxy_test

Override proxy or test URL ad hoc:
  proxy_on http://127.0.0.1:7897 https://api.openai.com/v1/models 10
  proxy_test http://127.0.0.1:7897 https://api.openai.com/v1/models 10

Current defaults:
  DEFAULT_PROXY_SERVER=$PROXY_SERVER
  DEFAULT_PROXY_TEST_URL=$TEST_URL
  DEFAULT_PROXY_TIMEOUT=$TIMEOUT
  DEFAULT_NO_PROXY=$NO_PROXY_VALUE

EOF

log "Done."
