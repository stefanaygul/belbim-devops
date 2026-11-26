# Hata senaryoları ve kurtarma

Her demoda önce beklenen hatayı, sonra aynı işin doğru ayarla geçtiğini gösterin. Paylaşılan GitLab/Jenkins/SonarQube ayarlarını ders sırasında bozmayın. Aşağıdaki “kanıt” sütunu yalnızca belirtilen koşuya aittir; eski kanıtlar yeni temiz kurulum kanıtı sayılmaz. Güncel tam koşu sonuçları [RAPOR.md](../../RAPOR.md) Faz 6 bölümündedir.

## Lab akışında üretilenler

| Hata | Nasıl üretilir? | Nasıl düzeltilir / kontrol edilir? | Kanıt |
|---|---|---|---|
| NU1605 | LAB 01-A: `lab/01a-conflict` üzerinde `dotnet restore SahaPortal.sln` | EF Core doğrudan bağımlılığını 10.0.15'e hizala, restore/build/test | LAB 01-A akış ve doğrulama logu |
| Merge conflict | LAB 01-B: SRJ-04 “Şarj ünitesi” commit'inden sonra `git merge origin/lab/01b-rename` | İşaretleri kaldır, tek SRJ-04 satırı; `git add`, test, `git commit --no-edit` | LAB 01-B logu |
| Korumalı branch push reddi | main/develop push No one; boş deneme commit'ini develop'a push et | Yalnızca deneme commit'ini geri al; feature → MR → Maintainer merge | LAB 02-A logu; iki hesap |
| Korumalı tag reddi | v* koruması Maintainers; Developer `git push origin v1.0.0` | Yerel deneme tag'ini sil; Maintainer aynı main commit'ine annotated tag atar | LAB 02-B logu |
| Docker x509 | Temiz workstation daemon'ında LAB 03-B ilk `docker login` | CA'yı `/etc/docker/certs.d/$REGISTRY/ca.crt` olarak ekle; login/push tekrar | LAB 03-B; önceden CA tanıtılmış makinede bu hata beklenmez |
| Registry yetki reddi | Login olmadan push; sonra yalnızca read_registry token ile push | read_registry + write_registry token kullan; `--password-stdin` | LAB 03-B: `access forbidden`, `insufficient_scope` |
| SQLite Error 14 | order-service root olmayan kullanıcı, sahipliği ayarlanmamış /data volume'u | Dockerfile'da USER'dan önce `RUN mkdir -p /data && chown $APP_UID:$APP_UID /data`; imajları yeniden build et. Yalnızca bu labın boş/deneme yerel volume'unu onayla silip yeniden yarat; talep ekle, container down/up sonrası kayıt kalsın | LAB 03-B; gerçek veride volume silinmez |
| Kırmızı test merge'ü engeller | LAB 04-A: boş productId için 400 yerine 200 bekleyen test; Pipelines must succeed açık | Hatalı test commit'ini revert et; yeşil status ve merge | LAB 04-A logu |
| Pipeline durumu yok / kuyrukta | Yeni commit'in status'u gelmeden merge dene; kuyruk demosu yalnızca bakım anında `KUYRUK=1` | Agent online; yeni SHA için Jenkins sonucu SUCCESS ve GitLab success | [Faz 4 zincir kanıtları](../../kanit/faz-4/); ortak agent ders sırasında kapatılmaz |
| Quality Gate ERROR | LAB 04-B: testsiz summary kodunu feature üzerinden develop'a merge et | Summary testlerini ikinci MR ile ekle; Gate OK, SHA imajları registry'de | LAB 04-B logu; Community'de feature analizi yapılmaz |
| `when { branch }` stage atlar | feature/sonar build'i; `when { branch 'develop' }` analizini atlar | develop'a merge edilince analiz çalışır. Bu beklenen kapsamdır; koşulu kaldırarak tüm branch'leri aynı Sonar projesine yazmayın | LAB 04-B logu |
| Nexus ikinci yayın | Aynı 1.0.0 nupkg dosyasını ikinci kez push et | 409 beklenir. Yeni paket yayını için Version 1.0.1; mevcut sürüm silinmez, redeploy açılmaz | LAB 05-A ve [Faz 6 yeni sürüm yayını](../../kanit/faz-6/nexus-yeni-surum.log) |
| Miktar hatası | quantity=0/-1 için 400 testlerini validation'dan önce yaz | `Quantity < 1` → 400; quantity=1/2 → 201 | LAB 05-B logu |
| Olmayan deploy etiketi | `vm "sh deploy.sh $IMG olmayan-etiket $WEB_PORT - demo"` | pull aşamasında durmalı; `.env`, çalışan container'lar ve deploy kaydı aynı kalmalı. Registry'de var olan etiketi kullan | [Faz 5](../../kanit/faz-5/22-lab-05-b-tek-kosu-ekip02.txt), ek hata denetimi |
| Tag commit'inin SHA imajı yok | İmaj üretilmemiş commit'e v* tag; tag job'ı başlar | En çok 5 dakika sonra anlaşılır hata; deploy yok. O commit için main build'ini yeşile getirip aynı tag job'ını yeniden çalıştır | [Faz 5](../../kanit/faz-5/51-tag-build-imaj-yok-ekip02.txt) |

