#!/usr/bin/env bash

echo "============================================================"
echo " GNOME BOXES / SPICE CHECK"
echo "============================================================"
echo

URI="qemu:///session"

echo "[1] Libvirt connection:"
virsh -c "$URI" uri

echo
echo "[2] Running VMs:"
virsh -c "$URI" list --all

echo
echo "[3] Detecting VM..."

VM_NAME="$(virsh -c "$URI" list --name | sed '/^$/d' | head -n 1)"

if [ -z "$VM_NAME" ]; then
    echo "[FAIL] No running VM found."
    exit 1
fi

echo "[ OK ] VM:"
echo "$VM_NAME"

echo
echo "[4] Checking SPICE graphics..."

XML="$(virsh -c "$URI" dumpxml "$VM_NAME")"

if echo "$XML" | grep -q "graphics type=.spice."; then
    echo "[ OK ] SPICE graphics detected."
else
    echo "[FAIL] SPICE graphics NOT detected."
    echo
    echo "CAUSE:"
    echo "GNOME Boxes VM does not appear to expose a SPICE display."
fi

echo
echo "[5] Checking SPICE channel..."

if echo "$XML" | grep -q "spicevmc"; then
    echo "[ OK ] SPICE VM channel detected."
else
    echo "[FAIL] SPICE VM channel NOT detected."
    echo
    echo "CAUSE:"
    echo "The guest does not appear to have a SPICE agent channel."
fi

echo
echo "[6] Complete SPICE configuration:"
echo

echo "$XML" | grep -E \
    "graphics|channel|spice|virtio" |
    sed 's/^/    /'

echo
echo "============================================================"
echo " CHECK COMPLETE"
echo "============================================================"
