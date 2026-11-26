# workstation icinde, ekip kullanicisiyla (login kabugu) calisir; dogrula/lib.sh'den sonra okunur.
# Betik standart giristen okundugu icin cekirdek.sh onu bir islev icine sarar: kabuk
# tamamini okumadan calistirmaz, standart girisi okuyan bir komut betigi yutamaz.
# Starter projeyi klonlar, Nexus uzerinden restore eder, derler ve test eder.
# Gecici bir klasorde calisir; ekibin ev dizinindeki calismaya ve paket onbelleklerine dokunmaz.
# (dotnet, ev dizininde ~/.dotnet ve ~/.nuget altinda birkac kucuk durum dosyasi birakabilir.)

calisma="$(mktemp -d)"
trap 'rm -rf "$calisma"' EXIT

# Paket onbellekleri gecici klasorde tutulur: paketler gercekten Nexus'tan gelir ve
# ekibin kendi onbelleklerine (~/.nuget, ~/.npm) dokunulmaz.
export DOTNET_CLI_HOME="$calisma/dotnet-home"
export NUGET_PACKAGES="$calisma/nuget-paketler"
export NUGET_HTTP_CACHE_PATH="$calisma/nuget-http"
export npm_config_cache="$calisma/npm-onbellek"

baslik "workstation ($(id -un))"
esit "EKIP" "${BEKLENEN_EKIP}" "${EKIP:-}"
esit "IMG" "${REGISTRY}/${GITLAB_GROUP}/ekip-${BEKLENEN_EKIP}/saha-ekipman-portal" "${IMG:-}"
esit "TEST_URL" "http://${TEST_VM}:${BEKLENEN_PORT}" "${TEST_URL:-}"
esit ".NET SDK" "10.0.404" "$(dotnet --version 2>&1)"
esit "Node.js" "v24.22.3" "$(node --version 2>&1)"
sudo -n true 2>/dev/null && gecti "sudo yetkisi var" || kaldi "sudo yetkisi yok"
docker info >/dev/null 2>&1 && gecti "Docker daemon'a erisim var (docker grubu)" || kaldi "Docker daemon'a erisilemiyor"

baslik "Starter proje: klonla (HTTPS, lab CA'si isletim sisteminde)"
cd "$calisma" || exit 1
if git clone --quiet "${GITLAB_URL}/${TEMPLATE_PROJECT}.git" saha-ekipman-portal 2>"$calisma/clone.err"; then
  gecti "git clone ${GITLAB_URL}/${TEMPLATE_PROJECT}.git"
else
  kaldi "git clone: $(cat "$calisma/clone.err")"
  ozet
  exit 1
fi
cd saha-ekipman-portal || exit 1
esit "NuGet kaynagi yalnizca Nexus" "1" "$(dotnet nuget list source --format short 2>/dev/null | grep -c .)"
icerir "NuGet kaynagi adresi" "$NUGET_GROUP_URL" "$(dotnet nuget list source --format short 2>/dev/null)"
esit ".npmrc registry" "registry=${NPM_GROUP_URL}" "$(cat src/web-ui/.npmrc)"

baslik "dotnet restore / build / test (onbellek bos, paketler Nexus'tan)"
cikti="$(dotnet restore 2>&1)"; kod=$?
esit "dotnet restore cikis kodu" "0" "$kod"
esit "restore uyarilari (NU1900 dahil)" "0" "$(printf '%s\n' "$cikti" | grep -ci 'warning')"
[ "$kod" = "0" ] || printf '%s\n' "$cikti" | tail -n 15
cikti="$(dotnet build --no-restore 2>&1)"; kod=$?
esit "dotnet build cikis kodu" "0" "$kod"
icerir "build: 0 uyari" "0 Warning(s)" "$cikti"
icerir "build: 0 hata" "0 Error(s)" "$cikti"
cikti="$(dotnet test --no-build 2>&1)"; kod=$?
esit "dotnet test cikis kodu" "0" "$kod"
esit "gecen test projesi sayisi" "2" "$(printf '%s\n' "$cikti" | grep -c 'Passed!')"

