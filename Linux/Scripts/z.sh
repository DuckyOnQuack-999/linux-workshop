#!/usr/bin/env bash
# Dynamic wallpaper-synced border colors for Hyprland + Waybar
# Uses matugen (Rust: median cut quant via palette_extract; Material You HCT tonals) to extract palette and applies via config edits
# Improvements: Waybar CSS sync, HSL interp, matugen scheme flags

set -euo pipefail

# Configuration (exportable)
: "${WALLPAPER_PATH_FILE:=$HOME/.local/state/quickshell/user/generated/wallpaper/path.txt}"
: "${PALETTE_DIR:=$HOME/.local/state/quickshell/user/generated/colors}"
: "${PALETTE_FILE:=$PALETTE_DIR/palette.json}"
: "${SETTINGS_FILE:=$HOME/.local/state/quickshell/user/settings/theme_sync.json}"
: "${HYPR_CONFIG_DIR:=$HOME/.config/hypr}"
: "${COLORS_CONF:=$HYPR_CONFIG_DIR/colors.conf}"
: "${GENERAL_CONF:=$HYPR_CONFIG_DIR/general.conf}"
: "${WAYBAR_STYLE:=$HOME/.config/waybar/style.css}"
: "${CACHE_FILE:=$PALETTE_DIR/cache.txt}"

# Default settings (added matugen_flags)
DEFAULT_SETTINGS='{
  "enabled": true,
  "fancy": true,
  "stops": 3,
  "keys": ["accent", "secondary", "tertiary"],
  "matugen_flags": "--scheme tonal",
  "alphaActive": 1.0,
  "alphaInactive": 0.35,
  "updateShadows": true,
  "updateHyprbars": true,
  "updateHyprexpo": true,
  "updateWaybar": true
}'

# Ensure directories exist
mkdir -p "$PALETTE_DIR"
mkdir -p "$(dirname "$SETTINGS_FILE")"

# Global vars
declare -A settings_cache

# Load settings (full JSON)
load_settings() {
    if [[ -z "${settings_cache[json]:-}" ]]; then
        if [[ -f "$SETTINGS_FILE" ]]; then
            settings_cache[json]=$(cat "$SETTINGS_FILE")
        else
            echo "$DEFAULT_SETTINGS" >"$SETTINGS_FILE"
            settings_cache[json]="$DEFAULT_SETTINGS"
        fi
    fi
    echo "${settings_cache[json]}"
}

is_enabled() {
    local settings
    settings=$(load_settings)
    echo "$settings" | jq -er '.enabled // true'
}

# Clamp
clamp() {
    local val=$1 min=$2 max=$3
    awk -v val="$val" -v min="$min" -v max="$max" 'BEGIN { print int((val < min ? min : (val > max ? max : val)) + 0.5) }'
}

# Cache check: md5 + mtime
is_cached() {
    local wallpaper_path="$1"
    if [[ ! -f "$wallpaper_path" ]]; then
        return 1
    fi
    local hash=$(md5sum "$wallpaper_path" | cut -d' ' -f1)
    local mtime=$(stat -c %Y "$wallpaper_path" 2>/dev/null || date +%s)
    local cache_hash cache_mtime
    if [[ -f "$CACHE_FILE" ]]; then
        {
            read -r cache_hash
            read -r cache_mtime
        } <"$CACHE_FILE"
    fi
    [[ "$hash" == "$cache_hash" && "$mtime" == "$cache_mtime" ]]
}

update_cache() {
    local wallpaper_path="$1"
    local hash=$(md5sum "$wallpaper_path" | cut -d' ' -f1)
    local mtime=$(stat -c %Y "$wallpaper_path" 2>/dev/null || date +%s)
    echo -e "$hash\n$mtime" >"$CACHE_FILE"
}

