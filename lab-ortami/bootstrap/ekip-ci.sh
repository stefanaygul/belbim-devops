#!/usr/bin/env bash
# Bir ekibin CI kaynaklari: Jenkins klasorundeki credential'lar ve Multibranch job,
# SonarQube projesi ve token'i, GitLab'deki Jenkins baglantisi (Project Access Token,
# webhook, Jenkins icin deploy token). araclar container'inda calisir.
#
# YALNIZCA verilen ekibe dokunur: Jenkins'te ekip-NN klasorunun ICI, SonarQube'da
# saha-portal-ekipNN anahtarli projeler ve ekipNN kullanicisinin token'lari, GitLab'de
# egitim/ekip-NN/saha-ekipman-portal. Global Jenkins ve SonarQube ayarlarina, baska
# ekibin klasorune ya da projesine dokunmaz.
#
#   ekip-ci.sh checkpoint <NN> <lab-04a|lab-04b>   LAB 04-A / 04-B sonundaki durum
#   ekip-ci.sh kaldir <NN>                         ekibin Jenkins ve SonarQube kaynaklarini siler
#   ekip-ci.sh parolalar <NN>                      dogrulama betikleri icin (standart cikti, AD=deger)
set -euo pipefail
source "$(dirname "$0")/lib.sh"

mod="${1:?checkpoint|kaldir|parolalar}"
nn="${2:?ekip numarasi}"
[[ "$nn" =~ ^[0-9][0-9]$ ]] || olum "ekip numarasi iki haneli olmali: $nn"

PROJE_YOLU="$GITLAB_GROUP/ekip-$nn/saha-ekipman-portal"
P="/projects/$(urlenc "$PROJE_YOLU")"
KLASOR="ekip-$nn"
JOB="saha-portal-ekip$nn"
JOB_YOLU="/job/$KLASOR/job/$JOB"
SONAR_KEY="saha-portal-ekip$nn"
HOOK_URL="${JENKINS_URL}/project/$KLASOR/$JOB"

if [ "$mod" = "parolalar" ]; then
  printf 'JENKINS_USER=ekip%s\nJENKINS_PAROLA=%s\nSONAR_USER=ekip%s\nSONAR_PAROLA=%s\n' \
    "$nn" "$(ekip_parola "jenkins:ekip$nn")" "$nn" "$(sonar_parola "$nn")"
  exit 0
fi

# SonarQube: sq (yonetici) ve sqe (ekip kullanicisi) METOD /api/yol [curl secenekleri]
sq() {
  : "${SONAR_ADMIN_PASSWORD:?SONAR_ADMIN_PASSWORD tanimli degil}"
  [ -n "${_SQ_CFG:-}" ] || _SQ_CFG="$(_curl_cfg sq "user = \"admin:${SONAR_ADMIN_PASSWORD}\"")"
  local metod="$1" yol="$2"
  shift 2
  _istek "$_SQ_CFG" "$metod" "${SONAR_URL}${yol}" "$@"
}
sqe() {
  [ -n "${_SQE_CFG:-}" ] || _SQE_CFG="$(_curl_cfg sqe "user = \"ekip$nn:$(sonar_parola "$nn")\"")"
  local metod="$1" yol="$2"
  shift 2
  _istek "$_SQE_CFG" "$metod" "${SONAR_URL}${yol}" "$@"
}

# Jenkins betigi: basina ekibin klasor adi eklenir; hata metni varsa durur.
groovy() {  # groovy <dosya>
  zorunlu "Jenkins betigi" jk_groovy "$1"
  if grep -q -E 'Exception|groovy\.lang|startup failed' <<<"$HTTP_BODY"; then
    olum "Jenkins betigi hata verdi: $(head -c 600 <<<"$HTTP_BODY")"
  fi
}
gizli_mi() { [[ "$1" =~ ^[A-Za-z0-9._-]+$ ]] || olum "beklenmeyen token bicimi ($2)"; }

