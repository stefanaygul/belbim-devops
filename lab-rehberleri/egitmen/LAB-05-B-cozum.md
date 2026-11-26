# LAB 05-B · Çözüm ve eğitmen notları

Final: uçtan uca teslimat · 140 dk · Gün 5, Modül 3 · öğrenci rehberi: [`../ogrenci/LAB-05-B.md`](../ogrenci/LAB-05-B.md)

**Durum:** `SANDBOX_VERIFIED`. ekip-01 ile; credential, tag keşfi, webhook, issue, dört MR, review, uygulama arayüzü ve Jenkins "Build Now" gerçek tarayıcıda yapılarak koşuldu (`kanit/faz-5/lab-05-b-ekip01.txt`, 48 denetim). ekip-02'de `checkpoint/lab-05a` durumundan tek seferde koşuldu (290 sn, 49 denetim). `checkpoint/final` ekip-02'ye dört kez uygulandı (son hali 69 sn, 41 denetim). Doğrulamanın olumsuz yönü: LAB 05-A durumundaki ekipte 32 denetim kalıyor. Ayrıntılar `RAPOR.md` §18'de.

## Eğitmen komutları

| Ne | Komut (`lab-ortami/` içinde) |
|---|---|
| Çözümü uygula | `bash dogrula/cozum.sh 05-b NN` |
| Denetle | `make dogrula-lab LAB=05-b EKIP=NN` (test ortamında miktarı 2 olan bir talep oluşturur) |
| Ekibi bu labın başına / sonuna getir | `make checkpoint EKIP=NN LAB=lab-05a` / `LAB=final` |
| Deploy açıklaması | `docker compose run --rm -T araclar bash dogrula/ci-durum.sh deploy NN v1.1.0` |
| Test ortamında çalışan sürüm | `docker compose exec -T -u deploy test-vm sh -c 'cd /opt/saha/ekipNN && cat .env && tail -n 3 deploy-kayit.log'` |

## Süre dağılımı ve ara kontroller

| Dakika | Adım | Ara kontrol |
|---|---|---|
| 0–30 | 1 · Deploy anahtarı, credential, `deploy.sh`, stage'ler, MR | `develop` build'inde Deploy ve Smoke test yeşil; `deploy-kayit.log`'da ilk satır |
| 30–35 | 2 · Issue, branch | |
| 35–55 | 3 · Önce kırmızı test, sonra kod | Kırmızıyı gören var mı? |
| 55–70 | 4 · MR, review | Lider onayladı |
| 70–80 | 5 · `develop` deploy'u | `quantity=0` → 400 test VM'de |
| 80–105 | 6 · Release, geri birleştirme, tag ayarları, `v1.1.0` | **Tag'i geri birleştirmeden sonra atın** (aşağıda) |
| 105–115 | 7 · Smoke, aynı digest | |
| 115–130 | 8 · Rollback ve yeniden `1.1.0` | Kayıtta `1.1.0 → 1.0.1 → 1.1.0` |
| 130–140 | Toparlama, sunum hazırlığı | Her ekibin `TEST_URL`'ini tahtaya yazın |

## Çözüm

### Adım 1 · Deploy anahtarı ve credential

```bash
ssh-keygen -t ed25519 -N "" -C "jenkins-ekip$EKIP" -f ~/.ssh/jenkins-test-vm
ssh-copy-id -i ~/.ssh/jenkins-test-vm.pub $TEST_VM_USER@$TEST_VM
```

Jenkins: klasör > Credentials > **SSH Username with private key**, ID `test-vm-ssh`, username `deploy`, private key "Enter directly".

### Adım 1 · `deploy/deploy.sh` (öğrencilere tam metin olarak verilir)

