#!/usr/bin/env bash
#
# WehttamSnaps-Niri Ubuntu Installer
#
# Target:
#   Ubuntu 26.04.x LTS
#   x86_64 / amd64
#
# Purpose:
#   Convert a minimal Ubuntu installation into a usable
#   Niri + Quickshell + WehttamSnaps desktop.
#
# Philosophy:
#   - Never assume dependencies exist.
#   - Check before installing.
#   - Preserve existing user configuration.
#   - Backup before replacing configuration.
#   - Translate Arch dependencies to Ubuntu.
#   - Validate after installation.
#
# Upstream:
#   https://github.com/Crowdrocker/WehttamSnaps-Niri
#

set -Eeuo pipefail

###############################################################################
# Configuration
###############################################################################

readonly REPO_URL="https://github.com/Crowdrocker/WehttamSnaps-Niri.git"
readonly REPO_NAME="WehttamSnaps-Niri"
readonly WORK_DIR="${HOME}/.cache/wehttamsnaps-installer"
readonly REPO_DIR="${WORK_DIR}/${REPO_NAME}"

readonly CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}"
readonly DATA_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}"
readonly STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}"
readonly BIN_DIR="${HOME}/.local/bin"

readonly BACKUP_ROOT="${HOME}/.local/share/wehttamsnaps-backups"
readonly LOG_FILE="${WORK_DIR}/install.log"

###############################################################################
# Colors
###############################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
RESET='\033[0m'

###############################################################################
# Logging
###############################################################################

mkdir -p "$WORK_DIR"
touch "$LOG_FILE"

log() {
    printf '%b\n' "$1" | tee -a "$LOG_FILE"
}

info() {
    log "${CYAN}[INFO]${RESET} $1"
}

success() {
    log "${GREEN}[ OK ]${RESET} $1"
}

warn() {
    log "${YELLOW}[WARN]${RESET} $1"
}

error() {
    log "${RED}[FAIL]${RESET} $1"
}

section() {
    log ""
    log "${BLUE}============================================================${RESET}"
    log "${BOLD}$1${RESET}"
    log "${BLUE}============================================================${RESET}"
}

###############################################################################
# Error handling
###############################################################################

on_error() {
    local exit_code=$?
    error "Installation stopped."
    error "Exit code: ${exit_code}"
    error "Log: ${LOG_FILE}"
    exit "$exit_code"
}

trap on_error ERR

###############################################################################
# Root protection
###############################################################################

if [[ "${EUID}" -eq 0 ]]; then
    error "Do not run this installer as root."
    error "Run it as your normal Ubuntu user."
    exit 1
fi

###############################################################################
# Ubuntu detection
###############################################################################

section "SYSTEM CHECK"

if [[ ! -f /etc/os-release ]]; then
    error "/etc/os-release does not exist."
    exit 1
fi

source /etc/os-release

if [[ "${ID:-}" != "ubuntu" ]]; then
    error "This installer is for Ubuntu."
    error "Detected: ${PRETTY_NAME:-unknown}"
    exit 1
fi

if [[ "${VERSION_ID:-}" != "26.04" ]]; then
    error "This installer targets Ubuntu 26.04.x."
    error "Detected: ${PRETTY_NAME:-unknown}"
    exit 1
fi

if [[ "$(dpkg --print-architecture)" != "amd64" ]]; then
    warn "This installer was primarily designed for amd64."
    warn "Detected architecture: $(dpkg --print-architecture)"
fi

success "Ubuntu 26.04 detected: ${PRETTY_NAME}"

info "Kernel: $(uname -r)"
info "Architecture: $(uname -m)"
info "User: ${USER}"
info "Home: ${HOME}"

###############################################################################
# Internet
###############################################################################

section "NETWORK CHECK"

if ! command -v curl >/dev/null 2>&1; then
    info "curl is missing. Installing bootstrap dependency."

    sudo apt-get update
    sudo apt-get install -y curl
fi

if ! curl -fsSL --connect-timeout 10 --max-time 20 \
    https://github.com >/dev/null; then

    error "Internet/GitHub connectivity test failed."
    error "Connect to the Internet and run the installer again."
    exit 1
fi

success "Internet connectivity available"

###############################################################################
# Repository configuration
###############################################################################

section "APT REPOSITORIES"

# Ubuntu Mini installations sometimes have only a subset of components.
# Make sure universe/multiverse are available.

if ! grep -RhsE \
    '^[[:space:]]*Components:.*universe' \
    /etc/apt/sources.list.d \
    /etc/apt/sources.list \
    2>/dev/null | grep -q universe; then

    info "Ensuring Ubuntu universe repository is enabled."

    sudo add-apt-repository -y universe
