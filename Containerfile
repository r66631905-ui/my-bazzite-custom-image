# Allow build scripts to be referenced without being copied
# into the final image.
FROM scratch AS ctx

COPY build_files /
COPY system_files /system_files


# ============================================================
# BASE IMAGE
# ============================================================

FROM ghcr.io/ublue-os/bazzite:stable@sha256:b923f92d5a5b59eb992e269383eba2744601052da9d3d1595f76e79aa6ce2df0


# ============================================================
# OPTIONAL: IMMUTABLE /opt
# ============================================================
#
# Bazzite/bootc images may use /opt -> /var/opt.
# Uncomment only if you specifically need /opt to be immutable.
#
# RUN rm -rf /opt && mkdir -p /opt


# ============================================================
# GAMING MODIFICATIONS
# ============================================================

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh


# ============================================================
# LINT
# ============================================================

RUN bootc container lint
