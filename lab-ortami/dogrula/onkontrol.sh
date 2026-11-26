#!/usr/bin/env bash
# Hedef ortam icin Docker Compose gerektirmeyen SALT OKUNUR denetim.
# bash dogrula/onkontrol.sh /yol/lab.env NN
# Yetkili API kimlikleri ortamdan: GITLAB_TOKEN, JENKINS_USER/JENKINS_TOKEN,
# SONAR_TOKEN (veya SONAR_USER/SONAR_PASSWORD), NEXUS_USER/NEXUS_PASSWORD.
# Eksikler GECTI sayilmaz. Kimlikler yalnizca GET sorgulari icin kullanilir.
set -uo pipefail
BURASI="$(cd "$(dirname "$0")" && pwd)"
dosya="${1:?kullanim: onkontrol.sh /yol/lab.env NN}"
nn="${2:?ekip numarasi gerekli}"
case "$nn" in [0-9][0-9]) ;; *) echo 'Iki haneli ekip numarasi gerekli' >&2; exit 2 ;; esac
set -a
source "$dosya"
set +a
source "$BURASI/lib.sh"
bilgi() { printf '  BILGI  %s\n' "$*"; }
for a in curl jq ssh; do
  command -v "$a" >/dev/null || { echo "Arac yok: $a" >&2; exit 2; }
done
for v in GITLAB_URL REGISTRY JENKINS_URL SONAR_URL NEXUS_URL TEST_VM TEST_VM_USER CA_CERT; do
  [ -n "${!v:-}" ] || { echo "Ortam degiskeni yok: $v" >&2; exit 2; }
done
[ -s "$CA_CERT" ] || { echo "CA dosyasi yok: $CA_CERT" >&2; exit 2; }
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
umask 077
# Kimlikleri komut satirina ya da ciktiya koyma; curl config ozel gecici dosyadadir.
cfg() {
  local ad="$1" deger="$2"
  case "$deger" in *$'\n'*|*$'\r'*|*'"'*|*'\'*) echo 'Kimlikte desteklenmeyen karakter' >&2; exit 2 ;; esac
  printf '%s = "%s"\n' "${deger%% = *}" "${deger#* = }" > "$tmp/$ad"
}
api() {
  local url="$1" kimlik="${2:-}" k
  if [ -n "$kimlik" ]; then
    k="$(curl -sS --cacert "$CA_CERT" --connect-timeout 10 --max-time 30 -K "$tmp/$kimlik" -o "$tmp/body" -w '%{http_code}' "$url")" || k=000
  else
    k="$(curl -sS --cacert "$CA_CERT" --connect-timeout 10 --max-time 30 -o "$tmp/body" -w '%{http_code}' "$url")" || k=000
  fi
  KOD="$k"
  [ "$k" = 200 ]
}
baslik 'DNS, HTTPS ve CA guveni'
for adres in "$GITLAB_URL/users/sign_in" "$JENKINS_URL/login" "$SONAR_URL/api/system/status" "$NEXUS_URL/service/rest/v1/status"; do
  if api "$adres"; then
    if [ "$adres" = "$SONAR_URL/api/system/status" ]; then
      if jq -e '.status == "UP" and (.version | type == "string" and length > 0)' "$tmp/body" >/dev/null; then
        gecti "$adres: UP, SonarQube $(jq -r .version "$tmp/body")"
      else kaldi 'SonarQube UP degil veya surum bilgisi alinamadi'; fi
    else gecti "$adres"; fi
  else kaldi "$adres: HTTP $KOD (DNS/TLS/ag da denetlenir)"; fi
done
api "https://$REGISTRY/v2/" || true
case "$KOD" in 200|401) gecti "registry TLS/erisim: HTTP $KOD" ;; *) kaldi "registry: HTTP $KOD" ;; esac

baslik 'GitLab surumu ve kullanilacak akis'
if [ -n "${GITLAB_TOKEN:-}" ]; then
  cfg gitlab "header = PRIVATE-TOKEN:$GITLAB_TOKEN"
  if api "$GITLAB_URL/api/v4/version" gitlab; then
    gecti "GitLab $(jq -r .version "$tmp/body")"
  else kaldi "GitLab surum API: HTTP $KOD"; fi
else kaldi 'GitLab surumu denetlenemedi: GITLAB_TOKEN yok'; fi
bilgi "Lab akisi: Free ile uyumlu (push kapali, merge Maintainer). GITLAB_TIER=${GITLAB_TIER:-belirtilmedi} beyanidir; lisans yetkisi dogrulanmadi."

