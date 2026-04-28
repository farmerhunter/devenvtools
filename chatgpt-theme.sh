#!/bin/bash
# chatgpt-theme.sh
#
# Control ChatGPT for macOS appearance behavior.
#
# Usage:
#   ./chatgpt-theme.sh light                 # Force ChatGPT to always use Aqua/light appearance
#   ./chatgpt-theme.sh reset                 # Remove override; ChatGPT follows macOS system appearance
#   ./chatgpt-theme.sh status                # Show current ChatGPT override and macOS appearance
#   ./chatgpt-theme.sh auto                  # Choose light/dark based on local clock, then launch ChatGPT
#   ./chatgpt-theme.sh auto --light 7 --dark 19
#                                             # Light from 07:00 inclusive, dark from 19:00 inclusive
#
# Notes:
# - This script uses the Mac's local clock via `date +%H`.
# - It does not use IP geolocation, VPN location, or sunrise/sunset.
# - `light` forces Aqua only for ChatGPT using NSRequiresAquaSystemAppearance.
# - `auto` uses:
#     daytime  -> force ChatGPT light
#     nighttime -> remove override, so ChatGPT follows macOS system appearance
#   If your macOS itself is dark at night, this gives the expected behavior.
#
# Default auto window:
#   light from 07:00 through 18:59
#   reset/follow-system from 19:00 through 06:59

set -euo pipefail

APP_ID="com.openai.chat"
APP_NAME="ChatGPT"

DEFAULT_LIGHT_HOUR=7
DEFAULT_DARK_HOUR=19

restart_app() {
  if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    osascript -e "quit app \"$APP_NAME\"" >/dev/null 2>&1 || true
    sleep 1
  fi

  open -a "$APP_NAME"
}

force_light_no_restart() {
  defaults write "$APP_ID" NSRequiresAquaSystemAppearance -bool true
}

reset_no_restart() {
  defaults delete "$APP_ID" NSRequiresAquaSystemAppearance >/dev/null 2>&1 || true
}

force_light() {
  echo "Setting $APP_NAME to ALWAYS LIGHT / Aqua appearance..."
  force_light_no_restart
  restart_app
  echo "Done."
}

reset_default() {
  echo "Restoring $APP_NAME to FOLLOW SYSTEM appearance..."
  reset_no_restart
  restart_app
  echo "Done."
}

macos_current_theme() {
  if defaults read -g AppleInterfaceStyle >/dev/null 2>&1; then
    echo "dark"
  else
    echo "light"
  fi
}

macos_auto_policy() {
  local auto_value
  auto_value="$(defaults read -g AppleInterfaceStyleSwitchesAutomatically 2>/dev/null || true)"

  if [[ "$auto_value" == "1" ]]; then
    echo "auto"
  else
    echo "manual"
  fi
}

chatgpt_override_status() {
  local value
  value="$(defaults read "$APP_ID" NSRequiresAquaSystemAppearance 2>/dev/null || true)"

  if [[ "$value" == "1" ]]; then
    echo "forced-light"
  else
    echo "follow-system"
  fi
}

status() {
  echo "ChatGPT override: $(chatgpt_override_status)"
  echo "macOS current theme: $(macos_current_theme)"
  echo "macOS appearance policy: $(macos_auto_policy)"
  echo "Local time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
}

usage() {
  cat <<EOF
Usage:
  $0 light
      Force ChatGPT to always use Aqua/light appearance.

  $0 reset
      Remove ChatGPT appearance override and follow macOS system appearance.

  $0 status
      Show ChatGPT override, current macOS theme, macOS auto/manual policy, and local time.

  $0 auto [--light HOUR] [--dark HOUR]
      Select ChatGPT appearance based on the Mac's local clock.

      Default:
        --light $DEFAULT_LIGHT_HOUR
        --dark  $DEFAULT_DARK_HOUR

      Example:
        $0 auto --light 7 --dark 19

      Behavior:
        If local hour is within [light, dark), ChatGPT is forced to light.
        Otherwise the override is removed, so ChatGPT follows system appearance.

EOF
}

validate_hour() {
  local name="$1"
  local value="$2"

  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
    echo "Error: $name must be an integer from 0 to 23; got '$value'." >&2
    exit 2
  fi

  if (( value < 0 || value > 23 )); then
    echo "Error: $name must be from 0 to 23; got '$value'." >&2
    exit 2
  fi
}

is_daytime() {
  local hour="$1"
  local light_hour="$2"
  local dark_hour="$3"

  if (( light_hour == dark_hour )); then
    echo "Error: --light and --dark cannot be the same hour." >&2
    exit 2
  fi

  if (( light_hour < dark_hour )); then
    # Normal same-day window, e.g. light=7 dark=19 means 07:00-18:59.
    (( hour >= light_hour && hour < dark_hour ))
  else
    # Wrapped window, e.g. light=22 dark=6 means 22:00-05:59.
    (( hour >= light_hour || hour < dark_hour ))
  fi
}

auto_mode() {
  local light_hour="$DEFAULT_LIGHT_HOUR"
  local dark_hour="$DEFAULT_DARK_HOUR"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --light)
        shift
        [[ $# -gt 0 ]] || { echo "Error: --light requires an hour." >&2; exit 2; }
        light_hour="$1"
        ;;
      --dark)
        shift
        [[ $# -gt 0 ]] || { echo "Error: --dark requires an hour." >&2; exit 2; }
        dark_hour="$1"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Error: unknown argument for auto mode: $1" >&2
        usage
        exit 2
        ;;
    esac
    shift
  done

  validate_hour "--light" "$light_hour"
  validate_hour "--dark" "$dark_hour"

  local current_hour
  current_hour="$(date +%H)"
  # Strip possible leading zero for arithmetic.
  current_hour=$((10#$current_hour))

  echo "Local time: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  echo "Auto rule: light from ${light_hour}:00 inclusive; dark/follow-system from ${dark_hour}:00 inclusive."

  if is_daytime "$current_hour" "$light_hour" "$dark_hour"; then
    echo "Current local hour $current_hour is inside the light window."
    echo "Forcing $APP_NAME to light/Aqua appearance..."
    force_light_no_restart
  else
    echo "Current local hour $current_hour is outside the light window."
    echo "Removing $APP_NAME override so it follows macOS system appearance..."
    reset_no_restart
  fi

  restart_app
  echo "Done."
}

main() {
  case "${1:-}" in
    light)
      force_light
      ;;
    reset|undo)
      reset_default
      ;;
    status)
      status
      ;;
    auto)
      shift
      auto_mode "$@"
      ;;
    -h|--help|"")
      usage
      ;;
    *)
      echo "Error: unknown command: $1" >&2
      usage
      exit 2
      ;;
  esac
}

main "$@"
