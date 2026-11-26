# LAB 04-B dogrulamasi: SonarQube, Quality Gate, imaj (SonarQube Community Build akisi).
# Basari kriteri: testsiz kod kapida kaliyor ve imaj uretilmiyor; testlerle yesile donuyor,
# develop commit'inin imaji registry'de. Hicbir seyi degistirmez.
baslik "LAB 04-B (ekip-$EKIP)"
if ! api "$PROJE_API"; then kaldi "ekip projesi yok: $PROJE_YOLU"; ozet; return 1; fi
api "$PROJE_API/repository/branches/develop"; DEV_SHA="$(jq -r '.commit.id' <<<"$API_GOVDE")"
KISA="${DEV_SHA:0:7}"

baslik "Repo (develop): ci/analyze.sh ve Jenkinsfile"
if dosya ci/analyze.sh; then
  a="$API_GOVDE"
  sira="$(grep -n -E 'dotnet sonarscanner begin|dotnet build|dotnet test|dotnet sonarscanner end' <<<"$a" | sed -E 's/^[0-9]+:dotnet (sonarscanner )?([a-z]+).*/\2/' | tr '\n' ' ')"
  esit "analyze.sh sirasi" "begin build test end " "$sira"
  icerir "proje anahtari degiskenden" '/k:"$SONAR_PROJECT_KEY"' "$a"
  icerir "coverage raporu opencover biciminde" 'sonar.cs.opencover.reportsPaths' "$a"
  grep -q 'sonar.branch.name' <<<"$a" && kaldi "sonar.branch.name gonderiliyor (Community Build desteklemez)" || gecti "sonar.branch.name gonderilmiyor"
  grep -q -E 'sonar\.(token|login)=' <<<"$a" && kaldi "analyze.sh icinde token parametresi var" || gecti "token betikte degil (withSonarQubeEnv ortamdan verir)"
  gizli_yok "ci/analyze.sh" "$a"
  api "$PROJE_API/repository/files/$(urlenc ci/analyze.sh)?ref=develop"
  esit "ci/analyze.sh calistirilabilir (git modu 100755)" "true" "$(jq -r '.execute_filemode' <<<"$API_GOVDE")"
else
  kaldi "ci/analyze.sh develop'ta yok"
fi
if dosya Jenkinsfile; then
  j="$API_GOVDE"
  icerir "proje anahtari" "SONAR_PROJECT_KEY = '$SONAR_KEY'" "$j"
  icerir "analiz withSonarQubeEnv icinde, ekibin token'iyla" "withSonarQubeEnv(installationName: 'sonarqube', credentialsId: 'sonar-token')" "$j"
  icerir "Quality Gate pipeline'i durduruyor" "waitForQualityGate abortPipeline: true" "$j"
  esit "analiz ve kapi yalnizca develop'ta (when { branch 'develop' })" "2" "$(grep -c "when { branch 'develop' }" <<<"$j")"
  icerir "imaj yalnizca develop ve main'de" "when { anyOf { branch 'develop'; branch 'main' } }" "$j"
  icerir "imaj etiketi commit SHA" 'SHA=$(git rev-parse --short HEAD)' "$j"
  icerir "registry girisi credential ile, parola standart giristen" '--password-stdin' "$j"
  grep -q -E ':latest|-t [^ ]+:latest' <<<"$j" && kaldi "Jenkinsfile icinde latest etiketi var" || gecti "latest etiketi yok"
  esit "tek durum adi (jenkins)" "3/3" "$(grep -c "updateGitlabCommitStatus name: 'jenkins'" <<<"$j")/$(grep -c 'updateGitlabCommitStatus' <<<"$j")"
  gizli_yok "Jenkinsfile" "$j"
else
  kaldi "Jenkinsfile develop'ta yok"
fi
api "$PROJE_API/repository/files/$(urlenc .gitlab-ci.yml)?ref=develop" && kaldi ".gitlab-ci.yml var" || gecti ".gitlab-ci.yml yok"

