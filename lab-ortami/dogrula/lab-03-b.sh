# LAB 03-B dogrulamasi: registry, Compose ve ikinci VM.
# Basari kriteri: uygulama ikinci VM'de registry'den cekilen imajlarla calisiyor;
# talep kaydi container yeniden yaratilinca kaybolmuyor.
# Yan etkisi: test VM'deki order-service container'ini bir kez yeniden yaratir (veri kalir).
baslik "LAB 03-B (ekip-$EKIP)"
if ! api "$PROJE_API"; then kaldi "ekip projesi yok: $PROJE_YOLU"; ozet; return 1; fi
VM="$TEST_VM_USER@$TEST_VM"
VM_DIZIN="/opt/saha/ekip$EKIP"
vm() { ssh -n -o BatchMode=yes "$VM" "cd $VM_DIZIN && export DOCKER_CONFIG=$VM_DIZIN/.docker && $1" 2>&1; }

baslik "Registry: uc imaj, 1.0.1 ve commit SHA etiketi ayni digest"
api "$PROJE_API/registry/repositories?per_page=100"
depolar="$API_GOVDE"
for s in order-service product-service web-ui; do
  kimlik="$(jq -r --arg n "$s" '.[] | select(.name == $n) | .id' <<<"$depolar")"
  if [ -z "$kimlik" ]; then kaldi "$s registry'de yok"; continue; fi
  if api "$PROJE_API/registry/repositories/$kimlik/tags/1.0.1"; then
    d="$(jq -r '.digest' <<<"$API_GOVDE")"
    gecti "$s:1.0.1 var (${d:0:19}…)"
    api "$PROJE_API/registry/repositories/$kimlik/tags?per_page=100"
    es=""
    for t in $(jq -r '.[].name' <<<"$API_GOVDE" | grep -E '^[0-9a-f]{7,40}$'); do
      api "$PROJE_API/registry/repositories/$kimlik/tags/$t" && [ "$(jq -r '.digest' <<<"$API_GOVDE")" = "$d" ] && es="$t"
    done
    if [ -n "$es" ]; then gecti "$s: commit SHA etiketi $es ayni imaji gosteriyor"; else kaldi "$s: 1.0.1 ile ayni digest'e sahip commit SHA etiketi yok"; fi
  else
    kaldi "$s:1.0.1 etiketi yok"
  fi
done

baslik "Repo (develop): compose.yaml ve nginx.conf"
if api "$PROJE_API/repository/files/$(urlenc deploy/compose.yaml)/raw?ref=develop"; then
  c="$API_GOVDE"
  icerir 'imaj adi ${IMG} ve ${TAG} ile' 'image: ${IMG}/order-service:${TAG}' "$c"
  icerir 'port ${WEB_PORT:-8080}:8080' '${WEB_PORT:-8080}:8080' "$c"
  icerir "orders-data volume'u /data'da" 'orders-data:/data' "$c"
  icerir "baglanti ayari ortam degiskeniyle" 'ConnectionStrings__Orders: Data Source=/data/orders.db' "$c"
  esit "port yayinlayan servis sayisi (yalnizca web-ui)" "1" "$(grep -c -E '^\s+ports:' <<<"$c")"
  grep -q 'latest' <<<"$c" && kaldi "compose.yaml icinde latest geciyor" || gecti "compose.yaml icinde latest yok"
else
  kaldi "deploy/compose.yaml develop'ta yok"
fi
if api "$PROJE_API/repository/files/$(urlenc deploy/nginx.conf)/raw?ref=develop"; then
  icerir "nginx: /api/products -> product-service" 'proxy_pass http://product-service:8080' "$API_GOVDE"
  icerir "nginx: /api/orders -> order-service" 'proxy_pass http://order-service:8080' "$API_GOVDE"
else
  kaldi "deploy/nginx.conf develop'ta yok"
fi
if api "$PROJE_API/repository/files/$(urlenc src/order-service/Dockerfile)/raw?ref=develop"; then
  icerir "order-service Dockerfile: /data dizini uygulama kullanicisinin" 'chown $APP_UID /data' "$API_GOVDE"
fi

