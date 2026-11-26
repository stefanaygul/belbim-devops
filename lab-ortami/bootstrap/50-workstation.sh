#!/usr/bin/env bash
# workstation: ekip kullanicilari ve test VM icin ekip SSH anahtarlari.
# Host'ta calisir (bash 3.2 uyumlu); tekrar calistirmak guvenlidir.
#
# Katilimciya birakilanlar burada YAPILMAZ: git kimligi, repo klonlama,
# Docker daemon'a CA tanitma, docker login.
set -euo pipefail
cd "$(dirname "$0")/.."
source bootstrap/host-lib.sh

adim "workstation"
# shellcheck disable=SC2046
docker compose exec -T workstation lab-users $(ekipler)

for nn in $(ekipler); do
  kullanici="ekip${nn}"
  docker compose exec -T -u "$kullanici" workstation bash -lc '
    mkdir -p ~/.ssh && chmod 700 ~/.ssh
    [ -f ~/.ssh/id_ed25519 ] || ssh-keygen -q -t ed25519 -N "" -C "$(id -un)@workstation" -f ~/.ssh/id_ed25519
    # Sandbox: ayni Linux kullanicisi iki GitLab hesabiyla calisir (bkz. `rol` komutu).
    [ -f ~/.ssh/id_ed25519_lead ] || ssh-keygen -q -t ed25519 -N "" -C "$(id -un)-lead@workstation" -f ~/.ssh/id_ed25519_lead
    # Sunucu anahtarlari yonetici tarafindan onceden tanitilir (ilk baglantida soru cikmaz).
    touch ~/.ssh/known_hosts && chmod 600 ~/.ssh/known_hosts
    for h in "$GITLAB_HOST" "$TEST_VM"; do
      ssh-keygen -F "$h" -f ~/.ssh/known_hosts >/dev/null 2>&1 || ssh-keyscan -T 10 -t ed25519 "$h" 2>/dev/null >> ~/.ssh/known_hosts
    done
    [ "$(grep -c . ~/.ssh/known_hosts)" -ge 2 ] || { echo "sunucu anahtarlari alinamadi" >&2; exit 1; }
  '
  tamam "kullanici $kullanici: SSH anahtarlari ve bilinen sunucular hazir"
done
