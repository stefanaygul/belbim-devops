# LAB 03-B cozumu: registry, Compose ve ikinci VM. Adimlar ogrenci rehberiyle aynidir.
# Token'lar ortamdan gelir (DEPLOY_TOKEN, PULL_TOKEN); komut satirina yazilmaz.
adim="${ADIM:?ADIM gerekli}"
cd "$REPO"
VM="$TEST_VM_USER@$TEST_VM"
VM_DIZIN="/opt/saha/ekip$EKIP"
# Test VM paylasilir: her ekip registry girisini kendi dizininde tutar.
vm() { printf '$ ssh %s "%s"\n' "$VM" "$1"; ssh -n "$VM" "cd $VM_DIZIN && export DOCKER_CONFIG=$VM_DIZIN/.docker && $1"; }
uc_imaj() {  # uc_imaj <sha>: uc imaji 1.0.1 ve commit SHA ile etiketleyerek build eder
  kos docker build -q -f src/order-service/Dockerfile --build-arg "MCR=$MCR" -t "$IMG/order-service:1.0.1" -t "$IMG/order-service:$1" .
  kos docker build -q -f src/product-service/Dockerfile --build-arg "MCR=$MCR" -t "$IMG/product-service:1.0.1" -t "$IMG/product-service:$1" .
  kos docker build -q -f src/web-ui/Dockerfile --build-arg "HUB=$HUB" -t "$IMG/web-ui:1.0.1" -t "$IMG/web-ui:$1" .
}

case "$adim" in
etiketle)
  baslik "Adim 1: uc imaji 1.0.1 ve commit SHA ile etiketle"
  rol dev
  kos git switch feature/9-docker
  kabuk "echo \$IMG"
  SHA="$(git rev-parse --short HEAD)"
  printf '$ SHA=$(git rev-parse --short HEAD)   # %s\n' "$SHA"
  uc_imaj "$SHA"
  kabuk "docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.ID}}' | grep -E 'REPOSITORY|/ekip-$EKIP/'"
  ;;

login-x509)
  baslik "Adim 2: deploy token ile login -> x509"
  : "${DEPLOY_TOKEN:?}"
  printf '$ echo "$TOKEN" | docker login $REGISTRY -u ekip%s-deploy --password-stdin\n' "$EKIP"
  cikti="$(printf '%s' "$DEPLOY_TOKEN" | docker login "$REGISTRY" -u "ekip$EKIP-deploy" --password-stdin 2>&1)"; kod=$?
  printf '%s\n' "$cikti"
  [ "$kod" -ne 0 ] || { echo "HATA: login basarili oldu; x509 bekleniyordu" >&2; exit 1; }
  case "$cikti" in *"x509: certificate signed by unknown authority"*) not_ "beklenen hata olustu: Docker daemon'i kurum CA'sina guvenmiyor" ;; *) echo "HATA: x509 hatasi bekleniyordu" >&2; exit 1 ;; esac
  ;;

ca)
  baslik "Adim 2: kurum CA'sini Docker daemon'ina tanit (TLS dogrulamasi kapatilmaz)"
  kos sudo mkdir -p "/etc/docker/certs.d/$REGISTRY"
  kos sudo cp "$CA_CERT" "/etc/docker/certs.d/$REGISTRY/ca.crt"
  kabuk "ls -l /etc/docker/certs.d/"
  ;;

push-denied)
  baslik "Adim 2 (kontrol): login olmadan push reddedilir"
  docker logout "$REGISTRY" >/dev/null 2>&1 || true
  beklenen_hata "access forbidden" docker push "$IMG/order-service:1.0.1"
  ;;

push-salt-okunur)
  baslik "Kontrol: yalnizca read_registry yetkili token ile push reddedilir"
  : "${PULL_TOKEN:?}" "${DEPLOY_TOKEN:?}"
  printf '%s' "$PULL_TOKEN" | docker login "$REGISTRY" -u "ekip$EKIP-pull" --password-stdin >/dev/null 2>&1
  printf '$ docker login $REGISTRY -u ekip%s-pull   # read_registry\n' "$EKIP"
  docker tag "$IMG/order-service:1.0.1" "$IMG/order-service:yetki-denemesi"
  beklenen_hata "insufficient_scope: authorization failed" docker push "$IMG/order-service:yetki-denemesi"
  docker rmi "$IMG/order-service:yetki-denemesi" >/dev/null 2>&1
  not_ "Dogru token ile yeniden login"
  printf '%s' "$DEPLOY_TOKEN" | docker login "$REGISTRY" -u "ekip$EKIP-deploy" --password-stdin >/dev/null 2>&1
  kabuk "docker push $IMG/order-service:1.0.1 2>&1 | grep -E 'digest:|denied|forbidden'"
  ;;