fi

if ! grep -RhsE \
    '^[[:space:]]*Components:.*multiverse' \
    /etc/apt/sources.list.d \
    /etc/apt/sources.list \
    2>/dev/null | grep -q multiverse; then

    info "Ensuring Ubuntu multiverse repository is enabled."

    sudo add-apt-repository -y multiverse || true
fi

sudo apt-get update

success "APT repositories updated"

###############################################################################
# Basic bootstrap dependencies
###############################################################################

section "BOOTSTRAP DEPENDENCIES"

BOOTSTRAP_PACKAGES=(
    ca-certificates
    curl
    wget
    git
    rsync
    jq
    unzip
    tar
    gzip
    bzip2
    xz-utils
    file
    findutils
    coreutils
    sed
    grep
    gawk
    bc
    ripgrep
    xdg-user-dirs
    dbus
)

for pkg in "${BOOTSTRAP_PACKAGES[@]}"; do

    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null |
        grep -q 'install ok installed'; then

        success "$pkg already installed"

    else

        info "Installing missing package: $pkg"
        sudo apt-get install -y "$pkg"
    fi
done

###############################################################################
# DankLinux repository
###############################################################################

section "QUICKSHELL SOURCE"

#
# Quickshell's official documentation currently lists Ubuntu packages
# through the AvengeMedia DankLinux PPA.
#

if ! grep -Rqs \
    'ppa.launchpadcontent.net/avengemedia/danklinux' \
    /etc/apt/sources.list \
    /etc/apt/sources.list.d \
    2>/dev/null; then

    info "DankLinux PPA not detected."
    info "Adding PPA for Quickshell."

    sudo add-apt-repository -y ppa:avengemedia/danklinux

    sudo apt-get update

else

    success "DankLinux PPA already configured"
fi

###############################################################################
# Package helper
###############################################################################

install_package() {

    local pkg="$1"

    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null |
        grep -q 'install ok installed'; then

        success "$pkg already installed"
        return 0
    fi

    if apt-cache show "$pkg" >/dev/null 2>&1; then

        info "Installing: $pkg"

        if sudo apt-get install -y "$pkg"; then
            success "$pkg installed"
            return 0
        fi
    fi

    warn "Package '$pkg' is not available from current Ubuntu sources."
    return 1
}

###############################################################################
# Try multiple Ubuntu package names
###############################################################################

install_any() {

    local name

    for name in "$@"; do

        if dpkg-query -W -f='${Status}' "$name" 2>/dev/null |
            grep -q 'install ok installed'; then

            success "$name already installed"
            return 0
        fi

        if apt-cache show "$name" >/dev/null 2>&1; then

            info "Installing available package: $name"

            if sudo apt-get install -y "$name"; then
                success "$name installed"
                return 0
            fi
        fi

    done

    warn "None of these packages were available: $*"
    return 1
}

###############################################################################
# Core desktop packages
###############################################################################

section "CORE DESKTOP DEPENDENCIES"

CORE_PACKAGES=(
    niri
    wl-clipboard
    cliphist
    libnotify-bin
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    xdg-desktop-portal-gnome
    policykit-1
    mate-polkit
    network-manager
    gnome-keyring
    foot
    fuzzel
    fontconfig
)

for pkg in "${CORE_PACKAGES[@]}"; do
    install_package "$pkg" || true
done

###############################################################################
# Quickshell
###############################################################################

section "QUICKSHELL"

if command -v qs >/dev/null 2>&1 ||
   command -v quickshell >/dev/null 2>&1; then

    success "Quickshell already installed"

else

    if apt-cache show quickshell >/dev/null 2>&1; then

        info "Installing Quickshell release package."

        sudo apt-get install -y quickshell

    elif apt-cache show quickshell-git >/dev/null 2>&1; then

        warn "Stable Quickshell package unavailable."
        info "Installing quickshell-git instead."

        sudo apt-get install -y quickshell-git

    else

        error "Quickshell is unavailable from configured sources."
        error "The DankLinux PPA may not provide a package for this Ubuntu build."
        error "Quickshell installation must be resolved before continuing."

        exit 1
    fi
fi

if command -v qs >/dev/null 2>&1; then
    success "Quickshell command available: $(command -v qs)"
elif command -v quickshell >/dev/null 2>&1; then
    success "Quickshell command available: $(command -v quickshell)"
else
    error "Quickshell installation did not provide qs/quickshell."
    exit 1
fi

###############################################################################
# Audio
###############################################################################

section "AUDIO"

AUDIO_PACKAGES=(
    pipewire
    pipewire-pulse
    pipewire-alsa
    pipewire-jack
    wireplumber
    playerctl
    pavucontrol
)

