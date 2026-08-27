#!/usr/bin/env bash
set -u
LOG="$HOME/inir-ubuntu-install.log"
exec > >(tee -a "$LOG") 2>&1
[ "$(id -u)" -ne 0 ] || { echo "Run as your normal user, not root."; exit 1; }
. /etc/os-release
[ "${VERSION_ID:-}" = "26.04" ] || { echo "This script is for Ubuntu 26.04 LTS."; exit 1; }

echo "=== Ubuntu 26.04 + Niri + iNiR ==="
sudo apt-get update
sudo apt-get install -y git curl wget ca-certificates software-properties-common build-essential pkg-config cmake ninja-build meson rustc cargo python3 python3-pip python3-venv bc coreutils rsync jq ripgrep xdg-user-dirs xdg-utils wl-clipboard cliphist libnotify-bin xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-gnome network-manager network-manager-gnome gnome-keyring polkitd gdm3 dbus-user-session pipewire pipewire-pulse wireplumber nautilus foot fish fuzzel dunst pavucontrol playerctl brightnessctl swayidle grim slurp fonts-dejavu fonts-liberation fontconfig qt6-base-dev qt6-declarative-dev qt6-wayland qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts qml6-module-qtquick-effects qml6-module-qtquick-dialogs qml6-module-qtquick-shapes qml6-module-qtquick-window qml6-module-qtqml qml6-module-qtqml-models qml6-module-qt5compat-graphicaleffects || true

sudo add-apt-repository -y ppa:avengemedia/danklinux || true
sudo apt-get update
sudo apt-get install -y niri quickshell xwayland-satellite || true
sudo apt-get install -y udiskie blueman mate-polkit libglib2.0-bin kdialog syntax-highlighting || true

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/inir-backup-$STAMP"
mkdir -p "$BACKUP"
for d in "$HOME/.config/niri" "$HOME/.config/quickshell/inir" "$HOME/.config/illogical-impulse" "$HOME/.config/inir"; do
  [ -e "$d" ] && cp -a "$d" "$BACKUP/"
done

REPO="$HOME/inir"
if [ -d "$REPO/.git" ]; then
  git -C "$REPO" fetch --depth=1 origin main
  git -C "$REPO" reset --hard origin/main
else
  rm -rf "$REPO"
  git clone --depth=1 https://github.com/snowarch/inir.git "$REPO"
fi
cd "$REPO"

echo "=== iNiR setup ==="
if ./setup install -y; then
  echo "[OK] iNiR setup completed"
else
  echo "[WARN] iNiR setup failed; trying local package install"
  sudo make install || true
fi

export PATH="$HOME/.local/bin:$PATH"
if [ -x "$REPO/scripts/inir" ]; then
  mkdir -p "$HOME/.local/bin"
  ln -sf "$REPO/scripts/inir" "$HOME/.local/bin/inir"
fi

if command -v inir >/dev/null 2>&1; then
  echo "=== iNiR doctor ==="
  inir doctor || true
  echo "=== iNiR status ==="
  inir status || true
  echo "=== iNiR service ==="
  inir service enable || true
fi

sudo systemctl enable gdm3 2>/dev/null || true
sudo systemctl set-default graphical.target 2>/dev/null || true
sudo systemctl enable --now NetworkManager 2>/dev/null || true
systemctl --user daemon-reload 2>/dev/null || true

echo "=== Niri validation ==="
command -v niri >/dev/null 2>&1 && niri validate || true

echo
echo "=== FINAL ==="
echo "niri: $(command -v niri || echo MISSING)"
echo "quickshell: $(command -v qs || echo MISSING)"
echo "inir: $(command -v inir || echo MISSING)"
echo "backup: $BACKUP"
echo "log: $LOG"
echo
echo "If the three commands exist, reboot with: sudo reboot"
echo "At GDM select Niri."
echo "Do not add spawn-at-startup for iNiR; its service starts with Niri."
