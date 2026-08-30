#!/usr/bin/env bash

set -u

echo "============================================================"
echo " Ubuntu VM - GNOME Boxes Clipboard Setup"
echo "============================================================"
echo

# ------------------------------------------------------------
# Check Ubuntu
# ------------------------------------------------------------

if [ ! -f /etc/os-release ]; then
    echo "[FAIL] Cannot identify operating system."
    exit 1
fi

. /etc/os-release

echo "OS: ${PRETTY_NAME:-unknown}"
echo

if ! command -v apt >/dev/null 2>&1; then
    echo "[FAIL] This script requires Ubuntu/Debian with APT."
    exit 1
fi

# ------------------------------------------------------------
# Internet
# ------------------------------------------------------------

echo "[1/7] Checking network..."

if ping -c 1 -W 3 archive.ubuntu.com >/dev/null 2>&1; then
    echo "[ OK ] Internet connection works."
else
    echo "[WARN] Cannot reach archive.ubuntu.com."
    echo "       APT installation may fail."
fi

# ------------------------------------------------------------
# Update package lists
# ------------------------------------------------------------

echo
echo "[2/7] Updating APT..."

if sudo apt update; then
    echo "[ OK ] APT updated."
else
    echo "[FAIL] apt update failed."
    exit 1
fi

# ------------------------------------------------------------
# SPICE agent
# ------------------------------------------------------------

echo
echo "[3/7] Installing SPICE clipboard agent..."

if sudo apt install -y spice-vdagent; then
    echo "[ OK ] spice-vdagent installed."
else
    echo "[FAIL] Could not install spice-vdagent."
    echo
    echo "APT error above explains the cause."
    exit 1
fi

# ------------------------------------------------------------
# QEMU guest agent
# ------------------------------------------------------------

echo
echo "[4/7] Installing QEMU guest agent..."

if sudo apt install -y qemu-guest-agent; then
    echo "[ OK ] qemu-guest-agent installed."
else
    echo "[WARN] qemu-guest-agent could not be installed."
    echo "       This is not required for clipboard sharing."
fi

# ------------------------------------------------------------
# Verify SPICE agent
# ------------------------------------------------------------

echo
echo "[5/7] Verifying SPICE agent..."

if command -v spice-vdagent >/dev/null 2>&1; then
    echo "[ OK ] spice-vdagent executable exists."
    echo
    spice-vdagent --version 2>&1 || true
else
    echo "[FAIL] spice-vdagent executable not found."
fi

# ------------------------------------------------------------
# Verify service/session
# ------------------------------------------------------------

echo
echo "[6/7] Checking SPICE agent process..."

if pgrep -x spice-vdagent >/dev/null 2>&1; then
    echo "[ OK ] spice-vdagent is currently running."
else
    echo "[WARN] spice-vdagent is not currently running."
    echo
    echo "This is normal if you are currently in a TTY/server"
    echo "session without a graphical desktop."
    echo
    echo "When you start your graphical Ubuntu session, the"
    echo "SPICE agent should start for that user session."
fi

# ------------------------------------------------------------
# QEMU service
# ------------------------------------------------------------

echo
echo "[7/7] Checking QEMU guest agent..."

if systemctl list-unit-files 2>/dev/null |
   grep -q '^qemu-guest-agent.service'; then

    echo "[ OK ] qemu-guest-agent service exists."

    if sudo systemctl enable --now qemu-guest-agent 2>/dev/null; then
        echo "[ OK ] qemu-guest-agent enabled and started."
    else
        echo "[WARN] qemu-guest-agent could not be started."
        echo "       Clipboard does not depend on this."
    fi
else
    echo "[WARN] qemu-guest-agent service not found."
fi

# ------------------------------------------------------------
# Final
# ------------------------------------------------------------

echo
echo "============================================================"
echo " SETUP COMPLETE"
echo "============================================================"
echo
echo "SPICE clipboard agent:"

if command -v spice-vdagent >/dev/null 2>&1; then
    echo "[ OK ] Installed"
else
    echo "[FAIL] Missing"
fi

echo
echo "IMPORTANT:"
echo
echo "1. Shut down the VM completely."
echo "2. Close/reopen it in GNOME Boxes."
echo "3. Start the Ubuntu graphical session."
echo "4. Test copying text from the host into the VM."
echo "5. Test copying text from the VM back to the host."
echo
echo "If clipboard still does not work, run:"
echo
echo "    pgrep -a spice-vdagent"
echo
echo "and:"
echo
echo "    echo \$XDG_SESSION_TYPE"
echo
echo "============================================================"
