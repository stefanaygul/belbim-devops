# Katilimcinin egitim makinesi: git, .NET SDK, Node.js ve kendi Docker daemon'i.
# Build context: lab-ortami/images
ARG UBUNTU_TAG=noble-20261110
ARG DOTNET_SDK_TAG=10.0.404
ARG NODE_TAG=24.22.3-bookworm-slim
ARG DOCKER_TAG=29.10.0-dind

FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_SDK_TAG} AS dotnet
FROM node:${NODE_TAG} AS node
FROM docker:${DOCKER_TAG} AS docker

FROM ubuntu:${UBUNTU_TAG}
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git jq make sudo openssh-client less nano vim-tiny unzip tree \
      iproute2 iputils-ping dnsutils procps psmisc bash-completion \
      iptables xz-utils pigz kmod \
      libicu74 libssl3t64 libstdc++6 tzdata \
 && rm -rf /var/lib/apt/lists/*

# .NET SDK (resmi imajdan, surumu sabit)
COPY --from=dotnet /usr/share/dotnet /usr/share/dotnet
RUN ln -s /usr/share/dotnet/dotnet /usr/local/bin/dotnet
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1 \
    DOTNET_NOLOGO=1 \
    DOTNET_GENERATE_ASPNET_CERTIFICATE=false

# Node.js + npm
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s ../lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
 && ln -s ../lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# Docker Engine, CLI, buildx ve compose (statik ikili dosyalar)
COPY --from=docker /usr/local/bin/docker /usr/local/bin/dockerd /usr/local/bin/docker-proxy \
     /usr/local/bin/docker-init /usr/local/bin/runc /usr/local/bin/ctr \
     /usr/local/bin/containerd-shim-runc-v2 /usr/local/bin/dind /usr/local/bin/
COPY --from=docker /usr/local/libexec/docker/cli-plugins /usr/local/libexec/docker/cli-plugins

# Docker daemon'in baslangicta gordugu guven deposu: yalnizca genel CA'lar.
# Lab CA'si isletim sistemine eklenir ama daemon'a tanitilmaz; bunu katilimci yapar.
RUN install -D -m 0644 /etc/ssl/certs/ca-certificates.crt /usr/local/share/lab/public-ca-bundle.crt

# Ekip kullanicilari `lab` grubundadir; egitim makinesinde sudo ve docker yetkileri vardir.
RUN (userdel --remove ubuntu 2>/dev/null || true) \
 && groupadd --gid 990 docker \
 && groupadd --gid 1900 lab \
 && echo '%lab ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/lab \
 && chmod 0440 /etc/sudoers.d/lab

COPY common/dockerd-start.sh /usr/local/bin/lab-dockerd-start
COPY workstation/entrypoint.sh /usr/local/bin/lab-entrypoint
COPY workstation/lab-users.sh /usr/local/bin/lab-users
COPY workstation/profile.sh /etc/profile.d/lab.sh
RUN chmod 0755 /usr/local/bin/lab-dockerd-start /usr/local/bin/lab-entrypoint /usr/local/bin/lab-users \
 && echo '. /etc/profile.d/lab.sh' >> /etc/bash.bashrc

ENTRYPOINT ["/usr/local/bin/lab-entrypoint"]
