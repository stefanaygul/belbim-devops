# Lab komutları

On labın terminal özeti. Blokları sırayla ve ayrı ayrı çalıştırın; dosya tek parça çalıştırılacak bir betik değildir. **Arayüzde MR açma/merge, token üretme ve editörde kod yazma adımları arasında durun.** Her bölümde asıl rehber bağlantısı var. Beklenen hata komutları özellikle başarısız olur.

## Başlangıç · her yeni terminal

Sandbox'ta host üzerinde, bu çalışma alanının kök dizininden:

```bash
cd lab-ortami
docker compose exec -it -u ekip01 workstation bash -l
# ekip01 yerine kendi ekip kullanıcınızı yazın; bundan sonrası container içindedir.
```

BELBİM katılımcı makinesinde Bash kullanın; yönetici tarafından doldurulmuş `lab.env` dosyasını yükleyin:

```bash
set -a
source /size/verilen/lab.env   # gerçek dosya yolu ile değiştirin
set +a
export EKIP=01               # kendi iki haneli ekip numaranız
export IMG="$REGISTRY/$GITLAB_GROUP/ekip-$EKIP/saha-ekipman-portal"
export WEB_PORT=$((8080 + 10#$EKIP))
export TEST_URL="http://$TEST_VM:$WEB_PORT"
# Yalnızca prova ekibi 99: WEB_PORT=8099; TEST_URL=http://$TEST_VM:8099
```

Sandbox'ta bu değişkenler otomatik yüklenir. Aşağıdaki `rol lead` / `rol dev` komutları yalnızca sandbox içindir; gerçek eğitimde herkes kendi hesabı ve SSH anahtarıyla çalışır. Token/parolaları komut metnine yazmayın; `read -rs` ile girin.

## LAB 01-A · Starter proje, build ve dependency

[Adımlar ve dosya düzenlemeleri](lab-rehberleri/ogrenci/LAB-01-A.md).

### Ön kontrol

```bash
dotnet --version     # 10.0.x
node --version       # v24.x
git --version
```

### Adım 1 · Starter projeyi klonla, klasörleri incele

```bash
cd ~
git clone "$GITLAB_URL/$TEMPLATE_PROJECT.git" saha-ekipman-portal
cd saha-ekipman-portal
git branch -a
tree -L 2 -I 'node_modules|bin|obj' --dirsfirst
```

```bash
git config --global user.name "Adınız Soyadınız"
git config --global user.email "kurum e-posta adresiniz"
```

### Adım 2 · `dotnet restore`, `build`, `test`

```bash
# restore: NuGet.config'teki Nexus'tan tüm projelerin paketlerini indirir (bağımlılıklar burada gelir)
dotnet restore SahaPortal.sln
# build: kodu Release modunda derler; --no-restore paketleri tekrar indirmez, bir önceki adımı kullanır
dotnet build SahaPortal.sln -c Release --no-restore
# test: tests/ altındaki birim testlerini çalıştırır; --no-build yeniden derlemez, az önceki çıktıyı test eder
dotnet test SahaPortal.sln -c Release --no-build
```

### Adım 3 · `web-ui` içinde `npm ci` ve `npm test`

```bash
# Arayüz projesinin klasörüne geç
cd src/web-ui
# ci: package-lock.json'daki sürümleri birebir, .npmrc'deki Nexus'tan kurar (node_modules'ü sıfırdan oluşturur)
npm ci
# test: package.json'daki "test" betiğini, yani Jest birim testlerini çalıştırır
npm test
# Repo köküne geri dön
cd ../..
```

### Adım 4 · NuGet bağımlılık ağacını oku

```bash
# order-service paketlerini listeler; --include-transitive sizin yazmadığınız, paketlerin getirdiği bağımlılıkları da gösterir
dotnet list src/order-service package --include-transitive
```

### Adım 5 · npm bağımlılık ağacını incele

```bash
cd src/web-ui
# Yalnızca package.json'a doğrudan yazılmış paketleri ve kurulu sürümlerini listeler
npm ls --depth=0
# react paketinin ağaçta nerede ve hangi sürümle bulunduğunu, onu kimin getirdiğini gösterir
npm ls react
cd ../..
```

### Adım 6 · `lab/01a-conflict` üzerindeki NU1605 hatasını çöz

```bash
# Sürüm çakışması hazırlanmış branch'e geç (order-service, EF Core 9.0.23'e doğrudan referans veriyor)
git switch lab/01a-conflict
# Beklenen hata: NU1605 "package downgrade". Mesajdaki "from … to …" sürümlerini okuyun
dotnet restore SahaPortal.sln
```

```bash
# Doğrudan referansı, Sqlite paketinin istediği 10.0.15'e hizalar (.csproj dosyasını günceller)
dotnet add src/order-service package Microsoft.EntityFrameworkCore -v 10.0.15
```

```bash
# Düzeltmeyi doğrula: restore artık hatasız geçmeli, build ve test yeşil olmalı
dotnet restore SahaPortal.sln
dotnet build SahaPortal.sln -c Release --no-restore
dotnet test SahaPortal.sln -c Release --no-build
# Değişen .csproj dosyasını commit'e hazırla ve commit at
git add src/order-service/order-service.csproj
git commit -m "fix(order): align EntityFrameworkCore version"
# main'e geri dön
git switch main
```

### Adım 7 · API'leri ve web-ui'yi başlat; `/health` ve arayüzü doğrula

