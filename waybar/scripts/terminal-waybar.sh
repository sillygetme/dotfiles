#!/usr/bin/env bash

set -euo pipefail

root_dir="${HOME}/.config/waybar"
label_width=12

print_row() {
  local label="$1"
  local value="$2"
  printf "%-${label_width}s\t%s\n" "$label" "$value"
}

json_text() {
  jq -r '.text // empty' 2>/dev/null
}

workspace_line() {
  command -v hyprctl >/dev/null 2>&1 || {
    print_row 'Workspaces' 'unavailable'
    return
  }

  local active_ids active_id line
  active_id="$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty' 2>/dev/null || true)"
  active_ids="$(hyprctl workspaces -j 2>/dev/null | jq -r 'sort_by(.id) | .[].id' 2>/dev/null || true)"

  if [[ -z "$active_ids" ]]; then
    print_row 'Workspaces' 'unavailable'
    return
  fi

  line=''
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    if [[ "$id" == "$active_id" ]]; then
      line+="[$id] "
    else
      line+="$id "
    fi
  done <<< "$active_ids"

  print_row 'Workspaces' "${line% }"
}

custom_json_line() {
  local label="$1"
  local script_path="$2"
  local text

  if [[ ! -x "$script_path" ]]; then
    print_row "$label" 'unavailable'
    return
  fi

  text="$($script_path | json_text || true)"
  if [[ -z "$text" ]]; then
    print_row "$label" 'hidden'
  else
    print_row "$label" "$text"
  fi
}

clock_line() {
  print_row 'Clock' "$(date '+%a %d %b - %H:%M:%S')"
}

wireplumber_line() {
  local volume icon status

  if command -v wpctl >/dev/null 2>&1; then
    status="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)"
    if [[ -n "$status" ]]; then
      if [[ "$status" == *'[MUTED]'* ]]; then
        print_row 'Audio' ' muted'
        return
      fi
      status="${status#Volume: }"
      status="${status%% *}"
      if [[ -n "$status" ]]; then
        volume="${status#0.}"
        if [[ "$status" == 1* ]]; then
          volume=100
        elif [[ "$status" == 0 ]]; then
          volume=0
        else
          volume="${volume%%[!0-9]*}"
          while ((${#volume} < 2)); do volume+="0"; done
        fi
      else
        volume=''
      fi
      if [[ -n "$volume" ]]; then
        if (( volume < 50 )); then
          icon=''
        else
          icon=''
        fi
        print_row 'Audio' "$icon $volume%"
        return
      fi
    fi
  fi

  print_row 'Audio' 'unavailable'
}

bluetooth_line() {
  local connected line names

  if ! command -v bluetoothctl >/dev/null 2>&1; then
    print_row 'Bluetooth' 'unavailable'
    return
  fi

  connected="$(bluetoothctl devices Connected 2>/dev/null || true)"
  if [[ -z "$connected" ]]; then
    print_row 'Bluetooth' ''
    return
  fi

  names=''
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    line="${line#Device }"
    line="${line#* }"
    if [[ -n "$names" ]]; then
      names+=', '
    fi
    names+="$line"
  done <<< "$connected"

  print_row 'Bluetooth' " $names"
}

temperature_line() {
  local temp_file temp_raw temp_c
  temp_file='/sys/class/thermal/thermal_zone4/temp'

  if [[ ! -r "$temp_file" ]]; then
    print_row 'Temperature' 'unavailable'
    return
  fi

  temp_raw="$(<"$temp_file")"
  temp_c=$(( temp_raw / 1000 ))
  print_row 'Temperature' "  $temp_c°C"
}

cpu_line() {
  local user1 nice1 system1 idle1 iowait1 irq1 softirq1 steal1
  local user2 nice2 system2 idle2 iowait2 irq2 softirq2 steal2
  local total1 total2 usage

  read -r _ user1 nice1 system1 idle1 iowait1 irq1 softirq1 steal1 _ < /proc/stat
  total1=$(( user1 + nice1 + system1 + idle1 + iowait1 + irq1 + softirq1 + steal1 ))

  sleep 0.1

  read -r _ user2 nice2 system2 idle2 iowait2 irq2 softirq2 steal2 _ < /proc/stat
  total2=$(( user2 + nice2 + system2 + idle2 + iowait2 + irq2 + softirq2 + steal2 ))

  if (( total2 == total1 )); then
    usage=0
  else
    usage=$(( 100 * ((total2 - total1) - (idle2 - idle1)) / (total2 - total1) ))
  fi

  print_row 'CPU' " $usage%"
}

memory_line() {
  local used_kb total_kb used_gb total_gb
  local key value _ mem_available_kb=0

  while read -r key value _; do
    case "$key" in
      MemTotal:)
        total_kb="$value"
        ;;
      MemAvailable:)
        mem_available_kb="$value"
        ;;
    esac
  done < /proc/meminfo

  used_kb=$(( total_kb - mem_available_kb ))
  used_gb="$(printf '%s\n' "$used_kb" | awk '{printf "%.2f", $1 / 1024 / 1024}')"
  total_gb="$(printf '%s\n' "$total_kb" | awk '{printf "%.2f", $1 / 1024 / 1024}')"
  print_row 'Memory' " $used_gb / $total_gb GB"
}

battery_line() {
  local battery_dir capacity status icon dir

  battery_dir=''
  for dir in /sys/class/power_supply/BAT* /sys/class/power_supply/CMB*; do
    if [[ -d "$dir" && -r "$dir/capacity" ]]; then
      battery_dir="$dir"
      break
    fi
  done

  if [[ -z "$battery_dir" || ! -r "$battery_dir/capacity" ]]; then
    print_row 'Battery' 'n/a'
    return
  fi

  capacity="$(<"$battery_dir/capacity")"
  status="$(<"$battery_dir/status")"

  case "$status" in
    Charging)
      print_row 'Battery' "  $capacity%"
      return
      ;;
    Full)
      print_row 'Battery' "  $capacity%"
      return
      ;;
  esac

  if (( capacity <= 20 )); then
    icon=''
  elif (( capacity <= 40 )); then
    icon=''
  elif (( capacity <= 60 )); then
    icon=''
  elif (( capacity <= 80 )); then
    icon=''
  else
    icon=''
  fi

  print_row 'Battery' "$icon $capacity%"
}

