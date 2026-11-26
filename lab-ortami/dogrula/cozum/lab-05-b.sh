# LAB 05-B cozumu: final, uctan uca teslimat. Adimlar ogrenci rehberiyle aynidir.
# Arayuz adimlari (credential, tag kesfi, webhook, issue, MR'lar) cozum.sh icinden yapilir.
adim="${ADIM:?ADIM gerekli}"
cd "$REPO"
VM="$TEST_VM_USER@$TEST_VM"
VM_DIZIN="/opt/saha/ekip$EKIP"
vm() { printf '$ vm "%s"\n' "$1"; ssh -n "$VM" "cd $VM_DIZIN && export DOCKER_CONFIG=$VM_DIZIN/.docker && $1"; }
# talep <miktar>: POST /api/orders yaniti (HTTP kodu ve govde)
talep() {
  printf '$ curl -s -w " HTTP %%{http_code}\\n" -X POST $TEST_URL/api/orders -d {"productId":"ADP-01","quantity":%s}\n' "$1"
  curl -s -w ' HTTP %{http_code}\n' -X POST "$TEST_URL/api/orders" -H 'Content-Type: application/json' \
    -d "{ \"productId\": \"ADP-01\", \"quantity\": $1 }"
}
kod_bekle() {  # kod_bekle <beklenen-http> <miktar>
  local k
  k="$(curl -s -o /dev/null -w '%{http_code}' -X POST "$TEST_URL/api/orders" -H 'Content-Type: application/json' -d "{ \"productId\": \"ADP-01\", \"quantity\": $2 }")"
  [ "$k" = "$1" ] || { printf '\033[31mHATA\033[0m  quantity=%s icin HTTP %s bekleniyordu, gelen %s\n' "$2" "$1" "$k" >&2; exit 1; }
}

case "$adim" in
anahtar)
  baslik "Adim 1a: Jenkins icin ayri bir SSH anahtari; test VM'de yetkilendir"
  rol dev
  kos ssh-keygen -q -t ed25519 -N "" -C "jenkins-ekip$EKIP" -f "$HOME/.ssh/jenkins-test-vm"
  kabuk "ssh-copy-id -i ~/.ssh/jenkins-test-vm.pub $VM 2>&1 | tail -n 2"
  kabuk "ssh -o IdentitiesOnly=yes -i ~/.ssh/jenkins-test-vm $VM 'hostname; ls -ld $VM_DIZIN'"
  not_ "Ozel anahtar (~/.ssh/jenkins-test-vm) Jenkins'e test-vm-ssh credential'i olarak eklenir; baska yere kopyalanmaz"
  ;;

deploy)
  baslik "Adim 1b: Deploy, smoke test ve SemVer stage'leri; deploy/deploy.sh"
  rol dev
  kos git switch develop
  kos git pull --ff-only
  kos git switch -c feature/deploy
  cozumden final~2 Jenkinsfile deploy/deploy.sh
  ci_kisisellestir Jenkinsfile
  kabuk "grep -n -E \"stage\\(|when|sshagent|deploy.sh|curl|TAG_NAME|manifest inspect|docker (tag|push)|disableConcurrentBuilds|TEST_URL|WEB_PORT  \" Jenkinsfile"
  kabuk "ls -l deploy/ | cut -c1-10,40-"
  kos git add Jenkinsfile deploy/deploy.sh
  kos git commit -q -m "ci: deploy to the test VM and run a smoke test"
  kos git push -q -u origin feature/deploy
  kabuk "git log --oneline -n 1"
  ;;

deploy-sonuc)
  rol dev
  kos git switch develop
  kos git pull --ff-only
  kos git fetch --prune
  kos git branch -D feature/deploy
  baslik "Test VM: Jenkins'in yaptigi ilk deploy"
  vm "cat .env; tail -n 1 deploy-kayit.log"
  kabuk "curl -fsS \$TEST_URL/api/products | head -c 60; echo"
  ;;

kirmizi)
  baslik "Adim 2-3: feature/12-miktar-dogrulama; once kirmizi test"
  rol dev
  kos git switch develop
  kos git pull --ff-only
  kos git switch -c feature/12-miktar-dogrulama
  cozumden final~1 tests/order-service.tests/OrdersApiTests.cs
  kabuk "git diff --stat"
  beklenen_hata "Failed!" dotnet test tests/order-service.tests --nologo -v q
  ;;

yesil)
  baslik "Adim 3: dogrulama; testler yesil"
  rol dev
  kos git switch feature/12-miktar-dogrulama
  cozumden final~1 src/order-service/Endpoints/OrderEndpoints.cs
  kabuk "git diff HEAD -- src/order-service | grep -E '^\\+' | grep -v '^+++'"
  kabuk "dotnet test tests/order-service.tests --nologo -v q 2>&1 | grep -E 'Passed!|Failed!'"
  kabuk "cd src/web-ui && npx jest src/api.test.js 2>&1 | grep -E 'Tests:|failed'"
  kos git add src/order-service tests/order-service.tests
  kos git commit -q -m "fix(order): reject quantities below one"
  kos git push -q -u origin feature/12-miktar-dogrulama
  ;;

