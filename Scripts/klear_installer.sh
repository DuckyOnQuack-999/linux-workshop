#!/usr/bin/env bash
# Klear KWin Shader Transparency Fix Installer
# Ensures KWin script is recognized by adding proper directory structure and metadata.

set -euo pipefail

NAME="klear"
DEST="$HOME/.local/share/kwin/scripts/$NAME"

write_file() {
  local path="$1"
  local content="$2"
  mkdir -p "$(dirname "$path")"
  printf "%s" "$content" >"$path"
  echo "[+] Wrote $path"
}

install_script() {
  echo "[+] Installing $NAME KWin script with GUI config..."

  mkdir -p "$DEST/contents/code" "$DEST/contents/config" "$DEST/contents/ui"

  write_file "$DEST/metadata.desktop" '[Desktop Entry]
Name=Klear
Comment=Smart window transparency with exclusions
Type=Service
X-KDE-ServiceTypes=KWin/Script'

  write_file "$DEST/metadata.json" '{
  "KPlugin": {
    "Name": "Klear",
    "Description": "Adds smart translucency to windows, excluding media, image, and icon windows. Includes GUI config.",
    "Version": "0.5.3-ducky",
    "Author": "DuckyOnQuack-999",
    "Website": "https://github.com/AaronRohrbacher/klear_kwin",
    "ServiceTypes": ["KWin/Script"],
    "FormFactors": ["desktop"],
    "Category": "Appearance"
  }
}'

  write_file "$DEST/contents/code/main.js" '// klear.js with GUI Config
const DEFAULT_OPACITY = 0.75;
const DEFAULT_EXCLUDES = ["vlc", "mpv", "spotify", "feh", "gwenview", "obs", "plasmashell", "thumbnail", "preview", "iconview"];
function containsAny(str,list){return!!str&&list.some(v=>str.toLowerCase().includes(v));}
function getOpacity(){const val=workspace.readConfig("opacity",DEFAULT_OPACITY);return Math.min(1.0,Math.max(0.1,parseFloat(val)||DEFAULT_OPACITY));}
function shouldExclude(c){if(!c)return true;const rawExcludes=workspace.readConfig("excludeList",DEFAULT_EXCLUDES.join(","))||DEFAULT_EXCLUDES.join(",");const excludes=rawExcludes.split(",").map(s=>s.trim().toLowerCase());return c.fullScreen||c.specialWindow||c.skipTaskbar||c.modal||c.utility||c.dialog||c.splash||c.popup||(c.resourceClass&&containsAny(c.resourceClass,excludes))||(c.caption&&containsAny(c.caption,excludes));}
function applyOpacity(c){const target=getOpacity();if(!c)return;try{if(shouldExclude(c)){if(typeof c.setOpacity==="function")c.setOpacity(1.0);else if("opacity" in c)c.opacity=1.0;}else{if(typeof c.setOpacity==="function")c.setOpacity(target);else if("opacity" in c)c.opacity=target;}}catch(e){}}
workspace.clientAdded.connect(applyOpacity);workspace.clientCaptionChanged.connect(applyOpacity);workspace.clientList().forEach(applyOpacity);'

  write_file "$DEST/contents/config/main.xml" '<!DOCTYPE kcfg SYSTEM "kcfg.xsd">
<kcfg>
  <kcfgfile name="kwinrc" />
  <group name="Effect-Klear">
    <entry name="opacity" type="Double">
      <default>0.75</default>
    </entry>
    <entry name="excludeList" type="String">
      <default>vlc,mpv,spotify,feh,gwenview,obs,plasmashell,thumbnail,preview,iconview</default>
    </entry>
  </group>
</kcfg>'

  write_file "$DEST/contents/ui/config.qml" 'import QtQuick 2.15
import QtQuick.Controls 2.15
import org.kde.kirigami 2.20 as Kirigami
Kirigami.FormLayout { id: root; property alias cfg_opacity: opacitySlider.value; property alias cfg_excludeList: excludeField.text; Kirigami.Heading { text: "Klear Transparency Settings" } Slider { id: opacitySlider; Kirigami.FormData.label: "Window Opacity"; from:0.1; to:1.0; stepSize:0.05; value:0.75 } TextField { id: excludeField; Kirigami.FormData.label: "Exclude Apps (comma-separated)"; placeholderText: "vlc, mpv, feh, gwenview, ..."; text: "vlc,mpv,spotify,feh,gwenview,obs" }}'

  qdbus org.kde.KWin /KWin reconfigure || true
  echo "[✓] Installation complete. Enable in System Settings → Window Management → KWin Scripts → Klear."
}

uninstall_script() {
  echo "[-] Removing $NAME script..."
  rm -rf "$DEST"
  qdbus org.kde.KWin /KWin reconfigure || true
  echo "[✓] Uninstalled."
}

case "${1:-}" in
install) install_script ;;
uninstall) uninstall_script ;;
*)
  echo "Usage: $0 {install|uninstall}"
  exit 1
  ;;
esac
