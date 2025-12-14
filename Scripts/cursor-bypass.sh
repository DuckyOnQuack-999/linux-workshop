#!/usr/bin/env bash
# Cursor/Warp Machine ID Reset Script for Linux (Arch compatible)
# Extended from original Cursor script to support Warp with adjusted logic
# For Cursor: Regenerates IDs and updates files (VSCode-based).
# For Warp: Generates IDs for display, then backs up and removes config/data/state dirs to fully reset (Rust-based, no VSCode files).
# This bypasses trial limits by simulating a new installation, forcing ID regeneration.
# Requires: sqlite3, jq, uuidgen, openssl (for Cursor); rm, cp (for Warp)

set -e

# === Utility Functions ===
color() { echo -e "\e[$1m$2\e[0m"; }
pause() { read -rp "Press Enter to continue..."; }

# === Root Check (optional for backups only) ===
if [[ $EUID -ne 0 ]]; then
  color 33 "[!] This script is not running as root. That's fine unless you want to modify global permissions."
fi

# === Menu Selection ===
color 36 "=== Machine ID Reset Tool (Linux Edition) ==="
echo "Select the application to reset:"
select app in "Cursor" "Warp"; do
  if [[ -n "$app" ]]; then
    break
  fi
done

# === Paths based on selection ===
if [[ "$app" == "Cursor" ]]; then
  app_dir="$HOME/.config/Cursor"
  machine_id_path="$app_dir/machineId"
  storage_json="$app_dir/User/globalStorage/storage.json"
  sqlite_path="$app_dir/User/globalStorage/state.vscdb"
  # Sanity Check
  if [[ ! -d "$app_dir" ]]; then
    color 31 "[✗] $app directory not found at: $app_dir"
    exit 1
  fi
  color 32 "[✔] Found $app configuration directory at: $app_dir"
  # Proceed with original Cursor logic
  color 36 "\nGenerating new identifiers..."
  devDeviceId=$(uuidgen)
  machineId=$(openssl rand -hex 32)
  macMachineId=$(openssl rand -hex 64)
  sqmId="{$(uuidgen | tr '[:lower:]' '[:upper:]')}"

  color 32 "\nGenerated IDs:"
  echo "devDeviceId: $devDeviceId"
  echo "machineId: $machineId"
  echo "macMachineId: $macMachineId"
  echo "sqmId: $sqmId"

  # 1. Update machineId file
  color 36 "\n[1/3] Updating machineId file..."
  if [[ -f "$machine_id_path" ]]; then
    cp -f "$machine_id_path" "$machine_id_path.backup"
    color 33 "[!] Backup created: $machine_id_path.backup"
  fi
  echo "$devDeviceId" >"$machine_id_path"
  color 32 "[✔] machineId file updated successfully."

  # 2. Update storage.json
  color 36 "\n[2/3] Updating storage.json..."
  if [[ -f "$storage_json" ]]; then
    cp -f "$storage_json" "$storage_json.backup"
    color 33 "[!] Backup created: $storage_json.backup"
  else
    mkdir -p "$(dirname "$storage_json")"
    echo "{}" >"$storage_json"
  fi
  tmp_json=$(mktemp)
  jq --arg dev "$devDeviceId" \
    --arg mach "$machineId" \
    --arg mac "$macMachineId" \
    --arg sqm "$sqmId" \
    '.["telemetry.devDeviceId"]=$dev |
      .["telemetry.machineId"]=$mach |
      .["telemetry.macMachineId"]=$mac |
      .["telemetry.sqmId"]=$sqm |
      .["storage.serviceMachineId"]=$dev' \
    "$storage_json" >"$tmp_json" && mv "$tmp_json" "$storage_json"
  color 32 "[✔] storage.json updated successfully."

  # 3. Update SQLite database
  color 36 "\n[3/3] Updating SQLite database..."
  if [[ -f "$sqlite_path" ]]; then
    cp -f "$sqlite_path" "$sqlite_path.backup"
    color 33 "[!] Backup created: $sqlite_path.backup"
    sqlite3 "$sqlite_path" <<SQL
