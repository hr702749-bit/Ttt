
#!/usr/bin/env bash
set -u

echo "=========================================="
echo " WehttamSnaps-Niri — Ubuntu Installer"
echo "=========================================="

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] Run with sudo:"
    echo "sudo ./install.sh"
    exit 1
fi

if [ ! -f /etc/os-release ]; then
    echo "[ERROR] Cannot detect operating system."
    exit 1
fi

. /etc/os-release

if [ "${ID:-}" != "ubuntu" ]; then
    echo "[ERROR] This installer is for Ubuntu."
    echo "Detected: ${PRETTY_NAME:-unknown}"
    exit 1
fi

echo "[OK] Detected: $PRETTY_NAME"

echo
echo "[1/4] Updating package lists..."
apt-get update || {
    echo "[ERROR] apt update failed."
    exit 1
}

# Ubuntu package equivalents for the project's basic runtime.
PACKAGES=(
    git
    curl
    wget
    rsync
    jq
    ripgrep
    bc
    coreutils
    xdg-user-dirs
    wl-clipboard
    libnotify-bin
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    policykit-1
    network-manager
    gnome-keyring
    foot
    fuzzel
    swayidle
    swaylock
    grim
    slurp
    swappy
    ffmpeg
    imagemagick
    playerctl
    pavucontrol
    pipewire
    pipewire-pulse
    wireplumber
    brightnessctl
    ddcutil
    upower
    fontconfig
    fonts-dejavu
    fonts-liberation
    qt6-wayland
    qt6-base-dev
    qt6-declarative-dev
    qt6-svg-dev
    qt6-multimedia-dev
    qt6-positioning-dev
    qt6-tools-dev
    qt6-tools-dev-tools
    qml6-module-qt5compat-graphicaleffects
    qt6-image-formats-plugins
    qt6-virtualkeyboard
    libkf6kirigami-dev
    kdialog
    syntax-highlighting
    qt6ct
    kde-config-gtk-style
    breeze
    xwayland
    tesseract-ocr
    tesseract-ocr-eng
)

echo
echo "[2/4] Checking Ubuntu packages..."

AVAILABLE=()
MISSING=()

for package in "${PACKAGES[@]}"; do
    if apt-cache show "$package" >/dev/null 2>&1; then
        AVAILABLE+=("$package")
    else
        MISSING+=("$package")
    fi
done

echo
echo "[3/4] Installing available packages..."

if [ "${#AVAILABLE[@]}" -gt 0 ]; then
    apt-get install -y "${AVAILABLE[@]}" || {
        echo
        echo "[ERROR] APT installation failed."
        exit 1
    }
fi

echo
echo "[4/4] Result"
echo "=========================================="

if [ "${#MISSING[@]}" -gt 0 ]; then
    echo
    echo "[WARN] These packages are not available under these names:"
    printf '  - %s\n' "${MISSING[@]}"
    echo
    echo "They need Ubuntu-specific alternatives or another installation method."
else
    echo "[OK] All requested Ubuntu packages were found."
fi

echo
echo "Base dependency installation completed."
echo
echo "IMPORTANT:"
echo "Quickshell and Matugen are handled separately because"
echo "the Arch/AUR packages used by WehttamSnaps-Niri do not"
echo "map directly to normal Ubuntu packages."
echo
echo "=========================================="