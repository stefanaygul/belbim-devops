#!/usr/bin/env bash
# Temel imajlarin registry tarafi. araclar container'inda calisir.
#   30-imaj.sh denetle <hedef> <kaynak> <ca-parmak-izi>   guncelse 0 doner
#   30-imaj.sh it <arsiv.tar> <hedef>                      arsivi registry'ye gonderir
#   30-imaj.sh kimlik <hedef>                              "<tam-ad> <manifest-digest> <katmanlar> <kaynak>" yazar
#   30-imaj.sh arsivle <hedef> <arsiv.tar>                 registry'deki imaji docker-archive olarak kaydeder
set -euo pipefail
source "$(dirname "$0")/lib.sh"

TABAN="${REGISTRY}/${GITLAB_GROUP}/base"

case "${1:-}" in
  denetle)
    hedef="$2" kaynak="$3" parmak="$4"
    etiketler="$(skopeo inspect --no-tags "docker://${TABAN}/${hedef}" 2>/dev/null | jq -c '.Labels // {}')" || exit 1
    [ "$(jq -r '."lab.kaynak" // ""' <<<"$etiketler")" = "$kaynak" ] || exit 1
    [ "$(jq -r '."lab.ca" // ""' <<<"$etiketler")" = "$parmak" ] || exit 1
    ;;
  it)
    arsiv="/lab/ortam/.cache/base/$2" hedef="$3"
    # Kimlik bilgisi komut satirina yazilmaz; gecici bir authfile'da durur.
    auth="$_CURL_DIR/auth.json"
    ( umask 077
      jq -n --arg r "$REGISTRY" --arg a "$(printf 'root:%s' "$GITLAB_ADMIN_TOKEN" | base64 -w0)" \
        '{auths: {($r): {auth: $a}}}' > "$auth" )
    skopeo copy --quiet --dest-authfile "$auth" "docker-archive:${arsiv}" "docker://${TABAN}/${hedef}"
    ;;
  kimlik)
    # Katmanlar (diff_ids) imajin iceriginin kimligidir: registry'de ve `docker load`
    # sonrasinda ayni kalir; manifest digest'i ise sikistirmaya gore degisebilir.
    hedef="$2"
    ozet="$(skopeo inspect --no-tags "docker://${TABAN}/${hedef}")"
    yapi="$(skopeo inspect --config "docker://${TABAN}/${hedef}")"
    printf '%s %s %s %s\n' "${TABAN}/${hedef}" \
      "$(jq -r '.Digest' <<<"$ozet")" \
      "$(jq -r '.rootfs.diff_ids | join(",")' <<<"$yapi")" \
      "$(jq -r '.Labels."lab.kaynak" // "-"' <<<"$ozet")"
    ;;
  arsivle)
    hedef="$2" arsiv="/lab/ortam/.cache/base/$3"
    rm -f "$arsiv"
    skopeo copy --quiet "docker://${TABAN}/${hedef}" "docker-archive:${arsiv}:${TABAN}/${hedef}"
    chown "${HOST_UID:-0}:${HOST_GID:-0}" "$arsiv"
    ;;
  *)
    olum "kullanim: 30-imaj.sh denetle|it|kimlik|arsivle ..."
    ;;
esac