## Ayrı demolar ve yönetici teşhisi

Komutlar katılımcının Bash terminalinde; `lab.env` ve ekip değişkenleri yüklenmiş olmalı. Demosu yapılmayan bir satırı yalnızca çözümün yazılı olması nedeniyle “doğrulandı” saymayın.

### Port çakışması

Sadece kendi demo container'larınızda aynı host portunu iki kez yayınlayın:

```bash
docker run -d --name port-demo-a -p 18090:8080 "$HUB/nginxinc/nginx-unprivileged:stable-alpine"
docker run -d --name port-demo-b -p 18090:8080 "$HUB/nginxinc/nginx-unprivileged:stable-alpine"  # başarısız
# İlk container'ı tutup ikincisini boş bir host portuyla yeniden oluşturun.
docker rm port-demo-b
docker run -d --name port-demo-b -p 18091:8080 "$HUB/nginxinc/nginx-unprivileged:stable-alpine"
docker rm -f port-demo-a port-demo-b
```

Portlar başka bir ekipte kullanılıyorsa demo için başka boş port seçin; başka ekibin container'ını durdurmayın.

### `manifest unknown` / `not found`

```bash
docker pull "$IMG/order-service:egitimde-olmayan-etiket"   # reddedilmeli
docker pull "$IMG/order-service:1.1.0"                   # LAB 05-B sonrası başarılı
```

Önce login/yetki ile etiketin varlığını ayırın. Tag adı başındaki `v`, Git tag'indedir; container etiketi `1.1.0` olur.

### NuGet kaynak hatası (NU1101)

Gerçek NuGet.config'i bozmak yerine geçici boş yerel feed ile bir demo proje kullanın. Restore başarısız olmalı; gerçek Nexus group kaynağıyla restore geçmeli. Projenin/önbelleğin izole olması gerekir; cache'ten gelen paket, yanlış kaynakla bile yanıltıcı başarı verebilir.

### Git sertifika hatası

Gerçek makinenin CA deposunu silmeyin. Tek Git çağrısında geçici ilgisiz CA dosyası ve boş CA dizini kullanın; TLS hatasını görün. Sonraki çağrıda doğru `CA_CERT` ve varsayılan güven deposu ile `git ls-remote` başarılı olmalı. `http.sslVerify=false` çözüm değildir.

### Docker soket izni

Yetkisiz demo kullanıcısında `docker info` soket izniyle kalır; yetkili eğitim kullanıcısında geçer. Yönetici kullanıcıyı uygun Docker grubuna ekler; oturum yeniden açılır. `chmod 666 /var/run/docker.sock` kullanmayın.

### GitLab “Url is blocked”

Yönetici, webhook hedefinin DNS/IP çözümünü ve giden istek izin listesini denetler. Yalnızca Jenkins host'unu izin listesine ekler, sonra proje webhook'unda Test > Push events ile HTTP 200 görülür. Bunu üretmek için çalışan ortamın genel izin listesini kaldırmayın; ayrı bakım penceresi gerekir. **Faz 6’da mevcut izin listesi değiştirilmeden denendi:** izin dışındaki Nexus host’una geçici webhook ekleme API’si `422 {"error":"Invalid url given"}` döndürdü; izinli Jenkins host’una ekleme geçti ve geçici hook silindi. Bu sürümün API metni arayüzdeki “Url is blocked” ifadesiyle aynı değildir. [Kanıt](../../kanit/faz-6/ci-hata-demolari-son.log).

### `waitForQualityGate` timeout

SonarQube yönetiminde son webhook teslimini açın: hedef `$JENKINS_URL/sonarqube-webhook/`, HTTP 200 olmalı. Yanlış hedef, eksik `/`, ağ/TLS hatası ve yanlış Jenkins token'ı ayrı incelenir. Jenkins task ID ile Sonar analizini eşleştirin; webhook'u düzeltip build'i yeniden çalıştırın. Analiz çok hızlı biterse Jenkins sonucu başlangıç sorgusuyla bulabilir; yalnızca webhook'u kapatmak her koşuda timeout üretmez. **Faz 6’da boş sandbox bakım anında üretildi:** geçici job’da 30 saniyelik timeout, yanlış webhook hedefinde `ABORTED`; hedef düzeltilince aynı job `SUCCESS`, Gate `OK`. Global hedef EXIT tuzağıyla da geri yüklenir. [Hata](../../kanit/faz-6/qg-timeout.log), [düzeltme](../../kanit/faz-6/qg-duzeltildi.log). Derste paylaşılan aktif ortamda bu demoyu çalıştırmayın.

