# LAB 03-B · Çözüm ve eğitmen notları

Registry, Compose ve ikinci VM · 95 dk · Gün 3, Modül 4 · öğrenci rehberi: [`../ogrenci/LAB-03-B.md`](../ogrenci/LAB-03-B.md)

**Durum:** `SANDBOX_VERIFIED`. ekip-01 ile, deploy token'lar, registry sayfası, MR ve iki arayüz denemesi gerçek tarayıcıda yapılarak koşuldu (`kanit/faz-3/lab-03-b-ekip01.txt`, 34 denetim). `checkpoint/lab-03b` ekip-02 üzerinde iki kez uygulandı (33 denetim).

## Eğitmen komutları

| Ne | Komut (`lab-ortami/` içinde) |
|---|---|
| Çözümü uygula | `bash dogrula/cozum.sh 03-b NN` |
| Denetle | `make dogrula-lab LAB=03-b EKIP=NN` |
| Ekibi bu labın başına / sonuna getir | `make checkpoint EKIP=NN LAB=lab-03a` / `LAB=lab-03b` |

## Süre dağılımı ve ara kontroller

| Dakika | Adım | Ara kontrol |
|---|---|---|
| 0–10 | 1 · Etiketle | İki etiket aynı `IMAGE ID` |
| 10–30 | 2 · Token, login (`x509`), CA, push | `x509`'u gören herkes `certs.d` ile çözdü mü? |
| 30–35 | 3 · Registry sayfası | **45. dk: herkesin imajları registry'de** |
| 35–50 | 4 · `compose.yaml`, `nginx.conf` | `docker compose config` hatasız |
| 50–65 | 5 · Lokal `compose up`, Error 14, düzeltme | Hatayı logdan bulan var mı? |
| 65–75 | 6 · İkinci VM | Pull önce reddedildi mi? |
| 75–85 | 7 · Smoke test, MR | Bir ekibin VM'deki arayüzünü projeksiyonda açın |
| 85–95 | Toparlama | |

## Çözüm

### Adım 1–2

```bash
SHA=$(git rev-parse --short HEAD)
docker build -f src/order-service/Dockerfile   --build-arg MCR=$MCR -t $IMG/order-service:1.0.1   -t $IMG/order-service:$SHA .
docker build -f src/product-service/Dockerfile --build-arg MCR=$MCR -t $IMG/product-service:1.0.1 -t $IMG/product-service:$SHA .
docker build -f src/web-ui/Dockerfile          --build-arg HUB=$HUB -t $IMG/web-ui:1.0.1          -t $IMG/web-ui:$SHA .
```

Deploy token: Settings > Repository > Deploy tokens; ad ve kullanıcı adı `ekipNN-deploy`, scope `read_registry` + `write_registry`.

```bash
read -rs TOKEN
echo "$TOKEN" | docker login $REGISTRY -u ekip$EKIP-deploy --password-stdin    # x509
sudo mkdir -p /etc/docker/certs.d/$REGISTRY
sudo cp $CA_CERT /etc/docker/certs.d/$REGISTRY/ca.crt
echo "$TOKEN" | docker login $REGISTRY -u ekip$EKIP-deploy --password-stdin    # Login Succeeded
unset TOKEN
for s in order-service product-service web-ui; do docker push --all-tags $IMG/$s; done
```

### Adım 4 · `deploy/compose.yaml`

```yaml
services:
  product-service:
    image: ${IMG}/product-service:${TAG}

  order-service:
    image: ${IMG}/order-service:${TAG}
    environment:
      ConnectionStrings__Orders: Data Source=/data/orders.db
    volumes:
      - orders-data:/data

  web-ui:
    image: ${IMG}/web-ui:${TAG}
    ports: ["${WEB_PORT:-8080}:8080"]
    depends_on: [product-service, order-service]

volumes:
  orders-data:
```

### Adım 4 · `deploy/nginx.conf`

```nginx
server {
  listen 8080;
  root /usr/share/nginx/html;

  location / { try_files $uri /index.html; }

  location /api/products {
    proxy_pass http://product-service:8080;
  }

  location /api/orders {
    proxy_pass http://order-service:8080;
  }
}
```

Commit: `feat(deploy): add compose file and nginx reverse proxy`; ardından `web-ui` yeniden build edilir (`nginx.conf` imajın içindedir).

### Adım 5 · SQLite Error 14 ve çözümü

