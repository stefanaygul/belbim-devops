# RAPOR

Son güncelleme: 2026-11-24 · **Faz 5 (Gün 5 labları) tamamlandı; onay bekliyor.** Özet, kanıtlar ve doğrulanmayanlar §18'de. Faz 4 onaylandı (K17).

## 1. Faz 3 özeti

Gün 1–3'ün altı labı için öğrenci rehberi, eğitmen çözüm rehberi, çözüm betiği, doğrulama betiği ve checkpoint yazıldı. Altı labın tamamı **ekip-01** ile öğrenci akışı izlenerek koşuldu: komut satırı adımları `workstation`'da, arayüz adımları gerçek tarayıcıda (Playwright; lab CA'sı tanıtılmış, sertifika hatası yok sayılmadan). Checkpoint'ler, sıfırlama ve rol değişimi **ekip-02** üzerinde denendi. Volume silinmedi, ortam yeniden kurulmadı; host bu fazda yanıt vermeme ya da yeniden başlama yaşamadı.

### Lab doğrulama sonuçları

| Lab | Öğrenci akışı (ekip-01) | Doğrulama betiği | İkinci koşu | Checkpoint (ekip-02) |
|---|---|---|---|---|
| 01-A | Koşuldu; arayüz adımı ekip-01'de yapılmadı (tarayıcı aracı o sırada hazır değildi) | 13 / 13 | ekip-02, sıfırlamadan sonra baştan, arayüz adımıyla: 13 / 13 | `lab-01a`: 13 / 13 |
| 01-B | Koşuldu | 11 / 11 | ekip-02: 11 / 11 | `gun1`: 11 / 11 |
| 02-A (A akışı) | Koşuldu; 2 MR, rol değişimi dahil | 23 / 23 | — | `lab-02a`: 16 / 16 (MR geçmişi denetlenmez) |
| 02-B | Tek seferde koşuldu; 4 MR, 2 tag | 17 / 17 | — | `lab-02b`: 13 / 13 |
| 03-A | Tek seferde koşuldu | 36 / 36 | ekip-02, `checkpoint/lab-02b`'den başlayarak: 36 / 36 | `lab-03a`: 36 / 36 |
| 03-B | Koşuldu | 34 / 34 | — | `lab-03b`: 33 / 33, iki kez uygulandı |

Her labın sonunda ekip-01'in kodu ilgili checkpoint ile karşılaştırıldı: `develop`, `main` ve `v1.0.0` ağaçları checkpoint'lerle aynı (ekibe özel `.gitlab/CODEOWNERS` dışında).

**Tek seferde koşu (Faz 3 onayından sonra, K14):** Gün 2–3'ün dört labı ekip-02 ile arka arkaya, kesintisiz koşuldu: `cozum.sh 02-a` (114 sn) → 23 / 23, `02-b` (91 sn) → 17 / 17, `03-a` (32 sn) → 36 / 36, `03-b` (45 sn) → 34 / 34. Her labın sonunda ağaçlar checkpoint'lerle aynı; bütün olumsuz denetimler (push reddi, tag reddi, kırmızı test, `x509`, `access forbidden`, `insufficient_scope`, SQLite Error 14) yeniden üretildi. `x509`'un yaşanması için koşudan önce `workstation` Docker'ındaki `certs.d` kaydı kaldırıldı; koşu yeniden ekledi (`kanit/faz-3/30-tek-seferde-ekip02.txt`).

Faz sonunda altı doğrulama, betiklerin son haliyle ekip-01 üzerinde yeniden koşuldu: 13, 11, 23, 17, 36 (bir düzeltmeden sonra; S12) ve 34 denetimin tamamı geçti (`20-kapanis-dogrulamalari.txt`).

Kanıt: `kanit/faz-3/lab-XX-Y-ekip01.txt` (çözüm adımları ve doğrulama), `checkpoint-ekip02.txt`, `sifirla-ekip-yalitim.txt`; ekran görüntüleri `lab-rehberleri/img/` (70 dosya).

### Olumsuz → olumlu denetimler

Her biri önce beklenen hatayı üretti, sonra düzeltmeyle geçti.

| Senaryo | Hata (gerçek çıktı) | Düzeltmeden sonra |
|---|---|---|
| NU1605 (01-A) | `error NU1605: … Detected package downgrade: Microsoft.EntityFrameworkCore from 10.0.15 to 9.0.23`, çıkış kodu 1 | restore, build, 9 test (iki ekipte) |
| Merge conflict (01-B) | `CONFLICT (content): Merge conflict in …/catalog.json` | testler yeşil, merge commit'i (iki ekipte) |
| Test, katalog değişince (01-B) | 1 test kırmızı (`Expected: […"STD-03"]`, `Actual: […"SRJ-04"]`) | test güncellenince yeşil |
| Korumalı branch'e push (02-A) | `You are not allowed to push code to protected branches on this project.` (Developer ve Maintainer, `main` ve `develop`: 4 / 4) | MR ile merge |
| Açık thread varken merge (02-A) | `Merge blocked: … Open threads must be resolved.` | thread çözüldü, merge edildi |
| Developer merge edemez (02-A) | Arayüzde düğme yok; API `401 Unauthorized`, `can_merge=false` | Maintainer merge etti |
| Rol değişimi (02-A) | `ekip01-lead` (Developer olunca) merge edemedi | `ekip01-dev` (Maintainer olunca) merge etti; roller geri alındı |
| Korumalı tag (02-B) | `You are not allowed to create this tag as it is protected.` | Maintainer `v1.0.0` ve `v1.0.1`'i attı |
| Boş ekipman kodu (02-B) | Yeni test 2 / 2 kırmızı (`Expected: BadRequest`, `Actual: Created`); `v1.0.0`'da istek `201` | `v1.0.1`'de `400`, geçerli talep `201` |
| Docker ve kurum CA'sı (03-B) | `docker login` → `x509: certificate signed by unknown authority` | `certs.d` ile `Login Succeeded`; TLS doğrulaması kapatılmadı |
| Registry yetkisi (03-B) | Login olmadan push → `access forbidden`; `read_registry` token'ı ile push → `insufficient_scope: authorization failed` | doğru token ile push; iki etiket aynı digest |
| İkinci VM'de pull (03-B) | `error from registry: access forbidden` | `read_registry` token'ı ile pull ve `up` |
| SQLite Error 14 (03-B) | `SQLite Error 14: 'unable to open database file'`; arayüzde "Veriler yüklenemedi" | `/data` sahipliği + volume yeniden oluşturma; talep, container'lar yeniden yaratılınca duruyor (lokalde ve test VM'de) |
| Temel imaj ön yüklemesi | `denetle`: 4 imaj eksik, çıkış 1; ön kontrol: imaj yokken `KALDI` | yüklemeden sonra `denetle` 0; ön kontrol 37 / 37 |
| Doğrulama betiklerinin kendisi | `lab-01-a`: `node_modules` yokken `KALDI`; `lab-02-a`: sıfırlanmış ekipte `KALDI` | durum düzelince geçti |

### Temel imajların önceden yüklenmesi (koşulların 1–6'sı)

| Koşul | Sonuç | Kanıt |
|---|---|---|
| 1. Bootstrap yüklesin; sürümler sabit, `latest` yok; tag ve digest kayıtlı | `bootstrap/35-workstation-imajlar.sh` (bootstrap adımı `ws-imajlar`). İmaj registry'den alınıp `docker load` ile yüklenir; daemon ayarına dokunulmaz. Tag, kaynak sürüm, registry digest'i ve makinedeki kimlik `VERSIONS.md` §3'te | `kanit/faz-3/01-temel-imaj-onyukleme.txt` |
| 2. İdempotent | İlk yükleme 29 sn; ikinci çalıştırma 3 sn, dört imaj "yüklü, güncel". Karşılaştırma katman kimlikleriyle yapılır (yüklenen imajın digest'i registry'dekinden farklı çıkar) | aynı dosya; `11-bootstrap-ve-checkpoint-tekrar.txt` |
| 3. BuildKit davranışı | Boş build önbelleğiyle, LAB 03-A'nın gerçek üç `docker build` komutu geçti (9 / 6 / 8 sn), çıktıda `x509` yok. `--pull` → `x509`. `docker-container` sürücülü builder → `x509`. Eski builder → geçti. `# syntax=` → Docker Hub'a gitti. **Sonuç: güvence yalnızca varsayılan builder için geçerli**; ön kontrol builder sürücüsünü denetliyor | `02-buildkit-onyukleme.txt` (17 / 17) |
| 4. LAB 03-B'de `x509` üretilip CA ile çözülsün | ekip-01'de yaşandı ve `certs.d` ile çözüldü; `insecure-registries` kullanılmadı (doğrulama betiği denetliyor) | `lab-03-b-ekip01.txt` |
| 5. BELBİM'e taşınabilir; ön kontrol | `dogrula/workstation-onkontrol.sh`: yalnızca `lab.env`, bash ve Docker ister. `make temel-imaj-paketi` dört `.tar` + `SHA256SUMS` üretir (1,48 GB). Sandbox'ta iki yönlü denendi; **sandbox dışında çalıştırılmadı** | `03-workstation-onkontrol.txt`, `04-temel-imaj-paketi.txt` |
| 6. Güvenilir çalışmazsa geçici çözüm üretme | Sorun çıkmadı; geçici çözüm yok. Sınırı: ortamın **tamamı** bu adımla birlikte temiz kurulumda yeniden koşulmadı (yıkıcı test yapılmadı); yükleme, imajsız ve önbelleksiz bir daemon'da ve tekrar çalıştırmalarda denendi | §2 |

### Checkpoint, sıfırlama, rol değişimi

- **`bootstrap/checkpoint-uygula.sh <ekip> <lab>`**: altı checkpoint ekip-02'ye sırayla uygulandı ve her biri ilgili doğrulamayı geçti; `lab-03b` iki kez uygulandı (tekrar çalıştırılabilir). `checkpoint/lab-02b`'den başlayan ekip-02, LAB 03-A çözümünü kendi koşup doğrulamayı geçti: checkpoint çalışılabilir bir başlangıç noktası.
- **`make sifirla-ekip`**: ekip-02 sıfırlandı. ekip-01'in durumu (GitLab, registry, test VM, workstation; 77 satırlık döküm) öncesi ve sonrası **aynı**; ekip-01'in test VM'deki uygulaması çalışmaya devam etti. İkinci kez çalıştırma da sorunsuz. Sıfırlanan ekip LAB 01-A'yı baştan koşup doğrulamayı geçti.
- **`bootstrap/rol-degistir.sh`**: ekip-02'de değiştir / geri al denendi, ekip-01 etkilenmedi; LAB 02-A'da ekip-01 üzerinde gerçek akışta kullanıldı.
- **Checkpoint üretimi tekrarlanabilir:** `checkpoint/uret.sh` iki kez çalıştırıldı, 10 branch'in SHA'ları aynı.
- **`make bootstrap` tekrar çalıştırıldı** (37 sn, hiçbir şey yeniden oluşturulmadı); **`make dogrula`** lablardan sonra 99 / 99.
- **Sır taraması:** 16 sır değeri ve token desenleri 206 dosyada (rehberler, kanıtlar, betikler, starter repo ve git geçmişi) arandı; bulgu yok.

## 2. Faz 3'te doğrulanmayanlar ve yalnızca yazılanlar

**Doğrulanamayan (ortam sınırı):**

- ~~LAB 02-A B akışı (GitLab Premium).~~ **Kapsamdan çıkarıldı (K13):** kullanılamayan lisanslı özellikler rehberlerde yer almıyor; B akışı öğrenci ve eğitmen rehberinden silindi.
- **x86-64:** her şey arm64'te koştu.
- **BELBİM ortamı:** doğrulama betikleri, ön kontrol ve imaj paketi sandbox dışında çalıştırılmadı.

**Yazıldı, bu haliyle çalıştırılmadı:**

