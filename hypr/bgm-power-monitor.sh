#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLAYER_BIN="${PLAYER_BIN:-mpv}"
SOCKET="${XDG_RUNTIME_DIR:-/tmp}/bgm-mpv.sock"
PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/bgm-mpv.pid"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/bgm-state"
OVERRIDE_FILE="$STATE_DIR/override"
LOG_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/bgm-power-monitor.log"
FADE_SECONDS="${BGM_FADE_SECONDS:-3}"
HOTKEY_FADE_SECONDS="${BGM_HOTKEY_FADE_SECONDS:-1}"
SKIP_FADE_SECONDS="${BGM_SKIP_FADE_SECONDS:-0.5}"
VOLUME="${BGM_VOLUME:-50}"
POLL_SECONDS="${BGM_POLL_SECONDS:-5}"
LOCK_DIR="${XDG_RUNTIME_DIR:-/tmp}/bgm-monitor.lock"
CAVA_LAUNCHER="$SCRIPT_DIR/launch-cava-bg.sh"

start_visualizer() {
  if [ -x "$CAVA_LAUNCHER" ]; then
    "$CAVA_LAUNCHER" >/dev/null 2>&1 &
  fi
}

stop_visualizer() {
  pkill -f 'kitty.*kitten panel .*cava-bg' >/dev/null 2>&1 || true
  pkill -f 'cava -p .*/config-bg' >/dev/null 2>&1 || true
}

log() {
  printf '%s %s\n' "$(date '+%F %T')" "$1" >> "$LOG_FILE"
}

mkdir -p "$STATE_DIR"

ac_online() {
  local power_supply
  for power_supply in /sys/class/power_supply/*; do
    [ -d "$power_supply" ] || continue
    case "$(cat "$power_supply/type" 2>/dev/null || true)" in
      Mains|USB|USB_C)
        if [ "$(cat "$power_supply/online" 2>/dev/null || echo 0)" = "1" ]; then
          return 0
        fi
        ;;
    esac
  done
  return 1
}

player_running() {
  local pid

  if [ ! -f "$PID_FILE" ]; then
    return 1
  fi

  pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
    rm -f "$PID_FILE" "$SOCKET"
    return 1
  fi

  if ps -p "$pid" -o comm= 2>/dev/null | grep -qx "$PLAYER_BIN"; then
    return 0
  fi

  rm -f "$PID_FILE" "$SOCKET"
  return 1
}

cleanup_duplicate_players() {
  local current_pid pid

  current_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
  pids="$(pgrep -x "$PLAYER_BIN" 2>/dev/null || true)"

  [ -n "$pids" ] || return 0

  while IFS= read -r pid; do
    [ -n "$pid" ] || continue
    if [ -n "$current_pid" ] && [ "$pid" = "$current_pid" ]; then
      continue
    fi
    kill "$pid" 2>/dev/null || true
    log "killed duplicate $PLAYER_BIN process $pid"
  done <<EOF
$pids
EOF
}

send_mpv() {
  printf '%s\n' "$1" | socat - UNIX-CONNECT:"$SOCKET" >/dev/null 2>&1
}

start_player() {
  local playlist

  cleanup_duplicate_players
  if player_running; then
    fade_to "$VOLUME"
    return 0
  fi

  playlist="$(BGM_FORCE_RESHUFFLE=1 "$SCRIPT_DIR/bgm-current-playlist.sh")"
  rm -f "$SOCKET" "$PID_FILE"
  nohup "$PLAYER_BIN" \
    --no-video \
    --idle=yes \
    --loop-playlist=inf \
    --volume=0 \
    --input-ipc-server="$SOCKET" \
    --playlist="$playlist" \
    >/dev/null 2>&1 &
  echo "$!" > "$PID_FILE"
  sleep 1
  fade_to "$VOLUME"
  start_visualizer
  log "started player on AC using $playlist"
}

fade_to() {
  local target="$1"
  local fade_seconds="${2:-$FADE_SECONDS}"
  local current step delay next
  if ! player_running; then
    return 1
  fi

  current="$(printf '{"command":["get_property","volume"]}\n' | socat - UNIX-CONNECT:"$SOCKET" 2>/dev/null | sed -n 's/.*"data"[[:space:]]*:[[:space:]]*\([0-9.]*\).*/\1/p' | head -n 1)"
  current="${current%%.*}"
  current="${current:-0}"

  if [ "$current" -eq "$target" ]; then
    return 0
  fi

  if [ "$current" -lt "$target" ]; then
    step=1
  else
    step=-1
  fi

  delay="$(awk -v secs="$fade_seconds" -v diff="$(( target - current ))" 'BEGIN { d = diff < 0 ? -diff : diff; if (d < 1) d = 1; printf "%.3f", secs / d }')"

  next="$current"
  while [ "$next" -ne "$target" ]; do
    next=$((next + step))
    send_mpv "{\"command\":[\"set_property\",\"volume\",$next]}"
    sleep "$delay"
  done
}

