#!/usr/bin/env bash

set -euo pipefail

state_file="${XDG_RUNTIME_DIR:-/tmp}/waybar-weather-city"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-weather"

mkdir -p "$cache_dir"

cities=(
  "Rzeszywska|50.022954|22.983578"
  "Stalowa Wola|49.729410|21.944869"
)

city_count="${#cities[@]}"

if (( city_count == 0 )); then
  jq -cn \
    --arg text "? No cities" \
    --arg tooltip "No weather cities configured" \
    --arg class "weather" \
    '{text: $text, tooltip: $tooltip, class: $class}'
  exit 0
fi

if [[ "${1:-}" == "toggle" ]]; then
  current_index=0
  if [[ -f "$state_file" ]]; then
    current_index="$(cat "$state_file")"
  fi

  if ! [[ "$current_index" =~ ^[0-9]+$ ]]; then
    current_index=0
  fi

  next_index=$(( (current_index + 1) % city_count ))
  printf '%s' "$next_index" > "$state_file"
  pkill -RTMIN+8 waybar || true
  exit 0
fi

selection=0
if [[ -f "$state_file" ]]; then
  selection="$(cat "$state_file")"
fi

if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
  selection=0
fi

if (( selection < 0 || selection >= city_count )); then
  selection=0
fi

IFS='|' read -r city_name latitude longitude <<< "${cities[$selection]}"
cache_slug="$(printf '%s' "$city_name" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-')"
cache_file="$cache_dir/${cache_slug}.json"

refresh_cache="true"
if [[ -f "$cache_file" ]]; then
  cache_age_seconds="$(( $(date +%s) - $(stat -c %Y "$cache_file") ))"
  if (( cache_age_seconds < 86400 )); then
    refresh_cache="false"
  fi
fi

if [[ "$refresh_cache" == "true" ]]; then
  if curl -sf "https://api.open-meteo.com/v1/forecast?latitude=${latitude}&longitude=${longitude}&current=temperature_2m,apparent_temperature,weather_code&timezone=auto" -o "$cache_file.tmp"; then
    mv "$cache_file.tmp" "$cache_file"
  else
    rm -f "$cache_file.tmp"
  fi
fi

if [[ -f "$cache_file" ]]; then
  response="$(cat "$cache_file")"
else
  offline_tooltip=$(printf '%s
%s' "$city_name" 'No cached weather available')
  jq -cn \
    --arg text "? $city_name --" \
    --arg tooltip "$offline_tooltip" \
    --arg class "weather" \
    '{text: $text, tooltip: $tooltip, class: $class}'
  exit 0
fi

temperature="$(printf '%s' "$response" | jq -r '.current.temperature_2m | round')"
feels_like="$(printf '%s' "$response" | jq -r '.current.apparent_temperature | round')"
weather_code="$(printf '%s' "$response" | jq -r '.current.weather_code')"

weather_text="Unknown"
weather_icon="☁"

case "$weather_code" in
  0)
    weather_text="Clear"
    weather_icon="☀"
    ;;
  1|2)
    weather_text="Partly cloudy"
    weather_icon="⛅"
    ;;
  3)
    weather_text="Cloudy"
    weather_icon="☁"
    ;;
  45|48)
    weather_text="Fog"
    weather_icon="🌫"
    ;;
  51|53|55|56|57)
    weather_text="Drizzle"
    weather_icon="🌦"
    ;;
  61|63|65|66|67|80|81|82)
    weather_text="Rain"
    weather_icon="🌧"
    ;;
  71|73|75|77|85|86)
    weather_text="Snow"
    weather_icon="❄"
    ;;
  95|96|99)
    weather_text="Storm"
    weather_icon="⛈"
    ;;
esac

jq_tooltip=$(printf '%s
%s
Measured %s°C
Feels like %s°C
City %s of %s' "$city_name" "$weather_text" "$temperature" "$feels_like" "$((selection + 1))" "$city_count")

jq -cn \
  --arg text "$weather_icon $city_name ${feels_like}°C" \
  --arg tooltip "$jq_tooltip" \
  --arg class "weather" \
  '{text: $text, tooltip: $tooltip, class: $class}'
