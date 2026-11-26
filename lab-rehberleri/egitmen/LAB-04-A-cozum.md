# LAB 04-A · Çözüm ve eğitmen notları

GitLab bağlantısı ve ilk pipeline · 90 dk · Gün 4, Modül 3 · öğrenci rehberi: [`../ogrenci/LAB-04-A.md`](../ogrenci/LAB-04-A.md)

**Durum:** `SANDBOX_VERIFIED`. ekip-01 ile; token, credential'lar, Multibranch job, webhook, MR ve merge ayarı gerçek tarayıcıda yapılarak koşuldu (`kanit/faz-4/lab-04-a-ekip01.txt`, 36 denetim). ekip-02'de `checkpoint/lab-03b` durumundan tek seferde koşuldu (156 sn; `kanit/faz-4/20-lab-04-a-tek-kosu-ekip02.txt`, 36 denetim). `checkpoint/lab-04a` ekip-02'ye uygulandı (30 denetim). Doğrulama betiğinin olumsuz yönü: LAB 03-B durumundaki ekipte 21 denetim kalıyor (`13-lab-04-a-olumsuz-ekip02.txt`).

## Eğitmen komutları

| Ne | Komut (`lab-ortami/` içinde) |
|---|---|
| CI ortamını başlat ve kur | `make up-ci && make bootstrap`; denetim: `make dogrula-ci` |
| Çözümü uygula | `bash dogrula/cozum.sh 04-a NN` (`KUYRUK=1` ile: ortak agent'ı birkaç saniye devre dışı bırakan kuyruk kanıtı adımı da koşar; ders sırasında kullanmayın) |
| Denetle | `make dogrula-lab LAB=04-a EKIP=NN` |
| Ekibi bu labın başına / sonuna getir | `make checkpoint EKIP=NN LAB=lab-03b` / `LAB=lab-04a` |
| Zincirin anlık durumu | `docker compose run --rm -T araclar bash dogrula/ci-durum.sh build NN <branch> SUCCESS` (`mr`, `hook`, `kuyruk` komutları da var) |

Jenkins ve SonarQube hesapları: `make parolalar`.

## Süre dağılımı ve ara kontroller

| Dakika | Adım | Ara kontrol |
|---|---|---|
| 0–5 | 1 · Project Access Token | Rol Maintainer, scope yalnızca `api` |
| 5–20 | 2 · Credential'lar, Multibranch job | İki credential'ın **türü** doğru mu? Tarama logunda `develop` ve `main` |
| 20–30 | 3 · Webhook, test | **35. dk: herkesin webhook'u 200** |
| 30–50 | 4 · `Jenkinsfile` | İlk yeşil build; Revision = `git rev-parse HEAD` |
| 50–60 | 5 · MR, pipeline durumu | MR'da "Pipeline #… passed" |
| 60–70 | 6 · Pipelines must succeed, testi boz | Lokalde de kırmızı |
| 70–80 | 7 · Engel, düzeltme, merge | Bir ekibin kırmızı MR'ını projeksiyonda açın |
| 80–90 | Toparlama | |

Sık görülen ilk hata webhook adresindeki job adıdır (`…/project/ekip-NN/saha-portal-ekipNN`: klasör **ve** job). Dolaşırken buna bakın.

## Çözüm

### Adım 1–3

- Token: Settings > Access tokens; ad `jenkins`, rol Maintainer, scope `api`.
- Jenkins > `ekip-NN` > Credentials > Folder > Global > Add Credentials: `gitlab-api` (GitLab API token), `gitlab-repo` (Username with password; kullanıcı adı `jenkins`, parola token).
- New Item > `saha-portal-ekipNN` > Multibranch Pipeline > Branch Sources > Git > proje HTTPS adresi, credential `gitlab-repo`.
- Webhook: `$JENKINS_URL/project/ekip-NN/saha-portal-ekipNN`, yalnızca Push events, SSL verification açık; Test > Push events → `HTTP 200`.

### Adım 4 · `Jenkinsfile`

Tam dosya: `checkpoint/lab-04a` (kaynak: `lab-ortami/checkpoint/adimlar/04a-jenkinsfile/Jenkinsfile`; `NN` yerine ekip numarası).

```groovy
pipeline {
  agent { label 'dotnet-docker' }

  options {
    gitLabConnection(gitLabConnection: 'gitlab', jobCredentialId: 'gitlab-api', useAlternativeCredential: true)
    gitlabBuilds(builds: ['jenkins'])
    timeout(time: 30, unit: 'MINUTES')
  }

  environment {
    REGISTRY = 'gitlab.kurum.test:5050'
    IMG      = "${REGISTRY}/egitim/ekip-NN/saha-ekipman-portal"
  }

  stages {
    stage('Restore') {
      steps { sh 'dotnet restore SahaPortal.sln' }
    }
    stage('Build') {
      steps { sh 'dotnet build SahaPortal.sln -c Release --no-restore' }
    }
    stage('Unit Test') {
      steps {
        sh '''dotnet test SahaPortal.sln -c Release \
          --no-build --logger "junit;LogFileName=junit.xml"'''
      }
      post { always { junit '**/TestResults/junit.xml' } }
    }
    stage('web-ui') {
      steps {
        dir('src/web-ui') {
          sh 'npm ci'
          sh 'npm test -- --coverage --ci'
          sh 'npm run build'
        }
      }
      post { always { junit 'src/web-ui/junit.xml' } }
    }
  }

  post {
    success { updateGitlabCommitStatus name: 'jenkins', state: 'success' }
    failure { updateGitlabCommitStatus name: 'jenkins', state: 'failed' }
    aborted { updateGitlabCommitStatus name: 'jenkins', state: 'canceled' }
  }
}
```

### Adım 5–7

```bash
git push -u origin feature/pipeline            # MR: ci: add Jenkins pipeline, Closes #4
# lider: Settings > Merge requests > Pipelines must succeed
sed -i 's/Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);/Assert.Equal(HttpStatusCode.OK, response.StatusCode);/' \
  tests/order-service.tests/OrdersApiTests.cs
git commit -am "test(order): expect 200 for an empty product id" && git push      # kirmizi; merge kapali
git revert --no-edit HEAD && git push                                             # yesil; lider merge eder
```

## Doğrulama zinciri (ekip-01 koşusundan)

| Halka | Kanıt |
|---|---|
| 1 · Push olayı Jenkins'e ulaşıyor | GitLab webhook olay kaydı: `push_hooks ref=refs/heads/feature/pipeline HTTP 200` (her push için bir satır) |
| 2 · Jenkins doğru commit'i derliyor | `feature/pipeline #1 … derlenen commit daa12920 (aynı SHA)`; konsolda `Checking out Revision daa1292…` |
| 3 · Sonuç commit status olarak dönüyor | `commit status jenkins = success (ref feature/pipeline) -> …/job/feature%252Fpipeline/1/display/redirect`; commit başına tek ad |
| 4 · Başarısız pipeline MR'da görünüyor | MR ekranı: `Pipeline #11 failed`; API: `head_pipeline=failed` (`lab-04-a-merge-engeli.png`) |
| 5 · MR birleştirilemez, merge reddediliyor | `detailed_merge_status=ci_must_pass`; `PUT …/merge` (lider adına) → `405 Method Not Allowed` |
| 6 · Düzeltmeden sonra merge mümkün | `jenkins=success`, `detailed_merge_status=mergeable`; lider arayüzden merge etti; `develop #2 SUCCESS` |

**İş kuyruktayken ve durum yokken** (ekip-01 ve ekip-02 koşuları, `KUYRUK=1`; agent `ci-durum.sh agent offline` ile geçici olarak devre dışı bırakıldı; çıktı ekip-02'den):

```
kuyrukta: feature%252Fpipeline
MR'in son commit'i c438bdb4 icin commit status: yok (Jenkins henuz yazmadi)
detailed_merge_status=ci_must_pass      PUT …/merge -> HTTP 405
# agent geri alindi
MR'in son commit'i c438bdb4 icin commit status: jenkins=pending
detailed_merge_status=ci_still_running  PUT …/merge -> HTTP 405
```

Yani Jenkins hiç yanıt vermese de merge kapalı kalır. Bu deneme ortak agent'ı birkaç saniye durdurur; derste yapmayın, anlatın.

## Bu ortamda gözlenenler (slayttan farklı olanlar `slayt-guncellemeleri.md` içinde)

- **Merge request events:** Multibranch job MR olayına `409 Merge Request Hook is not supported for this project` döner (`kanit/faz-4/05-webhook-olaylari-ekip02.txt`). Webhook yalnızca Push events ile kurulur. GitLab 19.6 bu 409'lardan sonra webhook'u devre dışı bırakmadı (9 olay), ama her MR hareketinde hata kaydı oluşur.
- **Secret token:** Multibranch job webhook'un secret token'ını denetlemiyor (yanlış token ile de `200`). Rehberde alan boş bırakılır. Webhook yalnızca "repoya bak" der; Jenkins kodu GitLab'den kendi credential'ıyla çeker.
- **Ortak Jenkins'te token:** global `gitlab` bağlantısı token taşımaz. Ekibin token'ı klasör credential'ıdır ve `gitLabConnection(gitLabConnection: 'gitlab', jobCredentialId: 'gitlab-api', useAlternativeCredential: true)` ile seçilir. Slayttaki kısa yazım (`gitLabConnection('gitlab')`) ortak Jenkins'te sonucu GitLab'e yazamaz.
- **Tek token, iki credential:** yalnızca `api` scope'lu Project Access Token hem API'de hem Git-over-HTTPS'te çalışıyor.
- **İskelet `Jenkinsfile`:** yalnızca yorum içeren dosya da "pipeline" sayılır; `develop` ve `main` için job açılır, build `SUCCESS` biter ve GitLab'e durum yazmaz. Adım 2'de bunu görürler; şaşırmasınlar.
- **Kimse beklemesin:** `gitlabBuilds` satırı olmadan build çalışırken MR'da durum görünmez (`ci_must_pass`); satır varken `pending` görünür (`ci_still_running`). İki durumda da merge kapalıdır.
- MR listesindeki `detailed_merge_status` bayat kalabiliyor; tek MR uç noktası günceldir (`ci-durum.sh mr` bunu kullanır).

## Olumsuz örnek demoları (yalnızca eğitmen)

- Webhook adresinde job adını yanlış yazın: Test → `HTTP 404`.
- Webhook'ta "Merge request events" işaretleyip test edin: `HTTP 409`.
- Durum yazmayan bir `Jenkinsfile` (örneğin iskelet dosya) ile branch açıp MR oluşturun: Jenkins build'i yeşil, GitLab'de durum yok, "Pipelines must succeed" açıkken merge kapalı (`ci_must_pass`, API'de `405`). Deneyde ekip-02 üzerinde görüldü.

## Doğrulanmayanlar

- BELBİM Jenkins'inde kimlik doğrulama (LDAP/SSO), klasör yetkileri ve plugin sürümleri: hedef ortamda `dogrula/onkontrol.sh` ile denetlenecek (Faz 6).
- Webhook'un GitLab tarafından kendiliğinden devre dışı bırakılma eşiği (uzun süreli hata durumunda).
- "Set to auto-merge" akışı denenmedi; rehberde seçenek olarak anılıyor.
