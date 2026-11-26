# LAB 04-B · Çözüm ve eğitmen notları

SonarQube, Quality Gate, imaj · 100 dk · Gün 4, Modül 4 · öğrenci rehberi: [`../ogrenci/LAB-04-B.md`](../ogrenci/LAB-04-B.md)

**Durum:** `SANDBOX_VERIFIED` (SonarQube Community Build akışı). ekip-01 ile; SonarQube projesi ve token'ı, credential'lar ve üç MR gerçek tarayıcıda yapılarak koşuldu (`kanit/faz-4/lab-04-b-ekip01.txt`, 47 denetim). ekip-02'de `checkpoint/lab-04a` durumundan tek seferde koşuldu (`kanit/faz-4/22-lab-04-b-tek-kosu-ekip02.txt`, 47 denetim). `checkpoint/lab-04b` ekip-02'ye uygulandı (33 denetim). Doğrulama betiğinin olumsuz yönü: LAB 04-A durumundaki ekipte 22 denetim kalıyor.

Ticari sürüm akışı (branch ve MR analizi) bu eğitimde **gösterilmez** (karar K13); rehberde yalnızca Community Build akışı vardır.

## Eğitmen komutları

| Ne | Komut (`lab-ortami/` içinde) |
|---|---|
| Çözümü uygula | `bash dogrula/cozum.sh 04-b NN` |
| Denetle | `make dogrula-lab LAB=04-b EKIP=NN` |
| Ekibi bu labın başına / sonuna getir | `make checkpoint EKIP=NN LAB=lab-04a` / `LAB=lab-04b` (= `gun4`) |
| Kapı ve imaj durumu | `docker compose run --rm -T araclar bash dogrula/ci-durum.sh sonar NN OK` · `… imaj NN var` |

## Süre dağılımı ve ara kontroller

Slayttaki üç bölüm: kurulum (30 dk), kırma ve düzeltme (45 dk), imaj (25 dk).

| Dakika | Adım | Ara kontrol |
|---|---|---|
| 0–15 | 1 · Proje, token'lar, credential'lar | Klasörde dört credential; SonarQube ana branch adı `develop` |
| 15–25 | 2 · `ci/analyze.sh` | `git ls-files -s ci/analyze.sh` → `100755` |
| 25–45 | 3 · Quality Gate ve Docker stage'leri, MR | **45. dk: herkesin `develop` build'i yeşil, taban analiz var** |
| 45–55 | 4 · Testsiz kod | Feature build yeşil, MR merge edildi |
| 55–65 | 5 · Kalan kapıyı oku | Bir ekibin kırmızı pipeline'ını ve "1 condition failed" kutusunu projeksiyonda birlikte okuyun |
| 65–80 | 6 · Testler | `dotnet test` lokalde yeşil |
| 80–90 | 7 · Merge, imaj | Registry'de `develop` SHA etiketi |
| 90–100 | Toparlama | |

**Taban çizgisi kuralı:** bir ekip Adım 3'ün `develop` analizini görmeden Adım 4'e geçerse testsiz kod "yeni kod" sayılmaz ve kapı kalmaz. 45. dakika kontrolünü atlamayın.

## Çözüm

### Adım 2 · `ci/analyze.sh`

```sh
#!/bin/sh
set -eu

: "${SONAR_PROJECT_KEY:?SONAR_PROJECT_KEY tanimli degil}"

dotnet sonarscanner begin /k:"$SONAR_PROJECT_KEY" \
  /d:sonar.cs.opencover.reportsPaths="**/coverage.opencover.xml"

dotnet build SahaPortal.sln -c Release --no-restore

dotnet test SahaPortal.sln -c Release --no-build \
  --logger "junit;LogFileName=junit.xml" \
  --collect:"XPlat Code Coverage" -- \
  DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Format=opencover

dotnet sonarscanner end
```

### Adım 3 · `Jenkinsfile` (değişen ve eklenen kısımlar)

En dış `post` bloğuna `always { sh 'rm -f "$DOCKER_CONFIG/config.json"' }` eklenir; mevcut durum bildirimleri korunur. Registry girişi her workspace için ayrıdır ve build bitince silinir.