```bash
# Her servis ön planda çalışır ve terminali tutar; bu yüzden üç ayrı terminal açın.
# terminal 1: ürün kataloğu API'sini başlatır
dotnet run --project src/product-service      # http://localhost:5101

# terminal 2: sipariş API'sini başlatır
dotnet run --project src/order-service        # http://localhost:5102

# terminal 3: arayüzü Vite geliştirme sunucusuyla başlatır
cd src/web-ui && npm run dev                  # http://localhost:5173
```

```bash
# Dördüncü bir terminalden: iki servisin sağlık kontrolü "Healthy" dönmeli
curl -s http://localhost:5101/health; echo
curl -s http://localhost:5102/health; echo
# Katalog API'si ürün listesini JSON olarak dönmeli
curl -s http://localhost:5101/api/products; echo
```

## LAB 01-B · Feature branch, conflict ve commit

[Adımlar ve dosya düzenlemeleri](lab-rehberleri/ogrenci/LAB-01-B.md).

### Adım 1 · `feature/katalog-sarj-unitesi` branch'ini aç

```bash
cd ~/saha-ekipman-portal
# main'den başla
git switch main
# -c: yeni branch oluşturur ve ona geçer
git switch -c feature/katalog-sarj-unitesi
# Hangi branch'te olduğunuzu ve çalışma alanının temiz olduğunu gösterir
git status
```

### Adım 2 · Kataloğa `SRJ-04` "Şarj ünitesi" kaydını ekle

Editör: kataloğun sonuna SRJ-04 “Şarj ünitesi” ekleyin.

```bash
# Değişen dosyaları listeler
git status
# Değişikliği satır satır gösterir (+ eklenen, - silinen)
git diff
```

### Adım 3 · İlgili testi güncelle, `dotnet test` ile doğrula

Önce eski testin kırıldığını görün; sonra beklenen ürün listesine SRJ-04 ekleyip testi tekrar çalıştırın.

```bash
# İlk çalıştırmada katalog testi kırılır (beklenen); testi güncelledikten sonra yeşil olmalı
dotnet test SahaPortal.sln
```

### Adım 4 · Conventional Commits biçiminde commit at

```bash
# Katalog ve test değişikliklerini commit'e hazırla (staging)
git add src/product-service tests/product-service.tests
# Dosyalar "Changes to be committed" altında görünmeli
git status
# tip(kapsam): açıklama biçiminde commit at
git commit -m "feat(catalog): add charging unit"
# Son 3 commit'i tek satırda gösterir
git log --oneline -n 3
```

### Adım 5 · `lab/01b-rename` branch'ini merge et, conflict'i çöz

```bash
# Aynı satırı değiştiren hazır branch'i birleştir; beklenen: catalog.json'da CONFLICT
git merge origin/lab/01b-rename
```

```bash
# Çakışan dosya "both modified" olarak görünür
git status
# <<<<<<< / ======= / >>>>>>> işaretleri arasında iki tarafın sürümünü gösterir
cat src/product-service/Data/catalog.json
```

Editörde conflict işaretlerini silin; tek SRJ-04 satırı ve “Şarj ünitesi” adı kalsın.

```bash
# Dosyada unutulmuş conflict işareti kalıp kalmadığını kontrol eder
grep -n '<<<<<<<\|=======\|>>>>>>>' src/product-service/Data/catalog.json    # çıktı vermemeli
```

### Adım 6 · Testleri yeniden çalıştır, merge'ü tamamla

```bash
# Çözülen dosyayı "çözüldü" olarak işaretle
git add src/product-service/Data/catalog.json
# Birleşmiş kodun testleri geçmeli
dotnet test SahaPortal.sln
# Merge commit'ini git'in hazırladığı varsayılan mesajla tamamlar
git commit --no-edit
```

### Adım 7 · `git log --oneline --graph` ile geçmişi göster

```bash
# Geçerli branch'in geçmişini dallanma/birleşme çizgileriyle gösterir
git log --oneline --graph
# Üç branch'i birlikte çizer: merge'ün iki kolu nereden ayrılıp nerede birleşti
git log --oneline --graph main feature/katalog-sarj-unitesi origin/lab/01b-rename
```

## LAB 02-A · Proje, koruma ve Merge Request

[Adımlar ve dosya düzenlemeleri](lab-rehberleri/ogrenci/LAB-02-A.md).

### Ön kontrol

```bash
ls ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519 -C "$USER"
cat ~/.ssh/id_ed25519.pub
```

```bash
ssh -T git@$GITLAB_HOST
# Welcome to GitLab, @ekip01-dev!
```

### Adım 1 · Lokal repoyu ekip grubundaki projeye push et — *lider*

```bash
cd ~/saha-ekipman-portal
git switch main
git merge --no-ff feature/katalog-sarj-unitesi -m "Merge branch 'feature/katalog-sarj-unitesi'"
```

```bash
mkdir -p .gitlab/merge_request_templates
```

Editör: MR şablonu ve CODEOWNERS dosyalarını rehbere göre doldurun.

```bash
git add .gitlab
git commit -m "chore: add merge request template and CODEOWNERS"
```

Arayüz: lider ekip grubunda README eklemeden boş proje oluştursun. Sandbox: `rol lead`.

```bash
git remote rename origin sablon
git remote add origin "git@$GITLAB_HOST:$GITLAB_GROUP/ekip-$EKIP/saha-ekipman-portal.git"
git push -u origin main
git remote -v
```

