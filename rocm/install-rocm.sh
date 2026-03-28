#!/bin/bash
# ============================================================================
# ROCm installer for AMD RX 6800 (gfx1030) on Arch Linux
#
# Sets up ROCm with the correct overrides for unofficial RDNA2 support.
# Safe to re-run — each step checks state before acting.
#
# Usage:
#   chmod +x install-rocm.sh && ./install-rocm.sh
# ============================================================================

set -uo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
NC='\033[0m'

ISSUES=()

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; ISSUES+=("WARN: $1"); }
err()   { echo -e "${RED}[ERROR]${NC} $1"; ISSUES+=("ERROR: $1"); }
skip()  { echo -e "${GRAY}[SKIP]${NC} $1"; }

# ============================================================================
# Pre-flight checks
# ============================================================================

if ! command -v pacman &>/dev/null; then
    err "This script is for Arch Linux only."
    exit 1
fi

# Check for AMD GPU
if ! lspci | grep -qi "AMD.*Navi\|AMD.*RX\|AMD.*Radeon"; then
    warn "No AMD GPU detected via lspci — continuing anyway"
fi

echo ""
echo "============================================"
echo "  ROCm installer for AMD RX 6800"
echo "  (gfx1030 / Navi 21 / RDNA2)"
echo "============================================"
echo ""

# ============================================================================
# Step 1: Install ROCm packages
# ============================================================================

info "Step 1/5: Installing ROCm packages..."

ROCM_PACKAGES=(
    rocm-hip-sdk
    rocm-opencl-sdk
    rocm-smi-lib
    clinfo
    opencl-headers
)

pkg_installed=0
pkg_skipped=0
pkg_failed=0

for pkg in "${ROCM_PACKAGES[@]}"; do
    if pacman -Qi "$pkg" &>/dev/null; then
        pkg_skipped=$((pkg_skipped + 1))
    else
        if sudo pacman -S --needed --noconfirm "$pkg" &>/dev/null; then
            pkg_installed=$((pkg_installed + 1))
        else
            warn "Failed to install: $pkg"
            pkg_failed=$((pkg_failed + 1))
        fi
    fi
done

if [[ $pkg_installed -gt 0 || $pkg_failed -gt 0 ]]; then
    ok "ROCm packages: $pkg_installed installed, $pkg_skipped already present, $pkg_failed failed"
else
    skip "All ROCm packages already installed"
fi

# Install ollama-rocm from AUR if yay is available
if command -v yay &>/dev/null; then
    if pacman -Qi ollama-rocm &>/dev/null; then
        skip "ollama-rocm already installed"
    else
        info "Installing ollama-rocm from AUR..."
        if yay -S --needed --noconfirm ollama-rocm &>/dev/null; then
            ok "ollama-rocm installed"
        else
            warn "Failed to install ollama-rocm — install manually: yay -S ollama-rocm"
        fi
    fi
else
    warn "yay not found — skipping ollama-rocm (install yay first, then: yay -S ollama-rocm)"
fi

# ============================================================================
# Step 2: User groups
# ============================================================================

info "Step 2/5: Checking user groups..."

groups_changed=false

if id -nG "$USER" | grep -qw "video"; then
    skip "User already in video group"
else
    if sudo usermod -aG video "$USER"; then
        ok "Added $USER to video group"
        groups_changed=true
    else
        err "Failed to add $USER to video group"
    fi
fi

if id -nG "$USER" | grep -qw "render"; then
    skip "User already in render group"
else
    if sudo usermod -aG render "$USER"; then
        ok "Added $USER to render group"
        groups_changed=true
    else
        err "Failed to add $USER to render group"
    fi
fi

if $groups_changed; then
    warn "Group changes require logout/login to take effect"
fi

# ============================================================================
# Step 3: Environment variables
# ============================================================================

info "Step 3/5: Setting up environment variables..."

ENVD_DIR="$HOME/.config/environment.d"
ENVD_FILE="$ENVD_DIR/rocm.conf"

EXPECTED_CONTENT="HSA_OVERRIDE_GFX_VERSION=10.3.0
HSA_ENABLE_SDMA=0
HIP_VISIBLE_DEVICES=0"

mkdir -p "$ENVD_DIR"

if [[ -f "$ENVD_FILE" ]] && [[ "$(cat "$ENVD_FILE")" == "$EXPECTED_CONTENT" ]]; then
    skip "Environment variables already configured in $ENVD_FILE"
else
    echo "$EXPECTED_CONTENT" > "$ENVD_FILE"
    ok "Environment variables written to $ENVD_FILE"
fi

# Also add to .zshrc if not already there (for interactive shells)
ZSHRC="$HOME/.zshrc"
if [[ -f "$ZSHRC" ]]; then
    if grep -q "HSA_OVERRIDE_GFX_VERSION" "$ZSHRC"; then
        skip "ROCm exports already in .zshrc"
    else
        cat >> "$ZSHRC" << 'EOF'

