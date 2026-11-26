#!/usr/bin/env bash
# Bir ekibin Nexus'taki kaynaklari: NuGet paketi (Saha.Common.Contracts.EkipNN) ve API anahtari.
# araclar container'inda calisir. YALNIZCA verilen ekibin paket kimligine dokunur.
#
#   ekip-nexus.sh sil <NN>       nuget-hosted'daki Saha.Common.Contracts.EkipNN surumlerini siler
#   ekip-nexus.sh anahtar <NN>   ekipNN kullanicisinin NuGet API anahtarini standart ciktiya yazar
#                                (baska hicbir sey yazmaz; checkpoint'in yayin adimi icin)
#   ekip-nexus.sh anahtar-yenile <NN>  anahtari yeniler (eskisi gecersiz olur; sifirlamada ve sizintida)
#
# Neden silme gerekir: hosted depoda redeploy kapalidir (ALLOW_ONCE); ayni surum ikinci kez
# yayinlanamaz. Ekip sifirlanir ya da daha erken bir checkpoint'e donerse LAB 05-A'da 1.0.0'i
# yeniden yayinlayabilmelidir.
#
# API anahtari Nexus'un arayuzunun kullandigi ic uc noktalardan alinir (/service/rest/wonderland,
# /service/rest/internal/nuget-api-key; 3.98.3'te dogrulandi). Bunlar herkese acik REST API'nin
# parcasi degildir; yalnizca sandbox otomasyonu icindir. Katilimci anahtari arayuzden alir.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

mod="${1:?sil|anahtar}"
nn="${2:?ekip numarasi}"
[[ "$nn" =~ ^[0-9][0-9]$ ]] || olum "ekip numarasi iki haneli olmali: $nn"
PAKET="Saha.Common.Contracts.Ekip${nn}"

case "$mod" in
sil)
  adim "Nexus: ekip-$nn paketi"
  zorunlu "paket aramasi" nx GET "/v1/search?repository=nuget-hosted&name=$(urlenc "$PAKET")"
  silinen=""
  for k in $(jq -r --arg p "$PAKET" '.items[] | select(.name == $p) | "\(.id)|\(.version)"' <<<"$HTTP_BODY"); do
    zorunlu "paket silme ${k#*|}" nx DELETE "/v1/components/${k%%|*}"
    silinen="$silinen ${k#*|}"
  done
  if [ -n "$silinen" ]; then tamam "nuget-hosted: $PAKET silindi (surum:$silinen)"; else tamam "nuget-hosted: $PAKET yok"; fi
  ;;
anahtar|anahtar-yenile)
  kullanici="ekip${nn}"
  sifre="$(ekip_parola "nexus-${kullanici}")"
  cfg="$(_curl_cfg nxe "user = \"${kullanici}:${sifre}\"")"
  bilet="$(curl -sS -K "$cfg" -X POST "${NEXUS_URL}/service/rest/wonderland/authenticate" \
    -H 'Content-Type: application/json' -H 'Accept: application/json' \
    --data-binary @- < <(jq -n --arg u "$(printf %s "$kullanici" | base64)" --arg p "$(printf %s "$sifre" | base64)" '{u:$u,p:$p}') \
    | jq -r '.t // empty')"
  [ -n "$bilet" ] || olum "Nexus kimlik dogrulama bileti alinamadi ($kullanici)"
  if [ "$mod" = "anahtar-yenile" ]; then
    # Arayuzdeki "Reset API Key": eski anahtar gecersiz olur.
    kod="$(curl -sS -K "$cfg" -o /dev/null -w '%{http_code}' -X DELETE -H 'Accept: application/json' \
      "${NEXUS_URL}/service/rest/internal/nuget-api-key?authToken=$(printf %s "$bilet" | base64 | tr -d '\n')")"
    [[ "$kod" =~ ^2 ]] || olum "NuGet API anahtari yenilenemedi ($kullanici): HTTP $kod"
    tamam "Nexus: $kullanici NuGet API anahtari yenilendi (eskisi gecersiz)"
    exit 0
  fi
  anahtar="$(curl -sS -K "$cfg" -H 'Accept: application/json' \
    "${NEXUS_URL}/service/rest/internal/nuget-api-key?authToken=$(printf %s "$bilet" | base64 | tr -d '\n')" | jq -r '.apiKey // empty')"
  [[ "$anahtar" =~ ^[0-9a-f-]{36}$ ]] || olum "NuGet API anahtari alinamadi ($kullanici)"
  printf '%s\n' "$anahtar"
  ;;
*) olum "kullanim: ekip-nexus.sh sil|anahtar|anahtar-yenile <NN>" ;;
esac
