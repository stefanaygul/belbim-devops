# Lab kuralları

Bu dosya `README.md` §4 (değişmez adlandırmalar) ve §12 (çalışma kuralları) bölümlerinin çalışma kopyasıdır. Çelişki olursa: LAB slaytı > `README.md` > bu dosya. İki bilinçli sapmada (SonarQube `community` kapsamı, pipeline tablosunda `main` / tag `v*` ayrımı) `README.md` slayttan önce gelir.

## 1. Değişmez adlandırmalar (README §4)

`D` = `LAB_DOMAIN`, `NN` = iki haneli ekip numarası (`01`, `02`, … `99`).

### Adresler

| Servis | Adres |
|---|---|
| GitLab | `https://gitlab.D` |
| Container Registry | `gitlab.D:5050` |
| Jenkins | `https://jenkins.D` |
| SonarQube | `https://sonar.D` |
| Nexus | `https://nexus.D` |
| Test VM | `test-vm.D` |

Dört servis arayüzü ve registry HTTPS ve lab CA'sının imzaladığı sertifikayla. Ağın içinden ve host tarayıcısından aynı URL kullanılır. Test VM'deki uygulama portları düz HTTP'dir: `TEST_URL=http://test-vm.D:808N` (onaylı karar).

Sandbox'ta `LAB_DOMAIN=kurum.test`.

### GitLab

- Grup: `egitim`
- Ekip alt grupları: `egitim/ekip-01`, `egitim/ekip-02`, …
- Her ekipte proje: `egitim/ekip-NN/saha-ekipman-portal`
- Şablon proje: `egitim/sablonlar/portal-starter`
- Temel imajlar: `egitim/base`
- Ekip hesapları: `ekipNN-lead` (alt grupta Maintainer), `ekipNN-dev` (Developer)

### Uygulama

- Solution: `SahaPortal.sln`
- `src/product-service`, `src/order-service`, `src/web-ui`, `src/common-contracts`
- `tests/`
- `deploy/compose.yaml`, `deploy/nginx.conf`
- `ci/analyze.sh`
- Kökte: `Jenkinsfile`, `NuGet.config`, `README.md`, `CHANGELOG.md`
- `.gitlab/CODEOWNERS`, `.gitlab/merge_request_templates/Default.md`

### İmajlar

- `IMG=gitlab.D:5050/egitim/ekip-NN/saha-ekipman-portal`
- İmaj adları: `product-service`, `order-service`, `web-ui`
- Etiketler: SemVer (`1.0.1`) ve kısa commit SHA

### Jenkins

- Agent label: `dotnet-docker`
- GitLab connection adı: `gitlab`
- SonarQube sunucu adı: `sonarqube`
- Credential ID'leri: `gitlab-registry`, `nexus-nuget-key`, `test-vm-ssh`; Faz 4'te eklenenler: `gitlab-api`, `gitlab-repo`, `sonar-token` (§8)
- Managed file: `nuget-config`
- Ekip klasörü: `ekip-NN`; Multibranch job: `saha-portal-ekipNN`
- Ortam değişkenleri: `REGISTRY`, `IMG`, `TEST_URL`

### SonarQube

- Proje anahtarı: `saha-portal-ekipNN` (bonus: `saha-portal-ekipNN-web-ui`)
- Webhook: `https://jenkins.D/sonarqube-webhook/` (sondaki `/` zorunlu)

### Nexus

- Depolar: `nuget.org-proxy`, `nuget-hosted`, `nuget-group`, `npm-proxy`, `npm-hosted`, `npm-group`
- Hosted depolarda redeploy kapalı
- Paket kimliği: `Saha.Common.Contracts.EkipNN`, ilk sürüm `1.0.0`

### Test VM

- Kullanıcı: `deploy`
- Dizin: `/opt/saha/ekipNN/`
- Compose proje adı: `ekipNN`
- `WEB_PORT` ekip başına sabit: ekip-01 → `8081`, ekip-02 → `8082`, …

### Sürüm çizgisi

`v1.0.0` (LAB 02-B) → `v1.0.1` hotfix (LAB 02-B) → `1.0.1` imajları (LAB 03-B) → `v1.1.0` (LAB 05-B)

## 2. Slaytlardan gelen diğer sabit adlar

LAB slaytlarında geçtiği için bunlar da değiştirilmez.