push)
  baslik "Adim 2: login ve push"
  : "${DEPLOY_TOKEN:?}"
  printf '$ echo "$TOKEN" | docker login $REGISTRY -u ekip%s-deploy --password-stdin\n' "$EKIP"
  printf '%s' "$DEPLOY_TOKEN" | docker login "$REGISTRY" -u "ekip$EKIP-deploy" --password-stdin 2>&1 | grep -v -E 'WARNING|credential|credentials-store|^$' || true
  for s in order-service product-service web-ui; do
    kabuk "docker push --all-tags $IMG/$s 2>&1 | grep -E 'digest:|denied|error'"
  done
  ;;

compose)
  baslik "Adim 4: compose.yaml ve nginx.conf"
  rol dev
  cozumden lab-03b deploy/compose.yaml deploy/nginx.conf
  kabuk "cat deploy/compose.yaml"
  kabuk "cat deploy/nginx.conf"
  kos git add deploy
  kos git commit -m "feat(deploy): add compose file and nginx reverse proxy"
  not_ "nginx.conf imajin icinde: web-ui yeniden build edilir"
  SHA="$(git rev-parse --short HEAD)"
  kos docker build -q -f src/web-ui/Dockerfile --build-arg "HUB=$HUB" -t "$IMG/web-ui:1.0.1" -t "$IMG/web-ui:$SHA" .
  ;;

yerel-hata)
  baslik "Adim 5: lokalde compose up -> SQLite Error 14"
  export TAG=1.0.1
  not_ "WEB_PORT ortamda tanimli ($WEB_PORT): arayuz http://localhost:$WEB_PORT adresinde"
  kabuk "TAG=1.0.1 docker compose -p ekip$EKIP -f deploy/compose.yaml config | head -n 30"
  kos docker compose -p "ekip$EKIP" -f deploy/compose.yaml up -d
  sleep 8
  kos docker compose -p "ekip$EKIP" -f deploy/compose.yaml ps -a
  cikti="$(docker compose -p "ekip$EKIP" -f deploy/compose.yaml logs order-service 2>&1)"
  printf '$ docker compose -p ekip%s -f deploy/compose.yaml logs order-service\n' "$EKIP"
  printf '%s\n' "$cikti" | grep -E 'SQLite Error|Unhandled|unable to open' | head -n 4
  case "$cikti" in *"SQLite Error 14"*) not_ "beklenen hata olustu: SQLite Error 14 (root olmayan kullanici /data'ya yazamiyor)" ;; *) echo "HATA: SQLite Error 14 bekleniyordu" >&2; printf '%s\n' "$cikti" | tail -n 20; exit 1 ;; esac
  kabuk "docker compose -p ekip$EKIP -f deploy/compose.yaml logs web-ui 2>&1 | tail -n 3"
  ;;

yerel-duzelt)
  baslik "Adim 5: /data dizinini Dockerfile'da olustur, sahipligini ver"
  rol dev
  export TAG=1.0.1
  cozumden lab-03b src/order-service/Dockerfile
  kabuk "git diff HEAD | cat"
  kos git add src/order-service/Dockerfile
  kos git commit -m "fix(order): create the data directory for the non-root user"
  SHA="$(git rev-parse --short HEAD)"
  not_ "Kod degisti: uc imaj son commit'ten yeniden etiketlenir (1.0.1 ve $SHA)"
  uc_imaj "$SHA"
  not_ "Eski volume root'a ait kaldi: -v ile silinip yeniden olusturulur"
  kos docker compose -p "ekip$EKIP" -f deploy/compose.yaml down -v
  kos docker compose -p "ekip$EKIP" -f deploy/compose.yaml up -d
  http_bekle "http://localhost:$WEB_PORT/api/orders" 40
  kos docker compose -p "ekip$EKIP" -f deploy/compose.yaml ps
  kabuk "curl -fsS http://localhost:\$WEB_PORT/api/products | head -c 70; echo"
  ;;

