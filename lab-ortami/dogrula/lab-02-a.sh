# LAB 02-A dogrulamasi: proje, koruma ve Merge Request (A akisi, Free).
# Basari kriteri: main ve develop korunuyor, dogrudan push reddediliyor; bir MR ikinci
# kisinin incelemesinden gecip develop'a merge edildi.
# KAYNAK=checkpoint ise MR gecmisi denetlenmez (checkpoint onu geri kurmaz).
baslik "LAB 02-A (ekip-$EKIP)"
if ! api "$PROJE_API"; then kaldi "ekip projesi yok: $PROJE_YOLU (HTTP $API_KODU)"; ozet; return 1; fi
proje="$API_GOVDE"
gecti "proje var: $PROJE_YOLU"
esit "gorunurluk" "private" "$(jq -r '.visibility' <<<"$proje")"
esit "varsayilan branch" "develop" "$(jq -r '.default_branch' <<<"$proje")"

baslik "Korumali branch'ler"
for b in main develop; do
  if api "$PROJE_API/protected_branches/$b"; then
    esit "$b: Allowed to push and merge" "No one" "$(jq -r '[.push_access_levels[].access_level] | if . == [0] then "No one" else tostring end' <<<"$API_GOVDE")"
    esit "$b: Allowed to merge" "Maintainers" "$(jq -r '[.merge_access_levels[].access_level] | if . == [40] then "Maintainers" else tostring end' <<<"$API_GOVDE")"
    esit "$b: force push" "false" "$(jq -r '.allow_force_push' <<<"$API_GOVDE")"
  else
    kaldi "$b korumali degil"
  fi
done
esit "merge yontemi" "merge" "$(jq -r '.merge_method' <<<"$proje")"
esit "cozulmemis thread varken merge kapali" "true" "$(jq -r '.only_allow_merge_if_all_discussions_are_resolved' <<<"$proje")"

baslik "Repo icerigi (develop)"
for dosya in .gitlab/merge_request_templates/Default.md .gitlab/CODEOWNERS; do
  api "$PROJE_API/repository/files/$(urlenc "$dosya")?ref=develop" && gecti "$dosya var" || kaldi "$dosya yok"
done
if api "$PROJE_API/repository/files/$(urlenc src/product-service/Data/catalog.json)/raw?ref=develop"; then
  esit "katalogdaki her kayitta inStock (true/false)" "true" "$(jq -r 'all(.[]; (.inStock | type) == "boolean")' <<<"$API_GOVDE" 2>/dev/null)"
  esit "SRJ-04 develop'ta" "Şarj ünitesi" "$(jq -r '[.[] | select(.code == "SRJ-04")][0].name // ""' <<<"$API_GOVDE" 2>/dev/null)"
else
  kaldi "catalog.json okunamadi"
fi

baslik "Merge Request sureci"
if [ "${KAYNAK:-}" = "checkpoint" ]; then
  atlandi "MR, inceleme ve issue gecmisi (checkpoint bunlari geri kurmaz)"
else
  api "$PROJE_API/merge_requests?state=merged&target_branch=develop&source_branch=$(urlenc feature/3-stok-durumu)&per_page=20"
  mr="$(jq -c '.[0] // empty' <<<"$API_GOVDE")"
  if [ -z "$mr" ]; then
    kaldi "feature/3-stok-durumu -> develop icin merge edilmis MR yok"
  else
    iid="$(jq -r '.iid' <<<"$mr")"
    yazar="$(jq -r '.author.username' <<<"$mr")"
    birlestiren="$(jq -r '.merged_by.username // .merge_user.username' <<<"$mr")"
    gecti "MR !$iid merge edilmis: $(jq -r '.title' <<<"$mr")"
    if [ "$yazar" != "$birlestiren" ]; then gecti "yazar ($yazar) ve merge eden ($birlestiren) farkli kisiler"; else kaldi "MR'i yazari merge etmis: $yazar"; fi
    api "$PROJE_API/merge_requests/$iid/discussions?per_page=100"
    esit "yazar disinda birinin actigi, cozulmus thread (en az 1)" "evet" \
      "$(jq -r --arg y "$yazar" '[.[] | select(.notes[0].resolvable == true and .notes[0].author.username != $y and .notes[0].resolved == true)] | if length >= 1 then "evet" else "hayir" end' <<<"$API_GOVDE")"
    esit "cozulmemis thread" "0" "$(jq -r '[.[] | select(.notes[0].resolvable == true and .notes[0].resolved != true)] | length' <<<"$API_GOVDE")"
    api "$PROJE_API/repository/branches/$(urlenc feature/3-stok-durumu)" && kaldi "kaynak branch silinmemis: feature/3-stok-durumu" || gecti "kaynak branch silinmis"
    api "$PROJE_API/merge_requests/$iid/closes_issues"
    kapanan="$(jq -r '.[0].iid // empty' <<<"$API_GOVDE")"
    if [ -n "$kapanan" ]; then
      esit "MR'in kapattigi issue #$kapanan" "closed" "$(jq -r '.[0].state' <<<"$API_GOVDE")"
    else
      kaldi "MR bir issue kapatmiyor (aciklamada 'Closes #N' yok)"
    fi
    if [[ "$(jq -r '.description // ""' <<<"$mr")" == *"Nasıl test edildi?"* ]]; then gecti "MR aciklamasi sablondan gelmis"; else kaldi "MR aciklamasinda sablon basliklari yok"; fi
  fi
fi

baslik "Testler (develop)"
if [ -d "$REPO/.git" ] && git -C "$REPO" fetch --quiet origin 2>/dev/null && d="$(agac origin/develop)"; then
  cikti="$(cd "$d" && dotnet test SahaPortal.sln 2>&1)"; kod=$?
  esit "dotnet test (cikis kodu)" "0" "$kod"
  printf '%s\n' "$cikti" | grep -E '^(Passed|Failed)!' | sed 's/^/         /'
else
  kaldi "yerel repo origin/develop'u getiremedi ($REPO)"
fi

ozet
