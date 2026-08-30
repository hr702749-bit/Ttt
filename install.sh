#!/usr/bin/env bash

set -u

# ponytail: one diagnostic/repair script instead of manually chasing
# individual dependencies and CMake errors.

LOG="$HOME/niri-darkly-dependency-report.txt"
VENV="$HOME/.venvs/materialyou"
DARKLY_DIR="$HOME/Darkly"

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

apt_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null |
        grep -q "install ok installed"
}

install_apt() {
    local pkg="$1"

    if apt_installed "$pkg"; then
        pass "$pkg installed"
        return 0
    fi

    echo "[INFO] Installing $pkg..."

    if sudo apt install -y "$pkg"; then
        pass "$pkg installed"
        return 0
    fi

    fail "$pkg could not be installed"

    echo "CAUSE:"
    if apt-cache show "$pkg" >/dev/null 2>&1; then
        echo "APT knows this package, but installation failed."
        echo "Possible cause: dependency conflict, held package,"
        echo "broken package state, or repository problem."
    else
        echo "APT cannot find this package for this Ubuntu release."
        echo "Possible cause: wrong package name or missing repository."
    fi

    return 1
}

check_command() {
    local name="$1"
    local command="$2"

    echo
    echo "Checking $name..."

    if command -v "$command" >/dev/null 2>&1; then
        local path
        path="$(command -v "$command")"

        pass "$name executable found: $path"

        echo "Version:"
        "$command" --version 2>&1 | head -n 3 || true

        return 0
    fi

    fail "$name executable not found"
    echo "CAUSE: command '$command' is not in PATH."

    return 1
}

# ============================================================
# SYSTEM
# ============================================================

section "SYSTEM"

if [ -f /etc/os-release ]; then
    . /etc/os-release

    echo "OS           : ${PRETTY_NAME:-unknown}"
    echo "VERSION_ID   : ${VERSION_ID:-unknown}"
    echo "CODENAME     : ${VERSION_CODENAME:-unknown}"
else
    fail "/etc/os-release missing"
fi

echo "Architecture : $(dpkg --print-architecture 2>/dev/null || uname -m)"

if command -v sudo >/dev/null 2>&1; then
    pass "sudo available"
else
    fail "sudo not available"
fi

if command -v apt >/dev/null 2>&1; then
    pass "APT available"
else
    fail "APT unavailable"
    exit 1
fi

# ============================================================
# APT
# ============================================================

section "APT"

if sudo apt update; then
    pass "APT repository update successful"
else
    fail "APT repository update failed"
fi

# ============================================================
# NIRI
# ============================================================

section "NIRI"

if check_command "Niri" "niri"; then

    if niri --version >/dev/null 2>&1; then
        pass "Niri executable works"
    else
        fail "Niri executable exists but cannot run"
    fi

    if command -v niri-session >/dev/null 2>&1; then
        pass "niri-session found"
    else
        warn "niri-session not found"
    fi

else
    echo
    echo "Trying Ubuntu APT package..."

    if apt-cache show niri >/dev/null 2>&1; then
        install_apt niri || true
    else
        warn "Niri is not available from current APT repositories."
        echo "CAUSE: Niri usually requires the appropriate Niri/DankLinux"
        echo "repository or a manual installation on Ubuntu."
    fi
fi

# ============================================================
# QUICKSHELL
# ============================================================

section "QUICKSHELL"

if check_command "QuickShell" "quickshell"; then
    pass "QuickShell executable works"
else

    echo
    echo "Checking APT for QuickShell..."

    if apt-cache show quickshell >/dev/null 2>&1; then
        install_apt quickshell || true
    else
        warn "QuickShell not available from current APT repositories."
        echo "CAUSE: Ubuntu Resolute does not provide the package in its"
        echo "normal package set. It may need another repository or source."
    fi
fi

# ============================================================
# KDE / QT RUNTIME PACKAGES
# ============================================================

section "KDE / QT RUNTIME DEPENDENCIES"

RUNTIME_PACKAGES=(
    libkf6syntaxhighlighting6
    qml6-module-org-kde-syntaxhighlighting

    libkirigami6
    libkirigami-data

    kdialog

    wl-clipboard
    cliphist

    pipewire
    wireplumber
    pipewire-pulse

    grim
    slurp

    plasma-browser-integration
    plasma-integration
)

for pkg in "${RUNTIME_PACKAGES[@]}"; do
    install_apt "$pkg" || true
done

# ============================================================
# COMMAND CHECKS
# ============================================================

section "COMMAND LINE TOOLS"

check_command "kdialog" "kdialog" || true
check_command "wl-clipboard / wl-copy" "wl-copy" || true
check_command "cliphist" "cliphist" || true
check_command "grim" "grim" || true
check_command "slurp" "slurp" || true

# ============================================================
# PIPEWIRE
# ============================================================

section "PIPEWIRE / WIREPLUMBER"

