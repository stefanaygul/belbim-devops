#!/usr/bin/env bash
# Katilimci makinesi on kontrolu: Gun 1-3 lablari icin gerekenler hazir mi?
# Katilimci makinesinde, katilimci kullanicisiyla calisir. Hicbir seyi degistirmez
# (yalnizca gecici bir deneme imaji derler ve siler).
#
# Iki modda da aynidir; fark lab.env dosyasidir:
#   sandbox     : dogrula/lab.sh workstation-onkontrol 01
#   integration : source /etc/lab/lab.env; source dogrula/lib.sh; source dogrula/workstation-onkontrol.sh
set -uo pipefail

bilgi() { printf '  BILGI  %s\n' "$*"; }
surum_ile() {  # surum_ile <aciklama> <beklenen-onek> <gelen>
  case "$3" in "$2"*) gecti "$1: $3" ;; *) kaldi "$1: beklenen $2*, gelen '${3:-yok}'" ;; esac
}

baslik "Ortam dosyasi (lab.env)"
for d in GITLAB_URL GITLAB_HOST REGISTRY NEXUS_URL TEST_VM TEST_VM_USER GITLAB_GROUP TEMPLATE_PROJECT MCR HUB NUGET_GROUP_URL NPM_GROUP_URL CA_CERT; do
  if [ -n "${!d:-}" ]; then gecti "$d=${!d}"; else kaldi "$d tanimli degil"; fi
done
[ -f "${CA_CERT:-/yok}" ] && gecti "kurum CA dosyasi var: $CA_CERT" || kaldi "kurum CA dosyasi yok: ${CA_CERT:-}"

baslik "Araclar"
surum_ile ".NET SDK" "10.0." "$(dotnet --version 2>/dev/null)"
surum_ile "Node.js" "v24." "$(node --version 2>/dev/null)"
for a in git npm curl jq ssh scp; do
  command -v "$a" >/dev/null 2>&1 && gecti "$a var" || kaldi "$a yok"
done

baslik "Kurum CA'si: isletim sistemi (git, curl, dotnet, npm)"
esit "GitLab'e HTTPS (dogrulama acik)" "200" "$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "$GITLAB_URL/users/sign_in" 2>&1)"
esit "NuGet group deposu" "200" "$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "$NUGET_GROUP_URL" 2>&1)"
esit "npm group deposu" "200" "$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "${NPM_GROUP_URL}react" 2>&1)"
if git ls-remote --heads "$GITLAB_URL/$TEMPLATE_PROJECT.git" main >/dev/null 2>&1; then
  gecti "sablon proje okunuyor: $TEMPLATE_PROJECT"
else
  kaldi "sablon proje okunamiyor: $GITLAB_URL/$TEMPLATE_PROJECT.git"
fi

baslik "Docker"
if docker info >/dev/null 2>&1; then
  gecti "Docker daemon'ina sudo olmadan erisiliyor (Engine $(docker version --format '{{.Server.Version}}' 2>/dev/null))"
else
  kaldi "Docker daemon'ina erisilemiyor (kullanici docker grubunda mi?)"; ozet; exit 1
fi
docker compose version >/dev/null 2>&1 && gecti "docker compose: $(docker compose version --short 2>/dev/null)" || kaldi "docker compose eklentisi yok"
surucu="$(docker buildx inspect 2>/dev/null | sed -n 's/^Driver: *//p' | head -n 1)"
if [ "$surucu" = "docker" ]; then
  gecti "varsayilan builder surucusu: docker (yerel imajlari kullanir)"
else
  kaldi "varsayilan builder surucusu '$surucu': yerel temel imajlari gormez. Cozum: docker buildx use default"
fi
[ "${DOCKER_BUILDKIT:-1}" = "0" ] && bilgi "DOCKER_BUILDKIT=0 tanimli: eski builder kullanilir"

