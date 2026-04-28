#!/usr/bin/env bash

set -euo pipefail

BGM_SOCKET="${XDG_RUNTIME_DIR:-/tmp}/bgm-mpv.sock"
BGM_PID_FILE="${XDG_RUNTIME_DIR:-/tmp}/bgm-mpv.pid"

hidden_json() {
  jq -cn --arg text "" --arg tooltip "" --arg class "hidden" '{text:$text, tooltip:$tooltip, class:$class}'
}

emit_json() {
  local track="$1"
  local tooltip="$2"
  local class="$3"
  local icon="$4"

  if (( ${#track} > 42 )); then
    track="${track:0:39}..."
  fi

  jq -cn \
    --arg text "$icon $track" \
    --arg tooltip "$tooltip" \
    --arg class "$class" \
    '{text:$text, tooltip:$tooltip, class:$class}'
}

bgm_player_running() {
  local pid
  if [[ ! -f "$BGM_PID_FILE" ]]; then
    return 1
  fi

  pid="$(cat "$BGM_PID_FILE" 2>/dev/null || true)"
  [[ -n "$pid" ]] || return 1
  kill -0 "$pid" 2>/dev/null
}

bgm_get() {
  local property="$1"
  printf '{"command":["get_property","%s"]}\n' "$property" | socat - UNIX-CONNECT:"$BGM_SOCKET" 2>/dev/null | jq -r '.data // empty' 2>/dev/null | head -n1
}

try_playerctl() {
  local status metadata player artist title album track tooltip icon class

  command -v playerctl >/dev/null 2>&1 || return 1

  status="$(playerctl status 2>/dev/null || true)"
  metadata="$(playerctl metadata --format $'{{playerName}}\t{{artist}}\t{{title}}\t{{album}}' 2>/dev/null || true)"
  [[ -n "$status" || -n "$metadata" ]] || return 1

  player=""
  artist=""
  title=""
  album=""
  if [[ -n "$metadata" ]]; then
    IFS=$'\t' read -r player artist title album <<< "$metadata"
  fi

  [[ -n "$artist" || -n "$title" ]] || return 1

  icon="🎵"
  class="playing"
  if [[ "$status" == "Paused" ]]; then
    icon="■"
    class="paused"
  elif [[ "$status" != "Playing" ]]; then
    class="stopped"
  fi

  track="$title"
  if [[ -n "$artist" && -n "$title" ]]; then
    track="$artist — $title"
  elif [[ -n "$artist" ]]; then
    track="$artist"
  fi

  tooltip="$track"
  if [[ -n "$album" ]]; then
    tooltip+=$'\n'
    tooltip+="Album: $album"
  fi
  if [[ -n "$player" ]]; then
    tooltip+=$'\n'
    tooltip+="Player: $player"
  fi

  emit_json "$track" "$tooltip" "$class" "$icon"
  return 0
}

try_bgm() {
  local path media_title pause_state playlist_pos playlist_count track tooltip icon class

  command -v socat >/dev/null 2>&1 || return 1
  command -v jq >/dev/null 2>&1 || return 1
  bgm_player_running || return 1
  [[ -S "$BGM_SOCKET" ]] || return 1

  path="$(bgm_get path || true)"
  media_title="$(bgm_get media-title || true)"
  pause_state="$(bgm_get pause || true)"
  playlist_pos="$(bgm_get playlist-pos-1 || true)"
  playlist_count="$(bgm_get playlist-count || true)"

  [[ -n "$path" || -n "$media_title" ]] || return 1

  track="$media_title"
  if [[ -z "$track" || "$track" == "null" ]]; then
    track="${path##*/}"
    track="${track%.*}"
  fi
  [[ -n "$track" ]] || return 1

  icon="🎵"
  class="playing"
  if [[ "$pause_state" == "true" ]]; then
    icon="■"
    class="paused"
  fi

  tooltip="$track"
  if [[ -n "$path" ]]; then
    tooltip+=$'\n'
    tooltip+="File: $path"
  fi
  if [[ -n "$playlist_pos" && -n "$playlist_count" && "$playlist_pos" != "null" && "$playlist_count" != "null" ]]; then
    tooltip+=$'\n'
    tooltip+="Track $playlist_pos of $playlist_count"
  fi
  tooltip+=$'\n'
  tooltip+="Player: bgm mpv"

  emit_json "$track" "$tooltip" "$class" "$icon"
  return 0
}

if try_playerctl; then
  exit 0
fi

if try_bgm; then
  exit 0
fi

hidden_json