# ROCm environment for AMD RX 6800 (gfx1030)
export HSA_OVERRIDE_GFX_VERSION=10.3.0
export HSA_ENABLE_SDMA=0
export HIP_VISIBLE_DEVICES=0
EOF
        ok "ROCm exports added to .zshrc"
    fi
fi

# ============================================================================
# Step 4: Configure Ollama systemd service
# ============================================================================

info "Step 4/5: Configuring Ollama for ROCm..."

OLLAMA_OVERRIDE_DIR="/etc/systemd/system/ollama.service.d"
OLLAMA_OVERRIDE_FILE="$OLLAMA_OVERRIDE_DIR/rocm.conf"

OLLAMA_OVERRIDE_CONTENT='[Service]
Environment="HSA_OVERRIDE_GFX_VERSION=10.3.0"
Environment="HSA_ENABLE_SDMA=0"
Environment="HIP_VISIBLE_DEVICES=0"'

if [[ -f "$OLLAMA_OVERRIDE_FILE" ]] && [[ "$(cat "$OLLAMA_OVERRIDE_FILE")" == "$OLLAMA_OVERRIDE_CONTENT" ]]; then
    skip "Ollama systemd override already configured"
else
    if sudo mkdir -p "$OLLAMA_OVERRIDE_DIR" && echo "$OLLAMA_OVERRIDE_CONTENT" | sudo tee "$OLLAMA_OVERRIDE_FILE" > /dev/null; then
        sudo systemctl daemon-reload 2>/dev/null || true
        ok "Ollama systemd override created at $OLLAMA_OVERRIDE_FILE"
    else
        warn "Failed to create Ollama systemd override — configure manually"
    fi
fi

# ============================================================================
# Step 5: Verification
# ============================================================================

info "Step 5/5: Running verification checks..."

echo ""

# Export for this session so verification works
export HSA_OVERRIDE_GFX_VERSION=10.3.0
export HSA_ENABLE_SDMA=0

# Check kernel module
if lsmod | grep -q amdgpu; then
    ok "amdgpu kernel module loaded"
else
    warn "amdgpu kernel module not loaded — may need reboot"
fi

# Check device nodes
if [[ -e /dev/kfd ]]; then
    ok "/dev/kfd exists (Kernel Fusion Driver)"
else
    warn "/dev/kfd not found — ROCm compute won't work without it"
fi

if ls /dev/dri/renderD* &>/dev/null; then
    ok "/dev/dri/renderD* exists (render nodes)"
else
    warn "/dev/dri/renderD* not found — check amdgpu driver"
fi

# Check rocminfo
if command -v rocminfo &>/dev/null; then
    if rocminfo 2>/dev/null | grep -q "gfx1030"; then
        ok "rocminfo detects gfx1030 GPU"
    elif rocminfo 2>/dev/null | grep -q "GPU"; then
        ok "rocminfo detects a GPU (check output with: rocminfo)"
    else
        warn "rocminfo did not detect GPU — may need logout/login for group changes"
    fi
else
    warn "rocminfo not found — ROCm packages may not be fully installed"
fi

# Check rocm-smi
if command -v rocm-smi &>/dev/null; then
    if rocm-smi 2>/dev/null | grep -qi "6800\|navi\|amd"; then
        ok "rocm-smi detects AMD GPU"
    else
        ok "rocm-smi is available (run it manually to check output)"
    fi
fi

# Check clinfo
if command -v clinfo &>/dev/null; then
    if clinfo 2>/dev/null | grep -qi "amd\|radeon"; then
        ok "OpenCL detects AMD device"
    else
        warn "clinfo did not detect AMD device — check installation"
    fi
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "============================================"

if [[ ${#ISSUES[@]} -eq 0 ]]; then
    echo -e "  ${GREEN}ROCm setup complete!${NC}"
else
    echo -e "  ${YELLOW}ROCm setup complete with ${#ISSUES[@]} issue(s)${NC}"
fi

echo "============================================"
echo ""
echo "  What was set up:"
echo "    - ROCm packages (rocm-hip-sdk, opencl, clinfo)"
echo "    - User groups (video, render)"
echo "    - Environment variables (HSA_OVERRIDE_GFX_VERSION=10.3.0)"
echo "    - SDMA disabled for stability (HSA_ENABLE_SDMA=0)"
echo "    - Ollama systemd override for ROCm"
echo ""

if [[ ${#ISSUES[@]} -gt 0 ]]; then
    echo -e "  ${YELLOW}Issues:${NC}"
    for issue in "${ISSUES[@]}"; do
        echo -e "    ${YELLOW}-${NC} $issue"
    done
    echo ""
fi

echo "  Next steps:"
echo "    1. Log out and back in (or reboot)"
echo "    2. Verify: rocminfo | grep gfx"
echo "    3. Verify: rocm-smi"
echo ""
echo "  Optional — install PyTorch with ROCm:"
echo "    python -m venv ~/pytorch-rocm"
echo "    source ~/pytorch-rocm/bin/activate"
echo "    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.2"
echo ""
