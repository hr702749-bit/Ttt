#!/usr/bin/env bash
set -e

echo "== SPICE clipboard setup =="

sudo apt update
sudo apt install -y spice-vdagent

# The system daemon handles the SPICE channel.
sudo systemctl enable --now spice-vdagentd

echo
echo "SPICE daemon:"
systemctl --no-pager --full status spice-vdagentd || true

echo
echo "SPICE virtio ports:"
ls -la /dev/virtio-ports/ 2>/dev/null || echo "No virtio SPICE port found."

echo
echo "Setup complete."
echo "Clipboard will work after a graphical session (Niri/Wayland) is running."
echo "Do NOT try to enable 'spice-vdagent' as a systemd service; it is a user-session agent."
