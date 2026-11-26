#!/usr/bin/env bash
# Bir ekibi bir labin sonundaki duruma getirir. Host'ta calisir (bash 3.2 uyumlu).
# Uc seyi birlikte kurar: kaynak kod (GitLab projesi ve katilimci makinesindeki repo),
# servis yapilandirmasi (korumalar, tag'ler, token'lar, registry imajlari),
# test ortami (uygulama ve verisi).
#
# YALNIZCA verilen ekibin kaynaklarina dokunur: egitim/ekip-NN, ekipNN-lead/dev hesaplari,
# workstation'daki ekipNN kullanicisi, test VM'deki /opt/saha/ekipNN ve ekipNN Compose projesi.
# Istisna (sandbox): lab-03b, workstation'in ekipler arasinda ortak olan Docker daemon'ina
# kurum CA'sini tanitir (BELBIM'de herkesin kendi makinesi vardir).
# MR ve yorum gecmisi geri kurulmaz. Katilimci makinesindeki eski repo ~/yedek altina tasinir.
#
# Kullanim: checkpoint-uygula.sh <ekip> <lab>
#   lab: lab-01a | gun1 | lab-02a | lab-02b (gun2) | lab-03a | lab-03b (gun3) | lab-04a | lab-04b (gun4)
#        | lab-05a | final
# lab-04a ve sonrasi icin ci profili calisiyor olmalidir (make up-ci). Daha erken bir
# checkpoint uygulanirken ci profili calisiyorsa ekibin Jenkins ve SonarQube kaynaklari kaldirilir.
set -euo pipefail
cd "$(dirname "$0")/.."
source bootstrap/host-lib.sh

nn="$(printf '%02d' "$((10#${1:?kullanim: checkpoint-uygula.sh <ekip> <lab>}))")"
lab="${2:?kullanim: checkpoint-uygula.sh <ekip> <lab>}"
lab="${lab#checkpoint/}"
case "$lab" in
  lab-01b) lab=gun1 ;;
  gun2) lab=lab-02b ;;
  gun3) lab=lab-03b ;;
  gun4) lab=lab-04b ;;
esac
imajli=0; ci=0; paketli=0
case "$lab" in
  lab-01a|gun1|lab-02a|lab-02b|lab-03a) ;;
  lab-03b) imajli=1 ;;
  lab-04a|lab-04b) imajli=1; ci=1 ;;
  lab-05a|final) imajli=1; ci=1; paketli=1 ;;
  *) echo "bilinmeyen checkpoint: $lab" >&2; exit 2 ;;
esac
ci_calisiyor=0
if docker compose ps --status running --services 2>/dev/null | grep -qx jenkins \
   && docker compose ps --status running --services 2>/dev/null | grep -qx sonarqube; then
  ci_calisiyor=1
fi
if [ "$ci" -eq 1 ] && [ "$ci_calisiyor" -eq 0 ]; then
  echo "checkpoint/$lab icin Jenkins ve SonarQube calisiyor olmali: make up-ci && make bootstrap" >&2
  exit 1
fi

ARACLAR="docker compose run --rm -T"
WS="docker compose exec -T -u ekip${nn} workstation"
VM="docker compose exec -T -u deploy test-vm"
D="$(env_degeri LAB_DOMAIN)"
if [ "$nn" = "99" ]; then port=8099; else port=$((8080 + 10#$nn)); fi
gizli=".cache/checkpoint/ekip${nn}.env"
trap 'rm -f "$gizli"' EXIT

printf '\033[1mcheckpoint/%s -> ekip-%s\033[0m\n' "$lab" "$nn"

# --- 1. GitLab ---------------------------------------------------------------
case "$lab" in
  lab-01a|gun1)
    adim "GitLab"
    echo "    1. gun checkpoint'i: ekip projesine dokunulmaz (proje LAB 02-A'da olusturulur)"
    ;;
  *)
    dev_anahtar="$($WS cat "/home/ekip${nn}/.ssh/id_ed25519.pub" < /dev/null)"
    lead_anahtar="$($WS cat "/home/ekip${nn}/.ssh/id_ed25519_lead.pub" < /dev/null)"
    $ARACLAR -e "DEV_ANAHTAR=$dev_anahtar" -e "LEAD_ANAHTAR=$lead_anahtar" araclar \
      bash bootstrap/ekip-gitlab.sh checkpoint "$nn" "$lab" < /dev/null
    ;;