baslik 'Jenkins pluginleri ve agent'
if [ -n "${JENKINS_USER:-}" ] && [ -n "${JENKINS_TOKEN:-}" ]; then
  cfg jenkins "user = $JENKINS_USER:$JENKINS_TOKEN"
  if api "$JENKINS_URL/pluginManager/api/json?depth=1" jenkins; then
    for p in git gitlab-plugin workflow-multibranch workflow-aggregator sonar junit credentials-binding ssh-agent config-file-provider basic-branch-build-strategies; do
      jq -e --arg p "$p" 'any(.plugins[]; .shortName==$p and .active)' "$tmp/body" >/dev/null && gecti "plugin $p" || kaldi "plugin $p yok/pasif"
    done
  else kaldi "Jenkins plugin listesi incelenemedi: HTTP $KOD"; fi
  if api "$JENKINS_URL/computer/api/json?depth=1" jenkins; then
    jq -e 'any(.computer[]; .offline == false and any(.assignedLabels[]?; .name == "dotnet-docker"))' "$tmp/body" >/dev/null && gecti 'dotnet-docker agent online' || kaldi 'dotnet-docker agent online degil'
  else kaldi "Jenkins agent API: HTTP $KOD"; fi
else kaldi 'Jenkins ayarlari denetlenemedi: JENKINS_USER/JENKINS_TOKEN yok'; fi

baslik 'SonarQube ve webhook'
if [ -n "${SONAR_TOKEN:-}" ] || { [ -n "${SONAR_USER:-}" ] && [ -n "${SONAR_PASSWORD:-}" ]; }; then
  if [ -n "${SONAR_TOKEN:-}" ]; then
    cfg sonar "user = $SONAR_TOKEN:"
  else
    cfg sonar "user = $SONAR_USER:$SONAR_PASSWORD"
  fi
  if api "$SONAR_URL/api/navigation/global" sonar; then
    edition="$(jq -r '.edition // "bilinmiyor"' "$tmp/body")"
    [ "$edition" = community ] && gecti 'Community: analiz yalnizca develop' || kaldi "Edition=$edition; bu rehber Community akisini dogrular"
  else kaldi "SonarQube edition: HTTP $KOD"; fi
  if api "$SONAR_URL/api/webhooks/list" sonar; then
    jq -e --arg u "$JENKINS_URL/sonarqube-webhook/" 'any(.webhooks[]; .url==$u)' "$tmp/body" >/dev/null && gecti 'SonarQube webhook URL dogru' || kaldi 'SonarQube webhook eksik/yanlis'
  else kaldi "SonarQube webhook denetlenemedi: HTTP $KOD"; fi
else kaldi 'SonarQube ayarlari denetlenemedi: yonetim sorgularina yetkili SONAR_TOKEN yok'; fi

baslik 'Nexus depolari ve realm'
if [ -n "${NEXUS_USER:-}" ] && [ -n "${NEXUS_PASSWORD:-}" ]; then
  cfg nexus "user = $NEXUS_USER:$NEXUS_PASSWORD"
  if api "$NEXUS_URL/service/rest/v1/repositories" nexus; then
    for ad in nuget.org-proxy nuget-hosted nuget-group npm-proxy npm-hosted npm-group; do
      jq -e --arg n "$ad" 'any(.[]; .name==$n)' "$tmp/body" >/dev/null && gecti "depo $ad" || kaldi "depo $ad yok"
    done
  else kaldi "Nexus depolari: HTTP $KOD"; fi
  if api "$NEXUS_URL/service/rest/v1/security/realms/active" nexus; then
    jq -e 'index("NuGetApiKey") != null' "$tmp/body" >/dev/null && gecti 'NuGet API Key realm' || kaldi 'NuGet API Key realm yok'
  else kaldi "Nexus realm denetlenemedi: HTTP $KOD"; fi
  if api "$NEXUS_URL/service/rest/v1/repositories/nuget/hosted/nuget-hosted" nexus; then
    esit 'nuget-hosted redeploy kapali' ALLOW_ONCE "$(jq -r '.storage.writePolicy' "$tmp/body")"
  else kaldi "Nexus redeploy ayari denetlenemedi: HTTP $KOD"; fi
else kaldi 'Nexus ayarlari denetlenemedi: NEXUS_USER/NEXUS_PASSWORD yok'; fi

baslik 'Test VM: SSH, Docker, ekip dizini'
if ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10 "$TEST_VM_USER@$TEST_VM" \
  "test -d /opt/saha/ekip$nn && test -w /opt/saha/ekip$nn && docker info >/dev/null && docker compose version >/dev/null"; then
  gecti "SSH guvenli; Docker/Compose ve ekip$nn dizini hazir"
else kaldi 'SSH/Docker/dizin denetimi basarisiz'; fi
bilgi 'Job/credential olusturma yetkisi, iki kullanici review akisi ve gercek pipeline calismasi ayrica kurumda sinanmalidir.'
ozet
