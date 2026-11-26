# LAB 03-A · Üç servis için Dockerfile

| | |
|---|---|
| **Gün / modül** | Gün 3 · Modül 2 |
| **Süre** | 95 dk (son 10 dk toparlama ve kontrol) |
| **Başlangıç durumu** | `checkpoint/gun2`: `main` üzerinde `v1.0.1`, `develop` güncel ve korumalı |
| **Takılırsan** | Build context repo kökü olmalı: `docker build -f src/…/Dockerfile .` Çözülmüş hal: `checkpoint/lab-03a` (bkz. bölüm 9) |

**Öğrenme kazanımı:** Bir .NET servisi ve bir React uygulaması için multi-stage Dockerfile yazabilir, katman sırasını cache'e göre kurabilir, imajı root olmayan kullanıcıyla çalıştırabilir ve `.dockerignore` ile build context'i küçültebilirsiniz.

Örnek değerler (prova ortamı):

| Değişken | Örnek değer | Ne için |
|---|---|---|
| `MCR` | `gitlab.kurum.test:5050/egitim/base` | .NET temel imajlarının iç aynası (`--build-arg MCR=$MCR`) |
| `HUB` | `gitlab.kurum.test:5050/egitim/base` | Node ve Nginx temel imajlarının iç aynası (`--build-arg HUB=$HUB`) |

> **Temel imajlar makinenizde hazır.** Kapalı ağda temel imajlar internetten değil iç aynadan gelir ve eğitim makinenize önceden yüklenmiştir: `docker images | grep /base/`. Bu yüzden bu labda registry'ye giriş yapmanız gerekmez. İki şeyden kaçının: `docker build --pull` (imajı registry'den yeniden ister) ve Dockerfile'ın başına `# syntax=…` satırı eklemek (Docker Hub'dan ek bir imaj ister). Registry ve sertifika konusu LAB 03-B'de.

## 1. Amaç

`v1.0.1` kodunu çalıştırılabilir üç imaja dönüştürmek: `order-service`, `product-service`, `web-ui`. Bugün her adımı elle yapıyoruz ki yarın pipeline'da hangi komutun neden orada olduğunu bilelim.

## 2. Ön koşullar

- LAB 02-B tamam: `git switch develop && git pull` hatasız.
- Docker çalışıyor: `docker version` ve `docker compose version` hata vermiyor.
- Dört temel imaj makinede: `docker images | grep /base/` dört satır göstermeli (`dotnet/sdk`, `dotnet/aspnet`, `library/node`, `nginxinc/nginx-unprivileged`). Eksikse eğitmene haber verin.
- `echo $MCR $HUB` iki adres yazıyor.

## 3. Kullanılacak sistemler

| Sistem | Ne için |
|---|---|
| Eğitim makinesi (terminal, editör, Docker) | Dockerfile'lar, build, çalıştırma |
| İç GitLab | Issue; lab sonunda branch'i push etmek |
| Nexus | `docker build` içindeki `dotnet restore` ve `npm ci` paketleri buradan alır |

## 4. Adımlar

### Adım 1 · `develop`'tan `feature/9-docker` branch'ini aç (5 dk)

GitLab'de bir issue açın: `Servisler için Docker imajları` (numarasını not edin; MR'ı LAB 03-B'nin sonunda açacaksınız). Branch adı slayttaki gibi kalır.

```bash
cd ~/saha-ekipman-portal
git switch develop && git pull
git switch -c feature/9-docker
```

### Adım 2 · `order-service` için multi-stage Dockerfile yaz (20 dk)

Dosya: `src/order-service/Dockerfile`. Build context **repo köküdür**: servis `common-contracts`'a ihtiyaç duyar. İskelet:

```dockerfile
ARG MCR=mcr.microsoft.com
FROM ${MCR}/dotnet/sdk:10.0 AS build
WORKDIR /src
# 1) NuGet.config                       (restore kaynağı: Nexus)
# 2) src/common-contracts/              (order-service buna ProjectReference ile bağlı)
# 3) yalnızca order-service'in .csproj dosyası
RUN dotnet restore src/order-service
# 4) order-service'in kaynak kodu
RUN dotnet publish src/order-service -c Release -o /app

FROM ${MCR}/dotnet/aspnet:10.0
WORKDIR /app
# 5) build stage'inin /app çıktısı
# 6) süreç root olmayan kullanıcıyla çalışsın
ENTRYPOINT ["dotnet", "order-service.dll"]
```