`TAG=1.0.1 docker compose -p ekip$EKIP -f deploy/compose.yaml up -d` sonrası sandbox'ta gözlenen:

- `docker compose ps -a`: üç container da **"Up"**.
- `docker compose logs order-service`: `Unhandled exception. Microsoft.Data.Sqlite.SqliteException (0x80004005): SQLite Error 14: 'unable to open database file'.`
- Arayüz: katalog listelenir, üstte "Veriler yüklenemedi" uyarısı çıkar (talepler `502`).

Neden: `orders-data` volume'u `/data`'ya bağlanır. İmajda `/data` yoktur; Docker dizini `root` sahipliğiyle oluşturur. Süreç `app` (uid 1654) kullanıcısıyla çalışır ve yazamaz.

Çözüm, `src/order-service/Dockerfile`, son stage'de `USER` satırından **önce**:

```dockerfile
COPY --from=build /app .
RUN mkdir /data && chown $APP_UID /data
USER $APP_UID
```

Boş bir named volume ilk bağlandığında imajdaki dizinin içeriğini ve sahipliğini devralır. **Var olan volume devralmaz:** ilk denemede oluşan `ekipNN_orders-data` hâlâ `root`'a aittir. Bu yüzden:

```bash
git add src/order-service/Dockerfile
git commit -m "fix(order): create the data directory for the non-root user"
SHA=$(git rev-parse --short HEAD)
# üç imajı Adım 1'deki komutlarla yeniden etiketle
docker compose -p ekip$EKIP -f deploy/compose.yaml down -v     # eski volume silinir
docker compose -p ekip$EKIP -f deploy/compose.yaml up -d
```

Öğrenci rehberi çözümü vermez; "Yaygın hatalar"ın ilk iki satırı yönlendirir. İpucunu kademeli verin: (1) "loga bakın", (2) "süreç kim, dizin kimin?", (3) "slayttaki ilk kart", (4) Dockerfile satırı.

Kalıcılık denetimi, son push ve `1.0.1` etiketinin taşınması öğrenci rehberindeki gibidir. Ölçülen örnek:

```
1.0.1:   sha256:ed8f9301…   <- son commit'in imajı
afd5969: sha256:cc6f68d6…   <- ilk build (Dockerfile'da /data yok)
d99149c: sha256:ed8f9301…   <- son commit
```

### Adım 6–7 · İkinci VM

```bash
scp deploy/compose.yaml $TEST_VM_USER@$TEST_VM:/opt/saha/ekip$EKIP/compose.yaml
printf 'IMG=%s\nTAG=1.0.1\nWEB_PORT=%s\n' "$IMG" "$WEB_PORT" | ssh $TEST_VM_USER@$TEST_VM "cat > /opt/saha/ekip$EKIP/.env"
VM=$TEST_VM_USER@$TEST_VM
vm() { ssh $VM "cd /opt/saha/ekip$EKIP && export DOCKER_CONFIG=/opt/saha/ekip$EKIP/.docker && $*"; }
vm docker compose -p ekip$EKIP pull          # error from registry: access forbidden
# lider: ekipNN-pull, yalnızca read_registry
read -rs TOKEN
echo "$TOKEN" | ssh $VM "mkdir -p /opt/saha/ekip$EKIP/.docker && DOCKER_CONFIG=/opt/saha/ekip$EKIP/.docker docker login $REGISTRY -u ekip$EKIP-pull --password-stdin"
unset TOKEN
vm docker compose -p ekip$EKIP pull
vm docker compose -p ekip$EKIP up -d
curl -fsS $TEST_URL/api/products | head -c 60
```

MR: `feature/9-docker` → `develop`, başlık `build(docker): add Dockerfiles and compose deployment`, `Closes #3`, squash açık.

Tam dosyalar: şablon projede `checkpoint/lab-03b` (= `checkpoint/gun3`).

## Doğrulanan olumsuz durumlar