- Lab kimlikleri ve süreleri: 01-A 70 dk, 01-B 80 dk, 02-A 80 dk, 02-B 80 dk, 03-A 95 dk, 03-B 95 dk, 04-A 90 dk, 04-B 100 dk, 05-A 75 dk, 05-B 140 dk
- Branch'ler: `feature/katalog-sarj-unitesi`, `feature/3-stok-durumu`, `release/1.0.0`, `hotfix/1.0.1`, `feature/9-docker`, `feature/12-miktar-dogrulama`, `release/1.1.0`
- Hazır branch'ler: `lab/01a-conflict`, `lab/01b-rename`, `lab/04b-untested`
- Checkpoint'ler: `checkpoint/lab-01a`, `checkpoint/gun1`, `checkpoint/lab-02a`, `checkpoint/lab-02b` (= `checkpoint/gun2`), `checkpoint/lab-03a`, `checkpoint/lab-03b` (= `checkpoint/gun3`), `checkpoint/lab-04a`, `checkpoint/lab-04b` (= `checkpoint/gun4`), `checkpoint/lab-05a`, `checkpoint/final`
- Katalog: `ADP-01` Terminal adaptörü, `KBL-02` Bağlantı kablosu, `STD-03` Cihaz standı; LAB 01-B'de `SRJ-04` "Şarj ünitesi"; LAB 02-A'da `inStock` alanı
- Commit status adı: `jenkins` (aynı commit için tek ad); repoda `.gitlab-ci.yml` bulunmaz
- Deploy token kullanıcı adı: `ekipNN-deploy`
- Dockerfile argümanları: `ARG MCR`, `ARG HUB`; uygulama portu `8080`; `USER $APP_UID`; `nginx-unprivileged`
- Compose: `${IMG}`, `${TAG}`, `${WEB_PORT:-8080}:8080`, volume `orders-data` → `/data`, `ConnectionStrings__Orders=Data Source=/data/orders.db`
- NuGet kaynak anahtarları: `nexus` (group, repodaki `NuGet.config`), `nexus-hosted` (Jenkins managed file)

## 3. Çalışma kuralları (README §12)

1. **Sır yazma.** Parola ve token'lar `.env` içinde üretilir, `.gitignore`'dadır; rehberlere ve repolara gerçek değer girmez.
2. **TLS doğrulamasını "çözüm" olarak kapatma** (`sslVerify false`, `insecure-registries`, `-k`). Bunlar yalnızca eğitmenin olumsuz örnek demolarında yer alır.
3. **Yalnızca `belbim-lab` Compose projesine dokun.** Volume silme, `docker system prune` gibi yıkıcı işlemlerden önce kullanıcıya sor. Host'taki başka container, volume ve imajlara dokunma.
4. **Üç deneme kuralı.** Bir şey üç denemede çalışmıyorsa dur; denediklerini ve seçenekleri yaz, kullanıcıya sor.
5. **Kararları kaydet.** Karar ve varsayımlar `RAPOR.md` içinde tutulur; slaytlarla her uyuşmazlık oraya ve `slayt-guncellemeleri.md` dosyasına eklenir.
6. **Gerçek veri yok.** Gerçek BELBİM verisi, müşteri bilgisi ya da ödeme senaryosu kullanılmaz.

## 4. Diğer bölümlerden gelen bağlayıcı kurallar

- Hiçbir imajda `latest` yok; kullanılan her imajın tam etiketi `VERSIONS.md` içinde (§3).
- Emin olunmayan API, ayar yolu ya da komut seçeneği için sabitlenen sürümün resmi belgesine bakılır; tahmin edilmez (§3).
- Host'un Docker soketi hiçbir container'a bağlanmaz; tam üç Docker daemon vardır: agent, workstation, test VM (§7).
- Portlar yalnızca `127.0.0.1` üzerinde yayınlanır (§7). Host'ta dolu olan portlar için farklı host portu kullanılır ve ortam kartına yazılır; container içindeki portlar slaytlardaki gibi kalır. Host'taki başka projelerin container'ları durdurulmaz.
- Öğrencinin labda yapacağı adımlar bootstrap'te yapılmaz; yalnızca `checkpoint-uygula.sh` ve `prova.sh` otomatikleştirir (§7).
- `checkpoint-uygula.sh` yalnızca ilgili ekibin kaynaklarına dokunur; paylaşılan servislerde global sıfırlama yapmaz (§6).
- Rehberlere adres gömülmez; `lab.env` değişkenleri kullanılır (§9).
- Çalıştırılmayan hiçbir adım "doğrulandı" diye yazılmaz. Durum etiketleri: `IMPLEMENTED`, `LOCALLY_TESTED`, `SANDBOX_VERIFIED`, `INTEGRATION_VERIFIED` (yalnızca kullanıcı verir), `BLOCKED`, `FAILED` (§10).
- `integration` modunda hiçbir servis kurulmaz ya da yeniden yapılandırılmaz; yalnızca denetlenir (§2, §14).
- Dil: rehberler Türkçe, teknik terimler slaytlardaki gibi İngilizce; kod, commit mesajı ve dosya adları İngilizce/ASCII (§2).
- Her fazın sonunda dur, özet ve kanıt göster, onay bekle (§11).