### Adım 2 · `develop`'u oluştur; `main` ve `develop`'u koru — *lider*

```bash
git switch -c develop
git push -u origin develop
```

Arayüz: varsayılan branch develop; main/develop push No one, merge Maintainers. Aşağıdaki reset yalnızca bu deneme commit’ini geri alır; başka yerel değişiklik bulunmamalı.

```bash
git switch develop
git commit --allow-empty -m "test: direct push"
git push origin develop          # reddedilmeli
git reset --hard origin/develop  # deneme commit'ini geri al
```

### Adım 3 · Issue aç; `feature/3-stok-durumu` branch'ini oluştur — *yazar*

Arayüz: issue açın. Sandbox: `rol dev`.

```bash
git switch develop && git pull
git switch -c feature/3-stok-durumu
```

### Adım 4 · Kataloğa "stok durumu" alanını ekle, testi güncelle — *yazar*

Editör: DTO, katalog ve testlere inStock ekleyin; STD-03 false, diğerleri true.

```bash
dotnet test SahaPortal.sln
git add src tests
git commit -m "feat(catalog): add stock status"
git push -u origin feature/3-stok-durumu
```

### Adım 6 · Reviewer yorum yazsın; düzelt, thread'i çöz

Arayüz: develop hedefli MR açın; reviewer yorumu sonrası testi düzeltin. Push sonrasında thread’i çözün.

```bash
# düzeltmeyi yapın, sonra:
dotnet test SahaPortal.sln
git add tests
git commit -m "test(catalog): cover stock status in the products API"
git push
```

### Adım 7 · Merge et; branch silindi, issue kapandı mı? — *lider*

Arayüz: lider MR’ı merge etsin; issue kapansın. Yerel branch’i ancak bundan sonra silin.

```bash
git switch develop && git pull
git fetch --prune
git branch -D feature/3-stok-durumu      # squash sonrası -d "not fully merged" der; -D gerekir
git log --oneline --graph -n 6
```

## LAB 02-B · Release ve hotfix döngüsü

[Adımlar ve dosya düzenlemeleri](lab-rehberleri/ogrenci/LAB-02-B.md).

### Adım 1 · `release/1.0.0` branch'ini `develop`'tan aç — *yazar*

```bash
cd ~/saha-ekipman-portal
git switch develop && git pull
git switch -c release/1.0.0
```

### Adım 2 · CHANGELOG'u güncelle; MR ile `main`'e merge et

Editör: CHANGELOG’u 1.0.0 için güncelleyin. Push sonrasında release → main MR’ını squash kapalı, kaynak branch silinmeden merge edin.

```bash
git add CHANGELOG.md
git commit -m "chore(release): 1.0.0"
git push -u origin release/1.0.0
```

### Adım 3 · `main` üzerinde `v1.0.0` annotated tag'ini at, push et

Arayüz: v* tag korumasını Maintainers olarak ayarlayın. Sandbox: `rol dev`; reddedilme denemesi.

```bash
git switch main && git pull
git tag -a v1.0.0 -m "release: v1.0.0"
git push origin v1.0.0       # Developer: reddedilir
git tag -d v1.0.0            # yerel tag'i silin
```

Lider hesabına geçin. Sandbox: `rol lead`. Bu blok başarılı olmalı.

```bash
git switch main && git pull
git tag -a v1.0.0 -m "release: v1.0.0"
git push origin v1.0.0
git describe --tags
```

### Adım 5 · `hotfix/1.0.1` aç: boş ekipman kodu hatasını düzelt — *yazar*

Önce release/1.0.0 → develop MR’ını squash kapalı merge edin. Sandbox: `rol dev`. Issue açın; boş productId için önce testi, sonra düzeltmeyi yazın.

```bash
git fetch --tags origin
git switch -c hotfix/1.0.1 v1.0.0
```

```bash
dotnet test tests/order-service.tests      # yeni test KIRMIZI olmalı: hata gerçekten var
```

```bash
dotnet test SahaPortal.sln                 # hepsi yeşil
git add src tests
git commit -m "fix(order): reject empty product id"
```

```bash
git add CHANGELOG.md
git commit -m "chore(release): 1.0.1"
git push -u origin hotfix/1.0.1
```

### Adım 6 · MR ile `main`'e merge et, `v1.0.1` tag'ini at

Arayüz: hotfix → main MR’ını squash kapalı, branch silinmeden merge edin. Sandbox: `rol lead`.

```bash
git switch main && git pull
git tag -a v1.0.1 -m "release: v1.0.1"
git push origin v1.0.1
```

### Adım 7 · Hotfix'i `develop`'a da merge et; grafiği doğrula

Arayüz: hotfix → develop MR’ını da squash kapalı merge edin.

```bash
git fetch --prune --tags origin
git switch develop && git pull
git log --oneline --graph origin/main origin/develop
git tag -l 'v*'
```

```bash
git branch -r --contains "$(git log --no-merges --format=%H --grep='^fix(order)' -n 1 origin/main)"
```

## LAB 03-A · Üç servis için Dockerfile

[Adımlar ve dosya düzenlemeleri](lab-rehberleri/ogrenci/LAB-03-A.md).

### Adım 1 · `develop`'tan `feature/9-docker` branch'ini aç

