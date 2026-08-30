#!/usr/bin/env bash

set -u

LOG="$HOME/vm-integration-report.txt"

PASS=0
FAIL=0
WARN=0

exec > >(tee "$LOG") 2>&1

pass() {
    echo "[ OK ] $1"
    PASS=$((PASS + 1))
}

fail() {
    echo "[FAIL] $1"
    FAIL=$((FAIL + 1))
}

warn() {
    echo "[WARN] $1"
    WARN=$((WARN + 1))
}

section() {
    echo
    echo "============================================================"
    echo "$1"
    echo "============================================================"
}

install_pkg() {
    local pkg="$1"

    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null |
        grep -q "install ok installed"; then
        pass "$pkg installed"
        return 0
    fi

    echo "[INFO] Installing $pkg..."

    if sudo apt install -y "$pkg"; then
        pass "$pkg installed successfully"
    else
        fail "$pkg installation failed"
        echo "CAUSE: APT could not install $pkg."
        return 1
    fi
}

# ============================================================
# SYSTEM
# ============================================================

section "SYSTEM"

if [ -f /etc/os-release ]; then
    . /etc/os-release

    echo "OS          : ${PRETTY_NAME:-unknown}"
    echo "Version     : ${VERSION_ID:-unknown}"
    echo "Codename    : ${VERSION_CODENAME:-unknown}"
else
    fail "/etc/os-release unavailable"
fi

echo "Kernel      : $(uname -r)"
echo "Architecture: $(uname -m)"
echo "Hostname    : $(hostname)"

# ============================================================
# APT
# ============================================================

section "APT"

if command -v apt >/dev/null 2>&1; then
    pass "APT available"
else
    fail "APT unavailable"
    exit 1
fi

if sudo apt update; then
    pass "APT repositories working"
else
    fail "APT update failed"
fi

# ============================================================
# SPICE
# ============================================================

section "SPICE GUEST INTEGRATION"

echo "Installing required SPICE packages..."

install_pkg spice-vdagent || true
install_pkg qemu-guest-agent || true

echo
echo "Checking spice-vdagent executable..."

if command -v spice-vdagent >/dev/null 2>&1; then
    pass "spice-vdagent executable exists"
    spice-vdagent --version 2>&1 | head -n 3 || true
else
    fail "spice-vdagent executable missing"
fi

# ============================================================
# SPICE VIRTIO CHANNEL
# ============================================================

section "SPICE VIRTIO CHANNEL"

if [ -d /dev/virtio-ports ]; then

    pass "/dev/virtio-ports exists"

    echo
    echo "Available virtio ports:"
    ls -la /dev/virtio-ports/

    if [ -e /dev/virtio-ports/com.redhat.spice.0 ]; then
        pass "SPICE channel com.redhat.spice.0 exists"
    else
        fail "SPICE channel com.redhat.spice.0 missing"

        echo
        echo "CAUSE:"
        echo "The VM kernel does not expose the SPICE agent channel."
        echo "Host-side SPICE may be configured, but the guest channel"
        echo "is not currently visible to Ubuntu."
    fi

else
    fail "/dev/virtio-ports does not exist"

    echo
    echo "CAUSE:"
    echo "The VM does not currently expose virtio-port devices."
fi

# ============================================================
# SESSION
# ============================================================

section "GRAPHICAL SESSION"

echo "XDG_SESSION_TYPE    : ${XDG_SESSION_TYPE:-not-set}"
echo "XDG_CURRENT_DESKTOP : ${XDG_CURRENT_DESKTOP:-not-set}"
echo "XDG_SESSION_DESKTOP : ${XDG_SESSION_DESKTOP:-not-set}"
echo "DISPLAY             : ${DISPLAY:-not-set}"
echo "WAYLAND_DISPLAY     : ${WAYLAND_DISPLAY:-not-set}"

