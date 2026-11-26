#!/usr/bin/env bash
# Bir ekibi baslangic durumuna dondurur. Host'ta calisir (bash 3.2 uyumlu).
#
# YALNIZCA verilen ekibin kaynaklarini siler:
#   GitLab      : egitim/ekip-NN altindaki projeler (issue, MR, registry imajlariyla birlikte);
#                 ekipNN-lead/dev hesaplarinin SSH anahtarlari ve token'lari; roller asil haline
#   test VM     : ekipNN Compose projesi ve verisi, /opt/saha/ekipNN icerigi, ekibin imajlari
#   workstation : ~ekipNN/saha-ekipman-portal, ~/yedek, registry girisi, git kimligi,
#                 ekipNN Compose projesi, ekibin registry adli imajlari
#   Jenkins     : ekip-NN klasorundeki job'lar ve credential'lar; agent'taki calisma dizinleri
#                 ve agent'in Docker daemon'indaki ekip imajlari (ci profili calisiyorsa)
#   SonarQube   : saha-portal-ekipNN projeleri, ekipNN kullanicisinin token'lari
# Dokunmadiklari: diger ekipler, sablon proje, temel imajlar, Nexus depolari, SSH anahtar
# dosyalari, paket onbellekleri, workstation Docker daemon'inin ayarlari (certs.d ortaktir),
# Jenkins klasorunun kendisi ve yetkileri, Jenkins/SonarQube kullanicilari ve global ayarlar.
#   Nexus       : nuget-hosted'daki Saha.Common.Contracts.EkipNN paketi (her surumu)
#   test VM     : deploy kullanicisinda Jenkins'in ekip anahtari (yorumu jenkins-ekipNN olan satir)
#
# Kullanim: sifirla-ekip.sh <NN>      (onay ister; EVET=1 ile sormaz)
set -euo pipefail
cd "$(dirname "$0")/.."
source bootstrap/host-lib.sh

nn="$(printf '%02d' "$((10#${1:?kullanim: sifirla-ekip.sh <NN>}))")"
if [ "${EVET:-0}" != "1" ]; then
  echo "ekip-${nn} baslangic durumuna dondurulecek. Silinecekler:"
  echo "  - GitLab: egitim/ekip-${nn} altindaki projeler (kod, issue, MR, registry imajlari)"
  echo "  - test VM: ekip${nn} uygulamasi ve verisi, /opt/saha/ekip${nn} icerigi"
  echo "  - workstation: /home/ekip${nn}/saha-ekipman-portal ve yedekleri, registry girisi"
  echo "  - Jenkins: ekip-${nn} klasorundeki job ve credential'lar; SonarQube: saha-portal-ekip${nn}"
  echo "  - Nexus: Saha.Common.Contracts.Ekip${nn} paketi"
  read -r -p "Devam etmek icin 'evet' yazin: " cevap
  [ "$cevap" = "evet" ] || { echo "Vazgecildi."; exit 1; }
fi

docker compose run --rm -T araclar bash bootstrap/ekip-gitlab.sh sifirla "$nn" < /dev/null
docker compose run --rm -T araclar bash bootstrap/ekip-nexus.sh sil "$nn" < /dev/null

if docker compose ps --status running --services 2>/dev/null | grep -qx jenkins; then
  docker compose run --rm -T araclar bash bootstrap/ekip-ci.sh kaldir "$nn" < /dev/null
  bash bootstrap/ekip-agent-temizle.sh "$nn"
else
  adim "Jenkins ve SonarQube"
  echo "    ci profili calismiyor: ekibin Jenkins ve SonarQube kaynaklarina dokunulmadi"
fi

adim "test-vm"
docker compose exec -T -u deploy test-vm env "NN=$nn" MOD=kaldir TEMIZLE=1 bash -s < bootstrap/checkpoint-vm.sh
tamam "test VM temiz"

adim "workstation (ekip${nn})"
docker compose exec -T -u "ekip${nn}" workstation bash -l -s <<'WS'
set -euo pipefail
ben="$(id -un)"
pkill -u "$ben" -f 'dotnet run|product-service|order-service|vite' 2>/dev/null || true
# Reset repo dizini disindan calisir; burada compose.yaml bulunmayabilir. Repo eksik
# olsa da yalnizca bu ekibin Compose etiketli kaynaklarini kaldir.
containerlar="$(docker ps -aq --filter "label=com.docker.compose.project=$ben")"
[ -z "$containerlar" ] || docker rm -f $containerlar >/dev/null
volumelar="$(docker volume ls -q --filter "label=com.docker.compose.project=$ben")"
[ -z "$volumelar" ] || docker volume rm $volumelar >/dev/null
imajlar="$(docker images --format '{{.Repository}}:{{.Tag}}' | grep "^${IMG}/" || true)"
[ -z "$imajlar" ] || docker rmi -f $imajlar >/dev/null 2>&1 || true
docker logout "$REGISTRY" >/dev/null 2>&1 || true
rm -rf "$HOME/saha-ekipman-portal" "$HOME/yedek" "$HOME/.docker" "$HOME/.lab" "$HOME/.lab-log" "$HOME/.gitconfig"
printf '    \033[32mtamam\033[0m  repo, yedekler, registry girisi ve git kimligi silindi; SSH anahtarlari ve paket onbellekleri duruyor\n'
WS

printf '\n\033[32mekip-%s baslangic durumunda.\033[0m\n' "$nn"
