# Slayt güncellemeleri

Durum: Faz 3 sonu (2026-11-24). Faz 3'te: C2, C3, C4, C8, C9 kesinleşti; C11–C19 yeni; D bölümüne Gün 2–3 çıktıları eklendi. Bu dosya üç şeyi toplar: slaytlardan bilinçli sapmalar, slaytla uyuşmayan ayrıntılar ve terminal bloklarının bu ortamdan alınan gerçek karşılıkları.

- Slayt gösterimi: `G4/26` = 4. gün sunumu, 26. slayt.
- **Kesin** = çalıştırılıp doğrulandı, slayt şimdi düzeltilebilir. **Ön gözlem** = ilgili fazda denenecek; metin değişebilir.
- Sürüm numaraları 2026-11-23 itibarıyla günceldir ve starter repoda sabitlenmiştir. Slaytta yama sürümünü `10.0.x` gibi yazmak eskimeyi önler.

## A. Bilinçli sapmalar

| # | Slayt | Slayt ne diyor | Lab ne yapıyor | Önerilen düzeltme | Durum |
|---|---|---|---|---|---|
| A1 | G4/26 notu, G5/18 tablo ve notu | `community` sürümde feature branch analizleri ekibin projesine yazılır; tabloda SonarQube `feature/*` sütununda "Çalışır" | `community` profilde analiz ve Quality Gate yalnızca `develop` build'inde çalışır | G4/26 notundaki "feature branch analizleri ekibin kendi projesine yazılır" cümlesi kaldırılmalı. G5/18 tablosunda SonarQube satırı: `feature/*` ve `main` "yalnızca ticari sürüm", `develop` "Çalışır", tag "—". G5/18 notundaki "Her ekibin tek projesine yazılır" yanıtı da değişmeli. | Karar kesin. **Faz 4'te doğrulandı:** feature build'lerinde analiz stage'leri atlanıyor (`skipped due to when conditional`), SonarQube projesinde tek branch (`develop`) var; testsiz kod MR'dan yeşil geçip kapıda `develop`'ta kalıyor |
| A2 | G5/18 | `main · tag v*` tek sütun | `main` SHA etiketli imaj üretir, deploy etmez. Tag build'i aynı SHA imajına SemVer etiketi ekler ve `TAG` = SemVer ile deploy eder. | Sütun ikiye bölünmeli (README §8 tablosu) | Karar kesin; davranış Faz 5'te doğrulanacak |

## B. Kesinleşen düzeltmeler

### B1. G1/18 — NU1605 örneği (kesin)

Slayttaki örnek (`Microsoft.Extensions.Logging.Abstractions` 10.0.0 → 9.0.0) .NET 10'da web projesinde hata vermiyor: paket ASP.NET Core paylaşımlı framework'ünden geldiği için restore grafiğinden budanıyor, restore geçiyor ve yalnızca `NU1510` uyarısı çıkıyor. Lab artık EF Core kullanıyor: `lab/01a-conflict` branch'inde `order-service`, `Microsoft.EntityFrameworkCore` 9.0.23'ü doğrudan referans ediyor; `Microsoft.EntityFrameworkCore.Sqlite` 10.0.15 ise 10.0.15 istiyor.

Gerçek çıktı (`kanit/faz-1/03-nu1605.txt`; her satır tek satırdır, burada bölünmedi):

```
$ dotnet restore SahaPortal.sln
src/order-service/order-service.csproj : error NU1605: Warning As Error: Detected package downgrade: Microsoft.EntityFrameworkCore from 10.0.15 to 9.0.23. Reference the package directly from the project to select a different version.  [SahaPortal.sln]
src/order-service/order-service.csproj : error NU1605:  order-service -> Microsoft.EntityFrameworkCore.Sqlite 10.0.15 -> Microsoft.EntityFrameworkCore.Sqlite.Core 10.0.15 -> Microsoft.EntityFrameworkCore.Relational 10.0.15 -> Microsoft.EntityFrameworkCore (>= 10.0.15)  [SahaPortal.sln]
src/order-service/order-service.csproj : error NU1605:  order-service -> Microsoft.EntityFrameworkCore (>= 9.0.23) [SahaPortal.sln]
  Failed to restore src/order-service/order-service.csproj (in 86 ms).
```

Aynı üç satır `tests/order-service.tests` için de tekrarlanır (test projesi servisi referans ettiği için).

Slayt için önerilen blok (okunabilirlik için bölünmüş):

```
$ dotnet restore
error NU1605: Warning As Error: Detected package downgrade:
  Microsoft.EntityFrameworkCore from 10.0.15 to 9.0.23
  order-service -> ...EntityFrameworkCore.Sqlite 10.0.15
    -> ... -> ...EntityFrameworkCore (>= 10.0.15)
  order-service
    -> ...EntityFrameworkCore (>= 9.0.23)

# Çözüm: doğrudan referansı hizala
$ dotnet add src/order-service package \
    Microsoft.EntityFrameworkCore -v 10.0.15
```

İki çözüm de denendi ve restore geçti: sürümü hizalamak (yukarıdaki komut) ve gereksiz doğrudan referansı kaldırmak (`dotnet remove src/order-service package Microsoft.EntityFrameworkCore`). Slayttaki "Çözüm" ve "Kalıcı çözüm" satırları aynen kalabilir.

Slayt notu için ek öneri: ".NET 10'dan itibaren framework'ün sağladığı paketler (ör. `Microsoft.Extensions.*`) web projelerinde grafikten budanır; bu paketlerde çakışma yerine `NU1510` uyarısı görülür."

### B2. G1/13 — bağımlılık şeması (kesin)

Şemadaki `common-contracts → Logging.Abstractions` dalı artık yok: `common-contracts` hiç paket bağımlılığı taşımıyor.

```
$ dotnet list src/common-contracts package --include-transitive
Project 'common-contracts' has the following package references
   [net10.0]: No packages were found for this framework.
```

Önerilen şema:

- `order-service.csproj` → **doğrudan · PackageReference** → `Microsoft.EntityFrameworkCore.Sqlite`
- `Microsoft.EntityFrameworkCore.Sqlite` → **geçişli** → `Microsoft.EntityFrameworkCore`, `Microsoft.Data.Sqlite.Core`, `SQLitePCLRaw.core`
- `order-service.csproj` → **doğrudan · ProjectReference** → `common-contracts` (paket bağımlılığı yok)

Bu haliyle şema G1/18'deki çakışmayı da hazırlar: geçişli gelen `Microsoft.EntityFrameworkCore`, labda doğrudan ve eski sürümle referans edilir.

