#!/usr/bin/env bash
# Bootstrap ve dogrulama betiklerinin ortak islevleri. araclar container'inda
# (bash 5) `source` edilir. Sirlar komut satirina ve ciktiya yazilmaz.

: "${LAB_DOMAIN:?LAB_DOMAIN tanimli degil}"

GITLAB_URL="https://gitlab.${LAB_DOMAIN}"
REGISTRY="gitlab.${LAB_DOMAIN}:5050"
NEXUS_URL="https://nexus.${LAB_DOMAIN}"
JENKINS_URL="https://jenkins.${LAB_DOMAIN}"
SONAR_URL="https://sonar.${LAB_DOMAIN}"
TEST_VM="test-vm.${LAB_DOMAIN}"
GITLAB_GROUP="egitim"

adim()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
bilgi() { printf '    %s\n' "$*"; }
tamam() { printf '    \033[32mtamam\033[0m  %s\n' "$*"; }
uyari() { printf '    \033[33muyari\033[0m  %s\n' "$*" >&2; }
olum()  { printf '\033[31mHATA\033[0m   %s\n' "$*" >&2; exit 1; }

# Ekip numaralari: 01..EKIP_SAYISI ve EK_EKIPLER icindekiler (ornegin "99").
ekipler() {
  local i
  for i in $(seq 1 "${EKIP_SAYISI:-0}"); do printf '%02d\n' "$i"; done
  for i in ${EK_EKIPLER:-}; do printf '%02d\n' "$((10#$i))"; done
}

# ekip-01 -> 8081 ... ekip-10 -> 8090; prova ekibi ekip-99 -> 8099
ekip_portu() {
  if [ "$1" = "99" ]; then echo 8099; else echo $((8080 + 10#$1)); fi
}

# Hesap parolalari LAB_SECRET'ten turetilir: saklanmaz, her calistirmada ayni cikar.
# Kullanim: ekip_parola ekip01-lead
ekip_parola() {
  : "${LAB_SECRET:?LAB_SECRET tanimli degil}"
  printf '%s' "$1" | openssl dgst -sha256 -hmac "$LAB_SECRET" -binary | base64 | tr -d '/+=' | cut -c1-16
}

# SonarQube parola kurali ozel karakter, rakam, buyuk ve kucuk harf ister.
sonar_parola() { printf '%s#Sq7' "$(ekip_parola "sonar-ekip$1")"; }

urlenc() { jq -rn --arg v "$1" '$v|@uri'; }

# --- HTTP ---------------------------------------------------------------
# Kimlik bilgileri curl yapilandirma dosyalarinda durur (container'a ozel /tmp).
_CURL_DIR="$(mktemp -d)"
trap 'rm -rf "$_CURL_DIR"' EXIT

_curl_cfg() {  # _curl_cfg <ad> <satir>
  local f="$_CURL_DIR/$1"
  ( umask 077; printf '%s\n' "$2" > "$f" )
  printf '%s' "$f"
}

HTTP_CODE=""
HTTP_BODY=""
# _istek <cfg-dosyasi> <METOD> <URL> [curl secenekleri...]
# HTTP_CODE ve HTTP_BODY degiskenlerini doldurur; 2xx ise 0 doner.
_istek() {
  local cfg="$1" metod="$2" url="$3" govde
  shift 3
  govde="$(mktemp -p "$_CURL_DIR")"
  HTTP_CODE="$(curl -sS -K "$cfg" -X "$metod" -o "$govde" -w '%{http_code}' --max-time 120 "$@" "$url")" || HTTP_CODE="000"
  HTTP_BODY="$(cat "$govde")"
  rm -f "$govde"
  [[ "$HTTP_CODE" =~ ^2 ]]
}

# GitLab API: gl METOD /yol [curl secenekleri]
gl() {
  : "${GITLAB_ADMIN_TOKEN:?GITLAB_ADMIN_TOKEN tanimli degil}"
  [ -n "${_GL_CFG:-}" ] || _GL_CFG="$(_curl_cfg gl "header = \"PRIVATE-TOKEN: ${GITLAB_ADMIN_TOKEN}\"")"
  local metod="$1" yol="$2"
  shift 2
  _istek "$_GL_CFG" "$metod" "${GITLAB_URL}/api/v4${yol}" "$@"
}

# Nexus REST: nx METOD /v1/yol [curl secenekleri]
nx() {
  : "${NEXUS_ADMIN_PASSWORD:?NEXUS_ADMIN_PASSWORD tanimli degil}"
  [ -n "${_NX_CFG:-}" ] || _NX_CFG="$(_curl_cfg nx "user = \"admin:${NEXUS_ADMIN_PASSWORD}\"")"
  local metod="$1" yol="$2"
  shift 2
  _istek "$_NX_CFG" "$metod" "${NEXUS_URL}/service/rest${yol}" "$@"
}

# Basarisiz istekte durur.
zorunlu() {  # zorunlu <aciklama> <komut...>
  local ne="$1"
  shift
  "$@" || olum "$ne basarisiz (HTTP $HTTP_CODE): $(printf '%s' "$HTTP_BODY" | head -c 400)"
}

# --- Jenkins -------------------------------------------------------------
# Yonetici kimligi curl yapilandirma dosyasinda durur; CSRF belirteci (crumb) oturum
# cerezine bagli oldugu icin cerez dosyasi kullanilir.
_jk_hazirla() {
  : "${JENKINS_ADMIN_PASSWORD:?JENKINS_ADMIN_PASSWORD tanimli degil}"
  [ -n "${_JK_CFG:-}" ] && return 0
  _JK_CEREZ="$_CURL_DIR/jk-cerez"
  _JK_CFG="$(_curl_cfg jk "user = \"admin:${JENKINS_ADMIN_PASSWORD}\"
cookie = \"$_JK_CEREZ\"
cookie-jar = \"$_JK_CEREZ\"")"
  local crumb
  crumb="$(curl -sS -K "$_JK_CFG" --max-time 30 "${JENKINS_URL}/crumbIssuer/api/json")" || return 1
  _JK_CRUMB="$(jq -r '"\(.crumbRequestField): \(.crumb)"' <<<"$crumb")"
}
# jk METOD /yol [curl secenekleri]
jk() {
  _jk_hazirla || { HTTP_CODE=000; HTTP_BODY="crumb alinamadi"; return 1; }
  local metod="$1" yol="$2"
  shift 2
  _istek "$_JK_CFG" "$metod" "${JENKINS_URL}${yol}" -H "$_JK_CRUMB" "$@"
}
# jk_groovy <dosya> : betigi Jenkins script console'da calistirir (yonetici)
jk_groovy() {
  jk POST /scriptText --data-urlencode "script@$1"
}
