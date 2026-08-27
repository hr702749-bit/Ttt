#!/usr/bin/env bash
set -u

# WehttamSnaps-Niri Ubuntu 26.04 bootstrap
# Intended for a fresh Ubuntu 26.04 LTS Server/minimal VM.
# Re-runnable: existing packages/configs are preserved.

REPO="https://github.com/Crowdrocker/WehttamSnaps-Niri.git"
WORK="$HOME/WehttamSnaps-Niri"
LOG="$HOME/wehttamsnaps-install.log"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

exec > >(tee -a "$LOG") 2>&1

ok()   { printf '\033[32m[OK]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$*"; }
die()  { printf '\033[31m[ERROR]\033[0m %s\n' "$*"; exit 1; }

[ "$(id -u)" -ne 0 ] || die "Run this as your normal Ubuntu user, not root."
command -v sudo >/dev/null || die "sudo is missing. Install it first with: su -c 'apt install sudo'"

echo "============================================================"
echo " WehttamSnaps-Niri / Ubuntu 26.04 setup"
echo " Log: $LOG"
echo "============================================================"

# Confirm Ubuntu.
. /etc/os-release
[ "${ID:-}" = "ubuntu" ] || die "This script is for Ubuntu."
case "${VERSION_ID:-}" in
  26.04) ok "Ubuntu 26.04 detected." ;;
  *) warn "Detected Ubuntu ${VERSION_ID:-unknown}; this script is tuned for Ubuntu 26.04." ;;
esac

echo
echo "[1/9] Enabling required Ubuntu repositories..."
sudo apt-get update
sudo apt-get install -y software-properties-common ca-certificates curl git rsync
sudo add-apt-repository -y universe || true
sudo apt-get update

echo
echo "[2/9] Adding the DankLinux PPA..."
if ! grep -Rqs 'ppa.launchpadcontent.net/avengemedia/danklinux' /etc/apt/sources.list.d /etc/apt/sources.list 2>/dev/null; then
    sudo add-apt-repository -y ppa:avengemedia/danklinux || true
fi
sudo apt-get update

echo
echo "[3/9] Installing Niri, Quickshell and core desktop dependencies..."

# Package names are checked before installation. Ubuntu package names differ
# from the Arch names used by the upstream theme documentation.
PACKAGES=(
  niri quickshell-git matugen cliphist wl-clipboard
  xwayland-satellite
  xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-gnome
  gnome-keyring
  polkitd policykit-1
  network-manager
  dbus-user-session
  pipewire pipewire-pulse wireplumber
  libpipewire-0.3-0
  grim slurp swappy wf-recorder
  imagemagick ffmpeg
  tesseract-ocr tesseract-ocr-eng
  playerctl pavucontrol
  upower wtype ydotool brightnessctl ddcutil
  swayidle
  fuzzel
  foot
  libnotify-bin
  fontconfig fonts-dejavu fonts-liberation fonts-jetbrains-mono
  fonts-rubik fonts-readex-pro
  qt6ct
  git curl wget jq ripgrep bc rsync
  python3 python3-venv python3-pip
  gdm3
  spice-vdagent
)

AVAILABLE=()
MISSING=()

for p in "${PACKAGES[@]}"; do
    if dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q 'install ok installed'; then
        continue
    fi
    if apt-cache show "$p" >/dev/null 2>&1; then
        AVAILABLE+=("$p")
    else
        MISSING+=("$p")
    fi
done

if [ "${#AVAILABLE[@]}" -gt 0 ]; then
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${AVAILABLE[@]}" || {
        warn "Some packages failed. Retrying individually."
        for p in "${AVAILABLE[@]}"; do
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$p" || warn "Could not install: $p"
        done
    }
fi

[ "${#MISSING[@]}" -eq 0 ] || warn "Unavailable on this Ubuntu repository: ${MISSING[*]}"

echo
echo "[4/9] Configuring services..."
sudo systemctl enable --now NetworkManager 2>/dev/null || true
sudo systemctl enable --now spice-vdagentd 2>/dev/null || true
sudo systemctl enable gdm3 2>/dev/null || true
sudo systemctl set-default graphical.target 2>/dev/null || true

# Niri's systemd user session can need lingering/user-runtime support.
loginctl enable-linger "$USER" 2>/dev/null || true

echo
echo "[5/9] Preparing user directories..."
mkdir -p "$XDG_CONFIG_HOME"
mkdir -p "$HOME/.local/bin" "$HOME/.local/share" "$HOME/.local/state"

