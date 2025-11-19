if lspci | grep -i nvidia &> /dev/null; then echo -e "
${BLUE}NVIDIA Driver Information:${NC}"; if command -v nvidia-smi &> /dev/null; then nvidia-smi --query-gpu=gpu_name,driver_version,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader | sed "s/^/  /"; else echo -e "  ${YELLOW}${ICON_WARN} NVIDIA drivers not installed${NC}"; fi; fi