### SonarScanner begin/end sırası

Boş geçici dizinde `dotnet-sonarscanner end` çağrısı, begin/build olmadığı için analiz hazırlığı bulunamadığını bildirmeli. Doğru akış `begin → build → test → end`; final labda `ci/analyze.sh` bu sırayı uygular. Build ve coverage dosyalarının aynı çalışma dizininde bulunması gerekir.

### SSH ve tag ayarları

- `Host key verification failed`: sunucu parmak izini yönetici üzerinden doğrulayın; agent `known_hosts` dosyasına doğru anahtarı ekleyin. Sunucu yeniden kurulmuşsa eski anahtarın neden değiştiğini doğrulayın.
- `Permission denied (publickey)`: `test-vm-ssh` credential'ındaki kullanıcı `deploy` mu; özel anahtarın açık eşi `authorized_keys` içinde mi? Katılımcının kişisel anahtarını Jenkins'e taşımayın.
- Tag job'ı yok: Discover tags; Regular branches + Tags build stratejileri; GitLab Tag push events üçlüsünü kontrol edin. Tags maksimum yaş filtresi eski tag'i dışlıyor olabilir.
- Smoke 502: hem products hem orders GET isteğinde retry kullanın. Yanlış uygulama davranışını yeniden denemelerle gizlemeyin; son HTTP durumunu doğrulayın.
- MSB4166: agent kaynakları ve MSBuild süreçlerini inceleyin; sandbox'ta `MSBUILDDISABLENODEREUSE=1` ile giderildi. Bu aralıklı hata her koşuda üretilemez.

### Temiz kurulumda boş Jenkins bağlantısı

İlk açılışta `gitlab` yanında adsız/URL'siz bir bağlantı oluşursa bootstrap denetimi durur. `bootstrap/60-jenkins.sh` yalnızca adı, URL'si ve credential referansı tamamen boş kaydı temizler; `gitlab` bağlantısını tekrar denetler. Adlı başka bir bağlantı varsa sessizce silmez. İlk hata çıktısı [temiz kurulum ilk deneme](../../kanit/faz-6/temiz-prova-ilk-deneme/bootstrap.log) altında tutulur.

## Faz 6 ek denetimleri

`bash dogrula/lab.sh ek-hatalar 99` final labdan sonra Git CA, Docker soket izni, port çakışması, NU1101, olmayan registry etiketi ve başarısız deploy’un çalışan sürümü korumasını sınar. [13/13 sonucu](../../kanit/faz-6/ek-hatalar.log). SonarScanner sıralama hatası ayrıca [gerçek komutla](../../kanit/faz-6/scanner-yanlis-sira.log) üretildi; doğru begin/build/test/end akışı LAB 04-B ve 05-B’de geçti.

CI ortam denetimi, son 20 webhook teslimi içinde **her projenin en yeni** tesliminin başarısını arar; giderilmiş eski hataları sayı olarak ayrıca gösterir. Bir ekibin yeni başarısı başka ekibin son başarısız teslimini örtmez.

### Ekip sıfırlanınca agent registry erişimi bozuldu

Ortak `$HOME/.docker/config.json`, silinen ekibin token’ını tutuyorsa public temel imajda bile HTTP Basic Access denied görülebilir. LAB 04-B/05-B Jenkinsfile’ları `DOCKER_CONFIG = "${WORKSPACE}@tmp/docker-config"` kullanır; en dış `post/always` bu job’ın `config.json` dosyasını siler. Çalışan başka job’ın dosyasını silmeyin. Ortam denetimi anonim pull için boş geçici config kullanır, ayrıca ortak agent config’inde giriş kalmadığını kontrol eder. [Düzeltme öncesi](../../kanit/faz-6/kurtarma-ilk/ci-son.log), [anonim erişim düzeltmesi](../../kanit/faz-6/ci-yalitim-duzeltmesi.log). Yeni pipeline’ın gerçek koşusu son temiz prova dizinindedir.

### Sıfırlama sonrası yerel container/volume kaldı

Ekip proje etiketi olan ama tam Compose metadata’sı olmayan bir demo container/volume üzerinde eski `docker compose down` çıkış 0 verdi; volume için `Resource is still in use` uyarısı çıktı ve kaynaklar kaldı. Düzeltilmiş `sifirla-ekip.sh`, repo olmasa da yalnızca ilgili `com.docker.compose.project=ekipNN` etiketli kaynakları kaldırır. Son kurtarma provasındaki yerel container/volume fikstürü, sıfırlamadan önce varlık ve sonra yokluk denetimi içindir; başka ekibin kaynakları kaldırılmaz.
