# ffmpeg with NVIDIA NVENC/NVDEC (hevc_nvenc, av1_nvenc) and CPU encoders (libx265, libsvtav1, libaom-av1)
#
# Codec libraries come from Ubuntu. Only ffmpeg and nv-codec-headers are built.
# NVENC needs no CUDA toolkit: ffmpeg loads the driver libraries at run time.
# In WSL they are /usr/lib/wsl/lib, see process-video.sh for the docker run flags.
#
# docker build --tag vetalca/ffmpeg:9.1 dockerfiles/ffmpeg

ARG UBUNTU_VERSION=26.04

FROM ubuntu:${UBUNTU_VERSION} AS build

# https://ffmpeg.org/releases/
ARG FFMPEG_VERSION=9.1
# https://github.com/FFmpeg/nv-codec-headers/tags. Newer headers need a newer driver.
ARG NV_CODEC_HEADERS_VERSION=n13.1.15.0

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
        build-essential ca-certificates curl git nasm pkg-config xz-utils \
        libaom-dev libass-dev libdav1d-dev libfreetype-dev libmp3lame-dev libopus-dev \
        libsvtav1enc-dev libvidstab-dev libvorbis-dev libvpx-dev libwebp-dev \
        libx264-dev libx265-dev libzimg-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch "${NV_CODEC_HEADERS_VERSION}" https://github.com/FFmpeg/nv-codec-headers.git /tmp/nv-codec-headers \
    && make -C /tmp/nv-codec-headers install PREFIX=/usr/local \
    && rm -rf /tmp/nv-codec-headers

WORKDIR /tmp/ffmpeg
RUN curl --fail --silent --show-error --location "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz" \
        | tar --extract --xz --strip-components=1 \
    && ./configure \
        --prefix=/opt/ffmpeg \
        --disable-debug \
        --disable-doc \
        --disable-ffplay \
        --enable-gpl \
        --enable-version3 \
        --enable-ffnvcodec \
        --enable-nvenc \
        --enable-nvdec \
        --enable-cuvid \
        --enable-libaom \
        --enable-libass \
        --enable-libdav1d \
        --enable-libfreetype \
        --enable-libmp3lame \
        --enable-libopus \
        --enable-libsvtav1 \
        --enable-libvidstab \
        --enable-libvorbis \
        --enable-libvpx \
        --enable-libwebp \
        --enable-libx264 \
        --enable-libx265 \
        --enable-libzimg \
    && make --jobs="$(nproc)" \
    && make install \
    && make --directory=tools qt-faststart \
    && cp tools/qt-faststart /opt/ffmpeg/bin/

# Ubuntu packages the binaries link to, for the release stage
RUN ldd /opt/ffmpeg/bin/* | awk '/=> \// { print $3 }' | sort --unique \
        | xargs dpkg --search 2> /dev/null | cut --delimiter=: --fields=1 | sort --unique \
        > /opt/ffmpeg/runtime-packages.txt


FROM ubuntu:${UBUNTU_VERSION} AS release

COPY --from=build /opt/ffmpeg/runtime-packages.txt /tmp/
RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends \
        ca-certificates curl $(cat /tmp/runtime-packages.txt) \
    && rm -rf /var/lib/apt/lists/* /tmp/runtime-packages.txt \
    && mkdir /data \
    && curl --fail --silent --show-error --location \
        https://github.com/dubhater/vapoursynth-nnedi3/raw/master/src/nnedi3_weights.bin \
        --output /data/nnedi3_weights.bin

COPY --from=build /opt/ffmpeg/bin/ /usr/local/bin/

# WSL GPU driver libraries, mounted at run time
ENV LD_LIBRARY_PATH=/usr/lib/wsl/lib

ENTRYPOINT ["ffmpeg"]
CMD ["-hide_banner", "-encoders"]