miktar-sonuc)
  baslik "Adim 5: develop'a merge; test VM'e otomatik deploy"
  rol dev
  kos git switch develop
  kos git pull --ff-only
  kos git fetch --prune
  kos git branch -D feature/12-miktar-dogrulama
  vm "cat .env; tail -n 1 deploy-kayit.log"
  talep 0
  talep 2
  kod_bekle 400 0
  kod_bekle 201 2
  ;;

release)
  baslik "Adim 6: release/1.1.0; CHANGELOG"
  rol dev
  kos git switch develop
  kos git pull --ff-only
  kos git switch -c release/1.1.0
  cozumden final CHANGELOG.md
  kabuk "git diff HEAD | grep -E '^\\+' | grep -v '^+++'"
  kos git commit -q -am "chore(release): 1.1.0"
  kos git push -q -u origin release/1.1.0
  ;;

tag)
  baslik "Adim 6: v1.1.0 tag'i (lider; korumali tag)"
  rol lead
  kos git fetch -q origin
  kabuk "git log --oneline -n 1 origin/main"
  kos git tag -a v1.1.0 -m "release: v1.1.0" origin/main
  kos git push -q origin v1.1.0
  kabuk "git show -s --format='%h %s' v1.1.0^{commit}"
  ;;

smoke)
  baslik "Adim 7: v1.1.0 test ortaminda; smoke test ve kayit"
  vm "cat .env; docker compose -p ekip$EKIP images"
  vm "tail -n 2 deploy-kayit.log"
  talep 0
  talep 2
  kod_bekle 400 0
  kod_bekle 201 2
  kabuk "curl -fsS -o /dev/null -w 'GET /api/orders/summary HTTP %{http_code}\\n' \$TEST_URL/api/orders/summary"
  baslik "Ayni imaj, iki etiket: SemVer ve commit SHA ayni digest"
  sha="$(git rev-parse --short "v1.1.0^{commit}")"
  for s in order-service product-service web-ui; do
    kabuk "docker buildx imagetools inspect \$IMG/$s:1.1.0 --format '{{json .Manifest.Digest}}' | tr -d '\"' | sed 's/^/$s:1.1.0   /'; echo; docker buildx imagetools inspect \$IMG/$s:$sha --format '{{json .Manifest.Digest}}' | tr -d '\"' | sed 's/^/$s:$sha /'; echo"
    [ "$(docker buildx imagetools inspect "$IMG/$s:1.1.0" --format '{{json .Manifest.Digest}}')" = "$(docker buildx imagetools inspect "$IMG/$s:$sha" --format '{{json .Manifest.Digest}}')" ] \
      || { echo "HATA: $s 1.1.0 ve $sha farkli digest" >&2; exit 1; }
  done
  ;;

rollback)
  baslik "Adim 8: rollback provasi: 1.0.1'e don"
  vm "docker compose -p ekip$EKIP images | grep -E 'IMAGE|order-service'"
  not_ "Hedef etiket registry'de mi? (deploy.sh once pull eder; yoksa calisan surume dokunmaz)"
  kabuk "docker buildx imagetools inspect \$IMG/order-service:1.0.1 --format '{{json .Manifest.Digest}}'"
  vm "sh deploy.sh $IMG 1.0.1 $WEB_PORT - elle"
  vm "docker compose -p ekip$EKIP images | grep -E 'IMAGE|order-service'"
  kabuk "curl -fsS \$TEST_URL/api/products | head -c 40; echo"
  kabuk "curl -s -o /dev/null -w 'GET /api/orders/summary HTTP %{http_code} (1.0.1 bu uc noktayi bilmez)\\n' \$TEST_URL/api/orders/summary"
  [ "$(curl -s -o /dev/null -w '%{http_code}' "$TEST_URL/api/orders/summary")" = "404" ] || { echo "HATA: 1.0.1 calismiyor gibi" >&2; exit 1; }
  ;;

ileri)
  baslik "Adim 8: yeniden 1.1.0 (Jenkins'te v1.1.0 job'i yeniden calisti)"
  vm "docker compose -p ekip$EKIP images | grep -E 'IMAGE|order-service'"
  vm "tail -n 3 deploy-kayit.log"
  kabuk "curl -s -o /dev/null -w 'GET /api/orders/summary HTTP %{http_code}\\n' \$TEST_URL/api/orders/summary"
  kod_bekle 400 0
  ;;

sonuc)
  baslik "Son durum"
  rol dev
  kos git switch develop
  kos git pull --ff-only
  kos git fetch --prune --tags
  git branch -D release/1.1.0 >/dev/null 2>&1 || true
  kabuk "git log --oneline --graph -n 10 origin/develop"
  kabuk "git log --oneline --graph -n 4 origin/main"
  baslik "Checkpoint karsilastirmasi"
  agac_ayni origin/develop final .gitlab/CODEOWNERS Jenkinsfile ci/analyze.sh \
    src/common-contracts/common-contracts.csproj src/order-service/order-service.csproj src/product-service/product-service.csproj
  kisisel_ayni origin/develop final Jenkinsfile ci/analyze.sh \
    src/common-contracts/common-contracts.csproj src/order-service/order-service.csproj src/product-service/product-service.csproj
  agac_ayni origin/main final-main .gitlab/CODEOWNERS Jenkinsfile ci/analyze.sh \
    src/common-contracts/common-contracts.csproj src/order-service/order-service.csproj src/product-service/product-service.csproj
  ;;
*) echo "bilinmeyen adim: $adim" >&2; exit 2 ;;
esac