generate_palette() {
    local wallpaper_path="$1"
    if is_cached "$wallpaper_path"; then
        if [[ "${VERBOSE:-false}" == "true" ]]; then
            echo "Using cached palette"
        fi
        return 0
    fi

    if [[ ! -f "$wallpaper_path" ]]; then
        echo "Wallpaper file not found: $wallpaper_path" >&2
        return 1
    fi

    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo "Generating palette from: $wallpaper_path"
    fi

    local flags
    flags=$(load_settings | jq -er '.matugen_flags // ""')
    matugen image "$wallpaper_path" $flags --json >"$PALETTE_FILE" || {
        echo "Failed to generate palette with matugen" >&2
        return 1
    }
    update_cache "$wallpaper_path"
}

# Hex to RGB (0-255 ints)
hex_to_rgb() {
    local hex="$1"
    echo "$hex" | sed 's/#//' | awk '
    /^[0-9a-fA-F]{6}$/ {
        r = strtonum("0x" substr($0,1,2))
        g = strtonum("0x" substr($0,3,2))
        b = strtonum("0x" substr($0,5,2))
        print r, g, b
    }'
}

# RGB to rgba string
rgb_to_rgba() {
    local r=$1 g=$2 b=$3 alpha=$4
    local a_int
    a_int=$(echo "$alpha * 255" | bc -l | cut -d. -f1)
    printf "rgba(%d,%d,%d,%d)" "$r" "$g" "$b" "$a_int"
}

# Enhanced HSL interp functions (Awk with bc for math)
rgb_to_hls() {
    local r=$1 g=$2 b=$3
    awk -v r="$r" -v g="$g" -v b="$b" '
    function max(x,y,z) { return ((x>y&&x>z)?x:(y>z?y:z)) }
    function min(x,y,z) { return ((x<y&&x<z)?x:(y<z?y:z)) }
    function delta(x,y,z) { return max(x,y,z) - min(x,y,z) }
    {
        r /= 255; g /= 255; b /= 255
        mx = max(r,g,b); mn = min(r,g,b); d = delta(r,g,b)
        l = (mx + mn) / 2
        if (d == 0) { s = 0; h = 0 }
        else {
            if (l < 0.5) s = d / (mx + mn)
            else s = d / (2 - mx - mn)
            if (mx == r) h = (g - b) / d + (g < b ? 6 : 0)
            else if (mx == g) h = (b - r) / d + 2
            else h = (r - g) / d + 4
            h /= 6
        }
        print h, l, s
    }' | bc -l | awk '{print $1, $2, $3}' # Pipe to bc if needed, but awk math suffices for basics
}

hls_to_rgb() {
    local h=$1 l=$2 s=$3
    awk -v h="$h" -v l="$l" -v s="$s" '
    function clamp(v,lo,hi) { return ((v<lo)?lo:((v>hi)?hi:v)) }
    {
        if (s == 0) { r=l; g=l; b=l }
        else {
            q = (l < 0.5) ? (l * (1 + s)) : (l + s - l * s)
            p = 2 * l - q
            r = hue_to_rgb(p, q, h + 1/3)
            g = hue_to_rgb(p, q, h)
            b = hue_to_rgb(p, q, h - 1/3)
        }
        r = clamp(r * 255, 0, 255)
        g = clamp(g * 255, 0, 255)
        b = clamp(b * 255, 0, 255)
        print int(r), int(g), int(b)
    }
    function hue_to_rgb(p, q, t) {
        if (t < 0) t += 1
        if (t > 1) t -= 1
        if (t < 1/6) return p + (q - p) * 6 * t
        if (t < 1/2) return q
        if (t < 2/3) return p + (q - p) * (2/3 - t) * 6
        return p
    }'
}

