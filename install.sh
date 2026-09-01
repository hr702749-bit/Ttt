#!/usr/bin/env bash
set -e

echo "=== DankLinux + Niri + DMS Ubuntu installer ==="

if [ "$EUID" -eq 0 ]; then
    echo "Do not run this script as root."
    exit 1
fi

. /etc/os-release

if [ "${ID:-}" != "ubuntu" ]; then
    echo "ERROR: This script is intended for Ubuntu."
    exit 1
fi

if [ "${VERSION_ID:-}" != "26.04" ]; then
    echo "ERROR: DankLinux currently requires Ubuntu 26.04+."
    echo "Detected: Ubuntu ${VERSION_ID:-unknown}"
    exit 1
fi

echo
echo "[1/5] Checking sudo..."
sudo -v

echo
echo "[2/5] Installing repository management tools..."
sudo apt update
sudo apt install -y software-properties-common ca-certificates curl

echo
echo "[3/5] Adding DankLinux PPA..."
sudo add-apt-repository -y ppa:avengemedia/danklinux

echo
echo "[4/5] Adding DankMaterialShell PPA..."
sudo add-apt-repository -y ppa:avengemedia/dms

echo
echo "[5/5] Installing Niri + DMS..."
sudo apt update

sudo apt install -y \
    niri \
    dms \
    quickshell-git \
    matugen \
    cliphist \
    danksearch \
    dgop \
    dankcalendar-git

echo
echo "============================================================"
echo " Installation complete"
echo "============================================================"

echo
echo "Niri:"
niri --version || true

echo
echo "DMS:"
dms --version || true

echo
echo "QuickShell:"
quickshell --version || true

echo
echo "Installed packages:"
dpkg -l | grep -E \
    '(^ii\s+)(niri|dms|quickshell|matugen|cliphist|danksearch|dgop|dankcalendar)' \
    || true

echo
echo "Next step:"
echo "    dms setup"
echo
echo "Then log out and select Niri from your login screen."
