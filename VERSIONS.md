# VERSIONS

Durum: **Faz 5 sonu** (2026-11-24). Faz 5'te yeni imaj ya da sürüm eklenmedi. Değişen: Jenkins controller imajı `belbim-lab/jenkins:faz5` (CasC'ye ortak `nuget-config` dosyası eklendi; taban imaj ve pluginler aynı) ve agent imajı `belbim-lab/jenkins-agent:faz5` (`MSBUILDDISABLENODEREUSE=1`; araç sürümleri aynı). Faz 4'te eklenenler: `ci` imajlarının digest'leri (§2), Jenkins plugin ve scanner sürümleri (§4), `ci` profilinin kaynak ölçümü (§6).

## 1. Parametreler

| Parametre | Değer | Kaynak |
|---|---|---|
| `LAB_DOMAIN` | `kurum.test` | Onaylandı. Host macOS; `.local` mDNS çözümleyicisine gidiyor. |
| `EKIP_SAYISI` | `2` (+ prova için `ekip-99`) | Varsayılan |
| `SONAR_PROFILE` | `community` | Varsayılan |
| GitLab katmanı | Free (CE) | Onaylandı; BELBİM lisansı bilinmiyor |
| Ekip hesapları | `ekipNN-lead` (Maintainer), `ekipNN-dev` (Developer) | Onaylandı |
| `TEST_URL` | `http://test-vm.<D>:808N` | Onaylandı |
| .NET hedef framework | `net10.0` | README §3 |
| Node.js | 24 LTS | README §3 |
| Mimari | `linux/arm64` (host'un yerel mimarisi) | Tüm imajların arm64 sürümü var; BELBİM büyük olasılıkla x86-64 |

## 2. Servis imajları

| Rol | İmaj | Not |
|---|---|---|
| GitLab CE | `gitlab/gitlab-ce:19.6.1-ce.0` | Çalıştırıldı. arm64 digest `sha256:d3727f8b1a1e…`. BELBİM sürümü bildirilirse o kullanılır. |
| Jenkins controller | `jenkins/jenkins:2.580.2-lts-jdk21` | arm64 `sha256:74401de6a6f9…`. Üzerine sabit sürümlü 89 plugin, Configuration as Code dosyası ve lab CA'sı eklenir (`lab-ortami/images/jenkins/`). Çalışan sürüm: 2.580.2. |
| Jenkins agent tabanı | `jenkins/inbound-agent:3396.ve02b_5cde31b_2-4-jdk21` | arm64 `sha256:4cdc9b77a15b…`. Üzerine .NET SDK 10.0.404, Node 24.22.3, Docker CLI 29.10.0 + buildx, `dotnet-sonarscanner` 12.1.0, `sonar-scanner` 8.5.0.16571 ve lab CA'sı eklenir. Controller'a WebSocket ile bağlanır. |
| SonarQube | `sonarqube:26.11.0.134175-community` | Community Build. arm64 `sha256:7b2296713a92…`. JVM güven deposuna lab CA'sı eklenir (Jenkins'e webhook için). |
| SonarQube veritabanı | `postgres:17.12-alpine3.24` | arm64 `sha256:f9cf3e1f0066…`. SonarQube 26.11 bu sürümle açıldı ve çalıştı (logda sürüm uyarısı yok). Desteklenen sürüm aralığı belgeden **doğrulanmadı**. |
| Nexus | `sonatype/nexus3:3.98.3` | Community Edition. Çalıştırıldı. `sha256:53ca1dc9580a…`. EULA kabulü olmadan paket indirmez. |
| Docker daemon (agent) | `docker:29.10.0-dind` | `sha256:4bbc7223f81d…`. Agent'ın daemon'ı (`agent-docker`) Faz 4'te bu imajla çalışıyor. workstation ve test VM, Docker ikili dosyalarını bu imajdan alır: Engine 29.10.0, Compose v5.7.1, buildx v0.39.0. |
| Reverse proxy | `nginx:1.31.9-alpine3.24` | Çalıştırıldı. `sha256:fb4658584bd9…`. TLS sonlandırma, registry `:5050`, GitLab SSH için TCP geçişi |
| Lab DNS | `coredns/coredns:1.15.0` | **Faz 2'de eklendi.** `sha256:0a9d8c8ddf34…`. İç içe Docker daemon'larındaki container'lar için lab adlarını çözer. |
| workstation / test VM / araclar tabanı | `ubuntu:noble-20261110` | `sha256:73b999393d07…`. Üzerine araçlar eklenir (`lab-ortami/images/`). |
| Tarayıcı aracı (arayüz adımları) | `mcr.microsoft.com/playwright:v1.65.1-noble` | **Faz 3'te eklendi.** arm64 `sha256:56be08aca06b…`. İçine `libnss3-tools` ve npm `playwright@1.65.1` eklenir (`lab-ortami/images/tarayici/`). Yalnızca komut çalışırken vardır; lab içeriği değildir. Lab CA'sı Chromium'un NSS deposuna eklenir. |
| workstation Node.js kaynağı | `node:24.22.3-bookworm-slim` | **Faz 2'de eklendi.** `sha256:dc26ae92c9fb…`. Yalnızca `node` ve `npm` kopyalanır (glibc derlemesi). |

