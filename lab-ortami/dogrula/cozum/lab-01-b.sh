# LAB 01-B cozumu: feature branch, conflict ve commit. Adimlar ogrenci rehberiyle aynidir.
adim="${ADIM:?ADIM gerekli}"
cd "$REPO"

case "$adim" in
feature)
  baslik "Adim 1: feature branch"
  kos git switch main
  kos git switch -c feature/katalog-sarj-unitesi

  baslik "Adim 2-3: kataloga SRJ-04, testi guncelle"
  cozumden gun1 src/product-service/Data/catalog.json tests/product-service.tests/CatalogStoreTests.cs
  kos git status --short
  kabuk "git diff HEAD | cat"
  kos dotnet test SahaPortal.sln

  baslik "Adim 4: Conventional Commits ile commit"
  kos git add src/product-service tests/product-service.tests
  kos git commit -m "feat(catalog): add charging unit"
  ;;

conflict)
  baslik "Adim 5: lab/01b-rename merge, conflict"
  beklenen_hata "CONFLICT (content)" git merge origin/lab/01b-rename
  kos git status --short
  kabuk "cat src/product-service/Data/catalog.json"
  not_ "Cozum: 'Sarj unitesi' satiri kalir, isaretler silinir"
  cozumden gun1 src/product-service/Data/catalog.json
  kabuk "! grep -n '^<<<<<<<\|^=======\|^>>>>>>>' src/product-service/Data/catalog.json"

  baslik "Adim 6: testleri yeniden calistir, merge'u tamamla"
  kos git add src/product-service/Data/catalog.json
  kos dotnet test SahaPortal.sln
  kos git commit --no-edit

  baslik "Adim 7: gecmis"
  kabuk "git log --oneline --graph --all | head -n 12"
  ;;
*) echo "bilinmeyen adim: $adim" >&2; exit 2 ;;
esac
