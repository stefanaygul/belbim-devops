# "Ikinci VM" / test VM: yalnizca Docker ve SSH sunucusu. Kaynak kod ve SDK yoktur.
# Build context: lab-ortami/images
ARG UBUNTU_TAG=noble-20261110
ARG DOCKER_TAG=29.10.0-dind

FROM docker:${DOCKER_TAG} AS docker

FROM ubuntu:${UBUNTU_TAG}
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl jq openssh-server less nano \
      iproute2 iputils-ping dnsutils procps \
      iptables xz-utils pigz kmod \
 && rm -rf /var/lib/apt/lists/* \
 && rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub \
 && mkdir -p /run/sshd

COPY --from=docker /usr/local/bin/docker /usr/local/bin/dockerd /usr/local/bin/docker-proxy \
     /usr/local/bin/docker-init /usr/local/bin/runc /usr/local/bin/ctr \
     /usr/local/bin/containerd-shim-runc-v2 /usr/local/bin/dind /usr/local/bin/
COPY --from=docker /usr/local/libexec/docker/cli-plugins /usr/local/libexec/docker/cli-plugins

# deploy kullanicisi docker grubundadir; sudo yetkisi yoktur. Parolasi yoktur
# (yalnizca SSH anahtari); `usermod -p '*'` hesabi kilitli durumdan cikarir.
RUN (userdel --remove ubuntu 2>/dev/null || true) \
 && groupadd --gid 990 docker \
 && useradd --uid 1500 --user-group --groups docker --shell /bin/bash --no-create-home \
            --home-dir /home/deploy deploy \
 && usermod -p '*' deploy

COPY test-vm/sshd_lab.conf /etc/ssh/sshd_config.d/lab.conf
COPY common/dockerd-start.sh /usr/local/bin/lab-dockerd-start
COPY test-vm/entrypoint.sh /usr/local/bin/lab-entrypoint
RUN chmod 0755 /usr/local/bin/lab-dockerd-start /usr/local/bin/lab-entrypoint

EXPOSE 22
ENTRYPOINT ["/usr/local/bin/lab-entrypoint"]
