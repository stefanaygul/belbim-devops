#!/usr/bin/env bash
# CI profilinin (Jenkins, SonarQube) dogrulamasi: API tarafi. araclar container'inda calisir.
# Hicbir seyi degistirmez. dogrula/ci.sh cagirir.
set -uo pipefail
source "$(dirname "$0")/../bootstrap/lib.sh"
source "$(dirname "$0")/lib.sh"
sq() {
  [ -n "${_SQ_CFG:-}" ] || _SQ_CFG="$(_curl_cfg sq "user = \"admin:${SONAR_ADMIN_PASSWORD}\"")"
  local metod="$1" yol="$2"
  shift 2
  _istek "$_SQ_CFG" "$metod" "${SONAR_URL}${yol}" "$@"
}
anonim() { curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "$1" 2>/dev/null; }
ilk="$(ekipler | head -n 1)"
ikinci="$(ekipler | sed -n 2p)"

baslik "Jenkins: surum, executor, agent, global tanimlar"
if jk GET /api/json; then
  cat > "$_CURL_DIR/durum.groovy" <<'GROOVY'
import jenkins.model.Jenkins
import com.cloudbees.plugins.credentials.SystemCredentialsProvider
def j = Jenkins.get()
def a = j.getComputer('agent-1')
def env = j.globalNodeProperties.collectMany { it.hasProperty('envVars') ? it.envVars.collect { k, v -> "${k}=${v}" } : [] }.sort()
println "surum=${Jenkins.VERSION}"
println "controller-executor=${j.numExecutors}"
println "agent=${a?.online} ${a?.node?.labelString} ${a?.numExecutors} ${a?.launcher?.getClass()?.simpleName}"
println "gitlab=${j.getDescriptorByType(com.dabsquared.gitlabjenkins.connection.GitLabConnectionConfig).connections.collect { it.name + ' ' + it.url + ' token:' + (it.apiTokenId ?: 'yok') }.join(';')}"
println "sonar=${j.getDescriptorByType(hudson.plugins.sonar.SonarGlobalConfiguration).installations.collect { it.name + ' ' + it.serverUrl + ' token:' + (it.credentialsId ?: 'yok') }.join(';')}"
println "ortam=${env.join(' ')}"
println "global-credential=${SystemCredentialsProvider.instance.credentials.size()}"
println "kayit=${j.securityRealm.allowsSignup()}"
println "klasorler=${j.items.findAll { it.getClass().simpleName == 'Folder' }*.name.sort().join(',')}"
def ncf = org.jenkinsci.plugins.configfiles.GlobalConfigFiles.get().getById('nuget-config')
println "nuget-config=${ncf ? ncf.content.readLines().findAll { it.contains('<add key=') }.collect { (it =~ /key="([^"]+)" value="([^"]+)"/)[0][1..2].join('=') }.join(' ') : 'yok'}"
return null
GROOVY
  jk_groovy "$_CURL_DIR/durum.groovy"
  d="$HTTP_BODY"
  al() { sed -n "s/^$1=//p" <<<"$d" | head -n 1; }
  gecti "Jenkins surumu: $(al surum)"
  esit "controller executor sayisi" "0" "$(al controller-executor)"
  esit "agent-1 (bagli, label, executor, baglanti)" "true dotnet-docker 2 JNLPLauncher" "$(al agent)"
  esit "GitLab connection (global token yok: ekipler kendi token'ini kullanir)" "gitlab ${GITLAB_URL} token:yok" "$(al gitlab)"
  esit "SonarQube sunucu tanimi (global token yok)" "sonarqube ${SONAR_URL} token:yok" "$(al sonar)"
  esit "ortak ortam degiskenleri" "HUB=${REGISTRY}/egitim/base MCR=${REGISTRY}/egitim/base" "$(al ortam)"
  esit "global (sistem) credential sayisi" "0" "$(al global-credential)"
  esit "kendi kendine kayit" "false" "$(al kayit)"
  beklenen_klasor="$(for n in $(ekipler); do printf 'ekip-%s\n' "$n"; done | sort | paste -sd, -)"
  esit "ekip klasorleri" "$beklenen_klasor" "$(al klasorler)"
  esit "managed file nuget-config (5. gun)" "nexus=${NEXUS_URL}/repository/nuget-group/index.json nexus-hosted=${NEXUS_URL}/repository/nuget-hosted/" "$(al nuget-config)"

  baslik "Jenkins: plugin surumleri (images/jenkins/plugins.txt)"
  jk GET "/pluginManager/api/json?depth=1&tree=plugins%5BshortName,version,active%5D"
  kurulu="$(jq -r '.plugins[] | select(.active) | "\(.shortName):\(.version)"' <<<"$HTTP_BODY" | sort)"
  istenen="$(grep -v -E '^\s*(#|$)' /lab/ortam/images/jenkins/plugins.txt | sort)"
  eksik="$(comm -23 <(printf '%s\n' "$istenen") <(printf '%s\n' "$kurulu") | tr '\n' ' ')"
  fazla="$(comm -13 <(printf '%s\n' "$istenen") <(printf '%s\n' "$kurulu") | tr '\n' ' ')"
  esit "plugins.txt'te olup kurulu olmayan ya da surumu farkli plugin" "" "$eksik"
  esit "kurulu olup plugins.txt'te olmayan plugin" "" "$fazla"
  gecti "sabit surumlu plugin sayisi: $(printf '%s\n' "$istenen" | wc -l | tr -d ' ')"

  baslik "Jenkins: erisim"
  esit "anonim erisim (API)" "403" "$(anonim "$JENKINS_URL/api/json")"
  if [ -n "$ikinci" ]; then
    cfg="$(_curl_cfg jke "user = \"ekip${ilk}:$(ekip_parola "jenkins:ekip${ilk}")\"")"
    esit "ekip${ilk} kendi klasorunu goruyor" "200" "$(curl -sS -K "$cfg" -o /dev/null -w '%{http_code}' --max-time 20 "$JENKINS_URL/job/ekip-${ilk}/api/json")"
    esit "ekip${ilk} baska ekibin klasorunu gormuyor (ekip-${ikinci})" "404" "$(curl -sS -K "$cfg" -o /dev/null -w '%{http_code}' --max-time 20 "$JENKINS_URL/job/ekip-${ikinci}/api/json")"
    esit "ekip${ilk} baska ekibin credential'larini gormuyor" "404" "$(curl -sS -K "$cfg" -o /dev/null -w '%{http_code}' --max-time 20 "$JENKINS_URL/job/ekip-${ikinci}/credentials/store/folder/domain/_/api/json")"
    esit "ekip${ilk} yonetici degil (script console)" "403" "$(curl -sS -K "$cfg" -o /dev/null -w '%{http_code}' --max-time 20 "$JENKINS_URL/manage/script")"
  fi
