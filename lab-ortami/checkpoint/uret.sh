#!/usr/bin/env bash
# checkpoint/* branch'lerini portal-starter reposunda bastan uretir (bash 3.2 uyumlu).
# Kaynak: bu klasordeki adimlar/ (her alt klasor bir commit'in dosyalari).
# Yazar ve tarihler sabittir; ayni girdi her zaman ayni commit SHA'larini uretir.
#
# Branch'ler ogrencinin GitLab'de uretecegi grafigi izler (squash + merge commit, GitFlow).
# main tarafinin durumu ayri branch'lerde tutulur: checkpoint/lab-02a-main, checkpoint/lab-02b-main,
# checkpoint/final-main.
#
# Kullanim: checkpoint/uret.sh [starter-repo-yolu]
set -euo pipefail
BURASI="$(cd "$(dirname "$0")" && pwd)"
REPO="${1:-$BURASI/../../portal-starter}"
ADIMLAR="$BURASI/adimlar"
cd "$REPO"

[ -z "$(git status --porcelain)" ] || { echo "HATA: $REPO calisma agaci temiz degil" >&2; exit 1; }
git rev-parse --verify --quiet main >/dev/null || { echo "HATA: main yok" >&2; exit 1; }

export GIT_AUTHOR_NAME="Egitim Ortami" GIT_AUTHOR_EMAIL="egitim@kurum.test"
export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"

