# LAB 02-B cozumu: release ve hotfix dongusu.
adim="${ADIM:?ADIM gerekli}"
cd "$REPO"

case "$adim" in
release)
  baslik "Adim 1-2: release/1.0.0, CHANGELOG"
  rol dev
  kos git switch develop
  kos git pull --ff-only
  kos git switch -c release/1.0.0
  cozumden lab-02b-main~1 CHANGELOG.md
  kabuk "git diff | cat"
  kos git add CHANGELOG.md
  kos git commit -m "chore(release): 1.0.0"
  kos git push -u origin release/1.0.0
  ;;

tag-reddi)  # ETIKET=v1.0.0
  baslik "Adim 3 (kontrol): Developer korumali tag olusturamaz"
  rol dev
  kos git switch main
  kos git pull --ff-only
  kos git tag -a "$ETIKET" -m "release: $ETIKET"
  beklenen_hata "You are not allowed to create this tag as it is protected" git push origin "$ETIKET"
  kos git tag -d "$ETIKET"
  ;;

tag)  # ETIKET=v1.0.0
  baslik "Annotated tag: $ETIKET (main uzerinde)"
  rol lead
  kos git switch main
  kos git pull --ff-only
  kos git tag -a "$ETIKET" -m "release: $ETIKET"
  kos git push origin "$ETIKET"
  kos git describe --tags
  kabuk "git cat-file -t $ETIKET"
  ;;

hotfix)
  baslik "Adim 5: hotfix/1.0.1 (main'deki v1.0.0'dan)"
  rol dev
  kos git fetch --tags origin
  kos git switch -c hotfix/1.0.1 v1.0.0
  not_ "Once hatayi gosteren test: bos ekipman koduyla talep 400 donmeli"
  cozumden lab-02b tests/order-service.tests/OrdersApiTests.cs
  beklenen_hata "Failed!" dotnet test tests/order-service.tests
  not_ "Duzeltme"
  cozumden lab-02b src/order-service/Endpoints/OrderEndpoints.cs
  kabuk "git diff HEAD -- src | cat"
  kos dotnet test SahaPortal.sln
  kos git add src tests
  kos git commit -m "fix(order): reject empty product id"
  cozumden lab-02b CHANGELOG.md
  kos git add CHANGELOG.md
  kos git commit -m "chore(release): 1.0.1"
  kos git push -u origin hotfix/1.0.1
  ;;

grafik)
  baslik "Adim 7: grafigi dogrula"
  rol dev
  kos git fetch --prune --tags origin
  kos git switch develop
  kos git pull --ff-only
  kabuk "git log --oneline --graph origin/main origin/develop | head -n 30"
  duzeltme="$(git log --no-merges --format=%H --grep='^fix(order): reject empty product id' origin/main | head -n 1)"
  kabuk "git branch -r --contains $duzeltme | grep origin/"
  kos git tag -l 'v*'
  kabuk "git branch -D release/1.0.0 hotfix/1.0.1 2>/dev/null; git branch"
  baslik "Checkpoint karsilastirmasi"
  agac_ayni origin/develop lab-02b .gitlab/CODEOWNERS
  agac_ayni origin/main lab-02b-main .gitlab/CODEOWNERS
  agac_ayni v1.0.0 lab-02b-main~1 .gitlab/CODEOWNERS
  ;;
*) echo "bilinmeyen adim: $adim" >&2; exit 2 ;;
esac
