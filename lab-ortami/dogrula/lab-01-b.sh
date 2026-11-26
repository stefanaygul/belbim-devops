# LAB 01-B dogrulamasi: feature branch, conflict ve commit.
# Basari kriteri: katalogda yeni ekipman var; conflict cozuldu, testler yesil;
# gecmis anlamli commit mesajlariyla okunuyor.
baslik "LAB 01-B (ekip-$EKIP)"
[ -d "$REPO/.git" ] || { kaldi "repo yok: $REPO"; ozet; return 1; }
cd "$REPO"

if git show-ref --verify --quiet refs/heads/feature/katalog-sarj-unitesi; then
  R="feature/katalog-sarj-unitesi"
  gecti "branch var: $R@$(git rev-parse --short "$R")"
else
  R="HEAD"
  kaldi "feature/katalog-sarj-unitesi branch'i yok (denetim HEAD uzerinden surer)"
fi
[ ! -f .git/MERGE_HEAD ] && gecti "yarim kalmis merge yok" || kaldi "merge tamamlanmamis (git status)"

baslik "Katalog"
katalog="$(git show "$R:src/product-service/Data/catalog.json" 2>/dev/null)"
if jq -e . >/dev/null 2>&1 <<<"$katalog"; then
  gecti "catalog.json gecerli JSON"
  esit "SRJ-04 kaydi (tek olmali)" "1" "$(jq '[.[] | select(.code == "SRJ-04")] | length' <<<"$katalog")"
  esit "SRJ-04 adi" "Şarj ünitesi" "$(jq -r '[.[] | select(.code == "SRJ-04")][0].name // ""' <<<"$katalog")"
else
  kaldi "catalog.json gecerli JSON degil (conflict isaretleri kalmis olabilir)"
fi
isaret="$(git grep -n -E '^(<<<<<<<|>>>>>>>)( |$)' "$R" -- src tests 2>/dev/null | head -n 3)"
[ -z "$isaret" ] && gecti "conflict isareti kalmamis" || kaldi "conflict isareti var: $isaret"
git grep -q 'SRJ-04' "$R" -- tests && gecti "test SRJ-04 kaydini bekliyor" || kaldi "testlerde SRJ-04 gecmiyor"

baslik "Merge ve gecmis"
rename="$(sablon_sha lab/01b-rename)"
taban="$(sablon_sha main)"
if git merge-base --is-ancestor "$rename" "$R" 2>/dev/null; then
  gecti "lab/01b-rename merge edilmis"
else
  kaldi "lab/01b-rename ($rename) $R gecmisinde yok"
fi
esit "lab/01b-rename'i getiren merge commit'i" "1" \
  "$(git rev-list --merges --parents "$R" 2>/dev/null | awk -v r="$rename" '$3 == r || $2 == r' | wc -l | tr -d ' ')"
kotu="$(git log --no-merges --format='%s' "$taban..$R" "^$rename" 2>/dev/null | grep -v -E "$CONVENTIONAL" | head -n 3)"
sayi="$(git log --no-merges --format='%s' "$taban..$R" "^$rename" 2>/dev/null | grep -c .)"
if [ "$sayi" -ge 1 ] && [ -z "$kotu" ]; then
  gecti "commit mesajlari Conventional Commits biciminde ($sayi commit)"
else
  kaldi "Conventional Commits bicimine uymayan mesaj (ya da commit yok): ${kotu:-yok}"
fi

baslik "Testler ($R)"
if d="$(agac "$R")"; then
  cikti="$(cd "$d" && dotnet test SahaPortal.sln 2>&1)"; kod=$?
  esit "dotnet test (cikis kodu)" "0" "$kod"
  printf '%s\n' "$cikti" | grep -E '^(Passed|Failed)!' | sed 's/^/         /'
fi

ozet
