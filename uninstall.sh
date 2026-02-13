#!/data/data/com.termux/files/usr/bin/bash

# BYD-HASS Uninstall Script
# Removes files, scripts, logs, and autostart entries created by install.sh

# Re-attach stdin when executed via pipe (curl | bash)
if [ ! -t 0 ] && [ -t 1 ] && [ -e /dev/tty ]; then
  exec < /dev/tty
fi

# --- Configuration ---
BINARY_NAME="byd-hass"
SHARED_DIR="/storage/emulated/0/bydhass"
BINARY_PATH="$SHARED_DIR/$BINARY_NAME"
EXEC_PATH="/data/local/tmp/$BINARY_NAME"
CONFIG_PATH="$SHARED_DIR/config.env"
LOG_FILE="$SHARED_DIR/byd-hass.log"
ADB_KEEPALIVE_SCRIPT_NAME="keep-alive.sh"
ADB_KEEPALIVE_SCRIPT_PATH="$SHARED_DIR/$ADB_KEEPALIVE_SCRIPT_NAME"
ADB_LOG_FILE="$SHARED_DIR/keep-alive.log"

INSTALL_DIR="$HOME/.byd-hass"
INTERNAL_LOG_FILE="$INSTALL_DIR/starter.log"
BOOT_DIR="$HOME/.termux/boot"
BOOT_SCRIPT_NAME="byd-hass-starter.sh"
BOOT_GPS_SCRIPT_NAME="byd-hass-gpsdata.sh"
BOOT_SCRIPT_PATH="$BOOT_DIR/$BOOT_SCRIPT_NAME"
BOOT_GPS_SCRIPT_PATH="$BOOT_DIR/$BOOT_GPS_SCRIPT_NAME"
BASHRC_PATH="$HOME/.bashrc"
AUTOSTART_CMD="$BOOT_SCRIPT_PATH &"
AUTOSTART_GPS_CMD="$BOOT_GPS_SCRIPT_PATH &"

ADB_SERVER="localhost:5555"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

adbs() {
  if ! command -v adb >/dev/null 2>&1; then
    return 1
  fi
  if ! adb devices | grep -q "$ADB_SERVER"; then
    adb connect "$ADB_SERVER" >/dev/null 2>&1 || return 1
  fi
  adb -s "$ADB_SERVER" shell "$@"
}

cleanup_all_processes() {
  echo -e "${YELLOW}Stopping all BYD-HASS processes...${NC}"

  echo "Stopping Android-side processes..."
  adbs "pkill -f $ADB_KEEPALIVE_SCRIPT_NAME" 2>/dev/null || true
  adbs "pkill -f $BINARY_NAME" 2>/dev/null || true
  adbs "pkill -f $EXEC_PATH" 2>/dev/null || true
  adbs "pkill -f $BINARY_PATH" 2>/dev/null || true

  echo "Stopping Termux-side processes..."
  pkill -f "$BOOT_SCRIPT_NAME" 2>/dev/null || true
  pkill -f "$BOOT_GPS_SCRIPT_NAME" 2>/dev/null || true
  pkill -f "$BINARY_NAME" 2>/dev/null || true

  sleep 2

  echo "Performing final cleanup..."
  adbs "ps | grep -E '(keep-alive|byd-hass|gpsdata)' | grep -v grep | awk '{print \$2}' | xargs -r kill -9" 2>/dev/null || true
  ps aux | grep -E '(byd-hass|keep-alive|gpsdata)' | grep -v grep | awk '{print $2}' | xargs -r kill -9 2>/dev/null || true

  echo "✅ All processes terminated."
}

remove_autostart_entries() {
  if [ ! -f "$BASHRC_PATH" ]; then
    return 0
  fi

  tmp_file=$(mktemp)
  grep -Fvx "$AUTOSTART_CMD" "$BASHRC_PATH" | grep -Fvx "$AUTOSTART_GPS_CMD" > "$tmp_file"
  mv "$tmp_file" "$BASHRC_PATH"
}

# --- Script Start ---
echo -e "${GREEN}🧹 BYD-HASS Uninstaller${NC}"

cleanup_all_processes

# Remove shared storage files
if adbs true >/dev/null 2>&1; then
  echo -e "${BLUE}Removing shared storage files...${NC}"
  adbs "rm -rf $SHARED_DIR" 2>/dev/null || true
  adbs "rm -f $EXEC_PATH" 2>/dev/null || true
else
  echo -e "${YELLOW}ADB not available or not connected. Removing shared storage directly...${NC}"
  rm -rf "$SHARED_DIR" 2>/dev/null || true
  rm -f "$EXEC_PATH" 2>/dev/null || true
fi

# Remove Termux scripts and logs
echo -e "${BLUE}Removing Termux scripts and logs...${NC}"
rm -f "$BOOT_SCRIPT_PATH" "$BOOT_GPS_SCRIPT_PATH" 2>/dev/null || true
rmdir "$BOOT_DIR" 2>/dev/null || true
rm -rf "$INSTALL_DIR" 2>/dev/null || true

# Remove autostart entries from .bashrc
echo -e "${BLUE}Removing .bashrc autostart entries...${NC}"
remove_autostart_entries

echo -e "${GREEN}✅ Uninstall complete.${NC}"
