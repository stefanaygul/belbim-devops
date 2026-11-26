#!/usr/bin/env bash
# Yalnizca sandbox, tum lablar bitince ve Jenkins bosta iken.
# araclar container'inda calisir. Gecici job ekip-99 klasorundedir.
# Sonar webhook hedefi kisa sure yanlis yapilir; EXIT tuzagi geri yukler.
set -euo pipefail
source "$(dirname "$0")/../bootstrap/lib.sh"
grep -qx 'LAB_MODE=sandbox' lab.env || olum 'Yalnizca sandbox modunda calisir'
[ "${CI_HATA_DEMO_ONAYI:-}" = 'bos-sandbox' ] || olum 'Bakim penceresi icin CI_HATA_DEMO_ONAYI=bos-sandbox gerekli'
sq() {
  [ -n "${_SQ_CFG:-}" ] || _SQ_CFG="$(_curl_cfg sq "user = \"admin:${SONAR_ADMIN_PASSWORD}\"")"
  local m="$1" y="$2"; shift 2
  _istek "$_SQ_CFG" "$m" "${SONAR_URL}${y}" "$@"
}
P='/projects/egitim%2Fekip-99%2Fsaha-ekipman-portal'
zorunlu 'final tag' gl GET "$P/repository/tags/v1.1.0"
zorunlu 'Jenkins kuyrugu' jk GET /queue/api/json
[ "$(jq '.items | length' <<<"$HTTP_BODY")" = 0 ] || olum 'Jenkins kuyrugu bos degil'
zorunlu 'Jenkins executor' jk GET '/computer/api/json?depth=1'
[ "$(jq '[.computer[].executors[]? | select(.currentExecutable != null)] | length' <<<"$HTTP_BODY")" = 0 ] || olum 'Jenkins build calisiyor'

adim 'GitLab: Url is blocked -> izinli Jenkins'
if gl POST "$P/hooks" --data-urlencode "url=https://nexus.${LAB_DOMAIN}/demo" --data 'push_events=true'; then
  id="$(jq -r .id <<<"$HTTP_BODY")"; gl DELETE "$P/hooks/$id" >/dev/null
  olum 'izin listesi disi yerel URL kabul edildi'
fi
[ "$HTTP_CODE" = 422 ] || [ "$HTTP_CODE" = 400 ] || olum "beklenmeyen HTTP: $HTTP_CODE"
grep -Eqi 'is blocked|Invalid url given' <<<"$HTTP_BODY" || olum 'URL dogrulama hatasi bekleniyordu'
printf '    HTTP %s: %s\n' "$HTTP_CODE" "$HTTP_BODY"
tamam 'izin listesi disi URL reddedildi (API hata metni surume gore degisir)'
zorunlu 'izinli Jenkins webhook' gl POST "$P/hooks" --data-urlencode "url=${JENKINS_URL}/project/ekip-99/gecici-demo" --data 'push_events=true'
id="$(jq -r .id <<<"$HTTP_BODY")"
zorunlu 'gecici hook temizligi' gl DELETE "$P/hooks/$id"
tamam 'izinli Jenkins URL kabul edildi; gecici hook kaldirildi'

J='/job/ekip-99/job/qg-hata-demose'
if jk GET "$J/api/json"; then olum 'demo job zaten var; gecmisin uzerine yazilmaz'; fi
[ "$HTTP_CODE" = 404 ] || olum "job sorgusu HTTP $HTTP_CODE"
cat > "$_CURL_DIR/job.xml" <<EOF
<flow-definition plugin="workflow-job"><description>Faz 6: webhook timeout ve duzeltme</description><keepDependencies>false</keepDependencies><properties/><definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps"><script><![CDATA[
node('dotnet-docker') {
  deleteDir()
  git branch: 'develop', credentialsId: 'gitlab-repo', url: '${GITLAB_URL}/egitim/ekip-99/saha-ekipman-portal.git'
  withEnv(['SONAR_PROJECT_KEY=saha-portal-ekip99']) {
    withSonarQubeEnv(installationName: 'sonarqube', credentialsId: 'sonar-token') {
      sh 'dotnet restore SahaPortal.sln'
      sh './ci/analyze.sh'
    }
  }
}
timeout(time: 30, unit: 'SECONDS') {
  waitForQualityGate abortPipeline: true, credentialsId: 'sonar-token'
}
]]></script><sandbox>true</sandbox></definition><triggers/><disabled>false</disabled></flow-definition>
EOF
zorunlu 'demo job' jk POST '/job/ekip-99/createItem?name=qg-hata-demose' -H 'Content-Type: application/xml' --data-binary @"$_CURL_DIR/job.xml"
zorunlu 'webhook listesi' sq GET /api/webhooks/list
key="$(jq -r '.webhooks[] | select(.name=="jenkins") | .key' <<<"$HTTP_BODY")"
eski="$(jq -r '.webhooks[] | select(.name=="jenkins") | .url' <<<"$HTTP_BODY")"
[ -n "$key" ] && [ "$eski" = "$JENKINS_URL/sonarqube-webhook/" ] || olum 'Beklenen global webhook bulunamadi'
geri_al() {
  local kod=$?
  if ! sq POST /api/webhooks/update --data-urlencode "webhook=$key" --data-urlencode name=jenkins --data-urlencode "url=$eski"; then
    echo 'KRITIK: webhook geri yuklenemedi; yonetici dogru URLyi geri koymali' >&2
    kod=1
  fi
  rm -rf "$_CURL_DIR"
  exit "$kod"
}
trap geri_al EXIT
calistir() {
  local no="$1" beklenen="$2" sonuc=''
  zorunlu 'demo build' jk POST "$J/build"
  for i in $(seq 1 120); do
    if jk GET "$J/$no/api/json"; then
      sonuc="$(jq -r 'if .building then "" else .result end' <<<"$HTTP_BODY")"
      [ -z "$sonuc" ] || break
    fi
    sleep 2
  done
  zorunlu 'demo console' jk GET "$J/$no/consoleText"
  mkdir -p .cache/ci-hata-demo
  printf '%s\n' "$HTTP_BODY" > ".cache/ci-hata-demo/build-$no.log"
  printf '%s\n' "$HTTP_BODY" | grep -E 'Checking status|task .*status|Quality gate|timeout|Finished:' || true
  [ "$sonuc" = "$beklenen" ] || olum "demo #$no: $sonuc (beklenen $beklenen)"
}
adim 'Sonar webhook yanlis hedef: waitForQualityGate timeout'
zorunlu 'yanlis webhook hedefi' sq POST /api/webhooks/update --data-urlencode "webhook=$key" --data-urlencode name=jenkins --data-urlencode "url=$JENKINS_URL/sonarqube-webhook-yok/"
calistir 1 ABORTED
grep -q 'timeout' .cache/ci-hata-demo/build-1.log || olum 'Timeout kaniti yok'
tamam 'Yanlis webhook hedefiyle Quality Gate bekleyisi timeout oldu'
zorunlu 'webhook duzeltme' sq POST /api/webhooks/update --data-urlencode "webhook=$key" --data-urlencode name=jenkins --data-urlencode "url=$eski"
adim 'Dogru webhook: ayni analiz ve Quality Gate basarili'
calistir 2 SUCCESS
tamam 'Webhook geri yuklendi; ayni job Quality Gate ile SUCCESS'