Sandbox: `rol dev`. Arayüz: Docker görevi için issue açın.

```bash
cd ~/saha-ekipman-portal
git switch develop && git pull
git switch -c feature/9-docker
```

### Adım 2 · `order-service` için multi-stage Dockerfile yaz

Önce başlıktaki dosyaları rehberdeki iskelete göre editörde tamamlayın.

```bash
docker build -f src/order-service/Dockerfile --build-arg MCR=$MCR -t order-service:dev .
git add src/order-service/Dockerfile
git commit -m "build(order): add multi-stage Dockerfile"
```

### Adım 3 · Aynı kalıbı `product-service`'e uygula

Önce başlıktaki dosyaları rehberdeki iskelete göre editörde tamamlayın.

```bash
diff src/order-service/Dockerfile src/product-service/Dockerfile
git add src/product-service/Dockerfile
git commit -m "build(product): add multi-stage Dockerfile"
```

### Adım 4 · `web-ui` için Node + Nginx Dockerfile'ını yaz

Önce başlıktaki dosyaları rehberdeki iskelete göre editörde tamamlayın.

```bash
git add src/web-ui/Dockerfile deploy/nginx.conf
git commit -m "build(web-ui): add Node and Nginx Dockerfile"
```

### Adım 5 · `.dockerignore` ekle; context boyutunu karşılaştır

Context ölçümünü .dockerignore eklemeden önce ve ekledikten sonra çalıştırın.

```bash
du -sh .git src/web-ui/node_modules
printf 'FROM %s\nCOPY . /ctx\nRUN du -sh /ctx\n' "$HUB/library/node:24-alpine" \
  | docker build --no-cache --progress=plain -f - . 2>&1 | grep '/ctx$'
```

Ölçümü karşılaştırdıktan sonra dosyayı commit edin.

```bash
git add .dockerignore
git commit -m "build: add .dockerignore"
```

### Adım 6 · Üç imajı build et; `docker images` ile boyutlara bak

```bash
docker build -f src/order-service/Dockerfile   --build-arg MCR=$MCR -t order-service:dev .
docker build -f src/product-service/Dockerfile --build-arg MCR=$MCR -t product-service:dev .
docker build -f src/web-ui/Dockerfile          --build-arg HUB=$HUB -t web-ui:dev .
docker images
```

```bash
echo "// cache" >> src/order-service/Program.cs
docker build --progress=plain -f src/order-service/Dockerfile --build-arg MCR=$MCR -t order-service:dev . 2>&1 | grep -E 'CACHED|RUN dotnet'
git checkout src/order-service/Program.cs
docker build -q -f src/order-service/Dockerfile --build-arg MCR=$MCR -t order-service:dev .
```

### Adım 7 · Tek tek çalıştır; `/health` ve logları kontrol et

```bash
docker run -d --name product -p 8080:8080 product-service:dev
curl -fsS --retry 10 --retry-connrefused --retry-delay 2 http://localhost:8080/health; echo
curl -s http://localhost:8080/api/products | head -c 70; echo
docker logs product
docker exec product whoami
docker rm -f product
```

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

```bash
git push -u origin feature/9-docker
```

## LAB 03-B · Registry, Compose ve ikinci VM

[Adımlar ve dosya düzenlemeleri](lab-rehberleri/ogrenci/LAB-03-B.md).

### Adım 1 · Üç imajı `1.0.1` ve commit SHA ile etiketle

```bash
cd ~/saha-ekipman-portal
echo $IMG
SHA=$(git rev-parse --short HEAD)
docker build -f src/order-service/Dockerfile   --build-arg MCR=$MCR -t $IMG/order-service:1.0.1   -t $IMG/order-service:$SHA .
docker build -f src/product-service/Dockerfile --build-arg MCR=$MCR -t $IMG/product-service:1.0.1 -t $IMG/product-service:$SHA .
docker build -f src/web-ui/Dockerfile          --build-arg HUB=$HUB -t $IMG/web-ui:1.0.1          -t $IMG/web-ui:$SHA .
docker images | grep "/ekip-$EKIP/"
```

### Adım 2 · Deploy token ile login ol, imajları push et

Arayüz: ekip deploy token’ı (read_registry + write_registry). İlk login’in x509 ile reddedilmesi beklenir.

```bash
read -rs TOKEN        # token'ı yapıştırın, Enter (ekranda görünmez)
echo "$TOKEN" | docker login $REGISTRY -u ekip$EKIP-deploy --password-stdin
```

```bash
sudo mkdir -p /etc/docker/certs.d/$REGISTRY
sudo cp $CA_CERT /etc/docker/certs.d/$REGISTRY/ca.crt
ls -l /etc/docker/certs.d/
```

```bash
echo "$TOKEN" | docker login $REGISTRY -u ekip$EKIP-deploy --password-stdin
unset TOKEN
docker push --all-tags $IMG/order-service
docker push --all-tags $IMG/product-service
docker push --all-tags $IMG/web-ui
```

### Adım 4 · `compose.yaml` ve `nginx.conf` dosyalarını tamamla

Editör: compose.yaml ve nginx.conf’u rehbere göre tamamlayın; .env ve token’ları commit etmeyin.

```bash
TAG=1.0.1 docker compose -p ekip$EKIP -f deploy/compose.yaml config
```

```bash
git add deploy
git commit -m "feat(deploy): add compose file and nginx reverse proxy"
```