## 5. Onaylı ek kararlar

- NU1605 örneği EF Core ile üretilir: `lab/01a-conflict` içinde `Microsoft.EntityFrameworkCore` 9.x doğrudan referansı. `RestoreEnablePackagePruning=false` kullanılmaz; `common-contracts` paket bağımlılığı taşımaz.
- LAB 04-B'de testsiz kod squash ile değil, `git checkout lab/04b-untested -- <yol>` ve katılımcının kendi commit'iyle alınır.
- Arayüz adımları Playwright ile yapılır: tarayıcıya lab CA'sı tanıtılır, sertifika hataları yok sayılmaz; betik adımları öğrenci rehberindeki adımlarla aynıdır.
- Lab ortasındaki rol değişimi için eğitmenin çalıştıracağı betik yalnızca ilgili ekibe dokunur.
- Mimariden etkilenen çıktılar (imaj boyutu, digest) `RAPOR.md` içinde işaretlenir; sandbox arm64'tür.
- Starter repoda kökte `Directory.Build.props` / `Directory.Packages.props` bulunmaz (Dockerfile katman sırası bunu gerektirir).
- Starter repodaki commit'ler `Egitim Ortami <egitim@kurum.test>` kimliği ve sabit tarihlerle atılır.

## 6. Faz 2'de yerleşen kurallar (sandbox)

- `egitim`, `egitim/sablonlar`, `egitim/sablonlar/portal-starter` ve `egitim/base` public'tir (1. gün klonlama ve temel imaj çekme kimlik bilgisi istemez); `egitim/ekip-NN` private'tır.
- Nexus'ta ekip başına tek hesap: `ekipNN` (rol `lab-yayinci`). Okuma anonimdir.
- Ekip parolaları dosyaya yazılmaz; `.env` içindeki `LAB_SECRET` değerinden türetilir (`bootstrap/lib.sh: ekip_parola`, `make parolalar`).
- Lab CA'sına güven: `workstation` işletim sistemi ve test VM'in Docker daemon'ı güvenir; `workstation`'ın Docker daemon'ı güvenmez (katılımcı `certs.d` altına ekler).
- Test VM'e yalnızca ekip SSH anahtarıyla girilir; `deploy` kullanıcısının parolası ve `sudo` yetkisi yoktur.
- Prova ekibi `ekip-99` için `WEB_PORT` `8099`'dur.
- Host portları: `443`, `5050` aynı; GitLab SSH `2222`; test VM `18081`–`18090` ve `18099`; workstation `5173` ve `18080`.
- Nexus Community Edition EULA'sı ve telemetri bildirimi yalnızca `.env` içinde `NEXUS_CE_EULA_KABUL=evet` / `NEXUS_CE_TELEMETRI_ONAY=evet` yazıyorsa işaretlenir. Kullanıcı 2026-11-23'te onay verdi.
- Sırlar komut satırına yazılmaz: curl yapılandırma dosyası, standart giriş ya da credential helper kullanılır.
- Host'ta çalışan betikler bash 3.2 uyumludur (macOS); API çağrıları `araclar` container'ında yapılır.
- Scratchpad klasörü yeniden başlatmada silinir; sonraki fazlarda gereken ara çıktılar (ör. slayt metinleri) proje içinde tutulur.

## 7. Faz 3'te yerleşen kurallar

