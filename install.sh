#!/bin/bash

set -e

echo "=========================================="
echo " WehttamSnaps-Niri Ubuntu Installer"
echo "=========================================="

if [ "$(id -u)" != "0" ]; then
    echo "Run with: sudo ./install.sh"
    exit 1
fi

if [ ! -f /etc/os-release ]; then
    echo "ERROR: Cannot detect Linux distribution."
    exit 1
fi

. /etc/os-release

if [ "$ID" != "ubuntu" ]; then
    echo "ERROR: This script requires Ubuntu."
    echo "Detected: $PRETTY_NAME"
    exit 1
fi

echo "[OK] $PRETTY_NAME"

echo
echo "[1/3] Updating package lists..."
apt-get update

echo
echo "[2/3] Installing Ubuntu dependencies..."

PACKAGES="git curl wget rsync jq ripgrep bc xdg-user-dirs wl-clipboard libnotify-bin xdg-desktop-portal xdg-desktop-portal-gtk policykit-1 network-manager gnome-keyring foot fuzzel swayidle swaylock grim slurp swappy ffmpeg imagemagick playerctl pavucontrol pipewire pipewire-pulse wireplumber brightnessctl ddcutil upower fontconfig fonts-dejavu fonts-liberation qt6-wayland qt6-base-dev qt6-declarative-dev qt6-svg-dev qt6-multimedia-dev qt6-positioning-dev qt6-tools-dev qt6-tools-dev-tools qml6-module-qt5compat-graphicaleffects qt6-image-formats-plugins qt6-virtualkeyboard kdialog qt6ct breeze xwayland tesseract-ocr tesseract-ocr-eng"

for PACKAGE in $PACKAGES; do
    if apt-cache show "$PACKAGE" >/dev/null 2>&1; then
        apt-get install -y "$PACKAGE"
    else
        echo "[SKIP] $PACKAGE is not available in Ubuntu."
    fi
done

echo
echo "[3/3] Finished."
echo
echo "Ubuntu dependencies installed."
echo
echo "Quickshell and Matugen are NOT installed yet."
echo "They require separate Ubuntu-compatible installation."
echo
echo "=========================================="