network_line() {
  local default_dev wifi_ssid connection_name wireless_flag iface dest flags refcnt use metric mask mtu win irtt

  default_dev=''
  while read -r iface dest _ flags refcnt use metric mask mtu win irtt; do
    if [[ "$dest" == "00000000" && "$mask" == "00000000" ]]; then
      default_dev="$iface"
      break
    fi
  done < /proc/net/route

  if [[ -z "$default_dev" ]]; then
    print_row 'Network' '⚠  Disconnected'
    return
  fi

  wireless_flag=''
  if [[ -d "/sys/class/net/$default_dev/wireless" ]]; then
    wireless_flag='1'
  fi

  if [[ -n "$wireless_flag" ]]; then
    if command -v iwgetid >/dev/null 2>&1; then
      wifi_ssid="$(iwgetid -r 2>/dev/null || true)"
    else
      wifi_ssid=''
    fi

    if [[ -z "$wifi_ssid" ]] && command -v nmcli >/dev/null 2>&1; then
      connection_name="$(timeout 0.3s nmcli -g GENERAL.CONNECTION device show "$default_dev" 2>/dev/null | head -n1 || true)"
    else
      connection_name=''
    fi

    if [[ -n "$wifi_ssid" ]]; then
      print_row 'Network' "  $wifi_ssid"
    elif [[ -n "$connection_name" && "$connection_name" != '--' ]]; then
      print_row 'Network' "  $connection_name"
    else
      print_row 'Network' "  $default_dev"
    fi
    return
  fi

  print_row 'Network' '  Wired'
}

tray_line() {
  print_row 'Tray' 'graphical-only module'
}

workspace_line
custom_json_line 'Weather' "$root_dir/scripts/weather.sh"
custom_json_line 'Now Playing' "$root_dir/scripts/now-playing.sh"
clock_line
wireplumber_line
bluetooth_line
temperature_line
cpu_line
memory_line
battery_line
network_line
