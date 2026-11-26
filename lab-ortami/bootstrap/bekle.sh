#!/usr/bin/env bash
# Servisler istek kabul edene kadar bekler. Host'ta calisir (bash 3.2 uyumlu).
# Kullanim: bekle.sh cekirdek [ci]
set -euo pipefail
cd "$(dirname "$0")/.."

SURE="${BEKLEME_SURESI:-900}"

# araclar container'i icinden HTTP kodu okur: ad cozumleme ve TLS lab'in kendi yoluyla denetlenir.
http_kodu() {
  docker compose run --rm -T --no-deps araclar \
    curl -sS -o /dev/null -w '%{http_code}' --max-time 10 "$1" 2>/dev/null || true
}

bekle_http() {
  local ad="$1" url="$2" beklenen="$3" basla kod
  basla=$(date +%s)
  printf '%-10s bekleniyor ' "$ad"
  while :; do
    kod="$(http_kodu "$url")"
    case " $beklenen " in
      *" $kod "*) printf ' hazir (HTTP %s, %ss)\n' "$kod" "$(( $(date +%s) - basla ))"; return 0 ;;
    esac
    if [ $(( $(date +%s) - basla )) -ge "$SURE" ]; then
      printf ' ZAMAN ASIMI (son HTTP kodu: %s)\n' "${kod:-yok}"
      return 1
    fi
    printf '.'
    sleep 10
  done
}

bekle_exec() {
  local ad="$1" basla
  shift
  basla=$(date +%s)
  printf '%-10s bekleniyor ' "$ad"
  while :; do
    if docker compose exec -T "$@" >/dev/null 2>&1; then
      printf ' hazir (%ss)\n' "$(( $(date +%s) - basla ))"
      return 0
    fi
    if [ $(( $(date +%s) - basla )) -ge "$SURE" ]; then
      printf ' ZAMAN ASIMI\n'
      return 1
    fi
    printf '.'
    sleep 5
  done
}

# .env icinden tek deger okur (dosyayi kabuga yuklemeden)
env_degeri() {
  sed -n "s/^$1=//p" .env | head -n 1
}
D="$(env_degeri LAB_DOMAIN)"

for profil in "$@"; do
  case "$profil" in
    cekirdek)
      bekle_exec workstation workstation docker info
      bekle_exec test-vm test-vm docker info
      bekle_http nexus "https://nexus.${D}/service/rest/v1/status/writable" "200"
      bekle_http gitlab "https://gitlab.${D}/users/sign_in" "200"
      bekle_http registry "https://gitlab.${D}:5050/v2/" "401"
      ;;
    ci)
      bekle_http jenkins "https://jenkins.${D}/login" "200"
      bekle_http sonar "https://sonar.${D}/api/system/status" "200"
      ;;
    *)
      echo "Bilinmeyen profil: $profil" >&2
      exit 2
      ;;
  esac
done
