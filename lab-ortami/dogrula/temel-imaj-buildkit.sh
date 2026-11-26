#!/usr/bin/env bash
# Onceden yuklenen temel imajlarla LAB 03-A build komutlarinin registry'ye baglanmadan
# calistigini dener. Katilimci makinesinde, ekip kullanicisiyla calisir (lab.env yuklu).
# dogrula/lib.sh ile birlikte standart giristen verilir (bkz. dogrula/lab.sh).
#
# Kaynak: sablon projedeki checkpoint/lab-03a (LAB 03-A'nin tamamlanmis Dockerfile'lari).
# Yan etkisi: build onbellegi dolar; etiketledigi imajlari sonunda siler.
# DIS_ERISIM=1 verilirse Docker Hub'a erisim gerektiren iki olumsuz senaryo da kosar
# (docker-container builder ve "# syntax=" satiri); kapali agda bunlar calistirilmaz.
set -uo pipefail

CALISMA="$(mktemp -d)"
ETIKET="lab-dogrula-bk"
temizle() {
  docker rmi -f "$ETIKET/order-service:dev" "$ETIKET/product-service:dev" "$ETIKET/web-ui:dev" >/dev/null 2>&1
  rm -rf "$CALISMA"
}
trap temizle EXIT

baslik "On kosullar"
esit "varsayilan builder surucusu" "docker" "$(docker buildx inspect 2>/dev/null | sed -n 's/^Driver: *//p' | head -n 1)"
for imaj in "$MCR/dotnet/sdk:10.0" "$MCR/dotnet/aspnet:10.0" "$HUB/library/node:24-alpine" "$HUB/nginxinc/nginx-unprivileged:stable-alpine"; do
  if docker image inspect "$imaj" >/dev/null 2>&1; then gecti "yuklu: $imaj"; else kaldi "yuklu degil: $imaj"; fi
done
cikti="$(docker pull "$MCR/dotnet/aspnet:10.0" 2>&1)"
if [ -e "/etc/docker/certs.d/$REGISTRY/ca.crt" ]; then
  printf '  BILGI  daemon registry'"'"'ye guveniyor (certs.d var); "registry'"'"'siz build" senaryolari bu makinede ayirt edilemez\n'
  GUVEN=1
else
  icerir "daemon registry'ye guvenmiyor: docker pull -> x509" "x509: certificate signed by unknown authority" "$cikti"
  GUVEN=0
fi

git clone --quiet --branch checkpoint/lab-03a "$GITLAB_URL/$TEMPLATE_PROJECT.git" "$CALISMA/repo" || { kaldi "klonlama"; ozet; exit 1; }
cd "$CALISMA/repo"

baslik "S1. LAB 03-A komutlari, varsayilan builder (ilk build)"
build() {  # build <servis> <arg> [ek secenekler...]
  local servis="$1" arg="$2"; shift 2
  docker build --progress=plain -f "src/$servis/Dockerfile" --build-arg "$arg" "$@" -t "$ETIKET/$servis:dev" . 2>&1
}
for satir in "order-service MCR=$MCR" "product-service MCR=$MCR" "web-ui HUB=$HUB"; do
  set -- $satir
  bas=$(date +%s)
  cikti="$(build "$1" "$2")"; kod=$?
  esit "docker build $1 (cikis kodu, $(( $(date +%s) - bas )) sn)" "0" "$kod"
  [ "$kod" -eq 0 ] || printf '%s\n' "$cikti" | tail -n 15
  printf '%s\n' "$cikti" | grep -E 'load metadata for|resolve image config' | sed 's/^/         /' | sort -u
  case "$cikti" in *x509*) kaldi "$1: build ciktisinda x509 geciyor" ;; *) gecti "$1: build ciktisinda x509 yok" ;; esac
done

baslik "S1b. Ikinci build: restore ve npm ci onbellekten"
echo "// cache test $(date +%s)" >> src/order-service/Program.cs
cikti="$(build order-service "MCR=$MCR")"
icerir "order-service: kaynak degisti, restore CACHED" "CACHED" "$(printf '%s\n' "$cikti" | grep -A1 'RUN dotnet restore' | head -n 4)"
echo "/* cache test $(date +%s) */" >> src/web-ui/src/styles.css
cikti="$(build web-ui "HUB=$HUB")"
icerir "web-ui: kaynak degisti, npm ci CACHED" "CACHED" "$(printf '%s\n' "$cikti" | grep -A1 'RUN npm ci' | head -n 4)"

baslik "S2. --pull: registry'ye gitmeye zorlar"
cikti="$(build order-service "MCR=$MCR" --pull)"; kod=$?
if [ "$GUVEN" -eq 0 ]; then
  esit "docker build --pull (cikis kodu; basarisiz olmali)" "1" "$kod"
  icerir "--pull hatasi x509" "x509: certificate signed by unknown authority" "$cikti"
else
  esit "docker build --pull (daemon guveniyor)" "0" "$kod"
fi

baslik "S4. Eski builder (DOCKER_BUILDKIT=0)"
cikti="$(DOCKER_BUILDKIT=0 docker build -f src/product-service/Dockerfile --build-arg "MCR=$MCR" -t "$ETIKET/product-service:dev" . 2>&1)"; kod=$?
printf '  BILGI  cikis kodu %s; son satir: %s\n' "$kod" "$(printf '%s\n' "$cikti" | tail -n 1 | cut -c1-200)"

if [ "${DIS_ERISIM:-0}" = "1" ]; then
  baslik "S3. docker-container builder (yerel imajlari gormez)"
  if docker buildx create --name lab-dogrula-dc --driver docker-container --driver-opt "image=moby/buildkit:v0.35.0" >/dev/null 2>&1; then
    cikti="$(docker buildx build --builder lab-dogrula-dc --progress=plain -f src/product-service/Dockerfile --build-arg "MCR=$MCR" -t "$ETIKET/product-service:dc" . 2>&1)"; kod=$?
    if [ "$GUVEN" -eq 0 ]; then
      esit "docker-container builder ile build (basarisiz olmali)" "1" "$kod"
    fi
    printf '%s\n' "$cikti" | grep -E 'ERROR|x509' | head -n 3 | cut -c1-260 | sed 's/^/         /'
    docker buildx rm lab-dogrula-dc >/dev/null 2>&1
    docker rmi -f moby/buildkit:v0.35.0 >/dev/null 2>&1
  else
    printf '  BILGI  docker-container builder olusturulamadi\n'
  fi

  baslik "S5. Dockerfile'da '# syntax=' satiri (frontend imaji Docker Hub'dan istenir)"
  { printf '# syntax=docker/dockerfile:1\n'; cat src/product-service/Dockerfile; } > "$CALISMA/Dockerfile.syntax"
  cikti="$(docker build --progress=plain -f "$CALISMA/Dockerfile.syntax" --build-arg "MCR=$MCR" -t "$ETIKET/product-service:dev" . 2>&1)"; kod=$?
  printf '  BILGI  cikis kodu %s\n' "$kod"
  printf '%s\n' "$cikti" | grep -E 'docker.io/docker/dockerfile' | head -n 3 | cut -c1-200 | sed 's/^/         /'
fi

ozet