```bash
SHA=$(git rev-parse --short HEAD)
docker build -f src/web-ui/Dockerfile --build-arg HUB=$HUB -t $IMG/web-ui:1.0.1 -t $IMG/web-ui:$SHA .
```

### Adım 5 · Lokalde `compose up`; arayüzden bir talep oluştur

```bash
export TAG=1.0.1
docker compose -p ekip$EKIP -f deploy/compose.yaml up -d
docker compose -p ekip$EKIP -f deploy/compose.yaml ps -a
```

```bash
docker compose -p ekip$EKIP -f deploy/compose.yaml logs order-service
docker compose -p ekip$EKIP -f deploy/compose.yaml logs web-ui
```

SQLite Error 14 çözümü (eğitmen): order Dockerfile’da USER satırından önce /data oluşturup APP_UID’ye verin; sonra aşağıdaki düzeltme komutları. `down -v` yalnızca bu labın yerel deneme verisini siler, test VM’de çalıştırılmaz.

```bash
git add src/order-service/Dockerfile
git commit -m "fix(order): create the data directory for the non-root user"
SHA=$(git rev-parse --short HEAD)
docker build -f src/order-service/Dockerfile --build-arg MCR=$MCR -t $IMG/order-service:1.0.1 -t $IMG/order-service:$SHA .
docker build -f src/product-service/Dockerfile --build-arg MCR=$MCR -t $IMG/product-service:1.0.1 -t $IMG/product-service:$SHA .
docker build -f src/web-ui/Dockerfile --build-arg HUB=$HUB -t $IMG/web-ui:1.0.1 -t $IMG/web-ui:$SHA .
docker compose -p ekip$EKIP -f deploy/compose.yaml down -v
docker compose -p ekip$EKIP -f deploy/compose.yaml up -d
# Arayüz: http://localhost:$WEB_PORT üzerinden talep oluşturun; sonra kalıcılığı sınayın.
curl -fsS --retry 10 --retry-connrefused --retry-delay 2 http://localhost:$WEB_PORT/api/orders; echo
docker compose -p ekip$EKIP -f deploy/compose.yaml down
docker compose -p ekip$EKIP -f deploy/compose.yaml up -d
curl -fsS --retry 10 --retry-connrefused --retry-delay 2 http://localhost:$WEB_PORT/api/orders; echo
docker compose -p ekip$EKIP -f deploy/compose.yaml down
```

```bash
git push
docker push --all-tags $IMG/order-service
docker push --all-tags $IMG/product-service
docker push --all-tags $IMG/web-ui
```

### Adım 6 · İkinci VM'de pull et, kendi proje adınla çalıştır

```bash
scp deploy/compose.yaml $TEST_VM_USER@$TEST_VM:/opt/saha/ekip$EKIP/compose.yaml
printf 'IMG=%s\nTAG=1.0.1\nWEB_PORT=%s\n' "$IMG" "$WEB_PORT" | ssh $TEST_VM_USER@$TEST_VM "cat > /opt/saha/ekip$EKIP/.env"
```

```bash
VM=$TEST_VM_USER@$TEST_VM
vm() { ssh $VM "cd /opt/saha/ekip$EKIP && export DOCKER_CONFIG=/opt/saha/ekip$EKIP/.docker && $*"; }

vm "ls -a && cat .env"
vm docker compose -p ekip$EKIP pull
```

Arayüz: yalnızca read_registry yetkili ekip pull token’ını oluşturun; burada o token’ı girin.

```bash
read -rs TOKEN
echo "$TOKEN" | ssh $VM "mkdir -p /opt/saha/ekip$EKIP/.docker && DOCKER_CONFIG=/opt/saha/ekip$EKIP/.docker docker login $REGISTRY -u ekip$EKIP-pull --password-stdin"
unset TOKEN

vm docker compose -p ekip$EKIP pull
vm docker compose -p ekip$EKIP up -d
vm docker compose -p ekip$EKIP ps
```

### Adım 7 · `curl` ile smoke test; MR ile `develop`'a gönder

```bash
curl -fsS --retry 10 --retry-connrefused --retry-delay 2 $TEST_URL/api/products | head -c 60; echo
curl -fsS -o /dev/null -w '%{http_code}\n' -X POST $TEST_URL/api/orders \
  -H 'Content-Type: application/json' -d '{ "productId": "KBL-02", "quantity": 3 }'
curl -fsS $TEST_URL/api/orders; echo
```

Arayüz: Docker MR’ını develop’a merge edin; sonra yereli güncelleyin.

```bash
git switch develop && git pull
git fetch --prune
git branch -D feature/9-docker
```

## LAB 04-A · GitLab bağlantısı ve ilk pipeline

[Adımlar ve dosya düzenlemeleri](lab-rehberleri/ogrenci/LAB-04-A.md).

### Adım 4 · `Jenkinsfile`: Restore, Build, Unit Test, web-ui

Önce arayüzde Project Access Token, klasör credential’ları, Multibranch job ve Push events webhook’u kurulmuş olmalı (rehber Adım 1–3). Issue açın; aşağıdaki branch’te Jenkinsfile’ı yazın.

```bash
cd ~/saha-ekipman-portal
git switch develop && git pull
git switch -c feature/pipeline
```

```bash
git add Jenkinsfile
git commit -m "ci: add Jenkins pipeline"
git push -u origin feature/pipeline
```

### Adım 6 · "Pipelines must succeed" ayarını aç, bir testi boz