if command -v pipewire >/dev/null 2>&1; then
    pass "PipeWire executable found"

    pipewire --version 2>&1 | head -n 2 || true
else
    fail "PipeWire executable missing"
fi

if command -v wireplumber >/dev/null 2>&1; then
    pass "WirePlumber executable found"

    wireplumber --version 2>&1 | head -n 2 || true
else
    fail "WirePlumber executable missing"
fi

if command -v systemctl >/dev/null 2>&1; then

    echo
    echo "User PipeWire service:"

    if systemctl --user is-active --quiet pipewire.service; then
        pass "PipeWire user service is running"
    else
        warn "PipeWire user service is not currently running"
        echo "This can be normal if you are running from a bare TTY/server."
    fi

    echo
    echo "User WirePlumber service:"

    if systemctl --user is-active --quiet wireplumber.service; then
        pass "WirePlumber user service is running"
    else
        warn "WirePlumber user service is not currently running"
        echo "This can be normal outside a graphical user session."
    fi

else
    warn "systemctl unavailable"
fi

# ============================================================
# WAYLAND
# ============================================================

section "WAYLAND"

if command -v wl-copy >/dev/null 2>&1 &&
   command -v wl-paste >/dev/null 2>&1; then

    pass "wl-clipboard provides wl-copy and wl-paste"

else
    fail "wl-clipboard commands incomplete"
fi

# ============================================================
# PYTHON
# ============================================================

section "PYTHON / MATERIALYOUCOLOR"

if command -v python3 >/dev/null 2>&1; then
    pass "Python 3 found"
    python3 --version
else
    fail "Python 3 not found"
fi

if python3 -m venv --help >/dev/null 2>&1; then
    pass "Python venv support available"
else
    fail "Python venv support unavailable"
    install_apt python3-venv || true
fi

if [ ! -d "$VENV" ]; then

    echo
    echo "Creating Python virtual environment:"
    echo "$VENV"

    if python3 -m venv "$VENV"; then
        pass "Python virtual environment created"
    else
        fail "Python virtual environment creation failed"
    fi

else
    pass "Python virtual environment exists"
fi

if [ -x "$VENV/bin/python" ]; then

    pass "Venv Python executable exists"

    echo
    echo "Venv Python:"
    "$VENV/bin/python" --version

    echo
    echo "Checking materialyoucolor..."

    if "$VENV/bin/python" -c "import materialyoucolor" >/dev/null 2>&1; then

        pass "materialyoucolor installed"

        "$VENV/bin/python" -c \
            "import materialyoucolor; print('materialyoucolor import: OK')"

    else

        warn "materialyoucolor missing"

        echo "Installing materialyoucolor into venv..."

        if "$VENV/bin/python" -m pip install materialyoucolor; then
            pass "materialyoucolor installed"
        else
            fail "materialyoucolor installation failed"
            echo "CAUSE: pip could not install the package."
        fi
    fi

else
    fail "Venv Python missing"
fi

# ============================================================
# PLASMA INTEGRATION
# ============================================================

section "PLASMA INTEGRATION"

for pkg in plasma-browser-integration plasma-integration; do

    if apt_installed "$pkg"; then
        pass "$pkg installed"
    else
        fail "$pkg not installed"
    fi

done

# ============================================================
# DARKLY
# ============================================================

section "DARKLY"

if [ -d "$DARKLY_DIR" ]; then
    pass "Darkly source directory found"

    if [ -f "$DARKLY_DIR/install.sh" ]; then
        pass "Darkly install.sh found"
    else
        warn "Darkly install.sh missing"
    fi
else
    warn "Darkly source directory not found"
    echo "Expected:"
    echo "$DARKLY_DIR"
fi

echo
echo "Checking Darkly Qt style..."

DARKLY_FOUND=0

DARKLY_PATHS=(
    "/usr/lib/x86_64-linux-gnu/qt6/plugins/styles"
    "/usr/lib/x86_64-linux-gnu/qt6/plugins/kstyle"
    "/usr/lib/x86_64-linux-gnu/qt6/plugins/kstyle_config"
    "$HOME/.local/lib/qt-6/plugins/styles"
    "$HOME/.local/lib/qt-6/plugins/kstyle"
    "$HOME/.local/lib/qt-6/plugins/kstyle_config"
    "$HOME/.local/lib/x86_64-linux-gnu/qt6/plugins/styles"
    "$HOME/.local/lib/x86_64-linux-gnu/qt6/plugins/kstyle"
    "$HOME/.local/lib/x86_64-linux-gnu/qt6/plugins/kstyle_config"
)

for path in "${DARKLY_PATHS[@]}"; do

    if [ -d "$path" ]; then

        if find "$path" -type f \
            \( -iname '*darkly*.so' -o -iname '*darkly*.desktop' \) \
            2>/dev/null | grep -q .; then

            pass "Darkly plugin found in $path"
            find "$path" -type f \
                \( -iname '*darkly*.so' -o -iname '*darkly*.desktop' \) \
                2>/dev/null

            DARKLY_FOUND=1
        fi
    fi
