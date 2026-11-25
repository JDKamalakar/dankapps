#!/usr/bin/env bash

# Resolve actual project root directory
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
ROOT_DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

# Auto-launch inside a terminal emulator if invoked from file manager (GUI double-click)
if [ ! -t 0 ] || [ ! -t 1 ]; then
    TERMINALS=(
        "kitty"
        "konsole"
        "gnome-terminal"
        "alacritty"
        "wezterm"
        "foot"
        "ghostty"
        "xfce4-terminal"
        "xterm"
    )

    # Check host commands if running under flatpak/container
    HAS_FLATPAK_SPAWN=false
    if command -v flatpak-spawn >/dev/null 2>&1; then
        HAS_FLATPAK_SPAWN=true
    fi

    for TERM_BIN in "${TERMINALS[@]}"; do
        if command -v "$TERM_BIN" >/dev/null 2>&1; then
            case "$TERM_BIN" in
                gnome-terminal|xfce4-terminal)
                    exec "$TERM_BIN" -- "$ROOT_DIR/install.sh" "$@"
                    ;;
                konsole)
                    exec "$TERM_BIN" -e "$ROOT_DIR/install.sh" "$@"
                    ;;
                *)
                    exec "$TERM_BIN" "$ROOT_DIR/install.sh" "$@"
                    ;;
            esac
        elif [ "$HAS_FLATPAK_SPAWN" = true ] && flatpak-spawn --host which "$TERM_BIN" >/dev/null 2>&1; then
            case "$TERM_BIN" in
                gnome-terminal|xfce4-terminal)
                    exec flatpak-spawn --host "$TERM_BIN" -- "$ROOT_DIR/install.sh" "$@"
                    ;;
                konsole)
                    exec flatpak-spawn --host "$TERM_BIN" -e "$ROOT_DIR/install.sh" "$@"
                    ;;
                *)
                    exec flatpak-spawn --host "$TERM_BIN" "$ROOT_DIR/install.sh" "$@"
                    ;;
            esac
        fi
    done

    # Fallback to gio / xdg-open if no known terminal found
    if command -v x-terminal-emulator >/dev/null 2>&1; then
        exec x-terminal-emulator -e "$ROOT_DIR/install.sh" "$@"
    fi
fi

cd "$ROOT_DIR" || exit 1

# Colors & Formatting
BOLD="\033[1m"
GREEN="\033[32m"
BLUE="\033[34m"
CYAN="\033[36m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

clear
echo -e "${BOLD}${CYAN}====================================================${RESET}"
echo -e "${BOLD}${BLUE}             DUX Apps Installer CLI                 ${RESET}"
echo -e "${BOLD}${CYAN}====================================================${RESET}"
echo ""

APP_DIRS=(
    "dankclock"
    "dankcalc"
    "dankvideo"
    "dankview"
    "duzzle"
)

APP_NAMES=(
    "DUX Clock (dclock)"
    "DUX Calculator (dcalc)"
    "DUX Video Player (dplay)"
    "DUX Galary (dview)"
    "Duzzle (duzzle)"
)

echo -e "${BOLD}Select the apps you want to install:${RESET}"
for i in "${!APP_NAMES[@]}"; do
    NUM=$((i + 1))
    echo -e "  ${BOLD}${GREEN}[$NUM]${RESET} ${APP_NAMES[$i]}"
done
echo -e "  ${BOLD}${GREEN}[A]${RESET} All apps"
echo -e "  ${BOLD}${RED}[Q]${RESET} Quit"
echo ""
echo -e "${YELLOW}Tip: You can enter multiple numbers separated by spaces or commas (e.g. '1 2 4' or '1,3').${RESET}"
echo ""
read -r -p "Enter your choice: " USER_INPUT

# Clean up input
USER_INPUT=$(echo "$USER_INPUT" | tr ',' ' ' | tr -d '\r')

if [[ "$USER_INPUT" =~ ^[Qq]$ ]] || [ -z "$USER_INPUT" ]; then
    echo -e "\n${YELLOW}Installation cancelled.${RESET}"
    exit 0
