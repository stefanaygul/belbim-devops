# LAB 03-A cozumu: uc servis icin Dockerfile. Adimlar ogrenci rehberiyle aynidir.
adim="${ADIM:?ADIM gerekli}"
cd "$REPO"
# Context'in tamamini gecici bir build asamasina kopyalar ve boyutunu yazar (imaj uretmez).
OLCUM="printf 'FROM %s\nCOPY . /ctx\nRUN du -sh /ctx\n' \"\$HUB/library/node:24-alpine\" | docker build --no-cache --progress=plain -f - . 2>&1 | grep -E '[0-9.]+[KMG]?[[:space:]]+/ctx\$'"

case "$adim" in
feature)
  baslik "Adim 1: feature/9-docker"
  rol dev
  kos git switch develop
  kos git pull --ff-only
  kos git switch -c feature/9-docker
  ;;

order)
  baslik "Adim 2: order-service icin multi-stage Dockerfile"
  rol dev
  cozumden lab-03a src/order-service/Dockerfile
  kabuk "cat src/order-service/Dockerfile"
  kos docker build -q -f src/order-service/Dockerfile --build-arg "MCR=$MCR" -t order-service:dev .
  kos git add src/order-service/Dockerfile
  kos git commit -m "build(order): add multi-stage Dockerfile"
  ;;

product)
  baslik "Adim 3: ayni kalip product-service icin"
  rol dev
  cozumden lab-03a src/product-service/Dockerfile
  kabuk "diff src/order-service/Dockerfile src/product-service/Dockerfile || true"
  kos git add src/product-service/Dockerfile
  kos git commit -m "build(product): add multi-stage Dockerfile"
  ;;

web-ui)
  baslik "Adim 4: web-ui icin Node + Nginx Dockerfile"
  rol dev
  cozumden lab-03a src/web-ui/Dockerfile deploy/nginx.conf
  kabuk "cat src/web-ui/Dockerfile"
  kabuk "cat deploy/nginx.conf"
  kos git add src/web-ui/Dockerfile deploy/nginx.conf
  kos git commit -m "build(web-ui): add Node and Nginx Dockerfile"
  ;;

dockerignore)
  baslik "Adim 5: .dockerignore, context boyutu"
  rol dev
  kabuk "du -sh .git src/web-ui/node_modules 2>/dev/null"
  not_ "Build context'e ne giriyor? Gecici bir imajda olculur."
  kabuk "$OLCUM"
  cozumden lab-03a .dockerignore
  kabuk "cat .dockerignore"
  kabuk "$OLCUM"
  kos git add .dockerignore
  kos git commit -m "build: add .dockerignore"
  ;;

build)
  baslik "Adim 6: uc imaji build et, boyutlara bak"
  rol dev
  kos docker build -q -f src/order-service/Dockerfile --build-arg "MCR=$MCR" -t order-service:dev .
  kos docker build -q -f src/product-service/Dockerfile --build-arg "MCR=$MCR" -t product-service:dev .
  kos docker build -q -f src/web-ui/Dockerfile --build-arg "HUB=$HUB" -t web-ui:dev .
  kabuk "docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' | grep -E 'REPOSITORY|^(order-service|product-service|web-ui) |dotnet/sdk|dotnet/aspnet|library/node|nginx-unprivileged'"
  not_ "Ikinci build: kaynak kod degisti, restore ve npm ci onbellekten gelmeli"
  echo "// cache demo" >> src/order-service/Program.cs
  kabuk "docker build --progress=plain -f src/order-service/Dockerfile --build-arg MCR=\$MCR -t order-service:dev . 2>&1 | grep -E 'CACHED|RUN dotnet (restore|publish)' | sed 's/^#[0-9]* //' | sort -u"
  kos git checkout src/order-service/Program.cs
  echo "/* cache demo */" >> src/web-ui/src/styles.css
  kabuk "docker build --progress=plain -f src/web-ui/Dockerfile --build-arg HUB=\$HUB -t web-ui:dev . 2>&1 | grep -E 'CACHED|RUN npm (ci|run build)' | sed 's/^#[0-9]* //' | sort -u"
  kos git checkout src/web-ui/src/styles.css
  not_ "Kaynak eski haline dondu; imajlari yeniden uret"
  kos docker build -q -f src/order-service/Dockerfile --build-arg "MCR=$MCR" -t order-service:dev .
  kos docker build -q -f src/web-ui/Dockerfile --build-arg "HUB=$HUB" -t web-ui:dev .
  ;;

calistir)
  baslik "Adim 7: tek tek calistir, /health ve loglar"
  kos docker run -d --name product -p 8080:8080 product-service:dev
  http_bekle http://localhost:8080/health 30
  kabuk "curl -s http://localhost:8080/health; echo"
  kabuk "curl -s http://localhost:8080/api/products | head -c 70; echo"
  kos docker exec product whoami
  kabuk "docker logs product 2>&1 | tail -n 4"
  kos docker rm -f product

  not_ "order-service SQLite dosyasina yazar; simdilik /tmp (kalici veri LAB 03-B'nin konusu)"
  kos docker run -d --name order -p 8080:8080 -e "ConnectionStrings__Orders=Data Source=/tmp/orders.db" order-service:dev
  http_bekle http://localhost:8080/health 30
  kabuk "curl -s http://localhost:8080/health; echo"
  kabuk "curl -s -o /dev/null -w '%{http_code}\n' -X POST http://localhost:8080/api/orders -H 'Content-Type: application/json' -d '{ \"productId\": \"ADP-01\", \"quantity\": 2 }'"
  kos docker exec order whoami
  kos docker rm -f order

  kos docker run -d --name web -p 8080:8080 web-ui:dev
  http_bekle http://localhost:8080/ 30
  kabuk "curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/"
  kos docker exec web id -u
  kabuk "docker inspect --format '{{.Config.User}}' product-service:dev order-service:dev web-ui:dev"
  ;;

kapat)
  kos docker rm -f web
  rol dev
  kos git status --short
  kos git push -u origin feature/9-docker
  baslik "Checkpoint karsilastirmasi"
  agac_ayni HEAD lab-03a .gitlab/CODEOWNERS
  ;;
*) echo "bilinmeyen adim: $adim" >&2; exit 2 ;;
esac
