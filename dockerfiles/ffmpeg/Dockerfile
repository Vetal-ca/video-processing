# ffmpeg - http://ffmpeg.org/download.html
#
# https://hub.docker.com/r/jrottenberg/ffmpeg/
#
#

FROM        alpine:3.19.0 AS base

RUN apk add --no-cache --virtual .build-deps \
    build-base \
    cmake \
    git \
    libjpeg-turbo-dev \
    libpng-dev \
    libwebp-dev \
    tiff-dev \
    openblas-dev \
    python3-dev \
    py3-numpy \
    linux-headers \
    musl-dev


# Cleanup build dependencies
RUN apk del .build-deps && \
    rm -rf /opencv /var/cache/apk/*


FROM        base AS build

WORKDIR     /tmp/workdir

ARG        PKG_CONFIG_PATH=/opt/ffmpeg/lib/pkgconfig
ARG        LD_LIBRARY_PATH=/opt/ffmpeg/lib
ARG        PREFIX=/opt/ffmpeg
ARG        MAKEFLAGS="-j2"

ENV         FFMPEG_VERSION=6.1.1      \
            FDKAAC_VERSION=2.0.3      \
            LAME_VERSION=3.100        \
            LIBASS_VERSION=0.17.1     \
            OGG_VERSION=1.3.5         \
            OPENCOREAMR_VERSION=0.1.6 \
            OPUS_VERSION=1.5.2          \
            OPENJPEG_VERSION=2.5.0    \
            VORBIS_VERSION=1.3.7      \
            VPX_VERSION=1.14.0        \
            X264_VERSION=20240411-2245 \
            X265_VERSION=3.5          \
            XVID_VERSION=1.3.7        \
            FREETYPE_VERSION=2.13.2   \
            FRIBIDI_VERSION=1.0.16    \
            FONTCONFIG_VERSION=2.15.0 \
            LIBVIDSTAB_VERSION=1.1.1  \
            KVAZAAR_VERSION=2.3.1     \
            AOM_VERSION=v3.12.0        \
            SVT_AV1_VERSION=1.7.0     \
            DOVI_VERSION=1.3.1        \
            ZIMG_VERSION=3.0.5        \
            VMAF_VERSION=2.3.1        \
            OPENCV_VERSION="4.11.0"   \
            PYTHON_VERSION="3.11"     \
            SRC=/usr/local



# Update checksum values for updated packages
ARG         OGG_SHA256SUM="0eb4b4b9420a0f51db142ba3f9c64b333f826532dc0f48c6410ae51f4799b664  libogg-${OGG_VERSION}.tar.gz"
ARG         VORBIS_SHA256SUM="0e982409a9c3fc82ee06e08205b1355e5c6aa4c36bca58146ef399621b0ce5ab  libvorbis-${VORBIS_VERSION}.tar.gz"
ARG         XVID_SHA256SUM="abbdcbd39555691dd1c9b4d08f0a031376a3b211652c0d8b3b8aa9be1303ce2d  xvidcore-${XVID_VERSION}.tar.gz"
ARG         FREETYPE_SHA256SUM="1ac27e16c134a7f2ccea177faba19801131116fd682efc1f5737037c5db224b5  freetype-${FREETYPE_VERSION}.tar.gz"
ARG         LIBVIDSTAB_SHA256SUM="9001b6df73933555e56deac19a0f225aae152abbc0e97dc70034814a1943f3d4  v${LIBVIDSTAB_VERSION}.tar.gz"
ARG         LIBASS_SHA256SUM="5ba42655d7e8c5e87bba3ffc8a2b1bc19c29904240126bb0d4b924f39429219f  ${LIBASS_VERSION}.tar.gz"
ARG         FRIBIDI_SHA256SUM="f9220c5a261c980dca30c08a2181cfbe1681dfcd9ed8cbcf18816624bf9a2c1d  v${FRIBIDI_VERSION}.tar.gz"

# Freebd:         build-base, meson, ninja

RUN     buildDeps="autoconf \
                   automake \
                   bash \
                   binutils \
                   bzip2 \
                   cmake \
                   curl \
                   coreutils \
                   diffutils \
                   file \
                   g++ \
                   gcc \
                   git \
                   gperf \
                   harfbuzz-dev \
                   libtool \
                   make \
                   nasm \
                   python3 \
                   openssl-dev \
                   tar \
                   yasm \
                   zlib-dev \
                   opencv-dev \
                   expat-dev \
                   build-base \
                   meson \
                   ninja \
                   python3-dev \
                   py3-pip \
                   py3-numpy \
                   py3-numpy-dev \
                   qt6-qt5compat-dev" && \
        apk  add --no-cache --update ${buildDeps}

# OpenCV:

## opencore-amr https://sourceforge.net/projects/opencore-amr/
RUN \
        DIR=/tmp/opencore-amr && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -fL "https://downloads.sourceforge.net/project/opencore-amr/opencore-amr/opencore-amr-${OPENCOREAMR_VERSION}.tar.gz" | \
        tar -xz --strip-components=1 && \
        ./configure --prefix="${PREFIX}" --enable-shared && \
        make -j$(nproc) && \
        make install && \
        rm -rf ${DIR}

## x264 http://www.videolan.org/developers/x264.html
RUN \
        DIR=/tmp/x264 && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        git clone https://code.videolan.org/videolan/x264.git --branch stable && \
        cd x264 && \
        ./configure --prefix=/usr/local --enable-shared --enable-pic --disable-cli && \
        make -j$(nproc) && \
        make install && \
        rm -rf ${DIR}

### x265 http://x265.org/
RUN \
        DIR=/tmp/x265 && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sL https://download.videolan.org/pub/videolan/x265/x265_${X265_VERSION}.tar.gz  | \
        tar -zx && \
        cd x265_${X265_VERSION}/build/linux && \
        sed -i "/-DEXTRA_LIB/ s/$/ -DCMAKE_INSTALL_PREFIX=\${PREFIX}/" multilib.sh && \
        sed -i "/^cmake/ s/$/ -DENABLE_CLI=OFF/" multilib.sh && \
        ./multilib.sh && \
        make -C 8bit install -j$(nproc) && \
        rm -rf ${DIR}
### libogg https://www.xiph.org/ogg/
RUN \
        DIR=/tmp/ogg && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO http://downloads.xiph.org/releases/ogg/libogg-${OGG_VERSION}.tar.gz && \
        echo ${OGG_SHA256SUM} | sha256sum --check && \
        tar -zx --strip-components=1 -f libogg-${OGG_VERSION}.tar.gz && \
        ./configure --prefix="${PREFIX}" --enable-shared  && \
        make -j$(nproc) && \
        make install && \
        rm -rf ${DIR}

### libopus https://www.opus-codec.org/
RUN \
        DIR=/tmp/opus && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        git clone  https://github.com/xiph/opus.git && \
        cd opus &&\
        autoreconf -fiv && \
        ./configure --prefix="${PREFIX}" --enable-shared && \
        make -j$(nproc) && \
        make install && \
        rm -rf ${DIR}

### libvorbis https://xiph.org/vorbis/
RUN \
        DIR=/tmp/vorbis && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO http://downloads.xiph.org/releases/vorbis/libvorbis-${VORBIS_VERSION}.tar.gz && \
        echo ${VORBIS_SHA256SUM} | sha256sum --check && \
        tar -zx --strip-components=1 -f libvorbis-${VORBIS_VERSION}.tar.gz && \
        ./configure --prefix="${PREFIX}" --with-ogg="${PREFIX}" --enable-shared && \
        make -j$(nproc) && \
        make install && \
        rm -rf ${DIR} \

### libtheora http://www.theora.org/
# https://gitlab.xiph.org/xiph/theora/-/issues/1947
# https://stackoverflow.com/questions/22603163/automake-error-ltmain-sh-not-found
RUN \
        DIR=/tmp/theora && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        git clone https://gitlab.xiph.org/xiph/theora theora && \
        cd theora && \
        autoreconf --install && \
        automake --add-missing && \
        autoconf && \
        ./configure --prefix="${PREFIX}" --with-ogg="${PREFIX}" --enable-shared && \
        make -j$(nproc) && \
        make install &&\
        rm -rf ${DIR}

### libvpx https://www.webmproject.org/code/
RUN \
        DIR=/tmp/vpx && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sL https://codeload.github.com/webmproject/libvpx/tar.gz/v${VPX_VERSION} | \
        tar -zx --strip-components=1 && \
        ./configure --prefix="${PREFIX}" --enable-vp8 --enable-vp9 --enable-vp9-highbitdepth --enable-pic --enable-shared \
        --disable-debug --disable-examples --disable-docs --disable-install-bins  && \
        make -j$(nproc) && \
        make install && \
        rm -rf ${DIR}

### libmp3lame http://lame.sourceforge.net/
RUN \
        DIR=/tmp/lame && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        git clone https://github.com/zlargon/lame && cd lame && \
        ./configure --prefix="${PREFIX}" --bindir="${PREFIX}/bin" --enable-shared --enable-nasm --enable-pic --disable-frontend && \
        make -j$(nproc) && \
        make install && \
        rm -rf ${DIR} \

### xvid https://www.xvid.com/
RUN \
        DIR=/tmp/xvid && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO http://downloads.xvid.org/downloads/xvidcore-${XVID_VERSION}.tar.gz && \
        echo ${XVID_SHA256SUM} | sha256sum --check && \
        tar -zx -f xvidcore-${XVID_VERSION}.tar.gz && \
        cd xvidcore/build/generic && \
        ./configure --prefix="${PREFIX}" --bindir="${PREFIX}/bin" --datadir="${DIR}" --enable-shared --enable-shared && \
        make -j$(nproc) && \
        make install && \
        rm -rf ${DIR}

### fdk-aac https://github.com/mstorsjo/fdk-aac
RUN \
        DIR=/tmp/fdk-aac && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sL https://github.com/mstorsjo/fdk-aac/archive/v${FDKAAC_VERSION}.tar.gz | \
        tar -zx --strip-components=1 && \
        autoreconf -fiv && \
        ./configure --prefix="${PREFIX}" --enable-shared --datadir="${DIR}" && \
        make -j$(nproc) && \
        make install && \
        rm -rf ${DIR}

## openjpeg https://github.com/uclouvain/openjpeg
RUN \
        DIR=/tmp/openjpeg && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sL https://github.com/uclouvain/openjpeg/archive/v${OPENJPEG_VERSION}.tar.gz | \
        tar -zx --strip-components=1 && \
        cmake -DBUILD_THIRDPARTY:BOOL=ON -DCMAKE_INSTALL_PREFIX="${PREFIX}" . && \
        make -j$(nproc) && \
        make install && \
        rm -rf ${DIR}
## freetype https://www.freetype.org/
RUN  \
        DIR=/tmp/freetype && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO https://download.savannah.gnu.org/releases/freetype/freetype-${FREETYPE_VERSION}.tar.gz && \
        echo ${FREETYPE_SHA256SUM} | sha256sum --check && \
        tar -zx --strip-components=1 -f freetype-${FREETYPE_VERSION}.tar.gz && \
        ./configure --prefix="${PREFIX}" --disable-static --enable-shared && \
        make -j$(nproc) && \
        make install && \
        rm -rf ${DIR}
## libvstab https://github.com/georgmartius/vid.stab
RUN  \
        DIR=/tmp/vid.stab && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO https://github.com/georgmartius/vid.stab/archive/v${LIBVIDSTAB_VERSION}.tar.gz &&\
        echo ${LIBVIDSTAB_SHA256SUM} | sha256sum --check && \
        tar -zx --strip-components=1 -f v${LIBVIDSTAB_VERSION}.tar.gz && \
        cmake -DCMAKE_INSTALL_PREFIX="${PREFIX}" . && \
        make -j$(nproc) && \
        make install && \
        rm -rf ${DIR}

## fridibi https://www.fribidi.org/
# + https://github.com/fribidi/fribidi/issues/8
RUN  \
        DIR=/tmp/fribidi && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        git clone https://github.com/fribidi/fribidi.git &&\
        cd fribidi && \
        git checkout "tags/v${FRIBIDI_VERSION}" && \
        meson setup builddir -Ddefault_library=shared --prefix="${PREFIX}" -Ddocs=false -Dtests=false -Dbin=false &&\
        meson compile -C builddir -j 1 &&\
        meson install -C builddir &&\
        rm -rf ${DIR}

## fontconfig https://www.freedesktop.org/wiki/Software/fontconfig/
RUN  \
        DIR=/tmp/fontconfig && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO https://www.freedesktop.org/software/fontconfig/release/fontconfig-${FONTCONFIG_VERSION}.tar.gz &&\
        tar -zx --strip-components=1 -f fontconfig-${FONTCONFIG_VERSION}.tar.gz && \
        ./configure -prefix="${PREFIX}" --disable-static --enable-shared && \
        make -j$(nproc) && \
        make install && \
        rm -rf ${DIR}

## libass https://github.com/libass/libass
RUN  \
        DIR=/tmp/libass && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO https://github.com/libass/libass/archive/${LIBASS_VERSION}.tar.gz &&\
        echo ${LIBASS_SHA256SUM} | sha256sum --check && \
        tar -zx --strip-components=1 -f ${LIBASS_VERSION}.tar.gz && \
        ./autogen.sh && \
        ./configure -prefix="${PREFIX}" --disable-static --enable-shared && \
        make -j$(nproc) && \
        make install && \
        rm -rf ${DIR}

## kvazaar https://github.com/ultravideo/kvazaar
RUN \
        DIR=/tmp/kvazaar && \
        mkdir -p ${DIR} && \
        cd ${DIR} && \
        curl -sLO https://github.com/ultravideo/kvazaar/archive/v${KVAZAAR_VERSION}.tar.gz &&\
        tar -zx --strip-components=1 -f v${KVAZAAR_VERSION}.tar.gz && \
        ./autogen.sh && \
        ./configure -prefix="${PREFIX}" --disable-static --enable-shared && \
        make -j$(nproc) && \
        make install && \
        rm -rf ${DIR}

RUN \
	DIR=/tmp/aom && \
        git clone --branch ${AOM_VERSION} --depth 1 https://aomedia.googlesource.com/aom ${DIR} ; \
        cd ${DIR} ; \
        rm -rf CMakeCache.txt CMakeFiles ; \
        mkdir -p ./aom_build ; \
        cd ./aom_build ; \
        cmake -DCMAKE_INSTALL_PREFIX="${PREFIX}" -DBUILD_SHARED_LIBS=1 ..; \
        make -j$(nproc); \
        make install ; \
        rm -rf ${DIR}


RUN cd /tmp &&\
    git clone --depth=1 --branch="${OPENCV_VERSION}" https://github.com/opencv/opencv_contrib.git &&\
    dir="/tmp/opencv" &&\
    git clone --depth=1 --branch="${OPENCV_VERSION}" https://github.com/opencv/opencv.git "${dir}" && \
    mkdir "${dir}/build" &&  cd "${dir}/build" && \
    cmake \
      -D CMAKE_BUILD_TYPE=RELEASE \
      -D BUILD_PYTHON_SUPPORT=ON \
      -D BUILD_DOCS=ON \
      -D BUILD_PERF_TESTS=OFF \
      -D BUILD_TESTS=OFF \
      -D CMAKE_INSTALL_PREFIX=/usr/local \
      -D OPENCV_EXTRA_MODULES_PATH=/tmp/opencv_contrib/modules \
      -D OPENCV_GENERATE_PKGCONFIG=ON \
      -D BUILD_opencv_python3=ON \
      -D BUILD_opencv_python2=OFF \
      -D PYTHON3_EXECUTABLE=/usr/bin/python3 \
      -D PYTHON_EXECUTABLE=/usr/bin/python3 \
      -D PYTHON_INCLUDE_DIR=/usr/include/python${PYTHON_VERSION} \
      -D PYTHON_LIBRARY=/usr/lib/libpython${PYTHON_VERSION}.so \
      -D PYTHON3_NUMPY_INCLUDE_DIRS=/usr/lib/python${PYTHON_VERSION}/site-packages/numpy/core/include \
      -D BUILD_EXAMPLES=OFF \
      -D BUILD_opencv_highgui=OFF \
      -D WITH_IPP=OFF \
      -D WITH_FFMPEG=ON \
      -D WITH_GSTREAMER=ON \
      -D WITH_V4L=ON \
      -D WITH_LIBV4L=ON \
      -D WITH_TBB=ON \
      -D WITH_QT=ON \
      -D WITH_OPENGL=ON \
      -D WITH_LAPACK=ON \
      -D OPENCV_ENABLE_NONFREE=ON\
      -D OPENCV_WORLD_MODULES=""\
      -D ENABLE_PRECOMPILED_HEADERS=OFF .. &&\
      make -j$(nproc) &&\
      make install && \
      cd /tmp && rm -rf ${dir}


## ffmpeg https://ffmpeg.org/
## ffmpeg configuration
RUN \
        DIR=/tmp/ffmpeg && mkdir -p ${DIR} && cd ${DIR} && \
        echo "PKG_CONFIG_PATH is: $PKG_CONFIG_PATH" && \
        curl -sLO https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.bz2 && \
        tar -jx --strip-components=1 -f ffmpeg-${FFMPEG_VERSION}.tar.bz2 && \
        ./configure \
        --pkg-config=pkg-config \
        --disable-debug \
        --disable-doc \
        --disable-ffplay \
        --enable-shared \
        --enable-swresample \
        --enable-libopencore-amrnb \
        --enable-libopencore-amrwb \
        --enable-gpl \
        --enable-libass \
        --enable-libfreetype \
        --enable-libvidstab \
        --enable-libmp3lame \
        --enable-libopenjpeg \
        --enable-libopus \
        --enable-libtheora \
        --enable-libvorbis \
        --enable-libvpx \
        --enable-libx265 \
        --enable-libxvid \
        --enable-libx264 \
        --enable-nonfree \
        --enable-openssl \
        --enable-libfdk_aac \
        --enable-libkvazaar \
        --enable-libaom --extra-libs=-lpthread \
        --enable-postproc \
        --enable-small \
        --enable-version3 \
        --enable-libopencv \
        --enable-filter=eis \
        --extra-cflags="-I${PREFIX}/include -I/usr/local/include/opencv4" \
        --extra-ldflags="-L${PREFIX}/lib" \
        --extra-libs="-laom -lpthread" \
        --extra-libs=-ldl \
        --prefix="${PREFIX}" || cat ffbuild/config.log && \
        make -j$(nproc) && \
        make install && \
        make distclean && \
        hash -r && \
        cd tools && \
        make qt-faststart && \
        cp qt-faststart ${PREFIX}/bin

       # --extra-cflags="-I${PREFIX}/include -I/usr/local/include/opencv4 -I/usr/include/opencv4" \

RUN \
    ldd ${PREFIX}/bin/ffmpeg | grep opt/ffmpeg | cut -d ' ' -f 3 | xargs -i cp {} /usr/local/lib/ && \
    cp ${PREFIX}/bin/* /usr/local/bin/ && \
    cp -r ${PREFIX}/share/ffmpeg /usr/local/share/ && \
    LD_LIBRARY_PATH=/usr/local/lib ffmpeg -buildconf

## Release Stage
FROM        base AS release
MAINTAINER  Vitali Khlebko <vitali.khlebko@vetal.ca>

# https://ffmpeg.org/ffmpeg-all.html#nnedi
RUN mkdir /data && \
    apk  add --no-cache --update curl libxcb libbz2 harfbuzz && \
    curl --silent --location https://github.com/dubhater/vapoursynth-nnedi3/raw/master/src/nnedi3_weights.bin --output /data/nnedi3_weights.bin

CMD         ["--help"]
ENTRYPOINT  ["ffmpeg"]

COPY --from=build /usr/local /usr/local
# Not sure if this is needed
COPY --from=build /usr/lib/libva.so.2 /usr/lib/
COPY --from=build /usr/lib/libva-drm.so.2 /usr/lib/
COPY --from=build /usr/lib/libva-x11.so.2 /usr/lib/
COPY --from=build /usr/lib/liblzma.so.5 /usr/lib/
COPY --from=build /usr/lib/libX11.so.6 /usr/lib/
COPY --from=build /usr/lib/libGL.so.1 /usr/lib/
COPY --from=build /usr/lib/libopenblas.so.3 /usr/lib/
COPY --from=build /usr/lib/libtbb.so.12 /usr/lib/
COPY --from=build /usr/lib/libstdc++.so.6 /usr/lib/
COPY --from=build /usr/lib/libgcc_s.so.1 /usr/lib/
COPY --from=build /usr/lib/libgomp.so.1 /usr/lib/
COPY --from=build /usr/lib/libexpat.so.1 /usr/lib/
COPY --from=build /usr/local/lib/libopencv_core.so.411 /usr/local/lib/
COPY --from=build /usr/lib/libdrm.so.2 /usr/lib/
COPY --from=build /usr/lib/libXext.so.6 /usr/lib/
COPY --from=build /usr/lib/libXfixes.so.3 /usr/lib/
COPY --from=build /usr/lib/libX11-xcb.so.1 /usr/lib/
COPY --from=build /usr/lib/libglapi.so.0 /usr/lib/
COPY --from=build /usr/lib/libXxf86vm.so.1 /usr/lib/
COPY --from=build /usr/lib/libxshmfence.so.1 /usr/lib/
COPY --from=build /usr/lib/libgfortran.so.5 /usr/lib/
COPY --from=build /usr/lib/libquadmath.so.0 /usr/lib/


ENV LD_LIBRARY_PATH="/usr/local/lib:/usr/lib"
#RUN ldconfig


 #Let's make sure the app built correctly
 #Convenient to verify on https://hub.docker.com/r/jrottenberg/ffmpeg/builds/ console output