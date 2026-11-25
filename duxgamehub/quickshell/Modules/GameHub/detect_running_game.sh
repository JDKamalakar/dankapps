#!/usr/bin/env bash
# detect_running_game.sh
# Watches for the executable name of a launched game (via pgrep) and prints the game's ID.
# Usage: detect_running_game.sh <game_id> <executable_name> [poll_interval_seconds]
#
# Prints the game_id once the process is detected, then exits cleanly.

GAME_ID="${1:-}"
EXEC_NAME="${2:-}"
INTERVAL="${3:-2}"

if [ -z "$GAME_ID" ] || [ -z "$EXEC_NAME" ]; then
    echo "Usage: $0 <game_id> <executable_name> [poll_interval_seconds]" >&2
    exit 1
fi

while true; do
    if pgrep -x "$EXEC_NAME" > /dev/null 2>&1; then
        echo "$GAME_ID"
        exit 0
    fi
    sleep "$INTERVAL"
done
