# Lab ortam degiskenleri. /etc/lab/lab.env bootstrap tarafindan yazilir;
# ekibe ozel degerler kullanici adindan (ekipNN) turetilir.
if [ -f /etc/lab/lab.env ]; then
  set -a
  . /etc/lab/lab.env
  set +a
fi

# Node.js isletim sisteminin guven deposunu kullanmaz; npm kurum CA'sini buradan okur.
if [ -f /etc/lab/kurum-ca.crt ]; then
  export NODE_EXTRA_CA_CERTS=/etc/lab/kurum-ca.crt
fi

case "$(id -un)" in
  ekip[0-9][0-9])
    EKIP="$(id -un)"
    EKIP="${EKIP#ekip}"
    export EKIP
    if [ -n "${REGISTRY:-}" ]; then
      export IMG="${REGISTRY}/${GITLAB_GROUP}/ekip-${EKIP}/saha-ekipman-portal"
      # ekip-01 -> 8081 ... ekip-10 -> 8090; prova ekibi ekip-99 -> 8099
      if [ "$EKIP" = "99" ]; then WEB_PORT=8099; else WEB_PORT="$((8080 + 10#$EKIP))"; fi
      export WEB_PORT
      export TEST_URL="http://${TEST_VM}:${WEB_PORT}"
    fi
    ;;
esac

# Sandbox'ta bir ekibin iki GitLab hesabi (ekipNN-lead, ekipNN-dev) ayni Linux kullanicisini
# paylasir. `rol lead` / `rol dev`, git'in hangi SSH anahtarini ve hangi yazar kimligini
# kullanacagini bu kabuk icin secer. Herkesin kendi makinesi varsa gerekmez.
rol() {
  local anahtar
  case "${1:-}" in
    lead) anahtar="$HOME/.ssh/id_ed25519_lead" ;;
    dev)  anahtar="$HOME/.ssh/id_ed25519" ;;
    *) echo "kullanim: rol lead|dev   (su an: ${LAB_ROL:-secilmedi})"; return 2 ;;
  esac
  [ -f "$anahtar" ] || { echo "anahtar yok: $anahtar"; return 1; }
  export LAB_ROL="$1"
  export GIT_SSH_COMMAND="ssh -i $anahtar -o IdentitiesOnly=yes"
  export GIT_AUTHOR_NAME="Ekip ${EKIP} ${1^}" GIT_AUTHOR_EMAIL="ekip${EKIP}-$1@${GITLAB_HOST#gitlab.}"
  export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
  echo "rol: ekip${EKIP}-$1"
}