# ---------------------------------------------------------------------------
jenkins_temizle() {
  {
    printf "def klasorAdi = '%s'\n" "$KLASOR"
    cat <<'GROOVY'
import jenkins.model.Jenkins
import com.cloudbees.plugins.credentials.domains.Domain
import com.cloudbees.hudson.plugins.folder.properties.FolderCredentialsProvider
def klasor = Jenkins.get().getItem(klasorAdi)
if (klasor == null) { println "klasor yok: ${klasorAdi}"; return null }
def isler = klasor.items.collect { it }
isler.each { it.delete() }
def ozellik = klasor.properties.get(FolderCredentialsProvider.FolderCredentialsProperty)
def kimlikler = ozellik ? ozellik.store.getCredentials(Domain.global()).collect { it } : []
kimlikler.each { ozellik.store.removeCredentials(Domain.global(), it) }
println "silinen job: ${isler.size()}, silinen credential: ${kimlikler.size()}"
return null
GROOVY
  } > "$_CURL_DIR/temizle.groovy"
  groovy "$_CURL_DIR/temizle.groovy"
  tamam "Jenkins $KLASOR: $(grep -E 'silinen|klasor yok' <<<"$HTTP_BODY" | head -n 1)"
}

sonar_temizle() {
  local k t silinen=0
  zorunlu "SonarQube proje sorgusu" sq GET "/api/projects/search?q=$(urlenc "$SONAR_KEY")&ps=100"
  for k in $(jq -r --arg k "$SONAR_KEY" '.components[] | select(.key == $k or (.key | startswith($k + "-"))) | .key' <<<"$HTTP_BODY"); do
    zorunlu "SonarQube proje silme $k" sq POST /api/projects/delete --data-urlencode "project=$k"
    silinen=$((silinen + 1))
  done
  zorunlu "SonarQube token listesi" sq GET "/api/user_tokens/search?login=ekip$nn"
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    zorunlu "SonarQube token iptali" sq POST /api/user_tokens/revoke --data-urlencode "login=ekip$nn" --data-urlencode "name=$t"
  done < <(jq -r '.userTokens[].name' <<<"$HTTP_BODY")
  tamam "SonarQube: $silinen proje silindi; ekip$nn kullanicisinin token'lari iptal edildi"
}

kaldir_modu() {
  adim "Jenkins ve SonarQube: ekip-$nn kaynaklari kaldiriliyor"
  jenkins_temizle
  sonar_temizle
}

# ---------------------------------------------------------------------------
# develop job'inin belirtilen commit icin build'i bitene kadar bekler; sonucu yazar.
build_bekle() {  # build_bekle <branch> <sha>
  local dal sha="$2" i durum=""
  dal="$(urlenc "$(urlenc "$1")")"
  for i in $(seq 1 120); do
    if jk GET "$JOB_YOLU/job/$dal/api/json?tree=builds%5Bnumber,result,building,actions%5BlastBuiltRevision%5BSHA1%5D%5D%5D"; then
      durum="$(jq -r --arg s "$sha" '[.builds[] | select(any(.actions[]?; .lastBuiltRevision.SHA1 == $s))][0] | select(. != null) | "\(.number) \(.building) \(.result)"' <<<"$HTTP_BODY")"
      case "$durum" in *" false "*) break ;; esac
    fi
    sleep 5
  done
  case "$durum" in *" false "*) ;; *) olum "$1 build'i beklenen surede bitmedi (commit ${sha:0:8}; son durum: ${durum:-job yok})" ;; esac
  BUILD_NO="${durum%% *}"
  BUILD_SONUC="${durum##* }"
}

