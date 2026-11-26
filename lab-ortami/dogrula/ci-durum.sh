#!/usr/bin/env bash
# CI zincirinin anlik durumunu API'lerden okur ve bekleneni denetler (Jenkins, GitLab, SonarQube).
# araclar container'inda, yonetici kimlikleriyle calisir; cozum kosularinda kanit uretir.
# `agent` komutu disinda hicbir seyi degistirmez.
#
#   ci-durum.sh build <NN> <branch|tag> <SUCCESS|FAILURE> [konsol-regex]
#       branch'in son commit'i (ya da tag'in commit'i) icin Jenkins build'ini bekler; derlenen SHA'yi ve GitLab commit status'u denetler
#   ci-durum.sh mr <NN> <kaynak-branch> <durum[,durum...]>   MR'in detailed_merge_status degerini bekler
#   ci-durum.sh hook <NN>                                     proje webhook'una giden son olaylar
#   ci-durum.sh sonar <NN> <OK|ERROR>                         develop'un son commit'inin analizi ve Quality Gate
#   ci-durum.sh imaj <NN> <var|yok> [sha]                     registry'de commit SHA etiketli uc imaj
#   ci-durum.sh agent <offline|online>                        agent-1'i gecici olarak devre disi birakir / geri alir
#   ci-durum.sh kuyruk <NN>                                   ekibin Jenkins kuyrugundaki isleri
set -euo pipefail
source "$(dirname "$0")/../bootstrap/lib.sh"

komut="${1:?komut}"
nn="${2:-}"
if [ "$komut" != "agent" ]; then
  [[ "$nn" =~ ^[0-9][0-9]$ ]] || olum "ekip numarasi iki haneli olmali: $nn"
fi
PROJE_YOLU="$GITLAB_GROUP/ekip-$nn/saha-ekipman-portal"
P="/projects/$(urlenc "$PROJE_YOLU")"
JOB_YOLU="/job/ekip-$nn/job/saha-portal-ekip$nn"
SONAR_KEY="saha-portal-ekip$nn"
sq() {
  [ -n "${_SQ_CFG:-}" ] || _SQ_CFG="$(_curl_cfg sq "user = \"admin:${SONAR_ADMIN_PASSWORD}\"")"
  local metod="$1" yol="$2"
  shift 2
  _istek "$_SQ_CFG" "$metod" "${SONAR_URL}${yol}" "$@"
}
dal_yolu() { urlenc "$(urlenc "$1")"; }
# branch_sha <branch|tag>: branch'in ucu ya da tag'in gosterdigi commit
branch_sha() {
  if gl GET "$P/repository/branches/$(urlenc "$1")"; then jq -r '.commit.id' <<<"$HTTP_BODY"; return; fi
  zorunlu "branch ya da tag $1" gl GET "$P/repository/tags/$(urlenc "$1")"
  jq -r '.commit.id' <<<"$HTTP_BODY"
}
satir() { printf '    %s\n' "$*"; }

case "$komut" in
build)
  branch="${3:?branch}"; beklenen="${4:?SUCCESS|FAILURE}"; desen="${5:-}"
  sha="$(branch_sha "$branch")"
  durum=""
  for i in $(seq 1 120); do
    if jk GET "$JOB_YOLU/job/$(dal_yolu "$branch")/api/json?tree=builds%5Bnumber,result,building,duration,actions%5BlastBuiltRevision%5BSHA1%5D%5D%5D"; then
      durum="$(jq -r --arg s "$sha" '[.builds[] | select(any(.actions[]?; .lastBuiltRevision.SHA1 == $s))][0] | select(. != null) | "\(.number) \(.building) \(.result) \(.duration)"' <<<"$HTTP_BODY")"
      case "$durum" in *" false "*) break ;; esac
    fi
    sleep 3
  done
  case "$durum" in *" false "*) ;; *) olum "$branch build'i beklenen surede bitmedi (commit ${sha:0:8}; son durum: ${durum:-job ya da build yok})" ;; esac
  read -r no _ sonuc sure <<<"$durum"
  satir "GitLab  : $branch son commit'i ${sha:0:8}"
  satir "Jenkins : ekip-$nn/saha-portal-ekip$nn/$branch #$no -> $sonuc ($((sure / 1000)) sn), derlenen commit ${sha:0:8} (ayni SHA)"
  [ "$sonuc" = "$beklenen" ] || olum "build sonucu beklenen $beklenen degil: $sonuc"
  case "$sonuc" in SUCCESS) gl_beklenen=success ;; FAILURE) gl_beklenen=failed ;; ABORTED) gl_beklenen=canceled ;; *) gl_beklenen="?" ;; esac
  for i in $(seq 1 15); do
    zorunlu "commit status" gl GET "$P/repository/commits/$sha/statuses?per_page=50"
    [ "$(jq -r '[.[] | select(.name == "jenkins")][0].status // "yok"' <<<"$HTTP_BODY")" = "$gl_beklenen" ] && break
    sleep 2
  done
  jq -r '.[] | "    GitLab  : commit status \(.name) = \(.status) (ref \(.ref)) -> \(.target_url)"' <<<"$HTTP_BODY"
  adlar="$(jq -r '[.[].name] | unique | join(",")' <<<"$HTTP_BODY")"
  [ "$adlar" = "jenkins" ] || olum "bu commit icin tek bir durum adi (jenkins) bekleniyordu; gelen: '${adlar:-yok}'"
  [ "$(jq -r '[.[] | select(.name == "jenkins")][0].status' <<<"$HTTP_BODY")" = "$gl_beklenen" ] || olum "commit status beklenen $gl_beklenen degil"
  if [ -n "$desen" ]; then
    zorunlu "konsol" jk GET "$JOB_YOLU/job/$(dal_yolu "$branch")/$no/consoleText"
    satir "Jenkins konsolu (#$no):"
    grep -E "$desen" <<<"$HTTP_BODY" | tail -n 14 | sed 's/^/      | /'
  fi
  tamam "$branch: build $sonuc, GitLab commit status jenkins=$gl_beklenen"
  ;;