Tam dosya: `checkpoint/lab-04b` (kaynak: `lab-ortami/checkpoint/adimlar/04b-sonar/Jenkinsfile`).

```groovy
  environment {
    DOCKER_CONFIG     = "${WORKSPACE}@tmp/docker-config"
    REGISTRY          = 'gitlab.kurum.test:5050'
    IMG               = "${REGISTRY}/egitim/ekip-NN/saha-ekipman-portal"
    SONAR_PROJECT_KEY = 'saha-portal-ekipNN'
  }

    stage('Build') {
      when { not { branch 'develop' } }
      // ...
    }
    stage('Unit Test') {
      when { not { branch 'develop' } }
      // ...
    }

    stage('Build + Test + SonarQube') {
      when { branch 'develop' }
      steps {
        withSonarQubeEnv(installationName: 'sonarqube', credentialsId: 'sonar-token') {
          sh './ci/analyze.sh'
        }
      }
      post { always { junit '**/TestResults/junit.xml' } }
    }

    stage('Quality Gate') {
      when { branch 'develop' }
      steps {
        timeout(time: 10, unit: 'MINUTES') {
          waitForQualityGate abortPipeline: true, credentialsId: 'sonar-token'
        }
      }
    }

    // web-ui stage'i degismez

    stage('Docker Build & Push') {
      when { anyOf { branch 'develop'; branch 'main' } }
      steps {
        withCredentials([usernamePassword(credentialsId: 'gitlab-registry',
            usernameVariable: 'U', passwordVariable: 'P')]) {
          sh '''echo "$P" | docker login $REGISTRY -u "$U" --password-stdin
                SHA=$(git rev-parse --short HEAD)
                docker build -f src/product-service/Dockerfile --build-arg MCR=$MCR -t $IMG/product-service:$SHA .
                docker build -f src/order-service/Dockerfile   --build-arg MCR=$MCR -t $IMG/order-service:$SHA .
                docker build -f src/web-ui/Dockerfile          --build-arg HUB=$HUB -t $IMG/web-ui:$SHA .
                for s in product-service order-service web-ui; do
                  docker push $IMG/$s:$SHA
                done'''
        }
      }
    }
```

### Adım 4 · Testsiz kod

```bash
git switch -c feature/siparis-ozeti
git fetch sablon
git checkout sablon/lab/04b-untested -- src/order-service
git commit -m "feat(order): add order summary endpoint"
git push -u origin feature/siparis-ozeti
```

### Adım 6 · Testler

Tam dosya: `tests/order-service.tests/OrderSummaryTests.cs`, `checkpoint/lab-04b` içinde (kaynak: `lab-ortami/checkpoint/adimlar/04b-tests/`). Beş test yöntemi (11 test durumu): `Summarize` gruplama ve sıralama; boş kod ve negatif miktar; `LevelFor` sınırları (`[Theory]`, 7 değer); `Busiest`; uç nokta testi (`OrderApiFactory`). Takılan ekibe dosyayı verin:

```bash
git fetch sablon
git checkout sablon/checkpoint/lab-04b -- tests/order-service.tests/OrderSummaryTests.cs
```

## İki yönlü doğrulama (ekip-01 koşusundan)