done

if [ "$DARKLY_FOUND" -eq 0 ]; then

    fail "Darkly Qt6 style plugin not found"

    echo "CAUSE:"
    echo "Darkly source may exist, but the installed Qt6 style plugin"
    echo "could not be found in the common system/user plugin locations."

    echo
    echo "Searching the entire filesystem for Darkly plugins..."
    find /usr /opt "$HOME/.local" \
        -type f \
        \( -iname '*darkly*.so' -o -iname '*darkly*.desktop' \) \
        2>/dev/null | head -n 30

else
    pass "Darkly appears to be installed"
fi

# ============================================================
# DARKLY CMAKE DEPENDENCIES
# ============================================================

section "DARKLY CMAKE DEPENDENCIES"

CMAKE_DIR="/usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)/cmake"

declare -A CMAKE_FILES

CMAKE_FILES["KF6CoreAddons"]="KF6CoreAddonsConfig.cmake"
CMAKE_FILES["KF6ColorScheme"]="KF6ColorSchemeConfig.cmake"
CMAKE_FILES["KF6Config"]="KF6ConfigConfig.cmake"
CMAKE_FILES["KF6ConfigWidgets"]="KF6ConfigWidgetsConfig.cmake"
CMAKE_FILES["KF6GuiAddons"]="KF6GuiAddonsConfig.cmake"
CMAKE_FILES["KF6I18n"]="KF6I18nConfig.cmake"
CMAKE_FILES["KF6IconThemes"]="KF6IconThemesConfig.cmake"
CMAKE_FILES["KF6KCMUtils"]="KF6KCMUtilsConfig.cmake"
CMAKE_FILES["KF6WindowSystem"]="KF6WindowSystemConfig.cmake"
CMAKE_FILES["KF6KirigamiPlatform"]="KF6KirigamiPlatformConfig.cmake"
CMAKE_FILES["KF6FrameworkIntegration"]="KF6FrameworkIntegrationConfig.cmake"
CMAKE_FILES["KDecorations3"]="KDecorations3Config.cmake"

for name in "${!CMAKE_FILES[@]}"; do

    file="${CMAKE_FILES[$name]}"

    found="$(
        find "$CMAKE_DIR" \
            -type f \
            -name "$file" \
            2>/dev/null |
        head -n 1
    )"

    if [ -n "$found" ]; then
        pass "$name CMake module found"
        echo "      $found"
    else
        fail "$name CMake module missing"
        echo "CAUSE: $file not found under $CMAKE_DIR"
    fi
done

# ============================================================
# REAL DARKLY CMAKE TEST
# ============================================================

section "REAL DARKLY QT6 CMAKE TEST"

if [ -d "$DARKLY_DIR" ] &&
   [ -f "$DARKLY_DIR/CMakeLists.txt" ]; then

    TEST_BUILD="$DARKLY_DIR/.dependency-test-build"

    rm -rf "$TEST_BUILD"
    mkdir -p "$TEST_BUILD"

    echo "Running Darkly CMake configuration."
    echo "This does NOT install Darkly."
    echo

    if cmake \
        -S "$DARKLY_DIR" \
        -B "$TEST_BUILD" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_TESTING=OFF \
        -DQT_MAJOR_VERSION=6; then

        pass "Darkly Qt6 CMake configuration succeeded"

    else

        fail "Darkly Qt6 CMake configuration failed"

        echo
        echo "CAUSE:"
        echo "At least one dependency is missing, incompatible,"
        echo "or unavailable to CMake."
    fi

else
    warn "Darkly CMake test skipped because source was not found"
fi

# ============================================================
# CONFIGURATION CHECK
# ============================================================

section "NIRI / QUICKSHELL CONFIGURATION"

echo "Niri config:"
if [ -f "$HOME/.config/niri/config.kdl" ]; then
    pass "Niri configuration exists"
    echo "$HOME/.config/niri/config.kdl"
else
    warn "Niri configuration not found"
fi

echo
echo "Quickshell config:"

if [ -d "$HOME/.config/quickshell" ]; then
    pass "Quickshell configuration directory exists"
    echo "$HOME/.config/quickshell"
else
    warn "Quickshell configuration directory not found"
fi

# ============================================================
# FINAL
# ============================================================

section "FINAL RESULT"

echo
echo "PASSED   : $PASS"
echo "WARNINGS : $WARN"
echo "FAILED   : $FAIL"
echo

echo "Report:"
echo "$LOG"

echo

if [ "$FAIL" -eq 0 ]; then

    echo "============================================================"
    echo " ALL REQUIRED CHECKS PASSED"
    echo "============================================================"

else

    echo "============================================================"
    echo " SOME DEPENDENCIES ARE NOT READY"
    echo "============================================================"

    echo
    echo "The report above contains the exact failed component"
    echo "and the reason it failed."

fi

echo
echo "Finished."
