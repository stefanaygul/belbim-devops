#!/bin/bash
set -euo pipefail

# Lab CA'si Chromium'un kullandigi NSS deposuna guvenilir kok olarak eklenir.
# LAB_CA_GUVENME=1 verilirse eklenmez (olumsuz deneme icin).
if [ -f /lab/ortam/certs/ca.crt ] && [ "${LAB_CA_GUVENME:-0}" != "1" ]; then
  mkdir -p "$HOME/.pki/nssdb"
  [ -f "$HOME/.pki/nssdb/cert9.db" ] || certutil -d "sql:$HOME/.pki/nssdb" -N --empty-password
  certutil -d "sql:$HOME/.pki/nssdb" -A -t "C,," -n "Egitim Lab Root CA" -i /lab/ortam/certs/ca.crt
  export NODE_EXTRA_CA_CERTS=/lab/ortam/certs/ca.crt
fi

exec "$@"
