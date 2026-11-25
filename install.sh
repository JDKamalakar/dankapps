#!/usr/bin/env bash

# Resolve actual project root directory
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
ROOT_DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

# Parse CLI flags for non-interactive mode
NON_INTERACTIVE=false
INSTALL_ALL=false
FLAG_APPS=""
MAKE_TARGET="install-user"

show_help() {
    echo "Usage: install.sh [OPTIONS] [APPS...]"
    echo ""
    echo "Options:"
    echo "  -a, --all            Install all apps without prompting"
    echo "  --apps <list>        Comma-separated list of apps (e.g. clock,calc,gamehub)"
    echo "  -u, --user           Install to ~/.local (default)"
    echo "  -s, --system         Install system-wide to /usr/local (requires sudo)"
    echo "  -y, --yes            Skip interactive prompts"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Available apps: clock (dankclock), calc (dankcalc), video (dankvideo), view/gallery (dankview), duzzle, gamehub (duxgamehub)"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -a|--all)
            INSTALL_ALL=true
            NON_INTERACTIVE=true
            shift
            ;;
        --apps|--app)
            FLAG_APPS="$2"
            NON_INTERACTIVE=true
            shift 2
            ;;
        --apps=*|--app=*)
            FLAG_APPS="${1#*=}"
            NON_INTERACTIVE=true
            shift
            ;;
        -u|--user)
            MAKE_TARGET="install-user"
            shift
            ;;
        -s|--system)
            MAKE_TARGET="install"
            shift
            ;;
        -y|--yes)
            NON_INTERACTIVE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            FLAG_APPS="${FLAG_APPS:+$FLAG_APPS,}$1"
            NON_INTERACTIVE=true
            shift
            ;;
    esac
done

# Auto-clone if invoked via curl | bash (repo directories not present next to script)
if [ ! -d "$ROOT_DIR/dankclock" ]; then
    CLONE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/dankapps"
    echo "Repository not found locally. Syncing to $CLONE_DIR ..."
    if [ -d "$CLONE_DIR/.git" ]; then
        git -C "$CLONE_DIR" pull --ff-only || true
    else
        git clone --recursive https://github.com/JD-Danklinux/dankapps.git "$CLONE_DIR" || exit 1
    fi
    ROOT_DIR="$CLONE_DIR"
fi

# Auto-launch inside a terminal emulator if invoked from file manager (GUI double-click)
if [ "$NON_INTERACTIVE" = false ] && { [ ! -t 0 ] || [ ! -t 1 ]; }; then
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
    "duxgamehub"
)

APP_NAMES=(
    "DUX Clock (dclock)"
    "DUX Calculator (dcalc)"
    "DUX Video Player (dplay)"
    "DUX Galary (dview)"
    "Duzzle (duzzle)"
    "DUX Game Hub (dgamehub)"
)

if [ "$NON_INTERACTIVE" = true ]; then
    CHOSEN_INDICES=()
    if [ "$INSTALL_ALL" = true ]; then
        for i in "${!APP_DIRS[@]}"; do
            CHOSEN_INDICES+=("$i")
        done
    else
        IFS=',' read -ra REQ_APPS <<< "$FLAG_APPS"
        for RAW in "${REQ_APPS[@]}"; do
            TOKEN=$(echo "$RAW" | tr '[:upper:]' '[:lower:]' | xargs)
            IDX=-1
            case "$TOKEN" in
                clock|dankclock|duxclock|dclock) IDX=0 ;;
                calc|dankcalc|duxcalc|dcalc) IDX=1 ;;
                video|dankvideo|duxvideo|dplay) IDX=2 ;;
                view|gallery|galary|dankview|duxview|duxgallery|duxgalary|dview) IDX=3 ;;
                duzzle) IDX=4 ;;
                gamehub|duxgamehub|dankgamehub|dgamehub) IDX=5 ;;
            esac
            if [ "$IDX" -ge 0 ]; then
                if [[ ! " ${CHOSEN_INDICES[*]} " =~ " ${IDX} " ]]; then
                    CHOSEN_INDICES+=("$IDX")
                fi
            else
                echo -e "${RED}Warning: Unknown app '$RAW'${RESET}"
            fi
        done
    fi
else
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
                    if [[ ! " ${CHOSEN_INDICES[*]} " =~ " ${IDX} " ]]; then
                        CHOSEN_INDICES+=("$IDX")
                    fi
                else
                    echo -e "${RED}Warning: Option '$TOKEN' is out of range.${RESET}"
                fi
            fi
        done
    fi
fi

if [ "${#CHOSEN_INDICES[@]}" -eq 0 ]; then
    echo -e "${RED}No valid apps selected. Exiting.${RESET}"
    exit 1
fi

if [ "$NON_INTERACTIVE" = false ]; then
    echo ""
    echo -e "${BOLD}Choose installation destination:${RESET}"
    echo -e "  ${BOLD}${GREEN}[1]${RESET} User-level (${HOME}/.local) ${CYAN}[Recommended - No root required]${RESET}"
    echo -e "  ${BOLD}${GREEN}[2]${RESET} System-wide (/usr/local) ${YELLOW}[Requires sudo]${RESET}"
    read -r -p "Enter choice [1/2, default: 1]: " DEST_CHOICE

    MAKE_TARGET="install-user"
    if [ "$DEST_CHOICE" == "2" ]; then
        MAKE_TARGET="install"
    fi
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
