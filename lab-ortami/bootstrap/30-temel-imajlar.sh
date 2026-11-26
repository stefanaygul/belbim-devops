#!/usr/bin/env bash
# Temel imajlari ic aynaya (egitim/base) alir. Host'ta calisir (bash 3.2 uyumlu).
#
# Kapali ag benzetimi: Dockerfile'lardaki ARG MCR ve ARG HUB bu ic adresle beslenir.
# SDK ve Node imajlarina lab CA'si eklenir. Imaj host'un Docker'inda derlenir, dosyaya
# kaydedilir ve araclar container'indan skopeo ile registry'ye gonderilir; host'un
# Docker daemon'i lab registry'sine baglanmaz.
#
# Imajlar yalnizca host'un mimarisi icin gonderilir.
set -euo pipefail
cd "$(dirname "$0")/.."

ARACLAR="docker compose run --rm -T araclar"
CALISMA=".cache/base"
mkdir -p "$CALISMA/ctx"
cp certs/ca.crt "$CALISMA/ctx/ca.crt"

printf '\n\033[1m==> Temel imajlar (egitim/base)\033[0m\n'
parmak="$($ARACLAR bash -c 'openssl x509 -in certs/ca.crt -noout -fingerprint -sha256 | cut -d= -f2' < /dev/null)"

# Tablo: bootstrap/temel-imajlar.tablo
while IFS='|' read -r hedef kaynak dosya <&3; do
  [ -n "$hedef" ] || continue
  if $ARACLAR bash bootstrap/30-imaj.sh denetle "$hedef" "$kaynak" "$parmak" < /dev/null; then
    printf '    \033[32mtamam\033[0m  %s (guncel: %s)\n' "$hedef" "$kaynak"
    continue
  fi
  ad="$(printf '%s' "$hedef" | tr '/:' '--')"
  printf '    %s <- %s\n' "$hedef" "$kaynak"
  docker build --quiet \
    -f "images/base/$dosya" \
    --build-arg "KAYNAK=$kaynak" --build-arg "CA_PARMAK_IZI=$parmak" \
    -t "belbim-lab/base:$ad" "$CALISMA/ctx" > /dev/null
  docker save -o "$CALISMA/$ad.tar" "belbim-lab/base:$ad"
  $ARACLAR bash bootstrap/30-imaj.sh it "$ad.tar" "$hedef" < /dev/null
  rm -f "$CALISMA/$ad.tar"
  printf '    \033[32mtamam\033[0m  %s (gonderildi)\n' "$hedef"
done 3< <(grep -v '^#' bootstrap/temel-imajlar.tablo)

rm -rf "$CALISMA/ctx"