yerel-kalicilik)
  baslik "Adim 5: container yeniden yaratilinca talep kaybolmuyor"
  export TAG=1.0.1
  kabuk "curl -fsS http://localhost:\$WEB_PORT/api/orders; echo"
  kos docker compose -p "ekip$EKIP" -f deploy/compose.yaml down
  kos docker compose -p "ekip$EKIP" -f deploy/compose.yaml up -d
  http_bekle "http://localhost:$WEB_PORT/api/orders" 40
  kabuk "curl -fsS http://localhost:\$WEB_PORT/api/orders; echo"
  [ "$(curl -fsS "http://localhost:$WEB_PORT/api/orders" | jq length)" -ge 1 ] || { echo "HATA: talep kayboldu" >&2; exit 1; }
  kos docker volume ls --filter "name=ekip${EKIP}_orders-data"
  kos docker compose -p "ekip$EKIP" -f deploy/compose.yaml down
  rol dev
  kos git push
  ;;

vm-hazirla)
  baslik "Adim 6: ikinci VM'e compose.yaml"
  kos scp deploy/compose.yaml "$VM:$VM_DIZIN/compose.yaml"
  printf '$ ssh %s "cat > %s/.env"   # IMG, TAG=1.0.1, WEB_PORT=%s\n' "$VM" "$VM_DIZIN" "$WEB_PORT"
  printf 'IMG=%s\nTAG=1.0.1\nWEB_PORT=%s\n' "$IMG" "$WEB_PORT" | ssh "$VM" "cat > $VM_DIZIN/.env"
  vm "ls -a && cat .env"
  ;;

vm-denied)
  baslik "Adim 6 (kontrol): ikinci VM'de login olmadan pull reddedilir"
  printf '$ ssh %s "docker compose -p ekip%s pull"\n' "$VM" "$EKIP"
  cikti="$(ssh -n "$VM" "cd $VM_DIZIN && export DOCKER_CONFIG=$VM_DIZIN/.docker && docker compose -p ekip$EKIP pull" 2>&1)"; kod=$?
  printf '%s\n' "$cikti" | grep -v -E 'Pulling *$' | tail -n 6
  [ "$kod" -ne 0 ] || { echo "HATA: pull basarili oldu; reddedilmesi bekleniyordu" >&2; exit 1; }
  case "$cikti" in *"access forbidden"*) not_ "beklenen hata olustu: access forbidden" ;; *) echo "HATA: 'access forbidden' bekleniyordu" >&2; exit 1 ;; esac
  ;;

vm-calistir)
  baslik "Adim 6: ikinci VM'de login (read_registry), pull, up"
  : "${PULL_TOKEN:?}"
  printf '$ echo "$TOKEN" | ssh %s "docker login $REGISTRY -u ekip%s-pull --password-stdin"\n' "$VM" "$EKIP"
  printf '%s' "$PULL_TOKEN" | ssh "$VM" "mkdir -p $VM_DIZIN/.docker && DOCKER_CONFIG=$VM_DIZIN/.docker docker login $REGISTRY -u ekip$EKIP-pull --password-stdin" 2>&1 | grep -v -E 'WARNING|credential|^$' || true
  vm "docker compose -p ekip$EKIP pull 2>&1 | tail -n 4"
  vm "docker compose -p ekip$EKIP up -d 2>&1 | tail -n 6"
  http_bekle "$TEST_URL/api/orders" 40
  vm "docker compose -p ekip$EKIP ps"
  ;;

smoke)
  baslik "Adim 7: smoke test"
  kabuk "curl -fsS \$TEST_URL/api/products | head -c 60; echo"
  kabuk "curl -fsS -o /dev/null -w '%{http_code}\n' -X POST \$TEST_URL/api/orders -H 'Content-Type: application/json' -d '{ \"productId\": \"KBL-02\", \"quantity\": 3 }'"
  kabuk "curl -fsS \$TEST_URL/api/orders; echo"
  not_ "Kalicilik: container'lar silinip yeniden yaratilir, talep durur"
  vm "docker compose -p ekip$EKIP down 2>&1 | tail -n 2 && docker compose -p ekip$EKIP up -d 2>&1 | tail -n 2"
  http_bekle "$TEST_URL/api/orders" 40
  kabuk "curl -fsS \$TEST_URL/api/orders; echo"
  [ "$(curl -fsS "$TEST_URL/api/orders" | jq length)" -ge 1 ] || { echo "HATA: talep kayboldu" >&2; exit 1; }
  ;;

sonuc)
  baslik "Adim 7: merge sonrasi"
  rol dev
  kos git switch develop
  kos git pull --ff-only
  kos git fetch --prune
  kos git branch -D feature/9-docker
  kabuk "git log --oneline --graph -n 6 origin/develop"
  baslik "Checkpoint karsilastirmasi"
  agac_ayni origin/develop lab-03b .gitlab/CODEOWNERS
  ;;
*) echo "bilinmeyen adim: $adim" >&2; exit 2 ;;
esac