baslik "Temel imajlar (LAB 03-A): makinede hazir mi?"
EKSIK=0
for imaj in "$MCR/dotnet/sdk:10.0" "$MCR/dotnet/aspnet:10.0" "$HUB/library/node:24-alpine" "$HUB/nginxinc/nginx-unprivileged:stable-alpine"; do
  if kimlik="$(docker image inspect --format '{{.Id}} {{index .Config.Labels "lab.kaynak"}}' "$imaj" 2>/dev/null)"; then
    gecti "$imaj"
    printf '         kimlik %s  kaynak %s\n' "$(printf '%s' "${kimlik%% *}" | cut -c8-19)" "${kimlik#* }"
  else
    kaldi "$imaj makinede yok. Yukleme: docker load -i <imaj>.tar (bkz. lab-ortami/README.md)"
    EKSIK=1
  fi
done

if [ "$EKSIK" -eq 0 ]; then
  baslik "Temel imajlarin ici: kurum CA'si ve Nexus erisimi (docker build icindeki restore / npm ci)"
  esit "SDK imajindan NuGet group deposu" "200" \
    "$(docker run --rm "$MCR/dotnet/sdk:10.0" curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "$NUGET_GROUP_URL" 2>&1 | tail -n 1)"
  esit "Node imajindan npm group deposu" "200" \
    "$(docker run --rm "$HUB/library/node:24-alpine" node -e 'fetch(process.argv[1]).then(r => console.log(r.status)).catch(e => console.log(e.cause ? e.cause.code : e.message))' "${NPM_GROUP_URL}react" 2>&1 | tail -n 1)"

  baslik "Deneme build'i: registry'ye baglanmadan"
  cikti="$(printf 'ARG MCR\nARG HUB\nFROM ${MCR}/dotnet/sdk:10.0 AS a\nFROM ${HUB}/library/node:24-alpine AS b\nFROM ${HUB}/nginxinc/nginx-unprivileged:stable-alpine AS c\nFROM ${MCR}/dotnet/aspnet:10.0\nCOPY --from=a /etc/hostname /tmp/a\nCOPY --from=b /etc/hostname /tmp/b\nCOPY --from=c /etc/hostname /tmp/c\n' \
    | docker build --progress=plain --build-arg "MCR=$MCR" --build-arg "HUB=$HUB" -t lab-onkontrol:deneme - 2>&1)"; kod=$?
  esit "docker build (dort temel imaj, cikis kodu)" "0" "$kod"
  [ "$kod" -eq 0 ] || printf '%s\n' "$cikti" | grep -E 'ERROR|x509' | head -n 3 | cut -c1-240 | sed 's/^/         /'
  docker rmi -f lab-onkontrol:deneme >/dev/null 2>&1
fi

baslik "Docker daemon'i registry'ye guveniyor mu? (LAB 03-B)"
# Var olmayan bir imaj istenir: hicbir sey indirilmez, yalnizca hata metnine bakilir.
cikti="$(docker pull "$REGISTRY/$GITLAB_GROUP/base/onkontrol-yok:0" 2>&1)"
case "$cikti" in
  *"x509: certificate signed by unknown authority"*)
    bilgi "guvenmiyor: LAB 03-B'de 'docker login' x509 hatasi verir ve katilimci CA'yi certs.d altina ekler (beklenen akis)"
    [ "$EKSIK" -eq 0 ] || kaldi "temel imajlar makinede yok VE daemon registry'ye guvenmiyor: LAB 03-A'nin ilk build'i x509 ile durur"
    ;;
  *"not found"*|*"manifest unknown"*|*"denied"*|*"unauthorized"*)
    bilgi "guveniyor: LAB 03-B'deki x509 adimi yasanmaz; rehberde 'zaten yapilmis' diye gecilir"
    ;;
  *) bilgi "registry yaniti siniflandirilamadi: $(printf '%s' "$cikti" | tail -n 1 | cut -c1-200)" ;;
esac
grep -qs 'insecure-registries' /etc/docker/daemon.json && kaldi "daemon.json icinde insecure-registries var (TLS dogrulamasi kapali)" \
  || gecti "daemon.json icinde insecure-registries yok"

ozet