fi

CHOSEN_INDICES=()

if [[ "$USER_INPUT" =~ ^[Aa]$ ]]; then
    for i in "${!APP_DIRS[@]}"; do
        CHOSEN_INDICES+=("$i")
    done
else
    for TOKEN in $USER_INPUT; do
        if [[ "$TOKEN" =~ ^[0-9]+$ ]]; then
            IDX=$((TOKEN - 1))
            if [ "$IDX" -ge 0 ] && [ "$IDX" -lt "${#APP_DIRS[@]}" ]; then
                # Avoid duplicate entries
                if [[ ! " ${CHOSEN_INDICES[*]} " =~ " ${IDX} " ]]; then
                    CHOSEN_INDICES+=("$IDX")
                fi
            else
                echo -e "${RED}Warning: Option '$TOKEN' is out of range.${RESET}"
            fi
        fi
    done
fi

if [ "${#CHOSEN_INDICES[@]}" -eq 0 ]; then
    echo -e "${RED}No valid apps selected. Exiting.${RESET}"
    update-desktop-database ~/.local/share/applications 2>/dev/null || true
read -r -p "Press Enter to exit..."
    exit 1
fi

echo ""
echo -e "${BOLD}Choose installation destination:${RESET}"
echo -e "  ${BOLD}${GREEN}[1]${RESET} User-level (${HOME}/.local) ${CYAN}[Recommended - No root required]${RESET}"
echo -e "  ${BOLD}${GREEN}[2]${RESET} System-wide (/usr/local) ${YELLOW}[Requires sudo]${RESET}"
read -r -p "Enter choice [1/2, default: 1]: " DEST_CHOICE

MAKE_TARGET="install-user"
if [ "$DEST_CHOICE" == "2" ]; then
    MAKE_TARGET="install"
fi

echo ""
echo -e "${BOLD}${CYAN}Starting installation...${RESET}"

FAILED_APPS=()
SUCCESS_APPS=()

for IDX in "${CHOSEN_INDICES[@]}"; do
    NAME="${APP_NAMES[$IDX]}"
    DIR="${APP_DIRS[$IDX]}"
    echo ""
    echo -e "${BOLD}${BLUE}>>> Installing $NAME ...${RESET}"

    if [ ! -d "$ROOT_DIR/$DIR" ]; then
        echo -e "${RED}Error: Directory '$DIR' not found!${RESET}"
        FAILED_APPS+=("$NAME")
        continue
    fi

    if [ "$MAKE_TARGET" == "install" ]; then
        if sudo make -C "$ROOT_DIR/$DIR" install; then
            echo -e "${GREEN}✓ Successfully installed $NAME${RESET}"
            SUCCESS_APPS+=("$NAME")
        else
            echo -e "${RED}✗ Failed to install $NAME${RESET}"
            FAILED_APPS+=("$NAME")
        fi
    else
        if make -C "$ROOT_DIR/$DIR" install-user; then
            echo -e "${GREEN}✓ Successfully installed $NAME${RESET}"
            SUCCESS_APPS+=("$NAME")
        else
            echo -e "${RED}✗ Failed to install $NAME${RESET}"
            FAILED_APPS+=("$NAME")
        fi
    fi
done

echo ""
echo -e "${BOLD}${CYAN}====================================================${RESET}"
echo -e "${BOLD}Summary:${RESET}"
if [ "${#SUCCESS_APPS[@]}" -gt 0 ]; then
    echo -e "  ${GREEN}Installed successfully:${RESET}"
    for APP in "${SUCCESS_APPS[@]}"; do
        echo -e "    • $APP"
    done
fi
if [ "${#FAILED_APPS[@]}" -gt 0 ]; then
    echo -e "  ${RED}Failed:${RESET}"
    for APP in "${FAILED_APPS[@]}"; do
        echo -e "    • $APP"
    done
fi
echo -e "${BOLD}${CYAN}====================================================${RESET}"
echo ""
update-desktop-database ~/.local/share/applications 2>/dev/null || true
read -r -p "Press Enter to exit..."