tarih() { export GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1"; }
uygula() { local a; for a in "$@"; do cp -R "$ADIMLAR/$a/." .; done; git add -A; }
commit() { git commit --quiet -m "$1"; }
# birlestir <branch> <mesaj>: her zaman merge commit'i (GitLab "Merge commit" yontemi)
birlestir() { git merge --quiet --no-ff -m "$2" "$1"; }
isaretle() { git branch --quiet --force "$1" HEAD; }

# Onceki uretimi temizle
for b in $(git for-each-ref --format='%(refname:short)' 'refs/heads/checkpoint/*' 'refs/heads/_uret/*'); do
  git branch --quiet -D "$b"
done

# --- Gun 1 ---------------------------------------------------------------------
# LAB 01-A: lab/01a-conflict uzerindeki NU1605'in cozumu (surumu hizala)
git checkout --quiet -b _uret/01a lab/01a-conflict
sed -i.bak 's#Include="Microsoft.EntityFrameworkCore" Version="9.0.23"#Include="Microsoft.EntityFrameworkCore" Version="10.0.15"#' \
  src/order-service/order-service.csproj
rm -f src/order-service/order-service.csproj.bak
git add -A
tarih "2026-11-02T12:00:00+03:00"; commit "fix(order): align EntityFrameworkCore version"
isaretle checkpoint/lab-01a

# LAB 01-B: feature branch + lab/01b-rename ile conflict
git checkout --quiet -b _uret/feature-sarj main
uygula 01b-sarj-unitesi
tarih "2026-11-02T14:00:00+03:00"; commit "feat(catalog): add charging unit"
tarih "2026-11-02T15:00:00+03:00"
if git merge --quiet --no-ff lab/01b-rename -m x >/dev/null 2>&1; then
  echo "HATA: lab/01b-rename conflict uretmedi" >&2; exit 1
fi
uygula 01b-sarj-unitesi
commit "Merge branch 'lab/01b-rename' into feature/katalog-sarj-unitesi"
isaretle checkpoint/gun1

# --- Gun 2 ---------------------------------------------------------------------
# LAB 02-A adim 1: dunku is main'e alinir, sablon dosyalari eklenir (ilk push'tan once)
git checkout --quiet -b _uret/main main
tarih "2026-11-03T09:30:00+03:00"; birlestir _uret/feature-sarj "Merge branch 'feature/katalog-sarj-unitesi'"
uygula 02a-sablon
tarih "2026-11-03T09:40:00+03:00"; commit "chore: add merge request template and CODEOWNERS"
isaretle checkpoint/lab-02a-main

git checkout --quiet -b _uret/develop
# MR: feature/3-stok-durumu -> develop (squash)
git checkout --quiet -b _uret/f3
uygula 02a-stok-durumu
tarih "2026-11-03T10:30:00+03:00"; commit "feat(catalog): add stock status"
git checkout --quiet _uret/develop
tarih "2026-11-03T10:45:00+03:00"; birlestir _uret/f3 "Merge branch 'feature/3-stok-durumu' into 'develop'"
# MR: feature/3-stok-durumu-arayuz -> develop (squash; rol degisimi)
git checkout --quiet -b _uret/f3ui
uygula 02a-stok-arayuz
tarih "2026-11-03T11:00:00+03:00"; commit "feat(web-ui): show stock status"
git checkout --quiet _uret/develop
tarih "2026-11-03T11:10:00+03:00"; birlestir _uret/f3ui "Merge branch 'feature/3-stok-durumu-arayuz' into 'develop'"
isaretle checkpoint/lab-02a

# LAB 02-B: release/1.0.0
git checkout --quiet -b _uret/release
uygula 02b-release-1.0.0
tarih "2026-11-03T14:00:00+03:00"; commit "chore(release): 1.0.0"
git checkout --quiet _uret/main
tarih "2026-11-03T14:20:00+03:00"; birlestir _uret/release "Merge branch 'release/1.0.0' into 'main'"
git checkout --quiet _uret/develop
tarih "2026-11-03T14:40:00+03:00"; birlestir _uret/release "Merge branch 'release/1.0.0' into 'develop'"
# hotfix/1.0.1 (main'den)
git checkout --quiet -b _uret/hotfix _uret/main
uygula 02b-hotfix-1.0.1
tarih "2026-11-03T15:00:00+03:00"; commit "fix(order): reject empty product id"
uygula 02b-hotfix-changelog
tarih "2026-11-03T15:10:00+03:00"; commit "chore(release): 1.0.1"
git checkout --quiet _uret/main
tarih "2026-11-03T15:30:00+03:00"; birlestir _uret/hotfix "Merge branch 'hotfix/1.0.1' into 'main'"
isaretle checkpoint/lab-02b-main
git checkout --quiet _uret/develop
tarih "2026-11-03T15:45:00+03:00"; birlestir _uret/hotfix "Merge branch 'hotfix/1.0.1' into 'develop'"
isaretle checkpoint/lab-02b
isaretle checkpoint/gun2

# --- Gun 3 ---------------------------------------------------------------------
# LAB 03-A: feature/9-docker (MR'i LAB 03-B'nin sonunda acilir)
git checkout --quiet -b _uret/f9
uygula 03a-order-dockerfile
tarih "2026-11-04T10:00:00+03:00"; commit "build(order): add multi-stage Dockerfile"
uygula 03a-product-dockerfile
tarih "2026-11-04T10:20:00+03:00"; commit "build(product): add multi-stage Dockerfile"
uygula 03a-web-ui-dockerfile
tarih "2026-11-04T10:40:00+03:00"; commit "build(web-ui): add Node and Nginx Dockerfile"
uygula 03a-dockerignore
tarih "2026-11-04T11:00:00+03:00"; commit "build: add .dockerignore"
isaretle checkpoint/lab-03a

# LAB 03-B: compose, nginx ve /data duzeltmesi; MR feature/9-docker -> develop (squash)
git checkout --quiet -b _uret/f9s _uret/develop
uygula 03a-order-dockerfile 03a-product-dockerfile 03a-web-ui-dockerfile 03a-dockerignore 03b-compose 03b-data-dizini
tarih "2026-11-04T15:30:00+03:00"; commit "build(docker): add Dockerfiles and compose deployment"
git checkout --quiet _uret/develop
tarih "2026-11-04T15:45:00+03:00"; birlestir _uret/f9s "Merge branch 'feature/9-docker' into 'develop'"
isaretle checkpoint/lab-03b
isaretle checkpoint/gun3

# --- Gun 4 ---------------------------------------------------------------------
# Hazir branch: testsiz yeni kod (LAB 04-B). Katilimci dosyalari bu branch'ten alir ve
# kendi commit'ini atar; branch merge edilmez (gecmisi ekip projesininkiyle ortak degildir).
git branch --quiet -D lab/04b-untested 2>/dev/null || true
git checkout --quiet -b lab/04b-untested checkpoint/lab-03b
uygula 04b-untested
tarih "2026-11-05T09:00:00+03:00"; commit "feat(order): add order summary endpoint"

# LAB 04-A: MR feature/pipeline -> develop (squash)
git checkout --quiet -b _uret/f-pipeline _uret/develop
uygula 04a-jenkinsfile
tarih "2026-11-05T10:30:00+03:00"; commit "ci: add Jenkins pipeline"
git checkout --quiet _uret/develop
tarih "2026-11-05T10:45:00+03:00"; birlestir _uret/f-pipeline "Merge branch 'feature/pipeline' into 'develop'"
isaretle checkpoint/lab-04a

# LAB 04-B: analiz ve Quality Gate; testsiz kod; testler
git checkout --quiet -b _uret/f-sonar
uygula 04b-sonar
tarih "2026-11-05T14:00:00+03:00"; commit "ci: add SonarQube analysis, Quality Gate and image publishing"
git checkout --quiet _uret/develop
tarih "2026-11-05T14:15:00+03:00"; birlestir _uret/f-sonar "Merge branch 'feature/sonar' into 'develop'"
git checkout --quiet -b _uret/f-ozet
uygula 04b-untested
tarih "2026-11-05T15:00:00+03:00"; commit "feat(order): add order summary endpoint"
git checkout --quiet _uret/develop
tarih "2026-11-05T15:10:00+03:00"; birlestir _uret/f-ozet "Merge branch 'feature/siparis-ozeti' into 'develop'"
git checkout --quiet -b _uret/f-ozet-test
uygula 04b-tests
tarih "2026-11-05T15:40:00+03:00"; commit "test(order): cover the order summary"
git checkout --quiet _uret/develop
tarih "2026-11-05T15:50:00+03:00"; birlestir _uret/f-ozet-test "Merge branch 'feature/siparis-ozeti-testleri' into 'develop'"
isaretle checkpoint/lab-04b
isaretle checkpoint/gun4

# --- Gun 5 ---------------------------------------------------------------------
# LAB 05-A: paket kimligi ve surumu, PackageReference; MR feature/ortak-paket -> develop (squash)
git checkout --quiet -b _uret/f-paket
uygula 05a-paket
tarih "2026-11-06T10:30:00+03:00"; commit "build(contracts): consume common contracts as a NuGet package"
git checkout --quiet _uret/develop
tarih "2026-11-06T10:45:00+03:00"; birlestir _uret/f-paket "Merge branch 'feature/ortak-paket' into 'develop'"
isaretle checkpoint/lab-05a

# LAB 05-B: deploy stage'leri; miktar dogrulamasi; release/1.1.0 -> main, v1.1.0; geri develop'a
git checkout --quiet -b _uret/f-deploy
uygula 05b-deploy
tarih "2026-11-06T13:30:00+03:00"; commit "ci: deploy to the test VM and run a smoke test"
git checkout --quiet _uret/develop
tarih "2026-11-06T13:40:00+03:00"; birlestir _uret/f-deploy "Merge branch 'feature/deploy' into 'develop'"
git checkout --quiet -b _uret/f-miktar
uygula 05b-miktar
tarih "2026-11-06T14:20:00+03:00"; commit "fix(order): reject quantities below one"
git checkout --quiet _uret/develop
tarih "2026-11-06T14:30:00+03:00"; birlestir _uret/f-miktar "Merge branch 'feature/12-miktar-dogrulama' into 'develop'"
git checkout --quiet -b _uret/release-110
uygula 05b-release
tarih "2026-11-06T15:00:00+03:00"; commit "chore(release): 1.1.0"
git checkout --quiet -b _uret/main-final checkpoint/lab-02b-main
tarih "2026-11-06T15:10:00+03:00"; birlestir _uret/release-110 "Merge branch 'release/1.1.0' into 'main'"
isaretle checkpoint/final-main
git checkout --quiet _uret/develop
tarih "2026-11-06T15:20:00+03:00"; birlestir _uret/release-110 "Merge branch 'release/1.1.0' into 'develop'"
isaretle checkpoint/final

git checkout --quiet main
for b in $(git for-each-ref --format='%(refname:short)' 'refs/heads/_uret/*'); do
  git branch --quiet -D "$b"
done

echo "checkpoint ve lab branch'leri:"
git for-each-ref --format='  %(refname:short)  %(objectname:short)  %(subject)' 'refs/heads/checkpoint/*' 'refs/heads/lab/*'
