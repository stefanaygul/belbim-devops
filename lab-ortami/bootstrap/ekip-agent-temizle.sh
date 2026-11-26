#!/usr/bin/env bash
# Jenkins agent'ta bir ekipten kalanlari siler: job'in calisma dizinleri ve agent'in
# Docker daemon'indaki ekip imajlari. Host'ta calisir (bash 3.2 uyumlu).
# YALNIZCA adi saha-portal-ekipNN iceren calisma dizinlerine ve deposu
# .../ekip-NN/saha-ekipman-portal/ olan imajlara dokunur.
# Kullanim: ekip-agent-temizle.sh <NN>
set -euo pipefail
cd "$(dirname "$0")/.."
source bootstrap/host-lib.sh

nn="$(printf '%02d' "$((10#${1:?kullanim: ekip-agent-temizle.sh <NN>}))")"
adim "Jenkins agent (ekip-${nn})"
if ! docker compose ps --status running --services 2>/dev/null | grep -qx jenkins-agent; then
  echo "    agent calismiyor: dokunulmadi"
  exit 0
fi
docker compose exec -T jenkins-agent env "NN=$nn" sh -s <<'AGENT'
set -u
ws=/home/jenkins/agent/workspace
sayi=0
for d in "$ws"/*"saha-portal-ekip${NN}_"*; do
  [ -e "$d" ] || continue
  rm -rf "$d"
  sayi=$((sayi + 1))
done
imajlar="$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep "/ekip-${NN}/saha-ekipman-portal/" || true)"
isayi=0
if [ -n "$imajlar" ]; then
  isayi="$(printf '%s\n' "$imajlar" | wc -l | tr -d ' ')"
  printf '%s\n' "$imajlar" | xargs docker rmi -f >/dev/null 2>&1 || true
fi
printf '    \033[32mtamam\033[0m  %s calisma dizini ve %s imaj etiketi silindi\n' "$sayi" "$isayi"
AGENT