Arayüz: MR açın, Pipelines must succeed açın. Editör: boş productId testinde beklenen 400 yerine 200 yazın; bu blok kırmızı üretmeli.

```bash
dotnet test tests/order-service.tests        # lokalde de kırmızı olmalı
git commit -am "test(order): expect 200 for an empty product id"
git push
```

### Adım 7 · Merge'ün engellendiğini gör; düzelt ve merge et

Merge’ün engellendiğini görün. HEAD’in yalnızca bilerek bozduğunuz test commit’i olduğundan emin olun.

```bash
git revert --no-edit HEAD
dotnet test tests/order-service.tests
git push
```

Pipeline yeşil olduktan sonra MR’ı merge edin.

```bash
git switch develop && git pull
git fetch --prune
git branch -D feature/pipeline
```

## LAB 04-B · SonarQube, Quality Gate, imaj

[Adımlar ve dosya düzenlemeleri](lab-rehberleri/ogrenci/LAB-04-B.md).

### Adım 2 · begin → build → test → end adımlarını pipeline'a taşı

Önce SonarQube projesi/token’ı ve Jenkins sonar-token/gitlab-registry credential’larını kurun. Editör: analyze.sh ve Jenkinsfile’ı hazırlayın.

```bash
cd ~/saha-ekipman-portal
git switch develop && git pull
git switch -c feature/sonar
```

### Adım 3 · Quality Gate stage'ini ekle; yeşil pipeline'ı gör

```bash
chmod +x ci/analyze.sh
git add Jenkinsfile ci/analyze.sh
git commit -m "ci: add SonarQube analysis, Quality Gate and image publishing"
git push -u origin feature/sonar
```

MR’ı merge edip develop Quality Gate’in yeşil taban analizini bekleyin; sonra devam edin.

```bash
git switch develop && git pull && git fetch --prune && git branch -D feature/sonar
```

### Adım 4 · Testsiz yeni kodu al

```bash
git switch -c feature/siparis-ozeti
git fetch sablon
git checkout sablon/lab/04b-untested -- src/order-service
git status --short
dotnet test tests/order-service.tests          # var olan testler geçer
git commit -m "feat(order): add order summary endpoint"
git push -u origin feature/siparis-ozeti
```

### Adım 5 · Kalan kapıyı Jenkins'te ve SonarQube'da incele

Testsiz kod MR’ını merge edin. develop Quality Gate ERROR olmalı; imaj üretilmemeli.

```bash
git switch develop && git pull && git fetch --prune && git branch -D feature/siparis-ozeti
```

### Adım 6 · Eksik testleri yaz

```bash
git switch -c feature/siparis-ozeti-testleri
```

Editör: OrderSummaryTests.cs testlerini tamamlayın.

```bash
dotnet test tests/order-service.tests
git add tests/order-service.tests/OrderSummaryTests.cs
git commit -m "test(order): cover the order summary"
git push -u origin feature/siparis-ozeti-testleri
```

### Adım 7 · `develop`'a merge et; imajın registry'ye gittiğini doğrula

Test MR’ını merge edin; develop Quality Gate OK ve registry’de SHA imajlarını bekleyin.

```bash
git switch develop && git pull && git fetch --prune && git branch -D feature/siparis-ozeti-testleri
git rev-parse --short HEAD
```

## LAB 05-A · Ortak paket Nexus'ta

[Adımlar ve dosya düzenlemeleri](lab-rehberleri/ogrenci/LAB-05-A.md).

### Adım 1 · PackageId (ekip sonekiyle) ve Version

```bash
cd ~/saha-ekipman-portal
git switch develop && git pull
git switch -c feature/ortak-paket
```

### Adım 2 · `dotnet pack`; paketin içini incele

Editör: common-contracts.csproj içine PackageId=Saha.Common.Contracts.EkipNN (kendi ekibiniz), Version=1.0.0 yazın.

```bash
dotnet pack src/common-contracts -c Release -o out
ls out/
unzip -l out/Saha.Common.Contracts.Ekip$EKIP.1.0.0.nupkg
```

### Adım 3 · `1.0.0`'ı Nexus hosted depoya push et

Nexus arayüzünde kendi NuGet API anahtarınızı alın; aşağıda gizli girişe yapıştırın.

```bash
read -rs NEXUS_APIKEY        # anahtarı yapıştırın, Enter (ekranda görünmez)
dotnet nuget push out/Saha.Common.Contracts.Ekip$EKIP.1.0.0.nupkg \
  --source $NEXUS_URL/repository/nuget-hosted/ --api-key "$NEXUS_APIKEY"
```

Nexus arayüzü: Browse → nuget-hosted → paket klasörünün solundaki **+** → **1.0.0** satırı; Summary’de adı ve sürümü kontrol edin.

### Adım 4 · Aynı sürümü yeniden push etmeyi dene; hatayı oku

Bu ikinci yayın 409 ile reddedilmeli. Ana akışta sürümü değiştirmeyin.

```bash
dotnet nuget push out/Saha.Common.Contracts.Ekip$EKIP.1.0.0.nupkg \
  --source $NEXUS_URL/repository/nuget-hosted/ --api-key "$NEXUS_APIKEY"
unset NEXUS_APIKEY
```

### Adım 6 · Önbelleği temizle; restore'un Nexus'tan geldiğini gör

