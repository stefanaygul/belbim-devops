# checkpoint-uygula.sh ve sifirla-ekip.sh'in test VM tarafi. deploy kullanicisiyla calisir.
# Ortam: NN, MOD (kur|kaldir); kur icin IMG, WEB_PORT, REGISTRY, PULL_TOKEN ve
# standart giristen "COMPOSE_BASLANGIC" satirindan sonra compose.yaml icerigi.
# Yalnizca /opt/saha/ekipNN dizinine ve ekipNN Compose projesine dokunur.
set -euo pipefail
DIZIN="/opt/saha/ekip${NN}"
PROJE="ekip${NN}"
tamam() { printf '    \033[32mtamam\033[0m  %s\n' "$*"; }
cd "$DIZIN"
export DOCKER_CONFIG="$DIZIN/.docker"
# Deploy kaydi ve betigi (LAB 05-B) checkpoint durumuna ait degildir; final'de Jenkins yeniden yazar.
rm -f deploy-kayit.log deploy.sh

if [ -n "$(docker ps -aq --filter "label=com.docker.compose.project=$PROJE")" ] \
   || docker volume ls -q --filter "label=com.docker.compose.project=$PROJE" | grep -q .; then
  docker compose -p "$PROJE" down --volumes --remove-orphans >/dev/null 2>&1
  tamam "test VM: $PROJE projesi ve verisi kaldirildi"
fi

if [ "$MOD" = "kaldir" ]; then
  if [ "${TEMIZLE:-0}" = "1" ]; then
    sed -i "/ jenkins-ekip${NN}\$/d" ~/.ssh/authorized_keys
    tamam "test VM: Jenkins'in ekip anahtari (jenkins-ekip${NN}) kaldirildi"
    imajlar="$(docker images --format '{{.Repository}}:{{.Tag}}' | grep "/ekip-${NN}/saha-ekipman-portal/" || true)"
    [ -z "$imajlar" ] || docker rmi -f $imajlar >/dev/null 2>&1 || true
    find "$DIZIN" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
    tamam "test VM: $DIZIN bosaltildi, ekibin imajlari silindi"
  fi
  exit 0
fi

cat > compose.yaml
( umask 077; printf 'IMG=%s\nTAG=1.0.1\nWEB_PORT=%s\n' "$IMG" "$WEB_PORT" > .env )
printf '%s' "$PULL_TOKEN" | docker login "$REGISTRY" -u "ekip${NN}-pull" --password-stdin >/dev/null 2>&1
docker compose -p "$PROJE" pull --quiet >/dev/null 2>&1
docker compose -p "$PROJE" up -d >/dev/null 2>&1
for _ in $(seq 1 30); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${WEB_PORT}/api/products")" = "200" ] && break
  sleep 1
done
[ "$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${WEB_PORT}/api/orders")" = "200" ] || { echo "HATA: uygulama yanit vermiyor" >&2; docker compose -p "$PROJE" ps -a >&2; exit 1; }
curl -fsS -o /dev/null -X POST "http://localhost:${WEB_PORT}/api/orders" -H 'Content-Type: application/json' -d '{ "productId": "ADP-01", "quantity": 2 }'
tamam "test VM: $PROJE calisiyor (TAG=1.0.1, port ${WEB_PORT}), ornek talep kaydedildi"