echo
echo "[6/9] Downloading the complete WehttamSnaps-Niri repository..."
if [ -d "$WORK/.git" ]; then
    git -C "$WORK" fetch --depth=1 origin main || true
    git -C "$WORK" reset --hard origin/main || true
else
    rm -rf "$WORK"
    git clone --depth=1 "$REPO" "$WORK" || die "Could not clone the theme repository."
fi
ok "Repository downloaded."

echo
echo "[7/9] Installing the theme files..."
# Upstream's manual instructions use ~/.config/quickshell/ii.
# The current repository's setup script also synchronizes these directories.
mkdir -p "$XDG_CONFIG_HOME/quickshell/ii"

for f in "$WORK"/*.qml; do
    [ -f "$f" ] && cp -f "$f" "$XDG_CONFIG_HOME/quickshell/ii/"
done

for d in modules services scripts assets translations; do
    if [ -d "$WORK/$d" ]; then
        mkdir -p "$XDG_CONFIG_HOME/quickshell/ii/$d"
        rsync -a "$WORK/$d/" "$XDG_CONFIG_HOME/quickshell/ii/$d/"
    fi
done

# Install the repository's ~/.config files without deleting existing user files.
if [ -d "$WORK/dots/.config" ]; then
    rsync -a "$WORK/dots/.config/" "$XDG_CONFIG_HOME/"
fi

# Some repository layouts put Niri files elsewhere; install those if present.
if [ -d "$WORK/dots/.config/niri" ]; then
    mkdir -p "$XDG_CONFIG_HOME/niri"
    rsync -a "$WORK/dots/.config/niri/" "$XDG_CONFIG_HOME/niri/"
fi

# Ensure Niri starts the ii Quickshell configuration.
NIRI_CFG="$XDG_CONFIG_HOME/niri/config.kdl"
if [ -f "$NIRI_CFG" ]; then
    if ! grep -Fq 'spawn-at-startup "qs" "-c" "ii"' "$NIRI_CFG"; then
        printf '\n// WehttamSnaps-Niri\nspawn-at-startup "qs" "-c" "ii"\n' >> "$NIRI_CFG"
    fi
else
    mkdir -p "$XDG_CONFIG_HOME/niri"
    cat > "$NIRI_CFG" <<'KDL'
input {
    keyboard {
    }
}

layout {
    gaps 8
}

spawn-at-startup "qs" "-c" "ii"
KDL
fi

# Make theme scripts executable.
find "$XDG_CONFIG_HOME/quickshell/ii/scripts" \
    -type f \( -name '*.sh' -o -name '*.py' -o -name '*.fish' \) \
    -exec chmod +x {} + 2>/dev/null || true

echo
echo "[8/9] Installing the theme's Python requirements..."
PYENV="$HOME/.local/state/wehttamsnaps-venv"
python3 -m venv "$PYENV" 2>/dev/null || true
if [ -x "$PYENV/bin/python" ] && [ -f "$WORK/requirements.txt" ]; then
    "$PYENV/bin/python" -m pip install --upgrade pip
    "$PYENV/bin/python" -m pip install -r "$WORK/requirements.txt" || \
        warn "Some Python requirements could not be installed."
fi

# Make the venv available to the user's shell without changing system Python.
mkdir -p "$HOME/.local/bin"
ln -sf "$PYENV/bin/python" "$HOME/.local/bin/wehttamsnaps-python"

echo
echo "[9/9] Final health checks..."

check_cmd() {
    if command -v "$1" >/dev/null 2>&1; then
        ok "$1: $(command -v "$1")"
    else
        warn "$1: MISSING"
    fi
}

for c in niri qs quickshell-git matugen cliphist wl-copy wl-paste xwayland-satellite \
         grim slurp fuzzel foot; do
    check_cmd "$c"
done

if [ -f "$NIRI_CFG" ]; then
    if command -v niri >/dev/null 2>&1; then
        niri validate 2>&1 || warn "Niri config validation reported an error."
    fi
fi

echo
echo "============================================================"
echo " INSTALLATION FINISHED"
echo "============================================================"
echo
echo "Repository: $WORK"
echo "Theme:      $XDG_CONFIG_HOME/quickshell/ii"
echo "Niri:       $NIRI_CFG"
echo "Log:        $LOG"
echo
echo "Important:"
echo "  1. Reboot the VM."
echo "  2. At the GDM login screen select Niri."
echo "  3. Log in normally."
echo
echo "If something is unavailable, the script continues and records it"
echo "instead of stopping at the first missing Ubuntu package."
echo
echo "For troubleshooting later:"
echo "  journalctl --user -u niri.service -b"
echo "  qs log -c ii"
echo