Editör: API projelerinde ProjectReference yerine ekibe özel 1.0.0 PackageReference; Dockerfile’lardan common-contracts kaynak COPY satırlarını kaldırın.

```bash
dotnet nuget locals all --clear
dotnet restore SahaPortal.sln -v n | grep -i -E 'saha\.common\.contracts|Installed' | head
dotnet build SahaPortal.sln -c Release --no-restore
dotnet test SahaPortal.sln -c Release --no-build
```

```bash
docker build -f src/order-service/Dockerfile --build-arg MCR=$MCR -t ekip$EKIP-yerel/order-service:paket .
docker rmi ekip$EKIP-yerel/order-service:paket
```

### Adım 7 · MR aç; Jenkins pipeline'ının yeşil olduğunu doğrula

```bash
git add src/common-contracts/common-contracts.csproj src/order-service src/product-service
git status --short        # out/ listede olmamalı
git commit -m "build(contracts): consume common contracts as a NuGet package"
git push -u origin feature/ortak-paket
```

Arayüz: MR merge; develop pipeline yeşil.

```bash
git switch develop && git pull && git fetch --prune && git branch -D feature/ortak-paket
```

## LAB 05-B · Final: uçtan uca teslimat

[Adımlar ve dosya düzenlemeleri](lab-rehberleri/ogrenci/LAB-05-B.md).

### Adım 1 · `Jenkinsfile`'a Deploy ve smoke test stage'lerini ekle

Jenkins için ayrı SSH anahtarı. Yeni özel anahtarı klasör kapsamlı test-vm-ssh credential’ına ekleyin; çıktısını kanıtlara kaydetmeyin.

```bash
ssh-keygen -t ed25519 -N "" -C "jenkins-ekip$EKIP" -f ~/.ssh/jenkins-test-vm
ssh-copy-id -i ~/.ssh/jenkins-test-vm.pub $TEST_VM_USER@$TEST_VM
ssh -o IdentitiesOnly=yes -i ~/.ssh/jenkins-test-vm $TEST_VM_USER@$TEST_VM hostname
```

```bash
cd ~/saha-ekipman-portal
git switch develop && git pull --ff-only
git switch -c feature/deploy
```

Editör: verilen deploy/deploy.sh ve final Jenkinsfile stage’lerini ekleyin. Sonra MR → develop; yeşil deploy ve smoke test bekleyin.

```bash
git add Jenkinsfile deploy/deploy.sh
git commit -m "ci: deploy to the test VM and run a smoke test"
git push -u origin feature/deploy
```

```bash
VM=$TEST_VM_USER@$TEST_VM
vm() { ssh $VM "cd /opt/saha/ekip$EKIP && export DOCKER_CONFIG=/opt/saha/ekip$EKIP/.docker && $*"; }
vm "cat .env; tail -n 1 deploy-kayit.log"
```

### Adım 2 · Issue aç; `feature/12-miktar-dogrulama`

Arayüz: miktar doğrulama issue’sunu açın; Sandbox: `rol dev`.

```bash
git switch develop && git pull
git switch -c feature/12-miktar-dogrulama
```

### Adım 3 · Validation ve unit testleri yaz; lokalde doğrula

Önce quantity 0/-1 için 400 testlerini yazın, kırmızı görün; sonra validation ekleyip yeşile dönün.

```bash
dotnet test tests/order-service.tests     # yeni 400 testleri KIRMIZI olmalı
```

Önce quantity 0/-1 için 400 testlerini yazın, kırmızı görün; sonra validation ekleyip yeşile dönün.

```bash
dotnet test tests/order-service.tests     # yeşil
```

Önce quantity 0/-1 için 400 testlerini yazın, kırmızı görün; sonra validation ekleyip yeşile dönün.

```bash
git add src/order-service tests/order-service.tests
git commit -m "fix(order): reject quantities below one"
git push -u origin feature/12-miktar-dogrulama
```

### Adım 5 · `develop`'a merge et; test VM'e otomatik deploy'u izle

Arayüz: MR review + yeşil pipeline → merge. develop Quality Gate ve deploy başarılı olunca çalıştırın (400 / 201).

```bash
git switch develop && git pull && git fetch --prune && git branch -D feature/12-miktar-dogrulama
vm "cat .env; tail -n 1 deploy-kayit.log"
curl -s -w ' HTTP %{http_code}\n' -X POST $TEST_URL/api/orders -H 'Content-Type: application/json' -d '{ "productId": "ADP-01", "quantity": 0 }'
curl -s -w ' HTTP %{http_code}\n' -X POST $TEST_URL/api/orders -H 'Content-Type: application/json' -d '{ "productId": "ADP-01", "quantity": 2 }'
```

### Adım 6 · `release/1.1.0` → `main`; `v1.1.0` tag'ini at

```bash
git switch develop && git pull
git switch -c release/1.1.0
# CHANGELOG.md: [Unreleased] altındakileri ## [1.1.0] - <tarih> başlığına taşıyın
git commit -am "chore(release): 1.1.0"
git push -u origin release/1.1.0
```

ÖNCE release → main MR’ını squash kapalı merge edin, main imajını bekleyin; release → develop MR’ını da squash kapalı merge edip develop deploy’unun bitmesini bekleyin. Jenkins: Discover tags + Regular branches + Tags; GitLab webhook: Tag push events. SONRA lider tag atsın.

