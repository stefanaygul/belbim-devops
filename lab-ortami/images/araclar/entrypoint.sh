#!/bin/bash
set -euo pipefail

# Lab CA'si varsa guven deposuna ekle: betikler TLS dogrulamasini kapatmaz.
if [ -f /lab/ortam/certs/ca.crt ]; then
  install -D -m 0644 /lab/ortam/certs/ca.crt /usr/local/share/ca-certificates/kurum-ca.crt
  update-ca-certificates >/dev/null 2>&1
fi

exec "$@"