esac

# --- 1b. Nexus: ekibin paketi silinir; lab-05a ve final'de workstation adimi yeniden yayinlar ----
$ARACLAR araclar bash bootstrap/ekip-nexus.sh sil "$nn" < /dev/null
if [ "$paketli" -eq 1 ]; then
  anahtar="$($ARACLAR araclar bash bootstrap/ekip-nexus.sh anahtar "$nn" < /dev/null)"
  mkdir -p "$(dirname "$gizli")"
  ( umask 077; printf 'NEXUS_APIKEY=%s\n' "$anahtar" >> "$gizli" )
  unset anahtar
fi

# --- 2. Test VM: bu checkpoint'te uygulama yoksa kaldirilir -------------------
if [ "$imajli" -eq 0 ]; then
  adim "test-vm"
  $VM env "NN=$nn" MOD=kaldir bash -s < bootstrap/checkpoint-vm.sh
  echo "    bu checkpoint'te test ortaminda uygulama yok"
fi

# --- 3. Katilimci makinesi ----------------------------------------------------
adim "workstation (ekip${nn})"
cikti="$(
  {
    printf 'export LAB=%s\n' "$lab"
    [ ! -f "$gizli" ] || sed 's/^/export /' "$gizli"
    cat bootstrap/checkpoint-ws.sh
  } | $WS bash -l -s
)"
printf '%s\n' "$cikti" | sed '/^COMPOSE_BASLANGIC$/,$d'

if [ "$lab" = "final" ]; then
  ( umask 077; printf 'JENKINS_SSH_KEY_B64=%s\n' "$($WS sh -c 'base64 -w0 ~/.ssh/jenkins-test-vm' < /dev/null)" >> "$gizli" )
fi

# --- 4. Test VM: uygulama ve veri (lab-03b ve sonrasi) -------------------------
if [ "$imajli" -eq 1 ]; then
  adim "test-vm"
  pull_token="$(sed -n 's/^PULL_TOKEN=//p' "$gizli")"
  {
    printf 'export NN=%s MOD=kur WEB_PORT=%s REGISTRY=%s IMG=%s\n' "$nn" "$port" "gitlab.${D}:5050" "gitlab.${D}:5050/egitim/ekip-${nn}/saha-ekipman-portal"
    printf 'export PULL_TOKEN=%s\n' "$pull_token"
    printf 'ana() {\n'
    cat bootstrap/checkpoint-vm.sh
    printf '\n}\nana <<'"'"'COMPOSE_SONU'"'"'\n'
    printf '%s\n' "$cikti" | sed '1,/^COMPOSE_BASLANGIC$/d'
    printf 'COMPOSE_SONU\n'
  } | $VM bash -s
fi

# --- 5. Jenkins ve SonarQube ---------------------------------------------------
if [ "$ci" -eq 1 ]; then
  $ARACLAR araclar bash bootstrap/ekip-ci.sh checkpoint "$nn" "$lab" < /dev/null
elif [ "$ci_calisiyor" -eq 1 ]; then
  $ARACLAR araclar bash bootstrap/ekip-ci.sh kaldir "$nn" < /dev/null
  bash bootstrap/ekip-agent-temizle.sh "$nn"
else
  adim "Jenkins ve SonarQube"
  echo "    ci profili calismiyor: ekibin Jenkins ve SonarQube kaynaklarina dokunulmadi"
fi

case "$lab" in
  gun1) denetim="lab-01-b" ;;
  final) denetim="lab-05-b" ;;
  *) denetim="$(printf '%s' "$lab" | sed 's/^lab-\([0-9][0-9]\)\([ab]\)$/lab-\1-\2/')" ;;
esac
printf '\n\033[32mcheckpoint/%s ekip-%s icin uygulandi.\033[0m Denetim: bash dogrula/lab.sh %s %s KAYNAK=checkpoint\n' \
  "$lab" "$nn" "$denetim" "$nn"
