FROM ubuntu:22.04

RUN useradd -U -d /config -s /bin/false plex

RUN mkdir -p /config /transcode /data

ENV DEBIAN_FRONTEND=noninteractive \
  TERM="xterm" \
  LANG="C.UTF-8" \
  LC_ALL="C.UTF-8" \
  PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR="/config/Library/Application Support" \
  PLEX_MEDIA_SERVER_PREFERENCES_FILE="/config/Library/Application Support/Plex Media Server/Preferences.xml" \
  PLEX_MEDIA_SERVER_HOME=/usr/lib/plexmediaserver \
  PLEX_MEDIA_SERVER_MAX_PLUGIN_PROCS=6 \
  PLEX_MEDIA_SERVER_INFO_VENDOR=Docker \
  PLEX_MEDIA_SERVER_INFO_DEVICE="Docker Container"

EXPOSE 32400/tcp 8324/tcp 32469/tcp 1900/udp 32410/udp 32412/udp 32413/udp 32414/udp
VOLUME /config /transcode

ARG PLEX_VERSION=1.30.2.6563-3d4dc0cce
ARG INTEL_NEO_VERSION=20.48.18558
ARG INTEL_IGC_VERSION=1.0.5699
ARG INTEL_GMMLIB_VERSION=20.3.2

ADD https://github.com/intel/compute-runtime/releases/download/${INTEL_NEO_VERSION}/intel-gmmlib_${INTEL_GMMLIB_VERSION}_amd64.deb /tmp/gmmlib.deb
ADD https://github.com/intel/intel-graphics-compiler/releases/download/igc-${INTEL_IGC_VERSION}/intel-igc-core_${INTEL_IGC_VERSION}_amd64.deb /tmp/intel-igc-core.deb
ADD https://github.com/intel/intel-graphics-compiler/releases/download/igc-${INTEL_IGC_VERSION}/intel-igc-opencl_${INTEL_IGC_VERSION}_amd64.deb /tmp/intel-igc-opencl.deb
ADD https://github.com/intel/compute-runtime/releases/download/${INTEL_NEO_VERSION}/intel-opencl_${INTEL_NEO_VERSION}_amd64.deb /tmp/intel-opencl.deb
ADD https://downloads.plex.tv/plex-media-server-new/${PLEX_VERSION}/debian/plexmediaserver_${PLEX_VERSION}_amd64.deb /tmp/plexmediaserver.deb

RUN apt-get update && \
  apt-get install --no-install-recommends \
  curl \
  ca-certificates \
  tzdata \
  xmlstarlet \
  uuid-runtime \
  unrar \
  intel-opencl-icd \
  ocl-icd-libopencl1 \
  --yes \
  --no-install-recommends && \
  \
  apt-get --option Dpkg::Options='--force-confold --force-architecture' --yes --no-install-recommends \
  install /tmp/gmmlib.deb /tmp/intel-igc-core.deb /tmp/intel-igc-opencl.deb /tmp/intel-opencl.deb /tmp/plexmediaserver.deb && \
  # Cleanup
  apt-get -y autoremove && \
  apt-get -y clean && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /tmp/* && \
  rm -rf /var/tmp/*

COPY entrypoint.sh /entrypoint

# Plex user, use numerical id to be compatible with Kubernetes security contexts
USER 1000

ENTRYPOINT ["/entrypoint"]
