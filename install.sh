#!/usr/bin/env bash

# File paths
ERROR_FILE="$HOME/error.txt"
CONFIG_DIR="$HOME/.config"
NIRI_RICE_DIR="$CONFIG_DIR/niri-rice"
II_DIR="$CONFIG_DIR/ii"
NIRI_DIR="$CONFIG_DIR/niri"
QUICKSHELL_DIR="$CONFIG_DIR/quickshell"

# Initialize error log
echo "=== Setup Error Log - $(date) ===" > "$ERROR_FILE"

log_error() {
    local cmd="$1"
    local reason="$2"
    echo "[ERROR] Command failed: '$cmd'" >> "$ERROR_FILE"
    echo "        Reason: $reason" >> "$ERROR_FILE"
    echo "----------------------------------------" >> "$ERROR_FILE"
}

run_step() {
    local title="$1"
    shift
    echo "==> $title..."
    if ! "$@"; then
        log_error "$*" "Failed during execution of '$title'"
        return 1
    fi
    return 0
}

# 1. Update and install base packages
echo "==> Updating apt and installing core system dependencies..."
sudo apt update -y
DEPS=(
    git build-essential cmake pkg-config libxkbcommon-dev libwayland-dev
    wayland-protocols libpam0g-dev libdbus-1-dev libgudev-1.0-dev libseat-dev
    libdisplay-info-dev libinput-dev libpipewire-0.3-dev pipewire wireplumber
    cliphist swayidle swaylock rofi-wayland foot qt6-base-dev qt6-declarative-dev
    qml6-module-qtquick-controls qml6-module-qtquick-layouts curl jq
)

for pkg in "${DEPS[@]}"; do
    if ! sudo apt install -y "$pkg" &>/dev/null; then
        log_error "apt install $pkg" "Package could not be installed via apt."
    fi
done

# 2. Rust & Cargo environment (Required for Niri & Matugen)
if ! command -v cargo &>/dev/null; then
    echo "==> Installing Rust ecosystem..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y &>/dev/null
    source "$HOME/.cargo/env"
fi

if command -v cargo &>/dev/null; then
    # Install Matugen
    if ! command -v matugen &>/dev/null; then
        echo "==> Building Matugen via cargo..."
        cargo install matugen &>/dev/null || log_error "cargo install matugen" "Matugen build failed."
    fi

    # Install Niri if not installed via apt
    if ! command -v niri &>/dev/null; then
        echo "==> Building Niri via cargo..."
        cargo install --locked niri &>/dev/null || log_error "cargo install niri" "Niri build failed."
    fi
else
    log_error "rustup/cargo" "Cargo is missing; skipped Matugen/Niri build."
fi

# 3. Clone Repository and fix file structure
echo "==> Setting up configuration directories..."
mkdir -p "$CONFIG_DIR"

if [ -d "$NIRI_RICE_DIR" ]; then
    rm -rf "$NIRI_RICE_DIR"
fi

if ! git clone https://github.com/Crowdrocker/WehttamSnaps-Niri.git "$NIRI_RICE_DIR"; then
    log_error "git clone" "Failed to clone Crowdrocker/WehttamSnaps-Niri repository."
else
    # Copy Niri Config
    mkdir -p "$NIRI_DIR"
    if [ -f "$NIRI_RICE_DIR/config.kdl" ]; then
        cp "$NIRI_RICE_DIR/config.kdl" "$NIRI_DIR/config.kdl"
    else
        log_error "cp config.kdl" "config.kdl not found in repository root."
    fi

    # Copy Quickshell files to modern path (~/.config/ii)
    mkdir -p "$II_DIR"
    if [ -d "$NIRI_RICE_DIR/shell" ]; then
        cp -r "$NIRI_RICE_DIR/shell/"* "$II_DIR/" 2>/dev/null || cp -r "$NIRI_RICE_DIR/"* "$II_DIR/"
    fi

    # Create symlink for legacy Quickshell paths (~/.config/quickshell/ii)
    mkdir -p "$QUICKSHELL_DIR"
    ln -sfn "$II_DIR" "$QUICKSHELL_DIR/ii"
fi

# 4. Enforce Material ii layout (Disable Waffle)
echo "==> Configuring Material ii layout and removing Waffle defaults..."
MODULES_JSON="$II_DIR/config/modules.json"
SETTINGS_JSON="$II_DIR/settings.json"

apply_material_theme() {
    local target_file="$1"
    if [ -f "$target_file" ]; then
        # Force panelFamily to "ii"
        sed -i 's/"panelFamily": *"[^"]*"/"panelFamily": "ii"/g' "$target_file"
    fi
}

apply_material_theme "$MODULES_JSON"
apply_material_theme "$SETTINGS_JSON"

# Remove keybinding to cycle to Waffle in config.kdl
if [ -f "$NIRI_DIR/config.kdl" ]; then
    sed -i '/panelFamily.*cycle/s/^/\/\//' "$NIRI_DIR/config.kdl"
    
    # Ensure auto-start for Quickshell is set to Material ii
    if ! grep -q "quickshell.*ii" "$NIRI_DIR/config.kdl"; then
        echo -e '\nspawn-at-startup "quickshell" "-c" "ii"' >> "$NIRI_DIR/config.kdl"
    fi
fi

# 5. Check Error Report & Boot Evaluation
ERR_COUNT=$(grep -c "\[ERROR\]" "$ERROR_FILE" 2>/dev/null || echo 0)

echo ""
echo "========================================"
if [ "$ERR_COUNT" -gt 0 ]; then
    echo " [!] Setup finished with $ERR_COUNT errors."
    echo " [!] Errors logged to: $ERROR_FILE"
    echo " [!] Displaying summary of issues:"
    echo ""
    cat "$ERROR_FILE"
    echo "========================================"
    echo "Boot skipped due to missing dependencies. Fix the issues in error.txt and run again."
else
    echo " [+] All setup steps completed successfully!"
    echo " [+] No critical errors detected."
    echo "========================================"
    read -p "Boot into Niri now? (y/n): " CHOICE
    if [[ "$CHOICE" =~ ^[Yy]$ ]]; then
        exec niri
    fi
fi