```sh
#!/bin/sh
# deploy/deploy.sh - test VM'de bir sürümü Compose ile çalıştırır ve kaydını tutar.
#   sh deploy.sh <IMG> <TAG> <WEB_PORT> [commit] [kaynak]
set -eu
IMG="$1"; TAG="$2"; WEB_PORT="$3"; COMMIT="${4:--}"; KAYNAK="${5:-elle}"
DIZIN="$(cd "$(dirname "$0")" && pwd)"
PROJE="$(basename "$DIZIN")"
cd "$DIZIN"
export DOCKER_CONFIG="$DIZIN/.docker" IMG TAG WEB_PORT

docker compose -p "$PROJE" pull --quiet                     # etiket yoksa burada durur
printf 'IMG=%s\nTAG=%s\nWEB_PORT=%s\n' "$IMG" "$TAG" "$WEB_PORT" > .env
docker compose -p "$PROJE" up -d --remove-orphans

OZETLER=""
for s in product-service order-service web-ui; do
  d="$(docker image inspect --format '{{index .RepoDigests 0}}' "$IMG/$s:$TAG")"
  OZETLER="$OZETLER $s@${d#*@}"
done
SATIR="$(date -u +%Y-%m-%dT%H:%M:%SZ) tag=$TAG commit=$COMMIT kaynak=$KAYNAK$OZETLER"
echo "$SATIR" >> deploy-kayit.log
echo "KAYIT $SATIR"
```

### Adım 1 · `Jenkinsfile` (eklenen kısımlar)

Tam dosya: `checkpoint/final` (kaynak: `lab-ortami/checkpoint/adimlar/05b-deploy/Jenkinsfile`; `NN` ve `PORT_NN` yerine ekibin değerleri).

```groovy
  options {
    // ... (mevcutlar)
    disableConcurrentBuilds()
  }
  environment {
    // ... (mevcutlar)
    TEST_VM           = 'deploy@test-vm.kurum.test'
    VM_DIZIN          = '/opt/saha/ekipNN'
    WEB_PORT          = 'PORT_NN'
    TEST_URL          = "http://test-vm.kurum.test:${WEB_PORT}"
  }

    stage('Docker: SemVer etiketi') {
      when { buildingTag() }
      steps {
        withCredentials([usernamePassword(credentialsId: 'gitlab-registry',
            usernameVariable: 'U', passwordVariable: 'P')]) {
          sh '''echo "$P" | docker login $REGISTRY -u "$U" --password-stdin
                SHA=$(git rev-parse --short HEAD)
                SURUM=${TAG_NAME#v}
                for s in product-service order-service web-ui; do
                  i=0
                  until docker manifest inspect $IMG/$s:$SHA > /dev/null 2>&1; do
                    i=$((i + 1))
                    if [ $i -gt 20 ]; then
                      echo "HATA: $IMG/$s:$SHA registry'de yok. ... imaj yeniden derlenmez. ..."
                      exit 1
                    fi
                    sleep 15
                  done
                  docker pull -q $IMG/$s:$SHA
                  docker tag $IMG/$s:$SHA $IMG/$s:$SURUM
                  docker push -q $IMG/$s:$SURUM
                done'''
        }
      }
    }

    stage('Deploy: test') {
      when { anyOf { branch 'develop'; buildingTag() } }
      steps {
        script {
          env.DEPLOY_TAG = env.TAG_NAME ? env.TAG_NAME.replaceFirst(/^v/, '') : sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
          env.DEPLOY_COMMIT = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
        }
        sshagent(['test-vm-ssh']) {
          sh 'scp deploy/compose.yaml deploy/deploy.sh $TEST_VM:$VM_DIZIN/'
          script {
            def cikti = sh(returnStdout: true,
              script: 'ssh $TEST_VM "sh $VM_DIZIN/deploy.sh $IMG $DEPLOY_TAG $WEB_PORT $DEPLOY_COMMIT $BUILD_URL"').trim()
            echo cikti
            def kayit = cikti.readLines().find { it.startsWith('KAYIT ') } ?: 'KAYIT yok'
            currentBuild.description = "test VM: TAG=${env.DEPLOY_TAG} · commit=${env.DEPLOY_COMMIT.take(7)} · " +
              kayit.tokenize(' ').findAll { it.contains('@sha256:') }.collect { it.take(it.indexOf('@sha256:') + 20) + '…' }.join(' · ')
          }
        }
      }
    }

    stage('Smoke test') {
      when { anyOf { branch 'develop'; buildingTag() } }
      steps {
        sh '''curl -fsS --retry 10 --retry-connrefused --retry-delay 3 "$TEST_URL/api/products" | grep -q '"code"'
              curl -fsS --retry 10 --retry-connrefused --retry-delay 3 -o /dev/null "$TEST_URL/api/orders"
              echo "smoke test: $TEST_URL yanıt veriyor (TAG=$DEPLOY_TAG)"'''
      }
    }
```

