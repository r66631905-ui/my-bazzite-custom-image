#!/bin/bash

set -ouex pipefail

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
# WINE / WINDOWS COMPATIBILITY
# ============================================================

dnf5 install -y \
    wine \
    wine-core \
    wine-common \
    wine-desktop \
    wine-mono \
    wine-gecko \
    winetricks


# ============================================================
# VULKAN
# ============================================================

dnf5 install -y \
    vulkan-loader \
    vulkan-tools \
    vulkan-validation-layers \
    mesa-vulkan-drivers \
    mesa-dri-drivers


# 32-bit Vulkan / Mesa
dnf5 install -y \
    vulkan-loader.i686 \
    mesa-vulkan-drivers.i686 \
    mesa-dri-drivers.i686


# ============================================================
# OPENGL / GRAPHICS
# ============================================================

dnf5 install -y \
    mesa-libGLU \
    mesa-libgbm \
    libglvnd \
    libglvnd-glx \
    libglvnd-egl


dnf5 install -y \
    libglvnd.i686 \
    libglvnd-glx.i686 \
    libglvnd-egl.i686


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


# 32-bit X11
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
# GAMING / PERFORMANCE
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
    fontconfig


# ============================================================
# STEAM GAMING SUPPORT
# ============================================================

# Bazzite already contains Steam in normal desktop images.
# Install these extra runtime libraries for Windows games.

dnf5 install -y \
    libcurl \
    openssl \
    ca-certificates


# ============================================================
# GAMING DIRECTORIES
# ============================================================

mkdir -p \
    /usr/share/steam/compatibilitytools.d \
    /usr/local/share/dxvk \
    /usr/local/share/vkd3d-proton \
    /usr/local/share/gaming


# ============================================================
# PROTON-CACHYOS
# ============================================================

echo "============================================================"
echo "Installing Proton-CachyOS"
echo "============================================================"

PROTON_API="https://api.github.com/repos/CachyOS/proton-cachyos/releases/latest"

PROTON_JSON="$(curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    "$PROTON_API")"

PROTON_TAG="$(printf '%s' "$PROTON_JSON" | jq -r '.tag_name')"

echo "Proton-CachyOS version: $PROTON_TAG"

PROTON_URL="$(
    printf '%s' "$PROTON_JSON" |
    jq -r '
        .assets[]
        | select(
            (.name | test("\\.tar\\.xz$|\\.tar\\.gz$|\\.tar\\.zst$"))
            and
            (.name | test("x86_64|amd64"; "i"))
        )
        | .browser_download_url
    ' |
    head -n 1
)"

if [ -n "$PROTON_URL" ] && [ "$PROTON_URL" != "null" ]; then

    mkdir -p /tmp/proton-cachyos

    curl -fL \
        --retry 5 \
        --retry-all-errors \
        "$PROTON_URL" \
        -o /tmp/proton-cachyos/proton.tar

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

    esac

    rm -rf /tmp/proton-cachyos

else
    echo "WARNING: Proton-CachyOS archive was not found."
fi


# ============================================================
# DXVK
# ============================================================

echo "============================================================"
echo "Installing latest DXVK"
echo "============================================================"

DXVK_API="https://api.github.com/repos/doitsujin/dxvk/releases/latest"

DXVK_JSON="$(curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    "$DXVK_API")"

DXVK_URL="$(
    printf '%s' "$DXVK_JSON" |
    jq -r '
        .assets[]
        | select(.name | test("^dxvk-.*\\.tar\\.gz$"))
        | .browser_download_url
    ' |
    head -n 1
)"

if [ -n "$DXVK_URL" ] && [ "$DXVK_URL" != "null" ]; then

    mkdir -p /tmp/dxvk

    curl -fL \
        --retry 5 \
        --retry-all-errors \
        "$DXVK_URL" \
        -o /tmp/dxvk/dxvk.tar.gz

    tar -xzf \
        /tmp/dxvk/dxvk.tar.gz \
        -C /usr/local/share/dxvk \
        --strip-components=1

    rm -rf /tmp/dxvk

fi


# ============================================================
# VKD3D-PROTON
# ============================================================

echo "============================================================"
echo "Installing latest VKD3D-Proton"
echo "============================================================"

VKD3D_API="https://api.github.com/repos/HansKristian-Work/vkd3d-proton/releases/latest"

VKD3D_JSON="$(curl -fsSL \
    -H "Accept: application/vnd.github+json" \
    "$VKD3D_API")"

VKD3D_URL="$(
    printf '%s' "$VKD3D_JSON" |
    jq -r '
        .assets[]
        | select(.name | test("\\.tar\\.zst$|\\.tar\\.xz$|\\.tar\\.gz$"))
        | .browser_download_url
    ' |
    head -n 1
)"

if [ -n "$VKD3D_URL" ] && [ "$VKD3D_URL" != "null" ]; then

    mkdir -p /tmp/vkd3d

    curl -fL \
        --retry 5 \
        --retry-all-errors \
        "$VKD3D_URL" \
        -o /tmp/vkd3d/vkd3d.tar

    case "$VKD3D_URL" in

        *.tar.zst)
            tar --zstd -xf \
                /tmp/vkd3d/vkd3d.tar \
                -C /usr/local/share/vkd3d-proton \
                --strip-components=1
            ;;

        *.tar.xz)
            tar -xJf \
                /tmp/vkd3d/vkd3d.tar \
                -C /usr/local/share/vkd3d-proton \
                --strip-components=1
            ;;

        *.tar.gz)
            tar -xzf \
                /tmp/vkd3d/vkd3d.tar \
                -C /usr/local/share/vkd3d-proton \
                --strip-components=1
            ;;

    esac

    rm -rf /tmp/vkd3d

fi


# ============================================================
# GAMEMODE CONFIG
# ============================================================

mkdir -p /etc

cat > /etc/gamemode.ini <<'EOF'
[general]
renice=10
softrealtime=auto
inhibit_screensaver=1
EOF


# ============================================================
# MANGOHUD CONFIG
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
# WINE / PROTON ENVIRONMENT
# ============================================================

cat > /etc/profile.d/gaming.sh <<'EOF'
export WINEDEBUG="${WINEDEBUG:--all}"

export WINEESYNC="${WINEESYNC:-1}"
export WINEFSYNC="${WINEFSYNC:-1}"

export DXVK_LOG_LEVEL="${DXVK_LOG_LEVEL:-none}"

export DXVK_STATE_CACHE_PATH="${DXVK_STATE_CACHE_PATH:-$HOME/.cache/dxvk}"

export VKD3D_SHADER_CACHE_PATH="${VKD3D_SHADER_CACHE_PATH:-$HOME/.cache/vkd3d-proton}"

export STEAM_COMPAT_TOOLS_PATHS="${STEAM_COMPAT_TOOLS_PATHS:-/usr/share/steam/compatibilitytools.d}"
EOF

chmod 0644 /etc/profile.d/gaming.sh


# ============================================================
# ENABLE SYSTEM SERVICES
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
echo "Gaming components:"
echo "  Wine"
echo "  Winetricks"
echo "  Proton-CachyOS"
echo "  DXVK"
echo "  VKD3D-Proton"
echo "  Vulkan 64-bit"
echo "  Vulkan 32-bit"
echo "  Mesa"
echo "  Gamescope"
echo "  MangoHud"
echo "  GameMode"
echo "  PipeWire"
echo "  FFmpeg/GStreamer"
echo "  SDL2"
echo "  Windows compatibility libraries"
echo
echo "============================================================"