baslik "Katilimci makinesi: Docker daemon'i registry'ye guveniyor (TLS dogrulamasi acik)"
if [ -f "/etc/docker/certs.d/$REGISTRY/ca.crt" ] && cmp -s "/etc/docker/certs.d/$REGISTRY/ca.crt" "$CA_CERT"; then
  gecti "/etc/docker/certs.d/$REGISTRY/ca.crt kurum CA'si"
else
  kaldi "/etc/docker/certs.d/$REGISTRY/ca.crt yok ya da kurum CA'si degil"
fi
grep -qs 'insecure-registries' /etc/docker/daemon.json && kaldi "daemon.json icinde insecure-registries var" || gecti "insecure-registries kullanilmamis"

baslik "Test VM: $VM_DIZIN, Compose projesi ekip$EKIP"
durum="$(vm "docker ps --filter label=com.docker.compose.project=ekip$EKIP --format '{{.Label \"com.docker.compose.service\"}}|{{.Image}}|{{.Ports}}|{{.State}}'")"
for s in order-service product-service web-ui; do
  satir="$(grep "^$s|" <<<"$durum" | head -n 1)"
  if [ -z "$satir" ]; then kaldi "$s calismiyor"; continue; fi
  esit "$s imaji registry'den, etiket 1.0.1" "$IMG/$s:1.0.1" "$(cut -d'|' -f2 <<<"$satir")"
  port="$(cut -d'|' -f3 <<<"$satir")"
  if [ "$s" = "web-ui" ]; then
    icerir "web-ui port yayinliyor: $WEB_PORT -> 8080" ":$WEB_PORT->8080/tcp" "$port"
  else
    case "$port" in *"->"*) kaldi "$s disariya port yayinliyor: $port" ;; *) gecti "$s port yayinlamiyor" ;; esac
  fi
  uid="$(vm "docker exec ekip$EKIP-$s-1 id -u")"
  if [ -n "$uid" ] && [ "$uid" != "0" ]; then gecti "$s root degil (uid=$uid)"; else kaldi "$s root olarak calisiyor (uid=${uid:-?})"; fi
done
[ "$(vm "test -f $VM_DIZIN/.docker/config.json && echo var")" = "var" ] && gecti "registry girisi ekibin kendi dizininde (DOCKER_CONFIG)" \
  || kaldi "$VM_DIZIN/.docker/config.json yok (ekipler ayni girisi paylasiyor olabilir)"
[ "$(vm "ls $VM_DIZIN | grep -c -E '^(src|tests)$'")" = "0" ] && gecti "test VM'de kaynak kod yok" || kaldi "test VM'de kaynak kod var"

baslik "Smoke test ve kalicilik ($TEST_URL)"
esit "arayuz" "200" "$(http_kodu "$TEST_URL/")"
icerir "/api/products" '"code":"ADP-01"' "$(curl -fsS --max-time 10 "$TEST_URL/api/products" 2>&1)"
once="$(curl -fsS --max-time 10 "$TEST_URL/api/orders" 2>&1)"
if [ "$(jq 'length' <<<"$once" 2>/dev/null || echo 0)" -ge 1 ]; then
  gecti "talep kaydi var ($(jq 'length' <<<"$once") talep)"
  vm "docker compose -p ekip$EKIP up -d --force-recreate order-service" >/dev/null
  http_bekle "$TEST_URL/api/orders" 40
  esit "order-service yeniden yaratildi, talepler duruyor" "$once" "$(curl -fsS --max-time 10 "$TEST_URL/api/orders" 2>&1)"
else
  kaldi "talep kaydi yok: smoke testte bir talep olusturulmamis"
fi
esit "veri volume'u" "ekip${EKIP}_orders-data" "$(vm "docker volume ls -q --filter name=ekip${EKIP}_orders-data")"

baslik "Merge Request"
if [ "${KAYNAK:-}" = "checkpoint" ]; then
  atlandi "MR gecmisi (checkpoint bunu geri kurmaz)"
else
  api "$PROJE_API/merge_requests?state=merged&source_branch=$(urlenc feature/9-docker)&target_branch=develop&per_page=5"
  mr="$(jq -c '.[0] // empty' <<<"$API_GOVDE")"
  [ -n "$mr" ] && gecti "MR !$(jq -r '.iid' <<<"$mr"): feature/9-docker -> develop merge edilmis" || kaldi "feature/9-docker -> develop icin merge edilmis MR yok"
fi

ozet
