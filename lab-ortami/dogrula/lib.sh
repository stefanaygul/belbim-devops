#!/usr/bin/env bash
# Dogrulama betiklerinin ortak islevleri (bash 3.2 ve 5 uyumlu).

GECEN=0
KALAN=0

baslik() { printf '\n\033[1m%s\033[0m\n' "$*"; }
gecti()  { GECEN=$((GECEN + 1)); printf '  \033[32mGECTI\033[0m  %s\n' "$*"; }
kaldi()  { KALAN=$((KALAN + 1)); printf '  \033[31mKALDI\033[0m  %s\n' "$*"; }

# esit <aciklama> <beklenen> <gelen>
esit() {
  if [ "$2" = "$3" ]; then
    gecti "$1: $3"
  else
    kaldi "$1: beklenen '$2', gelen '$3'"
  fi
}

# icerir <aciklama> <aranan> <metin>
icerir() {
  case "$3" in
    *"$2"*) gecti "$1" ;;
    *) kaldi "$1: '$2' bulunamadi. Gelen: $(printf '%s' "$3" | tail -n 3 | cut -c1-300)" ;;
  esac
}

ozet() {
  printf '\n%s gecti, %s kaldi\n' "$GECEN" "$KALAN"
  [ "$KALAN" -eq 0 ]
}
