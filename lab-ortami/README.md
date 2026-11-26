# Lab ortamı (sandbox)

BELBİM DevOps eğitiminin lablarını geliştirmek, prova etmek ve gerektiğinde yedek olarak kullanmak için Docker üzerinde çalışan yerel ortam. Eğitimin kendisi BELBİM'in kurulu servislerinde yapılır; bu ortam onların yerini tutar.

İki profil vardır. `cekirdek`: GitLab (Container Registry ile), Nexus, katılımcı makinesi (`workstation`) ve test VM. `ci`: Jenkins (controller + agent + agent'ın kendi Docker daemon'ı) ve SonarQube Community Build + PostgreSQL. Gün 1–5 lablarının çözüm, doğrulama, checkpoint ve sıfırlama betikleri de buradadır. Gün 1–3 için `cekirdek` yeter; 4. günden itibaren `ci` de gerekir (iki profil birlikte, iki ekiple en yüksek ≈ 14 GiB bellek kullandı; Docker'a 24 GB ayrıldı).

## Gereksinimler

- Docker Engine ya da Docker Desktop (Compose v2 ile), `make`, `bash`
- Docker'a ayrılmış en az 16 GB bellek (çekirdek profil için); `ci` profiliyle birlikte yaklaşık 28–32 GB
- İlk kurulumda internet erişimi: imajlar ve paketler bir kez indirilir

## Kurulum

```bash
cd lab-ortami
make env          # .env ve lab.env dosyalarını üretir
```

`.env` dosyasını açın ve Nexus Community Edition onaylarını kendiniz verin. Nexus, lisans sözleşmesi kabul edilmeden paket indirmeyi reddeder. Metin: <https://links.sonatype.com/products/nxrm/ce-eula>

```
NEXUS_CE_EULA_KABUL=evet
NEXUS_CE_TELEMETRI_ONAY=evet
```

Ardından:

```bash
make up           # CA'yı üretir, imajları derler, servisleri başlatır ve hazır olmalarını bekler
make bootstrap    # grupları, kullanıcıları, depoları ve temel imajları kurar; temel imajları workstation'a yükler
make dogrula      # ortamı denetler; hiçbir şeyi değiştirmez
```

`make bootstrap` tekrar çalıştırılabilir; var olanı yeniden oluşturmaz.

## Adresler

`D` = `.env` içindeki `LAB_DOMAIN` (varsayılan `kurum.test`).

| Servis | Ağ içindeki adres | Host'taki adres |
|---|---|---|
| GitLab | `https://gitlab.D` | aynı (`127.0.0.1:443`) |
| Container Registry | `gitlab.D:5050` | aynı (`127.0.0.1:5050`) |
| Nexus | `https://nexus.D` | aynı (`127.0.0.1:443`) |
| Jenkins (`ci` profili) | `https://jenkins.D` | aynı |
| SonarQube (`ci` profili) | `https://sonar.D` | aynı |
| GitLab SSH | `gitlab.D:22` | `127.0.0.1:2222` |
| Test VM, ekip uygulamaları | `http://test-vm.D:8081` … `8090` | `http://test-vm.D:18081` … `18090` |
| Test VM, prova ekibi (`ekip-99`) | `http://test-vm.D:8099` | `http://test-vm.D:18099` |
| workstation, Vite geliştirme sunucusu | `localhost:5173` | `127.0.0.1:5173` |
| workstation, `8080` | `localhost:8080` | `127.0.0.1:18080` |

Portlar yalnızca `127.0.0.1` üzerinde yayınlanır. Host'ta `8080` ve `8081` başka projelerde kullanıldığı için test VM ve workstation portları host'ta `1` önekiyle yayınlanır; container içindeki port numaraları slaytlardaki gibidir. Host portları `.env` içinden değiştirilebilir.

## Host hazırlığı (tarayıcıdan erişim için)

Komut satırından yapılan her şey container'ların içinde çalışır ve bu adımlara ihtiyaç duymaz. Arayüzleri host tarayıcısında açmak için iki şey gerekir: ad çözümleme ve lab CA'sına güven. Bu adımlar yönetici yetkisi ister ve ortamı kuran betikler bunları yapmaz.

CA dosyası: `lab-ortami/certs/ca.crt`. Bu CA yalnızca `LAB_DOMAIN` altındaki adlar için sertifika imzalayabilir.

### macOS

```bash
sudo sh -c 'echo "127.0.0.1 gitlab.kurum.test jenkins.kurum.test sonar.kurum.test nexus.kurum.test test-vm.kurum.test" >> /etc/hosts'
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain certs/ca.crt
```

Kaldırmak için: `sudo security delete-certificate -c "Egitim Lab Root CA" /Library/Keychains/System.keychain` ve `/etc/hosts` satırını silin. Firefox kendi sertifika deposunu kullanır; CA'yı Ayarlar > Gizlilik ve Güvenlik > Sertifikalar bölümünden ayrıca içe aktarın.

### Linux

```bash
sudo sh -c 'echo "127.0.0.1 gitlab.kurum.test jenkins.kurum.test sonar.kurum.test nexus.kurum.test test-vm.kurum.test" >> /etc/hosts'

# Debian / Ubuntu
sudo cp certs/ca.crt /usr/local/share/ca-certificates/egitim-lab-ca.crt
sudo update-ca-certificates

# RHEL / Rocky / Fedora
sudo cp certs/ca.crt /etc/pki/ca-trust/source/anchors/egitim-lab-ca.crt
sudo update-ca-trust
```

Chrome ve Firefox Linux'ta kendi NSS deposunu kullanır:

```bash
certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n "Egitim Lab Root CA" -i certs/ca.crt
```

### Windows

Yönetici olarak açılmış PowerShell'de:

```powershell
Add-Content C:\Windows\System32\drivers\etc\hosts "127.0.0.1 gitlab.kurum.test jenkins.kurum.test sonar.kurum.test nexus.kurum.test test-vm.kurum.test"
Import-Certificate -FilePath certs\ca.crt -CertStoreLocation Cert:\LocalMachine\Root
```

`make` komutları WSL 2 içinde çalıştırılır; hosts kaydı ve sertifika Windows tarafında yapılır.

## Hesaplar

| Sistem | Hesap | Rol |
|---|---|---|
| GitLab | `root` | yönetici; parola `.env` içinde `GITLAB_ROOT_PASSWORD` |
| GitLab | `ekipNN-lead` | `egitim/ekip-NN` alt grubunda Maintainer |
| GitLab | `ekipNN-dev` | `egitim/ekip-NN` alt grubunda Developer |
| Nexus | `admin` | yönetici; parola `.env` içinde `NEXUS_ADMIN_PASSWORD` |
| Nexus | `ekipNN` | hosted depolara paket yayınlar, kendi API anahtarını alır |
| Jenkins | `admin` | yönetici; parola `.env` içinde `JENKINS_ADMIN_PASSWORD` |
| Jenkins | `ekipNN` | yalnızca `ekip-NN` klasöründe job ve credential yönetir; başka ekibin klasörünü göremez |
| SonarQube | `admin` | yönetici; parola `.env` içinde `SONAR_ADMIN_PASSWORD` |
| SonarQube | `ekipNN` | proje oluşturur, analiz gönderir, kendi token'ını üretir |
| workstation | `ekipNN` | `sudo` ve `docker` yetkili Linux kullanıcısı |
| test VM | `deploy` | `docker` grubunda, `sudo` yok; yalnızca ekip SSH anahtarıyla girilir |

Ekip parolaları hiçbir dosyada durmaz; `.env` içindeki `LAB_SECRET` değerinden türetilir. Listeyi görmek için:

```bash
make parolalar
```

## Katılımcı makinesine girmek

```bash
docker compose exec -it -u ekip01 workstation bash -l
```

`-l` (login kabuğu) `lab.env` değişkenlerini ve ekibe özel `EKIP`, `IMG`, `WEB_PORT`, `TEST_URL` değerlerini yükler. Kurum CA'sı `/etc/lab/kurum-ca.crt` yolundadır.

## Komutlar

| Komut | Ne yapar |
|---|---|
| `make up` | Çekirdek profili başlatır |
| `make up-ci` | Çekirdek + CI profilini başlatır; ardından `make bootstrap` Jenkins ve SonarQube adımlarını da çalıştırır |
| `make bootstrap` | Kurulumu yapar; tekrar çalıştırılabilir |
| `make dogrula` | Çekirdek ortamı denetler |
| `make dogrula-ci` | CI profilini denetler: Jenkins tanımları ve plugin sürümleri, erişim, agent araçları, agent'ın Docker daemon'ı, SonarQube webhook'u |
| `make parolalar` | Ekip hesaplarını ve parolalarını ekrana yazar |
| `make durum` | Servis durumu, bellek, volume boyutları |
| `make dur` | Container'ları durdurur; veri kalır |
| `make dogrula-lab LAB=02-a EKIP=01` | Bir labın başarı kriterlerini denetler (`KAYNAK=checkpoint`: MR geçmişini denetlemez) |
| `make onkontrol EKIP=01` | Katılımcı makinesi ön kontrolü: araçlar, kurum CA'sı, temel imajlar, builder |
| `make checkpoint EKIP=01 LAB=lab-04a` | Ekibi bir labın sonundaki duruma getirir (`lab-04a` ve sonrası için `ci` profili açık olmalı) |
| `make rol-degistir EKIP=01` | Ekipte Maintainer / Developer rollerini değiştirir; `ASIL=1` geri alır |
| `make temel-imaj-paketi DIZIN=…` | Temel imajları başka makinelere taşımak için `.tar` olarak yazar |
| `make sifirla-ekip EKIP=01` | Bir ekibi başlangıç durumuna döndürür; onay ister |
| `make yik` | Ortamı ve bütün verisini siler; onay ister |

## Lablar: çözüm, doğrulama, checkpoint

Gün 1–5 lablarının (01-A … 05-B) her biri için üç şey vardır. `NN` ekip numarasıdır.

| Ne | Komut | Nerede çalışır |
|---|---|---|
| Çözümü baştan uygular | `bash dogrula/cozum.sh 02-a NN` | Komut satırı adımları `workstation`'da ekip kullanıcısıyla; arayüz adımları gerçek tarayıcıda (`tarayici` servisi, Playwright) |
| Başarı kriterlerini denetler | `make dogrula-lab LAB=02-a EKIP=NN` | `workstation`'da ekip kullanıcısıyla; GitLab'i salt okunur, kısa ömürlü bir token ile, Jenkins ve SonarQube'u (Gün 4) ekip hesabıyla sorgular |
| Ekibi labın sonuna getirir | `make checkpoint EKIP=NN LAB=lab-02a` | GitLab (API), `workstation`, test VM; `lab-04a` ve `lab-04b` için ayrıca Jenkins ve SonarQube |
| CI zincirinin anlık durumu (Gün 4) | `docker compose run --rm -T araclar bash dogrula/ci-durum.sh build NN develop SUCCESS` | Jenkins build'i, derlenen SHA, GitLab commit status; `mr`, `hook`, `sonar`, `imaj`, `kuyruk` komutları da vardır |

Checkpoint adları: `lab-01a`, `gun1`, `lab-02a`, `lab-02b` (= `gun2`), `lab-03a`, `lab-03b` (= `gun3`), `lab-04a`, `lab-04b` (= `gun4`), `lab-05a`, `final`. Kaynak kod şablon projedeki `checkpoint/*` branch'lerinden gelir; bu branch'ler `checkpoint/uret.sh` ile `checkpoint/adimlar/` altındaki çözüm dosyalarından üretilir (yazar ve tarihler sabit, SHA'lar tekrarlanabilir).

Bilinmesi gerekenler:

- **Yalnızca o ekibe dokunurlar:** `egitim/ekip-NN` grubu ve projeleri, `ekipNN-lead` / `ekipNN-dev` hesapları, `workstation`'daki `ekipNN` kullanıcısı, test VM'deki `/opt/saha/ekipNN` ve `ekipNN` Compose projesi, Jenkins'te `ekip-NN` klasörünün içi, SonarQube'da `saha-portal-ekipNN` projesi ve `ekipNN` kullanıcısının token'ları, agent'taki ekip çalışma dizinleri ve imajları. `bash dogrula/ekip-durumu.sh NN` bir ekibin bütün kaynaklarını listeler; iki çıktının farkı yalıtımı gösterir.
- **Checkpoint MR ve yorum geçmişini geri kurmaz.** Kod, korumalar, tag'ler, issue kayıtları, deploy token'lar, registry imajları ve test VM'deki uygulama kurulur. `lab-04a` ve `lab-04b` ayrıca Project Access Token'ı, webhook'u, "Pipelines must succeed" ayarını, Jenkins credential'larını ve Multibranch job'ı, (`lab-04b`) SonarQube projesini ve token'ını kurar; job ve SonarQube projesi **silinip yeniden** oluşturulur (build ve analiz geçmişi sıfırlanır) ve `develop` build'inin yeşil bitmesi beklenir. Daha erken bir checkpoint'e dönülürse ekibin Jenkins ve SonarQube kaynakları kaldırılır. Ekibin eski çalışma kopyası silinmez, `~/yedek/` altına taşınır.
- **`sifirla-ekip` siler:** ekibin GitLab projesi (issue, MR, registry imajlarıyla), test VM'deki uygulaması ve verisi, `workstation`'daki reposu ve yedekleri, Jenkins klasöründeki job ve credential'lar, SonarQube projesi ve token'ları. Jenkins klasörünün kendisi, yetkileri ve kullanıcı hesapları kalır.
- **Nexus (5. gün):** `sifirla-ekip` ve her checkpoint ekibin paketini (`Saha.Common.Contracts.EkipNN`) `nuget-hosted`'dan siler; hosted depo aynı sürümün yeniden yayınını reddettiği için LAB 05-A ancak böyle tekrarlanabilir. `lab-05a` ve `final` checkpoint'leri paketi ekibin kendi API anahtarıyla yeniden yayınlar. Sızan bir anahtar için: `docker compose run --rm -T araclar bash bootstrap/ekip-nexus.sh anahtar-yenile NN`.
- **Test VM ve Jenkins (5. gün):** `final` checkpoint'i Jenkins'in deploy anahtarını ekibin makinesinde üretir (`~/.ssh/jenkins-test-vm`, yorum `jenkins-ekipNN`), test VM'de yetkilendirir ve `test-vm-ssh` credential'ını kurar; daha erken checkpoint'ler ve `sifirla-ekip` bu satırı test VM'den siler. Deploy kaydı (`/opt/saha/ekipNN/deploy-kayit.log`) checkpoint'te sıfırlanır.
- **`cozum.sh 04-a NN` ve ortak agent:** `KUYRUK=1` verilirse "iş kuyruktayken merge kapalı mı?" kanıtı için ortak Jenkins agent'ı birkaç saniye devre dışı bırakılır; bütün ekiplerin build'leri bekler. Varsayılan kapalıdır; ders sırasında açmayın.
- **Sandbox'ta `workstation` tektir.** Docker daemon'ı, `certs.d` ve `8080` gibi portlar ekipler arasında ortaktır. `checkpoint lab-03b` daemon'a kurum CA'sını tanıtır; bu bütün ekipleri etkiler. BELBİM'de herkesin kendi makinesi vardır.
- **İki rol, tek makine:** `workstation`'da `rol lead` / `rol dev`, o terminalde git'in hangi SSH anahtarını ve kimliği kullanacağını seçer.

### Tarayıcı aracı

Arayüz adımları `tarayici` servisinde (Playwright, Chromium) yapılır. Servis `workstation`'ın ağ alanını paylaşır: GitLab, `http://localhost:5173`, `http://localhost:808N` ve test VM adresleri katılımcının tarayıcısındaki gibi açılır. Lab CA'sı tarayıcının güven deposuna eklenir; sertifika hataları yok sayılmaz (`node tls-denemesi.cjs` ile sınanır). Ekran görüntüleri `lab-rehberleri/img/` altına yazılır. Betikler: `dogrula/ui/`.

```bash
docker compose --profile cekirdek run --rm tarayici node tls-denemesi.cjs
```

## Temel imajlar ve katılımcı makineleri

LAB 03-A, dört temel imajın katılımcı makinesinin Docker'ında önceden yüklü olmasına dayanır; Docker'a kurum CA'sı LAB 03-B'de tanıtılır. `make bootstrap` imajları registry'den alıp `workstation`'a `docker load` ile yükler (daemon ayarına dokunmaz; imaj güncelse yeniden yüklemez). Liste ve sürümler: `bootstrap/temel-imajlar.tablo`, `VERSIONS.md` §3.

Doğrulanan sınır: imajın makinede olması yalnızca **varsayılan builder** (`docker` sürücüsü) için yeterlidir. `docker build --pull`, `docker-container` sürücülü bir builder ve Dockerfile'daki `# syntax=` satırı registry'ye gider.

**Başka makinelere taşıma (BELBİM):**

```bash
make temel-imaj-paketi DIZIN=/yol/temel-imajlar       # dört .tar ve SHA256SUMS
# her katılımcı makinesinde:
sha256sum -c SHA256SUMS && for f in *.tar; do docker load -i "$f"; done
```

Ardından her makinede ön kontrol: sandbox'ta `make onkontrol EKIP=NN`; BELBİM'de `dogrula/lib.sh` ile `dogrula/workstation-onkontrol.sh` dosyalarını makineye kopyalayıp `lab.env` yüklüyken çalıştırın. Paket, imajları kaynak registry'deki adlarıyla taşır: BELBİM'de paket BELBİM'in iç aynasından üretilmelidir ki adlar oradaki `MCR` / `HUB` değerleriyle tutsun. *Paketin üretimi ve içeriği sandbox'ta doğrulandı; BELBİM'in registry'sinden üretim ve ön kontrolün sandbox dışında çalıştırılması denenmedi.*

## Nasıl kurulu

- **Tek ağ, tek proxy.** `proxy` (Nginx) TLS'i sonlandırır; `gitlab`, `jenkins`, `sonar`, `nexus` adları onun ağ takma adlarıdır. Registry `:5050` ve GitLab SSH `:22` de proxy'den geçer.
- **DNS.** `workstation` ve test VM'in içindeki Docker daemon'larında çalışan container'lar Docker'ın gömülü DNS'ine ulaşamaz; lab adlarını `dns` servisi (CoreDNS) çözer. Bu yüzden `proxy`, `test-vm` ve `dns` sabit IP kullanır (`LAB_SUBNET`).
- **Docker daemon'ları.** Host'un Docker soketi hiçbir container'a bağlanmaz. Tam üç ayrı daemon vardır: `workstation`, `test-vm` ve `ci` profilindeki `agent-docker` (Jenkins agent'ının build'leri için). Agent ona TCP ile değil, ortak bir volume'daki Unix soketiyle ulaşır.
- **Jenkins.** Global yapılandırma imajdaki Configuration as Code dosyasındadır (`images/jenkins/casc/jenkins.yaml`): controller'da executor yok, agent `agent-1` (label `dotnet-docker`, 2 executor), GitLab connection `gitlab`, SonarQube sunucusu `sonarqube`, ortak ortam değişkenleri `MCR` ve `HUB`. Global bağlantılar **token taşımaz**; her ekip kendi token'larını klasör credential'ı olarak ekler. Pluginler sabit sürümlüdür (`images/jenkins/plugins.txt`). Bootstrap yalnızca ekip kullanıcılarını ve klasörlerini kurar.
- **Jenkins'in 5. gün ayarları.** CasC ortak `nuget-config` dosyasını tanımlar (managed file; `nexus` = group, `nexus-hosted` = hosted). Bootstrap'in `agent-ssh` adımı test VM'in SSH sunucu anahtarını agent'ın `known_hosts` dosyasına yazar (agent container'ı yeniden yaratılırsa bootstrap yeniden çalıştırılır); `StrictHostKeyChecking` kapatılmaz.
- **SonarQube.** Bootstrap yönetici parolasını, sunucu adresini, Jenkins'e giden global webhook'u (`…/sonarqube-webhook/`) ve ekip kullanıcılarını kurar. Yerel ağdaki Jenkins'e webhook gönderebilmesi için `sonar.validateWebhooks=false` ayarlanır (TLS doğrulaması açık kalır). Proje ve token katılımcı adımıdır.
- **Kapalı ağ benzetimi.** NuGet ve npm paketleri yalnızca Nexus proxy depolarından gelir. Temel imajlar `gitlab.D:5050/egitim/base` altındadır; SDK ve Node imajlarına lab CA'sı eklenmiştir.
- **Lab CA'sına kim güveniyor.** `workstation` işletim sistemi (git, curl, dotnet, npm) ve test VM'in Docker daemon'ı güvenir. `workstation`'daki Docker daemon'ı güvenmez: registry'ye ilk erişimde `x509` hatası verir ve katılımcı CA'yı `certs.d` altına kendisi ekler. `/etc/docker` ayrı bir volume'dadır; eklenen `certs.d` container yeniden yaratılınca kaybolmaz.
- **Bootstrap'in yapmadıkları.** Ekip projesi, branch koruması, token'lar, webhook, `docker login`, Docker'a CA tanıtma, paket yayını katılımcıya bırakılmıştır. Bunları yalnızca `checkpoint-uygula.sh` ve `cozum.sh` otomatikleştirir.
- **SSH.** Her ekip kullanıcısında iki anahtar (`id_ed25519`, `id_ed25519_lead`) ve GitLab ile test VM'in sunucu anahtarları (`known_hosts`) bootstrap ile hazırlanır. Anahtarı GitLab profiline eklemek katılımcı adımıdır.

## Sık karşılaşılanlar

| Belirti | Neden | Çözüm |
|---|---|---|
| Restore ya da `npm ci` Nexus'tan `403` alıyor | Community Edition EULA'sı kabul edilmemiş | `.env` içine onayları yazıp `make bootstrap` |
| Nexus `429 Too many authentication attempts` | Art arda hatalı giriş; Nexus hesabı kısa süre kilitler | 1–2 dakika bekleyin; `.env` içindeki parolanın değişmediğini denetleyin |
| `make up` GitLab'i uzun süre bekliyor | İlk açılışta veritabanı kurulur (3–5 dakika) | Bekleyin; `docker compose logs -f gitlab` ile izleyin |
| `Bind for 127.0.0.1:443 failed` | Host'ta port dolu | `.env` içinde `HOST_HTTPS_PORT` değerini değiştirin; host'taki adres ağ içindekinden farklı olur |
| `sifirla-ekip`: `Cannot rename or delete project because it contains container registry tags` | (eski sürüm) GitLab, registry etiketi olan projeyi silmez | Betik artık önce etiketleri siler; hata sürerse proje sayfasından etiketleri elle silin |
| Lab doğrulaması `KALDI: … node_modules yok` | Ekip `npm ci` çalıştırmamış | Katılımcı adımı; checkpoint bunu kendisi yapar |
| `certs/` altındaki CA başka alan adı için | `LAB_DOMAIN` sonradan değişmiş | `certs/ca.*` ve `certs/server.*` dosyalarını silip `make up`; yeni CA'yı host'a yeniden tanıtın |

## Dosyalar

```
compose.yaml          servisler, profiller, bellek sınırları
.env.example          yönetici ayarları ve sırlar için şablon (.env repoya girmez)
lab.env.example       rehberlerin kullandığı adres ve adlar (BELBİM için doldurulacak dosya)
certs/                üretilen CA ve servis sertifikası
images/               proxy, dns, workstation, test-vm, araclar, tarayici ve temel imaj tanımları
bootstrap/            kurulum betikleri; checkpoint-uygula.sh, sifirla-ekip.sh, rol-degistir.sh
checkpoint/           checkpoint branch'lerinin kaynağı (adimlar/) ve üretici (uret.sh)
dogrula/              cekirdek.sh; lab-XX-Y.sh (lab doğrulamaları); lab.sh (sandbox başlatıcısı);
                      cozum.sh ve cozum/ (lab çözümleri); ui/ (tarayıcı adımları);
                      workstation-onkontrol.sh; ekip-durumu.sh
```

## Uçtan uca prova ve eğitim teslimi

- [Tüm labların komut özeti](../komutlar.md)
- [Prova kullanımı, temiz kurulum ve devam](../lab-rehberleri/egitmen/prova.md)
- [Hata senaryoları](../lab-rehberleri/egitmen/hata-senaryolari.md)
- [Eğitim öncesi kontrol listesi](../lab-rehberleri/hazirlik-kontrol-listesi.md)
- [BELBİM yönetici hazırlığı](../lab-rehberleri/belbim-yoneticisinden-istenecekler.md)

`make prova`, yeni ekip-99 ile on labı terminal ve tarayıcıdan sırayla uygular; her labdan sonra denetler. LAB 03-B'nin deneme volume'u için açık onaydan sonra `PROVA_VOLUME_SILME_ONAYI=ekip-99` verilir. Tam temiz kurulum (`dogrula/temiz-prova.sh`) ayrıca açık onay ister; mevcut tüm ekiplerin verisini siler. Prova betiği mevcut ekibi kendiliğinden sıfırlamaz.

Kurumda Docker Compose kullanmadan, yalnızca GET sorguları ve SSH denetimleri yapan ön kontrol:

```bash
bash dogrula/onkontrol.sh /size/verilen/lab.env 01
```

Yönetici sorguları için kimlikler ortamdan alınır: `GITLAB_TOKEN`, `JENKINS_USER/JENKINS_TOKEN`, `SONAR_TOKEN` (veya `SONAR_USER/SONAR_PASSWORD`), `NEXUS_USER/NEXUS_PASSWORD`. `read -rs` ile alın ve `export` edin; komut metnine veya rapora yazmayın. Eksik yetki denetlenemeyen maddeyi başarısız sayar. Betik hiçbir servisi kurmaz/değiştirmez; sandbox üzerinde sınanması kurumun doğrulandığı anlamına gelmez.