Altı yorum satırının her biri tek bir Dockerfile komutudur (`COPY` ya da `USER`). İpuçları:

- 3 ve 4 neden ayrı? `.csproj` nadiren, kaynak kod her commit'te değişir. Değişmeyen katman cache'ten gelir.
- 5 için `COPY --from=<stage adı>` kullanılır.
- 6 için temel imaj hazır bir kullanıcı sunar; kimliği `APP_UID` ortam değişkenindedir.
- .NET imajları 8080 portunu dinler; `EXPOSE` yazmanız gerekmez.

Build edin ve commit edin:

```bash
docker build -f src/order-service/Dockerfile --build-arg MCR=$MCR -t order-service:dev .
git add src/order-service/Dockerfile
git commit -m "build(order): add multi-stage Dockerfile"
```

### Adım 3 · Aynı kalıbı `product-service`'e uygula (10 dk)

`src/product-service/Dockerfile`: aynı dosya, farklı servis adı. İki dosya arasındaki fark yalnızca servis adı olmalı:

```bash
diff src/order-service/Dockerfile src/product-service/Dockerfile
git add src/product-service/Dockerfile
git commit -m "build(product): add multi-stage Dockerfile"
```

### Adım 4 · `web-ui` için Node + Nginx Dockerfile'ını yaz (20 dk)

Kalıp aynı, araçlar farklı: Node yalnızca build içindir; çalışan imajda statik dosyalar ve Nginx vardır.

`src/web-ui/Dockerfile` iskeleti:

```dockerfile
ARG HUB=docker.io
FROM ${HUB}/library/node:24-alpine AS build
WORKDIR /app
# 1) package.json, package-lock.json ve .npmrc   (npm ci paketleri Nexus'tan alsın)
RUN npm ci
# 2) web-ui'nin kaynak kodu
RUN npm run build

FROM ${HUB}/nginxinc/nginx-unprivileged:stable-alpine
# 3) deploy/nginx.conf  ->  /etc/nginx/conf.d/default.conf
# 4) build stage'inin /app/dist çıktısı  ->  /usr/share/nginx/html
EXPOSE 8080
```

İpuçları:

- Context repo kökü olduğu için kaynak yolları `src/web-ui/…` ile başlar.
- `package*.json` deseni `.npmrc` dosyasını **kapsamaz**; ayrıca yazın. `.npmrc` imaja girmezse `npm ci` lock dosyasındaki dış adreslere gitmeye çalışır.
- İsterseniz bir `HEALTHCHECK` ekleyin; Alpine tabanlı Nginx imajında `wget` vardır (.NET runtime imajında yoktur).

