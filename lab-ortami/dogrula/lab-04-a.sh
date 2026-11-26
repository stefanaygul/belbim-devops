# LAB 04-A dogrulamasi: GitLab baglantisi ve ilk pipeline.
# Basari kriteri: her push pipeline'i tetikliyor; sonuc MR'da; kirilan test merge'u engelliyor.
# Dogrulama zinciri halka halka denetlenir. Hicbir seyi degistirmez.
# Canli merge reddi (halka 5'in ikinci yarisi) yalnizca cozum kosusunda uretilebilir
# (dogrula/cozum.sh 04-a): burada ayar ve MR gecmisindeki izler denetlenir.
baslik "LAB 04-A (ekip-$EKIP)"
if ! api "$PROJE_API"; then kaldi "ekip projesi yok: $PROJE_YOLU"; ozet; return 1; fi
proje="$API_GOVDE"
HOOK_URL="$JENKINS_URL/project/ekip-$EKIP/$JOB_ADI"
api "$PROJE_API/repository/branches/develop"; DEV_SHA="$(jq -r '.commit.id' <<<"$API_GOVDE")"

baslik "Repo (develop): Jenkinsfile, .gitlab-ci.yml yok"
if api "$PROJE_API/repository/files/$(urlenc .gitlab-ci.yml)?ref=develop"; then
  kaldi ".gitlab-ci.yml var: ayni commit icin iki ayri pipeline durumu olusur"
else
  gecti ".gitlab-ci.yml yok (HTTP $API_KODU)"
fi
if dosya Jenkinsfile; then
  j="$API_GOVDE"
  icerir "agent label'i dotnet-docker" "agent { label 'dotnet-docker' }" "$j"
  icerir "GitLab connection 'gitlab', ekibin token'i 'gitlab-api'" "gitLabConnection(gitLabConnection: 'gitlab', jobCredentialId: 'gitlab-api'" "$j"
  icerir "build baslarken durum pending (gitlabBuilds)" "gitlabBuilds(builds: ['jenkins'])" "$j"
  for s in Restore Build "Unit Test" web-ui; do icerir "stage: $s" "stage('$s')" "$j"; done
  icerir "test sonuclari Jenkins'e (junit)" "junit '**/TestResults/junit.xml'" "$j"
  esit "updateGitlabCommitStatus cagrilari tek bir ad kullaniyor (jenkins)" "3/3" \
    "$(grep -c "updateGitlabCommitStatus name: 'jenkins'" <<<"$j")/$(grep -c 'updateGitlabCommitStatus' <<<"$j")"
  gizli_yok "Jenkinsfile" "$j"
else
  kaldi "Jenkinsfile develop'ta yok"
fi

baslik "GitLab: Project Access Token, webhook, merge ayari"
if api "$PROJE_API/access_tokens?per_page=100"; then
  t="$(jq -c '[.[] | select(.name == "jenkins" and .revoked == false and .active == true)][0] // empty' <<<"$API_GOVDE")"
  if [ -n "$t" ]; then
    esit "Project Access Token 'jenkins' scope" '["api"]' "$(jq -c '.scopes' <<<"$t")"
    esit "Project Access Token rolu (40 = Maintainer)" "40" "$(jq -r '.access_level' <<<"$t")"
  else
    kaldi "etkin 'jenkins' adli Project Access Token yok"
  fi
else
  kaldi "access token listesi okunamadi (HTTP $API_KODU)"
fi
hook_id=""
if api "$PROJE_API/hooks?per_page=100"; then
  h="$(jq -c --arg u "$HOOK_URL" '[.[] | select(.url == $u)][0] // empty' <<<"$API_GOVDE")"
  if [ -n "$h" ]; then
    hook_id="$(jq -r '.id' <<<"$h")"
    gecti "webhook: $HOOK_URL"
    esit "webhook: Push events" "true" "$(jq -r '.push_events' <<<"$h")"
    esit "webhook: Merge request events (Multibranch job desteklemez: 409)" "false" "$(jq -r '.merge_requests_events' <<<"$h")"
    esit "webhook: SSL verification" "true" "$(jq -r '.enable_ssl_verification' <<<"$h")"
  else
    kaldi "webhook yok: $HOOK_URL (adresteki klasor ve job adini denetleyin)"
  fi
else
  kaldi "webhook listesi okunamadi (HTTP $API_KODU)"
fi
esit "Pipelines must succeed" "true" "$(jq -r '.only_allow_merge_if_pipeline_succeeds' <<<"$proje")"

baslik "Halka 1: push olayi Jenkins'e ulasiyor"
if [ -n "$hook_id" ] && api "$PROJE_API/hooks/$hook_id/events?per_page=20"; then
  son="$(jq -c '[.[] | select(.trigger == "push_hooks")][0] // empty' <<<"$API_GOVDE")"
  if [ -n "$son" ]; then
    esit "son push olayina Jenkins'in yaniti ($(jq -r '.request_data.ref // "-"' <<<"$son"))" "200" "$(jq -r '.response_status' <<<"$son")"
    esit "son 20 olayda basarisiz teslim" "0" "$(jq '[.[] | select(.response_status != "200")] | length' <<<"$API_GOVDE")"
  else
    kaldi "webhook'a hic push olayi gitmemis"
  fi
else
  kaldi "webhook olaylari okunamadi"
fi

baslik "Jenkins: credential'lar ve Multibranch job"
if jenkins_api "/job/ekip-$EKIP/credentials/store/folder/domain/_/api/json?tree=credentials[id,typeName]"; then
  for c in gitlab-api:"GitLab API token" gitlab-repo:"Username with password"; do
    tur="$(jq -r --arg i "${c%%:*}" '.credentials[] | select(.id == $i) | .typeName' <<<"$API_GOVDE")"
    esit "klasor credential'i ${c%%:*}" "${c#*:}" "$tur"
  done
