#!/bin/bash

set -euo pipefail

# ============================================================
# COPY SYSTEM FILES
# ============================================================

cp -avf "/ctx/system_files"/. /


# ============================================================
# BASIC UTILITIES
# ============================================================

dnf5 install -y \
    curl \
    wget \
    git \
    jq \
    unzip \
    zip \
    tar \
    xz \
    zstd \
    p7zip \
    p7zip-plugins \
    cabextract \
    rsync \
    file \
    which


# ============================================================
# WINE / WINDOWS EXE SUPPORT
# ============================================================

dnf5 install -y \
    wine \
    winetricks


# ============================================================
# VULKAN TOOLS
#
# Bazzite already provides the actual Mesa/Vulkan stack.
# We only add tools that are useful for diagnostics.
# ============================================================

dnf5 install -y \
    vulkan-tools \
    vulkan-validation-layers


# ============================================================
# GAMING RUNTIME
#
# Bazzite already ships these through Terra:
#
#   terra-gamescope
#   terra-gamescope-libs
#   umu-wrapper
#   umu-launcher
#   libFAudio
#   MangoHud
#   vkBasalt
#
# DO NOT install Fedora gamescope/Mesa/libcurl here.
# ============================================================


# ============================================================
# AUDIO
#
# Only install packages that are safe/needed for Wine.
# Bazzite already has PipeWire.
# ============================================================

dnf5 install -y \
    alsa-lib \
    alsa-plugins-pulseaudio


# ============================================================
# MULTIMEDIA
# ============================================================

dnf5 install -y \
    ffmpeg \
    gstreamer1 \
    gstreamer1-plugins-base \
    gstreamer1-plugins-good \
    gstreamer1-plugins-bad-free \
    gstreamer1-plugins-ugly-free


# ============================================================
# CONTROLLERS / SDL
# ============================================================

dnf5 install -y \
    SDL2 \
    SDL2_image \
    SDL2_mixer \
    SDL2_ttf \
    libusb1


# ============================================================
# FONTS
# ============================================================

dnf5 install -y \
    google-noto-sans-fonts \
    google-noto-serif-fonts \
    google-noto-emoji-fonts \
    liberation-fonts


# ============================================================
# BASIC RUNTIME LIBRARIES
#
# IMPORTANT:
# Do NOT install libcurl.
# Bazzite uses libcurl-minimal.
# ============================================================

dnf5 install -y \
    glib2 \
    libstdc++ \
    libgcc \
    zlib \
    freetype \
    fontconfig \
    openssl \
    ca-certificates


# ============================================================
# STEAM COMPATIBILITY TOOLS
# ============================================================

mkdir -p \
    /usr/share/steam/compatibilitytools.d \
    /usr/local/share/gaming


# ============================================================
# PROTON-CACHYOS
# ============================================================

echo
echo "============================================================"
echo " Installing Proton-CachyOS"
echo "============================================================"

PROTON_API="https://api.github.com/repos/CachyOS/proton-cachyos/releases/latest"

PROTON_JSON="$(
    curl -fsSL \
        --retry 5 \
        --retry-all-errors \
        -H "Accept: application/vnd.github+json" \
        "$PROTON_API"
)"

PROTON_TAG="$(
    printf '%s' "$PROTON_JSON" |
    jq -r '.tag_name'
)"

if [[ -z "$PROTON_TAG" || "$PROTON_TAG" == "null" ]]; then
    echo "ERROR: Could not determine Proton-CachyOS version."
    exit 1
fi

echo "Latest Proton-CachyOS: $PROTON_TAG"


# ============================================================
# FIND NORMAL X86_64 PROTON
#
# CachyOS recommends normal x86_64 for conservative use.
# x86_64_v4 is experimental.
# ============================================================

PROTON_URL="$(
    printf '%s' "$PROTON_JSON" |
    jq -r '
        .assets[]
        | select(.name | test("x86_64"; "i"))
        | select(.name | test("x86_64_v4"; "i") | not)
        | select(.name | test("arm64"; "i") | not)
        | select(.name | test("\\.(tar\\.xz|tar\\.gz|tar\\.zst)$"))
        | .browser_download_url
    ' |
    head -n 1
)"

if [[ -z "$PROTON_URL" || "$PROTON_URL" == "null" ]]; then
    echo
    echo "ERROR: Could not find Proton-CachyOS x86_64 archive."
    echo
    echo "Available assets:"
    printf '%s' "$PROTON_JSON" |
        jq -r '.assets[].name'
    exit 1
