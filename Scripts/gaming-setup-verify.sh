#!/bin/bash
# Verify System Readiness for Proton Gaming

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "SYSTEM VERIFICATION FOR PROTON GAMING"
echo "=========================================="
echo ""

# Check 1: Kernel
echo -e "${YELLOW}[1/12]${NC} Kernel Check"
KERNEL=$(uname -r)
echo "Kernel: $KERNEL"
if echo "$KERNEL" | grep -q "zen"; then
    echo -e "${GREEN}✓ Zen kernel detected${NC}"
fi
echo ""

# Check 2: GPU
echo -e "${YELLOW}[2/12]${NC} GPU Detection"
GPU=$(lspci | grep -i "vga\|3d" || echo "not detected")
echo "GPU: $GPU"

if echo "$GPU" | grep -qi "nvidia"; then
    GPU_VENDOR="nvidia"
    echo -e "${GREEN}✓ NVIDIA GPU${NC}"
elif echo "$GPU" | grep -qi "amd"; then
    GPU_VENDOR="amd"
    echo -e "${GREEN}✓ AMD GPU${NC}"
elif echo "$GPU" | grep -qi "intel"; then
    GPU_VENDOR="intel"
    echo -e "${GREEN}✓ Intel GPU${NC}"
fi
echo ""

# Check 3: NVIDIA Driver
if [ "$GPU_VENDOR" = "nvidia" ]; then
    echo -e "${YELLOW}[3/12]${NC} NVIDIA Driver"
    if echo "$KERNEL" | grep -q "zen"; then
        if pacman -Q nvidia-dkms &>/dev/null; then
            echo -e "${GREEN}✓ nvidia-dkms installed${NC}"
        else
            echo -e "${RED}✗ nvidia-dkms NOT installed${NC}"
        fi
    else
        if pacman -Q nvidia &>/dev/null; then
            echo -e "${GREEN}✓ nvidia installed${NC}"
        else
            echo -e "${RED}✗ nvidia NOT installed${NC}"
        fi
    fi
    
    if pacman -Q lib32-nvidia-utils &>/dev/null; then
        echo -e "${GREEN}✓ lib32-nvidia-utils installed${NC}"
    else
        echo -e "${RED}✗ lib32-nvidia-utils NOT installed${NC}"
    fi
    
    if lsmod | grep -q nvidia; then
        echo -e "${GREEN}✓ nvidia module loaded${NC}"
    else
        echo -e "${YELLOW}⚠ nvidia module not loaded (may need reboot)${NC}"
    fi
    echo ""
fi

# Check 4: AMD/Intel Drivers
if [ "$GPU_VENDOR" = "amd" ] || [ "$GPU_VENDOR" = "intel" ]; then
    echo -e "${YELLOW}[4/12]${NC} Mesa Drivers"
    if pacman -Q mesa &>/dev/null; then
        echo -e "${GREEN}✓ mesa installed${NC}"
    else
        echo -e "${RED}✗ mesa NOT installed${NC}"
    fi
    
    if pacman -Q lib32-mesa &>/dev/null; then
        echo -e "${GREEN}✓ lib32-mesa installed${NC}"
    else
        echo -e "${RED}✗ lib32-mesa NOT installed${NC}"
    fi
    echo ""
fi

# Check 5: Vulkan
echo -e "${YELLOW}[5/12]${NC} Vulkan Support"
if pacman -Q vulkan-icd-loader &>/dev/null; then
    echo -e "${GREEN}✓ vulkan-icd-loader installed${NC}"
else
    echo -e "${RED}✗ vulkan-icd-loader NOT installed${NC}"
fi

if pacman -Q lib32-vulkan-icd-loader &>/dev/null; then
    echo -e "${GREEN}✓ lib32-vulkan-icd-loader installed${NC}"
else
    echo -e "${RED}✗ lib32-vulkan-icd-loader NOT installed${NC}"
fi
echo ""

# Check 6: Core 32-bit libraries
echo -e "${YELLOW}[6/12]${NC} Core 32-bit Libraries"
for lib in lib32-glib2 lib32-libx11 lib32-libxext lib32-mesa lib32-libgl; do
    if pacman -Q $lib &>/dev/null; then
        echo -e "${GREEN}✓ $lib${NC}"
    else
        echo -e "${RED}✗ $lib MISSING${NC}"
    fi
done
echo ""

# Check 7: Media 32-bit libraries
echo -e "${YELLOW}[7/12]${NC} Media 32-bit Libraries"
for lib in lib32-libpng lib32-libjpeg-turbo lib32-fontconfig; do
    if pacman -Q $lib &>/dev/null; then
        echo -e "${GREEN}✓ $lib${NC}"
    else
        echo -e "${RED}✗ $lib MISSING${NC}"
    fi
done
echo ""

# Check 8: Steam
echo -e "${YELLOW}[8/12]${NC} Steam Installation"
if pacman -Q steam &>/dev/null; then
    echo -e "${GREEN}✓ Steam installed${NC}"
    if [ -f ~/.local/share/Steam/ubuntu12_32/steam ]; then
        echo -e "${GREEN}✓ Steam binary present${NC}"
    fi
else
    echo -e "${RED}✗ Steam NOT installed${NC}"
fi
echo ""

# Check 9: Vulkan test
echo -e "${YELLOW}[9/12]${NC} Vulkan Functionality"
if command -v vulkaninfo &>/dev/null; then
    echo "Testing Vulkan..."
    vulkaninfo 2>/dev/null | grep "deviceName" && echo -e "${GREEN}✓ Vulkan working${NC}" || echo -e "${YELLOW}⚠ Vulkan may have issues${NC}"
else
    echo -e "${RED}✗ vulkaninfo not available${NC}"
fi
echo ""

# Check 10: /tmp
echo -e "${YELLOW}[10/12]${NC} /tmp Mount"
if mount | grep "/tmp" | grep -q "noexec"; then
    echo -e "${RED}✗ /tmp has noexec flag${NC}"
    echo "Fix: sudo mount -o remount,exec /tmp"
else
    echo -e "${GREEN}✓ /tmp is OK${NC}"
fi
echo ""

# Check 11: DKMS (if applicable)
if echo "$KERNEL" | grep -q "zen"; then
    echo -e "${YELLOW}[11/12]${NC} DKMS Status"
    if command -v dkms &>/dev/null; then
        dkms status | head -5
        echo ""
        if dkms status | grep -q "nvidia"; then
            if dkms status | grep nvidia | grep -q "installed"; then
                echo -e "${GREEN}✓ NVIDIA DKMS module installed${NC}"
            else
                echo -e "${YELLOW}⚠ NVIDIA DKMS needs installation${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}⚠ DKMS not available${NC}"
    fi
    echo ""
fi

# Check 12: Proton
echo -e "${YELLOW}[12/12]${NC} Proton Installation"
if [ -d ~/.local/share/Steam/steamapps/common ]; then
    if ls ~/.local/share/Steam/steamapps/common/ | grep -q Proton; then
        echo -e "${GREEN}✓ Proton installed${NC}"
        ls ~/.local/share/Steam/steamapps/common/ | grep Proton
    else
        echo -e "${YELLOW}⚠ Proton not installed (install in Steam: Library → Tools)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Steamapps directory not found${NC}"
fi
echo ""

# Final summary
echo "=========================================="
echo "VERIFICATION SUMMARY"
echo "=========================================="
echo ""
echo "To install missing packages, run:"
echo "  sudo ./complete_gaming_setup.sh"
echo ""
echo "After installation, reboot:"
echo "  sudo reboot"
echo ""

