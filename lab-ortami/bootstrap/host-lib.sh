#!/usr/bin/env bash
# Host'ta calisan betiklerin ortak islevleri (bash 3.2 uyumlu). Sir okumaz.

adim()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
tamam() { printf '    \033[32mtamam\033[0m  %s\n' "$*"; }

# .env icinden tek deger okur (dosyayi kabuga yuklemeden)
env_degeri() {
  sed -n "s/^$1=//p" .env | head -n 1
}

# Ekip numaralari: 01..EKIP_SAYISI ve EK_EKIPLER (ortam degiskeni ya da .env)
ekipler() {
  local i sayi ek
  sayi="${EKIP_SAYISI:-$(env_degeri EKIP_SAYISI)}"
  ek="${EK_EKIPLER:-$(env_degeri EK_EKIPLER)}"
  for ((i=1; i<=${sayi:-0}; i++)); do printf '%02d\n' "$i"; done
  for i in $ek; do printf '%02d\n' "$((10#$i))"; done
}