```bash
rol lead
git fetch origin
git tag -a v1.1.0 -m "release: v1.1.0" origin/main
git push origin v1.1.0
```

### Adım 7 · `v1.1.0` imajını test ortamında smoke test ile doğrula

```bash
vm "cat .env; docker compose -p ekip$EKIP images"
vm "tail -n 2 deploy-kayit.log"
curl -s -w ' HTTP %{http_code}\n' -X POST $TEST_URL/api/orders -H 'Content-Type: application/json' -d '{ "productId": "ADP-01", "quantity": 0 }'
curl -s -w ' HTTP %{http_code}\n' -X POST $TEST_URL/api/orders -H 'Content-Type: application/json' -d '{ "productId": "ADP-01", "quantity": 2 }'
```

```bash
SHA=$(git rev-parse --short "v1.1.0^{commit}")
docker buildx imagetools inspect $IMG/order-service:1.1.0 --format '{{json .Manifest.Digest}}'
docker buildx imagetools inspect $IMG/order-service:$SHA  --format '{{json .Manifest.Digest}}'
```

### Adım 8 · Rollback provası: `1.0.1`'e dön, yeniden `1.1.0`'a çık

```bash
vm "docker compose -p ekip$EKIP images"
vm "sh deploy.sh $IMG 1.0.1 $WEB_PORT - elle"
vm "docker compose -p ekip$EKIP images"
curl -s -o /dev/null -w '%{http_code}\n' $TEST_URL/api/orders/summary     # 1.0.1 bu uç noktayı bilmez: 404
```

Jenkins: v1.1.0 job’ında Build Now ile tekrar ileri alın; build yeşil olunca kayıt 1.1.0 → 1.0.1 → 1.1.0 göstermeli.

```bash
vm "tail -n 3 deploy-kayit.log"
```

## Pipeline komutları · Jenkins agent referansı

Jenkinsfile `environment` içinde `DOCKER_CONFIG = "${WORKSPACE}@tmp/docker-config"`; en dış `post` içinde `always { sh 'rm -f "$DOCKER_CONFIG/config.json"' }` olmalı. Böylece ortak agent’ta ekiplerin Docker girişleri karışmaz.

Bu komutları LAB 04-A/04-B/05-B’de Jenkinsfile stage’leri çalıştırır; credential ve sunucu değişkenleri Jenkins tarafından sağlanır.

```bash
# LAB 04-A: build, test raporları ve web-ui
dotnet restore SahaPortal.sln
dotnet build SahaPortal.sln -c Release --no-restore
dotnet test SahaPortal.sln -c Release --no-build --logger "junit;LogFileName=junit.xml"
(cd src/web-ui && npm ci && npm test -- --coverage --ci && npm run build)

# LAB 04-B: withSonarQubeEnv içinde ci/analyze.sh'nin sırası
dotnet sonarscanner begin /k:"$SONAR_PROJECT_KEY" /d:sonar.cs.opencover.reportsPaths="**/coverage.opencover.xml"
dotnet build SahaPortal.sln -c Release --no-restore
dotnet test SahaPortal.sln -c Release --no-build --logger "junit;LogFileName=junit.xml" \
  --collect:"XPlat Code Coverage" -- DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Format=opencover
dotnet sonarscanner end
# Ardından Jenkins waitForQualityGate; yalnızca başarılıysa Docker Build & Push.

# LAB 05-B: her iki smoke isteği de hazır olmayı bekler.
curl -fsS --retry 10 --retry-connrefused --retry-delay 3 "$TEST_URL/api/products" | grep -q '"code"'
curl -fsS --retry 10 --retry-connrefused --retry-delay 3 -o /dev/null "$TEST_URL/api/orders"
```

## Eğitmen · doğrulama ve kurtarma

Host üzerinde `lab-ortami/` dizininde. Checkpoint ilgili ekibin mevcut lab durumunu değiştirir; öğrencinin çalışmasını önce değerlendirin.

```bash
/usr/bin/make durum
/usr/bin/make dogrula
/usr/bin/make dogrula-ci
/usr/bin/make onkontrol EKIP=01
/usr/bin/make dogrula-lab LAB=01-a EKIP=01   # LAB=01-b, 02-a, ... 05-b
/usr/bin/make checkpoint EKIP=01 LAB=lab-01a
# Diğer bitiş checkpoint'leri: gun1, lab-02a, lab-02b, lab-03a, lab-03b,
# lab-04a, lab-04b, lab-05a, final
/usr/bin/make rol-degistir EKIP=01
/usr/bin/make rol-degistir EKIP=01 ASIL=1
```

Bonus paket yayını ana akıştan ayrıdır. `1.0.0` API referanslarını ana labda koruyun; yalnızca bonus dalında paket sürümünü artırın:

```bash
# common-contracts.csproj Version=1.0.1 yapıldıktan sonra:
dotnet pack src/common-contracts -c Release -o out
read -rs NEXUS_APIKEY
dotnet nuget push out/Saha.Common.Contracts.Ekip$EKIP.1.0.1.nupkg \
  --source "$NEXUS_URL/repository/nuget-hosted/" --api-key "$NEXUS_APIKEY"
unset NEXUS_APIKEY
```

`Pack & Publish` stage'i ve GitLab Package Registry demosu: [eğitmen çözümü](lab-rehberleri/egitmen/LAB-05-A-cozum.md). Stage final Jenkinsfile’a varsayılan olarak eklenmez.
