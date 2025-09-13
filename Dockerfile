# syntax=docker/dockerfile:1

# Use Fedora as base OS as requested
FROM fedora:42

# labels and args
ARG BUILD_DATE
ARG VERSION
# v4.103.2
ARG CODE_RELEASE 
LABEL org.opencontainers.image.title="code-server on Fedora"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL maintainer="container-code-server maintainers"

# environment
ENV HOME="/config"

#
# Runtime and build dependencies via dnf
# - Development Tools group for build essentials
# - Fonts: IBM Plex
# - Utilities required by scripts and code-server
#
RUN set -eux; \
  echo "**** install runtime dependencies ****"; \
  dnf -y update; \
  dnf -y install \
    git \
    libatomic \
    nano \
    net-tools \
    sudo \
    curl \
    tar \
    ca-certificates \
    nmap-ncat \
    fontconfig \
    ibm-plex-fonts-all; \
  echo "**** install development tools ****"; \
  dnf -y group install development-tools; \
  echo "**** create abc user and prepare dirs ****"; \
  groupadd -g 911 abc; \
  useradd -u 911 -g 911 -m -s /bin/bash abc; \
  mkdir -p /config/extensions /config/data /config/workspace /app/code-server; \
  chown -R abc:abc /config; \
  echo "**** install code-server ****"; \
  if [ -z ${CODE_RELEASE+x} ]; then \
    CODE_RELEASE=$(curl -sX GET https://api.github.com/repos/coder/code-server/releases/latest \
      | awk '/tag_name/{print $4;exit}' FS='["\"]' | sed 's|^v||'); \
  fi; \
  ARCH_TARBALL="linux-amd64"; \
  case "$(uname -m)" in \
    aarch64|arm64) ARCH_TARBALL="linux-arm64" ;; \
    x86_64|amd64) ARCH_TARBALL="linux-amd64" ;; \
    *) echo "Unsupported architecture: $(uname -m)"; exit 1 ;; \
  esac; \
  curl -o /tmp/code-server.tar.gz -L \
    "https://github.com/coder/code-server/releases/download/v${CODE_RELEASE}/code-server-${CODE_RELEASE}-${ARCH_TARBALL}.tar.gz"; \
  tar xf /tmp/code-server.tar.gz -C /app/code-server --strip-components=1; \
  printf "Linuxserver.io version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version; \
  echo "**** clean up ****"; \
  dnf clean all; \
  rm -rf /var/cache/dnf/* /tmp/* /var/tmp/*

# Install Rust (non-interactive) for user abc
USER abc
ENV PATH="/home/abc/.cargo/bin:${PATH}"
RUN set -eux; \
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# copy helper scripts and set entrypoint
USER root
COPY container-root/ /
RUN chmod +x /usr/local/bin/start-code-server /usr/local/bin/install-extension && \
    chown -R abc:abc /usr/local/bin

# keep root for entrypoint to fix permissions, then drop to abc inside script
USER root

# ports and volumes
EXPOSE 8443

# default command
ENTRYPOINT ["/usr/local/bin/start-code-server"]