checkpoint_modu() {
  local lab="${1:?lab}" sonarli=0 etiketli=0
  case "$lab" in
    lab-04a) ;;
    lab-04b|lab-05a) sonarli=1 ;;
    final) sonarli=1; etiketli=1 ;;
    *) olum "CI durumu olan checkpoint'ler: lab-04a lab-04b lab-05a final (gelen: $lab)" ;;
  esac
  zorunlu "ekip projesi $PROJE_YOLU" gl GET "$P"
  zorunlu "develop" gl GET "$P/repository/branches/develop"
  local sha; sha="$(jq -r '.commit.id' <<<"$HTTP_BODY")"

  adim "CI: ekip-$nn icin checkpoint/$lab"
  # Temiz baslangic: eski job (ve calisan build'leri), credential'lar, SonarQube projesi
  jenkins_temizle
  sonar_temizle

  # --- GitLab: Project Access Token, webhook, Jenkins'in deploy token'i ---
  local t pat dt="" st=""
  zorunlu "access token listesi" gl GET "$P/access_tokens?per_page=100"
  for t in $(jq -r '.[] | select(.name == "jenkins" and .revoked == false) | .id' <<<"$HTTP_BODY"); do
    zorunlu "eski access token" gl DELETE "$P/access_tokens/$t"
  done
  zorunlu "Project Access Token" gl POST "$P/access_tokens" \
    --data-urlencode "name=jenkins" --data-urlencode "scopes[]=api" \
    --data-urlencode "access_level=40" --data-urlencode "expires_at=$(date -u -d '+30 days' +%F)"
  pat="$(jq -r '.token' <<<"$HTTP_BODY")"; gizli_mi "$pat" "access token"
  tamam "Project Access Token: jenkins (api, Maintainer)"

  zorunlu "webhook listesi" gl GET "$P/hooks?per_page=100"
  for t in $(jq -r --arg u "$JENKINS_URL/" '.[] | select(.url | startswith($u)) | .id' <<<"$HTTP_BODY"); do
    zorunlu "eski webhook" gl DELETE "$P/hooks/$t"
  done
  # Multibranch job yalnizca push olayini isler; MR olayina 409 doner (bkz. RAPOR.md).
  # Tag push events: LAB 05-B'de tag build'inin baslamasi icin (yalnizca o checkpoint'lerde).
  zorunlu "webhook" gl POST "$P/hooks" --data-urlencode "url=$HOOK_URL" \
    --data-urlencode "push_events=true" --data-urlencode "merge_requests_events=false" \
    --data-urlencode "tag_push_events=$([ "$etiketli" -eq 1 ] && echo true || echo false)" \
    --data-urlencode "enable_ssl_verification=true"
  local hook_id; hook_id="$(jq -r '.id' <<<"$HTTP_BODY")"
  tamam "webhook: $HOOK_URL (Push events$([ "$etiketli" -eq 1 ] && echo ', Tag push events'), SSL dogrulamasi acik)"

  zorunlu "deploy token listesi" gl GET "$P/deploy_tokens?per_page=100"
  for t in $(jq -r --arg a "ekip${nn}-jenkins" '.[] | select(.username == $a) | .id' <<<"$HTTP_BODY"); do
    zorunlu "eski deploy token" gl DELETE "$P/deploy_tokens/$t"
  done
  if [ "$sonarli" -eq 1 ]; then
    zorunlu "deploy token (Jenkins)" gl POST "$P/deploy_tokens" \
      --data-urlencode "name=ekip${nn}-jenkins" --data-urlencode "username=ekip${nn}-jenkins" \
      --data-urlencode "scopes[]=read_registry" --data-urlencode "scopes[]=write_registry"
    dt="$(jq -r '.token' <<<"$HTTP_BODY")"; gizli_mi "$dt" "deploy token"
    tamam "deploy token: ekip${nn}-jenkins (read_registry, write_registry)"

    # --- SonarQube: proje ve analiz token'i, ekip kullanicisi adina ---
    zorunlu "SonarQube projesi" sqe POST /api/projects/create \
      --data-urlencode "project=$SONAR_KEY" --data-urlencode "name=$SONAR_KEY" --data-urlencode "mainBranch=develop"
    zorunlu "SonarQube token" sqe POST /api/user_tokens/generate --data-urlencode "name=jenkins-$SONAR_KEY" \
      --data-urlencode "type=PROJECT_ANALYSIS_TOKEN" --data-urlencode "projectKey=$SONAR_KEY"
    st="$(jq -r '.token' <<<"$HTTP_BODY")"; gizli_mi "$st" "SonarQube token"
    tamam "SonarQube: proje $SONAR_KEY (ana branch develop), Project Analysis Token"
  fi

  # final: Jenkins'in test VM anahtari (workstation'da uretilip test VM'de yetkilendirildi)
  local ssh_b64=""
  if [ "$etiketli" -eq 1 ]; then
    ssh_b64="$(sed -n 's/^JENKINS_SSH_KEY_B64=//p' "/lab/ortam/.cache/checkpoint/ekip${nn}.env" 2>/dev/null)"
    [ -n "$ssh_b64" ] || olum "Jenkins'in test VM anahtari yok (checkpoint-uygula.sh final adimi)"
  fi

  # --- Jenkins: klasor credential'lari ve Multibranch job ---
  {
    printf "def klasorAdi = '%s'\ndef pat = '%s'\ndef dt = '%s'\ndef st = '%s'\ndef dtKullanici = '%s'\ndef sshB64 = '%s'\n" \
      "$KLASOR" "$pat" "$dt" "$st" "ekip${nn}-jenkins" "$ssh_b64"
    cat <<'GROOVY'
import jenkins.model.Jenkins
import com.cloudbees.plugins.credentials.CredentialsScope
import com.cloudbees.plugins.credentials.domains.Domain
import com.cloudbees.plugins.credentials.domains.DomainCredentials
import com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl
import com.cloudbees.hudson.plugins.folder.properties.FolderCredentialsProvider
import com.dabsquared.gitlabjenkins.connection.GitLabApiTokenImpl
import org.jenkinsci.plugins.plaincredentials.impl.StringCredentialsImpl
import hudson.util.Secret
def klasor = Jenkins.get().getItem(klasorAdi)
if (klasor.properties.get(FolderCredentialsProvider.FolderCredentialsProperty) == null) {
  klasor.addProperty(new FolderCredentialsProvider.FolderCredentialsProperty([] as DomainCredentials[]))
}
def store = klasor.properties.get(FolderCredentialsProvider.FolderCredentialsProperty).store
def liste = [
  new GitLabApiTokenImpl(CredentialsScope.GLOBAL, 'gitlab-api', 'GitLab Project Access Token (commit status)', Secret.fromString(pat)),
  new UsernamePasswordCredentialsImpl(CredentialsScope.GLOBAL, 'gitlab-repo', 'GitLab Project Access Token (repo okuma)', 'jenkins', pat),
]
if (st) liste << new StringCredentialsImpl(CredentialsScope.GLOBAL, 'sonar-token', 'SonarQube analiz token', Secret.fromString(st))
if (dt) liste << new UsernamePasswordCredentialsImpl(CredentialsScope.GLOBAL, 'gitlab-registry', 'Registry deploy token', dtKullanici, dt)
if (sshB64) liste << new com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey(CredentialsScope.GLOBAL,
  'test-vm-ssh', 'deploy', new com.cloudbees.jenkins.plugins.sshcredentials.impl.BasicSSHUserPrivateKey.DirectEntryPrivateKeySource(
    new String(sshB64.decodeBase64(), 'UTF-8')), '', 'Test VM deploy anahtari (Jenkins)')
liste.each { c -> store.addCredentials(Domain.global(), c) }
println "credential: ${liste*.id.join(', ')}"
return null
GROOVY
  } > "$_CURL_DIR/cred.groovy"
  groovy "$_CURL_DIR/cred.groovy"
  rm -f "$_CURL_DIR/cred.groovy"
  tamam "Jenkins $KLASOR $(grep '^credential:' <<<"$HTTP_BODY")"

  # Arayuzle olusturulan job'in XML'iyle ayni yapi. <owner reference="../.."/> satirlari zorunludur:
  # eksik olursa job arayuzden kaydedilemez (configSubmit: NullPointerException, "this.owner is null")
  # ve yarim uygulanan ayardan sonra tarama credential'i bulamaz (Faz 5'te yasandi).
  # Tag kesfi ve build stratejileri LAB 05-B'nin adimidir; yalnizca o checkpoint'lerde eklenir.
  local etiket_ozellik="" etiket_strateji=""
  if [ "$etiketli" -eq 1 ]; then
    etiket_ozellik="<jenkins.plugins.git.traits.TagDiscoveryTrait/>"
    etiket_strateji="<buildStrategies>
          <jenkins.branch.buildstrategies.basic.BranchBuildStrategyImpl/>
          <jenkins.branch.buildstrategies.basic.TagBuildStrategyImpl>
            <atLeastMillis>-1</atLeastMillis>
            <atMostMillis>86400000</atMostMillis>
          </jenkins.branch.buildstrategies.basic.TagBuildStrategyImpl>
        </buildStrategies>"
  fi
  cat > "$_CURL_DIR/job.xml" <<XML
