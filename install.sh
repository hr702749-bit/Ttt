#!/usr/bin/env bash

echo "======================================"
echo " WehttamSnaps-Niri Ubuntu Pre-Check"
echo "======================================"
echo

echo "== System =="
cat /etc/os-release | grep -E '^(NAME|VERSION|VERSION_ID)='
echo "Kernel: $(uname -r)"
echo

echo "== Desktop / Session =="
echo "XDG_CURRENT_DESKTOP: ${XDG_CURRENT_DESKTOP:-not set}"
echo "XDG_SESSION_TYPE:    ${XDG_SESSION_TYPE:-not set}"
echo "XDG_SESSION_DESKTOP:  ${XDG_SESSION_DESKTOP:-not set}"
echo

echo "== Required commands =="
for cmd in niri quickshell git curl wget jq \
           systemctl dbus-run-session \
           wayland-info; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "[YES] $cmd -> $(command -v "$cmd")"
    else
        echo "[NO ] $cmd"
    fi
done
echo

echo "== Important packages =="
for pkg in \
    niri \
    quickshell \
    git \
    curl \
    wget \
    jq \
    dbus \
    pipewire \
    wireplumber \
    xwayland \
    polkit \
    network-manager \
    playerctl; do

    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | \
       grep -q "install ok installed"; then
        echo "[YES] $pkg"
    else
        echo "[NO ] $pkg"
    fi
done
echo

echo "== Niri config =="
if [ -d "$HOME/.config/niri" ]; then
    echo "[YES] ~/.config/niri"
    find "$HOME/.config/niri" -maxdepth 2 -type f -print
else
    echo "[NO ] ~/.config/niri"
fi
echo

echo "== Quickshell config =="
if [ -d "$HOME/.config/quickshell" ]; then
    echo "[YES] ~/.config/quickshell"
    find "$HOME/.config/quickshell" -maxdepth 3 -type f -print
else
    echo "[NO ] ~/.config/quickshell"
fi
echo

echo "== Common dependencies =="
for cmd in \
    fuzzel \
    rofi \
    wofi \
    swaylock \
    swayidle \
    grim \
    slurp \
    wl-copy \
    wl-paste \
    brightnessctl \
    pamixer \
    playerctl; do

    if command -v "$cmd" >/dev/null 2>&1; then
        echo "[YES] $cmd"
    else
        echo "[NO ] $cmd"
    fi
done
echo

echo "== systemd user session =="
if systemctl --user is-system-running >/dev/null 2>&1; then
    echo "[YES] systemd user session working"
    systemctl --user is-system-running
else
    echo "[NO ] systemd user session unavailable"
fi
echo

echo "== GPU =="
if command -v lspci >/dev/null 2>&1; then
    lspci | grep -Ei 'vga|3d|display' || echo "GPU not detected"
else
    echo "[NO ] lspci"
fi
echo

echo "== RAM / Disk =="
free -h
echo
df -h "$HOME"
echo

echo "======================================"
echo " Inspection complete"
echo " No system changes were made."
echo "======================================"
