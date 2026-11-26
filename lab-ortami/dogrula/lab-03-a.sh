# LAB 03-A dogrulamasi: uc servis icin Dockerfile.
# Basari kriteri: uc imaj lokalde build oluyor ve root olmayan kullaniciyla calisiyor;
# ikinci build'de restore ve npm ci adimlari cache'ten geliyor.
# Denetim, calisma kopyasindaki HEAD uzerinden yapilir. Gecici imaj ve container'lari siler.
baslik "LAB 03-A (ekip-$EKIP)"
[ -d "$REPO/.git" ] || { kaldi "repo yok: $REPO"; ozet; return 1; }
cd "$REPO"
gecti "repo: $(git rev-parse --abbrev-ref HEAD)@$(git rev-parse --short HEAD)"
ETIKET="lab-dogrula-$EKIP"
_imaj_temizle() {
  docker rm -f "$ETIKET-product" "$ETIKET-order" "$ETIKET-web" >/dev/null 2>&1
  docker rmi -f "$ETIKET/order-service:t" "$ETIKET/product-service:t" "$ETIKET/web-ui:t" >/dev/null 2>&1
}
trap '_imaj_temizle; _temizle' EXIT

baslik "Dosyalar ve kurallar"
for f in src/order-service/Dockerfile src/product-service/Dockerfile src/web-ui/Dockerfile .dockerignore; do
  [ -f "$f" ] && gecti "$f var" || kaldi "$f yok"
done
for s in order-service product-service; do
  f="src/$s/Dockerfile"; [ -f "$f" ] || continue
  icerik="$(cat "$f")"
  icerir "$s: ARG MCR" "ARG MCR=" "$icerik"
  icerir "$s: temel imajlar \${MCR} uzerinden" 'FROM ${MCR}/dotnet/aspnet:10.0' "$icerik"
  icerir "$s: multi-stage (SDK ile build)" 'FROM ${MCR}/dotnet/sdk:10.0 AS' "$icerik"
  icerir "$s: COPY NuGet.config" "COPY NuGet.config" "$icerik"
  icerir "$s: USER \$APP_UID" 'USER $APP_UID' "$icerik"
done
if [ -f src/web-ui/Dockerfile ]; then
  icerik="$(cat src/web-ui/Dockerfile)"
  icerir "web-ui: ARG HUB" "ARG HUB=" "$icerik"
  icerir "web-ui: Node ile build" 'FROM ${HUB}/library/node:24-alpine AS' "$icerik"
  icerir "web-ui: nginx-unprivileged" 'FROM ${HUB}/nginxinc/nginx-unprivileged:' "$icerik"
  icerir "web-ui: .npmrc kopyalaniyor (npm ci Nexus'tan)" ".npmrc" "$icerik"
fi
if grep -R -n -E '^FROM .*:latest|^# *syntax=' src/*/Dockerfile >/dev/null 2>&1; then
  kaldi "Dockerfile'larda :latest ya da '# syntax=' satiri var"
else
  gecti "Dockerfile'larda :latest ve '# syntax=' yok"
fi
if [ -f .dockerignore ]; then
  for desen in node_modules bin obj .git; do
    grep -q -E "(^|/)${desen//./\\.}/?\$" .dockerignore && gecti ".dockerignore: $desen" || kaldi ".dockerignore icinde $desen yok"
  done
fi

baslik "Build (context: repo koku)"
build() { docker build --progress=plain -f "src/$1/Dockerfile" --build-arg "$2" -t "$ETIKET/$1:t" . 2>&1; }
for satir in "order-service MCR=$MCR" "product-service MCR=$MCR" "web-ui HUB=$HUB"; do
  set -- $satir
  cikti="$(build "$1" "$2")"; kod=$?
  esit "docker build $1 (cikis kodu)" "0" "$kod"
  [ "$kod" -eq 0 ] || printf '%s\n' "$cikti" | grep -E 'ERROR|error' | head -n 4 | cut -c1-220
done

baslik "Ikinci build: onbellek"
cikti="$(build order-service "MCR=$MCR")"
icerir "order-service: restore CACHED" "CACHED" "$(printf '%s\n' "$cikti" | grep -B0 -A1 'RUN dotnet restore' | head -n 4)"
cikti="$(build web-ui "HUB=$HUB")"
icerir "web-ui: npm ci CACHED" "CACHED" "$(printf '%s\n' "$cikti" | grep -B0 -A1 'RUN npm ci' | head -n 4)"

baslik "Imajlar root olmayan kullaniciyla calisiyor"
p=$((15300 + 10#$EKIP * 3))
kosu() {  # kosu <ad> <servis> <port> <saglik-yolu> [docker run secenekleri...]
  local ad="$1" servis="$2" port="$3" yol="$4"; shift 4
  docker run -d --name "$ETIKET-$ad" -p "127.0.0.1:$port:8080" "$@" "$ETIKET/$servis:t" >/dev/null 2>&1 || { kaldi "$servis baslatilamadi"; return 1; }
  if http_bekle "http://127.0.0.1:$port$yol" 30; then
    gecti "$servis: $yol -> 200"
  else
    kaldi "$servis: $yol yanit vermiyor"; docker logs "$ETIKET-$ad" 2>&1 | tail -n 4
  fi
  uid="$(docker exec "$ETIKET-$ad" id -u 2>/dev/null)"
  if [ -n "$uid" ] && [ "$uid" != "0" ]; then gecti "$servis: surec kullanicisi uid=$uid (root degil)"; else kaldi "$servis: surec root olarak calisiyor (uid=${uid:-?})"; fi
}
kosu product product-service "$p" /health
esit "product-service /health" "Healthy" "$(curl -s "http://127.0.0.1:$p/health")"
kosu order order-service "$((p + 1))" /health -e "ConnectionStrings__Orders=Data Source=/tmp/orders.db"
# LAB 03-B'den sonra nginx.conf /api isteklerini servis adlarina yonlendirir; Nginx bu adlari
# acilista cozemezse baslamaz. Imaj tek basina denenirken adlar bos bir adrese cozdurulur.
if grep -q 'proxy_pass' deploy/nginx.conf 2>/dev/null; then
  bilgi "nginx.conf /api kurallarini iceriyor (LAB 03-B yapilmis): web-ui servis adlari --add-host ile cozdurulerek deneniyor"
  kosu web web-ui "$((p + 2))" / --add-host product-service:127.0.0.1 --add-host order-service:127.0.0.1
else
  kosu web web-ui "$((p + 2))" /
fi
bilgi "boyutlar: $(docker images --format '{{.Repository}} {{.Size}}' | grep "^$ETIKET/" | sed "s#^$ETIKET/##" | tr '\n' ';')"

ozet