mr)
  kaynak="${3:?kaynak branch}"; beklenen="${4:?durum}"
  zorunlu "MR sorgusu" gl GET "$P/merge_requests?state=opened&source_branch=$(urlenc "$kaynak")"
  iid="$(jq -r '.[0].iid // empty' <<<"$HTTP_BODY")"
  [ -n "$iid" ] || olum "acik MR yok: $kaynak"
  d=""
  for i in $(seq 1 60); do
    # Liste uc noktasindaki deger bayat kalabilir; tek MR uc noktasi gunceldir.
    zorunlu "MR !$iid" gl GET "$P/merge_requests/$iid"
    d="$(jq -r '.detailed_merge_status' <<<"$HTTP_BODY")"
    case ",$beklenen," in *",$d,"*) break ;; esac
    sleep 1
  done
  satir "MR !$iid ($kaynak): detailed_merge_status=$d, head_pipeline=$(jq -r '.head_pipeline.status // "yok"' <<<"$HTTP_BODY"), sha=$(jq -r '.sha[0:8]' <<<"$HTTP_BODY")"
  mr_sha="$(jq -r '.sha' <<<"$HTTP_BODY")"
  zorunlu "commit status" gl GET "$P/repository/commits/$mr_sha/statuses?per_page=50"
  satir "MR'in son commit'i ${mr_sha:0:8} icin commit status: $(jq -r 'if length == 0 then "yok (Jenkins henuz yazmadi)" else ([.[] | "\(.name)=\(.status)"] | join(", ")) end' <<<"$HTTP_BODY")"
  case ",$beklenen," in *",$d,"*) tamam "MR !$iid: $d" ;; *) olum "MR durumu beklenen ($beklenen) degil: $d" ;; esac
  ;;

hook)
  zorunlu "webhook listesi" gl GET "$P/hooks?per_page=100"
  jq -r '.[] | "    webhook \(.id): \(.url)  push=\(.push_events) mr=\(.merge_requests_events) ssl=\(.enable_ssl_verification) durum=\(.alert_status)"' <<<"$HTTP_BODY"
  for h in $(jq -r --arg u "$JENKINS_URL/" '.[] | select(.url | startswith($u)) | .id' <<<"$HTTP_BODY"); do
    zorunlu "webhook olaylari" gl GET "$P/hooks/$h/events?per_page=20"
    jq -r '.[:8][] | "    \(.created_at)  \(.trigger)  ref=\(.request_data.ref // "-")  HTTP \(.response_status)"' <<<"$HTTP_BODY"
  done
  ;;