baslik "npm ci / npm test (onbellek bos, paketler Nexus'tan)"
cd src/web-ui || exit 1
cikti="$(npm ci --loglevel=http 2>&1)"; kod=$?
esit "npm ci cikis kodu" "0" "$kod"
[ "$kod" = "0" ] || printf '%s\n' "$cikti" | tail -n 15
nexus_istek="$(printf '%s\n' "$cikti" | grep -c "http fetch GET 200 ${NPM_GROUP_URL}")"
dis_istek="$(printf '%s\n' "$cikti" | grep 'http fetch' | grep -vc "${NPM_GROUP_URL}")"
[ "$nexus_istek" -gt 0 ] && gecti "npm paketleri Nexus'tan indirildi ($nexus_istek istek)" || kaldi "Nexus'a giden npm istegi yok"
esit "Nexus disina giden npm istegi" "0" "$dis_istek"
cikti="$(npm test 2>&1)"; kod=$?
esit "npm test cikis kodu" "0" "$kod"
icerir "Jest: 14 test gecti" "Tests:       14 passed, 14 total" "$cikti"

baslik "Docker daemon'i ve lab CA'si (katilimci LAB 03-B'de tanitir)"
# Var olmayan bir imaj istenir: hicbir sey indirilmez, yalnizca hata metnine bakilir.
cikti="$(docker pull "${REGISTRY}/${GITLAB_GROUP}/base/onkontrol-yok:0" 2>&1)"
if [ -e "/etc/docker/certs.d/${REGISTRY}/ca.crt" ]; then
  # LAB 03-B yapilmis ya da checkpoint/lab-03b uygulanmis: daemon registry'ye guvenmeli.
  printf '  BILGI  certs.d/%s var: LAB 03-B yapilmis (yeni kurulumda bulunmaz)\n' "$REGISTRY"
  case "$cikti" in
    *x509*) kaldi "certs.d var ama daemon registry'ye guvenmiyor: $(printf '%s' "$cikti" | tail -n 1 | cut -c1-160)" ;;
    *) gecti "daemon registry'ye lab CA'si ile guveniyor (TLS dogrulamasi acik)" ;;
  esac
else
  icerir "daemon lab CA'sina guvenmiyor: docker pull x509 hatasi veriyor" "x509: certificate signed by unknown authority" "$cikti"
  gecti "certs.d/${REGISTRY} yok"
fi
for imaj in "${MCR}/dotnet/sdk:10.0" "${MCR}/dotnet/aspnet:10.0" "${HUB}/library/node:24-alpine" "${HUB}/nginxinc/nginx-unprivileged:stable-alpine"; do
  docker image inspect "$imaj" >/dev/null 2>&1 && gecti "temel imaj makinede yuklu: ${imaj##*/base/}" || kaldi "temel imaj makinede yok: $imaj"
done
grep -qs 'insecure-registries' /etc/docker/daemon.json && kaldi "daemon.json icinde insecure-registries var" || gecti "insecure-registries kullanilmamis"

baslik "Test VM'e SSH (ekip anahtari)"
# Host anahtari gecici dosyaya yazilir; ekibin known_hosts dosyasina dokunulmaz.
cikti="$(ssh -n -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 \
  -o UserKnownHostsFile="$calisma/known_hosts" \
  "${TEST_VM_USER}@${TEST_VM}" 'id -un; docker version --format "{{.Server.Version}}"; ls -d /opt/saha/ekip'"${BEKLENEN_EKIP}"'; sudo -n true 2>/dev/null && echo sudo-var || echo sudo-yok' 2>&1)"
icerir "deploy kullanicisiyla baglanti" "deploy" "$cikti"
icerir "test VM'de Docker calisiyor" "29.10.0" "$cikti"
icerir "ekip dizini var" "/opt/saha/ekip${BEKLENEN_EKIP}" "$cikti"
icerir "deploy kullanicisinin sudo yetkisi yok" "sudo-yok" "$cikti"

ozet