for pkg in "${AUDIO_PACKAGES[@]}"; do
    install_package "$pkg" || true
done

###############################################################################
# Screenshots / recording / OCR
###############################################################################

section "SCREENSHOT AND RECORDING"

MEDIA_PACKAGES=(
    grim
    slurp
    swappy
    tesseract-ocr
    tesseract-ocr-eng
    wf-recorder
    imagemagick
    ffmpeg
)

for pkg in "${MEDIA_PACKAGES[@]}"; do
    install_package "$pkg" || true
done

###############################################################################
# Input / power
###############################################################################

section "INPUT AND POWER"

INPUT_PACKAGES=(
    upower
    wtype
    ydotool
    python3-evdev
    python3-pil
    brightnessctl
    ddcutil
    geoclue-2.0
    swayidle
)

for pkg in "${INPUT_PACKAGES[@]}"; do
    install_package "$pkg" || true
done

###############################################################################
# Theming
###############################################################################

section "THEMING"

THEME_PACKAGES=(
    matugen
    kvantum
    qt6ct
    libglib2.0-bin
)

for pkg in "${THEME_PACKAGES[@]}"; do
    install_package "$pkg" || true
done

###############################################################################
# Qt / KDE support
###############################################################################

section "QT / KDE COMPONENTS"

QT_PACKAGES=(
    qt6-base-dev
    qt6-declarative-dev
    qt6-svg-dev
    qt6-wayland
    qt6-image-formats-plugins
    qt6-multimedia
    qt6-positioning
    qt6-tools-dev
    qt6-tools-dev-tools
    qt6-virtualkeyboard
    libqt6core6
    libqt6gui6
    libqt6qml6
    libqt6quick6
    libdrm2
    libxcb1
    mesa-utils
)

for pkg in "${QT_PACKAGES[@]}"; do
    install_package "$pkg" || true
done

###############################################################################
# Fonts
###############################################################################

section "FONTS"

FONT_PACKAGES=(
    fontconfig
    fonts-dejavu
    fonts-liberation
    fonts-noto
    fonts-noto-color-emoji
)

for pkg in "${FONT_PACKAGES[@]}"; do
    install_package "$pkg" || true
done

###############################################################################
# Nerd Font
###############################################################################

if fc-list 2>/dev/null |
    grep -qiE 'JetBrains.*Nerd|Nerd Font'; then

    success "A Nerd Font is already installed"

else

    info "Nerd Font not detected."

    #
    # Try Ubuntu package first.
    #

    if apt-cache show fonts-jetbrains-mono >/dev/null 2>&1; then
        install_package fonts-jetbrains-mono
    fi

    warn "A full Nerd Font is preferred by the shell."
    warn "If Ubuntu does not provide the required glyph set, the shell will use fallback fonts."
fi

fc-cache -f >/dev/null 2>&1 || true

###############################################################################
# Cursor theme
###############################################################################

section "CURSOR THEME"

if apt-cache show capitaine-cursors >/dev/null 2>&1; then
    install_package capitaine-cursors
else
    warn "capitaine-cursors is unavailable in current Ubuntu repositories."
    warn "Niri configuration will retain its configured cursor name."
fi

###############################################################################
# XWayland
###############################################################################

section "XWAYLAND"

install_any xwayland || true

###############################################################################
# XDG portals
###############################################################################

section "XDG DESKTOP PORTALS"

PORTAL_PACKAGES=(
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    xdg-desktop-portal-gnome
)

for pkg in "${PORTAL_PACKAGES[@]}"; do
    install_package "$pkg" || true
done

###############################################################################
# Bluetooth
###############################################################################

section "BLUETOOTH"

if command -v bluetoothctl >/dev/null 2>&1; then

    success "Bluetooth tools already installed"

else

    install_any bluez bluetooth || true
fi

if systemctl list-unit-files 2>/dev/null |
    grep -q '^bluetooth.service'; then

    sudo systemctl enable bluetooth --now || true
fi

###############################################################################
# User directories
###############################################################################

section "USER DIRECTORIES"

if command -v xdg-user-dirs-update >/dev/null 2>&1; then
    xdg-user-dirs-update
    success "XDG user directories configured"
fi

mkdir -p \
    "$CONFIG_DIR" \
    "$DATA_DIR" \
    "$STATE_DIR" \
    "$BIN_DIR" \
    "$WORK_DIR"

###############################################################################
# Clone / update repository
###############################################################################

section "WEHTTAMSNAPS REPOSITORY"

if [[ -d "${REPO_DIR}/.git" ]]; then

    info "Existing repository found."
    info "Updating repository."

    git -C "$REPO_DIR" fetch --depth=1 origin main
    git -C "$REPO_DIR" reset --hard origin/main