<org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject>
  <description>Saha Ekipman Talep Portali - ekip $nn</description>
  <sources class="jenkins.branch.MultiBranchProject\$BranchSourceList">
    <data>
      <jenkins.branch.BranchSource>
        <source class="jenkins.plugins.git.GitSCMSource">
          <id>gitlab</id>
          <remote>${GITLAB_URL}/${PROJE_YOLU}.git</remote>
          <credentialsId>gitlab-repo</credentialsId>
          <traits>
            <jenkins.plugins.git.traits.BranchDiscoveryTrait/>
            ${etiket_ozellik}
          </traits>
        </source>
        <strategy class="jenkins.branch.DefaultBranchPropertyStrategy">
          <properties class="empty-list"/>
        </strategy>
        ${etiket_strateji}
      </jenkins.branch.BranchSource>
    </data>
    <owner class="org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject" reference="../.."/>
  </sources>
  <factory class="org.jenkinsci.plugins.workflow.multibranch.WorkflowBranchProjectFactory">
    <owner class="org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject" reference="../.."/>
    <scriptPath>Jenkinsfile</scriptPath>
  </factory>
</org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject>
XML
  zorunlu "Multibranch job" jk POST "/job/$KLASOR/createItem?name=$JOB" \
    -H "Content-Type: application/xml" --data-binary "@$_CURL_DIR/job.xml"
  # Arayuzden kaydetmenin yaptigini dener: kaynak listesi yeniden yazilir ve diske kaydedilir.
  {
    printf "def jobAdi = '%s'\n" "$KLASOR/$JOB"
    cat <<'GROOVY'
def p = jenkins.model.Jenkins.get().getItemByFullName(jobAdi)
p.setSourcesList(new ArrayList(p.getSourcesList()))
p.save()
println "kaynak-sahibi=${p.SCMSources[0].owner == p}"
return null
GROOVY
  } > "$_CURL_DIR/job-dene.groovy"
  groovy "$_CURL_DIR/job-dene.groovy"
  grep -q '^kaynak-sahibi=true$' <<<"$HTTP_BODY" || olum "job kaydedilemiyor: $(head -c 300 <<<"$HTTP_BODY")"
  tamam "Multibranch job: $KLASOR/$JOB (Git, HTTPS, credential gitlab-repo$([ "$etiketli" -eq 1 ] && echo '; tag kesfi, tag build stratejisi'); arayuzden kaydedilebilir)"
  # Branch taramasini webhook baslatir: GitLab'in "Test > Push events" istegi (baglanti da sinanir).
  zorunlu "webhook testi (Push events)" gl POST "$P/hooks/$hook_id/test/push_events"
  tamam "webhook testi: Push events Jenkins'e ulasti (HTTP $HTTP_CODE); branch taramasi basladi"

  # --- develop build'i: commit status, (lab-04b) Quality Gate ve imaj ---
  build_bekle develop "$sha"
  [ "$BUILD_SONUC" = "SUCCESS" ] || olum "develop build #$BUILD_NO: $BUILD_SONUC (beklenen SUCCESS). Konsol: $JENKINS_URL$JOB_YOLU/job/develop/$BUILD_NO/console"
  tamam "develop build #$BUILD_NO: SUCCESS (commit ${sha:0:8})"
  local i durum=""
  for i in $(seq 1 12); do
    zorunlu "commit status" gl GET "$P/repository/commits/$sha/statuses?name=jenkins"
    durum="$(jq -r '.[0].status // "yok"' <<<"$HTTP_BODY")"
    [ "$durum" = "success" ] && break
    sleep 2
  done
  [ "$durum" = "success" ] || olum "GitLab commit status 'jenkins' beklenen 'success' degil: $durum"
  tamam "GitLab commit status: jenkins = success"

  if [ "$sonarli" -eq 1 ]; then
    zorunlu "Quality Gate" sq GET "/api/qualitygates/project_status?projectKey=$SONAR_KEY"
    [ "$(jq -r '.projectStatus.status' <<<"$HTTP_BODY")" = "OK" ] || olum "Quality Gate OK degil: $(jq -c '.projectStatus' <<<"$HTTP_BODY" | head -c 300)"
    tamam "SonarQube Quality Gate: OK"
    local kisa="${sha:0:7}" depo s
    zorunlu "registry depolari" gl GET "$P/registry/repositories?per_page=100"
    local depolar="$HTTP_BODY"
    for s in order-service product-service web-ui; do
      depo="$(jq -r --arg n "$s" '.[] | select(.name == $n) | .id' <<<"$depolar")"
      [ -n "$depo" ] && gl GET "$P/registry/repositories/$depo/tags/$kisa" || olum "registry'de $s:$kisa yok"
    done
    tamam "registry: order-service, product-service, web-ui etiketi $kisa (develop commit'i)"
  fi

  if [ "$etiketli" -eq 1 ]; then
    # main build'i SHA imajini uretir; ardindan v1.1.0 tag build'i ona SemVer etiketi ekler ve deploy eder.
    # Checkpoint commit'leri sabit tarihlidir (1 gunden eski): tag build'i kendiliginden baslamaz, burada baslatilir.
    zorunlu "main" gl GET "$P/repository/branches/main"
    local ana; ana="$(jq -r '.commit.id' <<<"$HTTP_BODY")"
    build_bekle main "$ana"
    [ "$BUILD_SONUC" = "SUCCESS" ] || olum "main build #$BUILD_NO: $BUILD_SONUC"
    tamam "main build #$BUILD_NO: SUCCESS (commit ${ana:0:8}; SHA imaji registry'de)"
    jk POST "$JOB_YOLU/job/v1.1.0/build?delay=0" || [ "$HTTP_CODE" = "302" ] || olum "v1.1.0 tag build'i baslatilamadi (HTTP $HTTP_CODE)"
    build_bekle v1.1.0 "$ana"
    [ "$BUILD_SONUC" = "SUCCESS" ] || olum "v1.1.0 build #$BUILD_NO: $BUILD_SONUC. Konsol: $JENKINS_URL$JOB_YOLU/job/v1.1.0/$BUILD_NO/console"
    tamam "v1.1.0 tag build'i #$BUILD_NO: SUCCESS (SemVer etiketi, test VM'e deploy, smoke test)"
  fi
}

case "$mod" in
  checkpoint) checkpoint_modu "${3:-}" ;;
  kaldir) kaldir_modu ;;
  *) olum "kullanim: ekip-ci.sh checkpoint <NN> <lab>|kaldir <NN>|parolalar <NN>" ;;
esac