| Deneme | Gerçek çıktı (Docker 29.10.0, GitLab 19.6.1) |
|---|---|
| CA tanıtılmadan `docker login` | `Error response from daemon: Get "https://…:5050/v2/": tls: failed to verify certificate: x509: certificate signed by unknown authority` |
| Login olmadan `docker push` | `error from registry: access forbidden` |
| `read_registry` token'ı ile push | `failed commit on ref "index-sha256:…": server message: insufficient_scope: authorization failed` |
| İkinci VM'de login olmadan `docker compose pull` | `Error response from daemon: error from registry: access forbidden` |
| `/data` dizini olmayan imajla Compose | `SQLite Error 14: 'unable to open database file'`; container "Up" kalır |
| `/api` kuralları olan `web-ui` imajı tek başına | `nginx: [emerg] host not found in upstream "product-service"`; çıkış kodu 1 |

> Slayttaki `denied: requested access to the resource is denied` metni bu sürümlerde **çıkmadı**; yerine yukarıdaki iki mesaj geliyor. Katılımcı "denied" arıyorsa bunu söyleyin. (`slayt-guncellemeleri.md`)

## Sık takılınan yerler

- **`WEB_PORT` lokalde de ekip portudur.** Değişken eğitim makinesinde tanımlıdır (ekip-01 için `8081`); lokal Compose da o portu yayınlar. Adres `http://localhost:$WEB_PORT`. Slayttaki lokal örnek 8080'i gösterir.
- **"Up" ama çalışmıyor.** `order-service` hata verdiği halde container kapanmaz (bkz. yukarıdaki tablo). `docker compose ps` yanıltır; `logs` ilk bakılacak yerdir. İsteyen ekibe sorun: "Compose bunu nasıl fark edebilirdi?" (healthcheck).
- **Düzeltmeden sonra hata sürüyor.** Volume silinmemiştir (`down -v`). Lokalde veri olmadığı için güvenlidir; test VM'de `-v` kullanılmaz.
- **Token'ı kaçırdılar.** Değer bir kez gösterilir. Yeni token oluşturmak bir dakikadır; eskisini **Revoke** edin.
- **`certs.d` dizin adı.** Port unutulursa (`…/gitlab.kurum.test/`) Docker dosyayı görmez. `ls /etc/docker/certs.d/` ile `echo $REGISTRY` yan yana.
- **Test VM paylaşılır.** Ekipler `DOCKER_CONFIG` kullanmazsa aynı `~/.docker/config.json` dosyasına yazar; son giren kazanır, diğerinin pull'u reddedilir. Rehberdeki `vm` yardımcısı bunu her komutta ayarlar.
- **Sandbox'ta `certs.d` ortaktır.** Tek katılımcı makinesi vardır; bir ekip CA'yı tanıtınca diğer ekip `x509` hatasını yaşamaz. `x509`'u göstermek için ilk ekibin adımını projeksiyonda yapın. BELBİM'de herkesin kendi makinesi vardır.
- **`docker push --all-tags`** o imaj adının yereldeki **bütün** etiketlerini gönderir; eski SHA etiketleri de gider. Bu labda isteniyor (digest karşılaştırması).

## Kurtarma akışı

| Durum | Ne yapılır |
|---|---|
| Lab başında Dockerfile'lar yok | `make checkpoint EKIP=NN LAB=lab-03a` |
| 30. dk: `x509` çözülemedi | `certs.d` komutlarını birlikte yazın; dizin adını denetleyin |
| 45. dk: imajlar registry'de değil | Eğitmen token'ı birlikte oluşturur ve push'u izler. 55. dakikayı geçerse `make checkpoint EKIP=NN LAB=lab-03b` ve ekip Adım 6'daki komutları **okuyarak** çalışan ortamı inceler (`vm docker compose -p ekipNN ps`, `logs`, smoke test) |
| 65. dk: Error 14 çözülemedi | Çözüm satırını verin; `down -v` adımını birlikte yapın |
| 80. dk: ikinci VM'de çalışmıyor | `make checkpoint EKIP=NN LAB=lab-03b` |

`checkpoint/lab-03b` uygulanınca: `develop` güncellenir, `ekipNN-deploy` ve `ekipNN-pull` token'ları yeniden oluşturulur (değerleri ekibin `~/.lab/deploy-tokens` dosyasına yazılır), üç imaj `1.0.1` ve commit SHA ile registry'ye konur, uygulama ikinci VM'de `TAG=1.0.1` ile başlatılır ve bir örnek talep kaydedilir. Sandbox'ta ayrıca katılımcı makinesinin Docker'ına kurum CA'sı tanıtılır (makine ortak olduğu için bütün ekipleri etkiler). Yarının ön koşulu: `develop` üzerinde Dockerfile'lar ve `compose.yaml`.
