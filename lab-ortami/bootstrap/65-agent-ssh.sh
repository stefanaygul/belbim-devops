#!/usr/bin/env bash
# Jenkins agent: test VM'in SSH sunucu anahtari (known_hosts). Host'ta calisir (bash 3.2 uyumlu);
# tekrar calistirmak guvenlidir. Yonetici isidir: agent ilk baglantida soru sormaz ve
# sunucu anahtari denetimi acik kalir (StrictHostKeyChecking kapatilmaz).
# Agent container'i yeniden yaratilirsa dosya kaybolur; bootstrap yeniden calistirilir.
#
# Katilimciya birakilanlar burada YAPILMAZ: Jenkins'in deploy anahtari (test-vm-ssh credential'i)
# ve onun test VM'de yetkilendirilmesi (LAB 05-B).
set -euo pipefail
cd "$(dirname "$0")/.."
source bootstrap/host-lib.sh

adim "Jenkins agent: test VM sunucu anahtari"
D="$(env_degeri LAB_DOMAIN)"
docker compose exec -T -e "HEDEF=test-vm.${D}" jenkins-agent sh -c '
  set -e
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  touch ~/.ssh/known_hosts && chmod 600 ~/.ssh/known_hosts
  ssh-keygen -F "$HEDEF" -f ~/.ssh/known_hosts >/dev/null 2>&1 || ssh-keyscan -T 10 -t ed25519 "$HEDEF" 2>/dev/null >> ~/.ssh/known_hosts
  ssh-keygen -F "$HEDEF" -f ~/.ssh/known_hosts >/dev/null
' < /dev/null
tamam "agent known_hosts: test-vm.${D} (ed25519)"
