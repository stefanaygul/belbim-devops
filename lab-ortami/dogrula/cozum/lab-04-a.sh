# LAB 04-A cozumu: GitLab baglantisi ve ilk pipeline. Adimlar ogrenci rehberiyle aynidir.
# Arayuz adimlari (token, credential, job, webhook, MR) cozum.sh icinden tarayicida yapilir.
adim="${ADIM:?ADIM gerekli}"
cd "$REPO"
TEST_DOSYASI=tests/order-service.tests/OrdersApiTests.cs

case "$adim" in
baslangic)
  baslik "Baslangic: develop guncel, repoda .gitlab-ci.yml yok, Jenkinsfile iskelet"
  rol dev
  kos git switch develop
  kos git pull --ff-only
  kabuk "git ls-files | grep -c -x '.gitlab-ci.yml' || true"
  kabuk "grep -c -E '^\s*(pipeline|stage)' Jenkinsfile || true"
  kabuk "echo \$JENKINS_URL/job/ekip-\$EKIP/"
  ;;

jenkinsfile)
  baslik "Adim 4: Jenkinsfile - Restore, Build, Unit Test, web-ui"
  rol dev
  kos git switch develop
  kos git pull --ff-only
  kos git switch -c feature/pipeline
  cozumden lab-04a Jenkinsfile
  ci_kisisellestir Jenkinsfile
  kabuk "grep -n -E \"agent|gitLabConnection|gitlabBuilds|stage\\(|junit|updateGitlabCommitStatus\" Jenkinsfile"
  kos git add Jenkinsfile
  kos git commit -q -m "ci: add Jenkins pipeline"
  kos git push -q -u origin feature/pipeline
  kabuk "git log --oneline -n 1"
  ;;

boz)
  baslik "Adim 6: bir testi boz (bos ekipman kodu icin 400 yerine 200 bekle)"
  rol dev
  kos git switch feature/pipeline
  kos sed -i 's/Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);/Assert.Equal(HttpStatusCode.OK, response.StatusCode);/' "$TEST_DOSYASI"
  kabuk "git diff --stat"
  not_ "Lokalde de kirmizi:"
  beklenen_hata "Failed!" dotnet test tests/order-service.tests --nologo -v q
  kos git commit -q -am "test(order): expect 200 for an empty product id"
  kos git push -q
  kabuk "git log --oneline -n 1"
  ;;

duzelt)
  baslik "Adim 7: duzelt (bozan commit'i geri al) ve push et"
  rol dev
  kos git switch feature/pipeline
  kos git revert --no-edit HEAD
  kabuk "dotnet test tests/order-service.tests --nologo -v q 2>&1 | tail -n 3"
  kos git push -q
  kabuk "git log --oneline -n 3"
  ;;

sonuc)
  baslik "Adim 7: merge sonrasi"
  rol dev
  kos git switch develop
  kos git pull --ff-only
  kos git fetch --prune
  kos git branch -D feature/pipeline
  kabuk "git log --oneline --graph -n 4 origin/develop"
  kabuk "git ls-files | grep -c -x '.gitlab-ci.yml' || true"
  baslik "Checkpoint karsilastirmasi"
  agac_ayni origin/develop lab-04a .gitlab/CODEOWNERS Jenkinsfile
  kisisel_ayni origin/develop lab-04a Jenkinsfile
  ;;
*) echo "bilinmeyen adim: $adim" >&2; exit 2 ;;
esac