- **Temel imajlar katılımcı makinesine önceden yüklenir** (kullanıcı kararı, 2026-11-24). Slayt sırası korunur: Dockerfile ve multi-stage LAB 03-A'da, kurum CA'sı ve `x509` LAB 03-B'de. Yükleme idempotenttir; `latest` yoktur; etiket ve digest'ler `VERSIONS.md` §3'tedir. Ön yükleme temiz kurulumda çalışmazsa geçici çözüm üretilmez; raporlanır ve CA adımını LAB 03-A'nın başına almak değerlendirilir.
- Rehberlerde `docker build --pull` ve Dockerfile'da `# syntax=` satırı kullanılmaz (ikisi de registry'ye gider).
- GitLab'de ekip projesinin varsayılan branch'i `develop`'tur (MR şablonu ve `Closes #N` buna bağlıdır).
- Issue ve MR numaraları gerçek değerleriyle kullanılır (`#1`, `#2`, `#3`; `!1`…); branch adları slaytlardaki gibi kalır.
- Checkpoint branch'leri `develop`'un durumunu taşır; `main`'in durumu `checkpoint/lab-02a-main` ve `checkpoint/lab-02b-main` branch'lerindedir. Branch'ler `lab-ortami/checkpoint/uret.sh` ile üretilir; elle commit atılmaz.
- `checkpoint-uygula.sh`, `sifirla-ekip.sh` ve `rol-degistir.sh` yalnızca verilen ekibin kaynaklarına dokunur. Bilinen istisna: sandbox'ta `workstation` Docker daemon'ı ortaktır; `checkpoint lab-03b` ona kurum CA'sını tanıtır.
- Checkpoint, ekibin çalışma kopyasını silmez; `~/yedek/` altına taşır. `sifirla-ekip` onay ister.
- Test VM paylaşılır: her ekip registry girişini `DOCKER_CONFIG=/opt/saha/ekipNN/.docker` altında tutar.
- Deploy token adları: `ekipNN-deploy` (read + write registry), `ekipNN-pull` (yalnızca read).
- Arayüz adımları `tarayici` servisinde (Playwright) yapılır; lab CA'sı tarayıcıya tanıtılır, sertifika hataları yok sayılmaz. Token değerleri ekran görüntüsüne ve çıktıya girmez.
- Sandbox'ta iki rol tek Linux kullanıcısını paylaşır: `rol lead` / `rol dev`.
- Gerçek hata metinleri kullanılır: bu sürümlerde registry yetki hataları `access forbidden` ve `insufficient_scope` olarak çıkar (slayttaki `denied` değil).
- Bu makinede `make` ve `diff` kabukta gölgelidir; betikler ve kanıt komutları `/usr/bin/make`, `/usr/bin/diff` kullanır.
- **Kullanılamayan lisanslı özellikler gösterilmez** (kullanıcı kararı, 2026-11-24): rehberlerde GitLab Premium/Ultimate akışı (approval rules, Code Owners zorunluluğu) ve SonarQube ticari sürüm akışı (branch / MR analizi) yer almaz. Slaytlardaki anlatım yeterlidir. LAB 02-A tek akıştır; LAB 04-B yalnızca Community akışıyla yazılır.

## 8. Faz 4'te yerleşen kurallar