- **`cozum.sh 02-a` ve `cozum.sh 03-b` tek seferde.** *Güncelleme (K14): Faz 3 onayından sonra ekip-02 ile koşuldu; sonuç §1'in sonunda.* Bu iki labın adımları ekip-01'de tek tek koşuldu (arayüz otomasyonu geliştirilirken, bazı adımlar düzeltilip yeniden denenerek). Adımların tamamı çalışıyor; ama `lab_02_a` ve `lab_03_b` işlevleri baştan sona kesintisiz bir kez koşulmadı. `01-a`, `01-b`, `02-b`, `03-a` tek seferde koşuldu. Faz 6'daki `prova.sh` bunu ortaya çıkaracak; daha erken görmek istersen ekip-02 ile koşabilirim.
- **Temiz kurulum.** `make up && make bootstrap` bu fazdaki eklemelerle (`ws-imajlar` adımı, `workstation-docker-etc` volume'u, `tarayici` imajı) sıfırdan koşulmadı; yıkıcı test yapmamam istendiği için. `workstation` container'ı bir kez yeniden yaratıldı (volume'lar korundu) ve bootstrap adımları yeniden çalıştırıldı.
- **`dogrula/cekirdek.sh` içinde değişen üç denetimin "yeni kurulum" yönü.** Lablardan sonraki yön koştu (99 / 99); `certs.d` yokken ve ekip projesi yokken çalışan dallar bu değişiklikten sonra koşmadı (Faz 2'deki eski halleri koşmuştu).
- **`sifirla-ekip`'in onay sorusu.** Betik `EVET=1` ile çalıştırıldı; etkileşimli soru denenmedi.
- **`EKIP_SAYISI` > 2 ve `ekip-99`.** Betikler destekliyor; denenmedi.
- **Checkpoint'in, öğrencinin elle kurduğu bir projenin üzerine uygulanması.** ekip-02'de proje hep checkpoint ile kurulmuştu; ekip-01'e (gerçek MR geçmişi olan proje) checkpoint uygulanmadı.

**Rehberlerle ilgili:**

- **Rehberleri bir insan izlemedi.** Çözüm betikleri rehberdeki komutları çalıştırır; ama dosya içeriklerini yazmak yerine checkpoint branch'inden alır. İskelet ve ipuçlarının bir katılımcıya yetip yetmediği ve süre dağılımı ölçülmedi.
- **Arayüz adımları rehberle aynı ekranlarda, aynı sırayla yapıldı;** tıklama düzeyinde iki fark var: MR açıklaması düz metin kipinde doldurulur, proje adı tuş tuş yazılır.
- **"Yaygın hatalar" tablolarının bir kısmı üretilmedi.** Üretilenler: NU1605, conflict, push reddi, tag reddi, açık thread, `x509` (login ve `--pull`), `access forbidden`, `insufficient_scope`, SQLite Error 14 (tek container ve Compose), `host not found in upstream`, `# syntax=`, `node_modules` eksikliği. Üretilmeyenler (ör. `non-fast-forward`, `Permission denied (publickey)`, README'li proje, `manifest unknown`, port çakışması, `NU1301`, yanlış build context) Faz 6'daki `hata-senaryolari.md` kapsamında.
- **G2/7'deki `git clone` sertifika hatası** üretilmedi: eğitim makinesinde kurum CA'sı işletim sistemine kurulu.
- **Host tarayıcısı:** Vite'ın `--host` ile host tarayıcısından açılması denenmedi (tarayıcı aracı `workstation`'ın ağ alanında çalışır).

## 3. Faz 3'te karşılaşılan sorunlar

| # | Sorun | Ne oldu | Sonuç |
|---|---|---|---|
| S1 | `sifirla-ekip` proje silemedi | GitLab: `Cannot rename or delete project because it contains container registry tags`. Betik GitLab adımında durdu; test VM ve workstation'a dokunmadı | Düzeltildi: önce registry etiketleri silinir. İkinci koşu geçti. Testte bulundu |
| S2 | `checkpoint-uygula` üç hata | (a) macOS bash 3.2'de `$( case … )` sözdizimi; (b) GitLab boş projeye ilk push'ta `main`'i kendiliğinden koruyor, betik korumayı yeniden kuramadı (`409`); (c) checkpoint sonrası `npm ci` yapılmamıştı, doğrulama `KALDI` verdi | Üçü de düzeltildi; ham çıktılar `checkpoint-ekip02.txt` içinde duruyor |
| S3 | Registry hata metinleri slayttan farklı | `denied: requested access…` hiç çıkmadı; `access forbidden` ve `insufficient_scope` çıktı | Betikler ve rehber gerçek metne göre yazıldı; `slayt-guncellemeleri.md` C16 |
| S4 | `order-service` hata verince kapanmıyor | SQLite Error 14'ten sonra container "Up" kalıyor. Bir deneme komutum bu yüzden 10 dakika asılı kaldı; container'ı elle sildim | Rehberlere yansıtıldı ("Up ≠ sağlıklı"); nedeni araştırılmadı (R23) |
| S5 | Arayüz otomasyonu | Yeni GitLab arayüzünde (work items, "rapid diffs") seçiciler tahmin edilemedi. `proje-olustur` üçüncü, `mr-yorum` **dördüncü** denemede çalıştı | "Üç deneme" kuralını `mr-yorum`'da bir kez aştım: üçüncü başarısızlıktan sonra çalışan bir deneme betiğiyle farkı (sayfa yüklenmeden etkileşim) bulmuştum ve sormadan dördüncüyü denedim. Lab içeriğiyle değil otomasyon betiğiyle ilgiliydi; yine de bilmen gerekir |
| S6 | Lokal Compose portu | `WEB_PORT` eğitim makinesinde ekip portu olarak tanımlı; lokal Compose `8080` yerine `808N` yayınlıyor | Rehber `http://localhost:$WEB_PORT` kullanıyor |
| S7 | `git log --grep` merge commit'ini buldu | GitLab merge commit'ine MR başlığını da yazıyor; "düzeltme iki branch'te mi?" komutu yalnızca `origin/main` gösterdi | Komuta `--no-merges` eklendi; doğru sonuçla yeniden koşuldu |
| S8 | Kabukta `diff` bozuk | Yalıtım testinde "FARK VAR" yazdı; neden, bu makinedeki zsh'te `diff` adının gölgelenmiş olmasıydı | `/usr/bin/diff` ile fark yok. Kanıt dosyasında iki koşu da duruyor |
| S9 | Tarayıcı imajının indirilmesi ≈ 45 dk | 1 GB'tan büyük tek katman, yavaş bağlantı | Bu sırada tarayıcı gerektirmeyen işler yapıldı. İlk kurulum süresine eklenmeli |
| S10 | `Makefile`'da hedefler iki kez yazıldı | Bir komutum yarıda kesilip yeniden çalışınca | Düzeltildi |
| S11 | Deploy token ekran görüntüsü | Token oluşturulduktan sonraki görüntü boş formu gösteriyordu (değer görünmüyordu) | İki görüntü silindi; rehber form görüntüsünü kullanıyor |
| S12 | `lab-03-a` doğrulaması LAB 03-B'den sonra kaldı | Kapanış koşusunda ekip-01 için 34 / 36: 03-B'de eklenen `/api` kuralları yüzünden `web-ui` imajı tek başına açılmıyor (beklenen davranış), betik bunu hesaba katmıyordu | Düzeltildi (servis adları `--add-host` ile çözdürülür); yeniden 36 / 36. Kapanış koşusunda bulundu (`20-kapanis-dogrulamalari.txt`) |

## 4. Faz 2 özeti (çekirdek ortam)

`lab-ortami/` altında tek Compose projesi (`belbim-lab`) kuruldu: GitLab + Container Registry, Nexus, katılımcı makinesi (`workstation`), test VM, TLS proxy ve lab DNS'i. Volume'lar silinip `make up && make bootstrap` baştan koşuldu; ardından `make dogrula` çalıştırıldı.

| Ne | Sonuç | Kanıt |
|---|---|---|
| Temiz kurulum: `make up` | Çıkış kodu 0, 117 sn (imajlar önceden çekilmiş ve derlenmişti; GitLab'in ilk açılışı 86 sn) | `kanit/faz-2/01-make-up.txt` |
| Temiz kurulum: `make bootstrap` | Çıkış kodu 0, 52 sn. Gruplar, 4 GitLab + 2 Nexus hesabı, şablon proje (3 branch), 6 Nexus deposu, 4 temel imaj, ekip SSH anahtarları | `kanit/faz-2/02-make-bootstrap.txt` |
| `make bootstrap` ikinci kez | Çıkış kodu 0, 8 sn; her satır "var" / "güncel", hiçbir şey yeniden oluşturulmadı | `kanit/faz-2/03-make-bootstrap-tekrar.txt` |
| `make dogrula` | **96 denetim geçti, 0 kaldı** (ağ içi 56, workstation 29, Nexus önbelleği 2, test VM + host 9). Önce temiz kurulumun hemen ardından, sonra betiklerin son haliyle yeniden koşuldu; sonuç aynı | `kanit/faz-2/05-make-dogrula.txt`, `07-make-dogrula-son.txt` |
| HTTPS, doğrulama açık | GitLab 200, Nexus 200, registry `/v2/` 401; lab CA'sı olmadan bağlantı reddediliyor; sertifikayı `Egitim Lab Root CA` vermiş | aynı dosya, "TLS" |
| Ad çözümleme | Dört servis adı proxy'ye, `test-vm` test VM'e çözülüyor; hem ağ takma adıyla hem lab DNS'iyle | aynı dosya, "Ad cozumleme" |
| Starter proje Nexus üzerinden (R13, R14) | workstation'da boş önbellekle: `dotnet restore` 0 uyarı (`NU1900` yok), build 0 uyarı / 0 hata, 9 test; `npm ci` 475 isteğin tamamı Nexus'a, dışarıya 0; Jest 14 test | aynı dosya, "workstation" |
| Kapalı ağ benzetimi, iç içe container | Test VM'de iç aynadaki SDK imajıyla `git clone` + `dotnet restore`; Node imajıyla `fetch(nexus)` → 200 | aynı dosya, "test-vm" |
| Docker daemon'ı ve CA | workstation'da `docker pull` → `x509: certificate signed by unknown authority` (katılımcı adımı); test VM'de pull başarılı | aynı dosya |
| Test VM'e SSH | `ekip01` anahtarıyla `deploy@test-vm`; Docker 29.10.0; `sudo` yok | aynı dosya |
| Giden istek izin listesi | Yalnızca `jenkins.kurum.test`; yerel ağa webhook kapalı | aynı dosya, "GitLab" |
| Host | `127.0.0.1:443` ve `:5050` üzerinden lab CA'sıyla 200 / 401; yayınlanan bütün portlar `127.0.0.1`; host Docker soketini bağlayan container yok; iki ayrı Docker daemon'ı | aynı dosya, "Host" |
| Şablonun başka Nexus adresine göre yazılması (R13) | Yalnızca `NuGet.config` ve `.npmrc` değişiyor; yazar ve tarihler korunuyor; iki üretimde SHA'lar aynı | `kanit/faz-2/04-sablon-adres-degisimi.txt` |
| Ölçülen kaynak | Çekirdek profil boşta ≈ 6,3 GiB, doğrulama sırasında tepe ≈ 7,3 GiB (sınırların toplamı ≈ 15,3 GB). GitLab 3,4 GiB, Nexus 1,6 GiB. Ölçüm kısa süreli ve tek ekiple | `kanit/faz-2/06-make-durum.txt`, `08-bellek-tepe.txt`, `VERSIONS.md` §6 |

## 5. Faz 2'de doğrulanmayanlar

- **Host tarayıcısından erişim.** `/etc/hosts` kaydı ve CA'nın anahtarlığa eklenmesi `sudo` ister; yapmadım. Yerine iki şey denendi: host'tan `curl --resolve … --cacert certs/ca.crt` (geçti) ve macOS'un sertifika değerlendirmesi `security verify-cert -c server.crt -r ca.crt -p ssl -s gitlab.kurum.test` ("certificate verification successful"). Komutlar `lab-ortami/README.md` içinde; Windows ve Linux adımları bu makinede çalıştırılamadı.
- **GitLab arayüzünden ekip hesabıyla giriş.** Parolaların geçerli olduğu API ile doğrulandı (registry token ucu 200, yanlış parola reddediliyor). İlk girişte parola değiştirme ya da karşılama sayfası çıkıp çıkmadığına tarayıcıda bakılmadı; Faz 3'te Playwright ile.
- **`ekip02` ile tam derleme.** Derleme ve test yalnızca `ekip01` kullanıcısıyla koşuldu; `ekip02` için hesap, rol, parola, SSH anahtarı ve dizin denetlendi.
- **`EKIP_SAYISI` > 2 ve `ekip-99`.** Betikler 1–10 ekip ve `EK_EKIPLER` için yazıldı; yalnızca 2 ekiple çalıştırıldı.
- **Farklı `LAB_DOMAIN` ile uçtan uca kurulum.** Yalnızca şablonun adres değişimi denendi.
- **`make sifirla-ekip`.** Yazılmadı; Faz 3'te checkpoint betiğiyle birlikte. Şu an "henüz uygulanmadı" deyip 1 ile çıkar.
- **`ci` profili.** Jenkins, agent, SonarQube Faz 4'te. Proxy'de adları tanımlı; şimdilik 502 döner.
- **x86-64.** Her şey `linux/arm64` üzerinde koştu; temel imajlar iç aynaya yalnızca arm64 olarak gönderildi.
- **Temiz kurulumda imaj indirme ve derleme süresi.** Prova sırasında imajlar önbellekteydi. İlk kurulumda GitLab (5,4 GB), Nexus ve SDK imajlarının indirilmesi bu makinede yaklaşık 15 dakika sürmüştü; bu süre ölçülerek kaydedilmedi.

## 6. Olay: host'un yeniden başlaması

Temiz kurulum provasının ilk denemesinde (20:56) `make yik`, GitLab ve Nexus container'larını durduramadı (`tried to kill container, but did not receive an exit event`) ve volume'lar silinmedi. Aynı dakikalarda host'ta yük ortalaması 26'ya çıktı, `ps` / `pgrep` / `top` yanıt vermedi; ardından makine yeniden başladı (sistem açılışı ≈ 21:02). Nedenini belirleyemedim: Docker Desktop'ın 16,5 GB'lık VM'i, o sırada üst üste binen yük (doğrulama derlemeleri, temel imajların kaydı, GitLab'in durdurulması) ya da ilgisiz bir neden olabilir.

Sonrasında: Docker Desktop'ı yeniden başlattım, `docker compose down --volumes` bu kez tamamlandı (10 volume silindi, başka projeye dokunulmadı), prova baştan ve adım adım koşuldu; her adım bir öncekinin başarısına bağlı. Ayrıntı: `kanit/faz-2/00-make-yik.txt`.

**Durum (2026-11-24): kök neden belirlenmedi; açık risk (R20).** Kullanıcı talimatı: bellek, kanıt olmadan kesin neden sayılmayacak; Faz 3'te gereksiz yıkıcı test yapılmayacak ve çalışan ortam korunacak; Faz 4'e geçmeden önce Docker Desktop kaynak tüketimi, host bellek baskısı ve ilgili hata logları birlikte incelenecek. Faz 3 boyunca (6 saatten uzun kesintisiz çalışma, iki ekiple altı lab, onlarca `docker build`) olay tekrarlamadı; yük ortalaması en çok ≈ 8 görüldü. Bu, nedeni dışlamaz: Faz 3'te `make yik` çalıştırılmadı ve olay o komut sırasında yaşanmıştı.

### İnceleme (2026-11-24, Faz 4 öncesi)

macOS'un kendi raporları okundu; ayrıntı ve ham satırlar `kanit/faz-4/00-host-incelemesi.txt` içinde.

**Kesin olanlar:**

- Yeniden başlama bir **kernel panic**: `userspace watchdog timeout: no successful checkins from WindowServer (2 induced crashes) in 120 seconds`. Makineyi macOS'un bekçisi (`watchdogd`) yeniden başlattı; neden, pencere sunucusunun (WindowServer) yanıt vermemesi.
- Sıra: 21:00:12 dolayında WindowServer'ın ana iş parçacığı takıldı → 21:00:52'de bekçi onu sonlandırdı ("unresponsive work processor(s): WindowServer main thread") → yeniden başlayan WindowServer açılışını tamamlayamadı ("initialization not complete (post IOKitWaitQuiet)") → ≈ 21:02'de panic → 21:02:54'te açılış.
- **Panic anında çekirdek bellek baskısı bildirmiyor:** `memoryPressure: false`; sıkıştırıcı sınırının %11'inde ("OK"); swap dosyası yok. O günlerdeki bütün JetsamEvent raporları küçük sistem servislerinin kendi sınırlarını aşmasıyla ilgili (15–37 MB, `per-process-limit`); büyük bir sürecin bellek yüzünden sonlandırıldığına dair kayıt yok. Isıl durum normal.
- **Ama bellek boş da değildi:** 1053 sürecin resident toplamı 61,9 GB (RAM 64 GB), boş 1,3 GB, sıkıştırıcıda 26,3 GB. Docker Desktop VM'i 16,2 GB (ayrılanın tamamına dokunmuş), diğer uygulamalar 46 GB. Makine 6,3 gündür açıktı.
- O anda bir `docker compose down` 80 saniyedir çalışıyordu (GitLab ve Nexus'u durduramayan komut).

**Belirlenemeyen:** WindowServer'ın neden takıldığı. "post IOKitWaitQuiet" ifadesi bir aygıt ya da sürücünün meşgul kalmasına işaret eder; panic'ten önce yüklenen son çekirdek eklentisi bir USB-C sürücüsü (`AppleUVDMDriver`) ve 20:57:10'da bir güç bağlantısı olayı kayıtlı. Bunlar eşzamanlılık; nedensellik kanıtı değil. Docker VM'inin **içindeki** bellek durumu o an için bilinmiyor.

**Sonuç:** "Docker'a ayrılan bellek host'u tüketti" açıklamasını raporlar desteklemiyor: çekirdek bellek baskısı bildirmemiş. Dışlanmış da değil: host neredeyse tamamen doluydu ve yoğun sıkıştırma takılmaya katkı yapmış olabilir. Kök neden hâlâ belirsiz; R20 açık kalıyor, ama iki somut önlem çıkıyor: (1) Docker'ın belleğini artırmadan önce host'ta yer açmak (şu an boş oran %77; olay anında 46 GB'ı başka uygulamalar tutuyordu), (2) Faz 4 boyunca host belleğini ve `docker stats` değerlerini dakikada bir dosyaya yazmak ki tekrarlarsa elde veri olsun.

Bundan çıkanlar:

- Prova betiğim ilk denemede `make yik` başarısız olduğu hâlde devam etmişti. Düzeltildi; Faz 6'daki `prova.sh` de aynı kuralla yazılacak.
- Scratchpad klasörü yeniden başlatmada silindi; slayt metinleri kayboldu. Yeniden çıkarıldı ve artık `referans/metin/` altında.
- Olay tekrarlarsa Docker belleği ve eşzamanlı yük ilk bakılacak yer. `ci` profili açılmadan önce (Faz 4) bellek ayarı zaten gözden geçirilecek (R5).

## 7. Faz 1 özeti (starter uygulama)

`portal-starter/` kendi git reposu olarak oluşturuldu: üç branch, 52 dosya, `main` üzerinde tek commit (`174fe06 chore: starter project`).

| Ne | Sonuç | Kanıt |
|---|---|---|
| 1. gün sunumu doğru dosya mı | Evet: LAB 01-A 70 dk, LAB 01-B 80 dk | Bu rapor, §7 sonu |
| `dotnet restore / build / test` | 0 uyarı, 0 hata; 9 test geçti (product 5, order 4); `junit.xml` ve `coverage.opencover.xml` üretildi | `kanit/faz-1/01-dotnet-build-test.txt` |
| `npm ci / test / build` (Node 24.22.3) | 14 test geçti; `junit.xml` ve `coverage/lcov.info` üretildi; Vite build tamam | `kanit/faz-1/02-web-ui-test-build.txt` |
| NU1605, hata yönü | `lab/01a-conflict` üzerinde restore çıkış kodu 1, `error NU1605` | `kanit/faz-1/03-nu1605.txt` |
| NU1605, çözüm yönü | Sürüm hizalanınca restore, build, test geçti; referans kaldırılınca da restore geçti | aynı dosya |
| Conflict, hata yönü | `lab/01b-rename` merge edilince `CONFLICT (content)` | `kanit/faz-1/04-merge-conflict.txt` |
| Conflict, çözüm yönü | İşaretler silinince testler yeşil, merge tamamlandı | aynı dosya |
| Çalışan API'ler | `/health` → `Healthy`, `/swagger` 200, `GET /api/products` üç ürün, `POST /api/orders` 201 | `kanit/faz-1/05-calisma-zamani.txt` |
| Bilinçli üç eksik starter'da duruyor | Boş `productId` → 201; `quantity` 0 ve −3 → 201; katalogda `inStock` yok | aynı dosya |

Bu fazda **doğrulanmayanlar**:

- ~~Nexus üzerinden restore.~~ **Faz 2'de doğrulandı** (§4).
- **Arayüzün tarayıcıda çalışması.** web-ui birim testleri ve build geçti, API'ler `curl` ile denendi; ama Vite geliştirme sunucusu üzerinden tarayıcıda uçtan uca bakılmadı. Faz 3'te LAB 01-A doğrulamasında Playwright ile yapılacak.
- **Node 24 dışında sürüm.** web-ui yalnızca Node 24.22.3 container'ında çalıştırıldı.

### 1. gün sunumu ön kontrolü

`referans/01_BELBIM_DevOps_Git_Dependencies.pptx` (md5 `411f859f…`, 194 KB): gün planında LAB 01-A 70 dk, LAB 01-B 80 dk; LAB slaytlarında da aynı. `~/Downloads` altındaki aynı adlı 711 KB'lık eski dosya kullanılmadı.

## 8. Kararlar

### Faz 1

| # | Karar | Gerekçe |
|---|---|---|
| D1 | NU1605, EF Core ile üretiliyor: `lab/01a-conflict` branch'i `order-service`'e `Microsoft.EntityFrameworkCore` 9.0.23 doğrudan referansı ekler; `Microsoft.EntityFrameworkCore.Sqlite` 10.0.15 ise ≥ 10.0.15 ister. `RestoreEnablePackagePruning` kullanılmadı. `common-contracts` paket bağımlılığı taşımıyor. | Kullanıcı kararı. İki yönlü doğrulandı. |
| D2 | Test çatısı xUnit 2.9.3 + `xunit.runner.visualstudio` 3.1.5. | .NET 10 SDK'nın `dotnet new xunit` şablonu bunu üretiyor; `JunitXml.TestLogger` ve `coverlet.collector` bu yolla çalışıyor. xUnit v3 denenmedi. |
| D3 | Jest için Babel 7 (7.29.x). | Babel 8 ile Jest 30'un iç bağımlılıkları her `npm ci` çalıştırmasında 15 `ERESOLVE` uyarısı veriyordu. Babel 7 ile uyarı yok. |
| D4 | Kökte `Directory.Build.props` ve `Directory.Packages.props` yok; her şey `.csproj` içinde. | G3/11'deki Dockerfile yalnızca `NuGet.config` ve `.csproj` dosyalarını kopyalayıp restore ediyor; kökteki ortak dosya o katmana girmez ve restore kırılır. |
| D5 | Lokal çalıştırmada portlar `launchSettings.json` ile: product-service `5101`, order-service `5102`, Vite `5173`. Container imajında 8080. | İki API aynı makinede aynı portu dinleyemez. 8080, .NET container imajının varsayılanıdır. |
| D6 | `/swagger` arayüzü: `Microsoft.AspNetCore.OpenApi` (belge) + `Swashbuckle.AspNetCore.SwaggerUI` (arayüz). | .NET 10 şablonlarında Swagger arayüzü yerleşik gelmiyor; slayt `/swagger` yolunu kullanıyor. |
| D7 | `lab/01b-rename` yalnızca `catalog.json` dosyasına dokunur; testi değiştirmez. | Çakışma tek dosyada ve öngörülebilir kalır. Bu branch'te tek başına testler kırmızıdır; branch yalnızca merge edilmek için vardır. |
| D8 | API, Türkçe karakterleri `\uXXXX` olarak değil olduğu gibi yazar. | Slayttaki `curl` çıktıları (`"Terminal adaptörü"`) böyle. |
| D9 | Sipariş zaman damgaları yanıtta UTC (`…Z`) olarak döner. | SQLite `DateTimeKind` tutmuyor; düzeltilmeseydi arayüz saatleri 3 saat kaydırırdı. Testle sabitlendi. |
| D10 | Commit'lerde yazar `Egitim Ortami <egitim@kurum.test>`, tarihler sabit. | Repo dağıtılacak; kişisel kimlik taşımamalı. Sabit tarih SHA'ları tekrar üretilebilir kılar. |
| D11 | Starter'da `ci/analyze.sh` ve `.dockerignore` yok. | İkisi de lablarda katılımcı tarafından eklenir (04-B, 03-A). `Jenkinsfile` ve `deploy/*` yalnızca açıklama içeren iskelet. |

### Faz 2

| # | Karar | Gerekçe |
|---|---|---|
| D12 | Lab DNS'i (`dns`, CoreDNS) eklendi; `proxy`, `test-vm` ve `dns` sabit IP kullanır (`LAB_SUBNET`, varsayılan `172.30.99.0/24`). | İç içe Docker daemon'larındaki container'lar (docker build içindeki restore, test VM'deki uygulama) Docker'ın gömülü DNS'ine ulaşamıyor; daemon `127.0.0.11` adresini eleyip dış DNS'e düşüyor. Daemon'lara `--dns` olarak bu servis verildi. README §7'deki servis listesine bir yardımcı servis eklenmiş oldu. |
| D13 | Bootstrap ve doğrulamanın API çağrıları `araclar` container'ında, lab ağının içinden yapılır. Host yalnızca `docker compose` çağırır. | Host'ta hosts kaydı ve CA gerekmeden çalışır; TLS doğrulaması hiçbir betikte kapatılmaz. Host'ta yalnızca Docker, `make`, `bash` gerekir. |
| D14 | `workstation`'daki Docker daemon'ı lab CA'sına güvenmez; işletim sistemi güvenir. Test VM'in daemon'ı güvenir. | "Docker daemon'a CA tanıtma" katılımcı adımıdır (README §7) ve G3/18'deki hatayı üretir. Daemon `SSL_CERT_FILE` ile yalnızca genel CA'ları görür; `certs.d` altına CA konunca güven oluşur. Test VM'i yönetici hazırlar. |
| D15 | `egitim`, `egitim/sablonlar/portal-starter` ve `egitim/base` public; `egitim/ekip-NN` private. | 1. gün klonlama hesap gerektirmez (G1 notu: hesap erişimi 2. günün ön koşulu). LAB 03-A'da `docker build`, `docker login` yapılmadan temel imaj çekebilmelidir. |
| D16 | Ekip parolaları `LAB_SECRET`'ten türetilir (HMAC-SHA256), dosyaya yazılmaz; `make parolalar` ekrana basar. | "Sır yazma" kuralı; ekip sayısı değişince yeni sır üretmek gerekmez; checkpoint ve prova betikleri aynı parolayı yeniden hesaplar. |
| D17 | Nexus'ta ekip başına tek hesap `ekipNN`, rol `lab-yayinci` (hosted depolara yazma + kendi API anahtarı). Okuma anonim. | Slayt: anahtar kullanıcı profilinden alınır; repodaki `NuGet.config` kimlik bilgisi taşımaz. |
| D18 | Temel imajlar host'un Docker'ında derlenir, `docker save` ile dosyaya alınır ve `araclar` içinden `skopeo` ile registry'ye gönderilir. İmajlar `lab.kaynak` ve `lab.ca` etiketleriyle işaretlenir. | Host daemon'ı lab registry'sine bağlanmak zorunda kalmaz (hosts/CA gerekmez); katılımcı daemon'larına dokunulmaz; etiketler sayesinde tekrar çalıştırma güncel imajı yeniden göndermez. Yalnızca host mimarisi gönderilir. |
| D19 | `workstation` ve test VM, Docker ikili dosyalarını `docker:29.10.0-dind` imajından alır. | Üç daemon da aynı Engine sürümünü çalıştırır; apt deposundaki sürüm adlarına bağımlılık yok. |
| D20 | GitLab 19.6 ayar adları: `gitlab_rails['nginx'][…]`, `registry['nginx'][…]`. Yönetici token'ı `gitlab-rails runner` ile kurulur; değer standart girişten okunur. | Eski adlar (`nginx[…]`, `registry_nginx[…]`) bu sürümde kullanım dışı uyarısı veriyor; adlar imajın kendi `gitlab.rb.template` dosyasından alındı. Parola ile token alma (ROPC) GitLab 18'den beri istemci kimliği istiyor. |
| D21 | Lab CA'sı `nameConstraints` ile yalnızca `LAB_DOMAIN` için sertifika imzalayabilir; servis sertifikası 800 gün. | CA host'un güven deposuna eklenecek; başka siteler için kullanılamamalı. macOS, kullanıcının eklediği CA'larda 825 günden uzun sertifikayı reddeder. |
| D22 | Host portları: `443` ve `5050` aynı; test VM `18081`–`18090` (+ `18099`), workstation `8080` → `18080`, GitLab SSH `2222`. | K5. `8081` şu an boş olsa da sabit kural: host'ta `1` öneki. |
| D23 | Tek `workstation` container'ı, ekip başına Linux kullanıcısı (`ekipNN`, `sudo` ve `docker` yetkili), tek Docker daemon'ı. | README §7: üç daemon, fazlası yok. Sonucu R18'de. |
| D24 | Şablon proje GitLab'e yüklenirken Nexus adresi hedef ortama göre yeniden yazılır (`bootstrap/sablon-hazirla.sh`); `main` koruması yalnızca şablon projede, yalnızca içerik değiştiyse kaldırılıp yeniden kurulur. | R13. BELBİM'de Nexus adresi farklı olacak. |
| D25 | Nexus EULA'sı kabul edilmemişse `make bootstrap` her şeyi kurar ama sonunda 1 ile çıkar ve ne yapılacağını yazar. Onayları yalnızca `.env` içindeki açık satırlar işaretler. | Onay kullanıcıya aittir; onaysız ortam paket indiremediği için "tamamlandı" denemez. |
| D26 | Test VM'e yalnızca SSH anahtarıyla girilir. Her ekibin anahtarı workstation'daki ev dizininde üretilir, açık anahtar `deploy` kullanıcısına eklenir. `deploy`'un parolası ve `sudo` yetkisi yoktur. | Slayt (G5/20): `deploy` docker grubundadır. Aynı anahtar 5. gün Jenkins'teki `test-vm-ssh` credential'ı için kullanılabilir. |
| D27 | `ekip-99` için `WEB_PORT` `8099`. | `8080 + N` kuralı 99'da aralığın dışına çıkıyor. |

### Faz 3

| # | Karar | Gerekçe |
|---|---|---|
| D28 | Temel imajlar `workstation`'a registry'den `skopeo` ile arşivlenip `docker load` ile yüklenir; "güncel mi?" denetimi katman kimlikleriyle yapılır. | Daemon'ın registry'ye güvenmesi gerekmez, ayarına dokunulmaz; kaynak tek (registry). Yüklenen imajın digest'i registry'dekinden farklı çıktığı için digest karşılaştırması işe yaramaz. |
| D29 | Ekip projesinde varsayılan branch `develop`. | GitLab, MR şablonunu ve `Closes #N` ile issue kapatmayı varsayılan branch'e göre uygular (sabitlenen sürümün belgesi). Slayttaki 5. ve 7. görevler ancak böyle çalışır. |
| D30 | LAB 02-A'nın ilk adımında dünkü `feature/katalog-sarj-unitesi` lokalde `main`'e merge edilir, MR şablonu ve CODEOWNERS aynı adımda eklenir. | Slayt bunu belirtmiyor; `SRJ-04` `1.0.0` sürümünde olmalı ve şablon ilk MR'dan önce varsayılan branch'te bulunmalı. |
| D31 | Issue ve MR numaraları gerçek değerleriyle kullanılır; branch adları slaytlardaki gibi kalır. | GitLab'de iki sayaç ayrıdır ve 1'den başlar; slayttaki `#3`, `!5`, `#7` tutturulamaz. README, branch adlarının slaytla aynı olmasını ister. Öneri `slayt-guncellemeleri.md` C2'de. |
| D32 | A akışında MR ayarı "All threads must be resolved" açılır. | Slayt G2/9: "tartışmalar çözülmeden merge yok". "Thread'i çöz" görevine gerçek bir engel kazandırır. |
| D33 | Rol değişimi, zaman kalan ekipler için ikinci küçük MR'dır (`feature/3-stok-durumu-arayuz`: arayüzde stok sütunu); checkpoint bu MR'ı içerir. | Slayt notu: "yarı sürede eşler ikinci bir küçük MR ile rolleri değiştirsin". Atlayan ekipte yalnızca arayüz sütunu eksik kalır; sonraki lablar buna bağlı değil. |
| D34 | `.gitlab/CODEOWNERS` sahipleri: ekip grubu (`@egitim/ekip-NN`) ve ekip lideri. Şablon projedeki checkpoint'lerde `NN` yer tutucusu vardır; `checkpoint-uygula.sh` ekibe göre yazar. | Slayttaki `backend` / `frontend` alt grupları ortamda yok. Role dayalı sahiplik (`@@maintainer`) yalnızca doğrudan proje üyelerini sayar; ekipler gruptan miras alır. |
| D35 | Checkpoint branch'leri `develop`'un durumunu taşır; `main` için iki yardımcı branch vardır (`checkpoint/lab-02a-main`, `checkpoint/lab-02b-main`). | GitFlow'da `main`'in ucu (`hotfix` → `main` merge commit'i) `develop`'un geçmişinde değildir. README'deki listeye iki ad eklenmiş oldu. |
| D36 | Checkpoint branch'leri `checkpoint/uret.sh` ile `checkpoint/adimlar/` altındaki çözüm dosyalarından üretilir. | Çözümün tek kaynağı; ortadaki bir commit değişince sonrakiler yeniden üretilebilir; SHA'lar tekrarlanabilir. |
| D37 | Checkpoint durumu zorlayarak kurar (koruma kaldır, branch'leri yaz, yeniden koru); projeyi silmez, MR geçmişini geri kurmaz; ekibin çalışma kopyasını `~/yedek/` altına taşır. | Sınıfta takılan ekibin o ana kadarki issue ve MR'ları kalır; iş kaybolmaz. |
| D38 | `order-service` Dockerfile'ı LAB 03-A sonunda `/data` dizinini içermez; tek container denemesinde veritabanı yolu `/tmp`'ye yönlendirilir. | SQLite Error 14, README gereği LAB 03-B'de yaşanır. Yönlendirme olmadan hata 03-A'da erkenden çıkıyor (denendi). |
| D39 | `deploy/nginx.conf` LAB 03-A'da statik sunum bloğuyla yazılır; `/api` kuralları LAB 03-B'de eklenir. | `web-ui` imajı dosyayı kopyalar; kurallar erken yazılırsa imaj tek başına açılmaz (denendi). |
| D40 | `web-ui` Dockerfile'ı `.npmrc` dosyasını da kopyalar; `.dockerignore` desenleri `**/` ile yazılır; çözümde `web-ui` için `HEALTHCHECK` vardır. | R15; slayttaki iki satırın düzeltilmiş hali. `HEALTHCHECK`: slayt G3/13 "üçünü de yapacağız". |
| D41 | İki deploy token: `ekipNN-deploy` (read + write) ve test VM için `ekipNN-pull` (yalnızca read). | Slayt G3/19. |
| D42 | Test VM'de her ekip registry girişini `DOCKER_CONFIG=/opt/saha/ekipNN/.docker` altında tutar; komutlar eğitim makinesinden `ssh` ile çalıştırılır. | R7. `sshd` ayarı değiştirmeden, BELBİM'e taşınabilir; 5. günde Jenkins aynı biçimde çalışacak. |
| D43 | Lokal Compose da `WEB_PORT` değerini kullanır (`http://localhost:808N`). | Değişken eğitim makinesinde tanımlı; paylaşılan makinede çakışma olmaz. |
| D44 | LAB 03-B'de `1.0.1` etiketi, Compose ve `/data` düzeltmesinden sonra yeniden gönderilir (üzerine yazılır). | Slayttaki görev sırası (önce push, sonra Compose) bunu gerektiriyor; rehber bunu öğretme anı olarak kullanır. Alternatif sıra `slayt-guncellemeleri.md` C3'te. |
| D45 | Arayüz adımları `tarayici` servisinde yapılır; servis `workstation`'ın ağ alanını paylaşır. | Rehberdeki adresler (`localhost:5173`, `localhost:808N`, GitLab, test VM) katılımcının tarayıcısındaki gibi açılır; host'ta hosts kaydı ve CA gerekmez. |
| D46 | Doğrulama betikleri (`dogrula/lab-XX-Y.sh`) katılımcı makinesinde çalışır; GitLab'i salt okunur bir token ile sorgular. Sandbox'ta `dogrula/lab.sh` bunları `workstation`'a taşır ve kısa ömürlü token üretir. | İki modda aynı betik. `KAYNAK=checkpoint` verilirse MR geçmişi denetlenmez. |
| D47 | Sandbox'ta bir ekibin iki GitLab hesabı aynı Linux kullanıcısını paylaşır: iki SSH anahtarı ve `rol lead` / `rol dev`. Sunucu anahtarları (`known_hosts`) bootstrap ile hazırlanır. | Tek `workstation` (D23). Anahtarı GitLab profiline eklemek katılımcı adımı olarak kalır. |
| D48 | `workstation`'ın `/etc/docker` dizini ayrı bir volume'dadır. | Katılımcının eklediği `certs.d`, container yeniden yaratılınca kaybolmasın. |
| D49 | `dogrula/cekirdek.sh`: "ekip projesi yok", "`certs.d` yok" ve "test VM'de imaj yok" denetimleri duruma duyarlıdır; lab yapılmışsa bilgi satırı yazar. | Bu üçü yalnızca yeni kurulumda doğrudur. |

## 9. Onaylanan kararlar

| # | Karar |
|---|---|
| K1 | NU1605: EF Core (D1). |
| K2 | `LAB_DOMAIN=kurum.test`. Starter'daki `NuGet.config` ve `.npmrc` bu alan adıyla yazıldı. |
| K3 | Ekip başına iki hesap: `ekipNN-lead` (Maintainer), `ekipNN-dev` (Developer). Lab ortasındaki rol değişimi için eğitmenin çalıştıracağı, yalnızca o ekibe dokunan betik Faz 3'te yazılacak. |
| K4 | `TEST_URL=http://test-vm.<D>:808N`. README §4'teki "hepsi HTTPS" test VM'deki uygulama portlarını kapsamaz; servis arayüzleri HTTPS kalır. |
| K5 | Docker belleğini Faz 2'den önce kullanıcı 36 GB'a çıkaracak. Host'ta `8080` ve `8081` kullanan projelere dokunulmaz; lab portları host'ta farklı numarayla yayınlanır ve ortam kartına yazılır. Container içindeki portlar slaytlardaki gibi kalır. |
| K6 | BELBİM sürümleri bilinmiyor: `VERSIONS.md` içindeki sürümler, GitLab Free, SonarQube Community, `EKIP_SAYISI=2`. |
| — | LAB 04-B: squash'a güvenilmez. Katılımcı dosyaları `git checkout lab/04b-untested -- <yol>` ile alıp kendi commit'ini atar. Faz 4'te iki yönlü doğrulanacak. |
| — | Playwright: tarayıcıya lab CA'sı tanıtılır, sertifika hataları yok sayılmaz; betikteki adımlar öğrenci rehberindeki adımlarla aynı olur. |
| K7 | Docker belleği şimdilik 16,5 GB kalıyor (kullanıcı, 2026-11-23). Diğer projelerinin çoğunu kendisi durdurdu. Jenkins agent'ı ve build daemon'ı Faz 4'te küçük başlatılacak (2 GB + 3 GB, tek executor), ölçüme göre büyütülecek. K5'teki "36 GB" bunun yerini aldı. |
| K8 | Nexus Community Edition EULA'sı ve telemetri bildirimi kullanıcı onayıyla işaretlendi (2026-11-23). `.env` içinde `NEXUS_CE_EULA_KABUL=evet`, `NEXUS_CE_TELEMETRI_ONAY=evet`. |
| K9 | Temiz kurulum provası için `belbim-lab` volume'larının silinmesine kullanıcı izin verdi (2026-11-23). Bu izin o prova içindi; sonraki silmeler için yeniden sorulacak. |
| K10 | **LAB 03-A için temel imajların önceden yüklenmesi** (kullanıcı, 2026-11-24). Slayt sırası korunur. Altı koşul: bootstrap yükler, sürümler sabit, tag ve digest kayıtlı; idempotent; BuildKit davranışı gerçek komutlarla doğrulanır; LAB 03-B'de `x509` üretilip CA ile çözülür, TLS doğrulaması kapatılmaz; BELBİM'e taşınabilir ve katılımcı makineleri için ön kontrol vardır; güvenilir çalışmazsa geçici çözüm üretilmez, raporlanır. Karşılıkları §1'de. |
| K11 | Host'un yeniden başlaması açık risk olarak tutulur; Faz 3'te gereksiz yıkıcı test yapılmaz; Faz 4'ten önce Docker Desktop kaynak tüketimi, host bellek baskısı ve hata logları incelenir; bellek kanıtsız neden sayılmaz (kullanıcı, 2026-11-24). |
| K12 | CodeGraph güncellemesi yapılmaz (kullanıcı, 2026-11-24). |
| K13 | **Kullanılamayan lisanslı (enterprise) özellikler gösterilmez** (kullanıcı, 2026-11-24): "elimizdeki materyal ile anlatım yapabiliyoruz". LAB 02-A'nın Premium "B akışı" rehberlerden çıkarıldı. Aynı karar Faz 4'e uygulanır: LAB 04-B yalnızca SonarQube Community akışıyla yazılır; ticari sürümün branch / MR analizi akışı yazılmaz (benim yorumum; README §8 iki akışı da istiyordu). |
| K14 | Faz 3 onaylandı; önce `cozum.sh` ile tek seferde koşu, sonra Faz 4 (kullanıcı, 2026-11-24). |
| K15 | Issue numaraları için slaytlar değişmez; mevcut yaklaşım sürer (branch adları slayttaki gibi, MR'da gerçek numara). Kullanıcının "elimizdeki materyal ile anlatım yapabiliyoruz" sözünden çıkardığım sonuç; açıkça yanıtlanmadı. |
| K16 | **Docker Desktop belleği 24 GB'a çıkarılacak** (kullanıcı, 2026-11-24; `ci` profili için). Ayarı kullanıcı değiştirir. K7'deki "16,5 GB" bunun yerini aldı. Uzun koşularda host'taki ağır uygulamalar kapalı tutulur (§6). |
| K17 | Faz 4 sonuçları kabul edildi; Faz 5'e geçiş ("başla", 2026-11-24). Faz 4 özetinde sorduğum dört sapmaya (webhook yalnızca push ve secret token boş; uzun `gitLabConnection` / `withSonarQubeEnv` yazımı; yeni credential ve token adları; lab başına bir issue) itiraz gelmedi. **Benim yorumum:** dördü de kabul edildi sayıyorum; açıkça onaylanmadı, istenirse geri alınır. | 5 |

## 10. Starter uygulama

```
portal-starter/
  SahaPortal.sln  NuGet.config  README.md  CHANGELOG.md  Jenkinsfile
  .gitignore  .gitattributes
  deploy/compose.yaml  deploy/nginx.conf            # iskelet
  src/common-contracts/                             # ProductDto, CreateOrderRequest, OrderDto
  src/product-service/                              # GET /api/products, Data/catalog.json
  src/order-service/                                # POST, GET /api/orders; EF Core SQLite
  src/web-ui/                                       # React 19, Vite 8, Jest 30; .npmrc
  tests/product-service.tests/                      # 5 test
  tests/order-service.tests/                        # 4 test
```

| Branch | Commit | İçerik |
|---|---|---|
| `main` | `174fe06` | Starter |
| `lab/01a-conflict` | `59562d2` | `order-service.csproj` içine tek satır: `Microsoft.EntityFrameworkCore` 9.0.23 |
| `lab/01b-rename` | `756affb` | `catalog.json` içine `SRJ-04` "Hızlı şarj" |

| `checkpoint/lab-01a` | `cc4e219` | `lab/01a-conflict` + NU1605 çözümü (sürüm hizalandı) |
| `checkpoint/gun1` | `c0e7e82` | `feature/katalog-sarj-unitesi`: `SRJ-04` ve çözülmüş conflict |
| `checkpoint/lab-02a` / `-main` | `fd0a349` / `a7af75a` | `develop`: stok durumu (API ve arayüz); `main`: dünkü iş + `.gitlab/` |
| `checkpoint/lab-02b` = `gun2` / `-main` | `8a5349e` / `621ce23` | Release 1.0.0 ve hotfix 1.0.1; `main` ucu `v1.0.1`, ilk ebeveyni `v1.0.0` |
| `checkpoint/lab-03a` | `11289ab` | `feature/9-docker`: üç Dockerfile, `.dockerignore`, statik `nginx.conf` |
| `checkpoint/lab-03b` = `gun3` | `9fa7fc9` | `develop`: + `compose.yaml`, tam `nginx.conf`, `/data` düzeltmesi |

Checkpoint branch'leri `lab-ortami/checkpoint/uret.sh` ile üretilir. `main` hâlâ `174fe06`; starter'ın kendisi bu fazda değişmedi. `lab/04b-untested` Faz 4'te, kalan `checkpoint/*` branch'leri Faz 4–5'te eklenecek.

## 11. Lab ortamı

```
lab-ortami/
  Makefile  compose.yaml  README.md
  .env.example  lab.env.example         # .env ve lab.env üretilir, repoya girmez
  certs/                                # üretilen CA ve servis sertifikası
  images/  proxy/ dns/ workstation/ test-vm/ araclar/ base/ common/
  bootstrap/
    00-env.sh  01-certs.sh  bekle.sh  bootstrap.sh  host-lib.sh  lib.sh
    10-gitlab.sh  sablon-hazirla.sh
    20-nexus-parola.sh  20-nexus.sh
    30-temel-imajlar.sh  30-imaj.sh
    40-test-vm.sh  50-workstation.sh
    35-workstation-imajlar.sh  temel-imajlar.tablo        # Faz 3: temel imaj ön yüklemesi
    checkpoint-uygula.sh  checkpoint-ws.sh  checkpoint-vm.sh
    sifirla-ekip.sh  rol-degistir.sh  ekip-gitlab.sh  ekip-token.sh
    parolalar.sh  durum.sh
  checkpoint/
    uret.sh  adimlar/                                     # checkpoint branch'lerinin kaynağı
  dogrula/
    cekirdek.sh  cekirdek-api.sh  cekirdek-workstation.sh  lib.sh
    lab.sh  ortak-ws.sh  lab-01-a.sh … lab-03-b.sh         # lab doğrulamaları
    cozum.sh  cozum/ortak.sh  cozum/lab-01-a.sh … lab-03-b.sh
    ui/lib.cjs  ui/gitlab.cjs  ui/uygulama.cjs  ui/tls-denemesi.cjs
    workstation-onkontrol.sh  temel-imaj-buildkit.sh  ekip-durumu.sh  api-merge-dene.sh
lab-rehberleri/
  ortam-karti.md
  ogrenci/LAB-01-A.md … LAB-03-B.md     # 6 rehber
  egitmen/LAB-01-A-cozum.md … LAB-03-B-cozum.md
  img/                                  # tarayıcı aracının aldığı ekran görüntüleri
referans/metin/                         # slaytlardan çıkarılan metin ve notlar
```

| Servis | İmaj | Profil | Bellek sınırı | Not |
|---|---|---|---|---|
| `proxy` | `nginx:1.31.9-alpine3.24` | her zaman | 128 MB | TLS; `gitlab`, `jenkins`, `sonar`, `nexus` takma adları; `:5050`; SSH geçişi |
| `dns` | `coredns/coredns:1.15.0` | her zaman | 64 MB | D12 |
| `gitlab` | `gitlab/gitlab-ce:19.6.1-ce.0` | `cekirdek` | 6 GB | Düşük bellek ayarları; registry açık |
| `nexus` | `sonatype/nexus3:3.98.3` | `cekirdek` | 3 GB | Heap 1–1,5 GB olarak verildi |
| `workstation` | yerel derleme (Ubuntu noble) | `cekirdek` | 4 GB | .NET SDK 10.0.404, Node 24.22.3, Docker 29.10.0; daemon 1/3 |
| `test-vm` | yerel derleme (Ubuntu noble) | `cekirdek` | 2 GB | Docker 29.10.0 + sshd; daemon 2/3 |
| `araclar` | yerel derleme (Ubuntu noble) | `araclar` | 512 MB | Yalnızca komut çalışırken vardır |
| `tarayici` | `mcr.microsoft.com/playwright:v1.65.1-noble` + ekler | `araclar` | 2 GB | **Faz 3.** Arayüz adımları; `workstation`'ın ağ alanını paylaşır; yalnızca komut çalışırken vardır |

Bootstrap'in **yapmadıkları** (katılımcı adımları): ekip projesi ve push, branch koruması, access token, deploy token, webhook, `docker login`, Docker daemon'a CA, NuGet API anahtarı, paket yayını. Doğrulama betiği ekip alt gruplarında proje bulunmadığını da denetler.

## 12. Mimariden etkilenen çıktılar

Sandbox `linux/arm64`, BELBİM büyük olasılıkla x86-64. Aşağıdakiler x86-64'te farklı çıkar; rehberlere örnek olarak girerlerse "örnek çıktı" diye işaretlenecek:

- **Temel imajların digest'leri ve boyutları.** İç aynaya yalnızca arm64 gönderildi. `VERSIONS.md` §2–3'teki `sha256:…` değerleri arm64 içindir.
- **`docker stats` ölçümleri** (`VERSIONS.md` §6).
- Faz 1'de mimariye bağlı çıktı yoktu; durum değişmedi. `package-lock.json` Linux x64 (glibc ve musl) yerel bağlayıcılarını içeriyor.

Faz 3'te eklenenler (hepsi arm64; rehberlerde "örnek çıktı" olarak işaretli):

- **Uygulama imajlarının boyutları:** `order-service` 604 MB, `product-service` 545 MB, `web-ui` 127 MB (`docker images`, containerd image store). Aynı imajlar, temel imaj arşivden yüklenmek yerine registry'den çekildikten sonra 435 MB ve 376 MB göründü: `docker images` boyutu temel imajın makineye nasıl geldiğine de bağlı. Rehberlerdeki değerler bu yüzden yalnızca örnektir.
- **`docker push` digest'leri** ve Container Registry sayfasındaki değerler.
- **Önceden yüklenen temel imajların kimlikleri** (`VERSIONS.md` §3) ve taşıma paketinin boyutu (1,48 GB).
- **İlk build süreleri** (9 / 6 / 8 sn) ve build context ölçümleri.
- **SQLite Error 14'ten sonra container'ın kapanmaması** yalnızca arm64'te gözlendi (R23).

## 13. Açık konular ve riskler

| # | Konu | Durum |
|---|---|---|
| R1 | NU1605'in .NET 10'da oluşmaması | Kapandı (D1) |
| R2 | SonarQube yeni kodu commit tarihine göre belirliyor; `lab/04b-untested` "kesin kalmalı" | **Kapandı.** Öğrenci akışıyla iki ekipte: dosyalar `git checkout` ile alınıp katılımcının kendi commit'iyle gönderilince kapı `ERROR` (yeni kod coverage'ı %6,7), testlerle `OK` (%97,8). Koşul: taban analiz önce yapılmış olmalı (rehberde 45. dakika kontrolü) |
| R3 | Jenkins GitLab plugin + Multibranch: webhook, tag keşfi, ekip token'ı ile global `gitlab` bağlantısı | **Kapandı.** Tag keşfi ve tag build'i Faz 5'te doğrulandı (R36, R37) |
| R4 | "Pipelines must succeed" ile harici commit status | **Kapandı.** Durum yok → `ci_must_pass`; `pending` → `ci_still_running`; `failed` → `ci_must_pass`; üçünde de merge `405`. `success` → `mergeable` |
| R5 | Docker Desktop belleği | **Kapandı (K16).** 24 GB; bütün lab iki ekiple en yüksek 13,7 GiB (`VERSIONS.md` §6). On ekibin aynı anda build etmesi ölçülmedi |
| R6 | arm64 / x86-64 farkı | §12 |
| R7 | Test VM'de tek `deploy` kullanıcısıyla ekiplerin registry girişleri çakışır | **Kapandı.** Ekip başına `DOCKER_CONFIG` (D42); ekip-01 ve ekip-02 aynı VM'de ayrı girişlerle çalıştı |
| R8 | Checkpoint'in üç şeyi birlikte geri kurması | **Kapandı.** Gün 1–5: kod, GitLab korumaları, tag'ler, token'lar, webhook; registry imajları; Nexus paketi; Jenkins job, credential'lar ve deploy anahtarı; SonarQube projesi; test VM'deki uygulama, veri ve deploy kaydı |
| R9 | GitLab Premium B akışı ve SonarQube ticari akış doğrulanamaz | **Kapandı (K13):** ikisi de kapsamdan çıkarıldı; rehberlerde yer almaz |
| R10 | Nexus Community Edition ilk kurulum ve limitler | **Kapandı.** EULA kabul edilmeden paket indirme `403` dönüyor; kullanıcı onay verdi (K8). CE kullanım verisini Sonatype'a gönderiyor: "kapalı ağ" benzetiminde tek dışa giden trafik bu ve proxy depolarının kendisi. Kullanım limitlerine yaklaşılmadı |
| R11 | Tag build'i SHA imajını bulamazsa | **Kapandı.** Yeniden derlemez; 5 dk bekler, anlaşılır hatayla durur; deploy yapılmaz (denendi) |
| R12 | Host port çakışmaları | **Kapandı** (D22; `VERSIONS.md` §5, ortam kartı) |
| R13 | Starter'daki Nexus adresi ve lock dosyasındaki `registry.npmjs.org` adresleri | **Kapandı.** Şablon yüklenirken adres yeniden yazılıyor (D24). `.npmrc` yerindeyken `npm ci` lock'taki adresleri kendiliğinden Nexus'a çeviriyor: 475 istek Nexus'a, 0 dışarıya |
| R14 | NuGet güvenlik denetimi ve `NU1900` | **Kapandı.** Nexus üzerinden restore 0 uyarı |
| R15 | G3/12'deki web-ui Dockerfile'ı `.npmrc` dosyasını imaja kopyalamıyor | **Kapandı** (D40). `.npmrc` olmadan build denenmedi; açık ağda ayırt edici hata vermez |
| R16 | Paket sürümleri bugünün yamalarına sabit | Bilgi |
| R17 | LAB 03-A temel imajları iç aynadan kullanır; Docker'a CA LAB 03-B'de tanıtılır | **Kapandı** (K10, D28). Kalan sınır: güvence yalnızca varsayılan builder için; ön kontrol denetliyor. BELBİM'de imajların makinelere yüklenmesi yöneticinin işi (`belbim-yoneticisinden-istenecekler.md`, Faz 6) |
| R18 | Sandbox'ta tek `workstation` var: ekipler aynı Docker daemon'ını, `certs.d`'yi, `:dev` etiketlerini ve portları paylaşır | **Faz 3'te somutlaştı.** ekip-01 CA'yı tanıttıktan sonra ekip-02 için `x509` yaşanmaz oldu; `checkpoint lab-03b` de daemon'a CA'yı tanıtır (ekibe özel olmayan tek işlem). LAB 03-A'daki `order-service:dev` etiketleri ve `-p 8080:8080` iki ekipte çakışır. Prova tek ekiple sırayla koştuğu için engel değil; canlı yedek kullanım için `prova.md`'ye not (Faz 6) |
| R19 | **Yeni.** Nexus art arda hatalı girişte hesabı kısa süre kilitliyor (`429 Too many authentication attempts`) | Bootstrap ilk kurulum parolasını önce kullanacak şekilde düzeltildi. LAB 05-A'da yanlış API anahtarı deneyen ekip aynı hatayı görebilir; `hata-senaryolari.md` içine eklenecek |
| R20 | Host bir kez yanıt vermez hale gelip yeniden başladı (§6); **kök neden belirlenmedi** | **Açık.** İnceleme yapıldı (§6): panik kaydı WindowServer watchdog zaman aşımını gösteriyor; panik anında bellek baskısı yoktu. Faz 4 boyunca (Docker 24 GB, `ci` profili açık, host izlemesiyle) tekrarlamadı; host boş belleği en düşük %50, swap 0. Neden hâlâ bilinmiyor |
| R21 | **Yeni.** GitLab 19.6 ayar adları değişmiş (`nginx[…]` → `gitlab_rails['nginx'][…]`) | Sandbox'ta düzeltildi. BELBİM'in sürümü farklıysa `onkontrol.sh` yalnızca sürümü raporlar; yapılandırmaya dokunulmaz |
| R22 | **Yeni.** GitLab 19.6 arayüzü (work items, "rapid diffs") hızlı değişiyor; tarayıcı betikleri sürüme bağlı | Betikler sabitlenen sürümde çalışıyor. BELBİM'in sürümü farklıysa rehberdeki ekran adları ve görüntüler de farklı olabilir; `onkontrol.sh` sürümü raporlayacak (Faz 6). Betiklerin bozulması labı etkilemez, yalnızca provayı |
| R23 | **Yeni.** `order-service`, başlangıçtaki işlenmemiş hatadan (SQLite Error 14) sonra kapanmıyor; container "Up" kalıyor | Neden araştırılmadı (arm64, .NET 10.0.15, container'da PID 1). Etkisi: `docker compose ps` yanıltıyor; 5. gündeki smoke test bunu yakalar. Rehberler buna göre yazıldı. x86-64'te davranış farklı olabilir |
| R24 | **Yeni.** Aynı commit'ten yeniden build edilen imajın digest'i değişiyor (BuildKit oluşturma zamanı yazar) | Faz 5'teki "tag build'i yeniden derlemez, iki etiketin digest'i aynı olmalı" kuralının gerekçesi; tasarım buna göre yapılacak |
| R25 | `cozum.sh 02-a` ve `03-b` baştan sona tek seferde koşulmamıştı | **Kapandı.** ekip-02 ile dört lab arka arkaya tek seferde koştu (§1) |
| R26 | **Yeni.** Tarayıcı aracı imajı 1 GB'tan büyük; ilk indirme bu makinede ≈ 45 dk sürdü | İlk kurulum süresini uzatır. Araç yalnızca prova ve ekran görüntüsü içindir; eğitim sırasında gerekmez |
| R27 | **Yeni.** Docker, registry girişini `config.json` içinde base64 olarak saklar (ekip ev dizini, test VM'de ekip dizini); checkpoint, deploy token'ları `~/.lab/deploy-tokens` dosyasına yazar | Lab volume'larının içinde kalır, repoya ve kanıtlara girmez (taramayla denetlendi). Eğitimde credential helper anlatılmıyor; soran olursa not |
| R28 | **Yeni.** Multibranch job MR webhook olayını `409` ile reddediyor; webhook secret token'ını denetlemiyor | Tasarım buna göre: webhook yalnızca Push events, secret token boş (D59). Webhook'u koruyan şey GitLab'in giden istek izin listesi ve Jenkins'in kodu GitLab'den kendi credential'ıyla çekmesi. BELBİM güvenlik ekibi secret token zorunlu tutuyorsa plugin'in bu davranışı bilinmeli |
| R29 | **Yeni.** SonarQube'da projeler varsayılan olarak giriş yapan herkese açık: ekipler birbirinin analiz sonucunu görebilir (analiz gönderemez, ayar değiştiremez) | Eğitim için kabul edilebilir bulundu; değiştirilmedi. BELBİM yöneticisi varsayılan görünürlüğü "private" yapabilir (`belbim-yoneticisinden-istenecekler.md`, Faz 6) |
| R30 | **Yeni.** Jenkins 2.580 (yeni credential penceresi) ve SonarQube 26.11 arayüzleri sürüme bağlı; tarayıcı betikleri ve ekran görüntüleri bu sürümlerde alındı | R22 ile aynı: BELBİM'in sürümleri farklıysa ekran adları değişebilir; `onkontrol.sh` sürümleri raporlayacak (Faz 6) |
| R31 | **Yeni.** Ortak agent 2 executor'lı: aynı anda en çok iki build çalışır | On ekiple 4. gün öğleden sonra kuyruk oluşabilir (build 10–25 sn). Ölçülmedi. BELBİM'de agent sayısı ve executor sayısı yöneticiye sorulacak |
| R32 | **Yeni.** Çalışma sırasında host pilde uyku döngüsüne girdi (2026-11-24 13:49'dan itibaren, `pmset` kaydı) | Lab hatası değil; yalnızca süre ölçümlerini bozdu (LAB 04-B tek koşusu 718 sn). Uzun koşular `caffeinate -i` ile sürdürüldü. Provada makine prizde ve uyku kapalı olmalı (`prova.sh`, Faz 6) |
| R33 | **Yeni.** SonarQube, yerel ağ adresine webhook'u varsayılan olarak reddediyor | Sandbox'ta `sonar.validateWebhooks=false` (D56). BELBİM'de aynı ayar gerekebilir; yöneticiden istenecekler listesine girecek (Faz 6) |
| R34 | **Yeni.** Checkpoint, ekibin Nexus API anahtarını Nexus arayüzünün iç uç noktalarından alır (`/service/rest/wonderland`, `/service/rest/internal/nuget-api-key`) | Herkese açık REST API değildir; 3.98.3'te çalıştı. Nexus sürümü değişirse checkpoint'in yayın adımı bozulabilir (katılımcı akışı etkilenmez: anahtar arayüzden alınır) |
| R35 | **Yeni.** Tek test ortamı: `develop` deploy'u ve tag deploy'u aynı VM'e yazar | Rehberde sıra kuralı (tag, geri birleştirmeden sonra). Kaçırılırsa `v1.1.0` job'ında "Build Now" düzeltir |
| R36 | **Yeni.** "Tags" build stratejisi tag'in değil commit'in tarihine bakar (1 gün) | Lab akışında koşul sağlanır; checkpoint'te tag build'i elle başlatılır. Gerçek eğitimde release merge'ü ile tag aynı gün olmalı; değilse "Build Now" |
| R37 | **Yeni.** Tag keşfi açılınca son 1 gün içindeki eski tag'ler de build edilir | Sandbox'ta ekip-01'in `v1.0.x` tag'leri build edildi (iskelet `Jenkinsfile`, zararsız). Gerçek eğitimde 2. günün tag'leri 3 günlüktür |
| R38 | **Yeni.** MSBuild node reuse CI agent'ında aralıklı `MSB4166` hatası üretiyor | Sandbox agent'ında `MSBUILDDISABLENODEREUSE=1`. BELBİM agent'larında da önerilecek (`belbim-yoneticisinden-istenecekler.md`, Faz 6) |
| R39 | **Yeni.** Test VM paylaşılır ve tek `deploy` kullanıcısı vardır: her ekibin Jenkins anahtarı bütün ekiplerin dizinlerine erişebilir | Eğitim için kabul (R7 ile aynı model). Anahtarlar yorumla (`jenkins-ekipNN`) ayrılır, sıfırlamada kaldırılır. BELBİM'de ekip başına kullanıcı önerilebilir |

## 14. Varsayımlar

1. Ekip projesini LAB 02-A'nın ilk adımında `ekipNN-lead` oluşturur ve push eder. Bootstrap ekip alt grubunu boş bırakır.
2. LAB 01-A'da klonlanan repo `egitim/sablonlar/portal-starter`, hedef klasör `saha-ekipman-portal`; klonlama hesap istemez.
3. Jenkins'te slaytta adı geçmeyen iki klasör credential'ı için önerilen ID'ler: `gitlab-api`, `sonar-token`. Faz 4'te kesinleşir.
4. Deploy kaydı: test VM'de `/opt/saha/ekipNN/deploy.log` ve Jenkins build açıklaması.
5. Çalışma klasörünün kökü git reposu değil; `portal-starter/` kendi reposu.
6. **Yeni.** BELBİM'de katılımcı makinelerinde kurum CA'sı işletim sistemine kurulu, Docker daemon'ına tanıtılmamış olacak (sandbox bunu taklit ediyor). Değilse LAB 03-B'deki `x509` adımı "zaten yapılmış" olarak geçilir.
7. **Yeni.** Test VM'e ekipler SSH anahtarıyla girer; anahtarları yönetici önceden yetkilendirir. BELBİM parola kullanıyorsa rehberde yalnızca giriş adımı değişir.
8. **Yeni.** Sandbox dışa açık (internet var); "kapalı ağ" bir yapılandırma kuralıdır, ağ engeli değildir. Paketlerin ve temel imajların yalnızca iç adreslerden geldiği doğrulama betiğiyle denetlenir.
9. **Yeni.** LAB 02-A'da ekip projesini `ekipNN-lead` oluşturur; `ekipNN-dev` oluşturursa projede beklenenden yüksek yetki alabilir (denenmedi).
10. **Yeni.** Checkpoint ile kurulan projelerde issue'lar `#1`, `#2`, `#3` numaralarıyla (kapalı) oluşturulur; CHANGELOG'daki `(#1)`, `(#2)` bunlara bağlanır.
11. **Yeni.** BELBİM'de her katılımcının kendi makinesi ve kendi GitLab hesabı var; `rol` komutu ve ikinci SSH anahtarı yalnızca sandbox içindir.
12. **Yeni.** BELBİM'de temel imajları katılımcı makinelerine yönetici yükler (paket ya da iç aynadan `docker pull`); ön kontrol betiği eğitimden önce her makinede çalıştırılır.

## 15. Lab × durum

Etiketler: `IMPLEMENTED` (yazıldı, çalıştırılmadı), `LOCALLY_TESTED`, `SANDBOX_VERIFIED` (sandbox'ta gerçek servislerle doğrulandı), `INTEGRATION_VERIFIED` (yalnızca kullanıcı verir), `BLOCKED`, `FAILED`. "—" henüz başlanmadı.

| Çıktı | Durum | Not |
|---|---|---|
| Starter uygulama (`main`) | `SANDBOX_VERIFIED` | Arayüz Faz 3'te tarayıcıda da denendi (katalog, talep) |
| `lab/01a-conflict`, `lab/01b-rename` | `SANDBOX_VERIFIED` | İki ekipte, iki yönlü |
| `lab/04b-untested` | `SANDBOX_VERIFIED` | İki ekipte kapıda kaldı (%6,7), testlerle geçti (%97,8) |
| `checkpoint/lab-01a` … `final` (16 branch; `gun4`, `final-main` dahil) | `SANDBOX_VERIFIED` | ekip-02'ye uygulandı; ekip-01'in elle ürettiği ağaçlarla aynı (`final` ve `final-main` dahil) |
| Lab ortamı, `cekirdek` profili | `SANDBOX_VERIFIED` | Faz 2'de temiz kurulum; Faz 3 eklemeleriyle temiz kurulum **yapılmadı** (§2) |
| Lab ortamı, `ci` profili | `SANDBOX_VERIFIED` | `make dogrula-ci` 62 / 62 (5. gün: `nuget-config`, agent `known_hosts`). Çalışan ortama eklenerek kuruldu; `make yik` sonrası temiz kurulum **yapılmadı** |
| `bootstrap/*.sh` (çekirdek + `ws-imajlar`) | `SANDBOX_VERIFIED` | Tekrar çalıştırma dahil; 2 ekiple |
| `bootstrap/checkpoint-uygula.sh` | `SANDBOX_VERIFIED` | On checkpoint, ekip-02; `lab-05a` ve `final` dahil (Nexus paketi, Jenkins'in deploy anahtarı, tag build'i). `final` → `lab-04b` geri dönüşü denendi |
| `bootstrap/sifirla-ekip.sh` | `SANDBOX_VERIFIED` (Gün 1–4 kaynakları) | Faz 5 eklemeleri (Nexus paketi, test VM'deki Jenkins anahtarı) yazıldı; `sifirla-ekip` Faz 5'te **çalıştırılmadı** (aynı kaldırma kodları checkpoint geri dönüşünde çalıştı) |
| `bootstrap/rol-degistir.sh` | `SANDBOX_VERIFIED` | |
| `dogrula/cekirdek.sh` | `SANDBOX_VERIFIED` | `ci` profili açıkken 98 / 98 (Faz 5 sonu) |
| `dogrula/workstation-onkontrol.sh` | `SANDBOX_VERIFIED` | İki yönlü; sandbox dışında çalıştırılmadı |
| `dogrula/temel-imaj-buildkit.sh` | `SANDBOX_VERIFIED` | 17 / 17 |
| `make temel-imaj-paketi` | `SANDBOX_VERIFIED` | Paket üretildi ve denetlendi; paketten başka bir makineye yükleme denenmedi (aynı `docker load` yolu bootstrap'te çalışıyor) |
| `dogrula/ui/*.cjs` (tarayıcı adımları) | `SANDBOX_VERIFIED` | GitLab 19.6.1, Jenkins 2.580.2, SonarQube 26.11 arayüzlerinde |
| `dogrula/ci.sh`, `dogrula/ci-durum.sh` | `SANDBOX_VERIFIED` | Faz 4; Faz 5'te tag ve deploy komutları eklendi |
| `bootstrap/ekip-nexus.sh`, `65-agent-ssh.sh`, `dogrula/demo-gitlab-paket.sh` | `SANDBOX_VERIFIED` | Yeni (Faz 5) |
| `bootstrap/60-jenkins.sh`, `70-sonarqube.sh`, `ekip-ci.sh`, `ekip-agent-temizle.sh` | `SANDBOX_VERIFIED` | Yeni (Faz 4); bootstrap tekrar çalıştırıldı |
| `lab-ortami/README.md` host adımları | `IMPLEMENTED` | Değişmedi: macOS, Linux, Windows komutları çalıştırılmadı |
| `lab-rehberleri/ortam-karti.md` | `SANDBOX_VERIFIED` (Gün 1–4 satırları) | 5. güne ait adlar (`nexus-nuget-key`, `test-vm-ssh`, `nuget-config`) `IMPLEMENTED` |

| Lab | Öğrenci rehberi | Çözüm rehberi | Çözüm betiği (`cozum.sh`) | Doğrulama betiği | Checkpoint |
|---|---|---|---|---|---|
| LAB 01-A | `SANDBOX_VERIFIED` | `SANDBOX_VERIFIED` | `SANDBOX_VERIFIED` (tek seferde, ekip-02) | `SANDBOX_VERIFIED` (geçti ve kaldı yönü) | `SANDBOX_VERIFIED` |
| LAB 01-B | `SANDBOX_VERIFIED` | `SANDBOX_VERIFIED` | `SANDBOX_VERIFIED` (tek seferde, 2 ekip) | `SANDBOX_VERIFIED` | `SANDBOX_VERIFIED` |
| LAB 02-A | `SANDBOX_VERIFIED` | `SANDBOX_VERIFIED` | `SANDBOX_VERIFIED` (tek seferde, ekip-02) | `SANDBOX_VERIFIED` (geçti ve kaldı yönü) | `SANDBOX_VERIFIED` |
| LAB 02-A (B akışı, Premium) | kapsam dışı (K13) | — | — | — | — |
| LAB 02-B | `SANDBOX_VERIFIED` | `SANDBOX_VERIFIED` | `SANDBOX_VERIFIED` (tek seferde) | `SANDBOX_VERIFIED` | `SANDBOX_VERIFIED` |
| LAB 03-A | `SANDBOX_VERIFIED` | `SANDBOX_VERIFIED` | `SANDBOX_VERIFIED` (tek seferde, 2 ekip) | `SANDBOX_VERIFIED` | `SANDBOX_VERIFIED` |
| LAB 03-B | `SANDBOX_VERIFIED` | `SANDBOX_VERIFIED` | `SANDBOX_VERIFIED` (tek seferde, ekip-02) | `SANDBOX_VERIFIED` | `SANDBOX_VERIFIED` |
| LAB 04-A | `SANDBOX_VERIFIED` | `SANDBOX_VERIFIED` | `SANDBOX_VERIFIED` (tek seferde, ekip-02) | `SANDBOX_VERIFIED` (geçti ve kaldı yönü) | `SANDBOX_VERIFIED` |
| LAB 04-B (`community`) | `SANDBOX_VERIFIED` | `SANDBOX_VERIFIED` | `SANDBOX_VERIFIED` (tek seferde, ekip-02) | `SANDBOX_VERIFIED` (geçti ve kaldı yönü) | `SANDBOX_VERIFIED` |
| LAB 04-B (`commercial`) | kapsam dışı (K13) | — | — | — | — |
| LAB 05-A | `SANDBOX_VERIFIED` | `SANDBOX_VERIFIED` | `SANDBOX_VERIFIED` (tek seferde, ekip-02) | `SANDBOX_VERIFIED` (geçti ve kaldı yönü) | `SANDBOX_VERIFIED` |
| LAB 05-A bonus (`Pack & Publish`), GitLab Package Registry demosu | `IMPLEMENTED` (rehberde iskelet) | `SANDBOX_VERIFIED` | — (deneme betiği) | — | — |
| LAB 05-B | `SANDBOX_VERIFIED` | `SANDBOX_VERIFIED` | `SANDBOX_VERIFIED` (tek seferde, ekip-02) | `SANDBOX_VERIFIED` (geçti ve kaldı yönü) | `SANDBOX_VERIFIED` |

Rehberler için `SANDBOX_VERIFIED` şu anlama gelir: rehberdeki komutlar ve arayüz adımları sandbox'ta, gerçek servislere karşı çalıştırıldı ve beklenen çıktılar gerçek çıktılardan alındı. Rehberi bir katılımcının izlemesi, süreler ve "Yaygın hatalar" tablolarının tamamı bu etiketin kapsamında değildir (§2).

## 16. Ortamın şu anki durumu

- **Lab çalışıyor** (2026-11-24 akşamı): `cekirdek` ve `ci` profilleri açık, 11 container; Docker VM 23,93 GiB, lab ≈ 12–14 GiB. Host izleme betiği arka planda çalışıyor (`kanit/faz-4/izleme.log`).
- **ekip-01:** LAB 05-B'nin sonunda, öğrenci akışıyla (GitLab'de 16 merge edilmiş MR, 7 kapalı issue; `v1.0.0`, `v1.0.1`, `v1.1.0`; Nexus'ta `Saha.Common.Contracts.Ekip01 1.0.0`). Test VM'de `1.1.0` çalışıyor (`8081`); deploy kaydında 6 satır (rollback provası dahil). ekip-01'in `Jenkinsfile`'ı, build açıklamasının ayırıcısı ve smoke test'in ikinci isteği düzeltilmeden önceki sürümdür.
- **ekip-02:** `checkpoint/final` durumunda (son `Jenkinsfile` ile). Test VM'de `1.1.0` (`8082`).
- Test VM yeniden başladığında ekiplerin uygulamaları kendiliğinden açılmaz; ekip başına `docker compose -p ekipNN up -d` (ya da `sh deploy.sh …`) gerekir. Veri volume'da durur.
- Agent container'ı yeniden yaratılırsa `bash bootstrap/bootstrap.sh agent-ssh` yeniden çalıştırılmalı (test VM `known_hosts`).
- Kullanıcının diğer container'larına dokunulmadı. Volume silinmedi.

## 17. Faz 4: CI ortamı ve Gün 4 labları

### Özet

Jenkins (controller + ayrı agent + agent'ın kendi Docker daemon'ı) ve SonarQube Community Build + PostgreSQL kuruldu ve doğrulandı. LAB 04-A ve LAB 04-B için öğrenci rehberi, eğitmen çözüm rehberi, çözüm betiği, doğrulama betiği ve checkpoint yazıldı. İki lab **ekip-01** ile öğrenci akışı izlenerek koşuldu: komut satırı adımları `workstation`'da, arayüz adımları (GitLab, Jenkins, SonarQube) gerçek tarayıcıda. Ardından **ekip-02**'de `checkpoint/lab-03b` durumundan başlanıp iki lab tek seferde koşuldu; checkpoint'ler ve yalıtım yine ekip-02 üzerinde denendi. Kanıtlar `kanit/faz-4/` altında.

| Lab | ekip-01 (öğrenci akışı) | ekip-02 (tek seferde) | Checkpoint (ekip-02) | Doğrulama betiğinin olumsuz yönü |
|---|---|---|---|---|
| LAB 04-A | 36 / 36 (`lab-04-a-ekip01.txt`) | 156 sn; 36 / 36 (`20-…`, `lab-04-a-ekip02.txt`) | `lab-04a`: 30 / 30, MR geçmişi atlandı (`30-…`, `31-…`) | LAB 03-B durumundaki ekipte 21 kaldı, 2 geçti (`13-…`) |
| LAB 04-B | 47 / 47 (`lab-04-b-ekip01.txt`) | 47 / 47 (`22-…`, `lab-04-b-ekip02.txt`); süre geçersiz (R32) | `lab-04b`: 33 / 33, üç denetim atlandı (`32-…`, `33-…`) | LAB 04-A durumundaki ekipte 22 kaldı, 6 geçti (`21-…`) |

**LAB 04-A doğrulama zinciri** (her halka ayrı; ekip-01, ekip-02'de aynı):

| Halka | Sonuç |
|---|---|
| 1 · Push olayı Jenkins'e ulaşıyor | GitLab webhook kaydı: her push için `push_hooks … HTTP 200`. **MR olayı ulaşıyor ama Jenkins `409` ile reddediyor** (Multibranch job desteklemiyor; `05-webhook-olaylari-ekip02.txt`): webhook yalnızca push ile kuruldu |
| 2 · Jenkins doğru commit'i derliyor | Build'in `lastBuiltRevision` değeri = GitLab'deki branch ucu (her build'de karşılaştırıldı) |
| 3 · Sonuç commit status olarak dönüyor | `jenkins = success / failed`, hedef adres Jenkins build'i; commit başına tek ad; repoda `.gitlab-ci.yml` yok |
| 4 · Başarısız pipeline MR'da görünüyor | Tarayıcıda `Pipeline #11 failed`, `Merge blocked: 1 check failed`, `Pipeline must succeed.` (`lab-04-a-merge-engeli.png`); API `head_pipeline=failed` |
| 5 · MR birleştirilemez, merge reddediliyor | `detailed_merge_status=ci_must_pass`; lider adına `PUT …/merge` → `405 Method Not Allowed` |
| 6 · Düzeltmeden sonra merge mümkün | `jenkins=success`, `mergeable`; lider arayüzden merge etti; `develop` build'i yeşil |
| İş kuyruktayken / durum yokken | Agent geçici olarak devre dışı: yeni commit için durum **yok** → `ci_must_pass`, merge `405`. Agent geri gelince `pending` → `ci_still_running`, merge yine `405` |

**Quality Gate, iki yön** (ekip-01; ekip-02'de aynı değerler):

| An | Jenkins `develop` | Kapı | Yeni kod coverage | İmaj |
|---|---|---|---|---|
| Taban analiz | `SUCCESS` | `OK` (koşul yok) | — | var (`013b113`) |
| Testsiz kod (`lab/04b-untested`) | **`FAILURE`** | **`ERROR`** | **%6,7** (eşik %80) | **yok** (`149cd28`) |
| Testler eklendi | `SUCCESS` | **`OK`** | **%97,8** | var (`75995c7`) |

Community Build sınırı gözlendi ve rehbere açıkça yazıldı: testsiz kodun feature build'i yeşil (analiz atlanıyor), MR merge edilebiliyor; kapı `develop`'ta kalıyor ve imaj üretilmiyor.

**Checkpoint, sıfırlama, yalıtım, kalıcılık:**

| Deneme | Sonuç | Kanıt |
|---|---|---|
| `sifirla-ekip 02` (Jenkins job + 4 credential, SonarQube projesi ve token'ı, agent imajları dahil) | Tamam | `10-…` |
| `checkpoint lab-04b`, sıfırdan (52 sn) | Build yeşil, kapı `OK`, imaj registry'de | `11-…` |
| `checkpoint lab-03b` (Gün 4 durumundan geri) | Jenkins ve SonarQube kaynakları, webhook, token kaldırıldı; "Pipelines must succeed" kapandı | `12-…` |
| Yalıtım: ekip-02'de iki lab koşusu ve üç checkpoint sırasında ekip-01 | Durum özeti **aynı** (110 satır: GitLab, registry, test VM, workstation, Jenkins, SonarQube) | `34-…` |
| Jenkins ve SonarQube yeniden başlatıldı | ekip-01 durumu aynı; agent kendiliğinden bağlandı; 47 + 36 denetim ve `dogrula-ci` geçti | `43-…` |
| `make bootstrap`, `ci` açıkken ikinci kez | Hatasız | `42-…` |
| `make dogrula-ci` | 59 / 59 | `40-…` |
| `make dogrula`, `ci` açıkken | 98 / 98 | `41-…` |

**Arayüz adımları:** Faz 4'teki bütün arayüz adımları tarayıcıda yapıldı; API'ye düşülmedi. Beş adım ikinci denemede çalıştı (seçici düzeltmesi): Multibranch taramasını bekleme, webhook onay metni, MR durum satırı, SonarQube "yeni kod" kartı, SonarQube token formundaki açılır liste. Üç denemeyi aşan olmadı. Token değerleri ekran görüntülerinde maskeli (denetlendi: access token, SonarQube token, Jenkins credential formları).

### Doğrulanmayanlar ve yalnızca yazılanlar

- **Temiz kurulum:** `ci` profili çalışan ortama eklenerek kuruldu. `make yik` → `make up-ci` → `make bootstrap` zinciri Faz 4 eklemeleriyle **koşulmadı** (volume silme onayı gerektirir; çalışan ortam korundu). Faz 6 provasında yapılacak.
- **ekip-01 koşusunun tam dökümü yok:** ekip-01'de adımlar tek tek çalıştırıldı (arayüz seçicileri düzeltilirken); çıktıları tek dosyada saklanmadı. Tam dökümler ekip-02'nin tek seferlik koşularında (`20-…`, `22-…`), ekip-01 için doğrulama çıktıları var.
- **Süreler:** LAB 04-B tek koşusunun süresi geçersiz (R32). Lab süreleri (90 ve 100 dk) bir katılımcıyla ölçülmedi.
- **Kuyruk denemesi** ortak agent'ı durdurur; `cozum.sh` içinde artık yalnızca `KUYRUK=1` ile koşar. Varsayılan (kapalı) hal, bu değişiklikten sonra baştan sona **koşulmadı** (tek fark o adımların atlanması).
- Eğitmen rehberlerindeki olumsuz örneklerden çalıştırılanlar: yanlış job adresi (`404`), MR olayı (`409`), durum yazmayan `Jenkinsfile`. **Çalıştırılmayanlar:** `analyze.sh`'de yanlış sıra; `gitlab-registry`'ye salt okunur token; webhook yokken `waitForQualityGate` zaman aşımı.
- Öğrenci rehberlerinin "Yaygın hatalar" tablolarındaki belirtilerin bir kısmı gözlenmedi (ör. `Authentication failed`, `Permission denied`, `There are no nodes with the label`, SonarQube `Not authorized`); bilinen hata metinleridir.
- "Set to auto-merge" ve merge edilmiş MR'ı "Revert" akışları denenmedi.
- SonarQube ticari sürüm akışı ve React analizi bonusu: kapsam dışı / yazılmadı.
- `sifirla-ekip` onay sorusu (etkileşimli) ve doğrulama betiklerinin sandbox dışı (integration) kullanımı (`JENKINS_USER`, `SONAR_USER` …) denenmedi.
- On ekibin aynı anda build etmesi; uzun süre açık kalmış Jenkins ve SonarQube; x86-64.
- SonarQube 26.11'in desteklediği PostgreSQL sürüm aralığı belgeden doğrulanmadı (17.12 ile çalışıyor).
- **Faz 5'e kalan:** `v*` tag build'i (tag keşfi), `main` build'i (yalnızca iskelet `Jenkinsfile` ile "boş" build görüldü), deploy stage'i.

### Karşılaşılan sorunlar

| # | Sorun | Sonuç |
|---|---|---|
| S13 | Multibranch job MR webhook olayına `409` dönüyor; secret token'ı denetlemiyor | Webhook yalnızca Push events; README §8 halka 1 buna göre yorumlandı (`slayt-guncellemeleri.md` C20, E) |
| S14 | Boş projeye ilk push'tan sonra GitLab `main`'i arka planda kendiliğinden koruyor; checkpoint'in koruma adımı `409` ile kırıldı (yarış) | Koruma adımı "sil, kur, doğrula" olarak yeniden yazıldı; yeniden denendi |
| S15 | `cekirdek.sh` iki denetimi `ci` açıkken yanlış sonuç verirdi: "kendi daemon'ı olan container'lar" beklentisi ve `docker.sock` araması (`agent-docker-sock` volume adını yakalıyordu) | İkisi de düzeltildi; `ci` açıkken 98 / 98 |
| S16 | Checkpoint'ten sonra doğrulama "webhook'a hiç push olayı gitmemiş" diye kaldı | Checkpoint, branch taramasını GitLab'in webhook testiyle başlatıyor: bağlantı da sınanmış oluyor |
| S17 | SonarQube 3 GB sınırının %88'ine çıktı | Sınır 4 GB (D67) |
| S18 | Jenkins 2.580'de credential ekleme sayfası değişmiş (eski `newCredentials` adresi `404`); SonarQube açılır listeleri klavyeyle sürülüyor | Tarayıcı betikleri yeni arayüze göre yazıldı; rehber ekran görüntüleri bu sürümden |
| S19 | Çalışma sırasında host uyku döngüsüne girdi | R32; uzun koşular `caffeinate -i` ile |

### Hazırlık ve ortam kurulumu

Kapsam: Jenkins (controller + agent, ayrı Docker daemon'ı), SonarQube Community + PostgreSQL; LAB 04-A doğrulama zinciri (altı halka); `lab/04b-untested` ve Quality Gate'in iki yönlü doğrulaması; `checkpoint/lab-04a`, `lab-04b`; checkpoint, sıfırlama ve doğrulama betiklerinin Jenkins ve SonarQube tarafı. K13 gereği yalnızca Community akışı yazılır.

Yapılanlar:

1. **Host incelemesi (K11):** tamamlandı; §6.
2. **Çekirdek profilin ölçümü** (2026-11-24, iki ekibin uygulaması test VM'de çalışırken, boşta): gitlab 3,95 GiB, workstation 2,02 GiB, nexus 1,56 GiB, test-vm 0,55 GiB, proxy + dns 0,02 GiB; **toplam ≈ 8,1 GiB**. Docker VM'inin içinden: 15,7 GiB'ın 8,0'ı kullanımda, 7,7'si kullanılabilir.

3. **Docker belleği 24 GB (K16):** kullanıcı ayarı değiştirdi; Docker VM 23,93 GiB. Lab önceden düzgünce durdurulmuştu; `make up` 40 sn, veriler yerinde, `make dogrula` geçti (`kanit/faz-4/02-yeniden-acilis.txt`, `03-make-dogrula.txt`).
4. **Host izlemesi:** `bootstrap/host-izle.sh` dakikada bir satır yazıyor (`kanit/faz-4/izleme.log`): host boş bellek yüzdesi, sıkıştırıcı, swap, yük, container toplamı.
5. **`ci` profili kuruldu ve açıldı** (2026-11-24): `jenkins`, `jenkins-agent`, `agent-docker`, `sonarqube`, `sonar-db`. Açılış ≈ 75 sn. Agent WebSocket ile bağlandı; agent'ın Docker daemon'ı registry'den imaj çekebiliyor (CA güvenilir, lab DNS çalışıyor). `bootstrap.sh jenkins sonarqube` iki kez çalıştırıldı, ikincisinde hiçbir şey yeniden oluşturulmadı (`kanit/faz-4/04-bootstrap-ci.txt`).
6. **Ölçüm, `ci` boşta:** jenkins 0,82 GiB, sonarqube 2,30 GiB, sonar-db 0,11 GiB, jenkins-agent 0,14 GiB, agent-docker 0,10 GiB (`ci` ≈ 3,5 GiB); çekirdek ≈ 5,3 GiB (yeniden başlatmadan hemen sonra; GitLab 2,84 GiB); **toplam ≈ 8,8 GiB / 23,93 GiB**. Build sırasındaki tepe henüz ölçülmedi.

### Faz 4 kararları

| # | Karar | Gerekçe |
|---|---|---|
| D50 | Jenkins global yapılandırması imajdaki Configuration as Code dosyasında (`images/jenkins/casc/jenkins.yaml`); ekip kullanıcıları ve klasörleri bootstrap'te Groovy ile. Plugin'lerin 89'u da sürümüyle sabit (`images/jenkins/plugins.txt`). | README §7 "tercihen Configuration as Code". Ekip sayısı değişken olduğu için klasörler betikle kurulur. |
| D51 | Yetki modeli: giriş yapan herkes `Overall/Read`; her ekip kullanıcısı (`ekipNN`) yalnızca kendi klasöründe (`ekip-NN`) job ve credential yönetir. | Slayt G4/7: "klasör düzeyi, ekipleri birbirinden ayırır". |
| D52 | Global `gitlab` bağlantısı ve `sonarqube` sunucu tanımı **token taşımaz**. Ekip, kendi Project Access Token'ını ve SonarQube token'ını klasör credential'ı olarak saklar; Jenkinsfile bunları adıyla verir: `gitLabConnection(gitLabConnection: 'gitlab', jobCredentialId: 'gitlab-api', useAlternativeCredential: true)`. Sabitlenen GitLab plugin'inin şemasında `jobCredentialId` ve `useAlternativeCredential` alanları doğrulandı. | README §7'deki "ortak Jenkins notu". Slayttaki `gitLabConnection('gitlab')` yazımı paylaşılan Jenkins'te ekip token'ını seçemiyor; uzun yazım gerekiyor (`slayt-guncellemeleri.md`'ye eklenecek). Davranış LAB 04-A'da doğrulanacak. |
| D53 | Agent'ın bağlantı sırrı `.env`'e girmez: controller açılışta ortak bir volume'a yazar, agent oradan okur. | Sır yazma kuralı; elle adım gerekmez. |
| D54 | Agent'ın Docker daemon'ı (`agent-docker`) soketini ortak volume'da, 990 numaralı gruba açar; TCP portu açılmaz. | Üçüncü ve son daemon. Slayttaki `permission denied … docker.sock` hatası aynı mekanizmayla üretilebilir. |
| D55 | Jenkins, agent ve SonarQube imajlarına lab CA'sı derleme sırasında eklenir (JVM güven deposu ve işletim sistemi). | Controller → GitLab ve SonarQube; SonarQube → Jenkins webhook'u; agent → GitLab, Nexus, SonarQube. TLS doğrulaması hiçbir yerde kapatılmadı. |
| D56 | SonarQube'da `sonar.validateWebhooks=false`. | SonarQube yerel ağ adresine webhook'u reddediyor (`Invalid URL: loopback … site-local …`); kurum içi Jenkins yerel ağdadır. GitLab'deki "Url is blocked" ile aynı türden bir ağ izni; sertifika doğrulamasıyla ilgisi yok. BELBİM yöneticisinden istenecekler listesine girecek. |
| D57 | Agent'taki build'ler `MCR` ve `HUB` değerlerini Jenkins'in global ortam değişkenlerinden alır. | Slayt G4/16'daki `docker build` komutunda `--build-arg` yok; kapalı ağda temel imaj iç aynadan gelmeli. |
| D58 | Sürümler: `dotnet-sonarscanner` 12.1.0, `sonar-scanner` CLI 8.5.0.16571. | 2026-11-24'te NuGet ve GitHub sürüm listelerinden. |
| D59 | Proje webhook'u yalnızca **Push events** ile kurulur; secret token alanı boş bırakılır. | Multibranch job MR olayını `409` ile reddediyor ve secret token'ı denetlemiyor (ölçüldü). Slayt G4/10'dan sapma. |
| D60 | Aynı Project Access Token iki credential olarak kaydedilir: `gitlab-api` (GitLab API token) ve `gitlab-repo` (Username with password). Multibranch kaynağı "Git", adres HTTPS. | GitLab plugin ve Git plugin farklı credential türü ister; yalnızca `api` scope'u ikisine de yetiyor. |
| D61 | Jenkins'in registry girişi için ayrı deploy token: `ekipNN-jenkins` (`gitlab-registry` credential'ı). | LAB 03-B'deki token'ın değeri bir kez gösterilir; her tüketiciye ayrı token ayrı ayrı iptal edilebilir. |
| D62 | SonarQube projesi: ad ve anahtar `saha-portal-ekipNN`, ana branch adı `develop`, yeni kod tanımı kurum varsayılanı; token türü Project Analysis Token. | Analiz `develop`'tan gönderiliyor; en dar yetkili token yetiyor (ölçüldü). |
| D63 | Gün 4 lablarında lab başına bir issue (`#4` pipeline, `#5` SonarQube); branch adları numarasız (`feature/pipeline`, `feature/sonar`, `feature/siparis-ozeti`, `feature/siparis-ozeti-testleri`). Talep özeti MR'ları issue'ya bağlanmaz. | K15 ile uyumlu; 100 dakikalık labda arayüz adımlarını azaltır. **Benim yorumum**; istenirse issue'lar çoğaltılır. |
| D64 | `checkpoint lab-04a` / `lab-04b`: `ekip-ci.sh` ekibin Jenkins job'ını, credential'larını ve SonarQube projesini **silip yeniden kurar**; taramayı webhook testiyle başlatır; `develop` build'inin yeşil bitmesini bekler. `lab-04b` tek analizle kurulur. | Belirli bir son durum; "önce kaldı, sonra geçti" geçmişi checkpoint'te yoktur (doğrulama betiği `KAYNAK=checkpoint` ile bunu atlar). |
| D65 | Checkpoint'lerde `1.0.1` imajları LAB 03-B sonundaki commit'ten derlenir (`develop`'un ilk-ebeveyn zincirinde şablondaki kadar geride). | `develop` SHA etiketini Jenkins üretir; iki build aynı etiketin üzerine yazmasın. |
| D66 | Gün 4 doğrulama betikleri Jenkins ve SonarQube'u ekip kullanıcısıyla (`ekipNN`), salt okunur sorgular; parolalar standart girişten aktarılır. Canlı merge reddi yalnızca çözüm koşusunda üretilir. | Doğrulama hiçbir şeyi değiştirmemeli. |
| D67 | SonarQube bellek sınırı 4 GB. | S17. |
| D68 | Kuyruk kanıtı adımı (`ci-durum.sh agent offline`) `cozum.sh` içinde varsayılan olarak kapalı (`KUYRUK=1` ile açılır). | Ortak agent'ı durdurur; ders sırasında yanlışlıkla çalışmasın. |
| D69 | `make dogrula-ci` (`dogrula/ci.sh`): Jenkins global tanımları ve plugin sürümleri, erişim (anonim `403`, ekipler arası `404`), agent araçları ve CA güveni, agent daemon'ı, SonarQube webhook teslimleri, üç Docker daemon'ı. | CI profilinin `cekirdek.sh` karşılığı. |

### Faz 5 kararları

| # | Karar | Gerekçe |
|---|---|---|
| D70 | Paket kimliği `Saha.Common.Contracts.EkipNN`, `1.0.0`; servisler `PackageReference`; iki Dockerfile'dan `COPY src/common-contracts/` satırı kalkar. Branch `feature/ortak-paket`, issue `#6`. | Ekipler aynı hosted depoya yayınlar (G5/13 notu). |
| D71 | `sifirla-ekip` ve her checkpoint ekibin paketini `nuget-hosted`'dan siler; `lab-05a` ve `final` checkpoint'leri ekibin kendi API anahtarıyla yeniden yayınlar. | Redeploy kapalı: aksi halde LAB 05-A tekrarlanamaz. |
| D72 | Deploy `deploy/deploy.sh` ile: pull (etiket yoksa durur) → `.env` → `up -d` → `deploy-kayit.log` (zaman, etiket, commit, kaynak, üç digest). Jenkins aynı betiği SSH ile çağırır; rollback da aynı betikle. Betik öğrenciye tam metin verilir. | README'nin deploy kaydı ve "rollback etiket doğrulandıktan sonra" şartı; tek yer. |
| D73 | Jenkins'in test VM anahtarı ayrı üretilir (`~/.ssh/jenkins-test-vm`, yorum `jenkins-ekipNN`), `ssh-copy-id` ile yetkilendirilir, `test-vm-ssh` (SSH Username with private key) olarak eklenir. Sıfırlama ve erken checkpoint'ler satırı test VM'den siler. | Kişisel anahtar Jenkins'e konmaz. |
| D74 | Tag build'i: `buildingTag()`; `SHA=$(git rev-parse --short HEAD)`, `SURUM=${TAG_NAME#v}`; `docker pull` + `docker tag` + `docker push`. İmaj yoksa 20 × 15 sn bekler, sonra anlaşılır hatayla durur. | README "yeniden derlemez"; R11. |
| D75 | Deploy ve smoke test `develop` (TAG = commit SHA) ve tag build'inde (TAG = SemVer); `disableConcurrentBuilds()`; smoke test'te her istek `--retry`. Build açıklaması düz metin (` · `). | README tablosu; S27, S28. |
| D76 | Tag build'i için: "Discover tags" + build stratejileri "Regular branches" ve "Tags" (en çok 1 gün); webhook'ta "Tag push events". Tag, `release` → `develop` geri birleştirmesinden ve `develop` deploy'undan sonra atılır. | Ölçüldü (C31); tek test ortamı (R35). |
| D77 | Final branch'leri: `feature/deploy` (issue'suz), `feature/12-miktar-dogrulama` (slayttaki ad), issue `#7`; `release/1.1.0`; `v1.1.0` açıklamalı tag (lider). | K15 ile uyumlu. |
| D78 | Bonus `Pack & Publish` final `Jenkinsfile`'ında yok; eğitmen çözümünde ayrı (`05a-bonus/pack-publish.groovy`); push'tan önce sürümün Nexus'ta olup olmadığına bakar. | Elle yayınlanmış `1.0.0` release sonrası `main`'i kırardı. |
| D79 | Yönetici ayarları: CasC'de `nuget-config` (managed file); bootstrap `agent-ssh` adımı (agent `known_hosts`); agent imajında `MSBUILDDISABLENODEREUSE=1`. | Slayt G5/11, G5/20 notları; S26. |
| D80 | `ekip-ci.sh` job'ı arayüzün ürettiği XML yapısıyla oluşturur (`owner reference="../.."`) ve oluşturduktan sonra kaynak listesini yeniden yazıp kaydederek dener. | S20 (Faz 4 hatası). |
| D81 | web-ui'de final görevi için kod değişikliği yok; mevcut hata gösterimi tarayıcıda doğrulandı. | `api.js` zaten `error` alanını gösteriyor. |

### İlk deney (ekip-02, API ile; lab betikleri ve rehberler buna göre yazıldı)

Aşağıdakiler 2026-11-24'te ekip-02 üzerinde, adımlar API ve komut satırıyla yapılarak çalıştırıldı; sonra öğrenci akışı, doğrulama betiği ve checkpoint olarak paketlendi (yukarıdaki özet). Buradaki değerler ilk deneyindir (ör. yeni kod coverage'ı %4,4; öğrenci akışında %6,7).

**LAB 04-A zinciri**

| Halka | Sonuç |
|---|---|
| Project Access Token (`api`, Maintainer) | Yalnızca `api` scope'u ile hem API hem Git-over-HTTPS çalışıyor: aynı token Jenkins'te iki credential'da kullanılır: `gitlab-api` (tür: GitLab API token; commit status) ve `gitlab-repo` (tür: Username with password; Multibranch job'ın repo okuması) |
| Multibranch job (`ekip-NN/saha-portal-ekipNN`, Git kaynağı, HTTPS) | Oluşturuldu; `Jenkinsfile` bulunan her branch için job açıldı |
| Webhook `https://jenkins.<D>/project/ekip-NN/saha-portal-ekipNN` | GitLab'de test ve gerçek push: `200`. GitLab'in izin listesi (yalnızca Jenkins adresi) yeterli |
| Push → build | Branch'in build'i kendiliğinden başladı; Restore, Build, Unit Test, web-ui agent'ta geçti (16 sn) |
| Commit status | `jenkins: success`, ekibin kendi token'ıyla (`jobCredentialId: 'gitlab-api'`); `target_url` Jenkins build'ini gösteriyor |
| `gitlabBuilds(builds: ['jenkins'])` | Build başlarken durum `pending`; MR `ci_still_running` |
| "Pipelines must succeed" + hiç durum yok | MR `detailed_merge_status=ci_must_pass`; merge `405 Method Not Allowed` |
| Test kırık | Durum `failed`; MR `ci_must_pass`; merge `405` |
| Başarılı | MR `mergeable` |

Bulgular: (1) **Webhook secret token'ı Multibranch job'da denetlenmiyor**: yanlış token ile yapılan istek de `200` döndü (GitLab plugin 1.2169). (2) Starter'daki yalnızca yorumdan oluşan `Jenkinsfile` de bir "pipeline" sayılıyor: `main` ve `develop` için job açılıyor, boş build `SUCCESS` ile bitiyor ve GitLab'e durum yazmıyor. (3) MR listesindeki `detailed_merge_status` bayat kalabiliyor; tek MR uç noktası güncel değeri veriyor.

**LAB 04-B, `community` akışı**

| Adım | Sonuç |
|---|---|
| Analiz ve kapı yalnızca `develop`'ta (`when { branch 'develop' }`) | Feature branch'te "Build" ve "Unit Test" çalıştı, analiz atlandı; `develop`'ta tersi |
| `ci/analyze.sh` (begin → build → test → end), token klasör credential'ından | `ANALYSIS SUCCESSFUL`; coverage raporu okundu (9 dosya) |
| `waitForQualityGate abortPipeline: true, credentialsId: 'sonar-token'` | Görev `SUCCESS`, kapı sonucu geldi |
| İlk analiz (taban) | Kapı `OK`, koşul yok (henüz yeni kod dönemi yok); genel coverage %62,4 |
| Docker Build & Push (`develop`) | Agent'ın kendi daemon'ında üç imaj derlendi ve commit SHA etiketiyle gönderildi (build toplam 46 sn) |
| **Testsiz kod** (`git checkout sablon/lab/04b-untested -- src/order-service` + katılımcının kendi commit'i, MR ile `develop`'a) | Kapı **`ERROR`**: `new_coverage` %4,4 (eşik %80), 87 yeni satır, yeni issue 0. Pipeline `FAILURE` (`Pipeline aborted due to quality gate failure: ERROR`); web-ui ve Docker stage'leri atlandı; o commit için imaj **yok** |
| **Testler eklendi** (`OrderSummaryTests.cs`, MR ile) | Kapı **`OK`**: `new_coverage` %97,8; imaj yayınlandı |

Yeni kod tanımı varsayılan ("Previous version"); taban, ilk analizin tarihi. R2 (hazır branch'in commit tarihi) kapandı: dosyalar katılımcının kendi commit'iyle alındığında yeni kod sayılıyor.

Ölçüm (build'ler sırasında, iki ekip verisiyle): jenkins 1,1 GiB, sonarqube 2,6 GiB (3 GB sınırının %88'i: sınır 4 GB'a çıkarılacak), agent 0,35 GiB, agent-docker 0,44 GiB; **bütün lab ≈ 10,9 GiB / 23,93 GiB**. Host boş bellek oranı %55–67.

### Faz 4'te yaşanan iki olay

- **Parola çıktıya düştü (düzeltildi).** Jenkins'e ekip kullanıcılarını kuran Groovy betiğinin dönüş değeri, iki sandbox Jenkins hesabının (`ekip01`, `ekip02`) türetilmiş parolasını komut çıktısına ve `kanit/faz-4/04-bootstrap-ci.txt` dosyasına yazdı. Dosya hemen boşaltılıp yeniden üretildi; betik değer döndürmeyecek şekilde düzeltildi; iki parola türetme anahtarı değiştirilerek **yenilendi** (betik parolayı her çalıştırmada eşitliyor). Eski değerler artık geçerli değil. Değerler oturum dökümünde bir kez görünmüş oldu.
- **Kapsam dışı bir komut çalıştırdım.** Bir ölçüm komutunun içinde, orada işi olmayan `docker run --rm --privileged --pid=host alpine:3.24 true` satırı kalmıştı; host Docker'ında hiçbir şey yapmayan (`true`) geçici bir container çalıştı ve silindi. Etkisi yok; ama `belbim-lab` dışında bir container başlatmış oldum ve `alpine:3.24` imajı daha önce yoksa indirilmiş olabilir. İmajı silmedim (önceden senin olup olmadığını bilemiyorum).

## 18. Faz 5: Gün 5 labları

### Özet

LAB 05-A (ortak paket Nexus'ta) ve LAB 05-B (final: uçtan uca teslimat) için öğrenci rehberi, eğitmen çözüm rehberi, çözüm betiği, doğrulama betiği ve checkpoint (`lab-05a`, `final`, `final-main`) yazıldı. İki lab **ekip-01** ile öğrenci akışıyla koşuldu (arayüz adımları GitLab, Jenkins, Nexus ve uygulamada gerçek tarayıcıda). **ekip-02**'de `final` → `lab-04b` geri dönüşü, iki labın tek seferlik koşusu, checkpoint'ler, bonus ve iki hata kolu denendi. Kanıtlar `kanit/faz-5/` altında.

| Lab | ekip-01 (öğrenci akışı) | ekip-02 (tek seferde) | Checkpoint (ekip-02) | Doğrulamanın olumsuz yönü |
|---|---|---|---|---|
| LAB 05-A | 19 / 19 (`lab-05-a-ekip01.txt`) | 93 sn; 19 / 19 (`20-…`, `lab-05-a-ekip02.txt`) | `lab-05a`: 49 sn, 18 / 18 (`30-…`, `31-…`) | LAB 04-B durumunda 11 kaldı, 8 geçti (`11-…`) |
| LAB 05-B | 48 / 48 (`lab-05-b-ekip01.txt`) | 290 sn; 49 / 49 (`22-…`, `lab-05-b-ekip02.txt`) | `final`: 69 sn, 41 / 41 (`34-…`, `35-…`) | LAB 05-A durumunda 32 kaldı, 7 geçti (`21-…`) |

**Uçtan uca iz (ekip-01):** issue `#7` → MR `!14` (lider onayı, pipeline yeşil) → `develop #8` (Quality Gate `OK`, test VM `tag=e0c3bbc`) → `release/1.1.0` → `main #2` (`7b61f73`) → `v1.1.0 #1` (tag push'tan sonra kendiliğinden, 11 sn) → `order-service:1.1.0` = `order-service:7b61f73` = `sha256:aabcedeeb5f1…` (üç serviste de aynı digest) → test VM `TAG=1.1.0`, `deploy-kayit.log`: `tag=1.1.0 commit=7b61f738… kaynak=…/v1.1.0/1/ product-service@sha256:… order-service@sha256:… web-ui@sha256:…`.

**Olumsuz → olumlu denetimler:**

| Senaryo | Olumsuz | Olumlu |
|---|---|---|
| Aynı paket sürümü | ikinci push `409 … redeploy is not allowed` | yeni sürüm (`1.0.1`, bonus) yayınlandı |
| Miktar doğrulaması | testler kırmızı (`Failed: 2`); `1.0.1`'de `quantity=0` → `201` | `quantity=0` → `400 {"error":"Miktar en az 1 olmalı."}`, `quantity=2` → `201`; arayüzde mesaj |
| Rollback | — | `1.1.0` → `1.0.1` (`/api/orders/summary` `404`) → `1.1.0` (`200`); kayıtta üç satır |
| Rollback hedefi registry'de yok | `deploy.sh … 9.9.9` pull'da `not found`, çıkış 1; çalışan sürüm ve kayıt değişmedi | — |
| Tag'in commit'i için imaj yok | tag build'i 5 dk bekleyip `HATA: … imaj yeniden derlenmez` ile durdu; deploy yok | `main` build'inden sonra atılan tag'de SemVer etiketi ve deploy |
| Bonus: paket klasörü değişti, sürüm aynı | `main #4` push denemeden durdu (`HATA: … 1.0.1 Nexus'ta zaten var`) | `main #3` `1.0.1`'i yayınladı (`--configfile` + `nexus-hosted`) |

**Yalıtım:** ekip-02'deki bütün işlemler (geri dönüş, iki tek koşu, dört `final`, bonus, iki hata kolu, Package Registry demosu, agent imajının yenilenmesi) boyunca ekip-01'in durumu aynı kaldı (187 satır: GitLab, registry, test VM uygulaması ve deploy kaydı, Jenkins anahtarı, workstation, Nexus paketi, Jenkins, SonarQube; `70-yalitim-ekip01.txt`).

**Ortam:** `make dogrula-ci` 62 / 62, `make dogrula` 98 / 98 (`60-…`, `61-…`). Bellek en yüksek 14,0 GiB / 23,93 GiB; host boş bellek en düşük %53; yeniden başlama yok.

### Doğrulanmayanlar ve yalnızca yazılanlar

- **Temiz kurulum** (`make yik` → `up-ci` → `bootstrap`): koşulmadı (volume silme izni gerekir); Faz 6.
- **`sifirla-ekip`** Faz 5'te çalıştırılmadı; eklenen kaldırma işleri (Nexus paketi, test VM'deki Jenkins anahtarı) checkpoint geri dönüşünde çalışan kodla aynı.
- **Son `Jenkinsfile`** (smoke test'te ikinci isteğin yeniden denemesi, düz metin açıklama) yalnızca `final` checkpoint'iyle (develop, main, `v1.1.0` build'leri) koşuldu; iki ekibin tek seferlik/öğrenci koşuları önceki sürümle yapıldı.
- **Arayüz adımı API ile doğrulandı:** webhook'ta "Tag push events" (üçüncü denemede kaydedildi; kayıttan sonraki liste denetimimin seçicisi tutmadı, ayar API ile ve liste görüntüsüyle doğrulandı).
- `disableConcurrentBuilds()` altında aynı branch'e art arda push; webhook "Test > Tag push events"; ekip sunumu; lab süreleri bir katılımcıyla.
- Bonus yalnızca deneme betiğiyle (API ile MR) koşuldu; öğrenci rehberindeki bonus iskeleti arayüzden izlenmedi.
- `nexus-nuget-key` credential'ı arayüzden eklenmedi (deneme Groovy ile ekledi).
- x86-64; on ekiple eşzamanlı build (R31).

### Karşılaşılan sorunlar

| # | Sorun | Sonuç |
|---|---|---|
| S20 | **Faz 4 hatası:** `ekip-ci.sh`'nin XML ile oluşturduğu job'da `owner` bağı yoktu; job arayüzden kaydedilemiyordu (`configSubmit`: `NullPointerException`) ve yarım uygulanan ayardan sonra tarama credential'ı bulamıyordu. Checkpoint'ten gelen bir ekip 5. gün tag ayarını yapamazdı | XML düzeltildi; oluşturulduktan sonra "kaydet" denemesi eklendi (D80). ekip-02'de checkpoint'ten gelen job'a tag ayarı arayüzden kaydedildi |
| S21 | **Sızıntı:** Nexus API anahtarı ekranının "maskeli" görüntüsünde anahtar iki yerde açık kaldı (maske yalnızca `code` öğelerini kapatıyordu). Görüntü yerel diskteydi; repoya, kanıtlara ya da dışarıya gitmedi | Görüntü silindi; ekip01'in anahtarı yenilendi (`ekip-nexus.sh anahtar-yenile`); görüntüden önce anahtar sayfanın bütün metninden silinip denetleniyor; yeni görüntü gözle denetlendi |
| S22 | Arayüz adımlarında deneme sayısı: Nexus API anahtarı **4 denemede** çalıştı (giriş alanı, menü öğesi, gecikmeli parola penceresi), Jenkins tag ayarı 4 kez düzenlendi (biri S20'nin asıl hatası), GitLab webhook düzenleme 3 denemede kaydetti (kayıttan sonraki liste denetimi tutmadı; ayar API ile doğrulandı) | Her denemede farklı ve görüntüyle doğrulanmış bir neden vardı; kural aşımı burada bildiriliyor |
| S23 | Agent'ta `MSB4166: Child node exited prematurely` (develop build'i) | `MSBUILDDISABLENODEREUSE=1` (agent imajı `faz5`); sonraki bütün build'ler geçti |
| S24 | Smoke test'in ikinci isteği yeniden denemesizdi; bir koşuda `502` | İki istek de `--retry` (C40) |
| S25 | Build açıklamasında `<br>` metin olarak göründü | Ayırıcı ` · ` |
| S26 | Çözüm betiğinde: `git diff` boş döndüğü için `grep` başarısız sayıldı (dosya index'e de yazılıyordu); bonus denemesinde workstation'da `python3` yoktu; bir kanıt dosyası zsh `noclobber` yüzünden yazılmadı ve eski çıktı okundu | `git diff HEAD`; `awk`/`sed`; `>|`. Üçü de benim betik hatam; lab davranışını etkilemedi |
| S27 | Host yükü (lab dışı uygulama, pil modu) ve uyku döngüsü süreleri bozdu (`checkpoint lab-05a` 13 dk 45 sn; yük düşünce 49 sn) | Uzun koşular `caffeinate -i`; süreler aralıkla verildi |

### Faz 6'ya kalanlar (Faz 5 kaynaklı)

- `belbim-yoneticisinden-istenecekler.md`: `nuget-config` managed file, agent `known_hosts` (test VM), `MSBUILDDISABLENODEREUSE=1`, SSH Agent plugin, `sonar.validateWebhooks`, test VM'de ekip dizinleri ve `deploy` kullanıcısı, Nexus `nuget-hosted` redeploy kapalı.
- `hata-senaryolari.md`: `409` (aynı sürüm), `MSB4166`, smoke `502`, tag build'i başlamadı (üç ayar), "imaj yok", `Host key verification failed`, `Permission denied (publickey)`.
- Temiz kurulumda `prova.sh` ile beş günün baştan sona koşusu.

## 19. Faz 6: temiz kurulum, uçtan uca prova ve eğitim teslimi

**Tarih:** 2026-11-24, Europe/Istanbul. Kullanıcı bütün `belbim-lab` verilerinin silinmesine açık izin verdi. Yalnızca bu Compose projesinin container ve volume'ları kaldırıldı; host'un başka projelerine dokunulmadı. `.env`, CA dosyaları, kaynaklar ve host imaj cache'i korundu. Bu, **boş servis volume'larıyla kurulum** kanıtıdır; yeni bir bilgisayarda sıfır imaj cache'iyle indirme/kurulum kanıtı değildir.

### Teslimler

- [komutlar.md](komutlar.md): on labın terminal komutları, kısa açıklamalar, gerekli arayüz/editör/rol geçişleri; Jenkins komut referansı ve eğitmen kurtarma komutları. Tek parça çalıştırılacak betik değildir.
- [Prova rehberi](lab-rehberleri/egitmen/prova.md), [hata senaryoları](lab-rehberleri/egitmen/hata-senaryolari.md), [eğitim öncesi kontrol listesi](lab-rehberleri/hazirlik-kontrol-listesi.md), [BELBİM yöneticisi listesi](lab-rehberleri/belbim-yoneticisinden-istenecekler.md).
- `dogrula/prova.sh`: ekip-99 ile on lab; terminal + gerçek Playwright arayüz adımları; her labın ardından salt okunur başarı denetimi; ilk hatada durma ve kontrollü devam.
- `dogrula/temiz-prova.sh`: açık izin değişkeniyle bütün lab volume'larını silme → boş volume denetimi → `up-ci` → bootstrap → çekirdek/CI kontrolleri → on lab.
- `dogrula/onkontrol.sh`: Docker Compose gerektirmeyen, kurumda yalnızca okuma yapan DNS/TLS/API/SSH denetimi. Kimlik bilgisi yoksa ilgili ayar “geçti” sayılmaz. Sandbox'ta **28/28**; BELBİM'de çalıştırılmadı. GitLab lisans katmanı yalnızca ortam beyanıdır, lisans doğrulaması yapılmış sayılmaz.
- `dogrula/ek-hatalar.sh` ve `dogrula/ci-hata-demolari.sh`: ek olumsuz/olumlu senaryolar. CI demosu yalnızca boş sandbox bakım anında; geçici yanlış Sonar webhook hedefi EXIT tuzağıyla da geri yüklenir.

### İlk tam akış ve bulunan hatalar

İlk boş-volume kurulumunda Jenkins bağlantı doğrulaması durdu (`temiz-prova-ilk-deneme/bootstrap.log`). Düzeltmeden sonra yeniden bütün volume'lar silinerek başlandı. Bu ikinci kurulumdaki on lab tamamlandı: **285 geçti, 0 kaldı**. Ancak LAB 05-A paket arayüzü adımında duruldu, seçici düzeltildi ve yayın sonrası adımdan devam edildi. **Bu koşu kesintisiz tek seferlik koşu diye sunulmaz.** Akış/doğrulama logları [temiz-prova](kanit/faz-6/temiz-prova/), sonuç çizelgesi [sonuclar.tsv](kanit/faz-6/temiz-prova/sonuclar.tsv), 182 tarayıcı görüntüsü [img-ilk](kanit/faz-6/img-ilk/) altında.

| Lab | İlk tamamlanan temiz-volume akışındaki kontrol | Süre (otomasyon; katılımcı süresi değildir) |
|---|---:|---:|
| 01-A | 13/13 | 38 sn |
| 01-B | 11/11 | 8 sn |
| 02-A | 23/23 | 128 sn |
| 02-B | 17/17 | 105 sn |
| 03-A | 36/36 | 60 sn |
| 03-B | 34/34 | 57 sn |
| 04-A | 36/36 | 155 sn |
| 04-B | 47/47 | 291 sn |
| 05-A | 19/19 | 30 sn hatada durma + 100 sn devam; düzeltme süresi hariç |
| 05-B | 49/49 | 299 sn |

İlk akışın final izi: issue `#7` → MR `!14` → develop → release/1.1.0 → main `876e5f8` → `v1.1.0` → order-service `1.1.0` digest `540d20196c0c…` → test VM deploy kaydı. Üç serviste SemVer ve SHA digest eşitliği, quantity 0→400 / 2→201 ve 1.1.0→1.0.1→1.1.0 rollback geçti. İki GET isteği de retry içeren Jenkinsfile gerçek lab akışında çalıştı; Faz 5'teki “yalnızca checkpoint ile koşuldu” açığı kapandı.

| Bulgu | Düzeltme ve kanıt |
|---|---|
| **S28 — Temiz Jenkins ilk açılışı:** GitLab plugin'i CasC `gitlab` bağlantısının yanında adsız, URL'siz, credential'sız bir kayıt ekliyordu; bootstrap `gitlab-connection=gitlab,` ile durdu | `60-jenkins.sh` yalnızca üç alanı da boş olan kayıtları temizler; adı olan başka bağlantıları silmez. API yöntemi kurulu plugin sınıfından doğrulandı. Yeniden boş-volume bootstrap geçti |
| **S29 — Nexus paket ağacı:** çift tıklama temiz arayüzde paketi açmadı; sürüm seçilemedi | `nexus.cjs` paket satırının expander'ını açar, sürüme tek tıklar ve detay başlığını bekler. Öğrenci rehberi aynı adımla güncellendi; devam koşusu geçti |
| **S30 — Ortak agent Docker girişi:** ekip-02 sıfırlanınca ortak `$HOME/.docker/config.json` iptal edilmiş token tutuyordu; public temel imaj pull bile HTTP Basic Access denied oldu | LAB 04-B/05-B Jenkinsfile'larında `DOCKER_CONFIG = "${WORKSPACE}@tmp/docker-config"`; build context'i dışında, her workspace'e ayrı giriş. En dış `post/always` yalnızca kendi config dosyasını siler. Checkpoint'ler kaynak üreticisiyle yeniden üretildi. CI denetimi anonim pull'u boş geçici config ile yapar, ayrıca ortak config'te giriş kalmadığını denetler. İlk hata [kurtarma-ilk/ci-son.log](kanit/faz-6/kurtarma-ilk/ci-son.log); anonim erişim düzeltmesi [ci-yalitim-duzeltmesi.log](kanit/faz-6/ci-yalitim-duzeltmesi.log) |
| **S31 — Workstation sıfırlama sertleştirmesi:** yalnızca ekip proje etiketi olan demo container/volume üzerinde eski `docker compose down` çıkış 0 verdi fakat “Resource is still in use” uyarısıyla kaynaklar kaldı | Sıfırlama yalnızca ilgili `com.docker.compose.project=ekipNN` etiketiyle container ve volume kaldırır; hatalar artık yutulmaz. Son kurtarma koşusu öncesine gerçek yerel container/volume fikstürü eklendi; öncesi varlık, eski komuttan sonra kaynakların kalması, sonrası yokluk denetlenir. İlk denetimim hatalı biçimde “compose dosyası yok” hatası bekledi; gerçek davranış uyarı + çıkış 0 olarak kaydedildi |
| Kanıt denetimi giderilmiş eski webhook hatasını sürekli arıza sayıyordu | Son 20 teslimde her projenin en yeni teslimi geçmeli; geçmiş hata sayısı ayrıca yazılır. Başka projenin başarısı son başarısız teslimi örtmez |
| Ek hata betiği GitLab API'sinden birebir “is blocked” bekledi | Gerçek cevap `422 {"error":"Invalid url given"}`. Metin/sürüm farkı kaydedildi, aynı URL'nin reddi ve izinli Jenkins URL'sinin kabulü ayrı doğrulandı |
| Öğrenci akışında küçük eksikler | LAB 05-B `feature/deploy` açılışı tam terminal bloğu; LAB 04-B `chmod +x`; LAB 03-A/B açılış GET'lerine retry; hata anında credential/token ekran görüntüsü alınmaz |

### Ek hata senaryoları — gerçek olumsuz ve olumlu koşular

- [ek-hatalar.log](kanit/faz-6/ek-hatalar.log): **13/13**; yanlış Git CA→doğru CA, Docker socket izni→yetkili kullanıcı, port çakışması→boş port, izole boş feed NU1101→Nexus group restore, olmayan etiket→var olan 1.1.0. Olmayan etiketle deploy pull'da durdu; `.env`, deploy kaydı, container kimlikleri/imajları değişmedi; uygulama 200 verdi.
- LAB 05-A'da aynı 1.0.0 paketi ikinci kez yayınlanınca 409. Ardından [nexus-yeni-surum.log](kanit/faz-6/nexus-yeni-surum.log) ile **1.0.1 yayınlandı**; ana labın API referansları değiştirilmedi.
- GitLab URL izin listesi değiştirilmeden Nexus host'una hook ekleme reddedildi; Jenkins host'una geçici hook ekleme kabul edildi, sonra hook silindi ([ci-hata-demolari-son.log](kanit/faz-6/ci-hata-demolari-son.log)).
- Sonar webhook yanlış hedefte HTTP 403; gerçek analiz görevi `PENDING`, 30 saniyelik bekleme sonunda `ABORTED` ([qg-timeout.log](kanit/faz-6/qg-timeout.log)). Doğru hedef geri yüklendi; aynı job `SUCCESS`, Quality Gate `OK` ([qg-duzeltildi.log](kanit/faz-6/qg-duzeltildi.log)).
- SonarScanner boş geçici dizinde `end` çağrısını begin/build olmadığı için reddetti ([scanner-yanlis-sira.log](kanit/faz-6/scanner-yanlis-sira.log)); doğru begin→build→test→end sırası gerçek LAB 04-B/05-B analizlerinde geçti.
- NU1605, conflict, korumalı branch/tag reddi, gerçek Docker x509, registry yetki reddi, SQLite Error 14 ve veri kalıcılığı, kırmızı testin merge'ü engellemesi, Quality Gate ERROR→OK, miktar validasyonu ve rollback on labın kendi loglarında.
- İmajsız commit'e tag'in 5 dakika sonra durması ve bonus Pack & Publish sürüm kontrolü **Faz 5 kanıtlarıdır**, Faz 6'da yeniden çalıştırılmış sayılmaz. GitLab Package Registry demosu, agent offline kuyruk demosu ve aralıklı MSB4166 hatası da bu yeni koşuda yeniden üretilmedi.

### Checkpoint, sıfırlama ve yalıtım

İlk kurtarma koşusunda ekip-02'ye `final` uygulandı: develop/main/tag build'leri `SUCCESS`, final denetimi **41/41**. Sonra `sifirla-ekip 02` çalıştı; GitLab proje, Nexus paket, Jenkins job/credential, SonarQube proje/token, test VM uygulama/volume/Jenkins SSH anahtarı ve workstation repo/giriş/volume için **8/8** bağımsız kontrol geçti. Ekip-99'un öncesi/sonrası **191 satırlık** durum dökümü aynı; diff boş. Kanıtların ilk sürümü [kurtarma-ilk](kanit/faz-6/kurtarma-ilk/) altında. Bu test S30'u buldu; düzeltmenin son kurulumda yeniden doğrulanması aşağıdaki sonuçta ayrıca kayıtlıdır.

### Son kesintisiz koşu ve teslim durumu

Son kaynaklarla, Docker giriş yalıtımı düzeltmesi ve yeniden üretilen checkpoint'ler dahil, **tekrar boş volume'larla kurulum ve on lab tek komutla, kesintisiz tamamlandı: 285/285.** Başlatıcı çıkış kodu 0; `sonuclar.tsv` içinde KALDI veya devam satırı yok. Otomasyon lab süreleri toplamı 1273 sn (21 dk 13 sn); kurulum/ön kontroller ve insan süreleri bu toplama dahil değildir.

| Lab | Durum | Denetim | Otomasyon süresi |
|---|---|---:|---:|
| 01-A | SANDBOX_VERIFIED | 13/13 | 37 sn |
| 01-B | SANDBOX_VERIFIED | 11/11 | 8 sn |
| 02-A | SANDBOX_VERIFIED | 23/23 | 126 sn |
| 02-B | SANDBOX_VERIFIED | 17/17 | 104 sn |
| 03-A | SANDBOX_VERIFIED | 36/36 | 61 sn |
| 03-B | SANDBOX_VERIFIED | 34/34 | 59 sn |
| 04-A | SANDBOX_VERIFIED | 36/36 | 166 sn |
| 04-B | SANDBOX_VERIFIED | 47/47 | 290 sn |
| 05-A | SANDBOX_VERIFIED | 19/19 | 109 sn |
| 05-B | SANDBOX_VERIFIED | 49/49 | 313 sn |

Kanıt: [sonuç çizelgesi](kanit/faz-6/temiz-prova-son/sonuclar.tsv), [volume silme sonrası boş liste](kanit/faz-6/temiz-prova-son/volume-silme-sonrasi.txt), [bootstrap](kanit/faz-6/temiz-prova-son/bootstrap.log), [final denetimi](kanit/faz-6/temiz-prova-son/05-b-dogrula.log). Yeni final izinin main commit'i `b3b77b6`; order-service `1.1.0` digest'i `fa18f041338f…`; üç serviste SemVer/SHA digest'leri eşit. Son kaynaklarla checkpoint/sıfırlama regresyonu da tamamlandı: **41/41 checkpoint**, **8/8 sıfırlama**, ekip-99'un **187 satırlık** durum kaydı değişmedi ([boş diff](kanit/faz-6/ekip99-yalitim.diff)). Yerel deneme container/volume'u önce vardı; eski komut uyarı verip bıraktı; düzeltilmiş sıfırlamadan sonra ikisi de yok. Sıfırlama doğrulayıcısındaki ilk beklenti hatası S31'de açıklandı; bu ek testin devamı, yukarıdaki kesintisiz on lab koşusundan ayrıdır.

Ekip-02 token'ları iptal edildikten sonra ekip-99 **v1.1.0 #3 SUCCESS**: ayrı workspace Docker girişiyle SemVer yayın/deploy/smoke geçti; ortak config'te giriş ve tamamlanan job'ların config dosyaları kalmadı ([yalıtım](kanit/faz-6/docker-giris-yalitimi.log), [gerçek build logu](kanit/faz-6/docker-giris-yalitimi-tag.log)). Son final denetimi tekrar **49/49** ([log](kanit/faz-6/lab-05-b-son.log)).

**Son ortam:** çekirdek **107/107**, CI **64/64**; katılımcı ön kontrolü ekip-01 **37/37**, ekip-02 **37/37**; kurum ön kontrol betiğinin sandbox koşusu **28/28**. [Çekirdek](kanit/faz-6/cekirdek-son.log), [CI](kanit/faz-6/ci-son.log), [ekip-01](kanit/faz-6/katilimci01-onkontrol.log), [ekip-02](kanit/faz-6/katilimci02-onkontrol.log). Denetim sayısı CA/analiz geçmişi gibi duruma göre değişir; atlanan koşullar logda görünür.

**Bırakılan durum:** ekip-01/02 LAB 01-A başlangıcında; ekip projeleri/job/paket/uygulamaları yok, araçlar ve temel imajlar hazır. Ekip-99 final demo olarak 1.1.0'da çalışıyor. Ortak workstation Docker daemon'ındaki yalnızca registry CA dosyası yedeklenip kaldırıldı; LAB 03-B x509 adımı öğrenciye bırakıldı. OS, agent ve test VM CA güveni korunuyor. İki katılımcı ön kontrolünde beklenen x509 ve önceden yüklenmiş imajlarla build doğrulandı. Jenkins kuyruğu boş; çalışan build yok. On bir servis running, restart=0, OOM=false ([durum](kanit/faz-6/container-son-durum.log)).

**Kaynak örneklemi:** 11-24 18:53–11-24 19:50, 55 örnek; lab en çok **13.80 GiB / 23,9 GiB**; host boş bellek en az **%57**, gözlenen swap 0. İlk koşunun LAB 03-A civarından son temiz kurulum ve kurtarma sonuna kadar örneklenmiştir; ilk kurulumun tamamını kapsamaz, anlık pik garantisi vermez. Bu provanın kaynak izleyicisi durduruldu. [Ölçüm](kanit/faz-6/kaynak-kullanimi.log).

Son koşunun 182 tarayıcı görüntüsü [img](kanit/faz-6/img/) altında. Hassas Nexus anahtarı ve Jenkins SSH credential görüntülerinde maskeleme gözle kontrol edildi; metin kanıtlarında bilinen sır/token/özel anahtar taraması yapıldı. Bütün shell dosyaları ve `komutlar.md` içindeki 113 Bash bloğu sözdizimi kontrolünden geçti; yerel doküman bağlantıları denetlendi ([son kontrol](kanit/faz-6/statik-kontroller.log)).



### Korunan ders kararları ve sınırlar

- Tek test ortamı nedeniyle tag, release'in develop'a geri merge edilmesinden **ve o deploy'un bitmesinden sonra** atılır. `deploy/deploy.sh` tam metin verilir. Pack & Publish ayrı bonus kalır; ana pipeline'a eklenmez. Nexus yeniden yayın reddi 409, yeni sürüm 1.0.1. [Slayt güncellemeleri](slayt-guncellemeleri.md) C28–C40 ve F bölümü güncel; slayt dosyaları yeniden üretilmedi.
- **BELBİM entegrasyonu doğrulanmadı.** Kurum DNS/CA, hesap/yetki, sürüm/plugin, webhook erişimi, gerçek katılımcı ağı ve makineleri kurumda kontrol edilmeli. `INTEGRATION_VERIFIED` denmedi.
- Host tarayıcısının hosts/CA kurulumu bu prova ile kanıtlanmaz. Arayüz adımları lab CA'sına güvenen gerçek Playwright tarayıcısında; sertifika doğrulaması kapatılmadı. Host servis kontrolleri `--resolve` kullanır; bu DNS ayarının yerini tutmaz.
- arm64 sandbox; x86-64, on ekiple eşzamanlı yük, katılımcıyla süre ölçümü, ekip sunumu ve projeksiyon denemesi doğrulanmadı. Otomasyon saniyeleri ders süreleri değildir.