else
  kaldi "Jenkins API'sine erisilemedi (HTTP $HTTP_CODE)"
fi

baslik "SonarQube: surum, webhook, erisim"
if sq GET /api/system/status; then
  esit "durum" "UP" "$(jq -r '.status' <<<"$HTTP_BODY")"
  gecti "surum: $(jq -r '.version' <<<"$HTTP_BODY")"
  sq GET /api/navigation/global
  esit "surum turu (edition)" "community" "$(jq -r '.edition' <<<"$HTTP_BODY")"
  sq GET "/api/settings/values?keys=sonar.core.serverBaseURL,sonar.validateWebhooks,sonar.forceAuthentication"
  ayar() { jq -r --arg k "$1" '[.settings[] | select(.key == $k)][0].value // "varsayilan"' <<<"$HTTP_BODY"; }
  esit "sunucu adresi" "$SONAR_URL" "$(ayar sonar.core.serverBaseURL)"
  esit "yerel aga webhook izni (sonar.validateWebhooks)" "false" "$(ayar sonar.validateWebhooks)"
  esit "anonim erisim (API)" "401" "$(anonim "$SONAR_URL/api/projects/search")"
  sq GET /api/webhooks/list
  w="$(jq -c '[.webhooks[] | select(.name == "jenkins")][0] // empty' <<<"$HTTP_BODY")"
  esit "global webhook (sondaki / zorunlu)" "${JENKINS_URL}/sonarqube-webhook/" "$(jq -r '.url // "yok"' <<<"$w")"
  if [ -n "$w" ] && sq GET "/api/webhooks/deliveries?webhook=$(jq -r '.key' <<<"$w")&ps=20"; then
    n="$(jq '.deliveries | length' <<<"$HTTP_BODY")"
    if [ "$n" -gt 0 ]; then
      # Giderilmis hata demosu gecmiste kalir. Her projenin bu pencere icindeki
      # en yeni teslimi gecmeli; baska projenin basarisi hatayi ortmez.
      esit "son $n teslimde proje basina en yeni basarisiz webhook" "0" "$(jq '[.deliveries | group_by(.componentKey)[] | max_by(.at) | select(.success != true or .httpStatus != 200)] | length' <<<"$HTTP_BODY")"
      printf '  BILGI  bu penceredeki gecmis+guncel basarisiz teslim: %s\n' "$(jq '[.deliveries[] | select(.success != true or .httpStatus != 200)] | length' <<<"$HTTP_BODY")"
      gecti "son teslim: $(jq -r '.deliveries[0] | "\(.componentKey) HTTP \(.httpStatus) \(.durationMs) ms"' <<<"$HTTP_BODY")"
    else
      printf '  BILGI  webhook teslimi yok (henuz analiz yapilmamis)\n'
    fi
  fi
  sq GET /api/qualitygates/list
  gecti "varsayilan Quality Gate: $(jq -r '.qualitygates[] | select(.isDefault) | .name' <<<"$HTTP_BODY")"
  for n in $(ekipler); do
    sq GET "/api/users/search?q=ekip${n}"
    jq -e --arg u "ekip${n}" 'any(.users[]; .login == $u and .active)' <<<"$HTTP_BODY" >/dev/null && gecti "SonarQube kullanicisi ekip${n}" || kaldi "SonarQube kullanicisi ekip${n} yok"
  done
else
  kaldi "SonarQube API'sine erisilemedi (HTTP $HTTP_CODE)"
fi

baslik "GitLab: Jenkins'e giden istek izni"
gl GET /application/settings
esit "giden istek izin listesi (yalnizca Jenkins)" "[\"jenkins.${LAB_DOMAIN}\"]" "$(jq -c '.outbound_local_requests_whitelist' <<<"$HTTP_BODY")"
esit "yerel aga webhook genel izni" "false" "$(jq -r '.allow_local_requests_from_web_hooks_and_services' <<<"$HTTP_BODY")"

ozet