## 3. Temel imajlar (`egitim/base` altında)

| İç ad (Dockerfile'da görünen) | Kaynak etiket | Ek |
|---|---|---|
| `egitim/base/dotnet/sdk:10.0` | `mcr.microsoft.com/dotnet/sdk:10.0.404` (`sha256:2b1e13a22e46…`) | Lab CA eklenir |
| `egitim/base/dotnet/aspnet:10.0` | `mcr.microsoft.com/dotnet/aspnet:10.0.15` (`sha256:aac50ceef103…`) | — |
| `egitim/base/library/node:24-alpine` | `node:24.22.3-alpine3.24` (`sha256:116b800c3754…`) | Lab CA eklenir; `NODE_EXTRA_CA_CERTS` ayarlanır |
| `egitim/base/nginxinc/nginx-unprivileged:stable-alpine` | `nginxinc/nginx-unprivileged:1.31.7-alpine3.24` (`sha256:b5047b9b7684…`) | — |

### Katılımcı makinesine önceden yüklenen temel imajlar (Faz 3)

LAB 03-A için dört temel imaj `workstation`'ın Docker daemon'ına bootstrap sırasında yüklenir (`bootstrap/35-workstation-imajlar.sh`; tablo: `bootstrap/temel-imajlar.tablo`). `latest` yoktur; etiketler aşağıdaki sabit kaynak sürümleri gösterir. Değerler arm64 içindir (`kanit/faz-3/01-temel-imaj-onyukleme.txt`).

| Makinedeki ad (`MCR` / `HUB` = `gitlab.kurum.test:5050/egitim/base`) | Kaynak sürüm | Registry'deki manifest digest'i | Makinedeki imaj kimliği (`docker load` sonrası) |
|---|---|---|---|
| `…/dotnet/sdk:10.0` | `mcr.microsoft.com/dotnet/sdk:10.0.404` | `sha256:c761b1d0f1acf5ed598d7a94f5e40ea2398b3eaff6be304832a630dbfa5db770` | `17691e344e15` |
| `…/dotnet/aspnet:10.0` | `mcr.microsoft.com/dotnet/aspnet:10.0.15` | `sha256:2002c8f9b83df8925c6b273c7d39cf48b39898058fe9234d73d36f7b5b978811` | `9484cb26f9fe` |
| `…/library/node:24-alpine` | `node:24.22.3-alpine3.24` | `sha256:1002babad2d4bfa723cedf62ac3f02bc2be59d8d2b5ce6aa0b006d67810b49e0` | `459e32c18a03` |
| `…/nginxinc/nginx-unprivileged:stable-alpine` | `nginxinc/nginx-unprivileged:1.31.7-alpine3.24` | `sha256:e05a7b295f344531cb861af0efd10dae5907496a275b2e9d206e6efaf540911e` | `2d9ed44554d1` |

Makinedeki kimlik registry digest'inden farklıdır: imaj `docker pull` ile değil arşivden yüklenir ve containerd image store manifesti yeniden üretir. Bu yüzden "aynı imaj mı?" denetimi digest ile değil, katman kimlikleriyle (`RootFS.Layers` = registry'deki `rootfs.diff_ids`) yapılır; eşitse yeniden yüklenmez. Bir imaj sonradan registry'den çekilirse (LAB 03-B'den sonra) kimliği registry digest'ine döner, katmanlar aynı kalır.

