#!/usr/bin/env bash
# Bir labin cozumunu bir ekip icin uygular. Host'ta calisir (bash 3.2 uyumlu).
# Komut satiri adimlari katilimci makinesinde (workstation) ekip kullanicisiyla,
# arayuz adimlari gercek tarayicida (tarayici servisi, Playwright) yapilir.
# Adimlar ogrenci rehberindeki sirayla aynidir. Ilk basarisiz adimda durur.
#
# Kullanim: dogrula/cozum.sh <lab> <ekip>             ornek: dogrula/cozum.sh 01-a 01
#           dogrula/cozum.sh <lab> <ekip> ws <adim>   tek bir komut satiri adimi
#           dogrula/cozum.sh <lab> <ekip> ui <betik> <adim> [...]   tek bir arayuz adimi
set -euo pipefail
cd "$(dirname "$0")/.."

lab="${1:?kullanim: dogrula/cozum.sh <lab> <ekip>}"
nn="$(printf '%02d' "$((10#${2:?ekip numarasi gerekli}))")"
shift 2

# Tarayici araci. LAB_IMG_DIR verilirse ekran goruntuleri oraya yazilir (container icindeki yol;
# ornegin /lab/cikti/prova -> lab-ortami/.cache/ui/prova). Verilmezse lab-rehberleri/img.
TARAYICI="docker compose --profile cekirdek run --rm -T"
[ -z "${LAB_IMG_DIR:-}" ] || TARAYICI="$TARAYICI -e LAB_IMG_DIR=$LAB_IMG_DIR"

# ws <adim> [ORTAM=deger ...]: cozum/lab-<lab>.sh icindeki adimi workstation'da calistirir.
# Gizli degerler GIZLI_ORTAM degiskeniyle (satir satir AD=deger) standart giristen aktarilir.
ws() {
  local adim="$1" atama
  shift
  {
    printf 'export ADIM=%s\n' "$adim"
    for atama in "$@"; do printf 'export %s\n' "$atama"; done
    [ -z "${GIZLI_ORTAM:-}" ] || printf '%s\n' "$GIZLI_ORTAM" | sed 's/^/export /'
    printf 'ana() {\n'
    cat dogrula/cozum/ortak.sh "dogrula/cozum/lab-${lab}.sh"
    printf '\n}\nana\n'
  } | docker compose exec -T -u "ekip${nn}" workstation bash -l -s
}

# ui <betik> <adim> [arguman ...]: dogrula/ui/<betik>.cjs icindeki adimi tarayicida yapar.
ui() {
  local betik="$1"
  shift
  printf '\n\033[1m### Arayuz: %s %s\033[0m\n' "$betik" "$*"
  $TARAYICI tarayici node "${betik}.cjs" "$@" < /dev/null
}

lab_01_a() {
  ws kur
  ws catisma
  ws baslat
  ui uygulama talep http://localhost:5173 "lab-01-a-arayuz" ADP-01 2
  ws durdur
}

lab_01_b() {
  ws feature
  ws conflict
}

# gl <adim> [arguman ...]: GitLab arayuz adimi (dogrula/ui/gitlab.cjs)
gl() { ui gitlab "$@"; }
# gl_aciklama <aciklama> <gitlab.cjs argumanlari...>: MR aciklamasi ortam degiskeniyle verilir
gl_aciklama() {
  local aciklama="$1"
  shift
  printf '\n\033[1m### Arayuz: gitlab %s\033[0m\n' "$*"
  $TARAYICI -e "ACIKLAMA=$aciklama" tarayici node gitlab.cjs "$@" < /dev/null
}
# merge_reddi <rol> <kaynak-branch>: o hesabin MR'i API ile de merge edemedigini gosterir
merge_reddi() {
  printf '\n\033[1m### API: %s merge etmeyi deniyor (reddedilmeli)\033[0m\n' "ekip${nn}-$1"
  docker compose run --rm -T araclar bash dogrula/api-merge-dene.sh "$nn" "$1" "$2" < /dev/null
}
# ws_cikti <adim> [ORTAM=deger]: adimin ciktisini dondurur (baslik yazmadan)
ws_cikti() { ws "$@" | sed 's/\x1b\[[0-9;]*m//g' | grep -v '^rol: '; }

lab_02_a_onkosul() {
  local a
  for r in lead dev; do
    a="$(ws_cikti anahtar-goster "ROL=$r")"
    printf '\n\033[1m### Arayuz: gitlab ssh-anahtari %s %s\033[0m\n' "$nn" "$r"
    $TARAYICI -e "ANAHTAR=$a" tarayici node gitlab.cjs ssh-anahtari "$nn" "$r" < /dev/null
  done
  ws ssh-sina
}

lab_02_a() {
  lab_02_a_onkosul
  # Adim 1: lokal repoyu ekip projesine push et
  ws hazirla
  gl proje-olustur "$nn"
  ws push
  # Adim 2: develop, varsayilan branch, koruma
  ws develop
  gl varsayilan-branch "$nn" develop
  gl branch-koru "$nn" main develop
  gl mr-ayarlari "$nn"
  ws push-reddi
  # Adim 3-4: issue, feature branch, degisiklik
  gl issue-ac "$nn" dev "Katalogda stok durumu" "Saha personeli bir ekipmanın stokta olup olmadığını katalogda görebilmeli. Kabul kriteri: GET /api/products yanıtında her ekipman için inStock alanı bulunur." lab-02-a-issue
  ws feature
  # Adim 5: MR
  gl_aciklama "Katalogdaki her ekipmana stok durumu (inStock) alanı eklendi; saha personeli stokta olmayan ekipmanı talep etmeden önce görebilsin.|dotnet test: katalog dosyasındaki her kayıtta inStock alanı olduğunu denetleyen test eklendi." \
    mr-ac "$nn" dev feature/3-stok-durumu develop "feat(catalog): add stock status" 1 evet evet lab-02-a-mr
  # Adim 6: inceleme, duzeltme, thread
  gl mr-yorum "$nn" lead feature/3-stok-durumu ProductDto.cs "API testi bu alanı doğrulamıyor. ProductsApiTests içinde inStock değerini ve stokta olmayan bir ekipmanı da denetleyelim mi?" lab-02-a-inceleme
  gl mr-engel "$nn" lead feature/3-stok-durumu "Open threads must be resolved" lab-02-a-merge-engeli
  ws duzeltme
  gl mr-thread-coz "$nn" dev feature/3-stok-durumu lab-02-a-thread-cozuldu
  # Adim 7: merge (yalnizca Maintainer)
  gl mr-engel "$nn" dev feature/3-stok-durumu "Ready to merge by members who can write to the target branch" lab-02-a-developer-merge-edemez
  merge_reddi dev feature/3-stok-durumu
  gl mr-merge "$nn" lead feature/3-stok-durumu lab-02-a-merge
  gl sayfa "$nn" dev /-/issues/1 "Katalogda stok durumu|Closed" lab-02-a-issue-kapandi
  ws sonuc
  lab_02_a_rol_degisimi
}

# Rol degisimi (egitmen betigi) ve ikinci kucuk MR: yazar ekipNN-lead, merge eden ekipNN-dev
lab_02_a_rol_degisimi() {
  printf '\n\033[1m### Egitmen: bootstrap/rol-degistir.sh %s\033[0m\n' "$nn"
  bash bootstrap/rol-degistir.sh "$nn"
  ws arayuz
  gl_aciklama "Katalog tablosuna Stok sütunu eklendi: Stokta / Stokta yok. İlgili: #1|npm test: CatalogList bileşeni için stok durumu testi eklendi." \
    mr-ac "$nn" lead feature/3-stok-durumu-arayuz develop "feat(web-ui): show stock status" - evet evet lab-02-a-mr2
  gl mr-engel "$nn" lead feature/3-stok-durumu-arayuz "Ready to merge by members who can write to the target branch" lab-02-a-rol-degisimi-lead-merge-edemez
  gl mr-onayla "$nn" dev feature/3-stok-durumu-arayuz lab-02-a-mr2-onay
  gl mr-merge "$nn" dev feature/3-stok-durumu-arayuz lab-02-a-mr2-merge
  printf '\n\033[1m### Egitmen: bootstrap/rol-degistir.sh %s asil\033[0m\n' "$nn"
  bash bootstrap/rol-degistir.sh "$nn" asil
  ws arayuz-sonuc
}

lab_02_b() {
  # Adim 1-2: release/1.0.0, CHANGELOG, MR ile main (squash yok, kaynak branch silinmez)
  ws release
  gl_aciklama "1.0.0 sürümü hazırlandı: CHANGELOG güncellendi.|Kod değişikliği yok; develop üzerindeki testler yeşil." \
    mr-ac "$nn" dev release/1.0.0 main "chore(release): 1.0.0" - hayir hayir lab-02-b-mr-release
  gl mr-merge "$nn" lead release/1.0.0 lab-02-b-release-merge main
  # Adim 3: v* korumali tag, v1.0.0
  gl tag-koru "$nn" 'v*'
  ws tag-reddi ETIKET=v1.0.0
  ws tag ETIKET=v1.0.0
  # Adim 4: release geri develop'a
  gl_aciklama "release/1.0.0 üzerindeki CHANGELOG değişikliği develop'a geri alındı.|Kod değişikliği yok." \
    mr-ac "$nn" dev release/1.0.0 develop "chore(release): merge 1.0.0 back into develop" - hayir evet lab-02-b-mr-release-geri
  gl mr-merge "$nn" lead release/1.0.0 lab-02-b-release-geri-merge develop
  # Adim 5: hotfix/1.0.1
  gl issue-ac "$nn" dev "Boş ekipman koduyla talep açılabiliyor" "v1.0.0'da ekipman seçilmeden gönderilen talep kaydediliyor. Beklenen: POST /api/orders boş productId için 400 dönmeli." lab-02-b-issue
  ws hotfix
  # Adim 6: MR ile main, v1.0.1
  gl_aciklama "Boş ekipman koduyla gelen talep artık 400 ile reddediliyor.|dotnet test: boş ve yalnızca boşluk içeren ekipman kodu için iki test eklendi; düzeltmeden önce kırmızı, sonra yeşil." \
    mr-ac "$nn" dev hotfix/1.0.1 main "fix(order): reject empty product id" 2 hayir hayir lab-02-b-mr-hotfix
  gl mr-merge "$nn" lead hotfix/1.0.1 lab-02-b-hotfix-merge main
  ws tag ETIKET=v1.0.1
  # Adim 7: hotfix develop'a da
  gl_aciklama "v1.0.1 düzeltmesi develop'a da alındı; yoksa bir sonraki sürümde hata geri gelir.|dotnet test yeşil." \
    mr-ac "$nn" dev hotfix/1.0.1 develop "fix(order): merge hotfix 1.0.1 into develop" 2 hayir evet lab-02-b-mr-hotfix-geri
  gl mr-merge "$nn" lead hotfix/1.0.1 lab-02-b-hotfix-geri-merge develop
  gl sayfa "$nn" dev /-/tags "v1.0.0|v1.0.1" lab-02-b-tags
  gl sayfa "$nn" dev "/-/merge_requests?scope=all&state=merged" "fix(order): reject empty product id|chore(release): 1.0.0" lab-02-b-mr-gecmisi
  gl sayfa "$nn" dev /-/issues/2 "Closed" lab-02-b-issue-kapandi
  ws grafik
}

lab_03_a() {
  gl issue-ac "$nn" dev "Servisler için Docker imajları" "Üç servis container imajı olarak paketlenmeli ve test VM'de Compose ile çalışmalı. Kabul kriteri: imajlar root olmayan kullanıcıyla çalışır; uygulama registry'den çekilen imajlarla ikinci VM'de açılır." lab-03-a-issue
  ws feature
  ws order
  ws product
  ws web-ui
  ws dockerignore
  ws build
  ws calistir
  ws kapat
}

# gizli <DEGISKEN> <token-dosyasi-adi> <ws-adimi> [ORTAM=deger ...]: arayuzde uretilen token'i
# (.cache/ui/token-<ad>) workstation adimina standart giristen aktarir.
gizli() {
  local degisken="$1" dosya=".cache/ui/token-$2"
  shift 2
  [ -s "$dosya" ] || { echo "token dosyasi yok: $dosya" >&2; return 1; }
  GIZLI_ORTAM="${degisken}=$(cat "$dosya")" ws "$@"
}

lab_03_b() {
  local url port yerel
  if [ "$nn" = "99" ]; then port=8099; else port=$((8080 + 10#$nn)); fi
  url="http://test-vm.$(sed -n 's/^LAB_DOMAIN=//p' .env):${port}"
  yerel="http://localhost:${port}"
  # Adim 1: etiketle
  ws etiketle
  # Adim 2: deploy token, login (x509 -> CA), push
  gl deploy-token "$nn" "ekip${nn}-deploy" read_registry,write_registry lab-03-b-deploy-token
  if [ "${PROVA_PAYLASILAN:-0}" = "1" ] && docker compose exec -T workstation test -s "/etc/docker/certs.d/gitlab.$(sed -n 's/^LAB_DOMAIN=//p' .env):5050/ca.crt"; then
    echo 'ATLANDI: Docker x509 olumsuz adimi; paylasilan daemon CAya zaten guveniyor. Temiz kurulum kaniti degildir.'
  else
    gizli DEPLOY_TOKEN "ekip${nn}-deploy" login-x509
  fi
  ws ca
  ws push-denied
  gizli DEPLOY_TOKEN "ekip${nn}-deploy" push
  # Adim 3: Container Registry sayfasi
  gl registry "$nn" lab-03-b-registry 1.0.1
  # Adim 4-5: compose, nginx; lokalde calistir (SQLite Error 14 -> duzelt)
  ws compose
  ws yerel-hata
  ui uygulama katalog "$yerel" lab-03-b-yerel-hata "Veriler yüklenemedi"
  ws yerel-duzelt
  ui uygulama talep "$yerel" lab-03-b-yerel ADP-01 2
  ws yerel-kalicilik
  gizli DEPLOY_TOKEN "ekip${nn}-deploy" push
  # Adim 6: ikinci VM
  ws vm-hazirla
  ws vm-denied
  gl deploy-token "$nn" "ekip${nn}-pull" read_registry lab-03-b-pull-token
  gizli PULL_TOKEN "ekip${nn}-pull" vm-calistir
  GIZLI_ORTAM="PULL_TOKEN=$(cat ".cache/ui/token-ekip${nn}-pull")
DEPLOY_TOKEN=$(cat ".cache/ui/token-ekip${nn}-deploy")" ws push-salt-okunur
  # Adim 7: smoke test, MR
  ws smoke
  ui uygulama talep "$url" lab-03-b-test-vm STD-03 1
  gl_aciklama "Üç servis için multi-stage Dockerfile, .dockerignore, compose.yaml ve Nginx reverse proxy eklendi. order-service /data dizinine root olmayan kullanıcıyla yazabiliyor.|Lokalde ve test VM'de docker compose up; curl ile /api/products ve /api/orders; container yeniden yaratılınca talep kaydı duruyor." \
    mr-ac "$nn" dev feature/9-docker develop "build(docker): add Dockerfiles and compose deployment" 3 evet evet lab-03-b-mr
  gl mr-merge "$nn" lead feature/9-docker lab-03-b-merge develop
  ws sonuc
  rm -f ".cache/ui/token-ekip${nn}-deploy" ".cache/ui/token-ekip${nn}-pull"
}

# ci <komut> [arguman ...]: CI zincirinin durumunu API'lerden okur ve bekleneni denetler
# (dogrula/ci-durum.sh; Jenkins, GitLab, SonarQube). Ekip numarasi kendiliginden eklenir.
ci() {
  local k="$1"
  shift
  printf '\n\033[1m### CI durumu: %s %s\033[0m\n' "$k" "$*"
  if [ "$k" = "agent" ]; then
    docker compose run --rm -T araclar bash dogrula/ci-durum.sh agent "$@" < /dev/null
  else
    docker compose run --rm -T araclar bash dogrula/ci-durum.sh "$k" "$nn" "$@" < /dev/null
  fi
}
jku() { ui jenkins "$@"; }
squ() { ui sonar "$@"; }

lab_04_a() {
  local hook
  hook="https://jenkins.$(sed -n 's/^LAB_DOMAIN=//p' .env)/project/ekip-${nn}/saha-portal-ekip${nn}"
  ws baslangic
  # Adim 1: Project Access Token (api, Maintainer)
  gl access-token "$nn" jenkins Maintainer api "ekip${nn}-pat" lab-04-a-access-token
  # Adim 2: klasor credential'lari ve Multibranch job
  jku credential "$nn" gitlab-api gitlab-api "ekip${nn}-pat" - "GitLab Project Access Token (commit status)" lab-04-a-credential-gitlab-api
  jku credential "$nn" gitlab-repo userpass "ekip${nn}-pat" jenkins "GitLab Project Access Token (repo okuma)" lab-04-a-credential-gitlab-repo
  jku credentials "$nn" gitlab-api,gitlab-repo lab-04-a-credentials
  jku multibranch "$nn" lab-04-a-multibranch
  # Adim 3: webhook, Test > Push events
  gl webhook "$nn" "$hook" lab-04-a-webhook
  # Adim 4: Jenkinsfile
  gl issue-ac "$nn" dev "Her push'ta build ve test: Jenkins pipeline" "Her push'ta Jenkins build ve testleri çalıştırmalı; sonuç MR'da görünmeli. Kabul kriteri: kırılan test merge'ü engeller." lab-04-a-issue
  ws jenkinsfile
  ci hook
  ci build feature/pipeline SUCCESS 'Checking out Revision|^\[Pipeline\] \{ \(|Passed!|Finished:'
  jku sayfa "$nn" "/job/feature%252Fpipeline/lastBuild/" "" lab-04-a-build
  jku sayfa "$nn" "/job/feature%252Fpipeline/lastBuild/testReport/" "" lab-04-a-test-sonuclari
  # Adim 5: MR, pipeline durumu MR ekraninda
  gl_aciklama "Jenkinsfile eklendi: Restore, Build, Unit Test ve web-ui stage'leri; sonuç GitLab'e jenkins adlı commit status olarak yazılıyor.|Jenkins'te feature/pipeline build'i yeşil; test sonuçları Jenkins'te görünüyor." \
    mr-ac "$nn" dev feature/pipeline develop "ci: add Jenkins pipeline" 4 evet evet lab-04-a-mr
  gl mr-durum "$nn" dev feature/pipeline "Pipeline #\\d+ passed" lab-04-a-mr-pipeline-yesil
  # Adim 6: Pipelines must succeed; bir testi boz
  gl pipeline-zorunlu "$nn" lab-04-a-pipelines-must-succeed
  ws boz
  ci build feature/pipeline FAILURE 'Failed |Failed!|ERROR:|Finished:'
  # Adim 7: merge engellendi
  ci mr feature/pipeline ci_must_pass
  gl mr-durum "$nn" lead feature/pipeline "Pipeline #\\d+ failed" lab-04-a-mr-pipeline-kirmizi
  gl mr-engel "$nn" lead feature/pipeline "Pipeline must succeed" lab-04-a-merge-engeli
  merge_reddi lead feature/pipeline
  jku sayfa "$nn" "/job/feature%252Fpipeline/lastBuild/testReport/" "" lab-04-a-test-kirmizi
  if [ "${KUYRUK:-0}" = "1" ]; then
    # Kanit adimi (ogrenci akisinda yok; yalnizca KUYRUK=1 ile): ortak agent birkac saniye devre
    # disi birakilir; is kuyrukta kalir, yeni commit icin henuz durum yoktur; merge kapali kalmalidir.
    # Baska ekiplerin build'lerini de bekletir: ders sirasinda kullanmayin.
    ci agent offline
    ws duzelt
    perl -e 'select(undef,undef,undef,8)'
    ci kuyruk
    ci mr feature/pipeline ci_must_pass,ci_still_running
    merge_reddi lead feature/pipeline
    ci agent online
    ci mr feature/pipeline ci_still_running
    merge_reddi lead feature/pipeline
  else
    ws duzelt
  fi
  ci build feature/pipeline SUCCESS 'Passed!|Finished:'
  ci mr feature/pipeline mergeable
  gl mr-merge "$nn" lead feature/pipeline lab-04-a-merge develop
  ci build develop SUCCESS 'Finished:'
  ci hook
  gl sayfa "$nn" dev /-/issues/4 "Closed" lab-04-a-issue-kapandi
  ws sonuc
  rm -f ".cache/ui/token-ekip${nn}-pat"
}

lab_04_b() {
  # Adim 1: SonarQube projesi ve token; Jenkins credential'lari
  squ proje "$nn" lab-04-b-sonar-proje
  squ token "$nn" "jenkins-saha-portal-ekip${nn}" lab-04-b-sonar-token
  gl deploy-token "$nn" "ekip${nn}-jenkins" read_registry,write_registry lab-04-b-deploy-token
  jku credential "$nn" sonar-token secret "ekip${nn}-sonar" - "SonarQube analiz token" lab-04-b-credential-sonar-token
  jku credential "$nn" gitlab-registry userpass "ekip${nn}-jenkins" "ekip${nn}-jenkins" "Registry deploy token (Jenkins)" lab-04-b-credential-gitlab-registry
  jku credentials "$nn" gitlab-api,gitlab-repo,sonar-token,gitlab-registry lab-04-b-credentials
  # Adim 2-3: analyze.sh, Quality Gate, imaj; ilk yesil analiz = taban cizgisi
  gl issue-ac "$nn" dev "SonarQube analizi ve Quality Gate" "develop'a giren her değişiklik SonarQube ile analiz edilmeli; Quality Gate kalırsa imaj üretilmemeli." lab-04-b-issue
  ws sonar
  ci build feature/sonar SUCCESS 'skipped due to when|^\[Pipeline\] \{ \(|Finished:'
  gl_aciklama "ci/analyze.sh (begin → build → test → end), Quality Gate ve Docker Build & Push stage'leri eklendi. Analiz ve kapı yalnızca develop build'inde çalışır (SonarQube Community Build).|feature/sonar build'i yeşil: Build ve Unit Test çalıştı, analiz stage'leri atlandı." \
    mr-ac "$nn" dev feature/sonar develop "ci: add SonarQube analysis, Quality Gate and image publishing" 5 evet evet lab-04-b-mr-sonar
  ci mr feature/sonar mergeable
  gl mr-merge "$nn" lead feature/sonar lab-04-b-merge-sonar develop
  ci build develop SUCCESS 'ANALYSIS SUCCESSFUL|SonarQube task|Quality gate|digest: |Finished:'
  ci sonar OK
  ci imaj var
  squ sayfa "$nn" /dashboard "Passed" lab-04-b-sonar-taban
  ws sonar-sonuc
  # Adim 4-5: testsiz kod; kapi develop'ta kalir, imaj uretilmez
  ws testsiz
  ci build feature/siparis-ozeti SUCCESS 'skipped due to when|Passed!|Finished:'
  gl_aciklama "Talep özeti uç noktası eklendi (hazır kod: lab/04b-untested).|Var olan testler yeşil; yeni kod için test yok." \
    mr-ac "$nn" dev feature/siparis-ozeti develop "feat(order): add order summary endpoint" - evet evet lab-04-b-mr-testsiz
  ci mr feature/siparis-ozeti mergeable
  gl mr-merge "$nn" lead feature/siparis-ozeti lab-04-b-merge-testsiz develop
  ci build develop FAILURE 'SonarQube task|Quality gate|quality gate|skipped due to earlier|Finished:'
  ci sonar ERROR
  ci imaj yok
  jku sayfa "$nn" "/job/develop/lastBuild/console" "Pipeline aborted due to quality gate failure: ERROR" lab-04-b-jenkins-kapi-kaldi
  squ sayfa "$nn" /dashboard "Failed" lab-04-b-sonar-kapi-kaldi
  ws testsiz-sonuc
  # Adim 6-7: testler; kapi yesil, imaj registry'de
  ws testler
  ci build feature/siparis-ozeti-testleri SUCCESS 'Passed!|Finished:'
  gl_aciklama "Talep özeti hesaplaması ve uç noktası için testler eklendi; Quality Gate yeni kod coverage koşulunda kalmıştı.|dotnet test yeşil; yeni kodun coverage'ı SonarQube'da develop analizinde görülecek." \
    mr-ac "$nn" dev feature/siparis-ozeti-testleri develop "test(order): cover the order summary" - evet evet lab-04-b-mr-testler
  ci mr feature/siparis-ozeti-testleri mergeable
  gl mr-merge "$nn" lead feature/siparis-ozeti-testleri lab-04-b-merge-testler develop
  ci build develop SUCCESS 'SonarQube task|Quality gate|digest: |Finished:'
  ci sonar OK
  ci imaj var
  squ sayfa "$nn" /dashboard "Passed" lab-04-b-sonar-yesil
  jku sayfa "$nn" "/job/develop/" "" lab-04-b-jenkins-develop
  gl registry "$nn" lab-04-b-registry
  gl sayfa "$nn" dev /-/issues/5 "Closed" lab-04-b-issue-kapandi
  ws sonuc
  rm -f ".cache/ui/token-ekip${nn}-sonar" ".cache/ui/token-ekip${nn}-jenkins"
}

nxu() { ui nexus "$@"; }

lab_05_a() {
  gl issue-ac "$nn" dev "Ortak sözleşmeler Nexus'ta NuGet paketi olarak" "Servisler common-contracts'ı kaynak olarak değil, Nexus'taki sürümlü paketten almalı. Kabul kriteri: paket Nexus'ta; servisler paketten restore ediyor; aynı sürüm ikinci kez yayınlanamıyor." lab-05-a-issue
  # Adim 1-2: paket kimligi ve surumu; pack
  ws kimlik
  ws pack
  # Adim 3-4: API anahtari (arayuz), push, ayni surumu yeniden push (409)
  nxu api-anahtari "$nn" lab-05-a-api-anahtari
  gizli NEXUS_APIKEY "ekip${nn}-nexus" push
  lab_05_a_yayindan_sonra
}

# Yayin tamamlanip arayuzde durulduysa ayni paketi/issue'yu yeniden olusturmadan surdur.
lab_05_a_yayindan_sonra() {
  nxu paket "$nn" 1.0.0 lab-05-a-nexus-paket
  gizli NEXUS_APIKEY "ekip${nn}-nexus" push-tekrar
  # Adim 5-6: PackageReference; onbellek temizligi ve Nexus'tan restore
  ws referans
  ws restore
  # Adim 7: MR, pipeline
  ws gonder
  ci build feature/ortak-paket SUCCESS 'Passed!|Finished:'
  gl_aciklama "Servisler Saha.Common.Contracts.Ekip${nn} 1.0.0 paketini Nexus'tan alıyor; ProjectReference kaldırıldı, Dockerfile'lar paketi restore ediyor.|Paket Nexus'ta (nuget-hosted); aynı sürümün ikinci yayını 409 ile reddedildi; önbellek temizlenip restore Nexus'tan yapıldı; dotnet test yeşil." \
    mr-ac "$nn" dev feature/ortak-paket develop "build(contracts): consume common contracts as a NuGet package" 6 evet evet lab-05-a-mr
  ci mr feature/ortak-paket mergeable
  gl mr-merge "$nn" lead feature/ortak-paket lab-05-a-merge develop
  ci build develop SUCCESS 'Quality gate|digest: |Finished:'
  ci sonar OK
  ci imaj var
  gl sayfa "$nn" dev /-/issues/6 "Closed" lab-05-a-issue-kapandi
  ws sonuc
  rm -f ".cache/ui/token-ekip${nn}-nexus"
}

# ssh_anahtari_aktar: Jenkins'in ozel anahtari, katilimcinin Jenkins formuna yapistirdigi deger.
# Yalnizca .cache/ui/token-ekipNN-ssh dosyasina yazilir (repoya ve kanitlara girmez).
ssh_anahtari_aktar() {
  ( umask 077; docker compose exec -T -u "ekip${nn}" workstation cat "/home/ekip${nn}/.ssh/jenkins-test-vm" < /dev/null > ".cache/ui/token-ekip${nn}-ssh" )
}

lab_05_b() {
  local d url hook
  d="$(sed -n 's/^LAB_DOMAIN=//p' .env)"
  if [ "$nn" = "99" ]; then url="http://test-vm.${d}:8099"; else url="http://test-vm.${d}:$((8080 + 10#$nn))"; fi
  hook="https://jenkins.${d}/project/ekip-${nn}/saha-portal-ekip${nn}"
  # Adim 1: Jenkins'in deploy anahtari ve credential'i; Deploy, smoke test, SemVer stage'leri
  ws anahtar
  ssh_anahtari_aktar
  jku credential "$nn" test-vm-ssh ssh "ekip${nn}-ssh" deploy "Test VM deploy anahtari (Jenkins)" lab-05-b-credential-ssh
  rm -f ".cache/ui/token-ekip${nn}-ssh"
  ws deploy
  ci build feature/deploy SUCCESS 'skipped due to when|Finished:'
  gl_aciklama "Jenkinsfile'a Deploy: test, Smoke test ve tag build'i için SemVer etiketi stage'leri eklendi; deploy/deploy.sh test VM'de pull, up ve kayıt yapar.|feature/deploy build'i yeşil; yeni stage'ler feature branch'te atlanıyor." \
    mr-ac "$nn" dev feature/deploy develop "ci: deploy to the test VM and run a smoke test" - evet evet lab-05-b-mr-deploy
  ci mr feature/deploy mergeable
  gl mr-merge "$nn" lead feature/deploy lab-05-b-merge-deploy develop
  ci build develop SUCCESS 'KAYIT|smoke test:|Finished:'
  ci deploy develop
  jku sayfa "$nn" "/job/develop/lastBuild/" "test VM: TAG=" lab-05-b-jenkins-develop-deploy
  ws deploy-sonuc
  # Adim 2-3: issue, feature/12-miktar-dogrulama; once kirmizi test, sonra kod
  gl issue-ac "$nn" dev "Miktarı 1'den küçük talep açılabiliyor" "Saha personeli miktarı 0 ya da negatif olan talep oluşturabiliyor. Kabul kriteri: POST /api/orders miktar 1'den küçükse 400 döner; web-ui hata mesajını gösterir; geçerli talep kaydedilir." lab-05-b-issue
  ws kirmizi
  ws yesil
  ci build feature/12-miktar-dogrulama SUCCESS 'Passed!|Finished:'
  # Adim 4: MR, review
  gl_aciklama "POST /api/orders miktarı 1'den küçük talebi 400 ile reddediyor; mesaj web-ui'de gösteriliyor.|dotnet test: 0 ve -1 için 400, 1 ve 2 için 201 testleri; önce kırmızı, sonra yeşil." \
    mr-ac "$nn" dev feature/12-miktar-dogrulama develop "fix(order): reject quantities below one" 7 evet evet lab-05-b-mr-miktar
  ci mr feature/12-miktar-dogrulama mergeable
  gl mr-onayla "$nn" lead feature/12-miktar-dogrulama lab-05-b-mr-onay
  gl mr-merge "$nn" lead feature/12-miktar-dogrulama lab-05-b-merge-miktar develop
  # Adim 5: develop yesil, Quality Gate, test VM'e otomatik deploy
  ci build develop SUCCESS 'Quality gate|KAYIT|smoke test:|Finished:'
  ci sonar OK
  ws miktar-sonuc
  ui uygulama red "$url" lab-05-b-arayuz-red ADP-01 0 "Miktar en az 1 olmalı."
  # Adim 6: release/1.1.0 -> main; geri develop'a; tag kesfi; v1.1.0
  ws release
  gl_aciklama "1.1.0 sürümü: CHANGELOG güncellendi.|Kod değişikliği yok; develop pipeline'ı ve Quality Gate yeşil." \
    mr-ac "$nn" dev release/1.1.0 main "chore(release): 1.1.0" - hayir hayir lab-05-b-mr-release
  ci mr release/1.1.0 mergeable
  gl mr-merge "$nn" lead release/1.1.0 lab-05-b-release-merge main
  ci build main SUCCESS 'Stage "Docker Build|digest|Finished:'
  gl_aciklama "release/1.1.0 develop'a geri alındı (CHANGELOG).|Kod değişikliği yok." \
    mr-ac "$nn" dev release/1.1.0 develop "chore(release): merge 1.1.0 back into develop" - hayir evet lab-05-b-mr-release-geri
  ci mr release/1.1.0 mergeable
  gl mr-merge "$nn" lead release/1.1.0 lab-05-b-release-geri-merge develop
  ci build develop SUCCESS 'KAYIT|Finished:'
  jku tag-kesfi "$nn" lab-05-b-tag-kesfi
  gl webhook-tag "$nn" "$hook" lab-05-b-webhook-tag
  ws tag
  ci build v1.1.0 SUCCESS 'SURUM=|manifest inspect|KAYIT|smoke test:|Finished:'
  ci deploy v1.1.0
  jku sayfa "$nn" "/job/v1.1.0/lastBuild/" "TAG=1.1.0" lab-05-b-jenkins-tag
  # Adim 7: v1.1.0 test ortaminda
  ws smoke
  ui uygulama talep "$url" lab-05-b-arayuz-1-1-0 KBL-02 2
  gl registry "$nn" lab-05-b-registry 1.1.0
  # Adim 8: rollback provasi ve yeniden 1.1.0
  ws rollback
  jku build-baslat "$nn" v1.1.0 lab-05-b-yeniden-1-1-0
  ws ileri
  gl sayfa "$nn" dev /-/issues/7 "Closed" lab-05-b-issue-kapandi
  ws sonuc
}

if [ "$#" -gt 0 ]; then
  "$@"
  exit 0
fi

case "$lab" in
  01-a) lab_01_a ;;
  01-b) lab_01_b ;;
  02-a) lab_02_a ;;
  02-b) lab_02_b ;;
  03-a) lab_03_a ;;
  03-b) lab_03_b ;;
  04-a) lab_04_a ;;
  04-b) lab_04_b ;;
  05-a) lab_05_a ;;
  05-b) lab_05_b ;;
  *) echo "bilinmeyen lab: $lab" >&2; exit 2 ;;
esac
printf '\n\033[32mLAB %s cozumu ekip-%s icin uygulandi.\033[0m\n' "$lab" "$nn"
