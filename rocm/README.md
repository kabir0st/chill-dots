# ROCm Setup for AMD RX 6800 (16GB) on Arch Linux

> Unofficial but well-tested setup for running GPU-accelerated ML workloads on the RX 6800 (Navi 21 / gfx1030) with ROCm on Arch Linux (Omarchy).

---

## TL;DR

```bash
cd rocm
chmod +x install-rocm.sh
./install-rocm.sh
# Log out and back in, then:
rocminfo | grep gfx
```

---

## Support Status

The **RX 6800 (gfx1030) is NOT officially supported** by AMD's ROCm — their support matrix targets Instinct MI-series and Radeon Pro cards. However, it works reliably via a GFX version override that the community has been using since ROCm 5.x through the current 6.x releases.

**What works:**
- PyTorch (training + inference)
- Ollama / llama.cpp (local LLM inference)
- Stable Diffusion (ComfyUI, AUTOMATIC1111)
- General HIP/OpenCL compute

**What has rough edges:**
- Flash Attention may need specific builds for RDNA2
- Triton (OpenAI's compiler) has partial RDNA2 support
- Not all ROCm libraries are fully optimized for gfx1030 (expect ~10-30% below peak vs officially supported GPUs)

---

## What the Installer Does

1. Installs ROCm packages (`rocm-hip-sdk`, `rocm-opencl-sdk`, `clinfo`)
2. Adds your user to `video` and `render` groups
3. Sets up environment variables system-wide (`HSA_OVERRIDE_GFX_VERSION`, etc.)
4. Configures Ollama's systemd service for ROCm
5. Runs verification checks

---

## Key Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `HSA_OVERRIDE_GFX_VERSION` | `10.3.0` | **Required.** Tells ROCm to accept gfx1030 as a supported target |
| `HSA_ENABLE_SDMA` | `0` | Disables System DMA — prevents hangs/crashes on RDNA2 |
| `HIP_VISIBLE_DEVICES` | `0` | Use discrete GPU (useful if you also have an APU) |

These are set in `~/.config/environment.d/rocm.conf` by the installer so they apply to all sessions and systemd services.

---

## Manual Verification

After installing and logging back in:

```bash
# Check GPU is detected
rocminfo | grep -A5 "gfx1030"

# Check GPU stats
rocm-smi

# Check OpenCL
clinfo | head -20

# Test PyTorch (if installed)
python3 -c "
import torch
print(f'ROCm available: {torch.cuda.is_available()}')
print(f'GPU: {torch.cuda.get_device_name(0)}')
x = torch.randn(1000, 1000, device='cuda')
print(f'Compute test: {torch.matmul(x, x).shape}')
"
```

---

## PyTorch with ROCm

```bash
# Create a venv and install PyTorch with ROCm support
python -m venv ~/pytorch-rocm
source ~/pytorch-rocm/bin/activate
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.2
```

> PyTorch uses `torch.cuda` API names even with ROCm — this is by design (HIP translates CUDA calls).

Check https://pytorch.org/get-started/locally/ for the latest ROCm wheel URL.

---

## Ollama with ROCm

The installer sets up Ollama's systemd service with the correct environment variables. After installation:

```bash
sudo systemctl enable --now ollama
ollama run llama3.2
```

**What fits in 16GB VRAM:**

| Model | Quantization | VRAM | Fits? |
|-------|-------------|------|-------|
| 7B | Q4 | ~4-5 GB | Yes |
| 13B | Q4 | ~8-9 GB | Yes |
| 34B | Q4 | ~18-20 GB | No |
| 70B | Q4 | ~35-40 GB | No |

---

## Troubleshooting

### "No GPU agents found" in rocminfo
`HSA_OVERRIDE_GFX_VERSION` is not set. Log out and back in, or `source ~/.config/environment.d/rocm.conf` manually.

### Permission denied on /dev/kfd
Your user isn't in the `render` group. Run `sudo usermod -aG render,video $USER` and log out/in.

### GPU hangs or "GPU reset" in dmesg
Set `HSA_ENABLE_SDMA=0` (the installer does this by default).

### PyTorch says no HIP device
Ensure the environment variable reaches Python — check with `echo $HSA_OVERRIDE_GFX_VERSION` in the same shell.

### Wrong GPU used (APU instead of discrete)
Set `HIP_VISIBLE_DEVICES=0` (check `rocminfo` output for the correct index).

### ROCm version mismatch with PyTorch
Check installed version with `pacman -Q rocm-core` and match the pip wheel URL accordingly.

### Slow performance
```bash
# Set GPU to high performance mode
echo high | sudo tee /sys/class/drm/card1/device/power_dpm_force_performance_level
```

### Package conflicts after system update
Arch is rolling-release — a `pacman -Syu` can update ROCm and break PyTorch wheels. Consider adding `IgnorePkg = rocm-core rocm-hip-sdk` to `/etc/pacman.conf` for stability, or rebuild your Python environment after ROCm updates.

---

## Arch Linux vs Ubuntu Notes

- Arch uses `pacman -S rocm-hip-sdk` — no `amdgpu-install` script
- ROCm packages are in the official `extra` repo (not just AUR)
- Rolling release means you get newer ROCm faster, but updates can break things
- No DKMS needed — amdgpu is in the mainline kernel
- Watch for mesa/ROCm OpenCL conflicts if you also use Vulkan compute
