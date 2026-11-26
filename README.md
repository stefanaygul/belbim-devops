# BELBİM DevOps Eğitimi — Lab Üretim Görevi

> **Kullanım (insan için):** Boş bir workspace aç. Bu dosyayı köke, beş sunumu ve müfredat PDF'ini `referans/` klasörüne koy. Planning modunda şu mesajla başla: *"ANTIGRAVITY_LAB_PROMPT.md dosyasını oku ve yalnızca Faz 0'ı uygula."* Her fazın sonunda ajan durur; onay verince bir sonraki faza geç.
26 Kasim
---

## 1. Rol ve hedef

Deneyimli bir DevOps mühendisi ve teknik eğitim geliştiricisi olarak çalış. BELBİM için hazırlanan 5 günlük (5 × 6 saat) yüz yüze DevOps eğitiminin **lablarını** üret:

1. Çalışan bir **starter uygulama** (Saha Ekipman Talep Portalı) ve lablarda kullanılacak hazır branch'ler.
2. Labların geliştirilip prova edileceği, **Docker üzerinde çalışan yerel lab ortamı** (GitLab, Jenkins, SonarQube, Nexus, test VM, katılımcı makinesi).
3. On labın **öğrenci rehberi** ve **eğitmen çözüm rehberi**.
4. Her labın bu ortamda **uçtan uca çalıştırılarak doğrulanması** ve kanıtlarının saklanması.

Başarı ölçütü: Sıfırdan kurulan ortamda, tek komutla çalışan bir prova betiği beş günün tüm lablarını baştan sona geçirir; rehberler bu provada kullanılan adımlarla birebir aynıdır.

## 2. Bağlam

