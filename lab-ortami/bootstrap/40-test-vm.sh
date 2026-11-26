#!/usr/bin/env bash
# test VM: ekip dizinleri ve deploy kullanicisina ekip SSH anahtarlari.
# Host'ta calisir (bash 3.2 uyumlu); tekrar calistirmak guvenlidir.
# deploy kullanicisi imajda tanimlidir; ev dizini ve /opt/saha kalici volume'dadir.
#
# Katilimciya birakilanlar burada YAPILMAZ: docker login, compose dosyasi, uygulama.
set -euo pipefail
cd "$(dirname "$0")/.."
source bootstrap/host-lib.sh

adim "test-vm"
for nn in $(ekipler); do
  kullanici="ekip${nn}"
  docker compose exec -T test-vm install -d -o deploy -g deploy -m 0755 "/opt/saha/${kullanici}"

  acik="$(docker compose exec -T -u "$kullanici" workstation cat "/home/${kullanici}/.ssh/id_ed25519.pub" 2>/dev/null || true)"
  if [ -z "$acik" ]; then
    echo "    uyari  $kullanici icin SSH anahtari yok; once workstation adimini calistirin" >&2
    continue
  fi
  printf '%s\n' "$acik" | docker compose exec -T -u deploy test-vm bash -c '
    anahtar="$(cat)"
    grep -qxF "$anahtar" ~/.ssh/authorized_keys || printf "%s\n" "$anahtar" >> ~/.ssh/authorized_keys
  '
  tamam "/opt/saha/${kullanici}, ${kullanici} anahtari deploy kullanicisinda yetkili"
done