sonar)
  beklenen="${3:?OK|ERROR}"
  sha="$(branch_sha develop)"
  rev=""
  for i in $(seq 1 60); do
    zorunlu "analiz gecmisi" sq GET "/api/project_analyses/search?project=$SONAR_KEY&ps=1"
    rev="$(jq -r '.analyses[0].revision // empty' <<<"$HTTP_BODY")"
    [ "$rev" = "$sha" ] && break
    sleep 3
  done
  [ "$rev" = "$sha" ] || olum "develop commit'i (${sha:0:8}) icin analiz yok; son analiz: ${rev:0:8}"
  satir "SonarQube: $SONAR_KEY son analiz commit ${rev:0:8} (develop'un son commit'i)"
  zorunlu "Quality Gate" sq GET "/api/qualitygates/project_status?projectKey=$SONAR_KEY"
  gate="$(jq -r '.projectStatus.status' <<<"$HTTP_BODY")"
  satir "Quality Gate: $gate"
  jq -r '.projectStatus.conditions[]? | "      kosul \(.metricKey): \(.status)  deger=\(.actualValue)  esik=\(.comparator) \(.errorThreshold)"' <<<"$HTTP_BODY"
  [ "$(jq '.projectStatus.conditions | length' <<<"$HTTP_BODY")" != "0" ] || satir "      kosul yok (ilk analiz: yeni kod donemi henuz baslamadi)"
  zorunlu "olcumler" sq GET "/api/measures/component?component=$SONAR_KEY&metricKeys=coverage,new_coverage,ncloc,new_lines,new_lines_to_cover,new_violations"
  satir "olcumler: $(jq -c '[.component.measures[] | {(.metric): (.value // .period.value)}] | add' <<<"$HTTP_BODY")"
  [ "$gate" = "$beklenen" ] || olum "Quality Gate beklenen $beklenen degil: $gate"
  tamam "Quality Gate $gate (beklenen)"
  ;;

imaj)
  beklenen="${3:?var|yok}"
  sha="${4:-$(branch_sha develop)}"; kisa="${sha:0:7}"
  zorunlu "registry depolari" gl GET "$P/registry/repositories?per_page=100"
  depolar="$HTTP_BODY"
  for s in order-service product-service web-ui; do
    depo="$(jq -r --arg n "$s" '.[] | select(.name == $n) | .id' <<<"$depolar")"
    if [ -n "$depo" ] && gl GET "$P/registry/repositories/$depo/tags/$kisa"; then
      satir "$s:$kisa var ($(jq -r '.digest[0:19]' <<<"$HTTP_BODY")…)"
      [ "$beklenen" = "var" ] || olum "$s:$kisa registry'de var; bu commit icin imaj uretilmemeliydi"
    else
      satir "$s:$kisa yok"
      [ "$beklenen" = "yok" ] || olum "$s:$kisa registry'de yok"
    fi
  done
  tamam "commit $kisa icin imaj: $beklenen (beklenen)"
  ;;

agent)
  hedef="${2:?offline|online}"
  {
    printf "def hedef = '%s'\n" "$hedef"
    cat <<'GROOVY'
import jenkins.model.Jenkins
import hudson.slaves.OfflineCause
def c = Jenkins.get().getComputer('agent-1')
if (hedef == 'offline') c.setTemporarilyOffline(true, new OfflineCause.ByCLI('lab: kuyruk denemesi'))
else c.setTemporarilyOffline(false, null)
println "agent-1 temporarilyOffline=${c.temporarilyOffline} online=${c.online}"
return null
GROOVY
  } > "$_CURL_DIR/agent.groovy"
  zorunlu "agent" jk_groovy "$_CURL_DIR/agent.groovy"
  satir "$(grep '^agent-1' <<<"$HTTP_BODY")"
  ;;

kuyruk)
  zorunlu "kuyruk" jk GET "/queue/api/json?tree=items%5Bwhy,task%5Burl%5D%5D"
  jq -r --arg j "$JOB_YOLU/" '.items[] | select(.task.url | contains($j)) | "    kuyrukta: \(.task.url | sub(".*/job/"; "") | rtrimstr("/"))  neden: \(.why)"' <<<"$HTTP_BODY"
  zorunlu "calisan build'ler" jk GET "$JOB_YOLU/api/json?tree=jobs%5Bname,lastBuild%5Bnumber,building%5D%5D"
  jq -r '.jobs[] | select(.lastBuild.building == true) | "    calisiyor: \(.name) #\(.lastBuild.number)"' <<<"$HTTP_BODY"
  ;;

deploy)
  # Test VM'deki deploy kaydinin son satirlari ve Jenkins build aciklamasi
  dal="${3:-develop}"
  zorunlu "build aciklamasi" jk GET "$JOB_YOLU/job/$(dal_yolu "$dal")/lastBuild/api/json?tree=number,description,result"
  satir "Jenkins $dal #$(jq -r .number <<<"$HTTP_BODY") ($(jq -r .result <<<"$HTTP_BODY")) aciklama: $(jq -r '.description // "yok"' <<<"$HTTP_BODY" | sed 's#<br>#  #g')"
  ;;

*) olum "bilinmeyen komut: $komut" ;;
esac