baslik "Jenkins: credential'lar"
if jenkins_api "/job/ekip-$EKIP/credentials/store/folder/domain/_/api/json?tree=credentials[id,typeName]"; then
  for c in sonar-token:"Secret text" gitlab-registry:"Username with password"; do
    esit "klasor credential'i ${c%%:*}" "${c#*:}" "$(jq -r --arg i "${c%%:*}" '.credentials[] | select(.id == $i) | .typeName' <<<"$API_GOVDE")"
  done
else
  kaldi "ekip-$EKIP klasorunun credential'lari okunamadi (HTTP $API_KODU)"
fi
if api "$PROJE_API/deploy_tokens?per_page=100"; then
  esit "Jenkins'in deploy token'i ekip$EKIP-jenkins" '["read_registry","write_registry"]' \
    "$(jq -c --arg u "ekip$EKIP-jenkins" '[.[] | select(.username == $u and .revoked == false)][0].scopes // [] | sort' <<<"$API_GOVDE")"
fi

baslik "SonarQube: proje, yeni kod tanimi, Quality Gate"
if sonar_api "/api/components/show?component=$SONAR_KEY"; then
  gecti "proje var: $SONAR_KEY"
  sonar_api "/api/project_branches/list?project=$SONAR_KEY"
  esit "analiz edilen tek branch (ana branch)" "develop" "$(jq -r '[.branches[].name] | join(",")' <<<"$API_GOVDE")"
  sonar_api "/api/project_analyses/search?project=$SONAR_KEY&ps=100"
  analizler="$API_GOVDE"
  esit "son analiz develop'un son commit'i" "$DEV_SHA" "$(jq -r '.analyses[0].revision // "yok"' <<<"$analizler")"
  sonar_api "/api/qualitygates/project_status?projectKey=$SONAR_KEY"
  kapi="$API_GOVDE"
  esit "Quality Gate" "OK" "$(jq -r '.projectStatus.status' <<<"$kapi")"
  if [ "${KAYNAK:-}" = "checkpoint" ]; then
    atlandi "yeni kod kosullari ve kapi gecmisi (checkpoint tek analizle kurulur: taban cizgisi)"
  else
    esit "yeni kod donemi (New Code)" "PREVIOUS_VERSION" "$(jq -r '.projectStatus.period.mode // "yok"' <<<"$kapi")"
    yk="$(jq -r '[.projectStatus.conditions[] | select(.metricKey == "new_coverage")][0] | "\(.status) \(.actualValue) \(.errorThreshold)"' <<<"$kapi")"
    read -r yk_durum yk_deger yk_esik <<<"$yk"
    esit "yeni kod coverage kosulu (deger %$yk_deger, esik %$yk_esik)" "OK" "$yk_durum"
    n="$(jq '.analyses | length' <<<"$analizler")"
    [ "$n" -ge 3 ] && gecti "analiz sayisi: $n (taban, testsiz kod, testler)" || kaldi "analiz sayisi $n; en az 3 bekleniyordu"
    olaylar="$(jq -r '[.analyses | reverse | .[] | .events[]? | select(.category == "QUALITY_GATE") | .name] | join(" -> ")' <<<"$analizler")"
    icerir "kapi gecmisi: once kaldi, sonra gecti ($olaylar)" "Failed -> Passed" "$olaylar"
  fi
else
  kaldi "SonarQube projesi yok: $SONAR_KEY (HTTP $API_KODU)"
fi