stop_player() {
  if ! player_running; then
    rm -f "$SOCKET" "$PID_FILE"
    stop_visualizer
    return 0
  fi
  fade_to 0 || true
  send_mpv '{"command":["quit"]}' || true
  sleep 1
  rm -f "$SOCKET" "$PID_FILE"
  stop_visualizer
  log "stopped player on battery"
}

desired_mode() {
  local override

  if [ -f "$OVERRIDE_FILE" ]; then
    override="$(cat "$OVERRIDE_FILE" 2>/dev/null || true)"
    if [ "$override" = "on" ] || [ "$override" = "off" ]; then
      printf '%s\n' "$override"
      return 0
    fi
    rm -f "$OVERRIDE_FILE"
  fi

  if ac_online; then
    printf 'on\n'
  else
    printf 'off\n'
  fi
}

toggle_override() {
  local current
  current="$(desired_mode)"

  if [ "$current" = "on" ]; then
    printf 'off\n' > "$OVERRIDE_FILE"
    fade_to 0 "$HOTKEY_FADE_SECONDS" || true
    stop_player_fast
    log "manual override set to off"
  else
    printf 'on\n' > "$OVERRIDE_FILE"
    if ! player_running; then
      start_player
      fade_to "$VOLUME" "$HOTKEY_FADE_SECONDS" || true
    else
      fade_to "$VOLUME" "$HOTKEY_FADE_SECONDS" || true
    fi
    log "manual override set to on"
  fi
}

stop_player_fast() {
  if ! player_running; then
    rm -f "$SOCKET" "$PID_FILE"
    stop_visualizer
    return 0
  fi
  send_mpv '{"command":["quit"]}' || true
  sleep 1
  rm -f "$SOCKET" "$PID_FILE"
  stop_visualizer
}

clear_override() {
  rm -f "$OVERRIDE_FILE"
}

skip_track() {
  if ! player_running; then
    log "skip requested but player was not running"
    exit 0
  fi

  fade_to 0 "$SKIP_FADE_SECONDS" || true
  send_mpv '{"command":["playlist-next","force"]}' || true
  fade_to "$VOLUME" "$SKIP_FADE_SECONDS" || true
  log "skipped to next track"
}

if ! command -v "$PLAYER_BIN" >/dev/null 2>&1; then
  echo "error: required player not found: $PLAYER_BIN" >&2
  exit 1
fi

if ! command -v socat >/dev/null 2>&1; then
  echo "error: required helper not found: socat" >&2
  exit 1
fi

if [ "${1:-}" = "toggle" ]; then
  toggle_override
  exit 0
fi

if [ "${1:-}" = "skip" ]; then
  skip_track
  exit 0
fi

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  log "another bgm monitor instance already running; exiting"
  exit 0
fi

trap 'rm -rf "$LOCK_DIR"' EXIT

last_state="unknown"
last_ac_state="unknown"

while true; do
  if ac_online; then
    ac_state="ac"
  else
    ac_state="battery"
  fi

  if [ "$last_ac_state" != "unknown" ] && [ "$ac_state" != "$last_ac_state" ]; then
    clear_override
    log "power state changed to $ac_state; cleared manual override"
  fi

  state="$(desired_mode)"

  if [ "$state" != "$last_state" ]; then
    if [ "$state" = "on" ]; then
      if ! player_running; then
        start_player
      else
        fade_to "$VOLUME" || true
      fi
    else
      stop_player
    fi
    last_state="$state"
  fi

  last_ac_state="$ac_state"

  sleep "$POLL_SECONDS"
done
