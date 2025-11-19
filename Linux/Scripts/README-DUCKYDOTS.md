# Duckydots Hyprland Installation Scripts

## 📚 Documentation Index

| Document | Description |
|----------|-------------|
| **ENHANCEMENT_REPORT.md** | Complete enhancement report with all fixes and features |
| **CODE_REVIEW.md** | Detailed code analysis and issues found |
| **WHATS_NEW.md** | Quick summary of what's new in v0.6 |
| **README-DUCKYDOTS.md** | This file - documentation index |

## 🎯 Quick Start

### Choose Your Version:

#### ✅ **Recommended: v0.6 Enhanced (Latest)**
```bash
bash Duckydots-v0.6-enhanced.sh
```
**Includes:**
- ✅ All critical dependencies (aquamarine, hyprlang, hyprutils, hyprgraphics)
- ✅ Fixed conflict resolution
- ✅ Plugin support (hyprexpo)
- ✅ Additional utilities (grimblast, hyprpicker, wlogout)
- ✅ Qt Wayland support
- ✅ Working hyprpm

#### ⚠️ v0.5 (Original with tomlplusplus fix)
```bash
bash Duckydots-v0.5.sh
```
**Note:** Missing many critical dependencies, use v0.6 instead!

## 📊 Version Comparison

| Feature | v0.5 | v0.6 Enhanced |
|---------|------|---------------|
| tomlplusplus | ✅ | ✅ |
| aquamarine | ❌ | ✅ |
| hyprlang | ❌ | ✅ |
| hyprutils | ❌ | ✅ |
| hyprgraphics | ❌ | ✅ |
| waybar | ❌ | ✅ |
| Qt Wayland | ❌ | ✅ |
| Plugins | ❌ | ✅ |
| hyprpm | ❌ Fails | ✅ Works |

## 🔧 What Was Fixed

### Critical Issues:
1. ✅ Added missing `aquamarine` dependency
2. ✅ Fixed conflict resolution (stopped removing required packages)
3. ✅ Added `hyprlang`, `hyprutils`, `hyprgraphics`
4. ✅ Added `base-devel` build tools
5. ✅ Fixed hyprpm failures

### Enhancements:
1. ✨ Added plugin support (hyprexpo workspace overview)
2. ✨ Added additional utilities (grimblast, hyprpicker, wlogout, etc.)
3. ✨ Added Qt Wayland support (qt5 & qt6)
4. ✨ Added compatibility checking
5. ✨ Improved error handling

## 📦 What Gets Installed

### Core Hyprland Ecosystem:
- hyprland (compositor)
- aquamarine (rendering backend)
- hyprlang (config parser)
- hyprutils (core utilities)
- hyprgraphics (graphics utilities)
- hyprwayland-scanner (protocol scanner)

### Wayland Applications:
- foot (terminal)
- fuzzel (launcher)
- waybar (status bar)
- swww (wallpaper)
- mako/swaync (notifications)
- hyprlock (screen lock)
- hypridle (idle management)

### Utilities:
- grimblast (screenshots)
- hyprpicker (color picker)
- wlogout (logout menu)
- rofi-wayland (app launcher)
- brightnessctl (brightness)
- pamixer (audio)
- cliphist (clipboard)
- wl-clipboard (clipboard tools)

### Development Tools:
- base-devel (build tools)
- cmake, meson, ninja (build systems)
- git (version control)
- gcc (compiler)
- tomlplusplus (TOML parser)

### Plugins:
- hyprexpo (workspace overview - like macOS Exposé)

## 🚀 Installation Steps

1. **Backup** (automatic):
   ```bash
   # Script backs up to ~/.config/hypr/backups/TIMESTAMP/
   ```

2. **Install Dependencies**:
   - Core Hyprland ecosystem
   - Build tools
   - Wayland applications

3. **Configure**:
   - Hyprland config files
   - Helper scripts
   - System integration

4. **Enable Plugins**:
   - hyprexpo workspace overview

## ✅ Verification

After installation, verify everything works:

```bash
# Check critical packages
pacman -Q aquamarine hyprlang hyprutils hyprgraphics waybar tomlplusplus

# Should output:
# aquamarine X.X.X-X
# hyprlang X.X.X-X
# hyprutils X.X.X-X
# hyprgraphics X.X.X-X
# waybar X.X.X-X
# tomlplusplus X.X.X-X

# Test hyprpm
hyprpm update

# Should succeed without errors

# Check plugins
hyprpm list

# Should show hyprexpo
```

## 🐛 Troubleshooting

### If hyprpm fails:
```bash
# Install missing dependencies
yay -S --needed aquamarine hyprlang hyprutils hyprgraphics base-devel

# Reload libraries
sudo ldconfig

# Try again
hyprpm update
```

### If packages conflict:
```bash
# Remove -git versions
yay -R hyprgraphics-git waybar-git

# Install stable versions
yay -S hyprgraphics waybar
```

### Check logs:
```bash
# Installation log
cat ~/.cache/hyprland/install.log

# hyprpm verbose output
hyprpm update --verbose
```

## 📖 Additional Resources

- **Hyprland Wiki**: https://wiki.hypr.land/
- **Awesome Hyprland**: https://github.com/hyprland-community/awesome-hyprland
- **Plugin Repository**: https://github.com/hyprwm/hyprland-plugins

## 🎓 Key Learnings

1. **aquamarine** is required for hyprpm to work
2. **hyprlang** and **hyprutils** are core dependencies, never remove them
3. **base-devel** is needed for building plugins
4. Qt applications need **qt5-wayland** and **qt6-wayland**
5. Conflict resolution should replace -git versions, not remove required packages

## 📝 Changelog

### v0.6 Enhanced (October 3, 2025)
- ✅ Added all missing Hyprland ecosystem dependencies
- ✅ Fixed conflict resolution logic
- ✅ Added plugin support
- ✅ Added additional utilities
- ✅ Added Qt Wayland support
- ✅ Added compatibility checking
- ✅ Improved error handling

### v0.5 (October 3, 2025)
- ✅ Fixed tomlplusplus missing library issue
- ⚠️ Multiple critical dependencies still missing

## 👥 Credits

- Original script concept and configuration
- Enhanced with comprehensive Hyprland ecosystem support
- Researched and verified against Hyprland wiki and community resources

## 📄 License

Follows the original Duckydots script licensing.

---

**Last Updated:** October 3, 2025
**Current Version:** v0.6 Enhanced
**Status:** ✅ Production Ready
