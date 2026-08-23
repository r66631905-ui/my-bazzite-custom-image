#!/bin/bash

set -euo pipefail

# ============================================================
# COPY SYSTEM FILES
# ============================================================

cp -avf "/ctx/system_files"/. /


# ============================================================
# BASIC BUILD / DOWNLOAD UTILITIES
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
# WINE / WINDOWS COMPATIBILITY
# ============================================================

dnf5 install -y \
    wine \
    winetricks


# ============================================================
# VULKAN / GRAPHICS
#
# IMPORTANT:
# Bazzite provides its own Mesa stack and excludes Fedora's
# mesa-* packages. Do NOT try to install mesa-libEGL.i686
# from Fedora.
# ============================================================

dnf5 install -y \
    vulkan-loader \
    vulkan-tools \
    vulkan-validation-layers \
    mesa-vulkan-drivers \
    mesa-dri-drivers \
    mesa-libGLU \
    mesa-libgbm \
    libglvnd \
    libglvnd-glx \
    libglvnd-egl


# ============================================================
# 32-BIT VULKAN / GAMING SUPPORT
#
# Do not explicitly install mesa-libEGL.i686 or mesa-libGL.i686.
# Bazzite's multilib Mesa stack handles the required libraries.
# ============================================================

dnf5 install -y \
    vulkan-loader.i686 \
    mesa-vulkan-drivers.i686 \
    mesa-dri-drivers.i686 \
    libglvnd.i686 \
    libglvnd-glx.i686


# ============================================================
# X11 / WAYLAND
# ============================================================

dnf5 install -y \
    libX11 \
    libXcursor \
    libXdamage \
    libXext \
    libXfixes \
    libXi \
    libXinerama \
    libXrandr \
    libXrender \
    libXtst \
    libxcb \
    libxkbcommon \
    libxkbcommon-x11 \
    wayland \
    wayland-protocols


# 32-bit X11 libraries
dnf5 install -y \
    libX11.i686 \
    libXcursor.i686 \
    libXdamage.i686 \
    libXext.i686 \
    libXfixes.i686 \
    libXi.i686 \
    libXinerama.i686 \
    libXrandr.i686 \
    libXrender.i686 \
    libXtst.i686 \
    libxcb.i686 \
    libxkbcommon.i686


# ============================================================
# AUDIO
# ============================================================

dnf5 install -y \
    pipewire \
    pipewire-alsa \
    pipewire-pulseaudio \
    pipewire-jack-audio-connection-kit \
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
# GAMING PERFORMANCE
# ============================================================

dnf5 install -y \
    gamescope \
    mangohud \
    gamemode


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
# COMMON RUNTIME LIBRARIES
# ============================================================

dnf5 install -y \
    glib2 \
    libstdc++ \
    libgcc \
    zlib \
    freetype \
    fontconfig \
    libcurl \
    openssl \
    ca-certificates


# ============================================================
# GAMING DIRECTORIES
# ============================================================

mkdir -p \
    /usr/share/steam/compatibilitytools.d \
    /usr/local/share/gaming


# ============================================================
# PROTON-CACHYOS
#
# Install the latest x86_64 SLR compatibility tool.
#
# Proton-CachyOS itself contains its Proton/Wine/DXVK/
# VKD3D-Proton compatibility stack.
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
    echo "ERROR: Could not determine Proton-CachyOS release."
    exit 1
fi

echo "Latest Proton-CachyOS release: $PROTON_TAG"


# ------------------------------------------------------------
# Find x86_64 Proton SLR archive.
#
# Prefer normal x86_64, not x86_64_v4.
# ------------------------------------------------------------

PROTON_URL="$(
    printf '%s' "$PROTON_JSON" |
    jq -r '
        .assets[]
        | select(.name | test("x86_64"; "i"))
        | select(.name | test("slr|steam.?linux.?runtime"; "i"))
        | select(.name | test("\\.(tar\\.xz|tar\\.gz|tar\\.zst)$"))
        | .browser_download_url
    ' |
    head -n 1
)


# ------------------------------------------------------------
# Fallback: any x86_64 archive except v4/arm64.
# ------------------------------------------------------------

if [[ -z "$PROTON_URL" || "$PROTON_URL" == "null" ]]; then
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
fi


if [[ -z "$PROTON_URL" || "$PROTON_URL" == "null" ]]; then
    echo
    echo "ERROR: Proton-CachyOS archive was not found."
    echo
    echo "Available release assets:"
    printf '%s' "$PROTON_JSON" |
        jq -r '.assets[].name'
    echo
    exit 1
fi

echo
echo "Proton archive:"
echo "$PROTON_URL"
echo


# ============================================================
# DOWNLOAD PROTON-CACHYOS
# ============================================================

rm -rf /tmp/proton-cachyos

mkdir -p /tmp/proton-cachyos

curl -fL \
    --retry 5 \
    --retry-all-errors \
    "$PROTON_URL" \
    -o /tmp/proton-cachyos/proton.tar


# ============================================================
# EXTRACT PROTON
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
        echo "ERROR: Unsupported Proton archive format."
        exit 1
        ;;

esac


rm -rf /tmp/proton-cachyos


# ============================================================
# VERIFY PROTON
# ============================================================

echo
echo "============================================================"
echo " Proton compatibility tools installed:"
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
# WINE / PROTON ENVIRONMENT
# ============================================================

cat > /etc/profile.d/gaming.sh <<'EOF'
# ------------------------------------------------------------
# Wine
# ------------------------------------------------------------

export WINEDEBUG="${WINEDEBUG:--all}"

# ------------------------------------------------------------
# Esync / Fsync
# ------------------------------------------------------------

export WINEESYNC="${WINEESYNC:-1}"
export WINEFSYNC="${WINEFSYNC:-1}"

# ------------------------------------------------------------
# DXVK
# ------------------------------------------------------------

export DXVK_LOG_LEVEL="${DXVK_LOG_LEVEL:-none}"

# ------------------------------------------------------------
# Shader caches
# ------------------------------------------------------------

export DXVK_STATE_CACHE_PATH="${DXVK_STATE_CACHE_PATH:-$HOME/.cache/dxvk}"

export VKD3D_SHADER_CACHE_PATH="${VKD3D_SHADER_CACHE_PATH:-$HOME/.cache/vkd3d-proton}"

# ------------------------------------------------------------
# Steam compatibility tools
# ------------------------------------------------------------

export STEAM_COMPAT_TOOLS_PATHS="${STEAM_COMPAT_TOOLS_PATHS:-/usr/share/steam/compatibilitytools.d}"
EOF

chmod 0644 /etc/profile.d/gaming.sh


# ============================================================
# GAMEMODE CONFIGURATION
# ============================================================

cat > /etc/gamemode.ini <<'EOF'
[general]
renice=10
softrealtime=auto
inhibit_screensaver=1
EOF


# ============================================================
# MANGOHUD CONFIGURATION
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
# BUILD COMPLETE
# ============================================================

echo
echo "============================================================"
echo " BAZZITE GAMING IMAGE BUILD COMPLETE"
echo "============================================================"
echo
echo "Gaming stack:"
echo
echo "  Wine"
echo "  Winetricks"
echo "  Proton-CachyOS"
echo "  DXVK / VKD3D-Proton via Proton"
echo "  Vulkan"
echo "  Vulkan 32-bit"
echo "  Mesa"
echo "  Mesa 32-bit"
echo "  Gamescope"
echo "  MangoHud"
echo "  GameMode"
echo "  PipeWire"
echo "  FFmpeg / GStreamer"
echo "  SDL2"
echo "  32-bit Windows gaming libraries"
echo
echo "============================================================"
