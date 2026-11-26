#!/usr/bin/env bash
# Nexus: lisans onayi denetimi, anonim okuma, realm'ler, depolar, rol ve ekip kullanicilari.
# araclar container'inda calisir; yalnizca REST API kullanir; tekrar calistirmak guvenlidir.
#
# Katilimciya birakilanlar burada YAPILMAZ: NuGet API anahtari alma, paket yayinlama.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

json() { printf '%s' "$1"; }

# `eula-denetle` kipi: EULA kabul edilmemisse 1 doner (bootstrap sonunda kullanilir).
if [ "${1:-}" = "eula-denetle" ]; then
  zorunlu "EULA durumu" nx GET /v1/system/eula
  [ "$(jq -r '.accepted' <<<"$HTTP_BODY")" = "true" ]
  exit $?
fi

# --- Community Edition lisans onayi ve telemetri bildirimi ------------------
# Bu iki onay kullaniciya aittir; betik yalnizca .env'de acikca istenmisse isaretler.
adim "Nexus Community Edition onaylari"
zorunlu "EULA durumu" nx GET /v1/system/eula
if [ "$(jq -r '.accepted' <<<"$HTTP_BODY")" = "true" ]; then
  tamam "EULA daha once kabul edilmis"
elif [ "${NEXUS_CE_EULA_KABUL:-}" = "evet" ]; then
  govde="$(jq -c '.accepted = true' <<<"$HTTP_BODY")"
  zorunlu "EULA kabulu" nx POST /v1/system/eula -H "Content-Type: application/json" --data-binary "$govde"
  tamam "EULA kabul edildi (.env: NEXUS_CE_EULA_KABUL=evet)"
else
  uyari "EULA kabul edilmemis. Metin: https://links.sonatype.com/products/nxrm/ce-eula"
  uyari "Kabul ediyorsaniz .env dosyasina NEXUS_CE_EULA_KABUL=evet yazip yeniden calistirin."
fi

if nx GET /v1/system/mandatory-telemetry-acknowledgement; then
  if [ "$(jq -r '.acknowledgement' <<<"$HTTP_BODY")" = "true" ]; then
    tamam "telemetri bildirimi daha once onaylanmis"
  elif [ "${NEXUS_CE_TELEMETRI_ONAY:-}" = "evet" ]; then
    zorunlu "telemetri onayi" nx POST /v1/system/mandatory-telemetry-acknowledgement \
      -H "Content-Type: application/json" --data-binary '{"acknowledgement":true}'
    tamam "telemetri bildirimi onaylandi (.env: NEXUS_CE_TELEMETRI_ONAY=evet)"
  else
    uyari "Community Edition kullanim verisini Sonatype'a gonderir; bildirim onaylanmamis."
    uyari "Onayliyorsaniz .env dosyasina NEXUS_CE_TELEMETRI_ONAY=evet yazip yeniden calistirin."
  fi
fi

# --- Guvenlik ---------------------------------------------------------------
adim "Nexus guvenlik ayarlari"
# Okuma anonimdir: repodaki NuGet.config ve .npmrc kimlik bilgisi tasimaz.
zorunlu "anonim erisim" nx PUT /v1/security/anonymous -H "Content-Type: application/json" \
  --data-binary '{"enabled":true,"userId":"anonymous","realmName":"NexusAuthorizingRealm"}'
tamam "anonim okuma acik"

# NuGet API-Key Realm (dotnet nuget push) ve npm Bearer Token Realm (npm publish)
zorunlu "etkin realm'ler" nx GET /v1/security/realms/active
realmler="$(jq -c '. + ["NuGetApiKey","NpmToken"] | unique' <<<"$HTTP_BODY")"
# Yerel kimlik dogrulama her zaman ilk sirada kalir.
realmler="$(jq -c '["NexusAuthenticatingRealm"] + (. - ["NexusAuthenticatingRealm"])' <<<"$realmler")"
zorunlu "realm'ler" nx PUT /v1/security/realms/active -H "Content-Type: application/json" --data-binary "$realmler"
tamam "realm'ler: $realmler"

# --- Depolar ----------------------------------------------------------------
# depo_kur <format> <tur> <ad> <json-govde>
depo_kur() {
  local format="$1" tur="$2" ad="$3" govde="$4"
  if nx GET "/v1/repositories/$format/$tur/$ad"; then
    zorunlu "depo guncelleme $ad" nx PUT "/v1/repositories/$format/$tur/$ad" \
      -H "Content-Type: application/json" --data-binary "$govde"
    tamam "depo $ad (var, ayarlar esitlendi)"
  else
    [ "$HTTP_CODE" = "404" ] || olum "depo sorgusu $ad: HTTP $HTTP_CODE $HTTP_BODY"
    zorunlu "depo olusturma $ad" nx POST "/v1/repositories/$format/$tur" \
      -H "Content-Type: application/json" --data-binary "$govde"
    tamam "depo $ad (olusturuldu)"
  fi
}