Taşıma paketi (`make temel-imaj-paketi DIZIN=…`): dört `.tar`, toplam 1,48 GB (sdk 978 MB, aspnet 266 MB, node 170 MB, nginx 62 MB) ve `SHA256SUMS`.

Slaytlardaki Dockerfile'lar `10.0`, `24-alpine`, `stable-alpine` etiketlerini kullanır. İç kopyada bu adlar korunur, arkalarındaki kaynak sürüm burada sabitlenir. Her iç kopya `lab.kaynak` (kaynak etiket) ve `lab.ca` (CA parmak izi) etiketlerini taşır; `make bootstrap` bunlara bakarak güncel olanı yeniden göndermez. İç kopyalar yalnızca host'un mimarisi için gönderilir (sandbox'ta `linux/arm64`).

Düzeltme: Faz 0'da "`stable-alpine` etiketinin bu sürümü gösterdiği doğrulanacak" yazmıştım. Buna gerek kalmadı: iç kopya doğrudan sabit sürümden (`1.31.7-alpine3.24`) üretiliyor, Docker Hub'daki `stable-alpine` etiketi kullanılmıyor.

## 4. Araç ve paket sürümleri

| Araç | Sürüm | Not |
|---|---|---|
| .NET SDK (workstation, agent) | 10.0.404 | workstation'da çalıştırıldı (Faz 2). Faz 1 kanıtları host'taki 10.0.102 ile alınmıştı |
| Node.js (workstation, agent) | 24.22.3 (npm 11.19.1) | workstation'da çalıştırıldı (Faz 2) |
| git (workstation) | 2.43.0 | Ubuntu noble paketi |
| skopeo (araclar) | Ubuntu noble paketi | Temel imajları registry'ye gönderir |
| Jenkins pluginleri | 89 plugin, tam sürümlerle: `lab-ortami/images/jenkins/plugins.txt` | 20'si doğrudan istenen, 69'u bağımlılık. Öne çıkanlar: `gitlab-plugin` 1.2169.v80265e3a_2f4d, `sonar` 2.19.1, `workflow-aggregator` 608.v67378e9d3db_1, `configuration-as-code` 2147.v8a_8d38668c72, `git` 5.11.0, `credentials` 1514.vb_01eb_014e7d4, `cloudbees-folder` 6.1107.v31f8955765c8, `matrix-auth` 3.3, `junit` 1458.1460.vd53b_087eeb_2c. `make dogrula-ci` kurulu sürümleri dosyayla karşılaştırır (fark yok) |
| `dotnet-sonarscanner` (agent) | 12.1.0 | `dotnet tool`, `/opt/dotnet-tools`; LAB 04-B'de kullanıldı |
| `sonar-scanner` CLI (agent) | 8.5.0.16571 | `/opt/sonar-scanner`; kurulu, henüz kullanılmadı (React analizi bonusu) |
| Docker (agent daemon'ı ve CLI) | 29.10.0, buildx v0.39.0 | Agent'taki build'ler varsayılan `docker` sürücüsüyle |

NuGet paketleri (starter, `.csproj` içinde tam sürüm):

| Paket | Sürüm | Nerede |
|---|---|---|
| `Microsoft.AspNetCore.OpenApi` | 10.0.15 | product-service, order-service |
| `Swashbuckle.AspNetCore.SwaggerUI` | 11.0.1 | product-service, order-service |
| `Microsoft.EntityFrameworkCore.Sqlite` | 10.0.15 | order-service |
| `Microsoft.EntityFrameworkCore` | 9.0.23 | yalnızca `lab/01a-conflict` (bilinçli çakışma) |
| `Microsoft.AspNetCore.Mvc.Testing` | 10.0.15 | testler |
| `Microsoft.NET.Test.Sdk` | 18.12.0 | testler |
| `xunit` | 2.9.3 | testler |
| `xunit.runner.visualstudio` | 3.1.5 | testler |
| `JunitXml.TestLogger` | 8.1.0 | testler |
| `coverlet.collector` | 10.1.1 | testler |

npm paketleri (starter, `package.json` aralığı; kurulan tam sürüm `package-lock.json` içinde):

| Paket | Kurulan sürüm |
|---|---|
| `react`, `react-dom` | 19.3.1 |
| `vite` | 8.3.8 |
| `@vitejs/plugin-react` | 6.3.0 |
| `jest`, `babel-jest`, `jest-environment-jsdom` | 30.5.2 |
| `jest-junit` | 17.0.0 |
| `@babel/core` | 7.29.13 |
| `@babel/preset-env` | 7.29.14 |
| `@babel/preset-react` | 7.29.7 |
| `@testing-library/react` | 16.3.3 |
| `@testing-library/dom` | 10.4.2 |
| `@testing-library/jest-dom` | 8.0.0 |
| `@testing-library/user-event` | 14.6.13 |

## 5. Host (2026-11-23 ölçümü)

| Özellik | Değer |
|---|---|
| İşletim sistemi | macOS 27.2.1, arm64 |
| CPU | Apple M3 Max, 16 çekirdek |
| RAM | 64 GB |
| Boş disk | 399 GB (Faz 0 ölçümü) |
| Docker | Docker Desktop, Engine 28.1.1, Compose v2.35.1 |
| Docker'a ayrılan kaynak | 16 CPU, **24 GB RAM** (23,93 GiB; Faz 4 başında kullanıcı 16,5 GB'tan çıkardı, K16). |
| Docker'daki diğer yük | Faz 2 sırasında 3 container: `hyprena-frontend`, `hyprena-backend`, `kind-registry` (toplam ≈ 0,2 GB). Kullanıcı Faz 2'den önce diğerlerini kendisi durdurdu. |
| Dolu host portu | `8080` (hyprena-frontend). `8081` şu an boş, ama `kafka-lab-gun3` açılırsa dolar. |
| `/etc/hosts` | `gitlab.local`, `sonar.local`, `jenkins.local` kayıtları başka bir çalışmadan mevcut; `kurum.test` kayıtları yok (kullanıcı adımı). |

### Host port eşlemesi

Portlar yalnızca `127.0.0.1` üzerinde yayınlanır. Container içindeki portlar slaytlardaki gibidir.

| Servis | Container portu | Host portu | `.env` anahtarı |
|---|---|---|---|
| proxy: HTTPS (GitLab, Nexus, Jenkins, SonarQube) | 443 | 443 | `HOST_HTTPS_PORT` |
| proxy: Container Registry | 5050 | 5050 | `HOST_REGISTRY_PORT` |
| proxy: GitLab SSH | 22 | 2222 | `HOST_GITLAB_SSH_PORT` |
| test-vm: ekip uygulamaları | 8081–8090 | 18081–18090 | `HOST_TESTVM_PORTS` |
| test-vm: prova ekibi `ekip-99` | 8099 | 18099 | `HOST_TESTVM_PROVA_PORT` |
| workstation: Vite | 5173 | 5173 | `HOST_WORKSTATION_VITE_PORT` |
| workstation: `8080` | 8080 | 18080 | `HOST_WORKSTATION_WEB_PORT` |

## 6. Kaynak: ölçülen ve planlanan

### Çekirdek profil, ölçüm (2026-11-23, Faz 2)

Kaynak: `kanit/faz-2/06-make-durum.txt` ve `08-bellek-tepe.txt`. Ölçüm temiz kurulumdan yaklaşık 10 dakika sonra, `make dogrula` koşarken `docker stats` ile yaklaşık 7 saniyede bir alındı (14 örnek). GitLab'in belleği açık kaldıkça artar; bu değerler alt sınıra yakındır.

| Servis | Bellek sınırı | Boşta | Doğrulama sırasında tepe | Not |
|---|---|---|---|---|
| gitlab | 6 GB | 3,4 GiB | 3,4 GiB | Tek ekip, kısa süre |
| nexus | 3 GB | 1,6 GiB | 1,6 GiB | Heap 1–1,5 GB |
| workstation | 4 GB | 1,0 GiB (çoğu sayfa önbelleği) | 1,8 GiB | Tek ekip: `dotnet build/test`, `npm ci`, Jest |
| test-vm | 2 GB | 0,25 GiB | 0,4 GiB | SDK container'ında restore |
| proxy | 128 MB | 9 MiB | 9 MiB | |
| dns | 128 MB | 15 MiB | 47 MiB | İlk sınır 64 MB idi, %74'ü görüldü; yükseltildi |
| **Toplam** | **≈ 15,3 GB** | **≈ 6,3 GiB** | **≈ 7,3 GiB** | Tepeler aynı anda olmayabilir |

Ölçülmeyenler: iki ekibin aynı anda derlemesi; `docker build` (Faz 3); uzun süre açık kalmış GitLab.

| Volume | Boyut (temiz kurulum + doğrulama sonrası) |
|---|---|
| `gitlab-data` | 1,14 GB |
| `nexus-data` | 344 MB (proxy önbelleği: starter'ın NuGet ve npm paketleri) |
| diğerleri (8 volume) | toplam 6 MB'tan az; ekip ev dizinleri ve iç Docker daemon'ları henüz boş |

İmajlar diskte: GitLab 5,4 GB, Nexus 1,8 GB, workstation 1,8 GB, .NET SDK 1,35 GB, test-vm 0,6 GB, araclar 0,4 GB. Temel imajların host'taki kopyaları (`belbim-lab/base:*`) ≈ 2 GB.

Süreler (imajlar önbellekteyken): `make up` 117 sn (GitLab'in ilk açılışı 86 sn), `make bootstrap` 52 sn, ikinci `make bootstrap` 8 sn, `make dogrula` ≈ 100 sn. İmajların ilk indirilmesi bu sürelere dahil değildir.

### Çekirdek profil, Faz 3 sonu (2026-11-24)

Kaynak: `kanit/faz-3/12-make-durum.txt`. Ortam 6 saat açık kaldıktan, iki ekiple altı lab ve checkpoint testleri koşulduktan sonraki anlık değerler (boşta).

| Servis | Bellek sınırı | Faz 2 (boşta) | Faz 3 sonu (boşta) | Not |
|---|---|---|---|---|
| gitlab | 6 GB | 3,4 GiB | 3,85 GiB | 1 ekip projesi (ekip-02 sıfırlandı), 7 MR, registry'de ekip-01'in 10 imaj etiketi |
| nexus | 3 GB | 1,6 GiB | 1,57 GiB | |
| workstation | 4 GB | 1,0 GiB | 1,94 GiB | İç Docker: 21 imaj, 4,8 GB build önbelleği |
| test-vm | 2 GB | 0,25 GiB | 0,39 GiB | ekip-01 uygulaması çalışıyor (3 container) |
| proxy + dns | 256 MB | 24 MiB | 23 MiB | |
| **Toplam** | **≈ 15,3 GB** | **≈ 6,3 GiB** | **≈ 7,8 GiB** | Docker'a ayrılan: 15,35 GiB |

Lablar sırasındaki tepe değer **ölçülmedi** (örnekleme yapılmadı); `docker build` ve tarayıcı aracı (2 GB sınırlı, geçici) çalışırken toplam bunun üzerindedir. Faz 3 boyunca host yanıt vermeme ya da yeniden başlama yaşanmadı (çalışma süresi 6 sa 17 dk, gözlenen en yüksek yük ortalaması ≈ 8).

| Volume | Faz 2 | Faz 3 sonu |
|---|---|---|
| `gitlab-data` | 1,14 GB | 1,48 GB |
| `nexus-data` | 344 MB | 355 MB |
| `workstation-docker` | ≈ 0 | 6,59 GB (temel imajlar 1,5 GB + ekip imajları + build önbelleği) |
| `workstation-home` | ≈ 0 | 1,39 GB (iki ekibin reposu, `node_modules`, paket önbellekleri) |
| `testvm-docker` | ≈ 0 | 718 MB |
| `workstation-docker-etc` | — | 2 kB (**yeni volume:** katılımcının eklediği `certs.d` container yeniden yaratılınca kaybolmasın) |

Süreler (Faz 3): `make bootstrap` tekrar 37 sn; temel imajların ilk yüklenmesi 29 sn, tekrarında 3 sn; üç imajın boş önbellekle ilk build'i 9 + 6 + 8 sn; tarayıcı imajının ilk indirilmesi bu makinede ≈ 45 dk sürdü (yavaş bağlantı; 1 GB'tan büyük tek katman).

### `ci` profili, Faz 4 ölçümü (2026-11-24; Docker VM 23,93 GiB)

| Servis | Bellek sınırı | Boşta (açılıştan sonra) | Gün 4 labları koşulduktan sonra | Not |
|---|---|---|---|---|
| jenkins | 2 GB | 0,82 GiB | 0,71 GiB | Controller executor 0 |
| jenkins-agent | 3 GB | 0,14 GiB | 0,31 GiB; build sırasında gözlenen en yüksek **1,87 GiB** | 2 executor; `dotnet build`/`test` ve `npm` burada çalışır |
| agent-docker | 3 GB | 0,10 GiB | 0,56 GiB | Üç imajın build önbelleği birikir |
| sonarqube | **4 GB** (3 GB'tan çıkarıldı) | 2,30 GiB | 1,85–2,73 GiB | 3 GB sınırla iki ekibin analizinden sonra %88'e çıkmıştı |
| sonar-db | 512 MB | 0,11 GiB | 0,11 GiB | |

Bütün lab (çekirdek + `ci`, iki ekip): boşta ≈ 8,8 GiB; Gün 4 labları sırasında dakikalık örneklemeyle **en yüksek 13,7 GiB** (`kanit/faz-4/izleme.log`, 107 örnek); host boş bellek oranı en düşük %50, swap kullanımı 0. Sınırların toplamı 28,8 GB'tır; 24 GB'lık Docker VM'inde bugüne kadar sınırlara yaklaşılmadı. **Ölçülmeyen:** on ekibin aynı anda build etmesi (sandbox iki ekiple koşuyor; agent 2 executor'lı olduğu için aynı anda en çok iki build çalışır, diğerleri kuyrukta bekler).

Faz 5 (2026-11-24, iki ekip; Gün 5 labları ve checkpoint'ler): bütün lab dakikalık örneklemeyle en yüksek 14,0 GiB / 23,93 GiB (`kanit/faz-4/izleme.log`); host boş bellek oranı en düşük %53, swap 0. Süreler: `checkpoint lab-05a` 13 dk 45 sn (host yükü 14–23 iken) ve 46 sn–2 dk (yük düşükken); `checkpoint final` 9 dk 19 sn (yüklü); LAB 05-A çözümü tek seferde 93 sn, LAB 05-B 290 sn (yük düşükken). Host yükünün bir kısmı lab dışından geliyordu (oyun uygulaması, pil modu); süreler bu yüzden geniş aralıklı.

Süreler (Faz 4): `ci` profilinin açılışı ≈ 75 sn; feature build'i (restore, build, test, web-ui) 8–11 sn; `develop` build'i (analiz, kapı, üç imaj, push) 18–24 sn, önbellek sıcakken; ilk `develop` build'i 46 sn. `checkpoint lab-04b` 52 sn. LAB 04-A çözümü tek seferde 156 sn. LAB 04-B çözümünün tek seferde koşusu 718 sn sürdü, ama bu süre **geçerli bir ölçüm değil**: koşunun ortasında host pilde uyku döngüsüne girdi (`pmset` kaydı: 13:49'dan itibaren art arda "Maintenance Sleep").

### Faz 6 temiz-volume prova ölçümü (2026-11-24)

Kaynak sürümleri değişmedi. 11-24 18:53–11-24 19:50 aralığında 55 örnek: toplam lab en çok **13.80 GiB / 23,9 GiB**, host boş bellek en az %57, gözlenen swap 0. Son ortamda 11 serviste restart=0 ve OOM=false. Ölçüm ilk koşunun LAB 03-A civarında başladı; son boş-volume kurulumunu, on labı ve checkpoint/sıfırlama regresyonunu kapsar, on ekiple eşzamanlı yük ölçümü değildir. [Kanıt](kanit/faz-6/kaynak-kullanimi.log). Son on lab otomasyon toplamı 1273 sn (21 dk 13 sn); kurulum ve insanla süre ölçümü dahil değil.
