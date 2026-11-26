#!/usr/bin/env bash
# Dogrulama betikleri icin ekipNN-lead adina kisa omurlu, salt okunur (read_api) token.
# araclar container'inda calisir. Yalnizca ilgili kullanicinin `lab-dogrula` adli
# token'larina dokunur.
#   ekip-token.sh olustur <NN>   token degerini standart ciktiya yazar (baska hicbir sey yazmaz)
#   ekip-token.sh iptal <NN>
set -euo pipefail
source "$(dirname "$0")/lib.sh"

mod="${1:?olustur|iptal}"
nn="${2:?ekip numarasi}"
kullanici="ekip${nn}-lead"

zorunlu "kullanici sorgusu" gl GET "/users?username=$(urlenc "$kullanici")"
kimlik="$(jq -r '.[0].id // empty' <<<"$HTTP_BODY")"
[ -n "$kimlik" ] || olum "kullanici yok: $kullanici"

iptal() {
  zorunlu "token listesi" gl GET "/users/$kimlik/impersonation_tokens?state=active&per_page=100"
  local t
  for t in $(jq -r '.[] | select(.name == "lab-dogrula") | .id' <<<"$HTTP_BODY"); do
    gl DELETE "/users/$kimlik/impersonation_tokens/$t" || true
  done
}

case "$mod" in
  olustur)
    iptal
    zorunlu "token olusturma" gl POST "/users/$kimlik/impersonation_tokens" \
      --data-urlencode "name=lab-dogrula" --data-urlencode "scopes[]=read_api" \
      --data-urlencode "expires_at=$(date -u -d '+2 days' +%F)"
    jq -r '.token' <<<"$HTTP_BODY"
    ;;
  iptal) iptal ;;
  *) olum "kullanim: ekip-token.sh olustur|iptal <NN>" ;;
esac
