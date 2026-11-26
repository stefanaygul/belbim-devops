# LAB 02-A cozumu: proje, koruma ve Merge Request (A akisi, Free).
# Sandbox'ta iki rol ayni Linux kullanicisini paylasir: `rol lead` / `rol dev`.
adim="${ADIM:?ADIM gerekli}"
cd "$REPO"

case "$adim" in
anahtar-goster)  # arayuz adimina acik anahtari verir (yalnizca acik anahtar)
  case "$ROL" in lead) cat "$HOME/.ssh/id_ed25519_lead.pub" ;; dev) cat "$HOME/.ssh/id_ed25519.pub" ;; esac
  ;;

ssh-sina)
  baslik "On kosul: SSH anahtari GitLab profilinde"
  for r in lead dev; do
    rol "$r"
    printf '$ ssh -T git@%s\n' "$GITLAB_HOST"
    cikti="$($GIT_SSH_COMMAND -T "git@$GITLAB_HOST" 2>&1)" || true
    printf '%s\n' "$cikti"
    case "$cikti" in *"Welcome to GitLab, @ekip$EKIP-$r!"*) ;; *) echo "HATA: ekip$EKIP-$r icin SSH girisi basarisiz" >&2; exit 1 ;; esac
  done
  ;;

hazirla)
  baslik "Adim 1 (hazirlik): dunku isi main'e al, MR sablonu ve CODEOWNERS ekle"
  rol lead
  kos git switch main
  kos git merge --no-ff feature/katalog-sarj-unitesi -m "Merge branch 'feature/katalog-sarj-unitesi'"
  cozumden lab-02a-main .gitlab
  codeowners_kisisellestir
  kabuk "cat .gitlab/merge_request_templates/Default.md"
  kabuk "cat .gitlab/CODEOWNERS"
  kos git add .gitlab
  kos git commit -m "chore: add merge request template and CODEOWNERS"
  ;;

push)
  baslik "Adim 1: lokal repoyu ekip projesine push et"
  rol lead
  kos git remote rename origin sablon
  kos git remote add origin "$PROJE_SSH"
  kos git push -u origin main
  kos git remote -v
  ;;

develop)
  baslik "Adim 2: develop'u olustur"
  rol lead
  kos git switch -c develop
  kos git push -u origin develop
  ;;

push-reddi)
  baslik "Adim 2 (kontrol): korumali branch'e dogrudan push reddedilir"
  for r in dev lead; do
    for b in develop main; do
      rol "$r"
      kos git switch --quiet "$b"
      kos git commit --quiet --allow-empty -m "test: direct push to $b"
      beklenen_hata "You are not allowed to push code to protected branches on this project" git push origin "$b"
      kos git reset --quiet --hard "origin/$b"
    done
  done
  kos git switch --quiet develop
  ;;

feature)
  baslik "Adim 3-4: feature/3-stok-durumu, stok durumu alani"
  rol dev
  kos git switch develop
  kos git pull --ff-only
  kos git switch -c feature/3-stok-durumu
  cozumden lab-02a src/common-contracts/ProductDto.cs src/product-service/Data/catalog.json tests/product-service.tests/CatalogStoreTests.cs
  kabuk "git diff HEAD --stat | cat"
  kos dotnet test SahaPortal.sln
  kos git add src tests
  kos git commit -m "feat(catalog): add stock status"
  kos git push -u origin feature/3-stok-durumu
  ;;

duzeltme)
  baslik "Adim 6: reviewer yorumuna gore duzeltme"
  rol dev
  kos git switch feature/3-stok-durumu
  cozumden lab-02a tests/product-service.tests/ProductsApiTests.cs
  kos dotnet test SahaPortal.sln
  kos git add tests
  kos git commit -m "test(catalog): cover stock status in the products API"
  kos git push
  ;;

sonuc)
  baslik "Adim 7: merge sonrasi"
  rol dev
  kos git switch develop
  kos git pull --ff-only
  kos git fetch --prune
  kabuk "git branch -r | grep -v sablon/"
  not_ "squash ile merge edilen branch'te 'git branch -d' uyari verir; yerel branch -D ile silinir"
  kos git branch -D feature/3-stok-durumu
  kabuk "git log --oneline --graph -n 8 origin/develop"
  ;;

arayuz)
  baslik "Rol degisimi: ikinci kucuk MR (web-ui stok durumu)"
  rol lead
  kos git switch develop
  kos git pull --ff-only
  kos git switch -c feature/3-stok-durumu-arayuz
  cozumden lab-02a src/web-ui/src/components/CatalogList.jsx src/web-ui/src/components/CatalogList.test.jsx
  kabuk "cd src/web-ui && npm test 2>&1 | tail -n 8"
  kos git add src/web-ui
  kos git commit -m "feat(web-ui): show stock status"
  kos git push -u origin feature/3-stok-durumu-arayuz
  ;;

arayuz-sonuc)
  rol lead
  kos git switch develop
  kos git pull --ff-only
  kos git fetch --prune
  kos git branch -D feature/3-stok-durumu-arayuz
  baslik "Checkpoint karsilastirmasi"
  agac_ayni origin/develop lab-02a .gitlab/CODEOWNERS
  agac_ayni origin/main lab-02a-main .gitlab/CODEOWNERS
  ;;
*) echo "bilinmeyen adim: $adim" >&2; exit 2 ;;
esac
