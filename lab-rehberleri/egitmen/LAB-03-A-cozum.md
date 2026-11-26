# LAB 03-A · Çözüm ve eğitmen notları

Üç servis için Dockerfile · 95 dk · Gün 3, Modül 2 · öğrenci rehberi: [`../ogrenci/LAB-03-A.md`](../ogrenci/LAB-03-A.md)

**Durum:** `SANDBOX_VERIFIED`. ekip-01 (kendi akışıyla) ve ekip-02 (`checkpoint/lab-02b`'den başlayarak) ile koşuldu; kanıt: `kanit/faz-3/lab-03-a-ekip01.txt`, `lab-03-a-ekip02-checkpointten.txt` (36 denetim).

## Eğitmen komutları

| Ne | Komut (`lab-ortami/` içinde) |
|---|---|
| Çözümü uygula | `bash dogrula/cozum.sh 03-a NN` |
| Denetle | `make dogrula-lab LAB=03-a EKIP=NN` |
| Katılımcı makinesi ön kontrolü (temel imajlar, builder) | `make onkontrol EKIP=NN` |
| Temel imajları makineye yeniden yükle | `bash bootstrap/bootstrap.sh ws-imajlar` |
| Ekibi bu labın başına / sonuna getir | `make checkpoint EKIP=NN LAB=gun2` / `LAB=lab-03a` |

## Lab öncesi: temel imajlar

Bu lab, dört temel imajın katılımcı makinesinin Docker'ında **önceden yüklü** olmasına dayanır. Docker'a kurum CA'sı LAB 03-B'de tanıtılır; imaj makinede hazırsa `docker build` registry'ye bağlanmaz ve slayt sırası korunur.

| İmaj (`MCR` / `HUB` altında) | Kaynak | İçine eklenen |
|---|---|---|
| `dotnet/sdk:10.0` | `mcr.microsoft.com/dotnet/sdk:10.0.404` | kurum CA'sı (restore için) |
| `dotnet/aspnet:10.0` | `mcr.microsoft.com/dotnet/aspnet:10.0.15` | — |
| `library/node:24-alpine` | `node:24.22.3-alpine3.24` | kurum CA'sı (`npm ci` için) |
| `nginxinc/nginx-unprivileged:stable-alpine` | `nginxinc/nginx-unprivileged:1.31.7-alpine3.24` | — |

Güne başlamadan her makinede `make onkontrol EKIP=NN` (BELBİM'de `dogrula/workstation-onkontrol.sh`) çalıştırın. Betik imajların varlığını, içlerinden Nexus'a erişimi, varsayılan builder'ı ve registry'ye bağlanmadan deneme build'ini denetler.

Sandbox'ta doğrulanan builder davranışı (Docker 29.10.0, BuildKit v0.35.0; `kanit/faz-3/02-buildkit-onyukleme.txt`):

| Durum | Sonuç |
|---|---|
| Varsayılan builder (`docker` sürücüsü), imaj yerelde, daemon registry'ye güvenmiyor | Build geçer; çıktıda `x509` yok |
| Aynı durumda `docker build --pull` | `x509: certificate signed by unknown authority` |
| `docker-container` sürücülü builder (`docker buildx create`) | Yerel imajı görmez; `x509` ile durur |
| `DOCKER_BUILDKIT=0` (eski builder) | Build geçer |
| Dockerfile'da `# syntax=docker/dockerfile:1` | Frontend imajını `docker.io`'dan ister (kapalı ağda başarısız olur) |

Yani "imaj yerelde" güvencesi yalnızca varsayılan builder için geçerlidir. Bir makinede başka builder seçiliyse: `docker buildx use default`.

## Süre dağılımı ve ara kontroller

| Dakika | Adım | Ara kontrol |
|---|---|---|
| 0–5 | 1 · Issue, branch | |
| 5–25 | 2 · `order-service` Dockerfile | **25. dk:** herkesin en az bir imajı build oldu mu? |
| 25–35 | 3 · `product-service` | `diff` yalnızca servis adını gösteriyor mu? |
| 35–55 | 4 · `web-ui` + `nginx.conf` | `.npmrc` kopyalanıyor mu? |
| 55–65 | 5 · `.dockerignore` | İki ölçüm arasındaki fark |
| 65–75 | 6 · Build, boyut, cache | `CACHED` satırını gördüler mi? |
| 75–85 | 7 · Çalıştır | Herkes en az bir container'ı çalıştırdı, `whoami` root değil |
| 85–95 | Toparlama | |

İlk Dockerfile'ı (order-service) anlatımda birlikte yazdınız; labda ikinci ve üçüncüyü katılımcılar kendileri yazsın.

## Çözüm

### `src/order-service/Dockerfile`

```dockerfile
ARG MCR=mcr.microsoft.com
FROM ${MCR}/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY NuGet.config ./
COPY src/common-contracts/ src/common-contracts/
COPY src/order-service/*.csproj src/order-service/
RUN dotnet restore src/order-service
COPY src/order-service/ src/order-service/
RUN dotnet publish src/order-service -c Release -o /app

FROM ${MCR}/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /app .
USER $APP_UID
ENTRYPOINT ["dotnet", "order-service.dll"]
```

`src/product-service/Dockerfile` aynıdır; `order-service` geçen dört yerde `product-service` yazar.

> Bu labın sonunda `order-service` Dockerfile'ında `/data` dizini **yoktur**. O satır LAB 03-B'de, SQLite Error 14 yaşandıktan sonra eklenir. Katılımcıya şimdiden vermeyin.

### `src/web-ui/Dockerfile`

```dockerfile
ARG HUB=docker.io
FROM ${HUB}/library/node:24-alpine AS build
WORKDIR /app
COPY src/web-ui/package*.json src/web-ui/.npmrc ./
RUN npm ci
COPY src/web-ui/ ./
RUN npm run build

FROM ${HUB}/nginxinc/nginx-unprivileged:stable-alpine
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD wget -q -O /dev/null http://127.0.0.1:8080/ || exit 1
```

### `deploy/nginx.conf` (bu labdaki hali)

```nginx
server {
  listen 8080;
  root /usr/share/nginx/html;

  location / { try_files $uri /index.html; }
}
```

### `.dockerignore`

```
.git/
**/bin/
**/obj/
**/node_modules/
**/dist/
**/coverage/
**/TestResults/
**/*.db
**/*.db-shm
**/*.db-wal
.env
```

### Build ve çalıştırma

Öğrenci rehberindeki komutlarla aynıdır. Sandbox'ta ölçülen değerler (arm64; x86-64'te boyutlar farklı çıkar):

| Ölçüm | Değer |
|---|---|
| Build context, `.dockerignore` yok / var | 378,2 MB / 604 KB (ekip-01, `bin`, `obj`, `node_modules` dolu); 131,7 MB / 600 KB (ekip-02, yeni klon) |
| İlk build süresi, boş cache (order / product / web-ui) | 9 / 6 / 8 sn (paketler Nexus önbelleğindeyken) |
| İmaj boyutu (order / product / web-ui) | 604 MB / 545 MB / 127 MB (`docker images`; SDK imajı 1,98 GB). Temel imaj sonradan registry'den çekilirse aynı imajlar 435 MB / 376 MB görünür; değerler örnektir |
| Süreç kullanıcısı | .NET imajları `app` (uid 1654), `web-ui` uid 101 |

Tam dosyalar: şablon projede `checkpoint/lab-03a`.

## Slayttan farklar

- **`.npmrc` kopyalanır.** Slayttaki `COPY src/web-ui/package*.json ./` satırı `.npmrc` dosyasını kapsamaz. Dosya imaja girmezse `npm ci` lock dosyasındaki `registry.npmjs.org` adreslerine gider: kapalı ağda başarısız olur, açık ağda sessizce Nexus'u atlar.
- **`.dockerignore` desenleri `**/` ile yazılır.** Slayttaki `bin/`, `obj/`, `node_modules/` yalnızca kökteki klasörleri dışlar; `src/…/bin` ve `src/web-ui/node_modules` context'e girer.
- **`nginx.conf` bu labda yazılmaya başlar.** `web-ui` imajı `deploy/nginx.conf` dosyasını kopyalar; dosya starter'da yalnızca yorumdan ibarettir. Statik sunum bloğu bu labda, `/api` kuralları LAB 03-B'de eklenir. `proxy_pass` satırları şimdiden yazılırsa `web-ui` tek başına çalışmaz (Nginx açılışta `order-service` adını çözemez).

Üçü de `slayt-guncellemeleri.md` içindedir.

## Sık takılınan yerler

- **Context yanlış:** `docker build src/order-service` → `common-contracts` bulunamaz. Komut repo kökünde, `-f` ile.
- **`order-service` tek başına çalışırken veritabanı yolu.** `-e ConnectionStrings__Orders=…/tmp/…` verilmezse uygulama `/app/orders.db` dosyasını oluşturamaz ve `SQLite Error 14` verir. Sandbox'ta gözlenen: süreç hata verdiği halde container kapanmadı, `docker ps` "Up" göstermeye devam etti (elle silindi). LAB 03-B'deki "çalışıyor ≠ sağlıklı" tartışmasının ön gösterimi olarak kullanabilirsiniz.
- **`whoami` yok / `id` yok:** .NET imajında ikisi de vardır; Alpine tabanlı Nginx imajında `id` vardır.
- **Her build'de imaj kimliği değişir.** BuildKit, bütün katmanlar cache'ten gelse bile yeni bir oluşturma zamanı yazar; `docker build -q` her seferinde farklı bir `sha256` basar. Soran olursa: bu yüzden imaj bir kez build edilir ve etiketlenir (LAB 03-B, 5. gün).
- **Sandbox'ta ortak Docker:** iki ekip aynı makineyi paylaşıyorsa `order-service:dev` gibi etiketler ve `-p 8080:8080` çakışır. Tek ekiple prova edin ya da ekiplere ayrı etiket ve port verin.

## Kurtarma akışı

| Durum | Ne yapılır |
|---|---|
| Lab başında `v1.0.1` yok | `make checkpoint EKIP=NN LAB=gun2` |
| İlk build `x509` veriyor | `make onkontrol EKIP=NN`; imaj eksikse `bash bootstrap/bootstrap.sh ws-imajlar`. Bu **olmazsa** CA adımını (LAB 03-B, Adım 2c) öne alın ve devam edin |
| 30. dk: ilk Dockerfile bitmedi | `git checkout sablon/checkpoint/lab-03a -- src/order-service/Dockerfile`; satır satır okuyun, ikinciyi kendileri yazsın |
| 60. dk: `web-ui` build olmuyor | `git checkout sablon/checkpoint/lab-03a -- src/web-ui/Dockerfile deploy/nginx.conf` |
| 85. dk: imajlar yok | `make checkpoint EKIP=NN LAB=lab-03a`; ekip üç build komutunu çalıştırıp LAB 03-B'ye geçer |

Her ekip öğleden sonraya `feature/9-docker` branch'inde üç çalışan Dockerfile ile girmelidir; eksik kalan dosyayı checkpoint'ten almak beş dakikadır.
