# LAB 05-A dogrulamasi: ortak paket Nexus'ta.
# Basari kriteri: Saha.Common.Contracts.EkipNN 1.0.0 Nexus'ta; servisler paketi Nexus'tan restore
# ediyor; pipeline yesil. ("Ayni surum ikinci kez yayinlanamiyor" cozum kosusunda 409 ile
# gosterilir; dogrulama Nexus'a yazmaz.) Yan etkisi: gecici bir NuGet onbellegine restore yapar.
baslik "LAB 05-A (ekip-$EKIP)"
if ! api "$PROJE_API"; then kaldi "ekip projesi yok: $PROJE_YOLU"; ozet; return 1; fi
PAKET="Saha.Common.Contracts.Ekip$EKIP"
api "$PROJE_API/repository/branches/develop"; DEV_SHA="$(jq -r '.commit.id' <<<"$API_GOVDE")"

baslik "Repo (develop): paket kimligi, PackageReference, Dockerfile'lar"
if dosya src/common-contracts/common-contracts.csproj; then
  esit "PackageId (ekip sonekiyle)" "<PackageId>$PAKET</PackageId>" "$(grep -o '<PackageId>[^<]*</PackageId>' <<<"$API_GOVDE")"
  esit "Version" "<Version>1.0.0</Version>" "$(grep -o '<Version>[^<]*</Version>' <<<"$API_GOVDE")"
else
  kaldi "src/common-contracts/common-contracts.csproj develop'ta yok"
fi
for s in order-service product-service; do
  if dosya "src/$s/$s.csproj"; then
    icerir "$s: PackageReference $PAKET 1.0.0" "<PackageReference Include=\"$PAKET\" Version=\"1.0.0\" />" "$API_GOVDE"
    grep -q 'ProjectReference.*common-contracts' <<<"$API_GOVDE" && kaldi "$s: common-contracts'a ProjectReference duruyor" || gecti "$s: ProjectReference kaldirilmis"
  else
    kaldi "src/$s/$s.csproj yok"
  fi
  if dosya "src/$s/Dockerfile"; then
    grep -q 'COPY src/common-contracts' <<<"$API_GOVDE" && kaldi "$s Dockerfile: common-contracts kaynagi kopyalaniyor (paket kullanilmiyor)" \
      || gecti "$s Dockerfile: common-contracts kaynagi kopyalanmiyor (restore Nexus'tan)"
  fi
done
if dosya NuGet.config; then
  icerir "NuGet.config: <clear />" "<clear />" "$API_GOVDE"
  esit "NuGet.config: tek kaynak (Nexus nuget-group)" "1 $NEXUS_URL/repository/nuget-group/index.json" \
    "$(grep -c '<add key=' <<<"$API_GOVDE") $(grep -o 'value="[^"]*"' <<<"$API_GOVDE" | head -n 1 | sed 's/value="//; s/"$//')"
fi

baslik "Nexus: paket nuget-hosted'da"
nx="$(curl -s --max-time 30 "$NEXUS_URL/service/rest/v1/search?repository=nuget-hosted&name=$PAKET")"
esit "$PAKET surumleri (nuget-hosted)" "1.0.0" "$(jq -r '[.items[] | select(.name == "'"$PAKET"'") | .version] | sort | join(",")' <<<"$nx" 2>/dev/null)"
diger="$(curl -s --max-time 30 "$NEXUS_URL/service/rest/v1/search?repository=nuget-hosted&name=Saha.Common.Contracts" | jq -r '[.items[].name] | unique | join(",")' 2>/dev/null)"
[ -z "$diger" ] && gecti "ekip soneki olmayan Saha.Common.Contracts paketi yok (ekipler cakismiyor)" || kaldi "soneksiz paket yayinlanmis: $diger"

baslik "Restore: paket Nexus'tan geliyor (bos bir NuGet onbellegiyle)"
git -C "$REPO" fetch -q origin develop 2>/dev/null
if d="$(agac "$DEV_SHA")"; then
  onbellek="$(mktemp -d "/tmp/lab-nuget-$EKIP-XXXXXX")"; _GECICI+=("$onbellek")
  r="$(cd "$d" && NUGET_PACKAGES="$onbellek" NUGET_HTTP_CACHE_PATH="$onbellek/http" dotnet restore src/order-service -v n 2>&1)"
  icerir "restore basarili" "Restored $d/src/order-service/order-service.csproj" "$r"
  kucuk="$(printf '%s' "$PAKET" | tr 'A-Z' 'a-z')"
  icerir "paket Nexus nuget-group'tan indirildi" "OK $NEXUS_URL/repository/nuget-group/v3/content/$kucuk/1.0.0/$kucuk.1.0.0.nupkg" "$r"
  grep -q -E 'api\.nuget\.org|nuget\.org/' <<<"$r" && kaldi "restore nuget.org'a gitti" || gecti "restore nuget.org'a gitmedi"
else
  kaldi "develop calisma kopyasi acilamadi"
fi

baslik "Jenkins ve registry: develop yesil, imaj paketle derlendi"
if jenkins_api "$JOB_API/job/develop/api/json?tree=builds[number,result,actions[lastBuiltRevision[SHA1]]]"; then
  b="$(jq -c --arg s "$DEV_SHA" '[.builds[] | select(any(.actions[]?; .lastBuiltRevision.SHA1 == $s))][0] // empty' <<<"$API_GOVDE")"
  if [ -n "$b" ]; then
    esit "develop #$(jq -r .number <<<"$b") (commit ${DEV_SHA:0:7})" "SUCCESS" "$(jq -r .result <<<"$b")"
  else
    kaldi "develop'un son commit'i icin Jenkins build'i yok"
  fi
else
  kaldi "develop job'i okunamadi (HTTP $API_KODU)"
fi
api "$PROJE_API/registry/repositories?per_page=100"; depolar="$API_GOVDE"
for s in order-service product-service; do
  k="$(jq -r --arg n "$s" '.[] | select(.name == $n) | .id' <<<"$depolar")"
  [ -n "$k" ] && api "$PROJE_API/registry/repositories/$k/tags/${DEV_SHA:0:7}" && gecti "$s:${DEV_SHA:0:7} registry'de" || kaldi "$s:${DEV_SHA:0:7} registry'de yok"
done

baslik "Merge Request"
if [ "${KAYNAK:-}" = "checkpoint" ]; then
  atlandi "MR gecmisi (checkpoint bunu geri kurmaz)"
else
  api "$PROJE_API/merge_requests?state=merged&source_branch=$(urlenc feature/ortak-paket)&target_branch=develop&per_page=5"
  iid="$(jq -r '.[0].iid // empty' <<<"$API_GOVDE")"
  [ -n "$iid" ] && gecti "MR !$iid: feature/ortak-paket -> develop merge edilmis" || kaldi "feature/ortak-paket -> develop icin merge edilmis MR yok"
fi

ozet