- Eğitimin slaytları hazır: `referans/01_…pptx` – `referans/05_…pptx`. Lab kimlikleri, görev listeleri, süreler, dosya ve branch adları **slaytlardaki LAB slaytlarıyla birebir aynı** olmalı. Önce slaytları oku (gerekirse `python-pptx` ile metin ve notları çıkar). Bu dosya ile slayt çelişirse slayt geçerlidir; çelişkiyi `RAPOR.md` içinde bildir.
- BELBİM'in kendi ağında kurulu GitLab, Jenkins, SonarQube ve Nexus var. Eğitim orada yapılacak. Bu yüzden rehberler **ortamdan bağımsız** yazılır: tüm adresler, kullanıcılar ve kimlikler tek bir ortam dosyasından (`lab.env`) gelir. Docker ortamı yalnızca geliştirme, prova ve yedek içindir.
- **İki çalışma modu:** `sandbox` (bu dosyadaki yerel Docker ortamı) ve `integration` (BELBİM'in kurulu servisleri). BELBİM ağına erişimin yok; bu yüzden tüm doğrulamayı `sandbox`'ta yaparsın. Betikler ve rehberler iki modda aynıdır, fark yalnızca `lab.env` dosyasıdır. `integration` modunda hiçbir servisi kurma ya da yeniden yapılandırma; yalnızca denetle (§14).
- **Slaytlardan bilinçli iki sapma** (bunlarda bu dosya geçerlidir; `slayt-guncellemeleri.md` içine yaz): (1) SonarQube `community` profilinde analiz yalnızca `develop`'ta çalışır (§8, LAB 04-B); slaytlar feature branch analizlerinin ekip projesine yazıldığını anlatıyor. (2) Pipeline tablosunda `main` ve tag `v*` ayrı sütunlardır.
- Katılımcılar orta düzey: temel Linux, Git ve yazılım geliştirme biliyor; ileri DevOps deneyimi yok.
- Dil: rehberler ve açıklamalar Türkçe; teknik terimler (branch, merge request, pipeline, stage, image, tag…) slaytlardaki gibi İngilizce kalır. Kod, commit mesajı ve dosya adları İngilizce/ASCII.

## 3. Parametreler

Faz 0'da bu değerleri bana onaylat; bilinmeyenleri varsayılanla doldur ve `VERSIONS.md` içine yaz.

| Parametre | Varsayılan | Not |
|---|---|---|
| `LAB_DOMAIN` | `kurum.local` | Slaytlardaki örnek adreslerle aynı. `.local` host'ta mDNS ile çakışırsa `kurum.test` öner ve bana sor. |
| `EKIP_SAYISI` | `2` | Yerel prova için. Betikler 1–10 ekibi desteklemeli. |
| GitLab | En güncel kararlı CE, **sürümü sabitle** | BELBİM sürümü bilinirse onu kullan. CE = Free katmanı. |
| Jenkins | Güncel LTS, sürümü sabitle | Controller + ayrı Linux agent. |
| SonarQube | Community Build, sürümü sabitle | PostgreSQL ile. |
| Nexus | Nexus Repository 3 (Community), sürümü sabitle | |
| .NET SDK | 10.0 (LTS) | Hedef framework `net10.0`. |
| Node.js | 24 LTS | |
| `SONAR_PROFILE` | `community` | `community` ya da `commercial`; pipeline davranışı buna göre değişir (§8). |
| Host | Bana sor: işletim sistemi, mimari, CPU, RAM, disk, internet erişimi | Tercih: Linux x86-64. Tam ortam için planlama hedefi 32 GB RAM, 8 vCPU, 100 GB+ SSD. Daha azı varsa hangi profillerin aynı anda çalışabileceğini Faz 0'da raporla. |

Kurallar: hiçbir imajda `latest` kullanma; kullandığın her imajın tam etiketini `VERSIONS.md` içine yaz. Bir API, ayar yolu ya da komut seçeneğinden emin değilsen sabitlediğin sürümün resmi belgesine bak; tahmin etme. Kaynak rakamları tahmindir: ortam fazlarının sonunda `docker stats` ve disk kullanımıyla ölçtüğün gerçek değerleri `VERSIONS.md` içine yaz.

## 4. Değişmez adlandırmalar

Aşağıdakiler slaytlarda geçer; değiştirme.

**Adresler** (`D` = `LAB_DOMAIN`): `gitlab.D`, registry `gitlab.D:5050`, `jenkins.D`, `sonar.D`, `nexus.D`, `test-vm.D`. Hepsi HTTPS ve lab CA'sının imzaladığı sertifikayla.

**GitLab:** grup `egitim`; ekip alt grupları `ekip-01`…; her ekipte proje `saha-ekipman-portal`; şablon proje `egitim/sablonlar/portal-starter`; temel imajlar için `egitim/base`.

**Uygulama:** solution `SahaPortal.sln`; `src/product-service`, `src/order-service`, `src/web-ui`, `src/common-contracts`; `tests/`; `deploy/compose.yaml`, `deploy/nginx.conf`; `ci/analyze.sh`; kökte `Jenkinsfile`, `NuGet.config`, `README.md`, `CHANGELOG.md`; `.gitlab/CODEOWNERS`, `.gitlab/merge_request_templates/Default.md`.

**İmajlar:** `IMG=gitlab.D:5050/egitim/ekip-NN/saha-ekipman-portal`; imaj adları `product-service`, `order-service`, `web-ui`; etiketler SemVer (`1.0.1`) ve kısa commit SHA.

**Jenkins:** agent label `dotnet-docker`; GitLab connection adı `gitlab`; SonarQube sunucu adı `sonarqube`; credential ID'leri `gitlab-registry`, `nexus-nuget-key`, `test-vm-ssh`; managed file `nuget-config`; ekip klasörü `ekip-NN`, Multibranch job `saha-portal-ekipNN`; ortam değişkenleri `REGISTRY`, `IMG`, `TEST_URL`.

**SonarQube:** proje anahtarı `saha-portal-ekipNN` (bonus: `saha-portal-ekipNN-web-ui`); webhook `https://jenkins.D/sonarqube-webhook/` (sondaki `/` zorunlu).

**Nexus:** `nuget.org-proxy`, `nuget-hosted`, `nuget-group`, `npm-proxy`, `npm-hosted`, `npm-group`. Hosted depolarda redeploy kapalı. Paket kimliği `Saha.Common.Contracts.EkipNN`, ilk sürüm `1.0.0`.

**Test VM:** kullanıcı `deploy`, dizin `/opt/saha/ekipNN/`, Compose proje adı `ekipNN`; `WEB_PORT` ekip başına sabittir: ekip-01 → `8081`, ekip-02 → `8082`…

**Sürüm çizgisi:** `v1.0.0` (LAB 02-B) → `v1.0.1` hotfix (LAB 02-B) → `1.0.1` imajları (LAB 03-B) → `v1.1.0` (LAB 05-B).

## 5. Teslim edilecekler

```
portal-starter/          # starter uygulama (kendi git reposu, hazır branch'lerle)
lab-ortami/              # Docker Compose ortamı, bootstrap ve doğrulama betikleri
  compose.yaml  .env.example  lab.env.example
  certs/  bootstrap/  dogrula/  images/
lab-rehberleri/
  ogrenci/   LAB-01-A.md … LAB-05-B.md
  egitmen/   LAB-01-A-cozum.md … LAB-05-B-cozum.md, hata-senaryolari.md, prova.md
  ortam-karti.md  hazirlik-kontrol-listesi.md  img/
kanit/                   # her lab için terminal çıktıları ve ekran görüntüleri
VERSIONS.md  RAPOR.md  slayt-guncellemeleri.md
.agents/rules/lab-kurallari.md
```

`slayt-guncellemeleri.md`: slaytlardaki "örnek çıktı" etiketli her terminal bloğu için bu ortamdan aldığın gerçek çıktı ve slaytla uyuşmayan her ayrıntı (komut, mesaj metni, menü yolu).

## 6. Starter uygulama

Küçük ve okunur tut; amaç uygulama değil teslimat zinciri.

- `product-service` (ASP.NET Core Web API): `GET /api/products`. Katalog statik dosyadan okunur (`Data/catalog.json`): `ADP-01` Terminal adaptörü, `KBL-02` Bağlantı kablosu, `STD-03` Cihaz standı.
- `order-service` (ASP.NET Core Web API + EF Core SQLite): `POST /api/orders` gövdesi `{ "productId": "ADP-01", "quantity": 2 }`, başarıda 201; `GET /api/orders`. Bağlantı ayarı `ConnectionStrings:Orders`.
- Her API'de `/health` (yanıt `Healthy`) ve Swagger arayüzü (`/swagger`). Uygulamalar 8080 portunu dinler; log stdout'a gider.
- `common-contracts` (.NET class library): ortak DTO'lar. Başlangıçta servisler buna `ProjectReference` ile bağlıdır.
- `web-ui` (React + Vite): katalog listesi, talep formu, talep listesi. API çağrıları göreli adresle (`/api/...`); geliştirme sunucusunda Vite proxy ile API'lere gider. Test: Jest, `jest-junit` raporu (`junit.xml`), coverage `lcov`.
- `tests/`: xUnit; `JunitXml.TestLogger` ve `coverlet.collector` paketleri hazır.
- `NuGet.config` ve `.npmrc` baştan itibaren yalnızca Nexus group adreslerini gösterir (`<clear />` ile).
- `deploy/` ve `Jenkinsfile` başlangıçta yalnızca açıklama içeren iskelet dosyalardır; ilgili günde doldurulur.

**Starter'da bilinçli bırakılan eksikler** (lablar bunları düzeltir; çözmüş halde bırakma):

1. `POST /api/orders` boş `productId` kabul eder → LAB 02-B hotfix (`v1.0.1`).
2. `quantity` sıfır ya da negatif kabul edilir → LAB 05-B final görevi (400 dönmeli).
3. Katalogda stok alanı yok → LAB 02-A `inStock` alanını ekler.

**Hazır branch'ler:**

- `lab/01a-conflict`: `order-service`, `common-contracts`'ın istediğinden daha düşük sürümde bir paketi doğrudan referans eder; `dotnet restore` **NU1605** ile durur (slayttaki örnek: `Microsoft.Extensions.Logging.Abstractions` 10.0.0 → 9.0.0).
- `lab/01b-rename`: katılımcının LAB 01-B'de ekleyeceği `SRJ-04` katalog satırını farklı adla ekler; merge edilince **kesin conflict** çıkar.
- `lab/04b-untested`: `order-service`'e en az 40 satır testsiz yeni kod ekler; Quality Gate yeni kod coverage koşulunda **kesin kalır**.
- `checkpoint/lab-01a`, `checkpoint/gun1`, `checkpoint/lab-02a`, `checkpoint/lab-02b` (= `checkpoint/gun2`), `checkpoint/lab-03a`, `checkpoint/lab-03b` (= `checkpoint/gun3`), `checkpoint/lab-04a`, `checkpoint/lab-04b` (= `checkpoint/gun4`), `checkpoint/lab-05a`, `checkpoint/final`: ilgili labın tamamlanmış kaynak kodu. Bir checkpoint üç şeyi birlikte geri kurar: kaynak kod; ilgili servis yapılandırması (GitLab koruma ve token'ları, Jenkins job ve credential'ları, SonarQube projesi, Nexus paketi); test ortamındaki uygulama ve veri. Bunu `bootstrap/checkpoint-uygula.sh <ekip> <lab>` yapar. Betik yalnızca o ekibin kaynaklarına dokunur: başka ekibin reposunu, job'ını, verisini ya da credential'ını etkilemez ve paylaşılan servislerde global sıfırlama yapmaz.

## 7. Lab ortamı (Docker)

Tek Compose projesi (`belbim-lab`), tek ağ. Gereksinimler:

- **Servisler:** `gitlab` (Container Registry `:5050` açık), `jenkins` (controller, executor 0) + `jenkins-agent` (label `dotnet-docker`; .NET SDK, Node, Docker CLI, git, `dotnet-sonarscanner`, `sonar-scanner`), agent için ayrı Docker daemon, `sonarqube` + PostgreSQL, `nexus`, `test-vm` (Docker + SSH sunucusu; "ikinci VM" ve "test VM" rolünü birlikte üstlenir), `workstation` (katılımcının eğitim makinesini taklit eder: git, .NET SDK, Node, kendi Docker daemon'ı; lab komutları burada çalıştırılır).
- **Ad çözümleme ve TLS:** Bir lab CA üret. Tüm servisler §4'teki adlarla, ağın içinden ve host tarayıcısından **aynı URL** ile erişilir (önerilen: tek reverse proxy + ağ takma adları; GitLab SSH için TCP geçişi). Host için hosts kaydı ve CA içe aktarma adımlarını Windows/macOS/Linux ayrı ayrı belgeleyip `lab-ortami/README.md` içine yaz. Portları yalnızca `127.0.0.1` üzerinde yayınla.
- **Kapalı ağ benzetimi:** NuGet ve npm yalnızca Nexus proxy üzerinden gelir. Temel imajlar (`dotnet/sdk`, `dotnet/aspnet`, `node`, `nginx-unprivileged`) `egitim/base` altına itilir; SDK ve Node imajlarının iç kopyalarına lab CA'sı eklenir. Dockerfile'lardaki `ARG MCR` ve `ARG HUB` bu iç adresle beslenir.
- **Bootstrap (`bootstrap/*.sh`, idempotent, API tabanlı):** yönetici parolaları; GitLab grup/alt grup/kullanıcı/şablon proje, giden istek izin listesine **yalnızca** Jenkins adresi; Jenkins pluginleri ve yapılandırması (tercihen Configuration as Code), `gitlab` bağlantısı, `sonarqube` sunucu tanımı, ekip klasörleri; SonarQube webhook'u; Nexus depoları, realm'ler, kullanıcılar; test VM'de `deploy` kullanıcısı ve ekip dizinleri.
- **Katılımcıya bırakılanlar:** Labda öğrencinin yapacağı adımları bootstrap'te yapma (ör. ekip projesine push, branch koruması, Project Access Token, ekip credential'ı, Multibranch job, proje webhook'u, SonarQube projesi ve token'ı, Docker daemon'a CA tanıtma). Bunlar yalnızca `checkpoint-uygula.sh` ve prova betiğiyle otomatikleşir.
- **Komutlar:** `make up`, `make bootstrap`, `make durum`, `make sifirla-ekip EKIP=01`, `make yik` (volume silmeden önce onay ister). Compose profilleri ile hafif başlatma: `cekirdek` (GitLab, Nexus, workstation, test VM) ve `ci` (Jenkins, agent, SonarQube).
- **Docker daemon'ları:** Host'un Docker soketini hiçbir container'a bağlama. Üç rol üç ayrı daemon ister (agent, katılımcı makinesi, test VM); daha fazlasını ekleme.
- **Kaynak:** GitLab'ı resmi düşük bellek (memory-constrained) ayarlarıyla çalıştır, her servise bellek sınırı koy. Ortamı tek seferde değil fazlara göre büyüt (§11).
- **Ortak Jenkins notu:** GitLab connection ve SonarQube sunucu tanımı globaldir, ekip başına tekrarlanamaz. Slayttaki sözdizimini (`gitLabConnection('gitlab')`, `withSonarQubeEnv('sonarqube')`) koru; ekiplerin kendi token'larını klasör kapsamlı credential olarak nasıl kullandığını rehberde açıkla. Slaytla bağdaşmayan bir nokta kalırsa `RAPOR.md` içinde öner.

## 8. Lablar

Görevler slaytlardakiyle aynıdır; aşağıdaki listeyi slaytlarla karşılaştırarak doğrula.

**LAB 01-A · Starter proje, build ve dependency · 70 dk** — Klonla ve klasörleri incele → `dotnet restore/build/test` → `web-ui` içinde `npm ci`, `npm test` → `dotnet list package --include-transitive` → `npm ls` → `lab/01a-conflict` üzerindeki NU1605'i çöz → API'leri ve web-ui'yi başlat, `/health` ve arayüzü doğrula. *Başarı:* build ve testler yeşil, çakışma giderildi, tarayıcıda katalog listeleniyor ve talep oluşturulabiliyor.

**LAB 01-B · Feature branch, conflict ve commit · 80 dk** — `feature/katalog-sarj-unitesi` → kataloğa `SRJ-04` "Şarj ünitesi" → testi güncelle → Conventional Commits ile commit → `lab/01b-rename` merge, conflict'i çöz → testleri yeniden çalıştır → `git log --oneline --graph`. *Başarı:* yeni ekipman görünüyor, conflict çözüldü, geçmiş okunur.

**LAB 02-A · Proje, koruma ve Merge Request · 80 dk** — Lokal repoyu ekip projesine push et → `develop` oluştur, `main` ve `develop`'u koru → issue aç, `feature/3-stok-durumu` → kataloğa stok durumu alanı, testi güncelle → `develop` hedefli MR, şablonu doldur → reviewer yorumu, düzeltme, thread'i çözme → merge; branch silindi, issue kapandı. CODEOWNERS ve MR şablonu bu labda repoya eklenir. *Başarı:* doğrudan push reddediliyor; bir MR ikinci kişiden geçip merge edildi. **İki akış yaz:** A (Free: push kapalı, merge yalnızca Maintainer) ve B (Premium: approval rule + Code Owners).

**LAB 02-B · Release ve hotfix döngüsü · 80 dk** — `release/1.0.0` → CHANGELOG, MR ile `main` → `v1.0.0` annotated tag → release'i `develop`'a geri merge → `hotfix/1.0.1`: boş ekipman kodu hatası + unit test → MR ile `main`, `v1.0.1` → hotfix'i `develop`'a da merge, grafiği doğrula. *Başarı:* iki tag var; hotfix commit'i hem `main`'de hem `develop`'ta.

**LAB 03-A · Üç servis için Dockerfile · 95 dk** — `feature/9-docker` → `order-service` multi-stage Dockerfile → aynı kalıp `product-service` → `web-ui` için Node + Nginx → `.dockerignore`, context boyutu → üç imajı build et, boyutlara bak → tek tek çalıştır, `/health` ve loglar. *Başarı:* imajlar root olmayan kullanıcıyla çalışıyor; ikinci build'de restore ve `npm ci` cache'ten. Kurallar: build context repo kökü; `ARG MCR`/`ARG HUB`; `COPY NuGet.config`; `USER $APP_UID`; `nginx-unprivileged`; port 8080.

**LAB 03-B · Registry, Compose ve ikinci VM · 95 dk** — İmajları `1.0.1` ve commit SHA ile etiketle → deploy token ile login, push → Container Registry sayfasını doğrula → `compose.yaml` ve `nginx.conf` → lokalde `compose up`, arayüzden talep → ikinci VM'de pull, kendi proje adıyla çalıştır → `curl` smoke test, MR ile `develop`. *Başarı:* uygulama ikinci VM'de registry'den çekilen imajlarla çalışıyor; talep kaydı container yeniden yaratılınca kaybolmuyor. Kurallar: `${IMG}`, `${TAG}`, `${WEB_PORT:-8080}:8080`; `orders-data` → `/data`; `ConnectionStrings__Orders=Data Source=/data/orders.db`; yalnızca `web-ui` port yayınlar; Nginx `/api/products` ve `/api/orders` yollarını servis adlarına yönlendirir. Root olmayan kullanıcının `/data`'ya yazamaması (SQLite Error 14) labda **yaşanacak** bir hatadır: öğrenci rehberinde çözümü verme, "yaygın hata" bölümünde yönlendir; çözüm dosyasında düzelt.

**LAB 04-A · GitLab bağlantısı ve ilk pipeline · 90 dk** — `api` scope'lu Project Access Token → Jenkins'te credential ve Multibranch job → webhook, "Test > Push events" → Jenkinsfile'a Restore, Build, Unit Test, web-ui stage'leri → MR aç, pipeline durumunu MR'da gör → "Pipelines must succeed" aç, bir testi boz → merge engellendi; düzelt ve merge et. *Başarı:* her push pipeline'ı tetikliyor; sonuç MR'da; kırılan test merge'ü engelliyor. **Doğrulama zinciri** (her halka ayrı kanıtlanır): (1) push ve MR olayı Jenkins'e ulaşıyor; (2) Jenkins doğru commit SHA'yı derliyor; (3) sonuç GitLab'e commit status olarak dönüyor; (4) başarısız pipeline MR ekranında görünüyor; (5) "Pipelines must succeed" açıkken GitLab API'si MR'ı birleştirilemez gösteriyor ve merge denemesi reddediliyor; (6) düzeltmeden sonra merge mümkün. Jenkins işi kuyruktayken ya da hiç durum gelmemişken de merge'ün kapalı kaldığını denetle. Repoda `.gitlab-ci.yml` bulunmaz; aynı commit için tek bir durum adı (`jenkins`) kullan.

**LAB 04-B · SonarQube, Quality Gate, imaj · 100 dk** — SonarQube projesi ve token, Jenkins'e ekle → begin → build → test → end adımlarını pipeline'a taşı (`ci/analyze.sh`) → Quality Gate stage'i, yeşil pipeline → `lab/04b-untested` kodunu al → kalan kapıyı Jenkins'te ve SonarQube'da incele → eksik testleri yaz → `develop` yeşil, imaj registry'de. *Başarı:* testsiz kod kapıda kalıyor ve imaj üretilmiyor; testlerle yeşile dönüyor.

Analiz kapsamı `SONAR_PROFILE` ile belirlenir. İki akışı da yaz; yalnızca sandbox'ta çalışanı doğrula:

- `community`: analiz ve Quality Gate **yalnızca `develop`** build'inde çalışır; feature branch'lerde build ve test yeterlidir. `sonar.branch.name` gönderme. Testsiz kod MR ile `develop`'a girer, kapı `develop`'ta kalır ve imaj üretilmez; düzeltme ikinci bir MR ile gelir. Rehberde bunun Community Build'in sınırı olduğunu açıkça söyle. Farklı branch'lerin analizini aynı projeye yazıp branch analizi varmış gibi gösterme.
- `commercial`: analiz her branch'te ve MR'da çalışır; kapı merge'den önce MR'ı engeller.

Kapının sonucu her çalıştırmada aynı olmalı: New Code tanımını, taban analizini ve eşikleri sabitle ve belgele. Docker stage'i: `when { anyOf { branch 'develop'; branch 'main' } }`, kısa SHA için `git rev-parse --short HEAD` (bash'e özgü yazım yok).

**LAB 05-A · Ortak paket Nexus'ta · 75 dk** — PackageId (ekip sonekiyle) ve Version → `dotnet pack`, içeriği incele → `1.0.0`'ı hosted depoya push → aynı sürümü yeniden push, hatayı oku → API'lerde `ProjectReference` yerine `PackageReference` → önbelleği temizle, restore Nexus'tan → MR, pipeline yeşil. *Başarı:* paket Nexus'ta; servisler paketten restore ediyor; aynı sürüm ikinci kez yayınlanamıyor. Bonus: `Pack & Publish` stage'i (`when { allOf { branch 'main'; changeset 'src/common-contracts/**' } }`). Eğitmen demosu: aynı paketin GitLab Package Registry'ye yayını.

**LAB 05-B · Final: uçtan uca teslimat · 140 dk** — Jenkinsfile'a Deploy ve smoke test stage'leri → issue, `feature/12-miktar-dogrulama` → validation ve unit testler → MR: pipeline yeşil, review tamam → `develop`'a merge; Quality Gate yeşil ve test VM'e otomatik deploy (`commercial` profilde kapı MR aşamasında da yeşil olmalı) → `release/1.1.0` → `main`, `v1.1.0` tag → `v1.1.0` imajını test ortamında smoke test ile doğrula → rollback provası: `1.0.1`'e dön, yeniden `1.1.0`. *Başarı:* `v1.1.0` test ortamında; miktarı 0 olan talep 400, miktarı 2 olan talep 201; issue'dan imaja kadar iz gösterilebiliyor; deploy kaydında commit SHA ve imaj digest'i var.

**Pipeline davranışı (son hali):**

| Stage | `feature/*` | `develop` | `main` | tag `v*` |
|---|---|---|---|---|
| Restore, Build, Test, web-ui | çalışır | çalışır | çalışır | çalışır |
| SonarQube + Quality Gate | yalnızca `commercial` | çalışır | yalnızca `commercial` | — |
| Docker Build & Push | — | etiket: SHA | etiket: SHA | SHA imajına SemVer etiketi |
| Deploy (test VM) + smoke test | — | `TAG` = SHA | — | `TAG` = SemVer |
| Pack & Publish (bonus) | — | — | paket klasörü değiştiyse | — |

- Tag build'i imajı yeniden derlemez: aynı commit'in SHA etiketli imajını registry'den alır, SemVer etiketini ekler ve iter. İki etiketin digest'i aynı olmalı. İmaj henüz yoksa ne yapılacağına (anlaşılır hatayla durmak ya da derlemek) karar ver ve belgele.
- Her deploy; commit SHA, etiket ve imaj digest'ini test VM'de bir kayıt dosyasına ve Jenkins build açıklamasına yazar.
- `Pack & Publish` yalnızca paket klasörü değiştiğinde çalışır. Sürüm Nexus'ta zaten varsa anlaşılır bir mesajla durur; her build'de aynı sürümü yeniden yayınlamayı deneyen bir akış kurma. Paket yayını ile imaj yayını birbirinden bağımsızdır.
- Rollback, hedef etiketin registry'de bulunduğu doğrulandıktan sonra yapılır.
- Tag build'lerinin Multibranch job'da kendiliğinden başlaması için gereken ayarı (tag keşfi ve build stratejisi) kur, belgele ve doğrula; mümkün değilse elle başlatma adımını rehbere yaz. `buildingTag()` ve `TAG_NAME` davranışını sabitlediğin sürümde dene.

## 9. Rehber biçimi

**Öğrenci rehberi** (lab başına bir dosya; başında öğrenme kazanımı, süre ve başlangıç checkpoint'i): 1) Amaç 2) Ön koşullar 3) Kullanılacak sistemler 4) Adımlar (komutlar ve arayüz işlemleri, ekran görüntüsüyle) 5) Beklenen çıktı 6) Başarı kriterleri 7) Yaygın hatalar ve ipuçları 8) Kendini kontrol soruları (2–3 tane) 9) Başlangıç durumuna dönme. Lab süresinin son 10 dakikası toparlama ve kontrol içindir; slaytlardaki süreleri değiştirme. Öğrencinin kendi başına ilerleyebileceği kadar net, çözümü doğrudan vermeyecek kadar öğretici olsun: kritik dosyaların (Dockerfile, Jenkinsfile, compose.yaml) tamamını değil iskeletini ve ipuçlarını ver.

**Eğitmen çözüm rehberi:** her adımın tam çözümü, çalışan dosyalar, süre dağılımı, ara kontrol noktaları, sık takılınan yerler ve **kurtarma akışı**: ekip hangi dakikada hâlâ hangi adımdaysa hangi checkpoint'in uygulanacağı. Tek bir teknik sorun ekibin günün kalanını kaçırmasına yol açmamalı.

**`hata-senaryolari.md`:** slaytlardaki hata tablolarındaki her hatayı bu ortamda **nasıl üretip nasıl çözeceğini** yaz ve dene. En az: korumalı branch'e push reddi, korumalı tag reddi, Git ve Docker'da sertifika (x509) hatası, registry `denied`, SQLite Error 14, port çakışması, `manifest unknown`, GitLab "Url is blocked", `waitForQualityGate` timeout (webhook yok / sondaki `/` eksik), `when { branch }` atlanması, begin/end sırası yanlışken boş analiz, Docker soket izni, Nexus'ta aynı sürümü yeniden yayınlama (400), NuGet kaynak hatası (NU1101).

**`ortam-karti.md`:** ekip başına adresler, kullanıcılar, portlar, proje ve job adları, credential ID'leri. **`hazirlik-kontrol-listesi.md`:** eğitimden önce ortamda doğrulanacaklar.

Adresleri rehberlere gömme; `lab.env` değişkenleriyle yaz ve dosyanın başında örnek değerleri göster.

## 10. Doğrulama ve kanıt

- Her lab için `dogrula/lab-XX-Y.sh`: başarı kriterlerini API ve komutlarla denetler, geçti/kaldı döner.
- `dogrula/prova.sh`: temiz ortamda yeni bir ekip (`ekip-99`) oluşturur, on labın çözümünü sırayla uygular ve her labdan sonra ilgili doğrulamayı çalıştırır. Teslimden önce bunu **temiz kurulumda** baştan sona en az bir kez çalıştır.
- Arayüz adımlarını tarayıcı ajanıyla gerçekten yap; ekran görüntülerini `lab-rehberleri/img/` altına, terminal çıktılarını `kanit/` altına kaydet.
- Bilinçli her hata senaryosu iki kez doğrulanır: önce hatanın beklenen biçimde oluştuğu, sonra çözüm uygulanınca düzeldiği. En az: NU1605 → restore başarılı; merge conflict → merge tamam; korumalı branch'e push reddi → MR ile merge; Quality Gate kaldı → geçti; registry `denied` → push başarılı; SQLite Error 14 → veri volume'da kalıcı; Nexus'ta aynı sürüm reddi → yeni sürüm yayınlandı; `quantity=0` → 400, `quantity=2` → 201. Her koşunun çıktısını `kanit/` altında sakla.
- Her lab ve betik için durum etiketi kullan: `IMPLEMENTED` (yazıldı, çalıştırılmadı), `LOCALLY_TESTED` (yerel build/test geçti), `SANDBOX_VERIFIED` (sandbox'ta gerçek servislerle doğrulandı), `INTEGRATION_VERIFIED` (BELBİM ortamında doğrulandı; bunu yalnızca ben verebilirim), `BLOCKED` (ön koşul eksik), `FAILED`. Her faz sonunda `RAPOR.md` içinde lab × durum tablosu ver.
- Çalıştırmadığın hiçbir adımı "doğrulandı" diye yazma. Yerel ortamda doğrulanamayanları (GitLab Premium B akışı, SonarQube ticari sürümde branch/MR analizi, BELBİM'e özgü ayarlar) rehberde ve `RAPOR.md` içinde **"doğrulanmadı"** olarak işaretle.

## 11. Fazlar

Her fazın sonunda dur, kısa bir özet ve kanıt göster, onayımı bekle.

- **Faz 0 — Plan:** slaytları oku; parametreleri sor; mimariyi, dosya ağacını, riskleri ve belirsizlikleri içeren uygulama planını çıkar; §4 ve §12'yi `.agents/rules/lab-kurallari.md` dosyasına yaz. Kod yazma.
- **Faz 1 — Starter uygulama:** uygulama, testler, hazır branch'ler (`lab/01a-conflict`, `lab/01b-rename`). Lokal build/test ve NU1605 ile conflict'in üretildiğinin kanıtı.
- **Faz 2 — Çekirdek ortam:** CA, ad çözümleme, GitLab + registry, Nexus, `workstation`, `test-vm`, bootstrap. `make up && make bootstrap` temiz makinede çalışır; arayüzlere HTTPS ile erişilir. Ölçülen kaynak kullanımını raporla.
- **Faz 3 — Gün 1–3 labları:** rehberler, çözümler, checkpoint'ler, doğrulama betikleri.
- **Faz 4 — CI ortamı ve Gün 4 labları:** Jenkins, agent, SonarQube; LAB 04-A doğrulama zinciri; `lab/04b-untested` ve Quality Gate'in iki yönlü doğrulaması.
- **Faz 5 — Gün 5 labları:** paket yayını, pipeline'ın son hali, deploy kaydı, rollback, final görevi.
- **Faz 6 — Uçtan uca prova ve teslim:** temiz kurulumda `prova.sh`; `hata-senaryolari.md`; `slayt-guncellemeleri.md`; `RAPOR.md` (tamamlananlar, eksikler, riskler, BELBİM'e özgü doğrulanmamış ayarlar, kullanım talimatı).

## 12. Çalışma kuralları

- Sır yazma: parola ve token'lar `.env` içinde üretilir, `.gitignore`'dadır; rehberlere ve repolara gerçek değer girmez.
- TLS doğrulamasını "çözüm" olarak kapatma (`sslVerify false`, `insecure-registries`, `-k`); bunlar yalnızca eğitmenin olumsuz örnek demolarında yer alır.
- Yalnızca `belbim-lab` Compose projesine dokun. Volume silme, `docker system prune` gibi yıkıcı işlemlerden önce bana sor.
- Bir şey üç denemede çalışmıyorsa dur; denediklerini ve seçenekleri yaz, bana sor.
- Kararlarını ve varsayımlarını `RAPOR.md` içinde tut; slaytlarla her uyuşmazlığı oraya ekle.
- Gerçek BELBİM verisi, müşteri bilgisi ya da ödeme senaryosu kullanma.

## 13. Kapsam dışı

Kubernetes, public cloud, Terraform, harici SaaS; mikroservis mimarisi konuları (servis keşfi, mesaj kuyruğu, dağıtık transaction); kimlik doğrulama/yetkilendirme; Shared Library yazımı (yalnızca kavramsal); slaytların yeniden üretimi.

## 14. BELBİM ortamına taşıma

- `lab.env.example`: BELBİM'in gerçek adresleri, grup yolları ve kimlik adlarıyla doldurulacak tek dosya.
- `dogrula/onkontrol.sh`: Docker ortamına ihtiyaç duymadan hedef ortamı denetler: DNS ve TLS güveni, GitLab sürümü ve lisans katmanı, registry erişimi, Jenkins plugin listesi ve agent label'ı, SonarQube sürümü/sürüm türü ve webhook, Nexus depoları ve realm'ler, test VM'e SSH. Çıktısı hangi lab akışının (A/B, Community/ticari) uygulanacağını söyler.
- `lab-rehberleri/belbim-yoneticisinden-istenecekler.md`: yöneticinin önceden yapması gereken işlemler (grup ve kullanıcılar, giden istek izin listesi, Jenkins klasörleri ve global tanımlar, SonarQube webhook'u, Nexus depoları ve kullanıcıları, test VM, CA dağıtımı, temel imajların iç registry'ye alınması).
## Eğitim teslimi hızlı erişim

- [komutlar.md](komutlar.md): on labın terminal komutları ve kısa geçiş notları.
- [Hazırlık kontrol listesi](lab-rehberleri/hazirlik-kontrol-listesi.md), [yönetici hazırlığı](lab-rehberleri/belbim-yoneticisinden-istenecekler.md).
- [Prova rehberi](lab-rehberleri/egitmen/prova.md), [hata senaryoları](lab-rehberleri/egitmen/hata-senaryolari.md).
- [Faz 6 kanıtları](kanit/faz-6/); gerçek doğrulama durumu ve kalan sınırlar [RAPOR.md](RAPOR.md) içinde.
