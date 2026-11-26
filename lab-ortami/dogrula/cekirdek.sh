#!/usr/bin/env bash
# Cekirdek ortamin (Faz 2) dogrulamasi. Host'ta calisir (bash 3.2 uyumlu).
# Ortamin yapilandirmasini degistirmez; gecici dosyalarini ve cektigi imajlari temizler.
# Yan etkisi: Nexus proxy depolarinin onbellegi dolar.
# Kullanim: dogrula/cekirdek.sh
set -uo pipefail
cd "$(dirname "$0")/.."
source dogrula/lib.sh
source bootstrap/host-lib.sh

D="$(env_degeri LAB_DOMAIN)"
REGISTRY="gitlab.${D}:5050"
SONUC=0

# --- 1. Ag icinden: DNS, TLS, GitLab, registry, Nexus -------------------------
docker compose run --rm -T araclar bash dogrula/cekirdek-api.sh < /dev/null || SONUC=1

# --- 2. workstation: her ekip kullanicisiyla ----------------------------------
for nn in $(ekipler); do
  if [ "$nn" = "99" ]; then port=8099; else port=$((8080 + 10#$nn)); fi
  {
    printf 'BEKLENEN_EKIP=%s\nBEKLENEN_PORT=%s\n' "$nn" "$port"
    printf 'ana() {\n'
    cat dogrula/lib.sh dogrula/cekirdek-workstation.sh
    printf '\n}\nana\n'
  } | docker compose exec -T -u "ekip${nn}" workstation bash -l -s || SONUC=1
  # Tam derleme ve test yalnizca ilk ekipte: ikinci ekip ayni imaji ve agi kullanir.
  break
done

# --- 3. test VM: ic ice container'lar ----------------------------------------
baslik "test-vm: ic ice container'da ad cozumleme, CA ve Nexus"
node_imaj="${REGISTRY}/egitim/base/library/node:24-alpine"
sdk_imaj="${REGISTRY}/egitim/base/dotnet/sdk:10.0"
once="$(docker compose exec -T test-vm docker images -q < /dev/null | sort -u | wc -l | tr -d ' ')"
cikti="$(docker compose exec -T test-vm docker run --rm "$node_imaj" \
  node -e "fetch('https://nexus.${D}/service/rest/v1/status').then(r => console.log('durum', r.status)).catch(e => { console.log('hata', e.cause ? e.cause.code : e.message); process.exit(1) })" 2>&1 < /dev/null)"
icerir "Node temel imaji: anonim pull, lab DNS, lab CA (fetch nexus -> 200)" "durum 200" "$cikti"

cikti="$(docker compose exec -T test-vm docker run --rm "$sdk_imaj" bash -c "
  git clone --quiet https://gitlab.${D}/egitim/sablonlar/portal-starter.git /src &&
  cd /src && dotnet restore src/order-service 2>&1 | tail -n 3 && echo restore-kodu=\${PIPESTATUS[0]}" 2>&1 < /dev/null)"
icerir "SDK temel imaji: container icinde git clone + dotnet restore (Nexus)" "restore-kodu=0" "$cikti"
# Test VM'de kaynak kod ve SDK bulunmaz; denetim icin cekilen imajlar geri silinir.
docker compose exec -T test-vm docker rmi "$node_imaj" "$sdk_imaj" >/dev/null 2>&1 < /dev/null || true
esit "test VM'deki imaj sayisi denetimden once ve sonra ayni (ekiplerin imajlarina dokunulmadi)" "$once" "$(docker compose exec -T test-vm docker images -q < /dev/null | sort -u | wc -l | tr -d ' ')"

# --- 4. Nexus onbellegi: paketler gercekten proxy'den gecti mi -----------------
docker compose run --rm -T araclar bash dogrula/cekirdek-api.sh onbellek < /dev/null || SONUC=1

# --- 5. Host ------------------------------------------------------------------
baslik "Host"
https_port="$(env_degeri HOST_HTTPS_PORT)"
reg_port="$(env_degeri HOST_REGISTRY_PORT)"
for ad in gitlab nexus; do
  case "$ad" in gitlab) yol="/users/sign_in" ;; nexus) yol="/service/rest/v1/status" ;; esac
  kod="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 --cacert certs/ca.crt \
    --resolve "${ad}.${D}:${https_port}:127.0.0.1" "https://${ad}.${D}:${https_port}${yol}" 2>&1)"
  esit "host -> https://${ad}.${D} (lab CA'si ile, 127.0.0.1:${https_port})" "200" "$kod"
done
kod="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 --cacert certs/ca.crt \
  --resolve "gitlab.${D}:${reg_port}:127.0.0.1" "https://gitlab.${D}:${reg_port}/v2/" 2>&1)"
esit "host -> registry (127.0.0.1:${reg_port})" "401" "$kod"

kimlikler="$(docker compose --profile cekirdek --profile ci ps -q)"
# shellcheck disable=SC2086
acik="$(docker inspect $kimlikler --format '{{range $p, $b := .NetworkSettings.Ports}}{{range $b}}{{.HostIp}} {{end}}{{end}}' | tr ' ' '\n' | grep . | sort -u | tr '\n' ' ')"
esit "yayinlanan portlarin host adresi" "127.0.0.1 " "$acik"
# shellcheck disable=SC2086
soket="$(docker inspect $kimlikler --format '{{range .Mounts}}{{.Source}}{{"\n"}}{{end}}' | grep -c -x -E '(/private)?/var/run/docker\.sock|.*/\.docker/run/docker\.sock')"
esit "host Docker soketini baglayan container" "0" "$soket"
# shellcheck disable=SC2086
ayricalikli="$(docker inspect $kimlikler --format '{{if .HostConfig.Privileged}}{{index .Config.Labels "com.docker.compose.service"}}{{end}}' | grep . | sort | tr '\n' ' ')"
# ci profili calisiyorsa agent'in Docker daemon'i ucuncudur (ayrintili denetim: dogrula/ci.sh).
beklenen_daemon="test-vm workstation "
docker compose ps --status running --services 2>/dev/null | grep -qx agent-docker && beklenen_daemon="agent-docker test-vm workstation "
esit "kendi Docker daemon'i olan container'lar" "$beklenen_daemon" "$ayricalikli"

if grep -q "gitlab\.${D}" /etc/hosts 2>/dev/null; then
  gecti "/etc/hosts icinde gitlab.${D} kaydi var"
else
  printf '  \033[33mBILGI\033[0m  /etc/hosts icinde %s kaydi yok; tarayicidan erisim icin lab-ortami/README.md "Host hazirligi" adimlari gerekir\n' "gitlab.${D}"
fi

ozet || SONUC=1
if [ "$SONUC" -eq 0 ]; then
  printf '\n\033[32mCEKIRDEK ORTAM: GECTI\033[0m\n'
else
  printf '\n\033[31mCEKIRDEK ORTAM: KALDI\033[0m\n'
fi
exit "$SONUC"