baslik "Jenkins: develop build'leri"
kalan_sha=""
if jenkins_api "$JOB_API/job/develop/api/json?tree=builds[number,result,building,actions[lastBuiltRevision[SHA1]]]"; then
  buildler="$API_GOVDE"
  b="$(jq -c --arg s "$DEV_SHA" '[.builds[] | select(any(.actions[]?; .lastBuiltRevision.SHA1 == $s))][0] // empty' <<<"$buildler")"
  if [ -n "$b" ]; then
    no="$(jq -r '.number' <<<"$b")"
    esit "develop #$no (commit $KISA) sonucu" "SUCCESS" "$(jq -r '.result' <<<"$b")"
    jenkins_api "$JOB_API/job/develop/$no/consoleText"
    k="$API_GOVDE"
    icerir "analiz gonderildi" "ANALYSIS SUCCESSFUL" "$k"
    icerir "kapi sonucu Jenkins'e geldi" "Quality gate is 'OK'" "$k"
    icerir "imaj gonderildi" "$KISA: digest: sha256:" "$k"
  else
    kaldi "develop'un son commit'i ($KISA) icin Jenkins build'i yok"
  fi
  if [ "${KAYNAK:-}" = "checkpoint" ]; then
    atlandi "kalan kapinin build'i (checkpoint bunu geri kurmaz)"
  else
    kalan="$(jq -c '[.builds[] | select(.result == "FAILURE")] | sort_by(.number) | reverse' <<<"$buildler")"
    bulundu=0
    for no in $(jq -r '.[].number' <<<"$kalan"); do
      jenkins_api "$JOB_API/job/develop/$no/consoleText" || continue
      if grep -q "Pipeline aborted due to quality gate failure: ERROR" <<<"$API_GOVDE"; then
        bulundu=1
        kalan_sha="$(jq -r --argjson n "$no" '[.[] | select(.number == $n)][0].actions[] | select(.lastBuiltRevision != null) | .lastBuiltRevision.SHA1' <<<"$kalan" | head -n 1)"
        gecti "develop #$no: Quality Gate kaldi, pipeline durdu (commit ${kalan_sha:0:7})"
        icerir "develop #$no: kapi sonucu ERROR" "Quality gate is 'ERROR'" "$API_GOVDE"
        icerir "develop #$no: Docker stage'i atlandi" 'Stage "Docker Build & Push" skipped due to earlier failure(s)' "$API_GOVDE"
        break
      fi
    done
    [ "$bulundu" -eq 1 ] || kaldi "Quality Gate'te kalan develop build'i yok (testsiz kod develop'a girmemis)"
  fi
else
  kaldi "develop job'i okunamadi (HTTP $API_KODU)"
fi

baslik "Registry: commit SHA etiketli imajlar"
api "$PROJE_API/registry/repositories?per_page=100"
depolar="$API_GOVDE"
for s in order-service product-service web-ui; do
  kimlik="$(jq -r --arg n "$s" '.[] | select(.name == $n) | .id' <<<"$depolar")"
  if [ -n "$kimlik" ] && api "$PROJE_API/registry/repositories/$kimlik/tags/$KISA"; then
    gecti "$s:$KISA var (develop'un son commit'i)"
  else
    kaldi "$s:$KISA registry'de yok"
  fi
  if [ -n "$kalan_sha" ]; then
    if [ -n "$kimlik" ] && api "$PROJE_API/registry/repositories/$kimlik/tags/${kalan_sha:0:7}"; then
      kaldi "$s:${kalan_sha:0:7} var: kapida kalan commit icin imaj uretilmis"
    else
      gecti "$s:${kalan_sha:0:7} yok (kapida kalan commit icin imaj uretilmedi)"
    fi
  fi
done
api "$PROJE_API/repository/commits/$DEV_SHA/statuses?per_page=50"
esit "develop commit'inin GitLab durumu" "jenkins=success" "$(jq -r '[.[] | "\(.name)=\(.status)"] | unique | join(",")' <<<"$API_GOVDE")"
if [ -n "$kalan_sha" ]; then
  api "$PROJE_API/repository/commits/$kalan_sha/statuses?per_page=50"
  esit "kapida kalan commit'in GitLab durumu" "jenkins=failed" "$(jq -r '[.[] | "\(.name)=\(.status)"] | unique | join(",")' <<<"$API_GOVDE")"
fi

baslik "Merge Request'ler"
if [ "${KAYNAK:-}" = "checkpoint" ]; then
  atlandi "MR gecmisi (checkpoint bunu geri kurmaz)"
else
  for kaynak in feature/sonar feature/siparis-ozeti feature/siparis-ozeti-testleri; do
    api "$PROJE_API/merge_requests?state=merged&source_branch=$(urlenc "$kaynak")&target_branch=develop&per_page=5"
    iid="$(jq -r '.[0].iid // empty' <<<"$API_GOVDE")"
    [ -n "$iid" ] && gecti "MR !$iid: $kaynak -> develop merge edilmis" || kaldi "$kaynak -> develop icin merge edilmis MR yok"
  done
fi

ozet
