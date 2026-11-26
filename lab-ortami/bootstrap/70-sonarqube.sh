#!/usr/bin/env bash
# SonarQube: yonetici parolasi, sunucu adresi, Jenkins webhook'u, ekip kullanicilari.
# araclar container'inda calisir; tekrar calistirmak guvenlidir.
#
# Katilimciya birakilanlar burada YAPILMAZ: SonarQube projesi ve analiz token'i.
set -euo pipefail
source "$(dirname "$0")/lib.sh"
: "${SONAR_ADMIN_PASSWORD:?SONAR_ADMIN_PASSWORD tanimli degil}"

# sq METOD /api/yol [curl secenekleri]
sq() {
  [ -n "${_SQ_CFG:-}" ] || _SQ_CFG="$(_curl_cfg sq "user = \"admin:${SONAR_ADMIN_PASSWORD}\"")"
  local metod="$1" yol="$2"
  shift 2
  _istek "$_SQ_CFG" "$metod" "${SONAR_URL}${yol}" "$@"
}

adim "SonarQube"
# Ilk kurulumda parola admin/admin'dir; .env'deki degerle degistirilir.
if ! sq GET /api/authentication/validate || [ "$(jq -r '.valid' <<<"$HTTP_BODY")" != "true" ]; then
  ilk="$(_curl_cfg sq-ilk 'user = "admin:admin"')"
  _istek "$ilk" POST "${SONAR_URL}/api/users/change_password" \
    --data-urlencode "login=admin" --data-urlencode "previousPassword=admin" \
    --data-urlencode "password@-" < <(printf '%s' "$SONAR_ADMIN_PASSWORD") \
    || olum "yonetici parolasi degistirilemedi (HTTP $HTTP_CODE): $(head -c 300 <<<"$HTTP_BODY")"
  tamam "yonetici parolasi .env'deki degerle degistirildi"
else
  tamam "yonetici parolasi gecerli"
fi
zorunlu "surum" sq GET /api/system/status
bilgi "surum: $(jq -r '.version' <<<"$HTTP_BODY") ($(jq -r '.status' <<<"$HTTP_BODY"))"

zorunlu "sunucu adresi" sq POST /api/settings/set \
  --data-urlencode "key=sonar.core.serverBaseURL" --data-urlencode "value=${SONAR_URL}"
tamam "sunucu adresi: ${SONAR_URL}"

# SonarQube, yerel ag adreslerine giden webhook'lari varsayilan olarak reddeder
# ("Invalid URL: loopback ... site-local ..."). Kurum ici (on-prem) Jenkins yerel agdadir;
# dogrulama kapatilir. Bu TLS ile ilgili degildir: sertifika dogrulamasi acik kalir.
zorunlu "yerel webhook izni" sq POST /api/settings/set \
  --data-urlencode "key=sonar.validateWebhooks" --data-urlencode "value=false"
tamam "yerel aga webhook izni (sonar.validateWebhooks=false)"

# Quality Gate sonucunu Jenkins'e bildiren global webhook. Sondaki / zorunludur.
WEBHOOK_URL="${JENKINS_URL}/sonarqube-webhook/"
zorunlu "webhook listesi" sq GET /api/webhooks/list
mevcut="$(jq -r --arg n jenkins '.webhooks[] | select(.name == $n) | "\(.key) \(.url)"' <<<"$HTTP_BODY")"
if [ -z "$mevcut" ]; then
  zorunlu "webhook" sq POST /api/webhooks/create \
    --data-urlencode "name=jenkins" --data-urlencode "url=${WEBHOOK_URL}"
  tamam "webhook jenkins -> ${WEBHOOK_URL} (olusturuldu)"
elif [ "${mevcut#* }" != "$WEBHOOK_URL" ]; then
  zorunlu "webhook guncelleme" sq POST /api/webhooks/update \
    --data-urlencode "webhook=${mevcut%% *}" --data-urlencode "name=jenkins" --data-urlencode "url=${WEBHOOK_URL}"
  tamam "webhook jenkins -> ${WEBHOOK_URL} (guncellendi)"
else
  tamam "webhook jenkins -> ${WEBHOOK_URL} (var)"
fi

# Ekip kullanicilari: proje olusturabilir, kendi projelerinde analiz yapabilir.
for nn in $(ekipler); do
  kullanici="ekip${nn}"
  zorunlu "kullanici sorgusu" sq GET "/api/users/search?q=${kullanici}"
  if jq -e --arg u "$kullanici" 'any(.users[]; .login == $u)' <<<"$HTTP_BODY" >/dev/null; then
    tamam "kullanici $kullanici (var)"
  else
    zorunlu "kullanici $kullanici" sq POST /api/users/create \
      --data-urlencode "login=${kullanici}" --data-urlencode "name=Ekip ${nn}" \
      --data-urlencode "password@-" < <(printf '%s' "$(sonar_parola "$nn")")
    tamam "kullanici $kullanici (olusturuldu)"
  fi
  for yetki in provisioning scan; do
    zorunlu "yetki $yetki" sq POST /api/permissions/add_user \
      --data-urlencode "login=${kullanici}" --data-urlencode "permission=${yetki}"
  done
done
tamam "ekip kullanicilari proje olusturabilir ve analiz gonderebilir"

zorunlu "Quality Gate listesi" sq GET /api/qualitygates/list
bilgi "varsayilan Quality Gate: $(jq -r '.qualitygates[] | select(.isDefault) | .name' <<<"$HTTP_BODY")"