else

    info "Cloning WehttamSnaps-Niri."

    rm -rf "$REPO_DIR"

    git clone --depth=1 "$REPO_URL" "$REPO_DIR"
fi

success "Repository ready"

###############################################################################
# Verify repository contents
###############################################################################

section "REPOSITORY VALIDATION"

REQUIRED_PATHS=(
    "$REPO_DIR/setup"
    "$REPO_DIR/defaults/niri/config.kdl"
    "$REPO_DIR/shell.qml"
    "$REPO_DIR/modules"
    "$REPO_DIR/services"
    "$REPO_DIR/scripts"
    "$REPO_DIR/assets"
    "$REPO_DIR/dots"
    "$REPO_DIR/sdata"
)

for path in "${REQUIRED_PATHS[@]}"; do

    if [[ -e "$path" ]]; then
        success "Found: ${path#"$REPO_DIR"/}"
    else
        warn "Missing upstream path: ${path#"$REPO_DIR"/}"
    fi
done

###############################################################################
# Backup
###############################################################################

section "CONFIGURATION BACKUP"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"

mkdir -p "$BACKUP_DIR"

CONFIG_TARGETS=(
    "$CONFIG_DIR/niri"
    "$CONFIG_DIR/quickshell"
    "$CONFIG_DIR/fuzzel"
    "$CONFIG_DIR/matugen"
    "$CONFIG_DIR/gtk-3.0"
    "$CONFIG_DIR/gtk-4.0"
    "$CONFIG_DIR/Kvantum"
    "$CONFIG_DIR/kdeglobals"
    "$CONFIG_DIR/dolphinrc"
)

for target in "${CONFIG_TARGETS[@]}"; do

    if [[ -e "$target" ]]; then

        info "Backing up ${target}"

        mkdir -p "$BACKUP_DIR/$(dirname "${target#"$CONFIG_DIR"/}")" 2>/dev/null || true

        cp -a "$target" "$BACKUP_DIR/" 2>/dev/null || true
    fi
done

success "Backup created: $BACKUP_DIR"

###############################################################################
# Install Quickshell configuration
###############################################################################

section "QUICKSHELL CONFIGURATION"

II_TARGET="$CONFIG_DIR/quickshell/ii"

mkdir -p "$II_TARGET"

#
# Root QML files
#

for qml in "$REPO_DIR"/*.qml; do

    if [[ -f "$qml" ]]; then

        cp -f "$qml" "$II_TARGET/"
    fi
done

#
# Runtime directories.
#

QML_DIRS=(
    modules
    services
    scripts
    assets
    translations
    sdata/uv
)

for dir in "${QML_DIRS[@]}"; do

    if [[ -d "$REPO_DIR/$dir" ]]; then

        mkdir -p "$II_TARGET/$dir"

        rsync -a \
            "$REPO_DIR/$dir/" \
            "$II_TARGET/$dir/"
    fi
done

#
# Executable permissions.
#

if [[ -d "$II_TARGET/scripts" ]]; then

    find "$II_TARGET/scripts" \
        \( -name '*.sh' -o -name '*.py' -o -name '*.fish' \) \
        -exec chmod +x {} \; \
        2>/dev/null || true
fi

success "Quickshell ii configuration installed"

###############################################################################
# Install Niri configuration
###############################################################################

section "NIRI CONFIGURATION"

NIRI_CONFIG="$CONFIG_DIR/niri/config.kdl"
NIRI_SOURCE="$REPO_DIR/defaults/niri/config.kdl"

mkdir -p "$CONFIG_DIR/niri"

if [[ -f "$NIRI_SOURCE" ]]; then

    if [[ -f "$NIRI_CONFIG" ]]; then

        cp -a "$NIRI_CONFIG" \
            "$BACKUP_DIR/config.kdl.before-wehttamsnaps"

        info "Existing Niri config backed up."

    fi

    cp -f "$NIRI_SOURCE" "$NIRI_CONFIG"

    success "WehttamSnaps Niri configuration installed"

else

    error "Upstream Niri configuration not found."
    exit 1
fi

###############################################################################
# Install supporting configs
###############################################################################

section "SUPPORTING CONFIGURATION"

if [[ -d "$REPO_DIR/dots/.config/matugen" ]]; then

    mkdir -p "$CONFIG_DIR/matugen"

    rsync -a \
        "$REPO_DIR/dots/.config/matugen/" \
        "$CONFIG_DIR/matugen/"

    success "Matugen configuration installed"
fi

if [[ -d "$REPO_DIR/dots/.config/fuzzel" ]]; then

    mkdir -p "$CONFIG_DIR/fuzzel"

    rsync -a \
        "$REPO_DI