CREATE TABLE IF NOT EXISTS ItemTable (key TEXT PRIMARY KEY, value TEXT);
INSERT OR REPLACE INTO ItemTable (key, value) VALUES
('telemetry.devDeviceId', '$devDeviceId'),
('telemetry.macMachineId', '$macMachineId'),
('telemetry.machineId', '$machineId'),
('telemetry.sqmId', '$sqmId'),
('storage.serviceMachineId', '$devDeviceId');
SQL
    color 32 "[✔] SQLite database updated successfully."
  else
    color 33 "[!] No SQLite database found at: $sqlite_path"
    color 33 "Skipping this step ($app may not have created the DB yet)."
  fi

elif [[ "$app" == "Warp" ]]; then
  config_dir="$HOME/.config/warp-terminal"
  data_dir="$HOME/.local/share/warp-terminal"
  state_dir="$HOME/.local/state/warp-terminal"
  warp_dot_dir="$HOME/.warp" # Optional, for launch configs, themes, etc.

  # Sanity Check
  if [[ ! -d "$config_dir" && ! -d "$data_dir" && ! -d "$state_dir" ]]; then
    color 31 "[✗] No Warp directories found. Ensure Warp is installed and has been run at least once."
    exit 1
  fi
  color 32 "[✔] Found Warp directories: $config_dir, $data_dir, $state_dir"

  # Generate IDs (displayed for reference; app will regenerate upon reset)
  color 36 "\nGenerating new identifiers (for reference; Warp regenerates internally)..."
  devDeviceId=$(uuidgen)
  machineId=$(openssl rand -hex 32)
  macMachineId=$(openssl rand -hex 64)
  sqmId="{$(uuidgen | tr '[:lower:]' '[:upper:]')}"

  color 32 "\nGenerated IDs:"
  echo "devDeviceId: $devDeviceId"
  echo "machineId: $machineId"
  echo "macMachineId: $macMachineId"
  echo "sqmId: $sqmId"

  # Warp-specific logic: Full reset by removing dirs (no specific ID files; reset forces regeneration)
  color 36 "\nResetting Warp by backing up and removing directories..."
  timestamp=$(date +%Y%m%d_%H%M%S)
  backup_dir="$HOME/warp_backup_$timestamp"
  mkdir -p "$backup_dir"

  [[ -d "$config_dir" ]] && cp -r "$config_dir" "$backup_dir/" && rm -rf "$config_dir" && color 32 "[✔] Reset $config_dir (backup in $backup_dir)"
  [[ -d "$data_dir" ]] && cp -r "$data_dir" "$backup_dir/" && rm -rf "$data_dir" && color 32 "[✔] Reset $data_dir (backup in $backup_dir)"
  [[ -d "$state_dir" ]] && cp -r "$state_dir" "$backup_dir/" && rm -rf "$state_dir" && color 32 "[✔] Reset $state_dir (backup in $backup_dir)"
  [[ -d "$warp_dot_dir" ]] && cp -r "$warp_dot_dir" "$backup_dir/" && rm -rf "$warp_dot_dir" && color 32 "[✔] Reset $warp_dot_dir (backup in $backup_dir)"

  color 33 "[!] Backups created in: $backup_dir"
  color 32 "[✔] Warp reset complete. This should bypass trial limits by regenerating identifiers on relaunch."

else
  color 31 "[✗] Invalid selection."
  exit 1
fi

# === Completion ===
color 32 "\n=== Reset Complete for $app ==="
echo "What's been done:"
if [[ "$app" == "Cursor" ]]; then
  echo "1. Generated new identifiers"
  echo "2. Updated machineId file"
  echo "3. Updated storage.json"
  echo "4. Updated SQLite database (if found)"
else
  echo "1. Generated new identifiers (for reference)"
  echo "2. Backed up Warp directories"
  echo "3. Removed config, data, state directories to force reset and ID regeneration"
fi
echo
color 36 "Backups created:"
if [[ "$app" == "Cursor" ]]; then
  [[ -f "$machine_id_path.backup" ]] && echo "- $machine_id_path.backup"
  [[ -f "$storage_json.backup" ]] && echo "- $storage_json.backup"
  [[ -f "$sqlite_path.backup" ]] && echo "- $sqlite_path.backup"
else
  echo "- $backup_dir (full directory backups)"
fi
echo
color 36 "Next steps:"
echo "1. Launch $app to regenerate internal data (may require new account sign-in for Warp with temp email for full bypass)."
echo "2. Restore backups if you want to revert changes."
echo "3. For Warp, consider logging out of existing accounts and using a temporary email for new sign-up."

pause
