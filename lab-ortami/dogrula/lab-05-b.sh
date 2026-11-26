# LAB 05-B dogrulamasi: final, uctan uca teslimat.
# Basari kriteri: v1.1.0 test ortaminda; miktari 0 olan talep 400, miktari 2 olan talep 201;
# issue'dan imaja kadar iz gosterilebiliyor; deploy kaydinda commit SHA ve imaj digest'i var.
# Yan etkisi: test ortaminda miktari 2 olan bir talep olusturur.
baslik "LAB 05-B (ekip-$EKIP)"
if ! api "$PROJE_API"; then kaldi "ekip projesi yok: $PROJE_YOLU"; ozet; return 1; fi
VM="$TEST_VM_USER@$TEST_VM"
VM_DIZIN="/opt/saha/ekip$EKIP"
vm() { ssh -n -o BatchMode=yes "$VM" "cd $VM_DIZIN && export DOCKER_CONFIG=$VM_DIZIN/.docker && $1" 2>&1; }
api "$PROJE_API/repository/branches/main"; MAIN_SHA="$(jq -r '.commit.id' <<<"$API_GOVDE")"

baslik "Repo (develop): Jenkinsfile'in son hali, deploy/deploy.sh"
if dosya Jenkinsfile; then
  j="$API_GOVDE"
  icerir "Deploy stage'i develop ve tag build'inde" "stage('Deploy: test') {
      when { anyOf { branch 'develop'; buildingTag() } }" "$j"
  icerir "Smoke test stage'i" "stage('Smoke test')" "$j"
  icerir "deploy SSH anahtari credential'dan (sshagent)" "sshagent(['test-vm-ssh'])" "$j"
  icerir "smoke test curl -f ile (HTTP hatasinda kirilir)" "curl -fsS" "$j"
  icerir "tag build'i: SemVer etiketi TAG_NAME'den" 'SURUM=${TAG_NAME#v}' "$j"
  semver="$(awk "/stage\\('Docker: SemVer etiketi'\\)/,/stage\\('Deploy: test'\\)/" <<<"$j")"
  icerir "tag build'i: SHA imajina etiket eklenir" 'docker tag $IMG/$s:$SHA $IMG/$s:$SURUM' "$semver"
  grep -q 'docker build' <<<"$semver" && kaldi "tag build'i imaji yeniden derliyor" || gecti "tag build'i imaji yeniden derlemiyor"
  icerir "imaj yoksa anlasilir hatayla durur" "imaj yeniden derlenmez" "$semver"
  esit "test ortami adresi (TEST_URL)" "TEST_URL          = \"http://$TEST_VM:\${WEB_PORT}\"" "$(grep -o 'TEST_URL *= *"[^"]*"' <<<"$j")"
  gizli_yok "Jenkinsfile" "$j"
else
  kaldi "Jenkinsfile develop'ta yok"
fi
if dosya deploy/deploy.sh; then
  d="$API_GOVDE"
  icerir "deploy.sh: once pull (etiket registry'de yoksa durur)" 'docker compose -p "$PROJE" pull' "$d"
  icerir "deploy.sh: kayit dosyasi" "deploy-kayit.log" "$d"
  icerir "deploy.sh: ekibin registry girisi (DOCKER_CONFIG)" 'DOCKER_CONFIG="$DIZIN/.docker"' "$d"
else
  kaldi "deploy/deploy.sh develop'ta yok"
fi
dosya src/order-service/Endpoints/OrderEndpoints.cs && icerir "order-service: miktar dogrulamasi" "request.Quantity < MinQuantity" "$API_GOVDE"

baslik "GitLab: release, tag, issue"
if api "$PROJE_API/repository/tags/v1.1.0"; then
  esit "v1.1.0, main'in son commit'ini gosteriyor" "${MAIN_SHA:0:8}" "$(jq -r '.commit.id[0:8]' <<<"$API_GOVDE")"
  icerir "v1.1.0 aciklamali (annotated) tag" "release" "$(jq -r '.message // ""' <<<"$API_GOVDE")"
else
  kaldi "v1.1.0 tag'i yok"
fi
api "$PROJE_API/repository/files/CHANGELOG.md/raw?ref=main" && icerir "main CHANGELOG: [1.1.0]" "## [1.1.0]" "$API_GOVDE"
if [ "${KAYNAK:-}" = "checkpoint" ]; then
  atlandi "MR gecmisi (checkpoint bunu geri kurmaz)"
else
  for m in "feature/deploy develop" "feature/12-miktar-dogrulama develop" "release/1.1.0 main" "release/1.1.0 develop"; do
    set -- $m
    api "$PROJE_API/merge_requests?state=merged&source_branch=$(urlenc "$1")&target_branch=$2&per_page=5"
    iid="$(jq -r '.[0].iid // empty' <<<"$API_GOVDE")"
    [ -n "$iid" ] && gecti "MR !$iid: $1 -> $2 merge edilmis" || kaldi "$1 -> $2 icin merge edilmis MR yok"
    [ "$1" = "feature/12-miktar-dogrulama" ] && MIKTAR_MR="$iid"
  done
  if [ -n "${MIKTAR_MR:-}" ]; then
    api "$PROJE_API/merge_requests/$MIKTAR_MR/approvals"
    [ "$(jq '.approved_by | length' <<<"$API_GOVDE")" -ge 1 ] && gecti "MR !$MIKTAR_MR onaylanmis (review): $(jq -r '[.approved_by[].user.username] | join(",")' <<<"$API_GOVDE")" \
      || kaldi "MR !$MIKTAR_MR onaylanmamis"
    api "$PROJE_API/merge_requests/$MIKTAR_MR/closes_issues"
    ISSUE="$(jq -r '.[0].iid // empty' <<<"$API_GOVDE")"
    [ -n "$ISSUE" ] && gecti "MR !$MIKTAR_MR issue #$ISSUE'yu kapatiyor" || kaldi "MR !$MIKTAR_MR bir issue'ya bagli degil (Closes #N)"
    if [ -n "$ISSUE" ]; then api "$PROJE_API/issues/$ISSUE"; esit "issue #$ISSUE durumu" "closed" "$(jq -r .state <<<"$API_GOVDE")"; fi
  fi
fi

baslik "Jenkins: test-vm-ssh, tag kesfi, v1.1.0 build'i"
if jenkins_api "/job/ekip-$EKIP/credentials/store/folder/domain/_/api/json?tree=credentials[id,typeName]"; then
  esit "klasor credential'i test-vm-ssh" "SSH Username with private key" "$(jq -r '.credentials[] | select(.id == "test-vm-ssh") | .typeName' <<<"$API_GOVDE")"
fi
if jenkins_api "$JOB_API/config.xml"; then
  icerir "job: tag kesfi (Discover tags)" "TagDiscoveryTrait" "$API_GOVDE"
  icerir "job: tag build stratejisi" "TagBuildStrategyImpl" "$API_GOVDE"
fi
api "$PROJE_API/hooks?per_page=100"
esit "webhook: Tag push events" "true" "$(jq -r --arg u "$JENKINS_URL/project/ekip-$EKIP/$JOB_ADI" '[.[] | select(.url == $u)][0].tag_push_events // "yok"' <<<"$API_GOVDE")"
if jenkins_api "$JOB_API/job/v1.1.0/api/json?tree=builds[number,result,description,actions[lastBuiltRevision[SHA1]]]"; then
  b="$(jq -c '[.builds[] | select(.result == "SUCCESS")][0] // empty' <<<"$API_GOVDE")"
  if [ -n "$b" ]; then
    gecti "v1.1.0 build'i #$(jq -r .number <<<"$b"): SUCCESS"
    esit "v1.1.0 build'i main'in commit'ini derledi" "${MAIN_SHA:0:8}" "$(jq -r '[.actions[]? | select(.lastBuiltRevision) | .lastBuiltRevision.SHA1][0][0:8]' <<<"$b")"
    icerir "build aciklamasinda etiket" "TAG=1.1.0" "$(jq -r '.description // ""' <<<"$b")"
    icerir "build aciklamasinda commit" "commit=${MAIN_SHA:0:7}" "$(jq -r '.description // ""' <<<"$b")"
    icerir "build aciklamasinda imaj digest'i" "order-service@sha256:" "$(jq -r '.description // ""' <<<"$b")"
  else
    kaldi "v1.1.0 icin basarili build yok"
  fi
else
  kaldi "v1.1.0 tag job'i yok (tag kesfi kapali ya da tag push olayi Jenkins'e ulasmadi)"
fi

baslik "Registry: v1.1.0 ve commit SHA ayni imaj"
api "$PROJE_API/registry/repositories?per_page=100"; depolar="$API_GOVDE"
DIGEST_ORDER=""
for s in order-service product-service web-ui; do
  k="$(jq -r --arg n "$s" '.[] | select(.name == $n) | .id' <<<"$depolar")"
  d1=""; d2=""
  [ -n "$k" ] && api "$PROJE_API/registry/repositories/$k/tags/1.1.0" && d1="$(jq -r .digest <<<"$API_GOVDE")"
  [ -n "$k" ] && api "$PROJE_API/registry/repositories/$k/tags/${MAIN_SHA:0:7}" && d2="$(jq -r .digest <<<"$API_GOVDE")"
  if [ -n "$d1" ] && [ "$d1" = "$d2" ]; then gecti "$s: 1.1.0 = ${MAIN_SHA:0:7} (${d1:0:19}…)"; else kaldi "$s: 1.1.0 (${d1:-yok}) ve ${MAIN_SHA:0:7} (${d2:-yok}) ayni degil"; fi
  [ "$s" = "order-service" ] && DIGEST_ORDER="$d1"
  [ -n "$k" ] && api "$PROJE_API/registry/repositories/$k/tags/1.0.1" && gecti "$s:1.0.1 registry'de (rollback hedefi)" || kaldi "$s:1.0.1 registry'de yok"
done

baslik "Test ortami: calisan surum ve deploy kaydi"
calisan="$(vm "docker compose -p ekip$EKIP images --format json" | jq -r '.[] | "\(.Repository | split("/") | last):\(.Tag)"' 2>/dev/null | sort | tr '\n' ' ')"
esit "calisan imajlar" "order-service:1.1.0 product-service:1.1.0 web-ui:1.1.0 " "$calisan"
kayit="$(vm "tail -n 1 deploy-kayit.log")"
icerir "son deploy kaydi: etiket" "tag=1.1.0" "$kayit"
icerir "son deploy kaydi: commit SHA" "commit=$MAIN_SHA" "$kayit"
[ -n "$DIGEST_ORDER" ] && icerir "son deploy kaydi: order-service digest'i registry'dekiyle ayni" "order-service@$DIGEST_ORDER" "$kayit"
icerir "son deploy kaydi: Jenkins build adresi" "kaynak=$JENKINS_URL/job/ekip-$EKIP/job/$JOB_ADI/job/v1.1.0/" "$kayit"
if [ "${KAYNAK:-}" = "checkpoint" ]; then
  atlandi "rollback provasi (checkpoint bunu geri kurmaz)"
else
  sira="$(vm "cat deploy-kayit.log" | sed -n 's/.* tag=\([^ ]*\) .*/\1/p' | tr '\n' ' ')"
  case "$sira" in
    *"1.1.0 1.0.1 1.1.0 "*) gecti "rollback provasi kayitta: ... 1.1.0 -> 1.0.1 -> 1.1.0" ;;
    *) kaldi "rollback provasi kayitta yok (sira: $sira)" ;;
  esac
fi

baslik "Smoke test ($TEST_URL)"
esit "GET /api/products" "200" "$(http_kodu "$TEST_URL/api/products")"
esit "GET /api/orders/summary (1.1.0'da var)" "200" "$(http_kodu "$TEST_URL/api/orders/summary")"
esit "POST quantity=0" "400" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -X POST "$TEST_URL/api/orders" -H 'Content-Type: application/json' -d '{ "productId": "ADP-01", "quantity": 0 }')"
esit "POST quantity=2" "201" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -X POST "$TEST_URL/api/orders" -H 'Content-Type: application/json' -d '{ "productId": "ADP-01", "quantity": 2 }')"

baslik "Iz: issue'dan imaja"
bilgi "issue #${ISSUE:--} -> MR !${MIKTAR_MR:--} -> develop -> release/1.1.0 -> main ${MAIN_SHA:0:7} -> v1.1.0 -> order-service:1.1.0 ${DIGEST_ORDER:0:19}… -> test VM (deploy-kayit.log)"

ozet
