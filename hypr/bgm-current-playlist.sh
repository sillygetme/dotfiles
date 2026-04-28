#!/usr/bin/env bash
set -euo pipefail

MUSIC_DIR="${BGM_DIR:-$HOME/bgm/lofi}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/bgm"
PLAYLIST="$STATE_DIR/playlist.m3u"
STAMP_FILE="$STATE_DIR/playlist-date"
TODAY="$(date +%F)"
FORCE_RESHUFFLE="${BGM_FORCE_RESHUFFLE:-0}"

mkdir -p "$STATE_DIR"

if [ ! -d "$MUSIC_DIR" ]; then
  echo "error: music directory not found: $MUSIC_DIR" >&2
  exit 1
fi

if [ "$FORCE_RESHUFFLE" = "1" ] || [ ! -f "$STAMP_FILE" ] || [ "$(cat "$STAMP_FILE" 2>/dev/null || true)" != "$TODAY" ] || [ ! -s "$PLAYLIST" ]; then
  mapfile -d '' -t tracks < <(find "$MUSIC_DIR" -type f \( \
    -iname '*.mp3' -o -iname '*.flac' -o -iname '*.ogg' -o -iname '*.m4a' -o -iname '*.wav' -o -iname '*.opus' \
  \) -print0)

  if [ "${#tracks[@]}" -eq 0 ]; then
    echo "error: no audio files found in: $MUSIC_DIR" >&2
    exit 1
  fi

  printf '%s\0' "${tracks[@]}" | shuf -z | tr '\0' '\n' > "$PLAYLIST"
  printf '%s\n' "$TODAY" > "$STAMP_FILE"
fi

printf '%s\n' "$PLAYLIST"
