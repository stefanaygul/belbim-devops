# Bootstrap ve dogrulama betiklerinin calistigi arac imaji.
# Build context: lab-ortami/images
ARG UBUNTU_TAG=noble-20261110
FROM ubuntu:${UBUNTU_TAG}
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl jq git openssl openssh-client skopeo dnsutils \
 && rm -rf /var/lib/apt/lists/*

COPY araclar/entrypoint.sh /usr/local/bin/lab-entrypoint
RUN chmod 0755 /usr/local/bin/lab-entrypoint

ENTRYPOINT ["/usr/local/bin/lab-entrypoint"]
CMD ["bash"]
