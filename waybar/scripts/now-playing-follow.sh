#!/usr/bin/env bash

set -euo pipefail

cache_file="${XDG_RUNTIME_DIR:-/tmp}/waybar-now-playing.json"
pid_file="${XDG_RUNTIME_DIR:-/tmp}/waybar-now-playing-follow.pid"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
refresh_script="$script_dir/now-playing-refresh.sh"

if [[ -f "$pid_file" ]]; then
  old_pid="$(cat "$pid_file" 2>/dev/null || true)"
  if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
    exit 0
  fi
fi

printf '%s' "$$" > "$pid_file"
cleanup() {
  rm -f "$pid_file"
}
trap cleanup EXIT

update_cache() {
  "$refresh_script" > "$cache_file"
  while IFS= read -r pid; do
    kill -s RTMIN+9 "$pid" 2>/dev/null || true
  done < <(pgrep -x waybar 2>/dev/null || true)
}

follow_stream() {
  local mode="$1"
  while true; do
    if ! command -v playerctl >/dev/null 2>&1; then
      sleep 3
      continue
    fi

    if [[ "$mode" == "status" ]]; then
      playerctl --follow status 2>/dev/null | while IFS= read -r _; do
        update_cache
      done
    else
      playerctl --follow metadata --format '{{playerName}}|{{artist}}|{{title}}|{{album}}' 2>/dev/null | while IFS= read -r _; do
        update_cache
      done
    fi
    sleep 1
  done
}

poll_stream() {
  while true; do
    update_cache
    sleep 3
  done
}

update_cache

follow_stream status &
status_pid=$!
follow_stream metadata &
metadata_pid=$!
poll_stream &
poll_pid=$!

wait "$status_pid" "$metadata_pid" "$poll_pid"