| An | `develop` commit'i | Jenkins | Quality Gate | Yeni kod coverage | İmaj (SHA etiketi) |
|---|---|---|---|---|---|
| Taban (analiz MR'ı) | `013b113` | `#3 SUCCESS` | `OK` (koşul yok: yeni kod dönemi henüz başlamadı) | — (genel %62,4) | **var** |
| Testsiz kod | `149cd28` | `#4 FAILURE` | **`ERROR`** | **%6,7** (eşik %80; 31 satırın) | **yok** |
| Testler | `75995c7` | `#5 SUCCESS` | **`OK`** | **%97,8** | **var** |

Kapı kaldığında Jenkins konsolu (gerçek çıktı; slayt "Başarısız pipeline nasıl okunur?" ile karşılaştırın):

```
Checking status of SonarQube task 'b56a5f73-a7f3-4c64-85e5-e63511bfb98a' on server 'sonarqube'
SonarQube task 'b56a5f73-a7f3-4c64-85e5-e63511bfb98a' status is 'PENDING'
SonarQube task 'b56a5f73-a7f3-4c64-85e5-e63511bfb98a' status is 'SUCCESS'
SonarQube task 'b56a5f73-a7f3-4c64-85e5-e63511bfb98a' completed. Quality gate is 'ERROR'
Stage "web-ui" skipped due to earlier failure(s)
Stage "Docker Build & Push" skipped due to earlier failure(s)
ERROR: Pipeline aborted due to quality gate failure: ERROR
Finished: FAILURE
```

GitLab'de o commit'in durumu `jenkins=failed`; registry'de `149cd28` etiketi yok. ekip-02 koşusunda değerler aynı (%6,7 → %97,8).

## Bu ortamda gözlenenler

- **Community Build sınırı:** testsiz kodun feature build'i **yeşil** (analiz yok) ve MR merge edilebiliyor; kapı `develop`'ta kalıyor. Hasarı sınırlayan şey imajın üretilmemesidir. `develop` kırmızıyken sonraki MR'lar yine merge edilebilir (MR'ın durumu kendi branch'inden gelir). Bunu açıkça söyleyin.
- **Hazır branch merge edilmez:** `lab/04b-untested` geçmişi ekip projesiyle ortak değildir; ayrıca SonarQube "yeni kod"u satırın commit tarihine göre belirler. Dosyalar `git checkout <branch> -- <yol>` ile alınıp katılımcının kendi commit'iyle gönderilir; böyle yapıldığında 87 yeni satır görülüyor.
- **Yeni kod tanımı:** kurum varsayılanı "Previous version". Sürüm numarası gönderilmediği için dönem ilk analizle başlar ("New Code: Since November 24, 2026").
- **Token türü:** Project Analysis Token (`sqp_…`) hem analiz için hem `waitForQualityGate` için yeterli.
- **Ortak Jenkins'te token:** global `sonarqube` tanımı token taşımaz; `withSonarQubeEnv(installationName: 'sonarqube', credentialsId: 'sonar-token')` ve `waitForQualityGate … credentialsId: 'sonar-token'` klasör credential'ıyla çalışıyor. Slayttaki kısa yazım (`withSonarQubeEnv('sonarqube')`) ortak Jenkins'te token bulamaz.
- **`--build-arg`:** slayttaki `docker build` komutunda yok; iç ayna için gerekli (`MCR`, `HUB` Jenkins'in ortak ortam değişkenleri).
- **Görünürlük:** SonarQube projeleri varsayılan olarak giriş yapan herkese açıktır; ekipler birbirinin analiz sonucunu görebilir (analiz gönderemez, ayar değiştiremez). Proje silme yetkisi yöneticidedir.
- **Webhook:** SonarQube → Jenkins teslimleri `HTTP 200` (`make dogrula-ci`). SonarQube yerel ağ adresine webhook'u varsayılan olarak reddeder; `sonar.validateWebhooks=false` yönetici ayarıdır.
- Build süreleri: feature 8–9 sn, `develop` (analiz + üç imaj) 18–24 sn (önbellek sıcakken).

## Olumsuz örnek demoları (yalnızca eğitmen)

Bu fazda çalıştırılmadı; isterseniz deneyin ve sonucu not edin: `ci/analyze.sh` içinde build'i `begin`'den önceye almak (pano boş kalır); `gitlab-registry` credential'ına `read_registry` scope'lu token koymak (`insufficient_scope`, LAB 03-B'de görülmüştü).

## Doğrulanmayanlar

- SonarQube ticari sürümde branch ve MR analizi (`sonar.branch.name`, MR dekorasyonu): gösterilmiyor, denenmedi.
- Bonus: React analizi (`sonar-scanner`, proje `saha-portal-ekipNN-web-ui`): yazılmadı.
- Webhook eksikken `waitForQualityGate`'in zaman aşımı: denenmedi (ortak webhook'u kaldırmak bütün ekipleri etkiler).
- Öğrenci rehberi bölüm 9'daki "merge edilmiş MR > Revert" yolu: denenmedi.
- BELBİM SonarQube'unun sürümü, sürüm türü, varsayılan Quality Gate'i ve yeni kod tanımı: `dogrula/onkontrol.sh` ile denetlenecek (Faz 6). Varsayılan kapı "Sonar way" değilse eşikler farklı olabilir.
