# Cozum betiklerinin ortak islevleri. Katilimci makinesinde, ekip kullanicisiyla calisir.
# Buradaki komutlar ogrenci rehberindeki komutlarla aynidir; `kos` komutu once ekrana yazar.
set -uo pipefail

REPO="$HOME/saha-ekipman-portal"
PROJE_YOLU="$GITLAB_GROUP/ekip-$EKIP/saha-ekipman-portal"
PROJE_SSH="git@$GITLAB_HOST:$PROJE_YOLU.git"
mkdir -p "$HOME/.lab-log"

baslik() { printf '\n\033[1m### %s\033[0m\n' "$*"; }
not_() { printf '# %s\n' "$*"; }
# kos <komut...>: komutu yazar, calistirir; basarisizsa betigi durdurur.
kos() {
  printf '$ %s\n' "$*"
  "$@" || { local k=$?; printf '\033[31mHATA\033[0m  komut basarisiz (cikis kodu %s): %s\n' "$k" "$*" >&2; exit "$k"; }
}
# kabuk <komut-metni>: boru ve yonlendirme iceren komutlar icin
kabuk() {
  printf '$ %s\n' "$1"
  bash -c "$1" || { local k=$?; printf '\033[31mHATA\033[0m  komut basarisiz (cikis kodu %s)\n' "$k" >&2; exit "$k"; }
}
# beklenen_hata <aranan-metin> <komut...>: komut BASARISIZ olmali ve ciktisi metni icermeli.
beklenen_hata() {
  local aranan="$1" cikti kod
  shift
  printf '$ %s\n' "$*"
  cikti="$("$@" 2>&1)"; kod=$?
  printf '%s\n' "$cikti" | tail -n 25
  if [ "$kod" -eq 0 ]; then
    printf '\033[31mHATA\033[0m  komut basarili oldu; "%s" hatasi bekleniyordu\n' "$aranan" >&2; exit 1
  fi
  case "$cikti" in
    *"$aranan"*) printf '# beklenen hata olustu (cikis kodu %s): %s\n' "$kod" "$aranan" ;;
    *) printf '\033[31mHATA\033[0m  hata olustu ama "%s" metni yok\n' "$aranan" >&2; exit 1 ;;
  esac
}
# http_bekle <url> [saniye]: adres 200 donene kadar bekler
http_bekle() {
  local i
  for i in $(seq 1 "${2:-60}"); do
    [ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 "$1")" = "200" ] && return 0
    sleep 1
  done
  printf '\033[31mHATA\033[0m  %s hazir olmadi\n' "$1" >&2
  return 1
}
# cozumden <checkpoint>[~N] <yol...>: cozum dosyalarini sablon projedeki checkpoint
# branch'inden (ya da onun N. atasindan) alir.
cozumden() {
  local cp="${1%%~*}" ek=""
  case "$1" in *~*) ek="~${1#*~}" ;; esac
  shift
  git fetch --quiet "$GITLAB_URL/$TEMPLATE_PROJECT.git" "checkpoint/$cp"
  git checkout --quiet "FETCH_HEAD$ek" -- "$@"
}
# CODEOWNERS sablonundaki NN yerine ekip numarasi yazilir (checkpoint-uygula.sh ile ayni kural).
codeowners_kisisellestir() {
  sed -i -e '/NN yerine/d' -e "s#@egitim/ekip-NN#@$GITLAB_GROUP/ekip-$EKIP#g" -e "s#@ekipNN-lead#@ekip$EKIP-lead#g" .gitlab/CODEOWNERS
}
# agac_ayni <ref> <checkpoint>[~N] [haric-yol ...]: iki agacin ayni oldugunu denetler
agac_ayni() {
  local ref="$1" cp="${2%%~*}" ek=""
  case "$2" in *~*) ek="~${2#*~}" ;; esac
  shift 2
  git fetch --quiet "$GITLAB_URL/$TEMPLATE_PROJECT.git" "checkpoint/$cp"
  local haric=() y
  for y in "$@"; do haric+=(":(exclude)$y"); done
  if git diff --quiet "$ref" "FETCH_HEAD$ek" -- . "${haric[@]}"; then
    printf '# agac ayni: %s == checkpoint/%s%s%s\n' "$ref" "$cp" "$ek" "${1:+ (haric: $*)}"
  else
    printf '\033[31mHATA\033[0m  %s ile checkpoint/%s%s farkli:\n' "$ref" "$cp" "$ek" >&2
    git diff --stat "$ref" "FETCH_HEAD$ek" -- . "${haric[@]}" >&2
    exit 1
  fi
}
# Sablondaki ekibe ozel yer tutucular (ekip-NN, ekipNN, PORT_NN, Saha.Common.Contracts.EkipNN) ekibin
# degerleriyle yazilir (sablon-hazirla.sh EKIP_KISISEL ile ayni kural).
ci_kisisellestir() {
  local f
  for f in "$@"; do
    sed -i -e "s#ekip-NN#ekip-$EKIP#g" -e "s#ekipNN#ekip$EKIP#g" -e "s#PORT_NN#$WEB_PORT#g" \
      -e "s#Saha\.Common\.Contracts\.EkipNN#Saha.Common.Contracts.Ekip$EKIP#g" "$f"
  done
}
# kisisel_ayni <ref> <checkpoint> <dosya...>: dosya, sablondakinin ekibe uyarlanmis haliyle ayni mi
kisisel_ayni() {
  local ref="$1" cp="$2" f
  shift 2
  git fetch --quiet "$GITLAB_URL/$TEMPLATE_PROJECT.git" "checkpoint/$cp"
  for f in "$@"; do
    if [ "$(git show "FETCH_HEAD:$f" | sed -e "s#ekip-NN#ekip-$EKIP#g" -e "s#ekipNN#ekip$EKIP#g" -e "s#PORT_NN#$WEB_PORT#g" \
          -e "s#Saha\.Common\.Contracts\.EkipNN#Saha.Common.Contracts.Ekip$EKIP#g")" = "$(git show "$ref:$f")" ]; then
      printf '# %s: checkpoint/%s ile ayni (NN yerine %s)\n' "$f" "$cp" "$EKIP"
    else
      printf '\033[31mHATA\033[0m  %s, checkpoint/%s icindekinden farkli\n' "$f" "$cp" >&2
      exit 1
    fi
  done
}