proxy_govde() {  # <ad> <uzak-adres> [ek-json]
  local ek="${3:-}"
  [ -n "$ek" ] || ek='{}'
  jq -cn --arg ad "$1" --arg url "$2" --argjson ek "$ek" '{
    name: $ad, online: true,
    storage: { blobStoreName: "default", strictContentTypeValidation: true },
    proxy: { remoteUrl: $url, contentMaxAge: 1440, metadataMaxAge: 1440 },
    negativeCache: { enabled: true, timeToLive: 5 },
    httpClient: { blocked: false, autoBlock: true }
  } + $ek'
}
hosted_govde() {  # <ad>   (ALLOW_ONCE = "Disable redeploy")
  jq -cn --arg ad "$1" '{
    name: $ad, online: true,
    storage: { blobStoreName: "default", strictContentTypeValidation: true, writePolicy: "ALLOW_ONCE" }
  }'
}
group_govde() {  # <ad> <uye>...
  local ad="$1"
  shift
  jq -cn --arg ad "$ad" '{
    name: $ad, online: true,
    storage: { blobStoreName: "default", strictContentTypeValidation: true },
    group: { memberNames: $ARGS.positional }
  }' --args "$@"
}

adim "Nexus depolari"
depo_kur nuget proxy  nuget.org-proxy "$(proxy_govde nuget.org-proxy https://api.nuget.org/v3/index.json \
  '{"nugetProxy":{"queryCacheItemMaxAge":3600,"nugetVersion":"V3"}}')"
depo_kur nuget hosted nuget-hosted    "$(hosted_govde nuget-hosted)"
# Group'ta hosted once gelir: kurum paketleri ic depodan cozulur.
depo_kur nuget group  nuget-group     "$(group_govde nuget-group nuget-hosted nuget.org-proxy)"

depo_kur npm proxy  npm-proxy  "$(proxy_govde npm-proxy https://registry.npmjs.org)"
depo_kur npm hosted npm-hosted "$(hosted_govde npm-hosted)"
depo_kur npm group  npm-group  "$(group_govde npm-group npm-hosted npm-proxy)"

for ad in nuget-hosted npm-hosted; do
  format="${ad%%-*}"
  zorunlu "depo okuma $ad" nx GET "/v1/repositories/$format/hosted/$ad"
  [ "$(jq -r '.storage.writePolicy' <<<"$HTTP_BODY")" = "ALLOW_ONCE" ] || olum "$ad: redeploy kapali degil"
done
tamam "hosted depolarda redeploy kapali (ALLOW_ONCE)"

# --- Rol ve ekip kullanicilari ----------------------------------------------
adim "Nexus rol ve kullanicilari"
rol='{
  "id": "lab-yayinci",
  "name": "lab-yayinci",
  "description": "Egitim ekipleri: hosted depolara paket yayinlar, kendi API anahtarini alir",
  "privileges": [
    "nx-repository-view-nuget-nuget-hosted-*",
    "nx-repository-view-npm-npm-hosted-*",
    "nx-apikey-all",
    "nx-userschangepw"
  ],
  "roles": ["nx-anonymous"]
}'
if nx GET /v1/security/roles/lab-yayinci; then
  zorunlu "rol guncelleme" nx PUT /v1/security/roles/lab-yayinci -H "Content-Type: application/json" --data-binary "$rol"
  tamam "rol lab-yayinci (var, ayarlar esitlendi)"
else
  zorunlu "rol olusturma" nx POST /v1/security/roles -H "Content-Type: application/json" --data-binary "$rol"
  tamam "rol lab-yayinci (olusturuldu)"
fi

for nn in $(ekipler); do
  kullanici="ekip${nn}"
  zorunlu "kullanici sorgusu" nx GET "/v1/security/users?userId=${kullanici}"
  if [ "$(jq --arg u "$kullanici" '[.[] | select(.userId == $u)] | length' <<<"$HTTP_BODY")" != "0" ]; then
    tamam "kullanici $kullanici (var)"
    continue
  fi
  govde="$(jq -cn --arg u "$kullanici" --arg nn "$nn" --arg e "${kullanici}@${LAB_DOMAIN}" \
              --arg p "$(ekip_parola "nexus-${kullanici}")" \
              '{userId:$u, firstName:"Ekip", lastName:$nn, emailAddress:$e, password:$p,
                status:"active", roles:["lab-yayinci"]}')"
  zorunlu "kullanici olusturma $kullanici" nx POST /v1/security/users \
    -H "Content-Type: application/json" --data-binary @- < <(json "$govde")
  tamam "kullanici $kullanici (olusturuldu)"
done