### B3. G1/14 — `dotnet list package` çıktısı (kesin)

Gerçek çıktı (`kanit/faz-1/01-dotnet-build-test.txt`):

```
$ dotnet list src/order-service package --include-transitive
Project 'order-service' has the following package references
   [net10.0]:
   Top-level Package                           Requested   Resolved
   > Microsoft.AspNetCore.OpenApi              10.0.15     10.0.15
   > Microsoft.EntityFrameworkCore.Sqlite      10.0.15     10.0.15
   > Swashbuckle.AspNetCore.SwaggerUI          11.0.1      11.0.1

   Transitive Package                                Resolved
   > Microsoft.Data.Sqlite.Core                      10.0.15
   > Microsoft.EntityFrameworkCore                   10.0.15
   > Microsoft.EntityFrameworkCore.Abstractions      10.0.15
   > Microsoft.EntityFrameworkCore.Analyzers         10.0.15
   > Microsoft.EntityFrameworkCore.Relational        10.0.15
   > Microsoft.EntityFrameworkCore.Sqlite.Core       10.0.15
   > Microsoft.Extensions.DependencyModel            10.0.15
   > Microsoft.OpenApi                               2.13.0
   > SQLitePCLRaw.bundle_e_sqlite3                   2.1.13
   > SQLitePCLRaw.core                               2.1.13
   > SQLitePCLRaw.lib.e_sqlite3                      2.1.13
   > SQLitePCLRaw.provider.e_sqlite3                 2.1.13
```

Slayttan farklar: üçüncü bir üst düzey paket var (`Swashbuckle.AspNetCore.SwaggerUI`, `/swagger` arayüzü için); sürümler 10.0.0 değil 10.0.15; `SQLitePCLRaw.core` 2.1.11 değil 2.1.13. Slayt bloğu kısaltılacaksa geçişli listede `Microsoft.EntityFrameworkCore` satırı kalmalı; G1/18 ona bağlanıyor.

### B4. G1/15 — `package.json` (kesin)

Starter'daki gerçek dosya (kısaltılmış):

```json
{
  "name": "web-ui",
  "scripts": { "dev": "vite", "build": "vite build", "test": "jest" },
  "dependencies": { "react": "^19.3.1", "react-dom": "^19.3.1" },
  "devDependencies": { "vite": "^8.3.8", "jest": "^30.5.2" }
}
```

Slayttan fark: Vite `^7.0.0` değil `^8.3.8`. React ve Jest ana sürümleri slaytla aynı. Slaytta gösterilmeyen diğer devDependencies: Babel 7 ön ayarları, Testing Library, `jest-junit`, `jest-environment-jsdom`, `@vitejs/plugin-react`.

### B5. G1/22 — clone adresi (kesin)

Slayt `git@gitlab.kurum.local:egitim/saha-ekipman-portal.git` adresini klonluyor. G2/4 hiyerarşisinde ve README §4'te starter proje `egitim/sablonlar/portal-starter` yolunda.

Önerilen satır: `git clone git@gitlab.kurum.local:egitim/sablonlar/portal-starter.git saha-ekipman-portal`

Slayttaki `git log` çıktısı örnektir; starter'da ilk commit gerçekten `chore: starter project` mesajını taşır (SHA `174fe06`).

### B6. G1/24 — conflict örneği (kesin)

Gerçek çıktı (`kanit/faz-1/04-merge-conflict.txt`):

```
$ git merge origin/lab/01b-rename
Auto-merging src/product-service/Data/catalog.json
CONFLICT (content): Merge conflict in src/product-service/Data/catalog.json
Automatic merge failed; fix conflicts and then commit the result.

$ cat src/product-service/Data/catalog.json
[
  { "code": "ADP-01", "name": "Terminal adaptörü" },
  { "code": "KBL-02", "name": "Bağlantı kablosu" },
  { "code": "STD-03", "name": "Cihaz standı" },
<<<<<<< HEAD
  { "code": "SRJ-04", "name": "Şarj ünitesi" }
=======
  { "code": "SRJ-04", "name": "Hızlı şarj" }
>>>>>>> origin/lab/01b-rename
]
```

İki düzeltme:

