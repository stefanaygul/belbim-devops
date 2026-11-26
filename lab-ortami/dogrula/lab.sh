#!/usr/bin/env bash
# Bir dogrulama betigini katilimci makinesinde (workstation), ekip kullanicisiyla calistirir.
# Host'ta calisir (bash 3.2 uyumlu). sandbox modu icindir; integration modunda betikler
# katilimci makinesinde dogrudan calistirilir:
#   source dogrula/lib.sh; GITLAB_TOKEN=... bash dogrula/lab-02-a.sh
#   (Gun 4-5 icin ayrica JENKINS_USER, JENKINS_PAROLA, SONAR_USER, SONAR_PAROLA)
#
# Kullanim: dogrula/lab.sh <betik-adi> <ekip> [ORTAM=deger ...]
#   dogrula/lab.sh lab-01-a 01
#   dogrula/lab.sh lab-02-a 02 KAYNAK=checkpoint
#   dogrula/lab.sh temel-imaj-buildkit 01 DIS_ERISIM=1
#
# GitLab API denetimleri icin ekipNN-lead adina kisa omurlu, salt okunur bir token
# uretilir; deger standart giristen aktarilir ve betik bitince iptal edilir.
set -uo pipefail
cd "$(dirname "$0")/.."

betik="${1:?kullanim: dogrula/lab.sh <betik-adi> <ekip> [ORTAM=deger ...]}"
nn="$(printf '%02d' "$((10#${2:?ekip numarasi gerekli}))")"
shift 2
[ -f "dogrula/${betik}.sh" ] || { echo "dogrula/${betik}.sh yok" >&2; exit 2; }

token=""
case "$betik" in
  lab-01-*|temel-imaj-*|workstation-onkontrol) ;;
  *) token="$(docker compose run --rm -T araclar bash bootstrap/ekip-token.sh olustur "$nn" < /dev/null)" || {
       echo "token uretilemedi" >&2; exit 1; } ;;
esac

# Gun 4-5 lablari: Jenkins ve SonarQube salt okunur sorgulari ekip kullanicisiyla (ekipNN) yapilir;
# parolalar standart giristen aktarilir.
ci_ortam=""
case "$betik" in
  lab-04-*|lab-05-*) ci_ortam="$(docker compose run --rm -T araclar bash bootstrap/ekip-ci.sh parolalar "$nn" < /dev/null)" || {
       echo "CI kimlikleri alinamadi" >&2; exit 1; } ;;
esac

{
  printf 'export EKIP_NO=%s\n' "$nn"
  [ -z "$ci_ortam" ] || printf '%s\n' "$ci_ortam" | sed 's/^/export /'
  for atama in "$@"; do printf 'export %s\n' "$atama"; done
  [ -z "$token" ] || printf 'export GITLAB_TOKEN=%s\n' "$token"
  printf 'ana() {\n'
  cat dogrula/lib.sh dogrula/ortak-ws.sh "dogrula/${betik}.sh"
  printf '\n}\nana\n'
} | docker compose exec -T -u "ekip${nn}" workstation bash -l -s
kod=$?

[ -z "$token" ] || docker compose run --rm -T araclar bash bootstrap/ekip-token.sh iptal "$nn" < /dev/null >/dev/null 2>&1
exit "$kod"
