# LAB 04-B cozumu: SonarQube, Quality Gate, imaj (SonarQube Community Build akisi).
# Arayuz adimlari (SonarQube projesi ve token, credential'lar, MR'lar) cozum.sh icinden yapilir.
adim="${ADIM:?ADIM gerekli}"
cd "$REPO"

case "$adim" in
sonar)
  baslik "Adim 2-3: ci/analyze.sh (begin -> build -> test -> end), Quality Gate ve imaj stage'leri"
  rol dev
  kos git switch develop
  kos git pull --ff-only
  kos git switch -c feature/sonar
  cozumden lab-04b~2 Jenkinsfile ci/analyze.sh
  ci_kisisellestir Jenkinsfile ci/analyze.sh
  kabuk "grep -n -E 'sonarscanner|dotnet (build|test)' ci/analyze.sh"
  kabuk "grep -n -E \"SONAR_PROJECT_KEY|stage\\(|when|withSonarQubeEnv|waitForQualityGate|docker (build|push)|rev-parse\" Jenkinsfile"
  kabuk "git ls-files -s ci/analyze.sh 2>/dev/null; ls -l ci/analyze.sh | cut -c1-10"
  kos git add Jenkinsfile ci/analyze.sh
  kos git commit -q -m "ci: add SonarQube analysis, Quality Gate and image publishing"
  kabuk "git ls-files -s ci/analyze.sh | cut -c1-6"
  kos git push -q -u origin feature/sonar
  ;;

sonar-sonuc)
  rol dev
  kos git switch develop
  kos git pull --ff-only
  kos git fetch --prune
  kos git branch -D feature/sonar
  ;;

testsiz)
  baslik "Adim 4: hazir branch'teki testsiz kodu al (kendi commit'inle)"
  rol dev
  kos git switch develop
  kos git pull --ff-only
  kos git switch -c feature/siparis-ozeti
  kos git fetch -q sablon
  kos git checkout sablon/lab/04b-untested -- src/order-service
  kabuk "git status --short"
  kabuk "git diff --cached --stat | tail -n 1"
  not_ "Var olan testler geciyor; yeni kodun testi yok:"
  kabuk "dotnet test tests/order-service.tests --nologo -v q 2>&1 | tail -n 2"
  kos git commit -q -m "feat(order): add order summary endpoint"
  kos git push -q -u origin feature/siparis-ozeti
  kabuk "git log --oneline -n 1"
  ;;

testsiz-sonuc)
  rol dev
  kos git switch develop
  kos git pull --ff-only
  kos git fetch --prune
  kos git branch -D feature/siparis-ozeti
  kabuk "git log --oneline -n 1"
  ;;

testler)
  baslik "Adim 6: eksik testleri yaz"
  rol dev
  kos git switch develop
  kos git pull --ff-only
  kos git switch -c feature/siparis-ozeti-testleri
  cozumden lab-04b tests/order-service.tests/OrderSummaryTests.cs
  kabuk "grep -c -E '\\[(Fact|Theory)\\]' tests/order-service.tests/OrderSummaryTests.cs"
  kabuk "dotnet test tests/order-service.tests --nologo -v q 2>&1 | tail -n 2"
  kos git add tests/order-service.tests/OrderSummaryTests.cs
  kos git commit -q -m "test(order): cover the order summary"
  kos git push -q -u origin feature/siparis-ozeti-testleri
  ;;

sonuc)
  baslik "Adim 7: merge sonrasi"
  rol dev
  kos git switch develop
  kos git pull --ff-only
  kos git fetch --prune
  kos git branch -D feature/siparis-ozeti-testleri
  kabuk "git log --oneline --graph -n 8 origin/develop"
  kabuk "git grep -n -I -E 'sqp_|squ_|glpat-|gldt-' -- . || echo 'repoda token yok'"
  baslik "Checkpoint karsilastirmasi"
  agac_ayni origin/develop lab-04b .gitlab/CODEOWNERS Jenkinsfile ci/analyze.sh
  kisisel_ayni origin/develop lab-04b Jenkinsfile ci/analyze.sh
  ;;
*) echo "bilinmeyen adim: $adim" >&2; exit 2 ;;
esac