### Adım 3 · Doğrulama ve testler

```csharp
public const int MinQuantity = 1;
// CreateAsync içinde, ekipman kodu denetiminden sonra:
if (request.Quantity < MinQuantity)
{
    return Results.BadRequest(new { error = $"Miktar en az {MinQuantity} olmalı." });
}
```

Testler: `[Theory] [InlineData(0)] [InlineData(-1)]` → `400` ve mesajda "Miktar en az 1"; `[Theory] [InlineData(1)] [InlineData(2)]` → `201`. Tam hali `checkpoint/final` (kaynak: `05b-miktar/`).

### Adım 6 · Sıra ve tag

```bash
# release/1.1.0 -> main (MR, merge commit, kaynak silinmez) ; main build'i SHA imajını üretir
# release/1.1.0 -> develop (MR) ; develop deploy'u biter
# Jenkins: Discover tags + build stratejileri (Regular branches, Tags: 1 gün) ; GitLab webhook: Tag push events
rol lead
git fetch origin && git tag -a v1.1.0 -m "release: v1.1.0" origin/main && git push origin v1.1.0
```

## ekip-01 koşusundan gerçek değerler

| An | Sonuç |
|---|---|
| `feature/deploy` merge → `develop #7` | Deploy + smoke test yeşil; `tag=78ca4d7`; kayıt ve build açıklaması yazıldı |
| Kırmızı test | `Post_order_with_quantity_below_one_returns_400(quantity: 0)` ve `(-1)` `[FAIL]`; `Failed: 2, Passed: 19` |
| `feature/12-miktar-dogrulama` → `develop #8` | Quality Gate `OK`; test VM'de `{"error":"Miktar en az 1 olmalı."} HTTP 400`, miktar 2 → `HTTP 201` |
| `release/1.1.0` → `main #2`; geri `develop #9` | `main` SHA imajı `7b61f73`; `develop` yeniden deploy |
| `v1.1.0 #1` (tag push'tan sonra kendiliğinden) | 11 sn; SemVer etiketi; `KAYIT … tag=1.1.0 commit=7b61f738…` |
| Aynı digest | `order-service:1.1.0` = `order-service:7b61f73` = `sha256:aabcedeeb5f1…` (üç serviste de eşit) |
| Rollback | `tag=1.0.1 commit=- kaynak=elle`; `GET /api/orders/summary` → `404` |
| Yeniden `1.1.0` | `v1.1.0 #2` ("Build Now"); `summary` → `200`; kayıtta üç satır: `1.1.0`, `1.0.1`, `1.1.0` |
| İz | issue `#7` → MR `!14` → `develop` → `release/1.1.0` → `main 7b61f73` → `v1.1.0` → `order-service:1.1.0 sha256:aabcedeeb5f1…` → test VM |

## Bu ortamda gözlenenler

- **Tag build'inin kendiliğinden başlaması üç ayara bağlı:** "Discover tags", build stratejileri ("Regular branches" **ve** "Tags"), webhook'ta "Tag push events". "Tags" stratejisinin yaş sınırı tag'in gösterdiği **commit'in** tarihine bakar. Release merge'ü o gün yapıldığı için koşulu sağlar; checkpoint commit'leri sabit tarihli olduğu için checkpoint'te `v1.1.0` build'i elle başlatılır.
- **Tag keşfi açılınca eski tag'ler de build edilebilir:** sandbox'ta ekip-01'in `v1.0.0` ve `v1.0.1` tag'leri (1 günden yeni) build edildi; o commit'lerdeki `Jenkinsfile` iskelet olduğu için hiçbir şey yapmadı. Gerçek eğitimde 2. günün tag'leri 3 günlük olur.
- **Tek test ortamı:** `develop`'a her merge test VM'i SHA sürümüne çevirir. Tag geri birleştirmeden sonra atılmalı; yoksa test ortamında `v1.1.0` kalmaz. Kaçıran ekipte `v1.1.0` job'ında "Build Now" yeterlidir.
- **Arayüzden kaydedilemeyen job:** Faz 4'te checkpoint'in XML ile oluşturduğu job'larda (`owner` satırları eksikti) tag ayarı arayüzden kaydedilemiyordu (`NullPointerException`, ardından job repoyu okuyamıyordu). Faz 5'te düzeltildi; checkpoint'ten gelen ekipte de ayar arayüzden kaydedilir (ekip-02'de denendi).
- **Build açıklaması düz metindir:** Jenkins'in biçimlendiricisi HTML işlemez; ayırıcı ` · `. ekip-01 koşusundaki ilk sürüm `<br>` kullanıyordu ve açıklamada etiketler metin olarak görünüyordu; düzeltildi (ekip-01'in `Jenkinsfile`'ı bu eski sürümle kaldı).
- **web-ui:** kod değişikliği gerekmedi; `api.js` API'nin `error` alanını gösteriyor (`lab-05-b-arayuz-red.png`).
- **Tag'in commit'i için imaj yoksa:** SHA imajı olmayan bir commit'e atılan `v0.9.9-deneme` build'i 20 × 15 sn bekledi, ardından `HATA: …:c6e6188 registry'de yok. … imaj yeniden derlenmez. …` ile durdu (313 sn); Deploy ve Smoke test atlandı, test VM değişmedi (`kanit/faz-5/51-tag-build-imaj-yok-ekip02.txt`).
- **Smoke test'te yeniden deneme her istek için gerekli:** `checkpoint final`'ın bir koşusunda ikinci istek (`/api/orders`) `502` ile kırıldı (Nginx ve `product-service` hazır, `order-service` değil). İki istek de `--retry` ile yapılıyor. ekip-01 ve ekip-02'nin tek seferlik koşuları bu düzeltmeden önceki `Jenkinsfile` ile yapıldı.
- **Agent'ta MSBuild node reuse:** bir `develop` build'i `MSB4166: Child node "3" exited prematurely` ile kırıldı; agent imajında `MSBUILDDISABLENODEREUSE=1` ile giderildi (yönetici ayarı; BELBİM agent'larında da önerilir).
- **Rollback'te hedef etiket yoksa:** `sh deploy.sh $IMG 9.9.9 …` `pull` aşamasında `failed to resolve reference "…:9.9.9": not found` ile durdu (çıkış 1); `.env`, kayıt ve çalışan `1.1.0` değişmedi (`kanit/faz-5/40-deploy-olmayan-etiket-ekip01.txt`).
- **Rollback kanıtı:** `1.0.1` talep özeti uç noktasını bilmez; `GET /api/orders/summary` `404` → `200` geçişi, sürümün değiştiğini veriye dokunmadan gösterir.

## Doğrulanmayanlar

- Webhook "Test > Tag push events" düğmesi; Jenkins'in `TAG_NAME` dışındaki tag değişkenleri.
- `disableConcurrentBuilds()` altında aynı branch'e art arda iki push.
- Ekip sunumu (beş dakikada beş kanıt) ve sürelerin bir katılımcıyla ölçümü.