# Interp in HSL space (shortest hue arc)
interp_hsl() {
    local r1=$1 g1=$2 b1=$3 r2=$4 g2=$5 b2=$6 t=$7
    local h1 l1 s1 h2 l2 s2 dh h
    {
        read h1 l1 s1
        read h2 l2 s2
    } < <(rgb_to_hls "$r1" "$g1" "$b1" && rgb_to_hls "$r2" "$g2" "$b2")
    dh=$(echo "$h2 - $h1" | bc -l)
    if [[ $(echo "$dh > 0.5" | bc -l) == 1 ]]; then dh=$(echo "$dh - 1" | bc -l); fi
    if [[ $(echo "$dh < -0.5" | bc -l) == 1 ]]; then dh=$(echo "$dh + 1" | bc -l); fi
    h=$(echo "($h1 + $t * $dh) % 1" | bc -l | awk '{printf "%.6f", $0}')
    l=$(echo "$l1 + $t * ($l2 - $l1)" | bc -l)
    s=$(echo "$s1 + $t * ($s2 - $s1)" | bc -l)
    hls_to_rgb "$h" "$l" "$s"
}

# Generate interpolated RGBs (chain HSL interp for multi-stops)
generate_interpolated() {
    local keys=("$@")
    local rgbs=() n=${#keys[@]}
    if [[ $n -le 1 ]]; then
        local hex=$(jq -er ".colors.${keys[0]}.hex // empty" "$PALETTE_FILE")
        if [[ -n "$hex" ]]; then
            rgbs+=("$(hex_to_rgb "$hex")")
        fi
        echo "${rgbs[*]}"
        return
    fi

    # Get endpoint RGBs
    local prev_r prev_g prev_b curr_r curr_g curr_b
    { read prev_r prev_g prev_b; } < <(hex_to_rgb "$(jq -er ".colors.${keys[0]}.hex" "$PALETTE_FILE")")
    for ((i = 1; i < n; i++)); do
        local key="${keys[$i]}"
        { read curr_r curr_g curr_b; } < <(hex_to_rgb "$(jq -er ".colors.$key.hex" "$PALETTE_FILE")")
        local t=0.5 # Midpoint; for even spacing, adjust t = 1/(n-1) * i but chain pairwise
        local ir_r ir_g ir_b
        ir_r ir_g ir_b=$(interp_hsl "$prev_r" "$prev_g" "$prev_b" "$curr_r" "$curr_g" "$curr_b" "$t")
        rgbs+=("$ir_r $ir_g $ir_b")
        prev_r=$curr_r
        prev_g=$curr_g
        prev_b=$curr_b
    done
    # Add endpoints
    rgbs=("$prev_r $prev_g $prev_b" "${rgbs[@]}")
    echo "${rgbs[*]}"
}

hex_to_rgba() { # Retained
    local hex="$1" alpha="$2" r g b
    { read r g b; } < <(hex_to_rgb "$hex")
    rgb_to_rgba "$r" "$g" "$b" "$alpha"
}

rgba_modify_alpha() {
    local rgba="$1" new_alpha="$2"
    echo "$rgba" | awk -F'[,)]' -v na="$new_alpha" '
    /rgba\(\d+,\d+,\d+,\d+\)/ {
        r=substr($2,2); g=$3; b=$4
        a=int(na*255+0.5)
        printf "rgba(%s,%s,%s,%d)", r,g,b,a
    } {print}'
}

extract_colors() {
    local settings
    settings=$(load_settings)

    local stops alpha_active alpha_inactive fancy
    stops=$(echo "$settings" | jq -er '.stops // 3')
    stops=$(clamp "$stops" 1 5)
    alpha_active=$(echo "$settings" | jq -er '.alphaActive // 1.0')
    alpha_inactive=$(echo "$settings" | jq -er '.alphaInactive // 0.35')
    fancy=$(echo "$settings" | jq -er '.fancy // true')

    if [[ ! -f "$PALETTE_FILE" || ! -s "$PALETTE_FILE" ]]; then
        echo "Invalid palette file" >&2
        return 1
    fi

    local keys
    keys=$(echo "$settings" | jq -r '.keys // [] | @sh')
    if [[ "$keys" == "[]" ]]; then
        keys=$(jq -r '.colors | keys[] | select(. != "surface")' "$PALETTE_FILE" | head -n "$stops" | tr '\n' ' ')
    fi
    IFS=' ' read -ra key_array <<<"$keys"

    # Generate RGBs (HSL interp if fancy)
    local rgbs
    if [[ "$fancy" == "true" ]]; then
        rgbs=$(generate_interpolated "${key_array[@]}")
    else
        local hex r g b
        for key in "${key_array[@]}"; do
            hex=$(jq -er ".colors.$key.hex // empty" "$PALETTE_FILE")
            if [[ -n "$hex" ]]; then
                { read r g b; } < <(hex_to_rgb "$hex")
                rgbs+=" $r $g $b"
            fi
        done
    fi

    # Build rgba gradient
    local colors=() rgb_parts
    IFS=' ' read -ra rgb_parts <<<"$rgbs"
    for ((i = 0; i < ${#rgb_parts[@]}; i += 3)); do
        local r=${rgb_parts[$i]} g=${rgb_parts[$((i + 1))]} b=${rgb_parts[$((i + 2))]}
        colors+=("$(rgb_to_rgba "$r" "$g" "$b" "$alpha_active")")
    done

    if [[ ${#colors[@]} -eq 0 ]]; then
        colors=("rgba(100,100,100,255)")
    fi

    local gradient=$(
        IFS=' '
        echo "${colors[*]}"
    )

    # Inactive
    local muted_hex muted_r muted_g muted_b
    muted_hex=$(jq -er '.colors.surface.hex // empty' "$PALETTE_FILE")
    if [[ -n "$muted_hex" ]]; then
        { read muted_r muted_g muted_b; } < <(hex_to_rgb "$muted_hex")
        local inactive_rgba=$(rgb_to_rgba "$muted_r" "$muted_g" "$muted_b" "$alpha_inactive")
    else
        inactive_rgba="rgba(50,50,50,90)"
    fi

    echo "$gradient|$inactive_rgba|$muted_hex" # Pass muted_hex for Waybar
}

# Edit config: Replace/add key=value or CSS rules
edit_config() {
    local conf_file="$1" section="$2" replacements=("$@")
    shift 2
    local tmp=$(mktemp)
    if [[ "$conf_file" == *".css" ]]; then
        # CSS: Append/Replace in :root or selectors
        awk -v reps="$*" '
        BEGIN { root_found=0; gsub(/ /,"|",reps); split(reps,a,"|") }
        /:root *{/ { root_found=1; for(i in a) if (index(a[i], "--")) print a[i]; next }
        !root_found && /:root/ { print; root_found=1; for(i in a) if (index(a[i], "--")) print "    " a[i]; next }
        { print }
        END { if (!root_found && NR>0) print ":root {" RS "}" }' "$conf_file" >"$tmp" || cat "$conf_file" >"$tmp"
        # Separate pass for module rules
        awk -v rules="$*" '
        /#workspaces button\.focused/ { print; print "    background: var(--primary);" next }
        { print }' "$conf_file" >>"$tmp"
    else
        # Hypr conf: As before
        awk -v sec="$section" -v reps="$*" '
        BEGIN { in_sec=0; gsub(/ /,"|",reps); split(reps,a,"|") }
        /^\[.*\]/ { in_sec=($0 ~ sec) }
        in_sec && /^[a-zA-Z0-9:_.-]+[ \t]*=/ {
            for(i in a) { split(a[i],b,"="); if ($0 ~ "^" b[1]) { $0=b[1] "=" b[2]; break } }
        }
        { print }' "$conf_file" >"$tmp" || cat "$conf_file" >"$tmp"
    fi
    mv "$tmp" "$conf_file"
}

# Backup and apply
backup_and_apply() {
    local conf="$1"
    cp -n "$conf" "${conf}.bak.$(date +%s)" 2>/dev/null || true
}

apply_colors() {
    local colors="$1"
    local active_border="${colors%|*}"
    local inactive_border="${colors#*|}"
    local muted_hex="${colors##*|}"

    local active_rgb # First color for shadow
    active_rgb=$(echo "$active_border" | cut -d' ' -f1 | sed 's/rgba(//; s/,[^)]*)//; s/,/ /g')

    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo "Applying to configs:"
        echo "  Active: $active_border"
        echo "  Inactive: $inactive_border"
        echo "  Muted Hex: $muted_hex"
    fi

    # Hyprland (unchanged)
    backup_and_apply "$COLORS_CONF"
    edit_config "$COLORS_CONF" "colors" \
        "general:col.active_border = $active_border" \
        "general:col.inactive_border = $inactive_border"

    local settings
    settings=$(load_settings)

    if [[ "$(echo "$settings" | jq -er '.updateShadows // true')" == "true" ]]; then
        local shadow_rgba=$(rgba_modify_alpha "rgba($active_rgb)" 0.125)
        edit_config "$COLORS_CONF" "decoration" "decoration:shadow = $shadow_rgba"
    fi

    if [[ "$(echo "$settings" | jq -er '.updateHyprbars // true')" == "true" ]]; then
        local bar_color=$(rgba_modify_alpha "$inactive_border" 1.0)
        local text_color=$(rgba_modify_alpha "$active_border" 1.0)
        edit_config "$COLORS_CONF" "plugin:hyprbars" \
            "plugin:hyprbars:bar_color = $bar_color" \
            "plugin:hyprbars:col.text = $text_color"
    fi

    if [[ "$(echo "$settings" | jq -er '.updateHyprexpo // true')" == "true" ]]; then
        backup_and_apply "$GENERAL_CONF"
        local bg_rgb=$(echo "$inactive_border" | sed 's/rgba(/rgb(/; s/,[^)]*)//')
        edit_config "$GENERAL_CONF" "plugin:hyprexpo" "plugin:hyprexpo:bg_col = $bg_rgb"
    fi

    # Waybar sync
    if [[ "$(echo "$settings" | jq -er '.updateWaybar // true')" == "true" && -f "$WAYBAR_STYLE" ]]; then
        backup_and_apply "$WAYBAR_STYLE"
        local primary="${colors[0]}"
        local secondary="${colors[1]:-$primary}"
        local bg_var=$(rgba_modify_alpha "$inactive_border" 0.8) # Semi-trans bg
        edit_config "$WAYBAR_STYLE" ":root" \
            "--primary: $primary" \
            "--secondary: $secondary" \
            "--background: $bg_var" \
            "--accent: $muted_hex"
        # Reload Waybar
        pkill -USR2 waybar 2>/dev/null || true
    fi

    # Reload Hyprland
    hyprctl reload || true
}

main() {
    local force=false
    if [[ "${1:-}" == "--force" ]]; then
        force=true
        shift
    fi

    local enabled
    enabled=$(is_enabled)
    if [[ "$force" != "true" && "$enabled" != "true" ]]; then
        echo "Theme sync disabled"
        exit 0
    fi

    if [[ ! -f "$WALLPAPER_PATH_FILE" ]]; then
        echo "Wallpaper path file not found" >&2
        exit 1
    fi

    local wallpaper_path
    wallpaper_path=$(<"$WALLPAPER_PATH_FILE")

    if [[ -z "$wallpaper_path" ]]; then
        echo "No wallpaper path" >&2
        exit 1
    fi

    generate_palette "$wallpaper_path" || exit 1

    local colors
    colors=$(extract_colors) || exit 1

    apply_colors "$colors"

    if [[ "${VERBOSE:-false}" != "true" ]]; then
        echo "Theme sync completed"
    fi
}

# Args
case "${1:-}" in
--init | --force)
    main "$@"
    ;;
--verbose)
    VERBOSE=true
    shift
    main "$@"
    ;;
--help)
    echo "Usage: $0 [--init|--force|--verbose|--help]"
    echo "  --init     Run sync (default)"
    echo "  --force    Bypass enabled check"
    echo "  --verbose  Debug output"
    ;;
*)
    main "$@"
    ;;
esac
