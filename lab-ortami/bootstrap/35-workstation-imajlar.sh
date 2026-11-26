#!/usr/bin/env bash
# Temel imajlari workstation'in Docker daemon'ina onceden yukler. Host'ta calisir
# (bash 3.2 uyumlu); tekrar calistirmak guvenlidir.
#
# Neden: LAB 03-A temel imajlari ic aynadan kullanir; Docker daemon'ina kurum CA'si ise
# LAB 03-B'de tanitilir. Imajlar makinede hazirsa `docker build` registry'ye baglanmaz.
#
# Nasil: imaj registry'den (tek dogru kaynak) skopeo ile docker-archive olarak alinir ve
# `docker load` ile yuklenir. Daemon'in registry'ye guvenmesi gerekmez; daemon ayarina
# dokunulmaz. Yuklu imajin katmanlari registry'dekiyle ayniysa yeniden yuklenmez.
#
# Kullanim:
#   35-workstation-imajlar.sh              yukle (varsayilan)
#   35-workstation-imajlar.sh denetle      yalnizca karsilastir; fark varsa 1 doner
#   35-workstation-imajlar.sh paket <dir>  imajlari <dir> altina .tar olarak yazar
#                                          (baska makinelere `docker load -i` ile tasimak icin)
set -euo pipefail
cd "$(dirname "$0")/.."

ARACLAR="docker compose run --rm -T araclar"
WS="docker compose exec -T workstation"
CALISMA=".cache/base"
mod="${1:-yukle}"
mkdir -p "$CALISMA"

case "$mod" in
  yukle|denetle) printf '\n\033[1m==> Temel imajlar: workstation Docker daemon'"'"'i\033[0m\n' ;;
  paket)
    hedef_dizin="${2:?kullanim: 35-workstation-imajlar.sh paket <dizin>}"
    mkdir -p "$hedef_dizin"
    printf '\n\033[1m==> Temel imaj paketi: %s\033[0m\n' "$hedef_dizin"
    ;;
  *) echo "kullanim: 35-workstation-imajlar.sh [yukle|denetle|paket <dizin>]" >&2; exit 2 ;;
esac

yerel_katmanlar() {  # yerel_katmanlar <tam-ad> -> katmanlar ya da bos
  $WS docker image inspect --format '{{join .RootFS.Layers ","}}' "$1" 2>/dev/null < /dev/null || true
}

fark=0
while IFS='|' read -r hedef kaynak dosya <&3; do
  [ -n "$hedef" ] || continue
  # shellcheck disable=SC2034
  read -r tam digest katmanlar etiket < <($ARACLAR bash bootstrap/30-imaj.sh kimlik "$hedef" < /dev/null)
  [ -n "${katmanlar:-}" ] || { echo "HATA   $hedef registry'de yok; once 'imajlar' adimini calistirin" >&2; exit 1; }
  dosya_adi="$(printf '%s' "$hedef" | tr '/:' '--').tar"

  if [ "$mod" = "paket" ]; then
    $ARACLAR bash bootstrap/30-imaj.sh arsivle "$hedef" "$dosya_adi" < /dev/null
    mv "$CALISMA/$dosya_adi" "$hedef_dizin/$dosya_adi"
    printf '    \033[32mtamam\033[0m  %s  (%s, kaynak %s)\n' "$dosya_adi" "$tam" "$etiket"
    continue
  fi

  if [ "$(yerel_katmanlar "$tam")" = "$katmanlar" ]; then
    printf '    \033[32mtamam\033[0m  %s (yuklu, guncel)\n' "$tam"
    printf '           kaynak %s  registry %s\n' "$etiket" "$digest"
    continue
  fi
  if [ "$mod" = "denetle" ]; then
    printf '    \033[31meksik\033[0m  %s (yuklu degil ya da registry ile ayni degil)\n' "$tam"
    fark=1
    continue
  fi

  $ARACLAR bash bootstrap/30-imaj.sh arsivle "$hedef" "$dosya_adi" < /dev/null
  $WS docker load --quiet < "$CALISMA/$dosya_adi" > /dev/null
  rm -f "$CALISMA/$dosya_adi"
  if [ "$(yerel_katmanlar "$tam")" != "$katmanlar" ]; then
    echo "HATA   $tam yuklendi ama katmanlari registry ile ayni degil" >&2
    exit 1
  fi
  printf '    \033[32mtamam\033[0m  %s (yuklendi)\n' "$tam"
  printf '           kaynak %s  registry %s\n' "$etiket" "$digest"
done 3< <(grep -v '^#' bootstrap/temel-imajlar.tablo)

if [ "$mod" = "paket" ]; then
  ( cd "$hedef_dizin" && shasum -a 256 ./*.tar > SHA256SUMS 2>/dev/null || sha256sum ./*.tar > SHA256SUMS )
  printf '    Yukleme (her katilimci makinesinde): for f in *.tar; do docker load -i "$f"; done\n'
fi
exit "$fark"