else
  kaldi "ekip-$EKIP klasorunun credential'lari okunamadi (HTTP $API_KODU)"
fi
if jenkins_api "$JOB_API/api/json?tree=_class,jobs[name]"; then
  icerir "job turu Multibranch Pipeline" "WorkflowMultiBranchProject" "$(jq -r '._class' <<<"$API_GOVDE")"
  icerir "develop icin branch job'i var" '"develop"' "$(jq -c '[.jobs[].name]' <<<"$API_GOVDE")"
else
  kaldi "Multibranch job yok: ekip-$EKIP/$JOB_ADI (HTTP $API_KODU)"
fi

baslik "Halka 2: Jenkins dogru commit'i derliyor (develop ${DEV_SHA:0:8})"
if jenkins_api "$JOB_API/job/develop/api/json?tree=builds[number,result,building,actions[lastBuiltRevision[SHA1]]]"; then
  b="$(jq -c --arg s "$DEV_SHA" '[.builds[] | select(any(.actions[]?; .lastBuiltRevision.SHA1 == $s))][0] // empty' <<<"$API_GOVDE")"
  if [ -n "$b" ]; then
    no="$(jq -r '.number' <<<"$b")"
    gecti "develop #$no, GitLab'deki son commit'i derledi (${DEV_SHA:0:8})"
    esit "develop #$no sonucu" "SUCCESS" "$(jq -r '.result' <<<"$b")"
    if jenkins_api "$JOB_API/job/develop/$no/testReport/api/json?tree=passCount,failCount"; then
      gecen="$(jq -r '.passCount' <<<"$API_GOVDE")"
      [ "$gecen" -gt 0 ] && gecti "test sonuclari Jenkins'te: $gecen gecti, $(jq -r '.failCount' <<<"$API_GOVDE") kaldi" || kaldi "Jenkins'te test sonucu yok"
    else
      kaldi "develop #$no icin test raporu yok (junit adimi calismamis)"
    fi
  else
    kaldi "develop'un son commit'i (${DEV_SHA:0:8}) icin Jenkins build'i yok"
  fi
else
  kaldi "develop job'i okunamadi (HTTP $API_KODU)"
fi

baslik "Halka 3: sonuc GitLab'e commit status olarak donuyor"
if api "$PROJE_API/repository/commits/$DEV_SHA/statuses?per_page=50"; then
  esit "develop commit'indeki durum adlari (tek ad)" "jenkins" "$(jq -r '[.[].name] | unique | join(",")' <<<"$API_GOVDE")"
  esit "jenkins durumu" "success" "$(jq -r '[.[] | select(.name == "jenkins")][0].status // "yok"' <<<"$API_GOVDE")"
  icerir "durumun adresi Jenkins build'i" "$JENKINS_URL/job/ekip-$EKIP/job/$JOB_ADI/" "$(jq -r '[.[] | select(.name == "jenkins")][0].target_url // ""' <<<"$API_GOVDE")"
else
  kaldi "commit status okunamadi"
fi

baslik "Halka 4-6: MR gecmisi (kirmizi pipeline, sonra duzeltme ve merge)"
if [ "${KAYNAK:-}" = "checkpoint" ]; then
  atlandi "MR gecmisi (checkpoint bunu geri kurmaz)"
else
  api "$PROJE_API/merge_requests?state=merged&source_branch=$(urlenc feature/pipeline)&target_branch=develop&per_page=5"
  iid="$(jq -r '.[0].iid // empty' <<<"$API_GOVDE")"
  if [ -n "$iid" ]; then
    gecti "MR !$iid: feature/pipeline -> develop merge edilmis"
    api "$PROJE_API/merge_requests/$iid/pipelines?per_page=50"
    boru="$API_GOVDE"
    kirmizi="$(jq -r '[.[] | select(.status == "failed")][0].sha // empty' <<<"$boru")"
    if [ -n "$kirmizi" ]; then
      gecti "halka 4: MR'da basarisiz pipeline gorulmus (commit ${kirmizi:0:8}, kaynak $(jq -r '[.[] | select(.status == "failed")][0].source' <<<"$boru"))"
      api "$PROJE_API/repository/commits/$kirmizi/statuses?per_page=50"
      esit "o commit'in durumu" "jenkins=failed" "$(jq -r '[.[] | "\(.name)=\(.status)"] | unique | join(",")' <<<"$API_GOVDE")"
    else
      kaldi "halka 4: MR'da basarisiz pipeline yok (bir test bozulup push edilmemis)"
    fi
    api "$PROJE_API/merge_requests/$iid"
    mr="$API_GOVDE"
    esit "halka 6: merge edilen commit'in pipeline durumu" "success" "$(jq -r '.head_pipeline.status // "yok"' <<<"$mr")"
    son_sha="$(jq -r '.sha' <<<"$mr")"
    sira="$(jq -r --arg k "$kirmizi" --arg s "$son_sha" '([.[] | select(.sha == $k)][0].id // 0) < ([.[] | select(.sha == $s)][0].id // 0)' <<<"$boru")"
    [ -z "$kirmizi" ] || esit "halka 6: yesil pipeline kirmizidan sonra (duzeltme commit'i ${son_sha:0:8})" "true" "$sira"
    esit "merge eden" "ekip$EKIP-lead" "$(jq -r '.merged_by.username // "-"' <<<"$mr")"
  else
    kaldi "feature/pipeline -> develop icin merge edilmis MR yok"
  fi
fi

ozet
