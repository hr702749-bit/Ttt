#!/usr/bin/env bash
set -euo pipefail

echo "==> Checking Ubuntu version..."

if ! grep -qE 'VERSION_ID="26\.04"|VERSION_ID="26\.10"' /etc/os-release; then
    echo "ERROR: This script is intended for Ubuntu 26.04+."
    . /etc/os-release
    echo "Detected: ${PRETTY_NAME}"
    exit 1
fi

echo "==> Updating base system..."
sudo apt update
sudo apt full-upgrade -y

echo "==> Installing basic package infrastructure..."
sudo apt install -y \
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    build-essential \
    pkg-config \
    cmake \
    ninja-build \
    unzip \
    jq

echo "==> Enabling required Ubuntu repositories..."
sudo add-apt-repository -y universe
sudo add-apt-repository -y multiverse

sudo apt update

echo "==> Installing Wayland / desktop foundation..."
sudo apt install -y \
    dbus \
    dbus-user-session \
    systemd \
    systemd-sysv \
    xwayland \
    xdg-utils \
    xdg-user-dirs \
    xdg-desktop-portal \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-kde \
    polkitd \
    policykit-1 \
    accountsservice \
    seatd

echo "==> Installing Wayland utilities..."
sudo apt install -y \
    wl-clipboard \
    cliphist \
    grim \
    slurp

echo "==> Installing PipeWire / WirePlumber..."
sudo apt install -y \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    wireplumber \
    libspa-0.2-bluetooth

echo "==> Enabling PipeWire user services..."
systemctl --user enable pipewire.service || true
systemctl --user enable pipewire-pulse.service || true
systemctl --user enable wireplumber.service || true

echo "==> Installing Qt6 / KDE / Kirigami dependencies..."
sudo apt install -y \
    qt6-base-dev \
    qt6-declarative-dev \
    qt6-wayland \
    qt6-tools-dev \
    qt6-tools-dev-tools \
    qt6-shadertools-dev \
    libqt6core6 \
    libqt6gui6 \
    libqt6qml6 \
    libqt6quick6 \
    libqt6quickcontrols2-6 \
    libqt6quicktemplates2-6 \
    libqt6waylandclient6 \
    libqt6dbus6 \
    libqt6svg6 \
    libqt6widgets6 \
    qml6-module-qtquick \
    qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts \
    qml6-module-qtquick-window \
    qml6-module-qtqml \
    qml6-module-qtqml-models \
    qml6-module-qt-labs-settings \
    kirigami2-dev \
    kdialog

echo "==> Installing Qt/KDE integration..."
sudo apt install -y \
    plasma-integration \
    plasma-browser-integration \
    kde-cli-tools \
    breeze \
    breeze-icon-theme \
    oxygen-icon-theme

echo "==> Installing fonts..."
sudo apt install -y \
    fonts-noto \
    fonts-noto-color-emoji \
    fonts-noto-mono \
    fonts-dejavu \
    fontconfig

echo "==> Installing Material You / theming prerequisites..."
sudo apt install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-yaml \
    python3-pillow

echo "==> Refreshing font cache..."
fc-cache -fv

echo "==> Adding DankLinux repository..."
sudo add-apt-repository -y ppa:avengemedia/danklinux

echo "==> Updating package lists..."
sudo apt update

echo "==> Installing Niri + Quickshell + Matugen + Cliphist..."
sudo apt install -y \
    niri \
    quickshell-git \
    matugen \
    cliphist

echo "==> Installing additional Niri/Quickshell runtime dependencies..."
sudo apt install -y \
    cava \
    brightnessctl \
    playerctl \
    pavucontrol \
    network-manager \
    network-manager-gnome \
    bluez \
    blueman \
    grim \
    slurp \
    wl-clipboard

echo "==> Installing XDG desktop portals..."
sudo apt install -y \
    xdg-desktop-portal \
    xdg-desktop-portal-gtk \
    xdg-desktop-portal-kde

echo "==> Creating user directories..."
xdg-user-dirs-update || true

echo "==> Enabling NetworkManager..."
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager || true

echo "==> Installing DankMaterialShell using official Dank installer..."
sudo -v

curl -fsSL https://install.danklinux.com | sh -s -- \
    -c niri \
    -t alacritty \
    -y

echo "==> Refreshing user services..."
systemctl --user daemon-reload || true

echo
echo "=========================================="
echo " INSTALLATION COMPLETE"
echo "=========================================="
echo
echo "Installed:"
echo "  Niri"
echo "  Quickshell"
echo "  DankMaterialShell"
echo "  Matugen / Material You"
echo "  Kirigami"
echo "  KDialog"
echo "  Plasma integration"
echo "  Plasma browser integration"
echo "  wl-clipboard"
echo "  Cliphist"
echo "  PipeWire"
echo "  WirePlumber"
echo "  Grim"
echo "  Slurp"
echo "  KDE/Qt runtime"
echo
echo "Reboot is recommended."
echo
read -rp "Reboot now? [y/N] " answer

if [[ "$answer" =~ ^[Yy]$ ]]; then
    sudo reboot
fi