1. Alt işaretin etiketi `feature/katalog-sarj-unitesi` değil, gelen branch'in adıdır: `origin/lab/01b-rename`. Slayttaki haliyle "HEAD benim branch'im" açıklamasıyla çelişiyor.
2. "İşaretler dosyada kalırsa build kırılır" bu dosya için doğru değil: `catalog.json` derlenmez, build geçer. Kırılan testlerdir (`product-service.tests` içinde 5 testten 4'ü kaldı). Öneri: "İşaretler dosyada kalırsa testler kırılır; commit öncesi arat."

### B7. G2/5 — katılımcı rolleri (kesin)

Slaytın alt notu "Katılımcılar kendi ekip grubunda Maintainer" diyor; G2/11 notu A akışında yazarın Developer olduğunu söylüyor. Doğrusu G2/11.

Önerilen alt not: "Eğitimde: Her ekipte iki hesap vardır: `ekipNN-lead` (Maintainer) ve `ekipNN-dev` (Developer). Ortak gruplarda herkes Reporter rolündedir."

Lab ortasındaki rol değişimi için eğitmenin çalıştıracağı, yalnızca o ekibe dokunan bir betik Faz 3'te yazılacak; G2/15 notundaki "eşler rolleri değiştirsin" cümlesine "eğitmen rol değişim betiğini çalıştırır" eklenebilir.

## C. Ön gözlemler (ilgili fazda kesinleşecek)

| # | Slayt | Gözlem | Beklenen düzeltme | Faz |
|---|---|---|---|---|
| C1 | G4/27 | Görev 4 "branch'i merge et" diyor. Hazır branch'in geçmişi ekip projesiyle ortak değil; ayrıca SonarQube Community Build yeni kodu satırın commit tarihine göre belirliyor. **Faz 4'te kesinleşti:** dosyalar `git checkout sablon/lab/04b-untested -- src/order-service` ile alınıp katılımcının kendi commit'iyle gönderildiğinde 87 yeni satır görülüyor, kapı `ERROR` veriyor (yeni kod coverage'ı %6,7; eşik %80), testlerle `OK` (%97,8). İki ekipte aynı sonuç. Branch'i merge ederek deneme **yapılmadı**. | Görev 4: "`lab/04b-untested` branch'indeki kodu al: testsiz yeni kod". Not: Community Build'de bu kod MR'dan yeşil geçer, `develop`'a girer ve kapı orada kalır; imaj üretilmez. Notta "yaklaşık 40 satır" yerine "yaklaşık 85 satır (31'i kapsanabilir)". | 4 ✔ |
| C2 | G2/8, G2/9, G2/15, G2/24, G3/14, G5/23 | Branch adları ve örnekler sabit numara taşıyor (`feature/3-…`, `MR !5`, `(#7)`, `feature/9-…`, `feature/12-…`). **Faz 3'te kesinleşti:** GitLab'de issue ve MR sayaçları ayrıdır ve her projede 1'den başlar. Yeni projede ilk issue `#1`, ilk MR `!1` oldu; lab sırasıyla issue'lar `#1` (stok), `#2` (hotfix hatası), `#3` (docker), MR'lar `!1`–`!7`. Slayttaki numaralar hiçbir doğal sırayla tutturulamıyor. | İki yoldan biri: (a) slaytlar değişmez, rehber "branch adını slayttaki gibi yaz, `Closes #…` satırında kendi numaranı kullan" der (şu an böyle); (b) slaytlardaki numaralar gerçek sıraya çekilir: `feature/1-stok-durumu`, `MR !1`, CHANGELOG'da `(#1)` ve `(#2)`, `feature/3-docker`. (b) izlenebilirlik mesajıyla (G2/20: "isim hangi işe ait olduğunu söylemeli") tutarlıdır; **Karar (2026-11-24): slaytlar değişmez, (a) sürer.** | 3 ✔ |
| C3 | G3/2, G3/17, G3/25 | `1.0.1` etiketli imajlar `v1.0.1` tag'inin commit'inden değil, o kodu içeren `feature/9-docker` commit'inden üretiliyor (Dockerfile'lar orada). **Faz 3'te ek bulgu:** lab akışında `1.0.1` etiketi iki kez gönderiliyor. İlk push 2. adımda; ardından `nginx.conf` tamamlanıyor ve SQLite Error 14 düzeltiliyor, imajlar yeniden üretilip `1.0.1` üzerine yazılıyor (ölçülen: `1.0.1` `sha256:cc6f…` → `sha256:ed8f…`; eski commit SHA etiketi eski imajı göstermeye devam ediyor). | G3/25 notuna: "`1.0.1` henüz dağıtılmadığı için labda üzerine yazılır; yayınlanmış bir SemVer etiketinin üzerine yazılmaz." G3/17'deki "Aynı etiketi tekrar push edersem?" sorusuna canlı örnek olur. İstenirse görev sırası değiştirilir: önce Compose ve lokal deneme (4–5), sonra push (2–3). | 3 ✔ |
| C4 | G3/12 | `COPY src/web-ui/package*.json ./` satırı `.npmrc` dosyasını imaja almıyor. **Faz 3'te kesinleşti:** lab çözümü `COPY src/web-ui/package*.json src/web-ui/.npmrc ./` kullanıyor; bu haliyle `npm ci` build içinde Nexus'tan kuruyor (üç ekip koşusunda build geçti). `.npmrc` kopyalanmadan build **denenmedi** (açık ağda `registry.npmjs.org`'a gidip sessizce geçeceği için sandbox'ta ayırt edici bir hata vermez). | Slayttaki satır: `COPY src/web-ui/package*.json src/web-ui/.npmrc ./`. | 3 ✔ |
| C5 | G5/20 | `TEST_URL` biçimi slaytta yok. | Karar: `TEST_URL=http://test-vm.<D>:808N`. Slayt notuna örnek değer eklenebilir. | 5 |
| C6 | G4/10, G4/13, G4/24 | Tek global bağlantı ile ekip token'ının birlikte kullanımı. **Faz 4'te kesinleşti (GitLab plugin 1.2169, SonarQube Scanner plugin 2.19.1):** ortak Jenkins'te global `gitlab` bağlantısı ve `sonarqube` sunucu tanımı token taşımaz; ekip kendi token'ını klasör credential'ı olarak ekler ve pipeline'da seçer. Slayttaki kısa yazımlar (`gitLabConnection('gitlab')`, `withSonarQubeEnv('sonarqube')`, `waitForQualityGate abortPipeline: true`) global token varsayar. | G4/13: `gitLabConnection(gitLabConnection: 'gitlab', jobCredentialId: 'gitlab-api', useAlternativeCredential: true)`. G4/24: `withSonarQubeEnv(installationName: 'sonarqube', credentialsId: 'sonar-token')` ve `waitForQualityGate abortPipeline: true, credentialsId: 'sonar-token'`. G4/10 2. adım: "bağlantı yönetici tarafından kurulur; token ekip klasöründe credential'dır". Kısa yazım korunacaksa (README §7 notu) kod bloğunun altına "ortak Jenkins'te uzun yazım" notu eklenmeli. | 4 ✔ |
| C7 | G1/14 notu | "`--vulnerable` ve `--outdated` ağ erişimi gerektirir." NuGet'in varsayılan güvenlik denetimi kaynağa ulaşamazsa `NU1900` uyarısı veriyor. **Faz 2'de kapandı:** Nexus `nuget-group` üzerinden restore 0 uyarıyla geçiyor, `NU1900` çıkmıyor. | Değişiklik gerekmez. | 2 ✔ |
| C8 | G3/14 (LAB 03-A), G3/18 | LAB 03-A temel imajları iç aynadan kullanır; Docker daemon'ına CA ise G3/18'de anlatılır ve LAB 03-B'de tanıtılır. **Karar (kullanıcı, 2026-11-24): temel imajlar eğitim makinelerine önceden yüklenir; slayt sırası korunur.** Faz 3'te doğrulandı: varsayılan builder (`docker` sürücüsü) yerel imajı kullanıyor, registry'ye bağlanmıyor; `--pull`, `docker-container` sürücülü builder ve `# syntax=` satırı ise registry'ye gidiyor (`kanit/faz-3/02-buildkit-onyukleme.txt`). | G3/14 notuna: "Temel imajlar makinelerde hazırdır; `--pull` kullanmayın." G3/3 notundaki ön hazırlık listesine: "temel imajlar eğitim makinelerine yüklendi mi?" | 3 ✔ |
| C9 | G3/18 | Slayttaki hata metni. **Faz 3'te kesinleşti:** `docker login` için gerçek çıktı slayttakiyle aynı: `Error response from daemon: Get "https://gitlab.kurum.test:5050/v2/": tls: failed to verify certificate: x509: certificate signed by unknown authority`. `docker pull` içinse baş taraf farklı: `failed to resolve reference "…": failed to do request: Head "https://…/manifests/10.0": tls: failed to verify certificate: x509: …`. `certs.d` çözümü daemon yeniden başlatılmadan etkili oldu. | Slayt `docker pull` yerine `docker login` gösterirse metin birebir tutar (lab da hatayı login'de yaşıyor). | 3 ✔ |
| C10 | G5/12 notu | Not, Community Edition'ın kullanım limitlerinden söz ediyor. Buna ek: Nexus Community Edition (3.98.3), lisans sözleşmesi (EULA) kabul edilmeden paket indirmeyi `403` ile reddediyor (`You must accept the End User License Agreement (EULA)…`); kullanım verisini de Sonatype'a gönderiyor. | Slayt notuna bir cümle: "Community Edition ilk kurulumda EULA onayı ister; onay verilmeden restore `403` döner." BELBİM'de ticari sürüm varsa geçerli değildir. | 5 |
| C11 | G2/15 (LAB 02-A) | Görev listesinde varsayılan branch ayarı yok. GitLab'de MR şablonu ve `Closes #N` ile issue kapatma **varsayılan branch**'e göre çalışır; varsayılan `main` kalırsa `develop` hedefli MR'da 5. görev (şablon) ve 7. görev (issue kapandı mı?) sessizce başarısız olur. Sabitlenen sürümün belgesi: issue yalnızca "merged into the default branch" olunca kapanır. Faz 3'te `develop` varsayılan yapılarak doğrulandı: şablon kendiliğinden geldi, issue merge ile kapandı. | 2. görev: "`develop`'u oluştur, varsayılan branch yap; `main` ve `develop`'u koru". G2/23'e not: hotfix `main`'e merge edilince issue kapanmaz, `develop`'a merge edilince kapanır (ölçüldü). | 3 ✔ |
| C12 | G2/15 (LAB 02-A) | 1. görev "lokal repoyu push et" diyor; dünkü `feature/katalog-sarj-unitesi` işinin `main`'e nasıl gireceği ve MR şablonunun ne zaman ekleneceği belirsiz. G2/24'teki CHANGELOG örneği `SRJ-04`'ü `1.0.0`'da sayıyor. | Rehber: 1. görevin başında dünkü branch `main`'e merge edilir ve `.gitlab/` dosyaları eklenir (korumadan önceki son doğrudan değişiklik). G2/15 notuna bir cümle eklenebilir. | 3 ✔ |
| C13 | G2/10 | Tablo sütunu "Push". GitLab 19.6 arayüzünde sütun adı "Allowed to push and merge"; sayfada "Protected branches is moving to Branch rules" duyurusu var. İlk push'ta `main` kendiliğinden korunur (Maintainers / Maintainers). | Sütun adı güncellenebilir; G2/15 notuna "`main` zaten listededir, push iznini değiştirin". | 3 ✔ |
| C14 | G3/9 | `.dockerignore` örneği `bin/`, `obj/`, `node_modules/` yazıyor. `.dockerignore` desenleri yalnızca context köküne göre eşleşir; bu haliyle `src/…/bin`, `src/…/obj` ve `src/web-ui/node_modules` context'e girer. Ölçülen: `**/` ile 378,2 MB → 604 KB. Slayttaki desenlerle ölçüm **yapılmadı**. | Örnek: `**/bin/`, `**/obj/`, `**/node_modules/`, `.git/`. | 3 ✔ |
| C15 | G3/12, G3/14 | `web-ui` Dockerfile'ı `deploy/nginx.conf` dosyasını kopyalar; dosya LAB 03-B'nin 4. görevine kadar iskelettir. LAB 03-A'nın 7. görevinde ("tek tek çalıştır") `web-ui` için çalışan bir Nginx ayarı gerekir. `/api` kuralları şimdiden yazılırsa imaj tek başına açılmaz (doğrulandı: `nginx: [emerg] host not found in upstream "product-service"`). | LAB 03-A 4. görev: "…Dockerfile'ını ve statik sunum için `nginx.conf` dosyasını yaz". LAB 03-B 4. görev "tamamla" olarak kalır. | 3 ✔ |
| C16 | G3/25 notu, G3/26 | Hata tablosu ve not `denied: requested access to the resource is denied` diyor. Docker 29.10.0 + GitLab 19.6.1'de bu metin **çıkmadı**. Gerçek çıktılar: giriş yapmadan push ya da pull → `error from registry: access forbidden`; `read_registry` token'ı ile push → `failed commit on ref "…": server message: insufficient_scope: authorization failed`. | Tabloda belirti sütunu: "`access forbidden` / `insufficient_scope` (eski sürümlerde `denied: …`)". LAB slaytındaki "“denied”: token scope'una bak" ipucu "yetki hatası: login ve token scope'una bak" olabilir. | 3 ✔ |
| C17 | G3/26, G3/13 | SQLite Error 14 satırı. İki ek: (1) Hata oluştuğunda `order-service` container'ı kapanmıyor, `docker compose ps` "Up" gösteriyor (sandbox'ta, arm64); belirti yalnızca logda ve `502` yanıtında. (2) Nottaki "named volume ilk bağlanışta bu sahipliği devralır" doğru; ama ilk denemede oluşan volume `root`'a ait kalır, Dockerfile düzeltildikten sonra `down -v` ile yeniden oluşturulmalıdır. | G3/26 çözüm sütununa: "…ve eski volume'u yeniden oluştur (`down -v`)". Nota: "container Up görünse de loga bakın". | 3 ✔ |
| C18 | G3/9, G3/17 | "İkinci build'de CACHED" doğru. Ek bulgu: BuildKit, bütün katmanlar cache'ten gelse de imaja yeni oluşturma zamanı yazar; aynı commit'ten art arda iki `docker build` iki farklı digest üretir (ölçüldü: `product-service` `sha256:62d1…` → `sha256:023c…`, kaynak aynı). | G3/15 ya da G3/17 notuna: "Aynı commit'i yeniden build etmek aynı digest'i vermez; imaj bir kez build edilir, sonra etiketlenir." 5. günün "tag build'i yeniden derlemez" kuralının gerekçesidir. | 3 ✔ |
| C19 | G3/24 | Lokal örnek `WEB_PORT=8081` ile `localhost:8081` gösteriyor; lab rehberi de böyle (eğitim makinesinde `WEB_PORT` ekip portu olarak tanımlı). `docker compose ps` çıktısında PORTS sütunu web-ui için `0.0.0.0:8081->8080/tcp, [::]:8081->8080/tcp` (IPv6 satırı da var). | Değişiklik gerekmez; blok "örnek çıktı" olarak kalabilir. | 3 ✔ |
| C20 | G4/10 (4. adım), G4/18 notu | "push ve merge request olayları; secret token". **Faz 4'te ölçüldü:** Multibranch Pipeline job'ı "Merge request events" isteğine `409 Merge Request Hook is not supported for this project` dönüyor (9 olayın 9'u); push olayları `200`. Secret token Multibranch job'da denetlenmiyor: yanlış token ile yapılan istek de `200` döndü. MR ekranındaki durum, MR'ın son commit'ine yazılan commit status'tan geliyor; MR olayına gerek yok. | G4/10 4. adım: "adres `<jenkins>/project/<klasör>/<job-adı>`; yalnızca push olayı". "secret token" ifadesi kaldırılmalı ya da "Multibranch job'da denetlenmez" notu düşülmeli. | 4 ✔ |
| C21 | G4/10 (1. adım), G4/7 | Token "GitLab API token" türünde saklanır. Multibranch job'ın repoyu okuması için aynı token ayrıca "Username with password" türünde de gerekir (Git plugin o türü ister). Yalnızca `api` scope'lu Project Access Token ikisine de yetiyor (ölçüldü). | G4/10'a bir cümle: "aynı token iki credential olarak kaydedilir: `gitlab-api` (GitLab API token) ve `gitlab-repo` (Username with password)". | 4 ✔ |
| C22 | G4/13 | İskelette `gitlabBuilds` yok. Onsuz build çalışırken GitLab'de durum görünmez (MR `ci_must_pass`); `gitlabBuilds(builds: ['jenkins'])` ile build başlarken `pending` yazılır (MR `ci_still_running`). `post` bloğunda `aborted` durumu da yok. Örnek adres `gitlab.kurum.local`; sandbox `kurum.test` kullanıyor (ortam dosyasından gelir, sorun değil). | `options` bloğuna `gitlabBuilds(builds: ['jenkins'])`; `post` bloğuna `aborted { updateGitlabCommitStatus name: 'jenkins', state: 'canceled' }`. | 4 ✔ |
| C23 | G4/16 | `docker build -f src/$s/Dockerfile -t $IMG/$s:$SHA .` komutunda `--build-arg` yok. İç ayna kullanılan ortamda .NET servisleri `--build-arg MCR=$MCR`, web-ui `--build-arg HUB=$HUB` ister (G3/14 ile aynı); argümanlar servise göre değiştiği için tek `for` döngüsü yetmiyor. Lab çözümü üç ayrı `docker build` satırı ve push döngüsü kullanıyor. | Blok güncellenmeli ya da nota "iç aynada `--build-arg` eklenir; LAB 04-B rehberine bakın". | 4 ✔ |
| C24 | G4/11, G4/18 | Starter'daki yalnızca yorum içeren `Jenkinsfile` de Multibranch taramasında "bulundu" sayılıyor: `develop` ve `main` için job açılıyor, build `SUCCESS` bitiyor ve GitLab'e durum yazmıyor. G4/18 notundaki "No Jenkinsfile found" sorusu bu starter ile yaşanmaz. | G4/18 notu: "Job açıldı ve yeşil ama hiçbir stage yok: `Jenkinsfile` henüz iskelet." | 4 ✔ |
| C25 | G4/25 notu, G4/29 | SonarQube 26.11, yerel ağ adresine webhook tanımını reddediyor (`Invalid URL: loopback … site-local …`); kurum içi Jenkins için yönetici `sonar.validateWebhooks=false` ayarını yapmalı. TLS doğrulamasıyla ilgisi yoktur. | G4/25 notuna bir cümle; `belbim-yoneticisinden-istenecekler.md` (Faz 6). | 4 ✔ |
| C26 | G4/24 "DİKKAT" | "waitForQualityGate executor tutmaz." Lab çözümünde `agent` pipeline'ın tepesinde tanımlı olduğu için bekleme sırasında agent'ın executor'ı ayrılmış kalır (bekleme bu ortamda 1–5 sn sürdü). Executor'ın bırakılıp bırakılmadığı **ölçülmedi**. | Değişiklik önerilmiyor; soru gelirse: "executor'ı bırakmak için Quality Gate stage'i `agent none` ile ayrı tutulur". | 4 |
| C27 | G4/22, G4/27 | SonarQube'da proje oluştururken ana branch adı sorulur (varsayılan `main`). Analiz `develop` build'inden gönderildiği için projede ana branch adı `develop` yazılmalı; yoksa `develop` analizi panoda `main` adıyla görünür (denenmedi; lab çözümü `develop` kullanıyor). Token türü: Project Analysis Token yeterli (analiz ve `waitForQualityGate` için ölçüldü). | G4/27 1. göreve not: "Main branch name: `develop`; token türü Project Analysis Token". | 4 ✔ |
| C28 | G5/9 | Aynı sürümün ikinci push'u için slayt `400 (Bad Request)` gösteriyor. **Faz 5'te ölçüldü (Nexus CE 3.98.3, .NET SDK 10.0.404):** `Conflict` ve `409 (nuget-hosted/Saha.Common.Contracts.Ekip01/1.0.0 - cannot be updated as asset already exists and redeploy is not allowed)`. İlk push çıktısı da `Created … Your package was pushed.` | Terminal bloğunda `409 (Conflict)`; nota "Nexus hatanın nedenini mesajda söyler: redeploy is not allowed". | 5 ✔ |
| C29 | G5/10, G5/13 | G5/10'daki örnek `Saha.Common.Contracts` (soneksiz); G5/13 notu ekip sonekini (`.Ekip01`) zorunlu tutuyor. Soneksiz kimlikte ilk yayınlayan ekip dışındakiler 409 alır. G5/10 notundaki "Dockerfile'daki `COPY src/common-contracts/` satırı da kalkar" doğrulandı: satır kalkınca imaj paketi Nexus'tan restore ediyor (agent'ta ve eğitim makinesinde). | G5/10 kod örneğinde `Include="Saha.Common.Contracts.Ekip01"`. | 5 ✔ |
| C30 | G5/13 notu | "API anahtarları ortam kartında." Sır kuralı gereği kartta ve rehberlerde anahtar yok. Her ekip kendi anahtarını Nexus arayüzünden alır: Nexus 3.98'de sağ üstteki hesap simgesi ("Account settings, tokens and keys") > "NuGet API Key" > "Access API Key" (parola yeniden sorulur). | Not: "API anahtarını her ekip Nexus'tan kendisi alır (hesap menüsü > NuGet API Key)." Anahtar sayfadaki kullanım komutlarına da yazılır: ekran paylaşırken dikkat. | 5 ✔ |
| C31 | G5/18, G5/23 notu | "Tag build'leri tag keşfi açıksa oluşur; otomatik başlaması build stratejisi ayarına bağlıdır." **Faz 5'te ölçüldü:** üç ayar birlikte gerekir: (1) job'da "Discover tags"; (2) build stratejileri: "Tags" **ve** "Regular branches" (yalnızca "Tags" eklenirse branch build'leri durur); (3) GitLab webhook'unda "Tag push events" (yoksa tag ancak bir sonraki branch push'unda keşfedilir). "Tags" stratejisinin yaş sınırı tag'in değil **tag'in gösterdiği commit'in** tarihine bakar: eski bir commit'e bugün atılan tag kendiliğinden build edilmedi (`No automatic build triggered`), yeni commit'e atılan edildi. | G5/18 notuna üç ayar; G5/23 notundaki "tag job'ı elle başlatılır" yedeği korunur. | 5 ✔ |
| C32 | G5/18 | `TAG_NAME` ve `buildingTag()` sabitlenen sürümlerde (Jenkins 2.580.2, branch-api 2.1303) çalışıyor: tag build'inde `TAG_NAME=v1.1.0`, `${TAG_NAME#v}` → `1.1.0`. | Değişiklik gerekmez. | 5 ✔ |
| C33 | G5/19 | "Release: aynı imaja SemVer etiketi eklenir (`docker tag … :1.1.0`)". Lab çözümü `docker pull` + `docker tag` + `docker push`; registry'de `1.1.0` ile SHA etiketinin digest'i aynı çıktı (iki ekipte). Tag build'i `main` build'inin SHA imajını bekler (en çok 5 dk); yoksa anlaşılır hatayla durur, yeniden derlemez. | Değişiklik gerekmez; nota "imaj yoksa tag build'i durur". | 5 ✔ |
| C34 | G5/20 | Deploy stage'i: (1) adresler ve `ekip01`, `8081` sabit yazılmış (eğitimde ortam kartından gelir); (2) test VM paylaşıldığı için ekibin registry girişi `DOCKER_CONFIG=/opt/saha/ekipNN/.docker` ile verilmeli (LAB 03-B, D42), slaytta yok; (3) README deploy kaydı istiyor (commit, etiket, digest), slaytta yok. Lab çözümü bu işleri `deploy/deploy.sh` betiğinde toplar: pull (etiket yoksa durur), `.env`, `up -d`, kayıt; Jenkins aynı betiği SSH ile çağırır, rollback'te katılımcı da. | Kod bloğu `ssh … "sh /opt/saha/ekipNN/deploy.sh $IMG $TAG $WEB_PORT …"` olarak kısaltılabilir; notta `deploy.sh`'nin üç işi. | 5 ✔ |
| C35 | G5/21 | Rollback `export TAG=1.0.1; docker compose up -d`. Bu sandbox'ta `.env` dosyası `TAG`'i taşıdığı için bir sonraki elle `up` eski değere döner; ayrıca `DOCKER_CONFIG` gerekir. Lab'da rollback `sh deploy.sh $IMG 1.0.1 $WEB_PORT - elle` ile yapılır (önce pull, `.env` güncellenir, kayıt düşer). `1.0.1` dönünce `GET /api/orders/summary` `404` döner: sürümün değiştiğinin non-destructive kanıtı. | Terminal bloğu korunabilir; nota `.env` ve `DOCKER_CONFIG`. | 5 ✔ |
| C36 | G5/22 | "web-ui hata mesajını gösterir": web-ui'de kod değişikliği gerekmiyor; `api.js` API'nin `error` alanını zaten gösteriyor (test: `src/api.test.js`). Tarayıcıda miktar 0 → "Miktar en az 1 olmalı." (`lab-05-b-arayuz-red.png`). | Görev metninde "web-ui'nin hata mesajını gösterdiğini doğrulayın". | 5 ✔ |
| C37 | G5/23 | Tek test ortamında sıra: `release/1.1.0` → `develop` geri birleştirmesi `develop` deploy'unu tetikler ve test VM'i SHA sürümüne çevirir. Tag geri birleştirmeden **sonra** atılmalı; yoksa test ortamında `v1.1.0` kalmaz. LAB 02-B'de sıra tersti (orada deploy yoktu). | 6. göreve not: "tag'i release'i develop'a geri aldıktan ve develop deploy'u bittikten sonra atın". | 5 ✔ |
| C38 | G5/11 | `Pack & Publish` stage'i: `configFileProvider` + `dotnet nuget push --configfile $NUGET_CFG --source nexus-hosted` .NET SDK 10.0.404'te çalıştı (managed file `nuget-config`). Notta "Paket değişip sürüm artırılmadıysa Nexus push'u reddeder ve pipeline kırılır": doğru; lab çözümü push'tan önce sürümün Nexus'ta olup olmadığına bakar ve anlaşılır mesajla durur (`HATA: Saha.Common.Contracts.Ekip02 1.0.1 Nexus'ta zaten var …`). Final `Jenkinsfile`'ında stage yoktur: LAB 05-A'da paket elle yayınlandığı için release sonrası ilk `main` build'i kırılırdı. | Nota: "Elle yayınlanmış bir sürüm varsa stage onu yeniden yayınlamaya çalışıp main'i kırar; bonusu yapan ekip sürümü artırır." | 5 ✔ |
| C39 | G5/15 | GitLab Package Registry yayını (eğitmen demosu) slayttaki komutlarla çalıştı: proje düzeyi adres `…/api/v4/projects/<id>/packages/nuget/index.json`, deploy token (`read_package_registry`, `write_package_registry`), `--store-password-in-clear-text`. `dotnet nuget push` bir `warn : No API Key was provided …` satırı yazıyor ama yayın başarılı (`Created …`). Demo kaynağı geçici bir `NuGet.Config`'te tanımlandı: kullanıcının kendi yapılandırmasına düz metin parola yazılmadı. | Nota: "uyarı satırı beklenir; kimlik kaynağın kullanıcı adı/parolasıyla gider"; demoda `--configfile` ile geçici dosya önerilir. | 5 ✔ |
| C40 | G5/20 | Smoke test satırı yalnızca `/api/products` için yeniden deneme içeriyor. Faz 5'te ikinci istek (`/api/orders`) yeniden denemesizken `502` ile kırıldı: Nginx ve `product-service` hazır, `order-service` henüz değil. Her istek `--retry` ile yapılmalı. | Kod bloğunda iki `curl` de `--retry 10 --retry-connrefused`. | 5 ✔ |

## D. Terminal blokları: gerçek çıktı durumu

| Slayt | Blok | Durum |
|---|---|---|
| G1/14 | `dotnet list … --include-transitive` | Alındı (B3) |
| G1/18 | `dotnet restore` NU1605 | Alındı (B1) |
| G1/22 | `git log --oneline --graph --all` | Alındı; aşağıda |
| G1/24 | conflict işaretleri | Alındı (B6) |
| G2/7 | `git clone` sertifika hatası | Faz 6 (`hata-senaryolari.md`). Eğitim makinesinde kurum CA'sı işletim sistemine kurulu olduğu için labda yaşanmıyor; Faz 3'te üretilmedi |
| G2/22 | `git push origin v1.0.0`, korumalı tag reddi | Alındı; aşağıda. Ret mesajı slayttakiyle aynı (tek satırda) |
| G2/26 | Korumalı branch'e push reddi | Alındı; aşağıda. Slayttaki metnin sonunda `on this project.` var |
| G3/17 | `docker login`, `docker push --all-tags` | Alındı; aşağıda (digest ve boyut mimariye bağlıdır; sandbox arm64). `size: 1787` yerine `size: 856` |
| G3/18 | `docker pull` x509 hatası | Alındı (C9) |
| G3/24 | `docker compose ps`, `curl …/api/products` | Alındı; aşağıda |
| G4/28 | Jenkins console: Quality Gate `ERROR` | Alındı; aşağıda. Slayttan farkı: önce `status is 'PENDING'` satırı var; `web-ui` stage'i de atlanıyor (lab sırasında Quality Gate'ten sonra gelir) |
| G5/9 | `dotnet pack`, `dotnet nuget push`, ikinci push | Alındı; aşağıda. İkinci push `409` (C28) |
| G5/15 | GitLab Package Registry'ye push | Alındı (C39; `kanit/faz-5/52-demo-gitlab-package-registry-ekip02.txt`) |
| G5/21 | `docker compose images`, rollback | Alındı; aşağıda (C35) |

G1/22 ve G1/26 için, LAB 01-B sonundaki gerçek grafik:

```
$ git log --oneline --graph
*   d82999c Merge remote-tracking branch 'origin/lab/01b-rename' into feature/katalog-sarj-unitesi
|\
| * 756affb feat(catalog): add fast charger
* | 0aa8066 feat(catalog): add charging unit
|/
* 174fe06 chore: starter project
```

`d82999c` ve `0aa8066` prova sırasında oluşan commit'lerdir; katılımcıda farklı olur. `174fe06` ve `756affb` starter repoda sabittir.

G2/22 ve G2/26 (ekip-01, `kanit/faz-3/lab-02-a-ekip01.txt`, `lab-02-b-ekip01.txt`):

```
$ git push origin develop
remote: GitLab: You are not allowed to push code to protected branches on this project.
To gitlab.kurum.test:egitim/ekip-01/saha-ekipman-portal.git
 ! [remote rejected] develop -> develop (pre-receive hook declined)
error: failed to push some refs to 'gitlab.kurum.test:egitim/ekip-01/saha-ekipman-portal.git'

$ git push origin v1.0.0            # Developer
remote: GitLab: You are not allowed to create this tag as it is protected.
To gitlab.kurum.test:egitim/ekip-01/saha-ekipman-portal.git
 ! [remote rejected] v1.0.0 -> v1.0.0 (pre-receive hook declined)
```

G3/17 (ekip-01, ilk push):

```
$ echo "$TOKEN" | docker login $REGISTRY -u ekip01-deploy --password-stdin
Login Succeeded
$ docker push --all-tags $IMG/order-service
1.0.1: digest: sha256:cc6f68d6220e580377ba5e02a986b014d5c4b0f04d51365b71bc6877ef8d495e size: 856
afd5969: digest: sha256:cc6f68d6220e580377ba5e02a986b014d5c4b0f04d51365b71bc6877ef8d495e size: 856
```

G3/24 (ikinci VM, ekip-01):

```
$ docker compose -p ekip01 ps
NAME                       IMAGE                                       SERVICE           STATUS
ekip01-order-service-1     …/saha-ekipman-portal/order-service:1.0.1     order-service     Up 1 second
ekip01-product-service-1   …/saha-ekipman-portal/product-service:1.0.1   product-service   Up 1 second
ekip01-web-ui-1            …/saha-ekipman-portal/web-ui:1.0.1            web-ui            Up 1 second (health: starting)
$ curl -fsS $TEST_URL/api/products | head -c 60
[{"code":"ADP-01","name":"Terminal adaptörü","inStock":tru
```

`web-ui` satırındaki `(health: starting)` çözümdeki `HEALTHCHECK` satırından gelir.

G4/28 için, LAB 04-B'de kapı kaldığında gerçek çıktı (ekip-01, `develop #4`; satır başındaki zaman damgaları atıldı):

```
[Pipeline] { (Quality Gate)
[Pipeline] timeout
Timeout set to expire in 10 min
[Pipeline] waitForQualityGate
Checking status of SonarQube task 'b56a5f73-a7f3-4c64-85e5-e63511bfb98a' on server 'sonarqube'
SonarQube task 'b56a5f73-a7f3-4c64-85e5-e63511bfb98a' status is 'PENDING'
SonarQube task 'b56a5f73-a7f3-4c64-85e5-e63511bfb98a' status is 'SUCCESS'
SonarQube task 'b56a5f73-a7f3-4c64-85e5-e63511bfb98a' completed. Quality gate is 'ERROR'
[Pipeline] { (web-ui)
Stage "web-ui" skipped due to earlier failure(s)
[Pipeline] { (Docker Build & Push)
Stage "Docker Build & Push" skipped due to earlier failure(s)
ERROR: Pipeline aborted due to quality gate failure: ERROR
Finished: FAILURE
```

SonarQube'daki karşılığı: `Quality gate: Failed` · `1 condition failed` · `6.7% Coverage is less than 80.0%` · `On 31 New Lines to cover` (`lab-rehberleri/img/lab-04-b-sonar-kapi-kaldi.png`).

G4/18 için, webhook testi ve MR ekranı: `Hook executed successfully: HTTP 200`; kırmızı durumda `Pipeline #11 failed` · `Merge blocked: 1 check failed` · `Pipeline must succeed.` (`lab-04-a-merge-engeli.png`).

G5/9 için gerçek çıktı (ekip-01, LAB 05-A):

```
$ dotnet nuget push out/Saha.Common.Contracts.Ekip01.1.0.0.nupkg --source https://nexus.kurum.test/repository/nuget-hosted/ --api-key "$NEXUS_APIKEY"
Pushing Saha.Common.Contracts.Ekip01.1.0.0.nupkg to 'https://nexus.kurum.test/repository/nuget-hosted/'...
  PUT https://nexus.kurum.test/repository/nuget-hosted/
  Created https://nexus.kurum.test/repository/nuget-hosted/ …ms
Your package was pushed.
# Aynı sürümü ikinci kez göndermek:
  Conflict https://nexus.kurum.test/repository/nuget-hosted/ 56ms
error: Response status code does not indicate success: 409 (nuget-hosted/Saha.Common.Contracts.Ekip01/1.0.0 -  cannot be updated as asset already exists and redeploy is not allowed).
```

## E. Slayt dışı: `README.md` (görev tanımı) için öneriler

Kararlar görev tanımındaki şu cümleleri geçersiz kıldı ya da eksik bıraktı; dosyaya dokunmadım.

- §6, `lab/01a-conflict`: "`order-service`, `common-contracts`'ın istediğinden daha düşük sürümde bir paketi doğrudan referans eder … (`Microsoft.Extensions.Logging.Abstractions` 10.0.0 → 9.0.0)". Yeni hali: "`order-service`, `Microsoft.EntityFrameworkCore.Sqlite`'ın istediğinden daha düşük sürümde `Microsoft.EntityFrameworkCore` paketini doğrudan referans eder (10.0.x → 9.0.x)".
- §4, adresler: "Hepsi HTTPS" ifadesi test VM'deki uygulama portlarını kapsamaz; `TEST_URL` düz HTTP ve ekip portudur.
- §6, hazır branch'ler: `checkpoint/*` listesine iki yardımcı branch eklendi: `checkpoint/lab-02a-main` ve `checkpoint/lab-02b-main`. Checkpoint branch'leri `develop`'un durumunu taşır; GitFlow'da `main`'in ucu `develop`'un geçmişinde bulunmadığı için ayrı tutulması gerekti.
- §8, LAB 02-A: "`develop` oluştur" adımına "varsayılan branch yap" eklenmeli (C11).
- §8, LAB 03-B: "registry `denied`" ifadesi bu sürümlerde `access forbidden` / `insufficient_scope` olarak çıkıyor (C16).
- §7, servisler: `dns` (Faz 2) ve `tarayici` (Faz 3, yalnızca komut çalışırken var olan Playwright aracı) listede yok.
- §8, LAB 02-A ve LAB 04-B: "iki akış yaz" (Free / Premium; `community` / `commercial`). **Karar (2026-11-24):** kullanılamayan lisanslı özellikler gösterilmez; rehberlerde yalnızca Free ve Community akışları vardır. Slayt G2/11, G2/12 ve G4/26'daki lisans karşılaştırmaları anlatım için yeterlidir; slaytta değişiklik gerekmez.
- §8, LAB 04-A doğrulama zinciri (1): "push ve MR olayı Jenkins'e ulaşıyor". Multibranch job MR olayını `409` ile reddediyor (C20); webhook yalnızca push olayıyla kurulur. Halka "push olayı Jenkins'e ulaşıyor; MR'ın durumu son commit'in commit status'undan geliyor" olarak doğrulandı.
- §4, Jenkins credential ID'leri: listeye `gitlab-api`, `gitlab-repo` ve `sonar-token` eklendi (C6, C21). Jenkins'in registry girişi için ayrı deploy token: `ekipNN-jenkins` (`gitlab-registry` credential'ı).
- §7, "Slayttaki sözdizimini (`gitLabConnection('gitlab')`, `withSonarQubeEnv('sonarqube')`) koru": ortak Jenkins'te kısa yazım ekibin token'ını bulamıyor; uzun yazım kullanıldı (C6). Bağlantı ve sunucu **adları** slayttaki gibi korunuyor.
- §6, `lab/04b-untested`: "en az 40 satır" → branch 85 satır ekliyor (31'i kapsanabilir satır); hazır branch `checkpoint/lab-03b` üzerine kurulu ve merge edilmiyor, dosyaları alınıyor (C1).

## F. Faz 6 temiz kurulum provasından düzeltmeler

- LAB 05-A Nexus paket ağacı: paket satırına çift tıklamak yerine soldaki **+** ile açın; `1.0.0` sürümüne **tek tıklayın**. Temiz Nexus’ta çift tıklama ağacı kapalı bırakabiliyordu; rehber ve tarayıcı adımı düzeltildi.
- LAB 03-A/03-B: container açılışından hemen sonraki salt okunur sağlık kontrollerinde `curl --retry 10 --retry-connrefused --retry-delay 2` kullanın. Başlangıç gecikmesi uygulama hatası diye gösterilmemeli; bilinçli hatalı POST istekleri yeniden denenmez.
- LAB 04-B: `ci/analyze.sh` için `chmod +x ci/analyze.sh` terminal bloğunda açıkça yer alır.
- LAB 05-B: deploy düzenlemesine başlamadan `develop` güncellenir ve `feature/deploy` açılır; tam komut bloğu eklendi. Her iki smoke GET isteğinde retry bulunur (C40).
- GitLab giden webhook URL reddi: bu sürümün API’sinde `422 {"error":"Invalid url given"}`; arayüzdeki “Url is blocked” ifadesiyle metin eşitliği beklemeyin.

C28–C40 kararları korunur: `409` yeniden yayın reddi; yeni paket sürümü `1.0.1`; tag, release’in develop’a geri birleşmesi ve deploy’undan sonra; `deploy/deploy.sh` tam metin; Pack & Publish ayrı bonus. Slayt dosyaları yeniden üretilmedi.

- LAB 04-B/05-B Jenkinsfile: ortak agent'ta `DOCKER_CONFIG = "${WORKSPACE}@tmp/docker-config"`; en dış `post/always` ile yalnızca bu dizindeki `config.json` temizlenir. Bir ekibin token’ının iptal edilmesi diğer ekiplerin registry erişimini bozmamalı; giriş dosyası build context’ine de girmemeli.
