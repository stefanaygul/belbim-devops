# Lab dogrulama betiklerinin katilimci makinesindeki ortak islevleri.
# dogrula/lib.sh'den sonra yuklenir. Hicbir sey kalici olarak degistirmez.

REPO="${REPO:-$HOME/saha-ekipman-portal}"
EKIP="${EKIP:-${EKIP_NO:-}}"
PROJE_YOLU="$GITLAB_GROUP/ekip-$EKIP/saha-ekipman-portal"
bilgi()  { printf '  BILGI  %s\n' "$*"; }
atlandi() { printf '  ATLANDI %s\n' "$*"; }

_GECICI=()
_SURECLER=()
_temizle() {
  local p d
  for p in "${_SURECLER[@]:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null; done
  for d in "${_GECICI[@]:-}"; do
    [ -n "$d" ] || continue
    git -C "$REPO" worktree remove --force "$d" >/dev/null 2>&1
    rm -rf "$d"
  done
}
trap _temizle EXIT

# agac <ref> -> ref'in gecici bir calisma kopyasi (klasor adini yazar)
agac() {
  local d
  d="$(mktemp -d "/tmp/lab-dogrula-${EKIP}-XXXXXX")"
  rmdir "$d"
  git -C "$REPO" worktree add --quiet --detach "$d" "$1" >/dev/null 2>&1 || return 1
  _GECICI+=("$d")
  printf '%s' "$d"
}

# sablon_sha <branch> -> sablon projedeki branch'in commit'i
sablon_sha() {
  git ls-remote "$GITLAB_URL/$TEMPLATE_PROJECT.git" "refs/heads/$1" 2>/dev/null | cut -f1
}

http_kodu() { curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$@"; }
http_bekle() {
  local i
  for i in $(seq 1 "${2:-40}"); do
    [ "$(http_kodu "$1")" = "200" ] && return 0
    sleep 1
  done
  return 1
}

# GitLab API (salt okunur). GITLAB_TOKEN ortamdan gelir; komut satirina yazilmaz.
API_KODU=""
API_GOVDE=""
api() {  # api <yol>
  : "${GITLAB_TOKEN:?GITLAB_TOKEN tanimli degil (read_api yetkili bir token gerekir)}"
  local cfg govde
  cfg="$(mktemp)"; govde="$(mktemp)"
  chmod 600 "$cfg"
  printf 'header = "PRIVATE-TOKEN: %s"\n' "$GITLAB_TOKEN" > "$cfg"
  API_KODU="$(curl -sS -K "$cfg" -o "$govde" -w '%{http_code}' --max-time 60 "$GITLAB_URL/api/v4$1")" || API_KODU="000"
  API_GOVDE="$(cat "$govde")"
  rm -f "$cfg" "$govde"
  case "$API_KODU" in 2*) return 0 ;; *) return 1 ;; esac
}
urlenc() { jq -rn --arg v "$1" '$v|@uri'; }
PROJE_API="/projects/$(urlenc "$PROJE_YOLU")"

CONVENTIONAL='^(feat|fix|docs|style|refactor|test|chore|build|ci|perf|revert)(\([a-z0-9-]+\))?!?: .+'

# Jenkins ve SonarQube API (salt okunur). Kimlikler ortamdan gelir; komut satirina yazilmaz.
#   JENKINS_USER, JENKINS_PAROLA (parola ya da API token); SONAR_USER, SONAR_PAROLA
JOB_ADI="saha-portal-ekip$EKIP"
JOB_API="/job/ekip-$EKIP/job/$JOB_ADI"
SONAR_KEY="saha-portal-ekip$EKIP"
_temel_istek() {  # _temel_istek <kullanici> <parola> <url>
  local cfg govde
  cfg="$(mktemp)"; govde="$(mktemp)"
  chmod 600 "$cfg"
  printf 'user = "%s:%s"\n' "$1" "$2" > "$cfg"
  API_KODU="$(curl -sS -g -K "$cfg" -o "$govde" -w '%{http_code}' --max-time 60 "$3")" || API_KODU="000"
  API_GOVDE="$(cat "$govde")"
  rm -f "$cfg" "$govde"
  case "$API_KODU" in 2*) return 0 ;; *) return 1 ;; esac
}
jenkins_api() {  # jenkins_api <yol>
  : "${JENKINS_USER:?JENKINS_USER tanimli degil}" "${JENKINS_PAROLA:?JENKINS_PAROLA tanimli degil}"
  _temel_istek "$JENKINS_USER" "$JENKINS_PAROLA" "$JENKINS_URL$1"
}
sonar_api() {  # sonar_api <yol>
  : "${SONAR_USER:?SONAR_USER tanimli degil}" "${SONAR_PAROLA:?SONAR_PAROLA tanimli degil}"
  _temel_istek "$SONAR_USER" "$SONAR_PAROLA" "$SONAR_URL$1"
}
# dosya <yol> [ref]: ekip projesindeki dosyanin icerigi (API_GOVDE)
dosya() { api "$PROJE_API/repository/files/$(urlenc "$1")/raw?ref=${2:-develop}"; }
# gizli_yok <aciklama> <metin>: metinde token kalibi yok
gizli_yok() {
  if grep -q -E 'glpat-|gldt-|sqp_[0-9a-f]{8}|squ_[0-9a-f]{8}|sqa_[0-9a-f]{8}' <<<"$2"; then kaldi "$1: token degeri var"; else gecti "$1: token degeri yok"; fi
}