fi

echo "Proton download:"
echo "$PROTON_URL"


# ============================================================
# DOWNLOAD
# ============================================================

rm -rf /tmp/proton-cachyos

mkdir -p /tmp/proton-cachyos

curl -fL \
    --retry 5 \
    --retry-all-errors \
    "$PROTON_URL" \
    -o /tmp/proton-cachyos/proton.tar


# ============================================================
# EXTRACT
# ============================================================

case "$PROTON_URL" in

    *.tar.xz)
        tar -xJf \
            /tmp/proton-cachyos/proton.tar \
            -C /usr/share/steam/compatibilitytools.d
        ;;

    *.tar.gz)
        tar -xzf \
            /tmp/proton-cachyos/proton.tar \
            -C /usr/share/steam/compatibilitytools.d
        ;;

    *.tar.zst)
        tar --zstd -xf \
            /tmp/proton-cachyos/proton.tar \
            -C /usr/share/steam/compatibilitytools.d
        ;;

    *)
        echo "ERROR: Unsupported Proton archive."
        exit 1
        ;;

esac

rm -rf /tmp/proton-cachyos


# ============================================================
# VERIFY PROTON
# ============================================================

echo
echo "============================================================"
echo " Installed Proton compatibility tools"
echo "============================================================"

find /usr/share/steam/compatibilitytools.d \
    -maxdepth 3 \
    -type f \
    \( \
        -name "proton" \
        -o \
        -name "compatibilitytool.vdf" \
    \) \
    -print || true


# ============================================================
# GAMING ENVIRONMENT
# ============================================================

cat > /etc/profile.d/gaming.sh <<'EOF'

# ============================================================
# WINE
# ============================================================

export WINEDEBUG="${WINEDEBUG:--all}"


# ============================================================
# ESYNC / FSYNC
# ============================================================

export WINEESYNC="${WINEESYNC:-1}"
export WINEFSYNC="${WINEFSYNC:-1}"


# ============================================================
# DXVK
# ============================================================

export DXVK_LOG_LEVEL="${DXVK_LOG_LEVEL:-none}"

export DXVK_STATE_CACHE_PATH="${DXVK_STATE_CACHE_PATH:-$HOME/.cache/dxvk}"


# ============================================================
# VKD3D-PROTON
# ============================================================

export VKD3D_SHADER_CACHE_PATH="${VKD3D_SHADER_CACHE_PATH:-$HOME/.cache/vkd3d-proton}"


# ============================================================
# STEAM COMPATIBILITY TOOLS
# ============================================================

export STEAM_COMPAT_TOOLS_PATHS="${STEAM_COMPAT_TOOLS_PATHS:-/usr/share/steam/compatibilitytools.d}"

EOF

chmod 0644 /etc/profile.d/gaming.sh


# ============================================================
# GAMEMODE
# ============================================================

cat > /etc/gamemode.ini <<'EOF'
[general]
renice=10
softrealtime=auto
inhibit_screensaver=1
EOF


# ============================================================
# MANGOHUD
# ============================================================

cat > /etc/mangohud.conf <<'EOF'
fps
frametime
cpu_stats
cpu_temp
gpu_stats
gpu_temp
ram
vram
position=top-left
background_alpha=0.35
font_size=24
EOF


# ============================================================
# PODMAN
# ============================================================

systemctl enable podman.socket


# ============================================================
# CLEANUP
# ============================================================

dnf5 clean all

rm -rf /var/cache/dnf/*
rm -rf /var/cache/libdnf5/*
rm -rf /tmp/*


# ============================================================
# FINAL
# ============================================================

echo
echo "============================================================"
echo " BAZZITE CUSTOM GAMING IMAGE BUILD COMPLETE"
echo "============================================================"
echo
echo "Windows / Gaming:"
echo
echo "  Wine"
echo "  Winetricks"
echo "  Proton-CachyOS"
echo "  DXVK / VKD3D-Proton through Proton"
echo "  Vulkan tools"
echo "  Vulkan validation"
echo "  Bazzite Gamescope"
echo "  UMU"
echo "  MangoHud"
echo "  vkBasalt"
echo "  GameMode"
echo "  PipeWire"
echo "  FFmpeg"
echo "  GStreamer"
echo "  SDL2"
echo "  Controller support"
echo "  32-bit Bazzite gaming libraries"
echo
echo "============================================================"
