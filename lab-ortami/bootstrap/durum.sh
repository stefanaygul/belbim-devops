#!/usr/bin/env bash
# Servis durumu ve kaynak kullanimi. Host'ta calisir (bash 3.2 uyumlu).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== Servisler"
docker compose --profile cekirdek --profile ci ps --format 'table {{.Service}}\t{{.Status}}\t{{.Ports}}'

echo
echo "== Bellek ve CPU (anlik)"
adlar="$(docker compose --profile cekirdek --profile ci ps -q)"
if [ -n "$adlar" ]; then
  # shellcheck disable=SC2086
  docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.CPUPerc}}' $adlar
fi

echo
echo "== Volume boyutlari"
# jq host'ta sart degil; araclar imajindaki kullanilir.
docker system df -v --format '{{json .Volumes}}' \
  | docker run --rm -i --network none --entrypoint jq belbim-lab/araclar:faz2 \
      -r '.[] | select(.Name | startswith("belbim-lab_")) | "\(.Name)\t\(.Size)"' \
  | sort || true

echo
echo "== Docker'a ayrilan bellek"
docker info --format '{{.MemTotal}}' | awk '{ printf "%.1f GiB\n", $1 / 1024 / 1024 / 1024 }'
