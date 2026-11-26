#!/bin/sh
# Jenkins agent'in Docker daemon'i (docker:dind imaji icinde calisir).
# Registry'ye guven yonetici tarafindan kurulur: lab CA'si certs.d altina kopyalanir.
# Soket ortak volume'dadir ve 990 numarali gruba aciktir; TLS'siz TCP portu acilmaz.
set -eu

hedef="/etc/docker/certs.d/gitlab.${LAB_DOMAIN}:5050"
mkdir -p "$hedef"
cp /lab/certs/ca.crt "$hedef/ca.crt"

exec dockerd-entrypoint.sh dockerd \
  --host=unix:///run/agent-docker/docker.sock \
  --group=990 \
  --dns="${LAB_DNS}"