`deploy/nginx.conf` şimdilik yalnızca statik dosyaları sunsun (`/api` kurallarını LAB 03-B'de ekleyeceksiniz):

```nginx
server {
  listen 8080;
  root /usr/share/nginx/html;

  location / { try_files $uri /index.html; }
}
```

```bash
git add src/web-ui/Dockerfile deploy/nginx.conf
git commit -m "build(web-ui): add Node and Nginx Dockerfile"
```

### Adım 5 · `.dockerignore` ekle; context boyutunu karşılaştır (10 dk)

Önce context'e şu an ne girdiğini ölçün. Aşağıdaki komut context'in tamamını geçici bir build aşamasına kopyalar ve boyutunu yazar:

```bash
du -sh .git src/web-ui/node_modules
printf 'FROM %s\nCOPY . /ctx\nRUN du -sh /ctx\n' "$HUB/library/node:24-alpine" \
  | docker build --no-cache --progress=plain -f - . 2>&1 | grep '/ctx$'
```

Şimdi repo köküne `.dockerignore` yazın. Dışarıda kalması gerekenler: `.git`, build çıktıları (`bin`, `obj`, `dist`), `node_modules`, test ve coverage çıktıları, yerel veritabanı dosyaları, `.env`.

> **Dikkat:** `.dockerignore`, `.gitignore` gibi çalışmaz. `bin/` yalnızca kökteki `bin` klasörünü dışlar; alt klasörlerdekiler için `**/bin/` yazılır.

Ölçümü tekrarlayın, farkı not edin ve commit edin:

```bash
git add .dockerignore
git commit -m "build: add .dockerignore"
```

### Adım 6 · Üç imajı build et; `docker images` ile boyutlara bak (10 dk)

```bash
docker build -f src/order-service/Dockerfile   --build-arg MCR=$MCR -t order-service:dev .
docker build -f src/product-service/Dockerfile --build-arg MCR=$MCR -t product-service:dev .
docker build -f src/web-ui/Dockerfile          --build-arg HUB=$HUB -t web-ui:dev .
docker images
```

SDK imajı ile sizin imajlarınızın boyutunu karşılaştırın: derleyici ve kaynak kod son imajda yok.

**Cache'i görün.** Bir kaynak dosyasını değiştirip yeniden build edin; `restore` adımı çalışmamalı:

```bash
echo "// cache" >> src/order-service/Program.cs
docker build --progress=plain -f src/order-service/Dockerfile --build-arg MCR=$MCR -t order-service:dev . 2>&1 | grep -E 'CACHED|RUN dotnet'
git checkout src/order-service/Program.cs
docker build -q -f src/order-service/Dockerfile --build-arg MCR=$MCR -t order-service:dev .
```

Aynı denemeyi `web-ui` için bir `.css` dosyasıyla yapın: `npm ci` cache'ten gelmeli.

### Adım 7 · Tek tek çalıştır; `/health` ve logları kontrol et (10 dk)

```bash
docker run -d --name product -p 8080:8080 product-service:dev
curl -fsS --retry 10 --retry-connrefused --retry-delay 2 http://localhost:8080/health; echo
curl -s http://localhost:8080/api/products | head -c 70; echo
docker logs product
docker exec product whoami
docker rm -f product
```

`order-service` bir SQLite dosyasına yazar. Şimdilik dosyayı herkesin yazabildiği `/tmp` altına yönlendirin (kalıcı veri LAB 03-B'nin konusu):

```bash
docker run -d --name order -p 8080:8080 \
  -e "ConnectionStrings__Orders=Data Source=/tmp/orders.db" order-service:dev
curl -fsS --retry 10 --retry-connrefused --retry-delay 2 http://localhost:8080/health; echo
docker exec order whoami
docker rm -f order
```

```bash
docker run -d --name web -p 8080:8080 web-ui:dev
curl -fsS --retry 10 --retry-connrefused --retry-delay 2 -o /dev/null -w '%{http_code}\n' http://localhost:8080/
docker exec web id -u
docker rm -f web
```

Arayüz açılır ama "Veriler yüklenemedi" der: arkasında API yok. Üç servisi birbirine LAB 03-B'de bağlayacaksınız.

Son olarak branch'i gönderin (MR'ı LAB 03-B'nin sonunda açacaksınız):

```bash
git push -u origin feature/9-docker
```

### Toparlama (10 dk)

Bölüm 6'yı işaretleyin; bölüm 8'i yanıtlayın.

## 5. Beklenen çıktı

Context boyutu (değerler makinenize göre değişir; `bin`, `obj` ve `node_modules` doluysa ilk değer daha büyüktür):

```
#7 0.169 378.2M	/ctx        # .dockerignore yok
#7 0.084 604.0K	/ctx        # .dockerignore var
```

`docker images` (örnek çıktı; boyutlar mimariye ve Docker sürümüne göre değişir, prova ortamı arm64):

```
REPOSITORY                                            TAG             SIZE
web-ui                                                dev             127MB
product-service                                       dev             545MB
order-service                                         dev             604MB
gitlab.kurum.test:5050/egitim/base/dotnet/sdk         10.0            1.98GB
gitlab.kurum.test:5050/egitim/base/dotnet/aspnet      10.0            542MB
```

İkinci build:

```
CACHED
[build 6/8] RUN dotnet restore src/order-service
[build 8/8] RUN dotnet publish src/order-service -c Release -o /app
```

Çalışan container'lar:

```
Healthy
[{"code":"ADP-01","name":"Terminal adaptörü","inStock":true},{"code"
app          # whoami: root değil
101          # web: id -u
```

## 6. Başarı kriterleri

- [ ] Üç Dockerfile ve `.dockerignore` repoda, `feature/9-docker` branch'inde commit'li ve push edildi.
- [ ] Üç imaj `docker build -f src/…/Dockerfile .` ile (context kökten) build oluyor.
- [ ] Üç container da root olmayan kullanıcıyla çalışıyor (`whoami` / `id -u`).
- [ ] İkinci build'de `dotnet restore` ve `npm ci` adımları `CACHED`.
- [ ] `/health` iki API'de `Healthy`; `web-ui` 8080'de `200` dönüyor.
- [ ] Dockerfile'larda `latest` etiketi yok; temel imajlar `${MCR}` / `${HUB}` üzerinden geliyor.

## 7. Yaygın hatalar ve ipuçları

| Belirti | Olası neden | Ne yapmalı |
|---|---|---|
| `COPY failed` / `"/src/common-contracts": not found` | Context servis klasörü verilmiş (`docker build src/order-service`) | Komutu repo kökünde, sonda `.` ile çalıştırın; dosyayı `-f` ile gösterin |
| `x509: certificate signed by unknown authority` (build sırasında) | `--pull` kullanıldı ya da temel imaj makinede yok; Docker registry'ye gitmek zorunda kaldı | `--pull` yazmayın; `docker images \| grep /base/`. İmaj yoksa eğitmene haber verin |
| Build `mcr.microsoft.com` ya da `docker.io` adresine gidiyor (kapalı ağda zaman aşımı; açık ağda imajı internetten indirir) | `--build-arg MCR=…` / `HUB=…` verilmedi; Dockerfile'daki varsayılan dış adres kullanıldı | Build argümanını ekleyin; `echo $MCR $HUB` |
| Build `docker.io/docker/dockerfile` imajını arıyor | Dockerfile'ın başında `# syntax=` satırı var | Satırı silin |
| `error NU1301` / restore Nexus'a ulaşamıyor | `NuGet.config` imaja kopyalanmadı | İskeletteki 1. satır |
| `npm ci` çok yavaş ya da dış adrese gidiyor | `.npmrc` kopyalanmadı | Adım 4'teki ipucu |
| Her build'de restore yeniden çalışıyor | `COPY` sırası cache'i bozuyor (kaynak kod, restore'dan önce kopyalanmış) | Önce yalnızca `.csproj`, sonra `restore`, sonra kaynak |
| `Bind for 0.0.0.0:8080 failed: port is already allocated` | Önceki container duruyor (ya da makineyi paylaşan başka biri 8080'i kullanıyor) | `docker ps`; `docker rm -f <ad>`; gerekirse `-p 8085:8080` |
| `order` container'ı açılıyor ama `/health` yanıt vermiyor; logda `SQLite Error 14` | `-e ConnectionStrings__Orders=…` verilmedi; uygulama `/app` altına yazamıyor | Adım 7'deki komutu kullanın. Asıl çözümü LAB 03-B'de bulacaksınız |
| `docker exec order whoami` → `root` | `USER` satırı yok | İskeletteki 6. satır |

## 8. Kendini kontrol soruları

1. Multi-stage build imaj boyutu dışında neyi iyileştirir?
2. `COPY . .` satırını Dockerfile'ın en üstüne yazsaydınız ikinci build'de ne değişirdi?
3. Dockerfile servis klasöründe duruyor ama context repo kökü. Neden? Context'i servis klasörü yapsaydınız hangi satır kırılırdı?

## 9. Başlangıç durumuna dönme

**Laba baştan başlamak:**

```bash
docker rm -f product order web 2>/dev/null
cd ~/saha-ekipman-portal
git switch develop
git branch -D feature/9-docker
git push origin --delete feature/9-docker 2>/dev/null    # push ettiyseniz
```

İmajları silmeniz gerekmez; yeniden build edilince üzerine yazılır.

**Takıldıysanız (`checkpoint/lab-03a`):** labın tamamlanmış dosyalarını alın ve kendi yazdıklarınızla karşılaştırın:

```bash
git fetch sablon
git diff HEAD sablon/checkpoint/lab-03a -- src/order-service/Dockerfile      # fark
git checkout sablon/checkpoint/lab-03a -- src/order-service/Dockerfile src/product-service/Dockerfile \
    src/web-ui/Dockerfile deploy/nginx.conf .dockerignore                     # dosyaları al
git status
```

Ekibin tamamını bu duruma getirmek gerekiyorsa eğitmen `checkpoint/lab-03a`'yı uygular.
