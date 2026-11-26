#!/bin/bash
# Ekip kullanicilarini kurar: ekip01 ... ekipNN (EKIP_SAYISI) ve /home altinda
# dizini bulunan diger ekipler (ornegin prova ekibi ekip99).
# Kullanim: lab-users [NN ...]   (ek ekip numaralari)
set -euo pipefail

ekle() {
  local nn="$1" user="ekip$1" uid=$((2000 + 10#$1))
  if ! id "$user" >/dev/null 2>&1; then
    useradd --uid "$uid" --gid lab --groups docker --shell /bin/bash --no-create-home \
            --home-dir "/home/$user" "$user"
  fi
  if [ ! -d "/home/$user" ]; then
    mkdir -p "/home/$user"
    cp -r /etc/skel/. "/home/$user/"
  fi
  chown -R "$uid:lab" "/home/$user"
}

if [ "$#" -gt 0 ]; then
  for nn in "$@"; do ekle "$nn"; done
  exit 0
fi
for i in $(seq 1 "${EKIP_SAYISI:-0}"); do
  ekle "$(printf '%02d' "$i")"
done
for d in /home/ekip[0-9][0-9]; do
  [ -d "$d" ] && ekle "${d#/home/ekip}"
done
for nn in "$@"; do
  ekle "$nn"
done