if [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
    pass "Running Wayland session"
elif [ "${XDG_SESSION_TYPE:-}" = "x11" ]; then
    pass "Running X11 session"
else
    warn "No graphical session detected"
    echo "CAUSE: spice-vdagent needs a graphical user session."
fi

# ============================================================
# SPICE AGENT PROCESS
# ============================================================

section "SPICE AGENT PROCESS"

if pgrep -a spice-vdagent >/dev/null 2>&1; then
    pass "spice-vdagent is running"
    pgrep -a spice-vdagent
else
    fail "spice-vdagent is NOT running"

    echo
    echo "Trying to determine why..."

    if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
        echo "Graphical environment detected."
        echo "Attempting to start spice-vdagent..."

        if spice-vdagent >/tmp/spice-vdagent.log 2>&1 & then
            sleep 2

            if pgrep -a spice-vdagent >/dev/null 2>&1; then
                pass "spice-vdagent started successfully"
            else
                fail "spice-vdagent could not start"

                echo
                echo "Agent log:"
                cat /tmp/spice-vdagent.log 2>/dev/null || true
            fi
        fi
    else
        warn "Cannot start graphical SPICE agent from this session"
        echo "CAUSE: no graphical display is currently available."
    fi
fi

# ============================================================
# USER SYSTEMD
# ============================================================

section "USER SYSTEMD"

if command -v systemctl >/dev/null 2>&1; then

    echo "Checking user session..."

    if systemctl --user status >/dev/null 2>&1; then
        pass "User systemd session available"
    else
        warn "User systemd session unavailable"
    fi

    echo
    echo "SPICE-related user services:"

    systemctl --user --no-pager --all 2>/dev/null |
        grep -Ei 'spice|vdagent' |
        head -n 20 || true

else
    warn "systemctl unavailable"
fi

# ============================================================
# QEMU GUEST AGENT
# ============================================================

section "QEMU GUEST AGENT"

if systemctl list-unit-files 2>/dev/null |
    grep -q '^qemu-guest-agent.service'; then

    pass "qemu-guest-agent service exists"

    if sudo systemctl enable --now qemu-guest-agent 2>/dev/null; then
        pass "qemu-guest-agent enabled and running"
    else
        warn "qemu-guest-agent could not be started"
    fi

else
    warn "qemu-guest-agent service not found"
fi

# ============================================================
# CLIPBOARD
# ============================================================

section "WAYLAND CLIPBOARD"

install_pkg wl-clipboard || true

if command -v wl-copy >/dev/null 2>&1 &&
   command -v wl-paste >/dev/null 2>&1; then

    pass "wl-copy and wl-paste available"

else

    fail "Wayland clipboard commands unavailable"

fi

# ============================================================
# CLIPHIST
# ============================================================

section "CLIPHIST"

install_pkg cliphist || true

if command -v cliphist >/dev/null 2>&1; then
    pass "cliphist executable available"
else
    fail "cliphist executable unavailable"
fi

# ============================================================
# NIRI
# ============================================================

section "NIRI"

if command -v niri >/dev/null 2>&1; then

    pass "Niri installed"

    niri --version 2>&1 | head -n 3 || true

    if [ -f "$HOME/.config/niri/config.kdl" ]; then
        pass "Niri configuration exists"
    else
        warn "Niri configuration does not exist"
        echo "Expected:"
        echo "$HOME/.config/niri/config.kdl"
    fi

else

    warn "Niri not installed"

fi

# ============================================================
# QUICKSHELL
# ============================================================

section "QUICKSHELL"

if command -v quickshell >/dev/null 2>&1; then

    pass "QuickShell installed"

    quickshell --version 2>&1 | head -n 3 || true

else

    warn "QuickShell not installed"

fi

if [ -d "$HOME/.config/quickshell" ]; then
    pass "QuickShell configuration directory exists"
else
    warn "QuickShell configuration directory not found"
fi

# ============================================================
# PIPEWIRE
# ============================================================

section "PIPEWIRE"

install_pkg pipewire || true
install_pkg wireplumber || true
install_pkg pipewire-pulse || true

if command -v pipewire >/dev/null 2>&1; then
    pass "PipeWire executable available"
else
    fail "PipeWire executable missing"
fi

if command -v wireplumber >/dev/null 2>&1; then
    pass "WirePlumber executable available"
else
    fail "WirePlumber executable missing"
fi

if systemctl --user is-active --quiet pipewire.service 2>/dev/null; then
    pass "PipeWire user service running"
else
    warn "PipeWire user service not running"
fi

if systemctl --user is-active --quiet wireplumber.service 2>/dev/null; then
    pass "WirePlumber user service running"
else
    warn "WirePlumber user service not running"
fi

# ============================================================
# SCREEN CAPTURE
# ============================================================

section "SCREEN CAPTURE"

install_pkg grim || true
install_pkg slurp || true

if command -v grim >/dev/null 2>&1; then
    pass "grim available"
else
    fail "grim unavailable"
fi

if command -v slurp >/dev/null 2>&1; then
    pass "slurp available"
else
    fail "slurp unavailable"
fi

# ============================================================
# KDE / QT
# ============================================================

section "KDE / QT RUNTIME"

KDE_PACKAGES=(
    libkf6syntaxhighlighting6
    libkirigami6
    libkirigami-data
    kdialog
    plasma-browser-integration
    plasma-integration
)

for pkg in "${KDE_PACKAGES[@]}"; do
    install_pkg "$pkg" || true
done

# ============================================================
# KIRIGAMI CHECK
# ============================================================

section "KIRIGAMI"

if dpkg-query -W -f='${Status}' libkirigami6 2>/dev/null |
    grep -q "install ok installed"; then

    pass "Kirigami 6 runtime installed"
else
    fail "Kirigami 6 runtime missing"
fi

if dpkg-query -W -f='${Status}' libkirigami-dev 2>/dev/null |
    grep -q "install ok installed"; then

    pass "Kirigami development files installed"
else
    warn "Kirigami development files not installed"
fi

# ============================================================
# MATERIAL YOU
# ============================================================

section "PYTHON / MATERIALYOUCOLOR"

install_pkg python3 || true
install_pkg python3-venv || true
install_pkg python3-pip || true

if [ ! -d "$VENV" ]; then

    echo "Creating:"
    echo "$VENV"

    if python3 -m venv "$VENV"; then
        pass "Python virtual environment created"
    else
        fail "Could not create Python virtual environment"
    fi

else
    pass "Python virtual environment exists"
fi

if [ -x "$VENV/bin/python" ]; then

    pass "Venv Python exists"

    if "$VENV/bin/python" -c "import materialyoucolor" >/dev/null 2>&1; then

        pass "materialyoucolor installed"

    else

        warn "materialyoucolor missing"

        if "$VENV/bin/python" -m pip install materialyoucolor; then
            pass "materialyoucolor installed successfully"
        else
            fail "materialyoucolor installation failed"
        fi

    fi

    echo
    echo "Material You import test:"

    if "$VENV/bin/python" -c \
        "import materialyoucolor; print('materialyoucolor: OK')"; then

        pass "materialyoucolor import works"

    else

        fail "materialyoucolor import failed"

    fi

else

    fail "Venv Python unavailable"

fi

# ============================================================
# SPICE DEVICE PERMISSIONS
# ============================================================

section "SPICE DEVICE PERMISSIONS"

if [ -e /dev/virtio-ports/com.redhat.spice.0 ]; then

    ls -l /dev/virtio-ports/com.redhat.spice.0

    if [ -r /dev/virtio-ports/com.redhat.spice.0 ] &&
       [ -w /dev/virtio-ports/com.redhat.spice.0 ]; then

        pass "Current user can read/write SPICE channel"

    else

        warn "Current user cannot directly read/write SPICE channel"

        echo "CAUSE: device permissions may restrict the SPICE agent."
        echo
        echo "Device:"
        ls -l /dev/virtio-ports/com.redhat.spice.0
    fi

else

    fail "SPICE channel device unavailable"

fi

# ============================================================
# FINAL SPICE TEST
# ============================================================

section "FINAL SPICE CHECK"

if [ -e /dev/virtio-ports/com.redhat.spice.0 ]; then

    if pgrep -a spice-vdagent >/dev/null 2>&1; then

        pass "SPICE channel + spice-vdagent both available"

        echo
        echo "Clipboard integration prerequisites are present."

    else

        fail "SPICE channel exists but spice-vdagent is not running"

        echo
        echo "CAUSE:"
        echo "The VM has the SPICE communication channel, but the"
        echo "graphical SPICE agent isn't running."
    fi

else

    fail "SPICE channel unavailable"

    echo
    echo "CAUSE:"
    echo "Ubuntu cannot see the SPICE virtio channel."
    echo "This must be fixed at the VM device/session level."
fi

# ============================================================
# SUMMARY
# ============================================================

section "FINAL SUMMARY"

echo
echo "PASSED   : $PASS"
echo "WARNINGS : $WARN"
echo "FAILED   : $FAIL"
echo
echo "Full report:"
echo "$LOG"
echo

if [ "$FAIL" -eq 0 ]; then

    echo "============================================================"
    echo " VM INTEGRATION CHECK PASSED"
    echo "============================================================"

else

    echo "============================================================"
    echo " VM STILL HAS PROBLEMS"
    echo "============================================================"

    echo
    echo "Do not reinstall everything."
    echo "The failed checks above identify the remaining problem."

fi

echo
echo "Finished."
