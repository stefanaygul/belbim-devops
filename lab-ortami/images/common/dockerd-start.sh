#!/bin/bash
# Container icinde Docker daemon'i baslatir ve hazir olana kadar bekler.
# Kullanim: lab-dockerd-start [dockerd secenekleri...]
# Ortam: LAB_DNS (ic container'larin kullanacagi DNS sunucusu)
set -euo pipefail

# Ubuntu'nun iptables'i nftables arka ucunu kullanir; cekirdek desteklemiyorsa eski arka uca gec.
if ! iptables -nL >/dev/null 2>&1; then
  update-alternatives --set iptables /usr/sbin/iptables-legacy >/dev/null
  update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy >/dev/null
fi

mkdir -p /etc/docker
if [ -n "${LAB_DNS:-}" ]; then
  printf '{\n  "dns": ["%s"]\n}\n' "$LAB_DNS" > /etc/docker/daemon.json
fi

# Onceki calismadan kalan pid dosyalari daemon'in acilmasini engeller.
rm -f /var/run/docker.pid /var/run/docker/containerd/containerd.pid

dind dockerd --host unix:///var/run/docker.sock "$@" >> /var/log/dockerd.log 2>&1 &

for _ in $(seq 1 60); do
  if docker info >/dev/null 2>&1; then
    exit 0
  fi
  sleep 1
done
echo "dockerd 60 saniyede hazir olmadi; /var/log/dockerd.log dosyasina bakin" >&2
tail -n 30 /var/log/dockerd.log >&2 || true
exit 1
