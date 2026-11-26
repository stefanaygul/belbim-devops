#!/bin/bash
set -euo pipefail

# 1. Lab CA'si isletim sisteminin guven deposuna (git, curl, dotnet, npm bunu kullanir).
if [ -f /lab/certs/ca.crt ]; then
  install -D -m 0644 /lab/certs/ca.crt /usr/local/share/ca-certificates/kurum-ca.crt
  install -D -m 0644 /lab/certs/ca.crt /etc/lab/kurum-ca.crt
  update-ca-certificates >/dev/null 2>&1
fi

# 2. Ekip kullanicilari (/home kalici, /etc/passwd degil; her acilista yeniden kurulur).
lab-users

# 3. Docker daemon. SSL_CERT_FILE/SSL_CERT_DIR ile daemon yalnizca genel CA'lari gorur:
#    registry'ye guven /etc/docker/certs.d altina CA konunca olusur (LAB 03-B).
SSL_CERT_FILE=/usr/local/share/lab/public-ca-bundle.crt SSL_CERT_DIR=/nonexistent \
  lab-dockerd-start

echo "workstation hazir"
exec tail -F /var/log/dockerd.log