- Jenkins ortaktır: global `gitlab` bağlantısı ve `sonarqube` sunucu tanımı token taşımaz. Ekip token'ları yalnızca ekip klasöründe (`ekip-NN`) credential olarak durur; sistem düzeyinde credential eklenmez.
- `Jenkinsfile` içinde uzun yazım kullanılır: `gitLabConnection(gitLabConnection: 'gitlab', jobCredentialId: 'gitlab-api', useAlternativeCredential: true)`, `withSonarQubeEnv(installationName: 'sonarqube', credentialsId: 'sonar-token')`, `waitForQualityGate abortPipeline: true, credentialsId: 'sonar-token'`. Bağlantı ve sunucu adları slayttaki gibidir.
- Credential ID'leri ve türleri: `gitlab-api` (GitLab API token), `gitlab-repo` (Username with password; aynı Project Access Token), `sonar-token` (Secret text; Project Analysis Token), `gitlab-registry` (Username with password; deploy token `ekipNN-jenkins`).
- Proje webhook'u: `$JENKINS_URL/project/ekip-NN/saha-portal-ekipNN`, **yalnızca Push events**, SSL verification açık, secret token boş (Multibranch job MR olayını `409` ile reddeder, secret token'ı denetlemez).
- Aynı commit için tek durum adı: `jenkins`. Repoda `.gitlab-ci.yml` bulunmaz. Build başlarken `pending` yazılır (`gitlabBuilds(builds: ['jenkins'])`).
- SonarQube Community: analiz ve Quality Gate yalnızca `develop` build'inde (`when { branch 'develop' }`); `sonar.branch.name` gönderilmez; proje ana branch adı `develop`. Sunucu adresi ve token `ci/analyze.sh` içinde yer almaz.
- `lab/04b-untested` merge edilmez: dosyaları `git checkout sablon/lab/04b-untested -- src/order-service` ile alınır ve katılımcının kendi commit'iyle gönderilir. Taban analiz ondan önce yapılmış olmalıdır.
- İmaj yalnızca `develop` ve `main` build'lerinde, commit SHA etiketiyle üretilir; build'ler `--build-arg MCR=$MCR` / `HUB=$HUB` ile iç aynayı kullanır (değerler Jenkins'in ortak ortam değişkenleridir).
- Gün 4 branch adları: `feature/pipeline`, `feature/sonar`, `feature/siparis-ozeti`, `feature/siparis-ozeti-testleri`; issue'lar `#4` (pipeline) ve `#5` (SonarQube).
- `ekip-ci.sh` yalnızca ekibin Jenkins klasörünün içine, `saha-portal-ekipNN` SonarQube projesine ve ekip projesindeki Jenkins bağlantısına dokunur. Ortak agent'ı durduran tek komut `ci-durum.sh agent offline`'dır; `cozum.sh` onu yalnızca `KUYRUK=1` ile çağırır.
- Doğrulama betikleri Jenkins ve SonarQube'u ekip kullanıcısıyla, salt okunur sorgular; parolalar standart girişten aktarılır.
- Uzun koşular `caffeinate -i` ile başlatılır (host uykuya geçerse süre ölçümleri bozulur).

## 9. Faz 5'te yerleşen kurallar

- Paket kimliği ekibe özeldir: `Saha.Common.Contracts.EkipNN`, ilk sürüm `1.0.0`. Restore `nuget-group`'tan, yayın `nuget-hosted`'a. Hosted depoda redeploy kapalıdır (ikinci yayın `409`).
- NuGet API anahtarını her ekip Nexus arayüzünden kendisi alır; kartta, rehberde, ekran görüntüsünde ve çıktıda değeri yer almaz. Anahtar görüntüye girecekse sayfadaki bütün metin düğümlerinden önce silinir; sızıntıda `ekip-nexus.sh anahtar-yenile`.
- Deploy: `deploy/deploy.sh` (test VM'de; pull → `.env` → `up -d` → `deploy-kayit.log`). Jenkins'in `Deploy: test` stage'i ve elle rollback aynı betiği kullanır. Jenkins'in anahtarı ayrı üretilir (`jenkins-ekipNN`), kişisel anahtar Jenkins'e konmaz.
- Pipeline'ın son hali: Deploy ve smoke test `develop` (TAG = commit SHA) ve tag build'inde (TAG = SemVer); tag build'i imajı yeniden derlemez, `main` build'inin SHA imajına SemVer etiketi ekler; imaj yoksa en çok 5 dk bekleyip anlaşılır hatayla durur. Tek durum adı `jenkins`.
- Tag build'i için: job'da "Discover tags" + build stratejileri "Regular branches" ve "Tags" (en çok 1 günlük); webhook'ta "Tag push events". Tag, `release` → `develop` geri birleştirmesinden ve `develop` deploy'undan sonra atılır (tek test ortamı).
- Final görevinin branch'i `feature/12-miktar-dogrulama` (slayttaki ad), issue `#7`; LAB 05-A branch'i `feature/ortak-paket`, issue `#6`; deploy branch'i `feature/deploy`.
- Checkpoint'ler ekibin Jenkins job'ını XML ile oluşturur; XML, arayüzün ürettiği yapıyla aynı olmalıdır (`owner reference="../.."` satırları); oluşturulduktan sonra `setSourcesList` + `save` ile denenir.
- Bonus `Pack & Publish` final `Jenkinsfile`'ında yoktur (LAB 05-A'da paket elle yayınlandığı için `main` kırılırdı).

